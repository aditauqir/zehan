# Handoff — Zirn Feature Branch (updated 2026-07-16)

Read this first. This repo is currently on `feature` with local, uncommitted work.

## Status

- **Branch:** `feature`
- **Ready for:** local Debug testing from `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`
- **Not ready for:** merge to `debug`, merge to `main`, Sparkle OTA, or release until user approves
- **Last verified:** Debug build succeeded and fresh Debug app launched on 2026-07-16 after Island activation-hide + rectangular residue fix.

## Voice / Dynamic Island — latest fixes (2026-07-16)

### Activation rules (do not regress)

**Island is inactive-app only.** While Zirn is foreground (`NSApp.isActive`):

- Island panel is **always hidden** — no exception for pending draft, refine, capture, chooser, or finalize.
- Pending transcript / voice review renders in the in-app markdown editor pill (`AssistantFloatingPill`).
- Live listening / transcribing / failure status lives in the mic dialogue popup above the editor mic.

While Zirn is **inactive** and there is voice Island content, the Island may show.

`shouldShowPanel` is simply `hasVoiceIslandContent && !NSApp.isActive`.
`didBecomeActiveNotification` calls `updatePanel` immediately (not deferred) so the black pill never sits over the app for a frame.
`VoiceDynamicIslandView` also refuses to paint Island chrome while `NSApp.isActive` (defense in depth).

**Island persistence while inactive:** Panel `collectionBehavior` must be `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` — **never** `.transient`. Transient panels are auto-dismissed by macOS on tab/space/focus switches even when Zirn is still inactive. Keep `hidesOnDeactivate = false` and `canHide = false`. Hide only when Zirn becomes active.

**Do not** reintroduce `pinVisibleThroughActivation` / “keep Island up while already visible when active” to fix plus-insert flicker. That is what brought the black-pill-over-app bug back.

**Plus-insert flicker fix (without keeping Island while active):**

- Panel is `.nonactivatingPanel`; clicks use `makeKey()` + `orderFrontRegardless()` — never `makeKeyAndOrderFront` / `NSApp.activate`.
- Soft-hide: `hidePanel` `orderOut`s but retains `hostingView` so a later inactive re-show does not slam-rebuild.
- Island plus keeps the draft (`dismissAfterInsert: false`) and animates plus → tick → plus; if the app somehow activates, Island hides and the editor pill owns the draft.

### Other Island fixes

- **Island SIGABRT crash (00:02 DiagnosticReport):** Root cause was `NSHostingView.windowDidLayout` → `updateAnimatedWindowSize` nesting constraint updates inside an animated panel `setFrame(display: true)` display cycle (`NSInternalInconsistencyException` / abort). Fix:
  - Host SwiftUI in a clear container `NSView` via `VoiceIslandHostingView` (`sizingOptions = []`).
  - Defer all `updatePanel` / preference-driven resizes off the current layout turn (`scheduleUpdatePanel` / `schedulePanelFrame` + coalesce).
  - Animate panel frames with `display: false` and `allowsImplicitAnimation = false` (no nested window auto-size).
- **Continue mic animation:** `continueVoiceCaptureAppendingToPendingDraft` and Island transitions (expanded ↔ source choice ↔ recording) use `withAnimation(.easeInOut(…))`; panel resize stays on the deferred ease-in-out path.
- **Sharp rectangular residue under expanded card:** Root cause was `NSVisualEffectView` (`.behindWindow`) + SwiftUI `.thinMaterial` painting a window-sized rectangular band that ignores SwiftUI `clipShape`/masks — not just tall panel chrome. Fix: remove AppKit visual-effect / material glass from expanded chrome; use continuous-rounded black + soft gradient sheen only; panel hugs measured card height + modest `expandedShadowBleed`; clear panel/hosting layers (`isOpaque = false`); soft card shadow (radius 14 / y 6) fades in transparent bleed (no huge empty bottom padding).
- **Splash time greetings:** `WelcomeGreeting` now has ~12 phrases per morning/afternoon/evening/night bucket (stable per day+hour). Lead-in renders in soft green; welcome line stays white.

## Home Voice History redesign (2026-07-16)

