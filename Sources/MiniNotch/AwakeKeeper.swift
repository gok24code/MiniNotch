import AppKit
import Darwin
import IOKit.pwr_mgt
import Observation

enum ActivityReason: Hashable, Sendable {
    case powerAssertion, network, disk, cpu

    var label: String {
        switch self {
        case .powerAssertion: "Prevents sleep"
        case .network: "Network"
        case .disk: "Disk"
        case .cpu: "CPU"
        }
    }
}

/// An app (or background process) that is busy enough to be worth keeping the Mac awake for.
struct ActivityItem: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let reasons: [ActivityReason]
}

/// Always Awake: holds an idle-sleep assertion while apps are doing real work
/// (downloads, builds, anything that asks the system not to sleep) and turns
/// itself off as soon as nothing is left.
///
/// Nothing runs while the mode is off, so the app keeps its zero idle cost.
@MainActor
@Observable
final class AwakeKeeper {
    /// Sampling needs a baseline, and `nettop` takes ~5 s per sample. Until this much time
    /// has passed an empty list does not end the mode.
    private static let warmUp: Duration = .seconds(12)
    private static let localInterval: Duration = .seconds(2.5)

    private(set) var isEnabled = false
    private(set) var activeTasks: [ActivityItem] = []
    /// Whether the Mac is also kept running with the lid closed.
    private(set) var isLidSleepBlocked = false
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    @ObservationIgnored private var localTask: Task<Void, Never>?
    @ObservationIgnored private var networkTask: Task<Void, Never>?
    @ObservationIgnored private var localHits: [pid_t: Set<ActivityReason>] = [:]
    @ObservationIgnored private var networkHits: [pid_t: Set<ActivityReason>] = [:]
    @ObservationIgnored private var startedAt = ContinuousClock.now
    @ObservationIgnored private var sampler = ActivitySampler()
    @ObservationIgnored private let lidGuard = LidSleepGuard()

    init() {
        lidGuard.recoverFromCrash()
    }

    /// Releases everything the mode holds; called when the app quits.
    func shutdown() {
        lidGuard.disableAndWait()
    }

