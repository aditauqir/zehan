#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
DIST_DIR="$ROOT/dist"
BACKGROUND="$ROOT/packaging/dmg-background.png"
STAGING="$ROOT/build/dmg-staging"
APPLESCRIPT="$ROOT/scripts/dmg-finder-layout.applescript"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Run scripts/build-release.sh first."
  exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
  echo "Missing DMG background at $BACKGROUND"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_NAME="Zirn-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
RW_DMG="$DIST_DIR/rw.${DMG_NAME}.sparseimage"
DEV=""
MOUNT_DIR=""

cleanup() {
  if [[ -n "$DEV" ]]; then
    hdiutil detach "$DEV" -force >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Background is 1536×1024 (@2x) → 768×512 logical window.
WINW=768
WINH=512

WINX="$(osascript -e "tell application \"Finder\" to set s to bounds of window of desktop
set w to item 3 of s
set h to item 4 of s
return round ((w - ${WINW}) / 2)" | tr -d ',')"
WINY="$(osascript -e "tell application \"Finder\" to set s to bounds of window of desktop
set w to item 3 of s
set h to item 4 of s
return round ((h - ${WINH}) / 2)" | tr -d ',')"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST_DIR"
ditto --norsrc "$APP_PATH" "$STAGING/Zirn.app"
ln -sf /Applications "$STAGING/Applications"

rm -f "$DMG_PATH" "$RW_DMG"

STAGING_MB="$(du -sm "$STAGING" | awk '{print $1}')"
DMG_MB=$((STAGING_MB + 50))

hdiutil create -size "${DMG_MB}m" -type SPARSE -volname "Zirn" -fs HFS+ "${DIST_DIR}/rw.${DMG_NAME}" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -nobrowse -mountrandom /tmp "$RW_DMG")"
DEV="$(echo "$MOUNT_OUTPUT" | awk '/^\/dev\/disk[0-9]+s[0-9]+/ && /Apple_HFS/ {print $1; exit}')"
MOUNT_DIR="$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {print $3; exit}')"
VOLUME_NAME="$(basename "$MOUNT_DIR")"

if [[ -z "$DEV" || -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Failed to mount DMG for layout."
  echo "$MOUNT_OUTPUT"
  exit 1
fi

ditto --norsrc "$STAGING/" "$MOUNT_DIR/"

mkdir -p "$MOUNT_DIR/.background"
cp "$BACKGROUND" "$MOUNT_DIR/.background/dmg-background.png"

if [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
  cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$MOUNT_DIR"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
  fi
fi

sleep 2
osascript "$APPLESCRIPT" "Zirn" "$WINX" "$WINY" "$WINW" "$WINH" "$MOUNT_DIR/.background/dmg-background.png"

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
rm -rf "$MOUNT_DIR/.fseventsd" 2>/dev/null || true
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true

hdiutil detach "$DEV" >/dev/null
DEV=""
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGING"

echo "Created: $DMG_PATH"
