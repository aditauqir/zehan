# Handoff — Zirn Feature Branch (updated 2026-07-15)

Read this first. This repo is currently on `feature` with local, uncommitted work.

## Status

- **Branch:** `feature`
- **Ready for:** local Debug testing from `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`
- **Not ready for:** merge to `debug`, merge to `main`, Sparkle OTA, or release until user approves
- **Last verified:** Debug build succeeded and fresh Debug app launched on 2026-07-15 after voice review action-row redesign (plus insert, undo/redo revision stack, Refine label).

## Voice Transcription Handoff

The user is actively testing the new voice feature. The main transcription blocker found on 2026-07-15 was Homebrew `whisper-cli` crashing in its Metal/dynamic backend path before it could return text.

Current implementation facts:

- `BrainStore` downloads or reuses `ggml-small.bin` from whisper.cpp in the app container. On this machine the model is installed at about 465 MB.
- Final transcription now records mic audio to a temp CAF file, converts it to 16 kHz mono WAV with `/usr/bin/afconvert`, and routes that WAV through the bundled static CPU `whisper-cli` at `Contents/Resources/WhisperRuntime/bin/whisper-cli`.
- `whisper-cli` still runs with `--no-gpu`. A dynamic Homebrew `whisper-cli` path failed with Metal allocation errors or backend plugin crashes; the bundled static CLI links only Apple system libraries plus Accelerate.
- Smoke test passed with the exact built app executable:
  `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app/Contents/Resources/WhisperRuntime/bin/whisper-cli -m <app-container>/ggml-small.bin -f /tmp/zirn-whisper.cpp/samples/jfk.wav --no-timestamps --no-gpu --output-txt --output-file /tmp/zirn-whisper-app-static-smoke --language en`
- Debug, release, and ad-hoc entitlements now include microphone input and speech recognition:
  - `com.apple.security.device.audio-input`
  - `com.apple.security.personal-information.speech-recognition`
- `Zirn-Info.plist` has microphone and speech recognition usage strings.
- **Audio source is now explicitly chosen (no auto mic/screen detection).** When starting transcription the user picks **On Screen** (ScreenCaptureKit system audio via `SCStream`) or **Voice** (microphone via `AVAudioEngine`). The old decibel-based auto path is gone.
  - Editor: `VoiceAudioSourceChooserPopover` appears above the mic button (`ContentView.swift`).
  - Dynamic Island / black pill: `sourceChoicePillView` shows the same two options (`ZehanApp.swift`).
  - `BrainStore.pendingVoiceAudioSourceSelection` holds the target awaiting a source; `selectVoiceAudioSource(_:for:)` starts capture; `activeVoiceAudioSource` records the running source.
  - System audio requires Screen Recording permission (`NSScreenCaptureUsageDescription` in `Zirn-Info.plist`).
- Dynamic Island polish: the panel now reuses a single `NSHostingView` (no per-update rebuild) so the Stop/Pause/source buttons receive clicks reliably; the hosted content frame updates with panel size changes so width changes stay centered on the screen X axis. On first appearance, AppKit starts the panel oversized and nearly transparent, then flies/contracts it into place over 0.24s while a black keystone silhouette resolves into the opaque pill. The panel morphs smoothly between pill, transcribing, and expanded black-box states via `matchedGeometryEffect`. Final transcript renders in a solid black rounded container that expands from the pill (Apple Dynamic Island style).
- **Island crash fix (2026-07-15):** custom in-card destination list + `NSHostingView.updateAnimatedWindowSize` caused nested Auto Layout constraint updates and aborted the app. Destination picking now uses a native SwiftUI `Menu` (macOS liquid-glass popup overlay that does not resize the card). Island `NSHostingView.sizingOptions = []` so SwiftUI never auto-resizes the panel window.
- **Expanded box Y-alignment:** island content is top-anchored in the panel (`alignment: .top`); panel frame keeps a fixed top inset (8 pt) when morphing pill → expanded so the box does not drop down.
- Pill hearing/recording spinner is `VoiceDotGridSpinner` (3×4 white dot grid, random smooth ease-in-out shimmer) and stays inside the 48 pt pill. Transcribing now uses `VoiceOrbitingCirclesSpinner` (5 glowing white orbiting circles) with a large centered percent label and a right-side cancel button instead of a progress bar.
- The in-app "Transcribe from" chooser is a compact liquid-glass **speech bubble** anchored just above the circular voice button (bottom of popover aligned to mic top + 6 pt gap, downward material tail). Top padding inside the bubble is tight (`8` top / `12` bottom).
- In markdown editor, listening / transcribing / failure live status also lives in that same dialogue popup above the mic — not as a separate floating `VoiceLiveTranscriptBubble`. When the final transcript is ready, it morphs into `AssistantFloatingPill`.
- When a markdown voice transcript is ready (app active), it morphs into `AssistantFloatingPill` (same width, height grows with text) with `Insert in <page title>`, Refine with AI, and discard — not a separate floating review card. Dynamic Island still shows the expanded black-box review when the app is inactive.
- **Island glass chrome:** soft black fades to clear in the lower half; real `NSVisualEffectView` (`.hudWindow` / `.behindWindow`) + `.thinMaterial` provide frosted transparency. Glass sits **under** the action buttons (buttons on top). Opaque black base + continuous CAShapeLayer mask keep glass sized to the rounded card (no square bleed); the hosted panel/content/effect layers are clear and re-mask on bounds changes to avoid sharp rectangular bleed.
- **Refine with AI:** runs in-place in the same box/pill via `enhancePendingVoiceTranscript()` using `selectedAssistantModel` (same writing/assistant model preference). The Dynamic Island remains visible for pending/refining drafts even if clicking the panel activates the app. While refining, `isEnhancingVoiceTranscript` greys/disables Refine and swaps transcript text for `VoiceTranscriptRefineSkeleton` in both Dynamic Island and markdown input-pill.
- **Skeleton shimmer:** `VoiceTranscriptRefineSkeleton` now uses one shared top-to-bottom gradient masked by the whole block of bars, not separate gradients per line.
- **Voice review actions (2026-07-15 update):**
  - Destination `Menu` lists **notes only** (no folders). Insert always appends into the selected markdown note.
  - Single action row under transcript: **plus** | **copy** | **undo** | `n/total` | **redo** | **Refine** (sparkles + "Refine"). Symmetric 10 pt padding above/below the row.
  - Plus replaces the old `Insert in <>` chip; idle state pulses a white/primary ring, hover fills a circular highlight (easeInOut).
  - Refine success pushes onto a revision stack; undo/redo walk history; counter shows `current/total`. Undo dimmed at start, redo at end.
  - Copy stays icon-only (no chip). Pasteboard helper + Island key-window fix unchanged.
  - Recording pill shows elapsed `M:SS` timer on the **same row as the Recording/Paused heading** (immediately beside the title). Timer freezes while paused.
  - Target labels use the **current note file name** (not generic "Markdown").
