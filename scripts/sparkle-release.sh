#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/build/Zirn.app/Contents/Info.plist" 2>/dev/null || true)"
fi
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/sparkle-release.sh <version>"
  echo "Build Zirn.app to build/Zirn.app first, or pass a version after exporting the app."
  exit 1
fi

APP_PATH="$ROOT/build/Zirn.app"
ZIP_PATH="$ROOT/dist/Zirn-${VERSION}.zip"
APPCAST_PATH="$ROOT/Sparkle/appcast.xml"
SPARKLE_TOOLS="$ROOT/.sparkle-tools"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH — run scripts/build-release.sh first."
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]]; then
  echo "Downloading Sparkle release tools..."
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/sparkle-2.6.4.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS" --strip-components=1
fi

if [[ -z "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  if [[ -f "$HOME/.sparkle_eddsa_private_key" ]]; then
    export SPARKLE_EDDSA_PRIVATE_KEY="$(cat "$HOME/.sparkle_eddsa_private_key")"
  else
    echo "Set SPARKLE_EDDSA_PRIVATE_KEY or save the private key to ~/.sparkle_eddsa_private_key"
    echo "Generate keys with: $SPARKLE_TOOLS/bin/generate_keys"
    exit 1
  fi
fi

SIGNATURE="$("$SPARKLE_TOOLS/bin/sign_update" "$ZIP_PATH" -f "$SPARKLE_EDDSA_PRIVATE_KEY")"
FILE_SIZE="$(stat -f%z "$ZIP_PATH")"

echo "Release artifact: $ZIP_PATH"
echo "EdDSA signature: $SIGNATURE"
echo "File size: $FILE_SIZE"
echo
echo "Upload $ZIP_PATH to GitHub Releases as Zirn-${VERSION}.zip, then update Sparkle/appcast.xml enclosure length/signature if needed."
echo "Or run: $SPARKLE_TOOLS/bin/generate_appcast \"$ROOT/dist\" --download-url-prefix \"https://github.com/aditauqir/zehan/releases/download/v${VERSION}/\""
