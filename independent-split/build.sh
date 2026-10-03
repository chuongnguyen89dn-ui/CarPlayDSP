#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_DIR="${CPS_BUILD_DIR:-$PWD/build}"
STAGING="$BUILD_DIR/stage"
LDID_BIN="${CPS_LDID:-ldid}"
mkdir -p "$BUILD_DIR" packages
cc -Wall -Wextra -Werror tests/layouts.c -lm -o "$BUILD_DIR/layout-tests"
"$BUILD_DIR/layout-tests"
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
"${CC[@]}" "${COMMON[@]}" app/main.m shared/CPSSettings.m -o "$APP/CarPlaySplit"
PREF="$STAGING/var/jb/Library/PreferenceBundles/CarPlaySplitPrefs.bundle"
mkdir -p "$PREF" "$STAGING/var/jb/Library/PreferenceLoader/Preferences"
"${CC[@]}" "${COMMON[@]}" -bundle -Wl,-undefined,dynamic_lookup preferences/Entry.m shared/CPSSettings.m -o "$PREF/CarPlaySplitPrefs"
cp preferences/Info.plist "$PREF/"
if [[ "$(uname -s)" == Darwin ]]; then
    sips -z 29 29 app/AppIcon60x60@2x.png --out "$PREF/Icon.png" >/dev/null
    sips -z 58 58 app/AppIcon60x60@2x.png --out "$PREF/Icon@2x.png" >/dev/null
    sips -z 87 87 app/AppIcon60x60@3x.png --out "$PREF/Icon@3x.png" >/dev/null
else
    python3 - "$PREF" <<'PYICON'
import sys
from pathlib import Path
from PIL import Image
out = Path(sys.argv[1])
for scale in (1, 2, 3):
    source = 'app/AppIcon60x60@3x.png' if scale == 3 else 'app/AppIcon60x60@2x.png'
    suffix = '' if scale == 1 else f'@{scale}x'
    with Image.open(source) as image:
        image.resize((29 * scale, 29 * scale), Image.Resampling.LANCZOS).save(out / f'Icon{suffix}.png')
PYICON
fi
chmod 0644 "$PREF/"*.png
cp preferences/Loader.plist "$STAGING/var/jb/Library/PreferenceLoader/Preferences/CarPlaySplitPrefs.plist"
"$LDID_BIN" -S "$PREF/CarPlaySplitPrefs"
chmod 0755 "$PREF/CarPlaySplitPrefs"
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

# Build Showcase into the same package directory so the existing workflow copies it into Sileo.
if [[ "$(uname -s)" == Darwin ]]; then
    bash ../showcase/build.sh "${RUNNER_TEMP:-/tmp}/showcarplay" "$PWD/packages"
fi
