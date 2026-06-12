#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
DIST_DIR="$ROOT/dist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Run scripts/build-release.sh first."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_NAME="Zirn-${VERSION}.dmg"
STAGING="$ROOT/build/dmg-staging"
DMG_PATH="$DIST_DIR/$DMG_NAME"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING/Zirn.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "Zirn" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING"
echo "Created: $DMG_PATH"
