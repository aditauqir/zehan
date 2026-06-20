---
name: agent-state
description: >-
  Maintains AGENT_STATE.md, the shared Zirn project overview for AI agent
  handoffs. Read at session start; update after branch, version, release,
  deploy, or notarization changes, and before ending meaningful work. Use when
  handing off between Cursor, Claude, Codex, or other agents, or when the user
  asks what is going on, current status, or project context.
---

# Agent State — Zirn Handoff File

Keep [`AGENT_STATE.md`](../../../AGENT_STATE.md) accurate so any AI agent can
orient quickly without re-discovering branch, release, and blocker context.

## Read first (every session)

Before changing branches, versions, Sparkle files, or release scripts:

1. Read `AGENT_STATE.md`.
2. Run `scripts/update-agent-state.sh` to refresh the auto snapshot.
3. Re-read the snapshot; reconcile with narrative sections if stale.

## Update automatically (agent responsibility)

Update `AGENT_STATE.md` **without being asked** when you:

- Switch branches or start work on a new version
- Change `MARKETING_VERSION`, build number, or release scripts
- Ship, deploy, notarize, or publish a release
- Hit or clear a blocker (CI, notary, merge conflict, etc.)
- Finish a meaningful task the next agent should know about
- Receive a handoff phrase ("handoffed to you", "came from cursor/claude", etc.)

At session end (or before a handoff), if you changed project direction, update
narrative sections and run the refresh script.

## Refresh script

```bash
chmod +x scripts/update-agent-state.sh
scripts/update-agent-state.sh
```

The script replaces only the block between:

- `<!-- AGENT_STATE:AUTO:START -->`
- `<!-- AGENT_STATE:AUTO:END -->`

Never delete those markers.

## What the agent edits manually

Keep narrative sections short and factual. Update as needed:

| Section | Content |
|---|---|
| **Active focus** | Current branch, version line, user goal |
| **Release pipeline** | Public / pending / in-dev versions and status |
| **Branch workflow** | Which branches matter and their relationship |
| **Blockers and waiting on** | External dependencies (Apple, CI, user decision) |
| **Recent decisions** | Dated bullets — only decisions that affect next work |
| **Handoff notes** | Numbered actions for the next agent |

Also update the `Last narrative update` line (date + tool name).

## What not to put here

- Long changelogs → use `PATCH_NOTES.md`
- Personal notes → user files like `changelog_for_me.md`
- Secrets, API keys, or credentials
- Large code excerpts

## Narrative update checklist

```
Agent state update:
- [ ] Read AGENT_STATE.md
- [ ] Run scripts/update-agent-state.sh
- [ ] Update Active focus if changed
- [ ] Update Release pipeline if version/deploy status changed
- [ ] Update Blockers if new/cleared
- [ ] Add Recent decisions (dated) if meaningful
- [ ] Refresh Handoff notes for next agent
- [ ] Set Last narrative update line
```

## Section templates

**Active focus** (2–4 bullets max):

```markdown
- **Development line:** vX.Y on `feature`
- **User intent:** …
- **Do not** …
```

**Release pipeline** (table):

```markdown
| Stage | Version | Status |
|---|---|---|
| Public (GitHub) | vX.Y | Shipped / … |
| Pending ship | vX.Y | … |
| In development | vX.Y | … |
```

**Handoff notes** (numbered, actionable):

```markdown
1. Read this file, then run scripts/update-agent-state.sh
2. Work on `feature` for …
3. …
```

## Related skills

- `zirn-branch-flow` — feature / debug / main workflow
- `deploy-it` — OTA release after user approval
- `patch-notes` — user-facing changelog in `PATCH_NOTES.md`
