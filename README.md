# MiniNotch

A lightweight macOS notch utility (macOS 14+, Apple Silicon). A black panel sits
over the notch and springs open on hover, showing the battery state and an
AirDrop drop zone. No dependencies, no private APIs.

## Features

- Panel exactly over the hardware notch; expands on hover, collapses when the pointer leaves.
- Battery: percentage, Charging / On AC Power / On Battery, SF Symbol. Hidden on Macs without an internal battery.
- AirDrop: drag files onto the notch. It expands, highlights, and dropping opens the AirDrop sheet.
- Charging toast: when a charger is connected, the collapsed shape briefly widens to show a bolt and the percentage.
- Camera / microphone indicators: while any app uses a camera or microphone, a green (camera) or orange
  (microphone) dot sits beside the notch.
- Camera mirror: the camera button in the expanded panel opens a mirrored live preview. The camera turns
  off when you close it or the pointer leaves the panel.
- Right-click menu: **Hover Delay** (Off / Short / Long), **Island Size** (Small / Medium / Large),
  **Launch at Login** (via `SMAppService.mainApp`) and **Quit**.
- One panel per connected screen: the notch style on notched displays, and a floating island on others
  (a pill centered in the menu bar that expands into a rounded card). Plugging in, unplugging or
  rearranging displays is handled live.

## Build

```sh
swift build                 # debug build
./scripts/build_app.sh      # release build → ./build/MiniNotch.app (ad-hoc signed)
```

The script writes an `Info.plist` with `LSUIElement=YES`, bundle id
`com.stark.mininotch`, `LSMinimumSystemVersion=14.0` and `NSCameraUsageDescription`, then runs
`codesign --force --deep -s -`.

The app icon is drawn in code by `scripts/make_icon.swift`. Run `swift scripts/make_icon.swift` after
editing it to regenerate `Resources/AppIcon.icns` (and a 1024 px preview, `Resources/AppIcon-1024.png`).

## Run

```sh
open build/MiniNotch.app
```

The app has no Dock icon. Right-click the notch for settings and to quit.
The first time you open the mirror, macOS asks for camera access.
Launch at Login only works from the bundled `.app`, not from `swift run`. Move
the app to `/Applications` first so the login item points at a stable path.

## Measure idle CPU

```sh
PID=$(pgrep -x MiniNotch)
sleep 30                                   # leave the mouse away from the notch
for i in 1 2 3 4 5; do ps -o %cpu=,rss=,time= -p $PID; sleep 2; done
top -l 5 -s 2 -pid $PID -stats pid,command,cpu,mem,idlew
```

Expected: `%cpu` 0.0, and the cumulative `time` column does not grow while idle.
Measured on an Apple M5 running macOS 27.0.1: 0.0% CPU in every sample, about 46 MB RSS
(13 MB in `top`'s MEM), cumulative CPU time steady at 0.09 s, and the idle-wakeup count unchanged.

### Why it idles at zero

- No repeating timers, display links, `TimelineView`, or repeating animations. Springs run once per state change.
  The only deferred work is a cancellable one-shot `Task.sleep`: the hover delay, and the 3-second charging toast.
- Camera and microphone state comes from CoreMediaIO / CoreAudio property listeners, not from polling.
- AVFoundation is touched only after the mirror is first opened, and the capture session stops as soon as it closes.
- Hover uses an `NSTrackingArea` on the panel's own view. There are no global event monitors.
- Battery updates come from `IOPSNotificationCreateRunLoopSource`.
- When collapsed, the window is exactly notch-sized and the expanded content is removed from the view hierarchy.
- Always Awake is the one exception: while its switch is on it polls power assertions, CPU and disk every 2.5 s and
  runs `nettop` for network traffic. Turning it off, or it finding nothing left to wait for, stops all of that.

## Known limitations

- Mirrored displays share one panel, because macOS reports a mirror set as a single screen.
- The hover tracking area covers the whole panel frame. While the collapse animation runs, the frame is
  briefly larger than the black shape, so re-entering that area re-expands the panel.
- With Hover Delay set to Off, moving the pointer into the menu bar under the notch expands the panel immediately.
- The microphone dot uses each device's "running somewhere" flag. A device that has both input and
  output streams (some headsets) can therefore show the dot during playback only.
- The mirror itself uses the camera, so the green camera dot can flash briefly after the mirror closes.
- Once the mirror has been opened, AVFoundation stays loaded, so memory stays higher until the app quits.
  CPU returns to idle.
- Camera permission is tied to the code signature. Each ad-hoc rebuild can make macOS ask again.
- The AirDrop sheet needs the app to be activated, so it briefly takes focus.
- Ad-hoc signed only. On other Macs, Gatekeeper requires right-click → Open, or notarization.
- No AirDrop SF Symbol is public, so the drop zone uses `dot.radiowaves.left.and.right`.
