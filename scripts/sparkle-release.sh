#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
APP_PATH="$ROOT/build/Zirn.app"
DIST_DIR="$ROOT/dist"
SPARKLE_TOOLS="${SPARKLE_TOOLS:-/tmp}"

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
fi
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/sparkle-release.sh [version]"
  echo "Run scripts/build-release.sh first."
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH — run scripts/build-release.sh first."
  exit 1
fi

if [[ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]]; then
  echo "Downloading Sparkle release tools..."
  mkdir -p "$SPARKLE_TOOLS/sparkle-tools"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/sparkle-2.6.4.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS/sparkle-tools" --strip-components=1
  SPARKLE_TOOLS="$SPARKLE_TOOLS/sparkle-tools"
fi

APPCAST_DIR="$DIST_DIR/sparkle"
mkdir -p "$APPCAST_DIR"
rm -rf "$APPCAST_DIR"/*
cp "$ROOT/Sparkle/release-notes/${VERSION}.html" "$APPCAST_DIR/" 2>/dev/null || true
cp "$ROOT/dist/Zirn-${VERSION}.html" "$APPCAST_DIR/" 2>/dev/null || true
if [[ ! -f "$APPCAST_DIR/Zirn-${VERSION}.html" ]]; then
  cat > "$APPCAST_DIR/Zirn-${VERSION}.html" <<EOF
<h2>Zirn ${VERSION}</h2>
<ul><li>Update for Zirn ${VERSION}</li></ul>
EOF
fi

ZIP_PATH="$APPCAST_DIR/Zirn-${VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

SIGN_ARGS=("$ZIP_PATH")
if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  SIGN_ARGS+=(-f "$SPARKLE_EDDSA_PRIVATE_KEY")
fi

SIGNATURE="$("$SPARKLE_TOOLS/bin/sign_update" "${SIGN_ARGS[@]}")"
FILE_SIZE="$(stat -f%z "$ZIP_PATH")"

if [[ -f "$ROOT/Sparkle/appcast.xml" ]]; then
  cp "$ROOT/Sparkle/appcast.xml" "$APPCAST_DIR/appcast.xml"
fi

"$SPARKLE_TOOLS/bin/generate_appcast" "$APPCAST_DIR" \
  --download-url-prefix "https://github.com/aditauqir/zehan/releases/download/v${VERSION}/" \
  --embed-release-notes \
  --link "https://github.com/aditauqir/zehan"

cp "$APPCAST_DIR/appcast.xml" "$ROOT/Sparkle/appcast.xml"

# Keep release artifacts at dist root for GitHub Releases upload.
cp "$ZIP_PATH" "$DIST_DIR/Zirn-${VERSION}.zip"

echo "Release artifacts:"
echo "  DMG: $DIST_DIR/Zirn-${VERSION}.dmg"
echo "  ZIP: $DIST_DIR/Zirn-${VERSION}.zip"
echo "  Appcast: $ROOT/Sparkle/appcast.xml"
echo "EdDSA signature: $SIGNATURE"
echo "File size: $FILE_SIZE"
echo
echo "Upload dist/Zirn-${VERSION}.dmg and dist/Zirn-${VERSION}.zip to GitHub Releases for v${VERSION}."
