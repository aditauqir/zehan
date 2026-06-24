#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="/tmp/ZehanReleaseDerivedData"

rm -rf "$BUILD_DIR/Zirn.app"
mkdir -p "$BUILD_DIR"

cd "$ROOT"

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if [[ -z "${SIGN_IDENTITY:-}" || -z "${PROVISIONING_PROFILE:-}" ]]; then
    cat >&2 <<'EOF'
GitHub Actions release builds require Developer ID signing secrets.

Run scripts/import-signing-certificate.sh first, or configure:
  MACOS_CERTIFICATE
  MACOS_CERTIFICATE_PASSWORD
  KEYCHAIN_PASSWORD
  PROVISIONING_PROFILE_BASE64
EOF
    exit 1
  fi
  echo "CI release build: signing with $SIGN_IDENTITY"
fi

xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -resolvePackageDependencies

BUILD_ARGS=(
  -project Zehan.xcodeproj
  -scheme Zehan
  -configuration Release
  -derivedDataPath "$DERIVED_DATA"
  clean build
)
xcodebuild "${BUILD_ARGS[@]}"

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/Zirn.app"
RELEASE_STAGE="/tmp/ZirnReleaseStage/Zirn.app"
chmod +x scripts/sign-release-app.sh

rm -rf /tmp/ZirnReleaseStage "$BUILD_DIR/Zirn.app"
mkdir -p /tmp/ZirnReleaseStage "$BUILD_DIR"
ditto --norsrc --noextattr "$APP_BUNDLE" "$RELEASE_STAGE"
xattr -cr "$RELEASE_STAGE"
# Sign outside the iCloud nosync workspace; codesign rejects Sparkle detritus there.
scripts/sign-release-app.sh "$RELEASE_STAGE"
ditto --norsrc --noextattr "$RELEASE_STAGE" "$BUILD_DIR/Zirn.app"
echo "Built: $BUILD_DIR/Zirn.app"
