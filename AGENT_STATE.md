# Zirn Agent State

> **For AI agents:** Read this file at the **start of every session** before changing branches, versions, or release files. Update it at the **end of meaningful work** so the next agent inherits context.
>
> **Refresh factual data:** `scripts/update-agent-state.sh`  
> **How to maintain narrative sections:** `.cursor/skills/agent-state/SKILL.md`

**Last narrative update:** 2026-06-20 (Cursor)  
**Maintained by skill:** `agent-state`

---

## Snapshot (auto)

<!-- AGENT_STATE:AUTO:START -->
**Generated:** 2026-06-20 21:53 UTC

| Field | Value |
|---|---|
| Repo branch | `feature` |
| Dev version | 1.2 (build 11) |
| GitHub latest release | Zirn v1.1 (Mizan) — tag v1.1 |
| main vs remote | main ahead 5, behind 0 vs main/main |
| Deploy watcher | Not running |

**Git status**
```
## feature
 M scripts/finish-notarized-release.sh
?? .cursor/skills/agent-state/
?? AGENT_STATE.md
?? changelog_for_me.md
?? scripts/update-agent-state.sh
```

**Branch heads**
```
main 4f7d5ee Fix deploy log tee so background watcher keeps polling.
feature 4f7d5ee Fix deploy log tee so background watcher keeps polling.
debug 4f7d5ee Fix deploy log tee so background watcher keeps polling.
bug f07a88a Improve update notes, attachments, and assistant flows
```

**Release staging**
- Staged /tmp/ZirnReleaseStage/Zirn.app — v1.2 (build 11) — source=Unnotarized Developer ID

**Apple notary**
3 recent submissions — Accepted: 0, In Progress: 3, Failed: 0
  - e3c0877e-9ee6-4614-901c-33e8e0444734: In Progress
  - 7826de24-7b64-4f82-918c-20e5c692b9d0: In Progress
  - d3e425e1-463b-4128-a20f-6ba00c7c39e4: In Progress

**Useful commands**
- Refresh this block: `scripts/update-agent-state.sh`
- Finish v1.2 after notary accepts: `scripts/deploy-after-notary.sh`
- Branch flow skill: `.cursor/skills/agent-state/SKILL.md` + `zirn-branch-flow`
<!-- AGENT_STATE:AUTO:END -->

---

## Active focus

- **Development line:** v1.2 code on all canonical branches; **do not bump to v1.3** until the user explicitly asks.
- **User intent:** Continue v1.3 feature work is **on hold** — wait for user go-ahead before version bump.
- **Do not** push `main` or publish OTA until v1.2 notarization completes.

## Release pipeline

| Stage | Version | Status |
|---|---|---|
| Public (GitHub) | v1.1 | Shipped — latest GitHub Release |
| Pending ship | v1.2 (build 11) | Code on local `main` (+5 vs remote). **Not notarized.** 3 Apple submissions still **In Progress** since 2026-06-19. |
| In development | — | **Hold v1.3** until user requests version bump |

**When v1.2 notary accepts:** run `scripts/deploy-after-notary.sh` from a clean `main` tree (staged app must exist at `/tmp/ZirnReleaseStage/Zirn.app`).

## Branch workflow

Canonical branches (see `zirn-branch-flow` skill):

- `feature` — active implementation (**current**)
- `debug` — testing mirror of `feature`
- `main` — shipping branch (hold until v1.2 deploy)

`feature`, `debug`, and local `main` share commit `4f7d5ee`. Local `main` is **5 commits ahead** of `main/main` (v1.2 + notarization automation).

## Blockers and waiting on

- Apple notarization for v1.2 — three submissions stuck **In Progress** (oldest ~2026-06-19 14:11 UTC).
- Deploy watcher is **not running**; re-run `scripts/deploy-after-notary.sh` after notary accepts.

## Recent decisions

- Added `AGENT_STATE.md` + `agent-state` skill for AI agent handoffs (2026-06-20).
- v1.3 version bump **deferred** — user will say when to start v1.3.

## Handoff notes for next agent

1. Read this file, then run `scripts/update-agent-state.sh`.
2. Work on `feature`; mirror to `debug` for testing.
3. **Do not bump to v1.3** until the user explicitly requests it.
4. Leave `main` alone until v1.2 ships via `deploy-after-notary.sh`.
5. `changelog_for_me.md` is personal notes — do not treat as project state.
