#!/usr/bin/env bash
# Wait for an Apple notary submission to finish, then complete DMG + Sparkle OTA release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-ZirnNotary}"
RELEASE_APP="/tmp/ZirnReleaseStage/Zirn.app"
POLL_SECONDS="${POLL_SECONDS:-30}"
MAX_WAIT_HOURS="${MAX_WAIT_HOURS:-12}"

if [[ ! -d "$RELEASE_APP" ]]; then
  echo "Missing signed app: $RELEASE_APP"
  echo "Run scripts/build-release.sh first."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RELEASE_APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$RELEASE_APP/Contents/Info.plist")"

poll_all_submissions() {
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>/dev/null \
    | awk '/^    id: / { print $2 }'
}

wait_for_acceptance() {
  local ids=()
  if [[ -n "${NOTARY_SUBMISSION_ID:-}" ]]; then
    ids=("$NOTARY_SUBMISSION_ID")
  else
    ids=()
    while IFS= read -r id; do
      [[ -n "$id" ]] && ids+=("$id")
    done < <(poll_all_submissions)
  fi

  if ((${#ids[@]} == 0)); then
    echo "No notary submission ids found."
    exit 1
  fi

  echo "Release: Zirn ${VERSION} (build ${BUILD})"
  echo "Poll every ${POLL_SECONDS}s (max ${MAX_WAIT_HOURS}h)"
  echo "Watching submissions: ${ids[*]}"

  local deadline=$(( $(date +%s) + MAX_WAIT_HOURS * 3600 ))
  while [[ $(date +%s) -lt $deadline ]]; do
    for SUBMISSION_ID in "${ids[@]}"; do
      status="$(xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" 2>/dev/null | awk '/status:/ {print $2}')"
      case "$status" in
        Accepted)
          echo "Notarization accepted: $SUBMISSION_ID"
          return 0
          ;;
        Invalid|Rejected)
          echo "Submission $SUBMISSION_ID failed ($status)."
          xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
          ;;
        In|In\ Progress)
          echo "$(date '+%H:%M:%S') — $SUBMISSION_ID: In Progress"
          ;;
        *)
          echo "$(date '+%H:%M:%S') — $SUBMISSION_ID: ${status:-unknown}"
          ;;
      esac
    done
    sleep "$POLL_SECONDS"
  done

  echo "Timed out after ${MAX_WAIT_HOURS}h."
  echo "Check agreements at developer.apple.com and Apple System Status."
  exit 1
}

wait_for_acceptance

echo "Stapling app ticket…"
xcrun stapler staple "$RELEASE_APP"
xcrun stapler validate "$RELEASE_APP"

mkdir -p build
ditto --norsrc --noextattr "$RELEASE_APP" build/Zirn.app

echo "Creating installer DMG…"
chmod +x scripts/create-dmg.sh scripts/notarize-release.sh scripts/sparkle-release.sh
scripts/create-dmg.sh "$RELEASE_APP"

DMG_PATH="dist/Zirn-${VERSION}.dmg"
echo "Notarizing DMG…"
scripts/notarize-release.sh "$DMG_PATH"

echo "Generating Sparkle OTA artifacts…"
scripts/sparkle-release.sh "${VERSION}"

echo
echo "Release artifacts ready:"
echo "  $DMG_PATH"
echo "  dist/Zirn-${VERSION}.zip"
echo "  Sparkle/appcast.xml"
echo
spctl -a -t exec -vv "$RELEASE_APP" 2>&1 || true
