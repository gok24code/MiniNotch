import Foundation
import os

/// Keeps the Mac running with the lid closed by toggling `pmset disablesleep`.
///
/// An IOKit assertion cannot stop clamshell sleep, and `pmset` needs root. The first time the
/// mode is used, one admin prompt installs a narrow sudoers rule that allows exactly
/// `pmset -a disablesleep 0|1` without a password. After that it is silent.
///
/// The setting is system-wide and survives a crash, so it is always reset when the mode
/// ends, when the app quits, and on the next launch if a previous run left it on.
final class LidSleepGuard: @unchecked Sendable {
    private static let pmset = "/usr/bin/pmset"
    private static let rulePath = "/etc/sudoers.d/mininotch"
    private static let activeKey = "lidSleepGuardActive"

    private let queue = DispatchQueue(label: "mininotch.lidsleep")
    private let wanted = OSAllocatedUnfairLock(initialState: false)
    private let defaults = UserDefaults.standard

    /// Undoes a `disablesleep` left behind by a crashed or killed run.
    func recoverFromCrash() {
        guard defaults.bool(forKey: Self.activeKey) else { return }
        queue.async { [self] in setDisableSleep(false) }
    }

    /// Turns lid-closed operation on; `completion` gets whether it is now active.
    func enable(completion: @escaping @Sendable (Bool) -> Void) {
        wanted.withLock { $0 = true }
        queue.async { [self] in
            guard wanted.withLock({ $0 }) else { return completion(false) }
            if !isAuthorized, !installRule() { return completion(false) }
            guard wanted.withLock({ $0 }) else { return completion(false) }
            completion(setDisableSleep(true))
        }
    }

    func disable() {
        wanted.withLock { $0 = false }
        queue.async { [self] in setDisableSleep(false) }
    }

    /// Blocks until the setting is reset; used while the app is quitting.
    func disableAndWait() {
        wanted.withLock { $0 = false }
        queue.sync { setDisableSleep(false) }
    }

    // MARK: - Privileges

    private var isAuthorized: Bool {
        Self.run("/usr/bin/sudo", ["-n", "-l", Self.pmset, "-a", "disablesleep", "1"]) == 0
    }

    @discardableResult
    private func setDisableSleep(_ on: Bool) -> Bool {
        let ok = Self.run("/usr/bin/sudo", ["-n", Self.pmset, "-a", "disablesleep", on ? "1" : "0"]) == 0
        if ok { defaults.set(on, forKey: Self.activeKey) }
        return ok
    }

    /// Asks for an admin password once and installs the sudoers rule, validated with visudo first.
    private func installRule() -> Bool {
        let user = NSUserName()
        guard user.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }) else { return false }

        let rule = "\(user) ALL=(root) NOPASSWD: \(Self.pmset) -a disablesleep 0, \(Self.pmset) -a disablesleep 1"
        let temp = NSTemporaryDirectory() + "mininotch-\(UUID().uuidString).sudoers"
        let shell = """
        printf '%s\\n' '\(rule)' > '\(temp)' \
        && /usr/sbin/visudo -cf '\(temp)' \
        && /usr/bin/install -m 440 -o root -g wheel '\(temp)' '\(Self.rulePath)'; \
        status=$?; rm -f '\(temp)'; exit $status
        """
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let prompt = "MiniNotch needs to allow Always Awake to keep your Mac running with the lid closed."
        let script = "do shell script \"\(escaped)\" with prompt \"\(prompt)\" with administrator privileges"
        return Self.run("/usr/bin/osascript", ["-e", script]) == 0
    }

    private static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
