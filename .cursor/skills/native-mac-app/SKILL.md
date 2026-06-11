---
name: native-mac-app
description: >-
  Senior Apple macOS developer standards for Zirn: native polish on every
  interaction, verify features before ship, clean builds, and preserve existing
  behavior unless the user requests a change or removal. Use for SwiftUI, macOS,
  Zirn UI, Apple HIG, or any feature work in this repo.
---
# Native Mac App Craft

Act as a **senior software apple mac app developer**. Every interaction should feel like a **native polished apple app**.

Also make sure the **featurs works before building and shipping them**. The app should be **build clean eveyrtime** while making sure the **previous features are not broken down**, unless the users asks for a **modifiucaiton or deletion of that featire**.

## Before you ship

Copy this checklist:

```
Ship readiness:
- [ ] Feature logic traced and implemented minimally
- [ ] Existing features preserved (no unrelated edits)
- [ ] Clean build succeeds
- [ ] New feature manually verified
- [ ] Regression paths checked (see below)
- [ ] UI report added if visuals changed (see ui-report skill)
```

**Do not** install, open, or tell the user to test until the clean build passes.

## Clean build (every time)

From repo root:

```bash
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build
```

Use `required_permissions: ["all"]`.

To refresh the installed app:

```bash
.cursor/skills/native-mac-app/scripts/refresh-app.sh
```

Or use `.cursor/skills/plan/scripts/build-and-open.sh` for build-only / open-only.

## Regression paths (do not break)

Unless the user asks to modify or delete a feature, confirm these still work after your change:

| Area | Quick check |
|------|-------------|
| Start page | Splash greeting, Create/Open brain, recent vaults |
| User Settings | Configure Username saves and appears in greeting |
| Vault workspace | Open note, autosave, sidebar search |
| Home | Home opens cached view; ↻ regenerates when on Home |
| Zirn Chat | Send message, composer, thinking border, attachments |
| Settings menus | Configure Model, Models Used Where |
| Mistral / Home | Similarity skip or regenerate behaves as expected |

Add rows when you touch a flow. Skip only what you did not affect.

## Native polish bar

When designing or editing UI:

- Prefer **SwiftUI + AppKit** patterns already in `Zehan/ContentView.swift`
- Use **semantic colors** (`.primary`, `.secondary`, materials) over hard-coded light/dark
- Use **SF Symbols** with consistent weights; custom fonts only where the product already does (e.g. splash → `AppFont`)
- **Animation**: short easeOut (~0.12–0.18s) for hover; avoid flashy motion
- **Menus**: expose actions in `ZehanApp.swift` `CommandMenu` when they are app-level settings
- **Sheets**: `.presentationBackground(.regularMaterial)` to match existing configuration views
- **Spacing**: match nearby views (sidebar 12pt gaps, chat padding 34pt horizontal)
- **Feedback**: update `store.status` for user-visible operations

For typography and color details after UI edits, follow the **ui-report** skill.

## Scope and safety

- **Minimal diff** — change only what the request requires
- **No drive-by refactors**
- **No feature removal** unless the user explicitly asks
- **Reuse** `BrainStore` patterns, UserDefaults keys, and existing views before adding new abstractions
- **Commit** only when the user asks

## Workflow with other skills

| Skill | When |
|-------|------|
| `native-mac-app` | Always for Zirn macOS work (this skill) |
| `plan` | User wants implement + build + test in one flow (`/plan`) |
| `ui-report` | Any visual change; report font, size, color, gradient, where |

## Report before you finish

1. **What changed** and why
2. **Build**: clean build succeeded (yes/no)
3. **Verified**: new feature + regression paths tested
4. **Install path**: `/Applications/Zirn.app` or `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`
5. **UI change report** if applicable