    func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        if on {
            guard acquireAssertion() else { return }
            isEnabled = true
            startedAt = .now
            sampler = ActivitySampler()
            startSampling()
            lidGuard.enable { [weak self] active in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLidSleepBlocked = active && self.isEnabled
                }
            }
        } else {
            lidGuard.disable()
            isLidSleepBlocked = false
            isEnabled = false
            stopSampling()
            releaseAssertion()
            activeTasks = []
        }
        onChange?()
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    // MARK: - Sampling

    private func startSampling() {
        let sampler = sampler
        localTask = Task { [weak self] in
            while !Task.isCancelled {
                let hits = await sampler.sampleLocal()
                guard !Task.isCancelled, let self else { return }
                self.localHits = hits
                self.refresh()
                try? await Task.sleep(for: Self.localInterval)
            }
        }
        networkTask = Task { [weak self] in
            while !Task.isCancelled {
                let hits = await sampler.sampleNetwork()
                guard !Task.isCancelled, let self else { return }
                self.networkHits = hits
                self.refresh()
            }
        }
    }

    private func stopSampling() {
        localTask?.cancel()
        networkTask?.cancel()
        localTask = nil
        networkTask = nil
        localHits = [:]
        networkHits = [:]
    }

    /// Merges both sample sets, groups helper processes under their app, and ends the mode when idle.
    private func refresh() {
        guard isEnabled else { return }

        var merged = localHits
        for (pid, reasons) in networkHits {
            merged[pid, default: []].formUnion(reasons)
        }

        var grouped: [pid_t: (name: String, icon: NSImage?, reasons: Set<ActivityReason>)] = [:]
        for (pid, reasons) in merged {
            guard let owner = Self.owner(of: pid) else { continue }
            var entry = grouped[owner.pid] ?? (owner.name, owner.icon, [])
            entry.reasons.formUnion(reasons)
            grouped[owner.pid] = entry
        }

        let items = grouped
            .map { pid, entry in
                ActivityItem(
                    id: pid,
                    name: entry.name,
                    icon: entry.icon,
                    reasons: [.powerAssertion, .network, .disk, .cpu].filter(entry.reasons.contains)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let oldHeight = NotchGeometry.awakeListHeight(taskCount: activeTasks.count)
        activeTasks = items
        if NotchGeometry.awakeListHeight(taskCount: items.count) != oldHeight {
            onChange?()
        }

        if items.isEmpty, ContinuousClock.now - startedAt >= Self.warmUp {
            setEnabled(false)
        }
    }

    /// Core system apps that are busy by design and say nothing about the user's work.
    private static let systemBundleIDs: Set<String> = [
        "com.apple.finder", "com.apple.dock", "com.apple.loginwindow", "com.apple.systemuiserver",
        "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.Spotlight",
        "com.apple.WindowManager", "com.apple.universalcontrol", "com.apple.backgroundtaskmanagement.agent",
    ]

    /// The regular app a process belongs to (Chrome Helper → Chrome, caffeinate → Terminal).
    /// Returns nil for system processes and anything that no user-facing app owns.
    private static func owner(of pid: pid_t) -> (pid: pid_t, name: String, icon: NSImage?)? {
        if let found = ancestorApp(of: pid) { return found.isSystem ? nil : found.owner }
        // Orphaned jobs (nohup, disown, tmux) lose their parent chain but keep their terminal:
        // borrow the app of any other process on the same tty.
        guard let tty = terminalDevice(of: pid) else { return nil }
        for other in allProcessIDs() where other != pid && terminalDevice(of: other) == tty {
            if let found = ancestorApp(of: other) { return found.isSystem ? nil : found.owner }
        }
        return nil
    }

    private static func ancestorApp(of pid: pid_t) -> (owner: (pid: pid_t, name: String, icon: NSImage?), isSystem: Bool)? {
        var current = pid
        for _ in 0..<12 {
            if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular {
                let isSystem = app.bundleIdentifier.map(systemBundleIDs.contains) ?? false
                return ((current, app.localizedName ?? processName(current), app.icon), isSystem)
            }
            guard let parent = parentPID(of: current), parent > 1 else { break }
            current = parent
        }
        return nil
    }

    // MARK: - Power assertion

    private func acquireAssertion() -> Bool {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MiniNotch Always Awake" as CFString,
            &assertionID
        )
        return result == kIOReturnSuccess
    }

    private func releaseAssertion() {
        guard assertionID != kIOPMNullAssertionID else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    }
}

// MARK: - Process helpers

private func processName(_ pid: pid_t) -> String {
    var buffer = [CChar](repeating: 0, count: 256)
    guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "PID \(pid)" }
    return String(cString: buffer)
}

private func kernelInfo(of pid: pid_t) -> kinfo_proc? {
    // sysctl works for root-owned processes such as `login`, where proc_pidinfo is denied.
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
    return info
}

private func parentPID(of pid: pid_t) -> pid_t? {
    kernelInfo(of: pid)?.kp_eproc.e_ppid
}

/// The controlling terminal of a process, or nil when it has none.
private func terminalDevice(of pid: pid_t) -> dev_t? {
    guard let tty = kernelInfo(of: pid)?.kp_eproc.e_tdev, tty != dev_t.max, tty != 0 else { return nil }
    return tty
}

private func allProcessIDs() -> [pid_t] {
    let capacity = proc_listallpids(nil, 0)
    guard capacity > 0 else { return [] }
    var pids = [pid_t](repeating: 0, count: Int(capacity) + 32)
    let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
    return count > 0 ? Array(pids.prefix(Int(count))) : []
}

// MARK: - Sampler

