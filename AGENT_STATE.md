# Zirn Agent State

> **For AI agents:** Read this file at the **start of every session** before changing branches, versions, or release files. Update it at the **end of meaningful work** so the next agent inherits context.
>
> **Refresh factual data:** `scripts/update-agent-state.sh`  
> **How to maintain narrative sections:** `.cursor/skills/agent-state/SKILL.md`

**Last narrative update:** 2026-06-22 (Codex)  
**Maintained by skill:** `agent-state`

---

## Snapshot (auto)

<!-- AGENT_STATE:AUTO:START -->
**Generated:** 2026-06-22 03:57 UTC

| Field | Value |
|---|---|
| Repo branch | `feature` |
| Dev version | 1.3 (build 11) |
| GitHub latest release | Zirn v1.2 (Mizan) — tag v1.2 |
| main vs remote | main ahead 0, behind 0 vs main/main |
| Deploy watcher | Not running |

**Git status**
```
## feature
```

**Branch heads**
```
main 856c368 Ship Zirn v1.2 with notarized DMG and Sparkle OTA.
feature ffc19ed Merge v1.2 release into feature
debug ffc19ed Merge v1.2 release into feature
```

**Release staging**
- Staged /tmp/ZirnReleaseStage/Zirn.app — v1.2 (build 11) — source=Notarized Developer ID

**Apple notary**
5 recent submissions — Accepted: 5, In Progress: 0, Failed: 0
  - 5f52d218-fe9a-42f5-b41f-c85501612b59: Accepted
  - b0f504d0-df40-474b-93b9-0c731155b487: Accepted
  - e3c0877e-9ee6-4614-901c-33e8e0444734: Accepted
  - 7826de24-7b64-4f82-918c-20e5c692b9d0: Accepted
  - d3e425e1-463b-4128-a20f-6ba00c7c39e4: Accepted

**Useful commands**
- Refresh this block: `scripts/update-agent-state.sh`
- Finish v1.2 after notary accepts: `scripts/deploy-after-notary.sh`
- Branch flow skill: `.cursor/skills/agent-state/SKILL.md` + `zirn-branch-flow`
<!-- AGENT_STATE:AUTO:END -->

---

## Active focus

- **Development line:** v1.3 is active on `feature`; build number remains 11.
- **User intent:** Replace the macOS app icon with `/Users/aditauqir/Pictures/Affinity Projects/logov4.svg`, delete local `bug`, sync `feature` and `debug` to the same head, then launch a fresh Debug app for testing.
- **Do not** push `main`, publish OTA, or overwrite the v1.3/logo work unless the user explicitly asks.

## Release pipeline

| Stage | Version | Status |
|---|---|---|
| Public (GitHub) | v1.2 | Shipped — latest GitHub Release; local `main` matches `main/main`. |
| Installed app | v1.2 (build 11) | Installed at `/Applications/Zirn.app` from `dist/Zirn-1.2.dmg`; Gatekeeper accepted and code signature verified. |
| In development | v1.3 (build 11) | `MARKETING_VERSION` bump and v4 app icon work on `feature`; clean Debug build target is `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`. |

The v1.2 notary submissions are accepted. Do not re-run deploy/release automation unless the user explicitly asks for OTA or release work.

## Branch workflow

Canonical branches (see `zirn-branch-flow` skill):

- `feature` — active implementation (**current**)
- `debug` — testing mirror of `feature`
- `main` — shipping branch (currently v1.2 release)

`feature` and `debug` are synchronized at `ffc19ed` with the v1.2 release merged in, the v1.3 version bump, and the v4 app icon work. `main` remains at the shipped v1.2 release (`856c368`).

## Blockers and waiting on

- Fresh Debug build succeeded and `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app` was launched for testing.
- Local `bug` branch was deleted after Git reported it merged into `main`.

## Recent decisions

- Added `AGENT_STATE.md` + `agent-state` skill for AI agent handoffs (2026-06-20).
- User explicitly requested the v1.3 Debug launch; Codex bumped `MARKETING_VERSION` to 1.3 on `feature`, built cleanly, and launched `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app` (2026-06-22).
- For install simulation, Codex removed non-1.3 app bundles, installed v1.2 from `dist/Zirn-1.2.dmg`, and verified notarization/code signing (2026-06-22).
- User requested the v4 logo from `logov4.svg`; Codex rasterized it to the existing `AppIcon.appiconset` PNG sizes and deleted local branch `bug` (2026-06-22).
- Codex synchronized `feature` and `debug` to the same head, then launched the fresh v1.3 Debug app (2026-06-22).

## Handoff notes for next agent

1. Read this file, then run `scripts/update-agent-state.sh`.
2. Preserve the v1.3 app icon work on `feature`.
3. Keep `feature` and `debug` at the same head; do not force-reset divergent branches.
4. Use `/Applications/Zirn.app` for shipped v1.2 install behavior and `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app` for v1.3 Debug testing.
5. `changelog_for_me.md` is personal notes — do not treat as project state.
