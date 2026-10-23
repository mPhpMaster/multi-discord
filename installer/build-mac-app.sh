#!/usr/bin/env bash
# ============================================================
#  Builds "Discord Multi.app" - the macOS app (a window around discord-multi.sh).
#  Needs macOS (osacompile, sips, iconutil, codesign).
#
#  Usage: installer/build-mac-app.sh [output-folder]     (default: dist)
# ============================================================

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC/dist}"
APP="$OUT/Discord Multi.app"
VERSION="$(bash "$SRC/discord-multi.sh" version)"

mkdir -p "$OUT"
rm -rf "$APP"

# A stay-open applet: its run handler opens the window and the applet keeps the event loop going
osacompile -l JavaScript -s -o "$APP" "$SRC/discord-multi-mac.js"

RES="$APP/Contents/Resources"
cp "$SRC/discord-multi.sh" "$SRC/discord-multi-mac.js" "$RES/"
mkdir -p "$RES/assets"
cp "$SRC/assets/logo.png" "$RES/assets/"

# App icon from the logo
ICONSET="$(mktemp -d)/applet.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$SRC/assets/logo.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$SRC/assets/logo.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RES/applet.icns"
# Newer macOS takes the icon from Assets.car (CFBundleIconName) before applet.icns
rm -f "$RES/Assets.car"
rm -rf "$(dirname "$ICONSET")"

PLIST="$APP/Contents/Info.plist"
plutil -remove CFBundleIconName "$PLIST" 2>/dev/null || true
plutil -replace CFBundleName -string "Discord Multi" "$PLIST"
plutil -replace CFBundleIdentifier -string "com.mphpmaster.discordmulti" "$PLIST"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -replace CFBundleVersion -string "$VERSION" "$PLIST"
plutil -replace NSHumanReadableCopyright -string "MIT License - not affiliated with Discord Inc." "$PLIST"

# Adding files broke the applet's signature: sign it again (ad-hoc, so it runs on Apple silicon)
codesign --force --deep --sign - "$APP"

echo "Built: $APP ($VERSION)"
