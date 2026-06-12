#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="/tmp/ZehanReleaseDerivedData"

rm -rf "$BUILD_DIR/Zirn.app"
mkdir -p "$BUILD_DIR"

cd "$ROOT"
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  clean build

cp -R "$DERIVED_DATA/Build/Products/Release/Zirn.app" "$BUILD_DIR/Zirn.app"
echo "Built: $BUILD_DIR/Zirn.app"

"$(dirname "$0")/create-dmg.sh" "$BUILD_DIR/Zirn.app"
