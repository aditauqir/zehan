#!/usr/bin/env bash
# Refresh factual sections in AGENT_STATE.md for AI agent handoffs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$ROOT/AGENT_STATE.md"
PBX="$ROOT/Zehan.xcodeproj/project.pbxproj"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-ZirnNotary}"

marketing_version() {
  awk -F' = ' '/MARKETING_VERSION/ { gsub(/;/, "", $2); print $2; exit }' "$PBX"
}

build_number() {
  awk -F' = ' '/CURRENT_PROJECT_VERSION/ { gsub(/;/, "", $2); print $2; exit }' "$PBX"
}

branch_name() {
  git -C "$ROOT" branch --show-current 2>/dev/null || echo "unknown"
}

git_status_short() {
  git -C "$ROOT" status --short --branch 2>/dev/null | head -20
}

main_vs_remote() {
  local ahead behind
  ahead="$(git -C "$ROOT" rev-list --count main/main..refs/heads/main 2>/dev/null || echo "?")"
  behind="$(git -C "$ROOT" rev-list --count refs/heads/main..main/main 2>/dev/null || echo "?")"
  echo "main ahead ${ahead}, behind ${behind} vs main/main"
}

branch_heads() {
  local b
  for b in main feature debug bug; do
    if git -C "$ROOT" rev-parse --verify "refs/heads/$b" >/dev/null 2>&1; then
      git -C "$ROOT" log -1 --format="${b} %h %s" "refs/heads/$b"
    fi
  done
}

latest_github_release() {
  local line
  line="$(gh release list --limit 1 --repo aditauqir/zehan 2>/dev/null | head -1 || true)"
  if [[ -z "$line" ]]; then
    echo "unavailable"
    return
  fi
  echo "$line" | awk -F'\t' '{ print $1 " — tag " $3 }'
}

notary_summary() {
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/tmp/zirn-notary-history.txt 2>/dev/null; then
    echo "Notary profile unavailable"
    return
  fi

  local count accepted in_progress rejected
  count="$(grep -c '^    id: ' /tmp/zirn-notary-history.txt || true)"
  accepted="$(grep -c 'status: Accepted' /tmp/zirn-notary-history.txt || true)"
  in_progress="$(grep -c 'status: In Progress' /tmp/zirn-notary-history.txt || true)"
  rejected="$(grep -E -c 'status: (Invalid|Rejected)' /tmp/zirn-notary-history.txt || true)"

  echo "${count} recent submissions — Accepted: ${accepted}, In Progress: ${in_progress}, Failed: ${rejected}"
  awk '
    /^    id: / { id=$2 }
    /^    status: / {
      status=$0
      sub(/^    status: /, "", status)
      printf "  - %s: %s\n", id, status
    }
  ' /tmp/zirn-notary-history.txt | head -5
}

staged_release_app() {
  local app="/tmp/ZirnReleaseStage/Zirn.app"
  if [[ ! -d "$app" ]]; then
    echo "No staged release app"
    return
  fi
  local version build gatekeeper
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || echo "?")"
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist" 2>/dev/null || echo "?")"
  gatekeeper="$(spctl -a -t exec -vv "$app" 2>&1 | awk '/source=/ { print $0; exit }')"
  echo "Staged /tmp/ZirnReleaseStage/Zirn.app — v${version} (build ${build}) — ${gatekeeper}"
}

deploy_watcher() {
  if pgrep -f 'deploy-after-notary|finish-notarized-release' >/dev/null 2>&1; then
    echo "Running"
  else
    echo "Not running"
  fi
}

generate_auto_block() {
  cat <<EOF
<!-- AGENT_STATE:AUTO:START -->
**Generated:** $(date -u '+%Y-%m-%d %H:%M UTC')

| Field | Value |
|---|---|
| Repo branch | \`$(branch_name)\` |
| Dev version | $(marketing_version) (build $(build_number)) |
| GitHub latest release | $(latest_github_release) |
| main vs remote | $(main_vs_remote) |
| Deploy watcher | $(deploy_watcher) |

**Git status**
\`\`\`
$(git_status_short)
\`\`\`

**Branch heads**
\`\`\`
$(branch_heads)
\`\`\`

**Release staging**
- $(staged_release_app)

**Apple notary**
$(notary_summary)

**Useful commands**
- Refresh this block: \`scripts/update-agent-state.sh\`
- Finish v1.2 after notary accepts: \`scripts/deploy-after-notary.sh\`
- Branch flow skill: \`.cursor/skills/agent-state/SKILL.md\` + \`zirn-branch-flow\`
<!-- AGENT_STATE:AUTO:END -->
EOF
}

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Missing $STATE_FILE"
  exit 1
fi

AUTO_BLOCK="$(generate_auto_block)"
python3 - <<'PY' "$STATE_FILE" "$AUTO_BLOCK"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
block = sys.argv[2]
text = path.read_text()
pattern = re.compile(r"<!-- AGENT_STATE:AUTO:START -->.*?<!-- AGENT_STATE:AUTO:END -->", re.S)
if not pattern.search(text):
    raise SystemExit("AGENT_STATE auto markers not found")
text = pattern.sub(block.strip(), text)
path.write_text(text)
PY

echo "Updated auto block in AGENT_STATE.md"
