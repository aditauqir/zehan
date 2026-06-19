#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x scripts/build-release.sh scripts/create-dmg.sh scripts/sparkle-release.sh
chmod +x scripts/notarize-release.sh

echo "Building signed Release app…"
scripts/build-release.sh

RELEASE_APP="/tmp/ZirnReleaseStage/Zirn.app"
if [[ ! -d "$RELEASE_APP" ]]; then
  echo "Missing signed release app: $RELEASE_APP"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RELEASE_APP/Contents/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$RELEASE_APP/Contents/Info.plist")"

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
  echo "Notarizing Release app…"
  scripts/notarize-release.sh "$RELEASE_APP"
  ditto --norsrc --noextattr "$RELEASE_APP" build/Zirn.app
else
  echo "Skipping notarization because SKIP_NOTARIZATION=1 (not for public downloads)."
fi

echo "Packaging Zirn ${VERSION} (${BUILD})…"
scripts/create-dmg.sh "$RELEASE_APP"

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
  echo "Notarizing installer DMG…"
  scripts/notarize-release.sh "dist/Zirn-${VERSION}.dmg"
fi

scripts/sparkle-release.sh "${VERSION}"

echo
echo "OTA release ready:"
echo "  dist/Zirn-${VERSION}.dmg   — website download"
echo "  dist/Zirn-${VERSION}.zip   — Sparkle OTA"
echo "  Sparkle/appcast.xml        — update feed"
echo
echo "Upload the .dmg and .zip to GitHub Release v${VERSION}, then commit and push Sparkle/appcast.xml."
