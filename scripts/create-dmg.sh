#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
DIST_DIR="$ROOT/dist"
BACKGROUND="$ROOT/packaging/background.png"
BACKGROUND_2X="$ROOT/packaging/background@2x.png"
INSTALL_README="$ROOT/packaging/README.txt"
STAGING="$ROOT/build/dmg-staging"
DS_STORE_SCRIPT="$ROOT/scripts/generate-dmg-ds-store.py"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Run scripts/build-release.sh first."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_NAME="Zirn-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST_DIR"
ditto --norsrc --noextattr "$APP_PATH" "$STAGING/Zirn.app"
xattr -cr "$STAGING/Zirn.app"
ln -sf /Applications "$STAGING/Applications"
cp "$INSTALL_README" "$STAGING/README.txt"
rm -f "$DMG_PATH"

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "CI build: creating a basic installer DMG (Finder background layout skipped)."
  hdiutil create \
    -volname "Zirn ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
  rm -rf "$STAGING"
  echo "Created: $DMG_PATH"
  exit 0
fi

if [[ ! -f "$BACKGROUND" || ! -f "$BACKGROUND_2X" ]]; then
  echo "Missing DMG backgrounds in packaging/ (background.png and background@2x.png)."
  exit 1
fi

if ! python3 -c "from ds_store import DSStore; from mac_alias import Alias" 2>/dev/null; then
  echo "Missing Python deps for DMG layout. Install with:"
  echo "  python3 -m pip install ds-store mac-alias"
  exit 1
fi

RW_DMG="$DIST_DIR/rw.${DMG_NAME}.sparseimage"
DEV=""
MOUNT_DIR=""

cleanup() {
  if [[ -n "$DEV" ]]; then
    hdiutil detach "$DEV" -force >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# background@2x is 1024×768 → 512×384 logical window.
WINW=512
WINH=384

WINX="$(osascript -e "tell application \"Finder\" to set s to bounds of window of desktop
set w to item 3 of s
set h to item 4 of s
return round ((w - ${WINW}) / 2)" 2>/dev/null | tr -d ',' || echo 200)"
WINY="$(osascript -e "tell application \"Finder\" to set s to bounds of window of desktop
set w to item 3 of s
set h to item 4 of s
return round ((h - ${WINH}) / 2)" 2>/dev/null | tr -d ',' || echo 120)"

rm -f "$RW_DMG"

STAGING_MB="$(du -sm "$STAGING" | awk '{print $1}')"
DMG_MB=$((STAGING_MB + 50))

hdiutil create -size "${DMG_MB}m" -type SPARSE -volname "Zirn ${VERSION}" -fs HFS+ "${DIST_DIR}/rw.${DMG_NAME}" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -nobrowse -mountrandom /tmp "$RW_DMG")"
DEV="$(echo "$MOUNT_OUTPUT" | awk '/^\/dev\/disk[0-9]+s[0-9]+/ && /Apple_HFS/ {print $1; exit}')"
MOUNT_DIR="$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {print $3; exit}')"

if [[ -z "$DEV" || -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Failed to mount DMG for layout."
  echo "$MOUNT_OUTPUT"
  exit 1
fi

ditto --norsrc --noextattr "$STAGING/" "$MOUNT_DIR/"

mkdir -p "$MOUNT_DIR/.background"
cp "$BACKGROUND" "$MOUNT_DIR/.background/background.png"
cp "$BACKGROUND_2X" "$MOUNT_DIR/.background/background@2x.png"

if [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
  cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$MOUNT_DIR"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
  fi
fi

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$MOUNT_DIR/.background"
fi

python3 "$DS_STORE_SCRIPT" "$MOUNT_DIR" \
  --window-x "$WINX" \
  --window-y "$WINY" \
  --window-width "$WINW" \
  --window-height "$WINH"

if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "Failed to write .DS_Store; DMG background will not appear."
  exit 1
fi
echo "Saved Finder layout to .DS_Store"

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
rm -rf "$MOUNT_DIR/.fseventsd" 2>/dev/null || true

# Finder layout (SetFile, .DS_Store) can add detritus that breaks code signing.
xattr -cr "$MOUNT_DIR/Zirn.app"
if ! codesign --verify --deep --strict "$MOUNT_DIR/Zirn.app" 2>/dev/null; then
  echo "DMG app failed code signature verification after layout."
  codesign --verify --deep --strict --verbose=4 "$MOUNT_DIR/Zirn.app" 2>&1 || true
  exit 1
fi

sync

hdiutil detach "$DEV" >/dev/null
DEV=""
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGING"

echo "Created: $DMG_PATH"
