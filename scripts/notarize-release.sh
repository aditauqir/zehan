#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_PATH="${1:-}"

usage() {
  cat <<'EOF'
Usage: scripts/notarize-release.sh <path-to-app-or-dmg>

Credentials, in priority order:
  NOTARYTOOL_PROFILE=<keychain-profile>
  APP_STORE_CONNECT_KEY_PATH=AuthKey_XXXX.p8 APP_STORE_CONNECT_KEY_ID=... APP_STORE_CONNECT_ISSUER_ID=...
  APPLE_ID=... APP_SPECIFIC_PASSWORD=... APPLE_TEAM_ID=...
EOF
}

if [[ -z "$TARGET_PATH" ]]; then
  usage
  exit 1
fi

if [[ ! -e "$TARGET_PATH" ]]; then
  echo "Missing notarization target: $TARGET_PATH"
  exit 1
fi

notary_args=()
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  notary_args+=(--keychain-profile "$NOTARYTOOL_PROFILE")
elif [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  notary_args+=(
    --key "$APP_STORE_CONNECT_KEY_PATH"
    --key-id "$APP_STORE_CONNECT_KEY_ID"
    --issuer "$APP_STORE_CONNECT_ISSUER_ID"
  )
elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  notary_args+=(
    --apple-id "$APPLE_ID"
    --password "$APP_SPECIFIC_PASSWORD"
    --team-id "$APPLE_TEAM_ID"
  )
else
  echo "Missing notarization credentials."
  usage
  exit 1
fi

SUBMIT_PATH="$TARGET_PATH"
TEMP_ZIP=""
cleanup() {
  if [[ -n "$TEMP_ZIP" ]]; then
    rm -f "$TEMP_ZIP"
  fi
}
trap cleanup EXIT

if [[ -d "$TARGET_PATH" && "$TARGET_PATH" == *.app ]]; then
  TEMP_ZIP="$(mktemp "/tmp/zirn-notary.XXXXXX.zip")"
  ditto -c -k --keepParent "$TARGET_PATH" "$TEMP_ZIP"
  SUBMIT_PATH="$TEMP_ZIP"
fi

echo "Submitting for notarization: $TARGET_PATH"
xcrun notarytool submit "$SUBMIT_PATH" "${notary_args[@]}" --wait

echo "Stapling notarization ticket: $TARGET_PATH"
xcrun stapler staple "$TARGET_PATH"
xcrun stapler validate "$TARGET_PATH"

echo "Notarized: $TARGET_PATH"
