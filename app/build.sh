#!/bin/bash
set -e
cd "$(dirname "$0")"
APP=NetBanking.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Regenerate the icon if not committed (needs only swift + sips + iconutil).
if [ ! -f AppIcon.icns ]; then
    swift make_icon.swift icon_1024.png
    rm -rf AppIcon.iconset && mkdir -p AppIcon.iconset
    for s in 16 32 64 128 256 512 1024; do
        sips -z $s $s icon_1024.png --out "AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    done
    for s in 16 32 128 256 512; do
        cp "AppIcon.iconset/icon_${s}x${s}.png" "AppIcon.iconset/icon_${s}x${s}@2x.png"
    done
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi
cp AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NetBanking</string>
    <key>CFBundleIdentifier</key><string>local.netbanking.sparkasse-helper</string>
    <key>CFBundleName</key><string>NetBanking</string>
    <key>CFBundleDisplayName</key><string>NetBanking Helper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
swiftc -O -o "$APP/Contents/MacOS/NetBanking" main.swift \
    -framework AppKit -framework WebKit
codesign -s - --force "$APP"

# Package: installs NetBanking.app into /Applications via System Preferences GUI
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/NetBanking.app"
mkdir -p "$(pwd)/dist"
pkgbuild --root "$STAGE" \
         --install-location /Applications \
         --identifier local.netbanking.sparkasse-helper \
         --version 1.0 \
         --no-relocate \
         dist/NetBanking-1.0.pkg 2>&1 | tail -2
echo "Built $(pwd)/$APP and $(pwd)/dist/NetBanking-1.0.pkg"
echo "Note: the app depends on /Users/martin/netbanking-helper (python venv, pkcs11-tool)."