/// Measures what the system is doing off the main actor. Keeps the previous
/// sample so rates can be derived from counters.
actor ActivitySampler {
    private static let cpuThreshold = 0.25          // fraction of one core
    private static let diskThreshold = 1_000_000.0  // bytes per second
    private static let networkThreshold = 100_000.0 // bytes per second
    /// System daemons that are busy by design and say nothing about the user's work.
    private static let ignoredNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "mds", "mds_stores", "mdworker", "mdworker_shared",
        "fseventsd", "powerd", "mDNSResponder", "coreaudiod", "logd", "syslogd", "MiniNotch",
    ]

    private struct Usage {
        var cpuNanos: UInt64
        var diskBytes: UInt64
        var at: UInt64
    }

    private var previousUsage: [pid_t: Usage] = [:]
    private var streaks: [pid_t: [ActivityReason: Int]] = [:]
    private var previousNetwork: [pid_t: UInt64] = [:]
    private var previousNetworkAt: UInt64?
    private let ownPID = getpid()

    /// Power assertions plus CPU and disk load. CPU and disk must stay high for two samples in a row.
    func sampleLocal() -> [pid_t: Set<ActivityReason>] {
        var result: [pid_t: Set<ActivityReason>] = [:]
        for pid in assertionHolders() {
            result[pid, default: []].insert(.powerAssertion)
        }

        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        var usage: [pid_t: Usage] = [:]
        var nextStreaks: [pid_t: [ActivityReason: Int]] = [:]

        for pid in allProcessIDs() where pid > 1 && pid != ownPID {
            guard let (cpu, disk) = Self.readUsage(pid) else { continue }
            let current = Usage(cpuNanos: cpu, diskBytes: disk, at: now)
            usage[pid] = current
            guard let old = previousUsage[pid], now > old.at else { continue }

            let seconds = Double(now - old.at) / 1e9
            var exceeded: Set<ActivityReason> = []
            if cpu >= old.cpuNanos, Double(cpu - old.cpuNanos) / 1e9 / seconds >= Self.cpuThreshold {
                exceeded.insert(.cpu)
            }
            if disk >= old.diskBytes, Double(disk - old.diskBytes) / seconds >= Self.diskThreshold {
                exceeded.insert(.disk)
            }
            guard !exceeded.isEmpty, !Self.ignoredNames.contains(processName(pid)) else { continue }

            for reason in exceeded {
                let count = (streaks[pid]?[reason] ?? 0) + 1
                nextStreaks[pid, default: [:]][reason] = count
                if count >= 2 {
                    result[pid, default: []].insert(reason)
                }
            }
        }

        previousUsage = usage
        streaks = nextStreaks
        return result
    }

    /// Processes moving enough network traffic since the last call. Takes ~5 s because `nettop` does.
    func sampleNetwork() async -> [pid_t: Set<ActivityReason>] {
        guard let output = await Self.runNettop() else {
            // Without nettop the mode still works on assertions, CPU and disk.
            try? await Task.sleep(for: .seconds(5))
            return [:]
        }
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)

        var totals: [pid_t: UInt64] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count >= 3,
                  let dot = columns[0].lastIndex(of: "."),
                  let pid = pid_t(columns[0][columns[0].index(after: dot)...]),
                  let received = UInt64(columns[1]),
                  let sent = UInt64(columns[2]) else { continue }
            totals[pid, default: 0] += received + sent
        }

        var result: [pid_t: Set<ActivityReason>] = [:]
        if let before = previousNetworkAt, now > before {
            let seconds = Double(now - before) / 1e9
            for (pid, bytes) in totals where pid != ownPID {
                guard let old = previousNetwork[pid], bytes >= old,
                      Double(bytes - old) / seconds >= Self.networkThreshold,
                      !Self.ignoredNames.contains(processName(pid)) else { continue }
                result[pid] = [.network]
            }
        }
        previousNetwork = totals
        previousNetworkAt = now
        return result
    }

    // MARK: - System queries

    /// PIDs that currently hold an assertion that prevents the Mac from sleeping.
    private func assertionHolders() -> [pid_t] {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byPID = unmanaged?.takeRetainedValue() as? [Int: [[String: Any]]] else { return [] }

        let blocking: Set<String> = ["PreventUserIdleSystemSleep", "PreventSystemSleep", "NoIdleSleepAssertion"]
        return byPID.compactMap { pid, assertions in
            let pid = pid_t(pid)
            guard pid > 1, pid != ownPID, !Self.ignoredNames.contains(processName(pid)) else { return nil }
            let blocks = assertions.contains { (($0["AssertType"] as? String).map(blocking.contains)) ?? false }
            return blocks ? pid : nil
        }
    }

    /// Cumulative CPU time in nanoseconds and disk bytes (read + written) of a process.
    private static func readUsage(_ pid: pid_t) -> (cpu: UInt64, disk: UInt64)? {
        var info = rusage_info_current()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
            }
        }
        guard status == 0 else { return nil }

        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let ticks = info.ri_user_time &+ info.ri_system_time
        let nanos = ticks &* UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
        return (nanos, info.ri_diskio_bytesread &+ info.ri_diskio_byteswritten)
    }

    private static func runNettop() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
                process.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil)
            }
        }
    }
}
