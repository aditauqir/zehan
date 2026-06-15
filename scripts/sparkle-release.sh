#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
APP_PATH="$ROOT/build/Zirn.app"
DIST_DIR="$ROOT/dist"
SPARKLE_TOOLS="${SPARKLE_TOOLS:-/tmp}"
RELEASE_CODENAME="${RELEASE_CODENAME:-}"

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

# Drop stale local release artifacts from prior builds.
rm -f "$DIST_DIR/Zirn.dmg"
find "$DIST_DIR" -maxdepth 1 -type f \( -name 'Zirn-*.dmg' -o -name 'Zirn-*.zip' -o -name 'Zirn-*.html' \) \
  ! -name "Zirn-${VERSION}.dmg" \
  ! -name "Zirn-${VERSION}.zip" \
  ! -name "Zirn-${VERSION}.html" \
  -delete 2>/dev/null || true

if [[ ! -x "$SPARKLE_TOOLS/bin/generate_appcast" && ! -x "$SPARKLE_TOOLS/bin/sign_update" ]]; then
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
  if [[ -f "$ROOT/PATCH_NOTES.md" ]]; then
    PATCH_NOTES_ARGS=(
      "$VERSION"
      --patch-notes "$ROOT/PATCH_NOTES.md"
      --output "$APPCAST_DIR/Zirn-${VERSION}.html"
    )
    if [[ -n "$RELEASE_CODENAME" ]]; then
      PATCH_NOTES_ARGS+=(--codename "$RELEASE_CODENAME")
    fi
    python3 "$ROOT/scripts/patch-notes-release-html.py" \
      "${PATCH_NOTES_ARGS[@]}" || true
  fi
fi
if [[ ! -f "$APPCAST_DIR/Zirn-${VERSION}.html" ]]; then
  DISPLAY_VERSION="v${VERSION}"
  if [[ -n "$RELEASE_CODENAME" ]]; then
    DISPLAY_VERSION="${DISPLAY_VERSION} (${RELEASE_CODENAME})"
  fi
  cat > "$APPCAST_DIR/Zirn-${VERSION}.html" <<EOF
<h2>Zirn ${DISPLAY_VERSION}</h2>
<ul><li>Update for Zirn ${DISPLAY_VERSION}</li></ul>
EOF
fi

ZIP_PATH="$APPCAST_DIR/Zirn-${VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ -f "$ROOT/Sparkle/appcast.xml" ]]; then
  cp "$ROOT/Sparkle/appcast.xml" "$APPCAST_DIR/appcast.xml"
fi

GENERATE_ARGS=(
  "$APPCAST_DIR"
  --download-url-prefix "https://github.com/aditauqir/zehan/releases/download/v${VERSION}/"
  --embed-release-notes
  --link "https://github.com/aditauqir/zehan"
)

run_generate_appcast() {
  if ! "$SPARKLE_TOOLS/bin/generate_appcast" "${GENERATE_ARGS[@]}" "$@"; then
    echo "generate_appcast failed."
    echo "Check that SPARKLE_EDDSA_PRIVATE_KEY matches SUPublicEDKey in Zirn-Info.plist."
    exit 1
  fi
}

if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  if [[ -f "$SPARKLE_EDDSA_PRIVATE_KEY" ]]; then
    run_generate_appcast --ed-key-file "$SPARKLE_EDDSA_PRIVATE_KEY"
  else
    # GitHub Actions stores the exported EdDSA key as secret text.
    if ! printf '%s\n' "$SPARKLE_EDDSA_PRIVATE_KEY" | "$SPARKLE_TOOLS/bin/generate_appcast" "${GENERATE_ARGS[@]}" --ed-key-file -; then
      echo "generate_appcast failed."
      echo "Check that SPARKLE_EDDSA_PRIVATE_KEY matches SUPublicEDKey in Zirn-Info.plist."
      exit 1
    fi
  fi
elif [[ -f "$HOME/.sparkle_eddsa_private_key" ]]; then
  run_generate_appcast --ed-key-file "$HOME/.sparkle_eddsa_private_key"
else
  echo "Missing SPARKLE_EDDSA_PRIVATE_KEY — cannot sign update."
  exit 1
fi

cp "$APPCAST_DIR/appcast.xml" "$ROOT/Sparkle/appcast.xml"
cp "$ZIP_PATH" "$DIST_DIR/Zirn-${VERSION}.zip"

FILE_SIZE="$(stat -f%z "$ZIP_PATH")"

echo "Release artifacts:"
echo "  DMG: $DIST_DIR/Zirn-${VERSION}.dmg"
echo "  ZIP: $DIST_DIR/Zirn-${VERSION}.zip"
echo "  Appcast: $ROOT/Sparkle/appcast.xml"
echo "File size: $FILE_SIZE"
echo
echo "Upload dist/Zirn-${VERSION}.dmg and dist/Zirn-${VERSION}.zip to GitHub Releases for v${VERSION}."
