#!/usr/bin/env bash
# Builds a release binary and assembles an ad-hoc signed MiniNotch.app in ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/MiniNotch.app"
cd "$ROOT"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MiniNotch" "$APP/Contents/MacOS/MiniNotch"
# Regenerate with `swift scripts/make_icon.swift`.
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>MiniNotch</string>
    <key>CFBundleIdentifier</key><string>com.stark.mininotch</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>MiniNotch</string>
    <key>CFBundleDisplayName</key><string>MiniNotch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSCameraUsageDescription</key><string>MiniNotch uses the camera only while the mirror is open.</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

codesign --force --deep -s - "$APP"
codesign --verify --strict "$APP"

echo "Built $APP"