- **"Voice History" heading is left-aligned** (same as Vault Map / Page Summaries); compact blocks stay centered under it.
- **Section collapse:** chevron.down to the left of **Voice History** and **Page Summaries**; points down when expanded, rotates −90° when collapsed; heading row stays, content hides.
- **Home compact (max 2):** 3-word title + spectrogram → filename only — no transcript preview, timestamp, or revision labels. Title uses the same **12pt system regular** as the markdown filename (not bold 18pt).
- **Show more:** plain text inline with the Voice History heading (no pill fill); opacity + underline on hover. Opens floating list (no black page scrim).
- Connector is a **spectrogram** (`VoiceHistorySpectrogramConnector` — seeded frequency bars).
- **3-word title** (`shortTitle` in `.convo`) via `selectedAssistantModel` after insert (Title Case, e.g. "Debt Service Plan"); offline/fail → first meaningful transcript words; legacy 3-letter titles display word fallback and regenerate on vault open / insert.
- Destination filename resolves via live notes/sidebar + note path (avoids false `Untitled.md`).

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
- When a markdown voice transcript is ready (app active), it morphs into `AssistantFloatingPill` (same width, height grows with text) with plus / Refine / discard — not a separate floating review card. Dynamic Island shows the expanded black-box review **only when the app is inactive**. Bringing Zirn to the foreground always hides the Island; pending draft stays in the editor pill.
- **Island glass chrome:** soft black fades toward a translucent lower sheen via continuous-rounded SwiftUI gradients only (no `NSVisualEffectView` / `.thinMaterial` — those left a sharp rectangular residue the size of the shadow-bleed panel). Glass-sized to the card; panel/hosting layers stay clear outside the rounded card.
- **Island shadow bleed (2026-07-16):** expanded/compact Island panels include modest transparent padding around the card so soft drop shadows fade instead of hard-clipping. Do not “fix” residue by adding huge empty bottom padding or by keeping window-server materials.
- **Continue dictation (append):** review action row has a right-side mic that starts a new capture for the same target while stashing the current draft. On finish, new text is space-concatenated onto the previous transcript and pushed as a new revision (undo reverses the append). Cancel/dismiss source chooser restores the prior draft.
- **Refine with AI:** runs in-place in the same box/pill via `enhancePendingVoiceTranscript()` using `selectedAssistantModel` (same writing/assistant model preference). While the app is inactive, refine stays on the Island; if the app becomes active, Island hides and the editor pill shows the refining draft / skeleton. While refining, `isEnhancingVoiceTranscript` greys/disables Refine and swaps transcript text for `VoiceTranscriptRefineSkeleton` in both Dynamic Island and markdown input-pill.
- **Skeleton shimmer:** `VoiceTranscriptRefineSkeleton` now uses one shared top-to-bottom gradient masked by the whole block of bars, not separate gradients per line.
- **Voice review actions (2026-07-15 update):**
  - Destination `Menu` lists **notes only** (no folders). Insert always appends into the selected markdown note.
  - Single action row under transcript: **plus** | **copy** | **undo** | `n/total` | **redo** | **Refine** | **mic** (continue dictation / append). Symmetric 10 pt padding above/below the row.
  - Plus replaces the old `Insert in <>` chip; idle state pulses a white/primary ring, hover fills a circular highlight (easeInOut).
  - Refine success pushes onto a revision stack; undo/redo walk history; counter shows `current/total`. Undo dimmed at start, redo at end.
  - Copy stays icon-only (no chip). Pasteboard helper + Island key-window fix unchanged.
  - Recording pill shows elapsed `M:SS` timer on the **same row as the Recording/Paused heading** (immediately beside the title). Timer freezes while paused.
  - Target labels use the **current note file name** (not generic "Markdown").
- **Unread insert dots:** inserting into a non-current note adds that note ID to `unreadVoiceInsertNoteIDs`. Sidebar shows a yellow-ochre 7 pt filled circle next to the title; opening the note clears the dot. Inserting into the currently open note does not set a dot.
- **Plus hover:** white/primary circular fill with `.easeInOut(duration: 0.18)`.
- **Insert feedback and dismissal:** Island plus inserts without clearing the pending review, animates to a checkmark for 0.9s, then returns to plus; editor plus keeps the existing insert-and-dismiss behavior.
- **Review dismiss hover:** transcript-review X buttons in both Island and editor increase circular background and icon opacity on hover with `.easeInOut(duration: 0.18)`.
- **Refine** hover: no system-color fill gradient. Instead a `#a1e4ff` glow travels around the capsule border perimeter (~1.45s loop).
- Mic button shows a compact liquid-glass hover tip: "Press Fn + Control to use".
- Confirming a voice transcript (plus) targets the selected review destination and saves/writes immediately.
- **Voice History + `.convo` (2026-07-16):** Successful editor inserts append a vault-local `.convo` JSON sidecar (alongside the brain file), not the main brain / `brain.smart.features`. Each entry stores timestamp, revision count, transcript, destination note ID/title/path, optional UTF-16 character range, and optional `shortTitle` (3-word AI title). Home shows left-aligned **Voice History** above Page Summaries (max 2 compact blocks: 3-word title + spectrogram → file; title matches filename 12pt). Section chevrons collapse content. **Show more** is plain text beside the heading (hover underline); opens a floating list (no black page scrim) with 3-line previews + note titles; clicking opens the note and search-highlights the inserted snippet. `BrainStore.loadVoiceHistoryContext(limit:maxCharacters:)` / `recentVoiceConversationEntries(limit:)` expose compact history for writing/chat callers (opt-in, not dumped into every prompt).
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
10. Home Voice History above Page Summaries, persisted in vault `.convo` (bulk history stays out of brain / `brain.smart.features`) — collapse chevrons, left-aligned headings, compact centered diagram rows, spectrogram connector, 3-word AI titles (12pt matching filename), real destination filenames; Show more is plain inline text with hover, floating separator list (no black scrim).

