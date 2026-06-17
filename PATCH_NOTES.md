# Patch Notes

## v1.1 (Mizan)

- Reworked the Sparkle update window into a wider layout with app and version identity on the left and a scrollable changelog on the right.
- Added the non-notarized app README into the DMG build flow so every new release can explain the Gatekeeper bypass steps.
- Rendered Markdown on the Home summary page instead of showing raw Markdown markers.
- Limited personalization context to Zirn Chat and Home summaries.
- Fixed Home summary generation for Markdown files stored inside folders.
- Cleaned dragged Markdown filenames so temporary/hash-style names do not appear during rename.
- Prevented Mistral writing mode from ending with follow-up invitation lines.
- Preserved input focus while the assistant prompt box grows during typing.
- Added a conversation-mode insert button that weaves the assistant answer back into the current Markdown page.
- Added supported attachment storage under each vault's `Files/PDFs`, `Files/Images`, and `Files/Documents` folders.
- Added attachment routing so Zirn prefers Markdown context first and only includes file context when the user asks a file-specific question.
- Added stored file links to attachment-aware prompts when file context is used.
- Cleared attached files from Zirn Chat, writing, and conversation prompts after sending so stale attachments do not keep consuming tokens.
- Added File > Open Your Files to open the vault's managed file folder.
- Added on-device Dice-Sorensen source similarity for Home generation so reopening a vault can skip unnecessary model calls when the vault has only marginal changes.
- Added persisted Home source signatures in generated summary metadata so similarity checks can work across vault reopen sessions.
- Added an automatic Sparkle update checker flow that notifies users when an update is available, shows what changed, and offers Update, Don't Update, or Skip This Version.
- Added release-note generation from `PATCH_NOTES.md` so OTA popup copy and GitHub release notes can use the same versioned source of truth.
- Added automatic reopening of the previous workspace on launch, plus a File menu Go to Home shortcut that returns to the greeting start page.
- Added centered Personalize and Configure buttons under the welcome greeting for faster profile and model setup.
- Changed the About Zirn panel to show `v1.1 (Mizan)` instead of the internal Sparkle build number.
- Fixed release delivery safety by requiring Developer ID signing for public builds and adding notarization support before Sparkle/GitHub distribution.
- Changed the app version to `1.1`.
- Improved rendered page spacing near the floating input pill so end-of-page text is not covered.
- Added git ignore coverage for local `.brain` vault files.
- Notes: OTA publishing, appcast updates, and release uploads should still only happen after an explicit ship/release instruction.
