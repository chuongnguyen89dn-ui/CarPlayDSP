#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_DIR="${CPS_BUILD_DIR:-$PWD/build}"
STAGING="$BUILD_DIR/stage"
LDID_BIN="${CPS_LDID:-ldid}"
mkdir -p "$BUILD_DIR" packages
rm -rf "$STAGING"
mkdir -p "$STAGING/DEBIAN" "$STAGING/var/jb/Applications/CarPlaySplit.app" "$STAGING/var/jb/Library/MobileSubstrate/DynamicLibraries"
APP="$STAGING/var/jb/Applications/CarPlaySplit.app"
DYLIB="$STAGING/var/jb/Library/MobileSubstrate/DynamicLibraries/CarPlaySplit.dylib"
if [[ "$(uname -s)" == Darwin ]]; then
    SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
    CC=(xcrun --sdk iphoneos clang -arch arm64 -arch arm64e -miphoneos-version-min=16.0 -isysroot "$SDK")
else
    : "${CPS_ZIG:?Set CPS_ZIG to the Zig executable}"
    : "${CPS_SDK:?Set CPS_SDK to an iPhoneOS SDK}"
    SDK="$CPS_SDK"
    CC=("$CPS_ZIG" cc -target aarch64-ios.16.0 -isysroot "$SDK" -isystem "$SDK/usr/include" -iframework "$SDK/System/Library/Frameworks" -F"$SDK/System/Library/Frameworks" -L"$SDK/usr/lib")
fi
COMMON=(-Wl,-headerpad,0x1000 -fobjc-arc -fblocks -Os -Wall -Wextra -Wno-unused-parameter -framework Foundation -framework UIKit -framework CoreFoundation -framework CoreGraphics -framework QuartzCore -lobjc)
"${CC[@]}" "${COMMON[@]}" -dynamiclib runtime/CPSRuntime.m -Wl,-install_name,/var/jb/Library/MobileSubstrate/DynamicLibraries/CarPlaySplit.dylib -o "$DYLIB"
"${CC[@]}" "${COMMON[@]}" app/main.m -o "$APP/CarPlaySplit"
cp app/Info.plist app/AppIcon60x60@2x.png app/AppIcon60x60@3x.png "$APP/"
"$LDID_BIN" -S "$DYLIB"
"$LDID_BIN" -Spackaging/entitlements.plist "$APP/CarPlaySplit"
cp packaging/control packaging/postinst packaging/postrm "$STAGING/DEBIAN/"
cp packaging/CarPlaySplit.plist "$STAGING/var/jb/Library/MobileSubstrate/DynamicLibraries/"
chmod 0755 "$STAGING/DEBIAN" "$STAGING/DEBIAN/postinst" "$STAGING/DEBIAN/postrm" "$APP/CarPlaySplit" "$DYLIB"
chmod 0644 "$STAGING/DEBIAN/control" "$APP/Info.plist" "$APP/"*.png "$STAGING/var/jb/Library/MobileSubstrate/DynamicLibraries/CarPlaySplit.plist"
VERSION="$(sed -n 's/^Version: //p' packaging/control)"
OUTPUT="packages/com.chuong.carplaysplit_${VERSION}_iphoneos-arm64.deb"
dpkg-deb --build --root-owner-group "$STAGING" "$OUTPUT"
python3 verify_package.py "$OUTPUT"
