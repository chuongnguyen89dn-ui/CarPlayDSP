#!/bin/bash
set -euo pipefail
SRC="${1:-$RUNNER_TEMP/showcarplay}"
OUT="${2:-packages}"
PKG="$RUNNER_TEMP/showcase-rootless"
rm -rf "$SRC" "$PKG"
git clone --depth=1 --branch fix/bluetooth-clean-shutdown https://github.com/chuongnguyen89dn-ui/showcarplay.git "$SRC"
mkdir -p "$OUT" "$PKG/DEBIAN" "$PKG/var/jb/Applications/Showcase.app"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
# Build the main Showcase app first. The upstream repository does not contain
# libBTstack.dylib, so do not manufacture or silently substitute that binary.
xcrun --sdk iphoneos clang -arch arm64 -fobjc-arc -DSHOWCASE_ROOTLESS=1 -miphoneos-version-min=12.0 -isysroot "$SDK" \
  -o "$PKG/var/jb/Applications/Showcase.app/Showcase" "$SRC/source/Showcase.m" \
  -framework UIKit -framework AVFoundation -framework AudioToolbox \
  -framework CoreMedia -framework Foundation -framework Security \
  -Wl,-undefined,dynamic_lookup
ldid -S"$SRC/source/ent_app.xml" "$PKG/var/jb/Applications/Showcase.app/Showcase"
cp "$SRC/source/Info.plist" "$PKG/var/jb/Applications/Showcase.app/Info.plist"
if [ -d "$SRC/icon/generated" ]; then cp "$SRC/icon/generated/"*.png "$PKG/var/jb/Applications/Showcase.app/" 2>/dev/null || true; fi
cp "$SRC/packaging/control-rootless/control" "$PKG/DEBIAN/control"
VER="0.0.${GITHUB_RUN_NUMBER:-1}"
sed -i '' "s/^Version:.*/Version: $VER/" "$PKG/DEBIAN/control"
# This CI package intentionally excludes CarDisplaySim/BTdaemon until the real
# BTstack dylib is restored; it lets us validate/install the Showcase app via Sileo.
for f in postinst prerm postrm; do
  if [ -f "$SRC/packaging/control-rootless/$f" ]; then cp "$SRC/packaging/control-rootless/$f" "$PKG/DEBIAN/$f"; chmod 0755 "$PKG/DEBIAN/$f"; fi
done
chmod 0755 "$PKG/var/jb/Applications/Showcase.app/Showcase"
dpkg-deb --build --root-owner-group "$PKG" "$OUT/showcase_${VER}_iphoneos-arm64.deb"
dpkg-deb -I "$OUT/showcase_${VER}_iphoneos-arm64.deb"
dpkg-deb -c "$OUT/showcase_${VER}_iphoneos-arm64.deb"
