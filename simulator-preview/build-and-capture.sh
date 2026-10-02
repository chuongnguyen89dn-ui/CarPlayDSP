#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-$PWD/output}"; APP="$OUT/CarPlaySplitPreview.app"; mkdir -p "$APP"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m); [[ "$ARCH" == arm64 ]] && TARGET=arm64-apple-ios16.0-simulator || TARGET=x86_64-apple-ios16.0-simulator
xcrun --sdk iphonesimulator clang -target "$TARGET" -isysroot "$SDK" -fobjc-arc -framework UIKit -framework Foundation -framework QuartzCore main.m -o "$APP/CarPlaySplitPreview"
cp Info.plist "$APP/Info.plist"
codesign --force --sign - "$APP"
UDID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); xs=[x for v in d["devices"].values() for x in v if "iPhone" in x["name"] and x.get("isAvailable")]; print(xs[0]["udid"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
mkdir -p "$OUT/screenshots"
xcrun simctl launch --terminate-running-process "$UDID" com.chuong.carplaysplit.preview
sleep 3
xcrun simctl io "$UDID" screenshot "$OUT/screenshots/duodash-split-427x240.png"
xcrun simctl terminate "$UDID" com.chuong.carplaysplit.preview || true
xcrun simctl launch "$UDID" com.chuong.carplaysplit.preview --fullscreen
sleep 3
xcrun simctl io "$UDID" screenshot "$OUT/screenshots/duodash-fullscreen-427x240.png"
file "$OUT/screenshots/"*.png