- **Unread insert dots:** inserting into a non-current note adds that note ID to `unreadVoiceInsertNoteIDs`. Sidebar shows a yellow-ochre 7 pt filled circle next to the title; opening the note clears the dot. Inserting into the currently open note does not set a dot.
- **Plus hover:** white/primary circular fill with `.easeInOut(duration: 0.18)`.
- **Refine** hover: no system-color fill gradient. Instead a `#a1e4ff` glow travels around the capsule border perimeter (~1.45s loop).
- Mic button shows a compact liquid-glass hover tip: "Press Fn + Control to use".
- Confirming a voice transcript (plus) targets the selected review destination and saves/writes immediately.
- Stop Recording should stop only `AVAudioEngine` input capture. The finalizing controller is kept in `finalizingVoiceTranscriptionController` while `afconvert` and `whisper-cli` run. `VoiceTranscriptionController.cancel()` now also terminates the running Whisper/afconvert `Process` so cancellation is immediate.
- The red stop icon in the transcribing UI is the only intended full cancellation path.
- Shortcut handling should ignore `fn + control` while final transcription is processing, instead of starting a new capture and stomping finalization state.
- `inputNode.setVoiceProcessingEnabled(false)` is intentional. The earlier `true` setting likely caused macOS to duck/reduce system audio like a voice-call session.
- Whisper CLI progress is currently estimated UI progress and reaches 100% only when final text returns.
- If no text returns, Zirn should show `Nothing to transcribe`.

Likely remaining root causes if transcription still fails:

- If transcription still fails in the app but the smoke command passes, inspect the temp CAF to WAV conversion path, app sandbox process execution, and `processFailed` status text.

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
| `Zehan/ContentView.swift` | Home layout, recommendation buttons, Apple Calendar Sync UI, delete confirmation popover, liquid glass styling, voice review action row (plus·copy·undo·counter·redo·Refine), unread sidebar dots |
| `Zehan/ZehanApp.swift` | Dynamic Island panel, expanded transcript glass chrome, shared review action row, recording timer beside title |
| `Zehan/BrainStore.swift` | Smart feature blob persistence, recommendation support, voice Refine revision stack (undo/redo), notes-only destination insert, unread voice-insert note IDs, capture timer + pasteboard helper |
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
- [ ] Expanded Dynamic Island transcript box stays top-aligned with the recording pill (same X, no Y drop).
- [ ] Glass behind expanded box matches continuous corner radius (no sharp rectangular bleed).
- [ ] Refine updates text in-place, greys the button, shows skeleton in island + input pill, uses selected writing model.
- [ ] Plus inserts into selected note; idle pulse ring + hover fill highlight.
- [ ] Changing voice destination via breadcrumb Menu does not resize/crash the review card or Island panel.
- [ ] Destination Menu shows notes only (no folders).
- [ ] Insert into a different note does not crash; text lands in that note.
- [ ] Insert into a different note shows ochre sidebar dot; opening the note clears the dot.
- [ ] Action row is plus | copy | undo | n/total | redo | Refine with equal padding above/below.
- [ ] Undo/redo walk refine revisions; counter updates; undo dimmed at 1/n, redo at n/n.
- [ ] Recording pill shows `M:SS` timer beside the Recording/Paused heading.
- [ ] Recording / destination labels show the current note file name, not "Markdown".

## Branch Flow

Use skill `zirn-branch-flow` for branch sync. Keep `feature` as the implementation source of truth until the user approves testing or shipping. Do not force-reset or discard local changes.
