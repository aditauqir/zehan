#!/usr/bin/env bash
# Poll Apple notary, finish DMG/OTA, push main, and publish GitHub Release v1.2.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOG="/tmp/zirn-release-deploy.log"

log() {
  echo "$@" | tee -a "$LOG"
}

log "=== Zirn release deploy started $(date) ==="

export NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-ZirnNotary}"
chmod +x scripts/finish-notarized-release.sh

if ! scripts/finish-notarized-release.sh; then
  echo "Release packaging failed. See $LOG"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /tmp/ZirnReleaseStage/Zirn.app/Contents/Info.plist)"

git switch feature 2>/dev/null || true
git merge --ff-only main 2>/dev/null || true
git switch debug 2>/dev/null || true
git merge --ff-only main 2>/dev/null || true
git switch main 2>/dev/null || git switch refs/heads/main

git add Sparkle/appcast.xml README.md Sparkle/INSTALL.md scripts/finish-notarized-release.sh 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "$(cat <<EOF
Publish Sparkle appcast for v${VERSION}.

Ship notarized Zirn ${VERSION} DMG and OTA zip to GitHub Releases.
EOF
)"
fi

git push main main

NOTES="$(python3 - <<'PY' 2>/dev/null || true
import re, pathlib
text = pathlib.Path("PATCH_NOTES.md").read_text()
m = re.search(r"## v1\.2 \(Mizan\)\n\n(.*?)(?:\n## |\Z)", text, re.S)
if m:
    print(m.group(1).strip())
PY
)"

if [[ -z "$NOTES" ]]; then
  NOTES="Zirn v${VERSION} (Mizan)"
fi

if gh release view "v${VERSION}" --repo aditauqir/zehan >/dev/null 2>&1; then
  gh release upload "v${VERSION}" \
    "dist/Zirn-${VERSION}.dmg" \
    "dist/Zirn-${VERSION}.zip" \
    --repo aditauqir/zehan --clobber
else
  gh release create "v${VERSION}" \
    "dist/Zirn-${VERSION}.dmg" \
    "dist/Zirn-${VERSION}.zip" \
    --repo aditauqir/zehan \
    --title "Zirn v${VERSION} (Mizan)" \
    --notes "$NOTES"
fi

log "=== Zirn v${VERSION} release complete $(date) ==="
log "OTA: https://raw.githubusercontent.com/aditauqir/zehan/main/Sparkle/appcast.xml"
log "DMG: https://github.com/aditauqir/zehan/releases/latest/download/Zirn-${VERSION}.dmg"
