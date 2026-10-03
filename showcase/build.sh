#!/bin/bash
set -euo pipefail
SRC="${1:-$RUNNER_TEMP/showcarplay}"
OUT="${2:-packages}"
PKG="$RUNNER_TEMP/showcase-rootless"
rm -rf "$SRC" "$PKG"
git clone --depth=1 --branch fix/bluetooth-clean-shutdown https://github.com/chuongnguyen89dn-ui/showcarplay.git "$SRC"
mkdir -p "$OUT" "$PKG/DEBIAN" "$PKG/var/jb/usr/local/bin" "$PKG/var/jb/usr/lib"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -arch arm64 -fobjc-arc -DSHOWCASE_ROOTLESS=1 -miphoneos-version-min=12.0 -isysroot "$SDK" -o "$SRC/carplay_bt" "$SRC/source/carplay_bt.m" "$SRC/packaging/payload/usr/lib/libBTstack.dylib" -framework Foundation -framework Security -Wl,-undefined,dynamic_lookup
ldid -S "$SRC/carplay_bt"
cp "$SRC/carplay_bt" "$PKG/var/jb/usr/local/bin/"
cp "$SRC/packaging/payload/usr/lib/libBTstack.dylib" "$PKG/var/jb/usr/lib/"
cp "$SRC/packaging/control-rootless/control" "$PKG/DEBIAN/control"
VER="0.0.${GITHUB_RUN_NUMBER:-1}"
sed -i '' "s/^Version:.*/Version: $VER/" "$PKG/DEBIAN/control"
for f in postinst prerm postrm; do
  if [ -f "$SRC/packaging/control-rootless/$f" ]; then cp "$SRC/packaging/control-rootless/$f" "$PKG/DEBIAN/$f"; chmod 0755 "$PKG/DEBIAN/$f"; fi
done
chmod 0755 "$PKG/var/jb/usr/local/bin/carplay_bt"
dpkg-deb --build --root-owner-group "$PKG" "$OUT/showcase_${VER}_iphoneos-arm64.deb"
dpkg-deb -I "$OUT/showcase_${VER}_iphoneos-arm64.deb"
