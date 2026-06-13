#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
ENTITLEMENTS="$ROOT/Zehan/Zirn.adhoc.entitlements"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  exit 1
fi

strip_release_metadata() {
  xattr -cr "$APP_PATH"
  find "$APP_PATH" -print0 | xargs -0 xattr -c 2>/dev/null || true
  rm -f "$APP_PATH/Contents/embedded.provisionprofile"
}

sign_release_app() {
  local identity="$1"

  strip_release_metadata

  # Ad-hoc signing cannot use hardened runtime; nested Sparkle must match the main binary.
  local sparkle_b="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
  if [[ -d "$sparkle_b" ]]; then
    for bin in \
      "$sparkle_b/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
      "$sparkle_b/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
      "$sparkle_b/Autoupdate" \
      "$sparkle_b/Updater.app/Contents/MacOS/Updater" \
      "$sparkle_b/Sparkle"
    do
      if [[ -f "$bin" ]]; then
        codesign --force --sign "$identity" "$bin"
      fi
    done
    codesign --force --sign "$identity" "$sparkle_b/Updater.app"
    codesign --force --sign "$identity" "$sparkle_b"
    codesign --force --sign "$identity" "$APP_PATH/Contents/Frameworks/Sparkle.framework"
  fi

  codesign --force --sign "$identity" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

  strip_release_metadata

  if ! codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo "Strict signature verification failed."
    codesign --verify --deep --strict --verbose=4 "$APP_PATH" 2>&1 || true
    exit 1
  fi

  echo "Signed: $APP_PATH"
}

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "CI build: ad-hoc signing app for Sparkle packaging."
  strip_release_metadata
  codesign --force --deep --sign - "$APP_PATH"
  strip_release_metadata
  codesign --verify --deep --strict "$APP_PATH"
  exit 0
fi

echo "Release signing: ad-hoc (right-click → Open once on first launch)."
sign_release_app "$SIGN_IDENTITY"

spctl -a -t exec -vv "$APP_PATH" 2>&1 || true
