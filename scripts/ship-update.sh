#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x scripts/build-release.sh scripts/create-dmg.sh scripts/sparkle-release.sh

echo "Building signed Release app…"
scripts/build-release.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/Zirn.app/Contents/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' build/Zirn.app/Contents/Info.plist)"

echo "Packaging Zirn ${VERSION} (${BUILD})…"
scripts/create-dmg.sh build/Zirn.app
scripts/sparkle-release.sh "${VERSION}"

echo
echo "OTA release ready:"
echo "  dist/Zirn-${VERSION}.dmg   — website download"
echo "  dist/Zirn-${VERSION}.zip   — Sparkle OTA"
echo "  Sparkle/appcast.xml        — update feed"
echo
echo "Upload the .dmg and .zip to GitHub Release v${VERSION}, then commit and push Sparkle/appcast.xml."
