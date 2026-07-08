# Handoff — Zirn Feature Branch (2026-07-06)

Read this first. This repo is currently on `feature` with local, uncommitted work.

## Status

- **Branch:** `feature`
- **Ready for:** local Debug testing from `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`
- **Not ready for:** merge to `debug`, merge to `main`, Sparkle OTA, or release until user approves
- **Last verified:** clean Debug build succeeded on 2026-07-06

## Current User Requests Implemented

1. Home page summary was removed.
2. Vault Map now sits below the Home header.
3. Home page now has:
   - `Go back to <last open page>` button
   - `Go to recommended page` button with the requested symbol treatment
   - Apple Calendar Sync disabled subtext with dismiss behavior
4. Configure menu now has an Apple Calendar Sync toggle.
5. Calendar recommendation logic checks upcoming calendar events by priority:
   - tests
   - classes
   - other events
6. Recommendation reasoning writes relevant blobs to a sidecar file named `brain.smart.features`.
7. A repo-local skill was added so future agents ask before adding feature reasoning to `brain.smart.features`.
8. Delete actions now show a confirmation popover before deleting a file.
9. Delete confirmation popover styling was revised toward native macOS liquid glass:
   - no visible extra border
   - no gradient separation
   - centered action buttons
   - caution symbol uses yellow `exclamationmark.triangle.fill`
   - Delete button is white with black text normally
   - Delete button transitions to red with white text on hover
   - red hover glow appears below the Delete button
   - all text in the bubble uses regular weight, with no bolding

## Files Touched

| File | Role |
|---|---|
| `Zehan/ContentView.swift` | Home layout, recommendation buttons, Apple Calendar Sync UI, delete confirmation popover, liquid glass styling |
| `Zehan/BrainStore.swift` | Smart feature blob persistence and recommendation support |
| `Zehan/AppleCalendarEventProvider.swift` | EventKit-backed Apple Calendar lookup and event prioritization |
| `Zehan/Zirn.entitlements` | Calendar entitlement for Debug |
| `Zehan/Zirn.release.entitlements` | Calendar entitlement for Release |
| `Zirn-Info.plist` | Calendar permission usage strings |
| `.codex/skills/brain-smart-features/SKILL.md` | Agent skill for asking before adding `brain.smart.features` reasoning |
| `.codex/skills/brain-smart-features/agents/openai.yaml` | Skill agent metadata |

## Delete Confirmation Bubble Details

Component: `LiquidGlassDeleteConfirmation` in `Zehan/ContentView.swift`.

Current expected styling:

- Background: `.ultraThinMaterial`
- Shape: `RoundedRectangle(cornerRadius: 18, style: .continuous)`
- Stroke/border: none
- Gradient: none
- Shadow: black @ 18%, radius 22, y 12
- Icon: `exclamationmark.triangle.fill`, 15 pt, regular, yellow @ 96%
- Message: 13 pt, regular, primary @ 90%
- Buttons: centered in the bubble
- Cancel: 12 pt, regular, primary @ 74%, white capsule @ 12%
- Delete normal: 12 pt, regular, white capsule @ 94%, black text @ 86%
- Delete hover: red capsule @ 96%, white text, red shadow @ 34%, radius 10, y 5
- Animation: `.easeOut(duration: 0.16)` on delete hover

Do not add bold or semibold text back into this bubble unless the user explicitly asks.

## Build And Launch

Use the native Debug path:

```bash
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build

pkill -f Zirn
sleep 1
open -n /tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app
```

## Test Checklist

- [ ] Home opens without the old summary section.
- [ ] Vault Map appears directly under the Home header.
- [ ] `Go back to <last open page>` opens the previous page.
- [ ] `Go to recommended page` is enabled only when Apple Calendar Sync is on.
- [ ] Disabled recommendation subtext can be dismissed and stays out until sync is enabled.
- [ ] Configure menu Apple Calendar Sync toggle persists.
- [ ] Calendar permission prompt appears when sync is enabled and needed.
- [ ] Recommendations prefer tests over classes over other events.
- [ ] `brain.smart.features` receives compact relevant blobs, not full brain content.
- [ ] Delete toolbar button asks for confirmation before deleting.
- [ ] Sidebar row delete button asks for confirmation before deleting.
- [ ] Delete confirmation bubble has no visible border or gradient separation.
- [ ] Delete confirmation bubble text is not bold.
- [ ] Delete button is white/black normally and red/white with a red glow on hover.

## Branch Flow

Use skill `zirn-branch-flow` for branch sync. Keep `feature` as the implementation source of truth until the user approves testing or shipping. Do not force-reset or discard local changes.
