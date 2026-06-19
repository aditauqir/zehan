#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
ENTITLEMENTS="$ROOT/Zehan/Zirn.adhoc.entitlements"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
ALLOW_ADHOC_RELEASE="${ALLOW_ADHOC_RELEASE:-0}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  exit 1
fi

strip_release_metadata() {
  dot_clean -m "$APP_PATH" 2>/dev/null || true
  xattr -cr "$APP_PATH"
  find "$APP_PATH" -print0 | while IFS= read -r -d '' path; do
    xattr -c "$path" 2>/dev/null || true
    xattr -d com.apple.provenance "$path" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$path" 2>/dev/null || true
  done
  rm -f "$APP_PATH/Contents/embedded.provisionprofile"
}

sign_path() {
  local target="$1"
  xattr -cr "$target" 2>/dev/null || true
  codesign "${signing_args[@]}" "$target"
}

sign_release_app() {
  local identity="$1"

  strip_release_metadata

  local signing_args=(--force --sign "$identity")
  if [[ "$identity" != "-" ]]; then
    signing_args+=(--timestamp --options runtime)
  fi

  # Nested Sparkle code must be signed consistently with the main binary.
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
        sign_path "$bin"
      fi
    done
    sign_path "$sparkle_b/Updater.app"
    sign_path "$sparkle_b"
    sign_path "$APP_PATH/Contents/Frameworks/Sparkle.framework"
  fi

  xattr -cr "$APP_PATH" 2>/dev/null || true
  codesign "${signing_args[@]}" \
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

find_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' \
    | head -n 1
}

resolve_sign_identity() {
  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "$SIGN_IDENTITY"
    return
  fi

  local developer_id
  developer_id="$(find_developer_id_identity)"
  if [[ -n "$developer_id" ]]; then
    echo "$developer_id"
    return
  fi

  if [[ "$ALLOW_ADHOC_RELEASE" == "1" ]]; then
    echo "-"
    return
  fi

  cat >&2 <<'EOF'
Missing Developer ID Application signing identity.

Install a "Developer ID Application" certificate or set SIGN_IDENTITY to one.
Set ALLOW_ADHOC_RELEASE=1 only for private local testing; ad-hoc builds trigger
Gatekeeper's "Apple could not verify Zirn is free of malware" warning.
EOF
  exit 1
}

RESOLVED_IDENTITY="$(resolve_sign_identity)"
if [[ "$RESOLVED_IDENTITY" == "-" ]]; then
  echo "Release signing: ad-hoc (private testing only; not for public downloads)."
else
  echo "Release signing: $RESOLVED_IDENTITY"
fi

sign_release_app "$RESOLVED_IDENTITY"

spctl -a -t exec -vv "$APP_PATH" 2>&1 || true
