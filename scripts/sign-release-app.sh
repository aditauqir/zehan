#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/Zirn.app}"
ENTITLEMENTS="$ROOT/Zehan/Zirn.release.entitlements"
ADHOC_ENTITLEMENTS="$ROOT/Zehan/Zirn.adhoc.entitlements"
FIND_PROFILE="$ROOT/scripts/find-developer-id-profile.py"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
ALLOW_ADHOC_RELEASE="${ALLOW_ADHOC_RELEASE:-0}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"

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
}

sign_path() {
  local target="$1"
  shift
  xattr -cr "$target" 2>/dev/null || true
  codesign "$@" "$target"
}

sign_release_app() {
  local identity="$1"

  strip_release_metadata

  if [[ "$identity" == "-" ]]; then
    adhoc_sign_release_app "$identity"
  elif release_app_is_developer_id_signed; then
    echo "Keeping existing Developer ID signature."
  else
    developer_id_sign_release_app "$identity"
  fi

  strip_release_metadata

  if ! codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo "Strict signature verification failed."
    codesign --verify --deep --strict --verbose=4 "$APP_PATH" 2>&1 || true
    exit 1
  fi

  verify_release_launch_entitlements

  echo "Release app ready: $APP_PATH"
}

release_app_is_developer_id_signed() {
  codesign -dvvv "$APP_PATH" 2>&1 | grep -q "Authority=Developer ID Application:"
}

embed_developer_id_provision_profile() {
  local profile="$1"
  mkdir -p "$APP_PATH/Contents"
  cp "$profile" "$APP_PATH/Contents/embedded.provisionprofile"
  echo "Embedded provisioning profile: $(basename "$profile")"
}

find_developer_id_provision_profile() {
  if [[ -n "$PROVISIONING_PROFILE" ]]; then
    if [[ -f "$PROVISIONING_PROFILE" ]]; then
      echo "$PROVISIONING_PROFILE"
      return 0
    fi
    echo "PROVISIONING_PROFILE not found: $PROVISIONING_PROFILE" >&2
    return 1
  fi

  if [[ ! -x "$FIND_PROFILE" ]]; then
    chmod +x "$FIND_PROFILE"
  fi

  "$FIND_PROFILE"
}

developer_id_sign_release_app() {
  local identity="$1"
  local profile
  local signing_args=(--force --sign "$identity" --timestamp --options runtime)

  if ! profile="$(find_developer_id_provision_profile)"; then
    cat >&2 <<'EOF'
Missing Developer ID Application provisioning profile for noortech.Zirn.

Create one in Apple Developer → Profiles → + → Developer ID Application,
select App ID noortech.Zirn (Keychain Sharing enabled), and your Developer ID
certificate. Download it, then in Xcode open Settings → Accounts → Download
Manual Profiles.

Or set PROVISIONING_PROFILE to the downloaded .provisionprofile path.
EOF
    exit 1
  fi

  embed_developer_id_provision_profile "$profile"
  resign_sparkle_binaries "$identity" "${signing_args[@]}"
  codesign "${signing_args[@]}" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"
}

adhoc_sign_release_app() {
  local identity="$1"
  local signing_args=(--force --sign "$identity")

  resign_sparkle_binaries "$identity" "${signing_args[@]}"
  codesign "${signing_args[@]}" \
    --entitlements "$ADHOC_ENTITLEMENTS" \
    "$APP_PATH"
}

resign_sparkle_binaries() {
  local identity="$1"
  shift
  local signing_args=("$@")

  local sparkle_b="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
  [[ -d "$sparkle_b" ]] || return 0

  for bin in \
    "$sparkle_b/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
    "$sparkle_b/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
    "$sparkle_b/Autoupdate" \
    "$sparkle_b/Updater.app/Contents/MacOS/Updater" \
    "$sparkle_b/Sparkle"
  do
    if [[ -f "$bin" ]]; then
      sign_path "$bin" "${signing_args[@]}"
    fi
  done
  sign_path "$sparkle_b/Updater.app" "${signing_args[@]}"
  sign_path "$sparkle_b" "${signing_args[@]}"
  sign_path "$APP_PATH/Contents/Frameworks/Sparkle.framework" "${signing_args[@]}"
}

verify_release_launch_entitlements() {
  local embedded
  embedded="$(codesign -d --entitlements - "$APP_PATH" 2>/dev/null || true)"

  if grep -q 'keychain-access-groups' <<<"$embedded"; then
    if [[ ! -f "$APP_PATH/Contents/embedded.provisionprofile" ]]; then
      cat >&2 <<'EOF'
ERROR: Release build claims keychain-access-groups but has no embedded.provisionprofile.

On macOS 26 the app will fail to launch. Embed a Developer ID Application
provisioning profile before shipping.
EOF
      exit 1
    fi
    return 0
  fi

  if [[ -f "$APP_PATH/Contents/embedded.provisionprofile" ]]; then
    echo "Warning: embedded.provisionprofile present but keychain entitlement missing."
  fi
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
