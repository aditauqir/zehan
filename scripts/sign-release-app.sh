#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
ENTITLEMENTS="$ROOT/Zehan/Zirn.entitlements"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  exit 1
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "CI build: ad-hoc signing app for Sparkle packaging."
  xattr -cr "$APP_PATH"
  codesign --force --deep --sign - "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
  exit 0
fi

IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
if [[ -z "$IDENTITY" ]]; then
  echo "No Apple Development signing identity found in Keychain."
  echo "Open Xcode → Settings → Accounts and download your signing certificate."
  exit 1
fi

echo "Signing release app with: $IDENTITY"
xattr -cr "$APP_PATH"

sign_if_mach_o() {
  local target="$1"
  if file "$target" | grep -q "Mach-O"; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$target"
  fi
}

while IFS= read -r -d '' helper; do
  sign_if_mach_o "$helper"
done < <(find "$APP_PATH/Contents" -type f \( -path "*/MacOS/*" -o -path "*/Frameworks/*" -o -path "*/Sparkle.framework/*" -o -path "*/XPCServices/*" -o -path "*/Helpers/*" \) -print0)

codesign --force --options runtime --timestamp \
  --sign "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -t exec -vv "$APP_PATH" 2>&1 || true
echo "Signed: $APP_PATH"
