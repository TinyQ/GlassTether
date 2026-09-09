#!/bin/bash
set -euo pipefail
LAB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$LAB_ROOT"
swift build -c release
LAB_BIN="$(swift build -c release --show-bin-path)"
mkdir -p dist
LAB_BUILD=1
while [[ -e "dist/LiveMateBluetoothLab-$(printf '%03d' "$LAB_BUILD").app" ]]; do
  LAB_BUILD=$((LAB_BUILD + 1))
done
LAB_APP="$LAB_ROOT/dist/LiveMateBluetoothLab-$(printf '%03d' "$LAB_BUILD").app"
mkdir -p "$LAB_APP/Contents/MacOS"
cp "$LAB_BIN/LiveMateBluetoothLab" "$LAB_APP/Contents/MacOS/LiveMateBluetoothLab"
cat > "$LAB_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LiveMateBluetoothLab</string>
<key>CFBundleIdentifier</key><string>com.tinyq.livemate.bluetoothlab</string>
<key>CFBundleName</key><string>LiveMate 蓝牙实验室</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>$LAB_BUILD</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>将本 Mac 作为实验鼠标，连接并控制你手动配对的 iPhone。</string>
<key>NSBluetoothPeripheralUsageDescription</key><string>发布蓝牙鼠标服务，供你的 iPhone 手动配对。</string>
<key>NSCameraUsageDescription</key><string>在你选择连接后显示 USB iPhone 屏幕，不采集音频、不保存画面。</string>
</dict></plist>
EOF
codesign --force --sign - --entitlements "$LAB_ROOT/script/Lab.entitlements" "$LAB_APP"
codesign --verify --deep --strict "$LAB_APP"
plutil -lint "$LAB_APP/Contents/Info.plist"
printf '\n独立应用：%s\n' "$LAB_APP"