## Files Touched

| File | Role |
|---|---|
| `Zehan/ContentView.swift` | Home layout, Voice History section + overlay, recommendation buttons, Apple Calendar Sync UI, delete confirmation popover, liquid glass styling, voice review action row (plus·copy·undo·counter·redo·Refine), unread sidebar dots |
| `Zehan/ZehanApp.swift` | Dynamic Island panel, expanded transcript glass chrome, shared review action row, recording timer beside title |
| `Zehan/BrainStore.swift` | `.convo` voice history persistence + context loader, smart feature blob persistence, recommendation support, voice Refine revision stack (undo/redo), notes-only destination insert, unread voice-insert note IDs, capture timer + pasteboard helper |
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
- [ ] Glass behind expanded box matches continuous corner radius (no sharp rectangular bleed; no NSVisualEffectView).
- [ ] Refine updates text in-place, greys the button, shows skeleton in island + input pill, uses selected writing model.
- [ ] Plus inserts into selected note; idle pulse ring + hover fill highlight.
- [ ] Island insert keeps the review open and animates plus → tick → plus; editor insert dismisses its review.
- [ ] Island and editor transcript-review X buttons highlight smoothly on hover.
- [ ] Changing voice destination via breadcrumb Menu does not resize/crash the review card or Island panel.
- [ ] Destination Menu shows notes only (no folders).
- [ ] Insert into a different note does not crash; text lands in that note.
- [ ] Insert into a different note shows ochre sidebar dot; opening the note clears the dot.
- [ ] Action row is plus | copy | undo | n/total | redo | Refine | mic with equal padding above/below.
- [ ] Undo/redo walk refine revisions; counter updates; undo dimmed at 1/n, redo at n/n.
- [ ] Mic on review pill continues dictation (source choice → record); finished text appends and adds a revision.
- [ ] Cancel mid-append restores the previous transcript draft.
- [ ] Expanded Island has no sharp light residue/cutoff under the black card (no NSVisualEffectView band; shadow fades in modest transparent bleed; panel hugs card height).
- [ ] Continue-mic morphs expanded → source choice → recording with easeInOut (no hard jump).
- [ ] Island plus insert stays open with plus→tick→plus while app stays inactive; does **not** vanish/reappear from activation pin hacks.
- [ ] Bringing Zirn to the foreground always hides the Island; pending draft appears in `AssistantFloatingPill` only.
- [ ] Resigning active with a pending draft shows the Island again (editor pill is not required while inactive).
- [ ] Splash time lead-in has varied green phrases per morning/afternoon/evening/night.
- [ ] Recording pill shows `M:SS` timer beside the Recording/Paused heading.
- [ ] Recording / destination labels show the current note file name, not "Markdown".
- [ ] Confirming a voice insert writes/updates vault `.convo` (not the main brain file).
- [ ] Home Voice History sits above Page Summaries and shows at most 2 recent blocks.
- [ ] Home Voice History blocks show only 3-word title + spectrogram → filename (no preview / timestamp / revisions); title size matches filename (~12pt).
- [ ] Voice History / Page Summaries have left chevrons that collapse section content.
- [ ] Show more is plain text beside Voice History (no pill), with hover; floating popup (no full-page black dim) with hairline separators, 3-line preview + note title per row; clicking opens the note and jumps/highlights the inserted snippet when possible.
- [ ] `loadVoiceHistoryContext` is available for assistant/writing callers and is not injected into every prompt by default.

## Branch Flow

Use skill `zirn-branch-flow` for branch sync. Keep `feature` as the implementation source of truth until the user approves testing or shipping. Do not force-reset or discard local changes.
