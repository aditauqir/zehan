#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="/tmp/ZehanReleaseDerivedData"

rm -rf "$BUILD_DIR/Zirn.app"
mkdir -p "$BUILD_DIR"

cd "$ROOT"

XCODE_FLAGS=()
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "CI build: skipping code signing (no Apple certificate on runner)."
  XCODE_FLAGS+=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    "CODE_SIGN_IDENTITY=-"
  )
fi

xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -resolvePackageDependencies \
  clean build \
  "${XCODE_FLAGS[@]}"

cp -R "$DERIVED_DATA/Build/Products/Release/Zirn.app" "$BUILD_DIR/Zirn.app"
echo "Built: $BUILD_DIR/Zirn.app"
