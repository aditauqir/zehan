---
name: brain-smart-features
description: Use when adding, changing, or reviewing Zirn features that store recommendation memory, smart feature blobs, calendar-derived context, AI reasoning traces, ranking inputs, or other lightweight feature memory outside the main .brain file. Before persisting a new smart feature blob, ask the user whether to add it to brain.smart.features.
---

# Brain Smart Features

Use `brain.smart.features` as a lightweight sidecar for feature-specific memory that should not bloat the main `.brain` vault file.

## Workflow

1. Identify whether the feature wants to persist AI reasoning, recommendation context, ranking inputs, calendar-derived context, or similar smart memory.
2. Before adding a new persisted blob type, ask the user: "Should this be added to `brain.smart.features`?"
3. If approved, store it in the opened vault folder as `brain.smart.features`, linked to the active brain by vault ID and brain filename.
4. Keep each blob compact, append-only, and scoped to the feature. Prefer one JSON object per line so loading recent context can use a bounded suffix instead of parsing the whole file.
5. Do not store secrets, API keys, full calendar dumps, or full note bodies in the sidecar. Store only the minimal context needed for future reasoning.
6. Feed only a small recent slice of `brain.smart.features` into AI prompts to avoid performance regressions.

## Blob Minimum

Each blob should include:

- `version`
- `vaultID`
- `brainFileName`
- `feature`
- `createdAt`
- compact source context
- selected/recommended page or result
- short reasoning

Keep the main `.brain` schema unchanged unless the feature truly needs durable core vault metadata.
