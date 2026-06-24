#!/usr/bin/env bash
set -euo pipefail

required_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "::error::$name secret is not configured."
    exit 1
  fi
}

required_env MACOS_CERTIFICATE
required_env MACOS_CERTIFICATE_PASSWORD
required_env KEYCHAIN_PASSWORD
required_env PROVISIONING_PROFILE_BASE64

RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
CERT_PATH="$RUNNER_TEMP/zirn-developer-id.p12"
PROFILE_PATH="$RUNNER_TEMP/ZirnDeveloperID.provisionprofile"
PROFILE_PLIST="$RUNNER_TEMP/ZirnDeveloperIDProfile.plist"
KEYCHAIN_PATH="$RUNNER_TEMP/zirn-signing.keychain-db"

printf '%s' "$MACOS_CERTIFICATE" | base64 --decode > "$CERT_PATH"
printf '%s' "$PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
INSTALLED_PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$INSTALLED_PROFILE_DIR"
cp "$PROFILE_PATH" "$INSTALLED_PROFILE_DIR/$PROFILE_UUID.provisionprofile"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" \
  -P "$MACOS_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"

security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/[ "]//g')

SIGN_IDENTITY="$(
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' \
    | head -n 1
)"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "::error::No Developer ID Application signing identity found in imported certificate."
  exit 1
fi

{
  echo "SIGN_IDENTITY=$SIGN_IDENTITY"
  echo "PROVISIONING_PROFILE=$PROFILE_PATH"
  echo "SIGNING_KEYCHAIN_PATH=$KEYCHAIN_PATH"
} >> "${GITHUB_ENV:-/dev/null}"

echo "Imported signing identity: $SIGN_IDENTITY"
echo "Provisioning profile: $PROFILE_PATH"
