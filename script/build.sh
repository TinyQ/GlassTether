#!/bin/bash
set -euo pipefail
GT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$GT_ROOT"
swift build -c release
GT_BIN="$(swift build -c release --show-bin-path)"
mkdir -p dist
GT_BUILD=1
while [[ -e "dist/GlassTether-$(printf '%03d' "$GT_BUILD").app" ]]; do
  GT_BUILD=$((GT_BUILD + 1))
done
GT_APP="$GT_ROOT/dist/GlassTether-$(printf '%03d' "$GT_BUILD").app"
mkdir -p "$GT_APP/Contents/MacOS"
cp "$GT_BIN/GlassTether" "$GT_APP/Contents/MacOS/GlassTether"
cat > "$GT_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassTether</string>
<key>CFBundleIdentifier</key><string>local.glasstether.preview</string>
<key>CFBundleName</key><string>GlassTether</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0-alpha.1</string>
<key>CFBundleVersion</key><string>$GT_BUILD</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>Connect this Mac as a mouse to the iPhone you explicitly pair.</string>
<key>NSBluetoothPeripheralUsageDescription</key><string>Advertise a mouse for manual pairing with your iPhone.</string>
<key>NSCameraUsageDescription</key><string>Show USB iPhone video after you choose Connect. No audio or saved frames.</string>
</dict></plist>
EOF
codesign --force --sign - --entitlements "$GT_ROOT/script/GlassTether.entitlements" "$GT_APP"
codesign --verify --deep --strict "$GT_APP"
plutil -lint "$GT_APP/Contents/Info.plist"
printf '\nApplication:%s\n' "$GT_APP"
