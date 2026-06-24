# Patch Notes

## v1.4.5

- Fixed oversized or corrupt page files from blocking an entire vault load; readable pages continue loading and Zirn reports the skipped file clearly.
- Fixed missing page files and broken wiki links so Zirn shows an in-app status instead of failing silently or handing custom note URLs to macOS.
- Improved large-page editing stability by skipping full-document Markdown restyling once a document is large enough to risk UI stalls.
- Added GitHub Actions Debug CI plus a signed, notarized manual Sparkle release workflow with Developer ID certificate/profile import.
- Added a Codex runbook for branch preflight, Debug testing, wiki-link validation, and the GitHub Actions release checklist.

## v1.4.4

- Restored Apple Passwords / Keychain support in notarized release builds by embedding a Developer ID Application provisioning profile and signing with the Keychain access group entitlement.
- Release signing now fails early if the Developer ID profile for `noortech.Zirn` is missing, so broken Keychain builds cannot ship again.
- Fixed API keys not appearing in the Passwords app by storing them with standard Keychain accessibility instead of Touch ID–gated access control, which hid entries from Passwords browsing.

## v1.4.3

- Fixed Zirn failing to open after v1.4.2 by restoring release re-signing entitlements that macOS 26 can launch. Keychain in shipped builds remains a follow-up once the Developer ID provisioning profile is wired up.
- Kept the v1.4.2 fixes for Home summary saving, DeepSeek Home compilation, and brain AI preference sync.

## v1.4.2

- Fixed Apple Passwords / Keychain storage by embedding the keychain access group in release-signed builds.
- Fixed Home page generation failing to save `home-summary.md` when a vault is open by restoring security-scoped folder access before writing summaries.
- Fixed DeepSeek Home page and summary generation by disabling V4 thinking mode for structured markdown output so the model returns complete Home documents instead of truncated reasoning.
- Fixed brain vault AI preference sync failing after loading API keys from Keychain when a vault is open.
- Added a release signing check that blocks shipping builds missing the Keychain entitlement.

## v1.4.1 (Raxat)

- Redesigned the Zirn Chat start screen with PT Serif branding, the full-color app icon, and a centered composer that animates into place when a conversation begins.
- Added recent conversations below the chat input on the start screen, showing the three latest chats with a Show more popover for the rest.
- Reworked the active chat composer so it floats above the thread, sits closer to the footer, and grows dynamically from one line up to five lines before scrolling inside the field.
- Fixed chat input caret alignment, Return vs Shift-Return behavior, and copy/paste routing so Cmd-C works on selected response text without stealing focus from the input field.
- Added multi-conversation Zirn Chat history with conversation switching, new-chat creation, deletion, and persisted session storage per vault.
- Added a menu bar usage gauge that tracks combined Mistral, Mistral OCR, and DeepSeek spend against a soft $10 budget, with per-provider breakdowns.
- Improved launch responsiveness by deferring automatic vault reopen until after the first frame instead of blocking startup on the main thread.
- Fixed Home regeneration so highlight-only Markdown edits no longer trigger unnecessary Home recompilation.
- Changed the app version to `1.4.1` and kept the codename `Raxat`.

## v1.4 (Raxat)

- Added DeepSeek as a beta model provider with API key verification, model persistence, and Apple Keychain saving/loading alongside Mistral.
- Added one Configure Models sheet that replaces the old split settings and lets users route content generation, Home page generation, and flashcard generation independently.
- Added equal-size Mistral/DeepSeek logo switches in Configure Models and the prompt input field so provider selection no longer stretches around text labels.
- Added a Document Reading Service row in Configure Models and kept document OCR on Mistral OCR because DeepSeek's current API does not expose OCR/document-reading support.
- Added native Undo/Redo menu handling so Cmd-Z, Cmd-Y, and Cmd-Shift-Z work reliably in the editor.
- Added a Word-style Markdown ribbon with Bold, Italic, Underline, and Highlight controls in the editor header.
- Fixed editor highlighting so highlights persist in the Markdown/rendered page instead of disappearing after render.
- Changed the editor header controls from circular chrome buttons to flatter hover-only ribbon icons.
- Added a dedicated editor flashcard page opened from the header, instead of showing flashcards as a popup.
- Added cached page flashcard files with source fingerprints and similarity checks so Zirn loads local flashcards first and avoids unnecessary model calls.
- Fixed flashcard generation fallbacks so rate-limit/error text does not become the displayed flashcard content.
- Removed Highlight Flashcards from Home and page summaries while preserving the normal highlighter.
- Removed page-summary flashcard UI and stopped Home generation from asking the model to create page-summary flashcards.
- Improved Home and flashcard generation routing so regenerations use the configured provider instead of one shared model choice.
- Tamed automatic relevance suggestions with steadier dismissal/pause behavior so suggestions do not keep taking over the editor.
- Fixed the follow-up prompt composer so Cmd-Enter submits and the input grows by estimated line count instead of trapping Enter behind an oversized field.
- Updated the app icon assets for the Raxat release.
- Added internal agent/release-state tracking so future handoffs can preserve release status more safely.
- Changed the app version to `1.4` and codename to `Raxat`.

## v1.2 (Mizan)

- Added liquid-glass relevance suggestions while writing Markdown, with in-place wiki-link creation and cursor placement at the end of the inserted link.
- Added page flashcards from the Home page, with question/answer cards, source navigation, close/regenerate controls, and cached `.fcard` storage per vault.
- Fixed Home summary refresh so Zirn reads newly added vault pages without regenerating unchanged existing page summaries.
- Fixed Home summary formatting by keeping the vault overview as a compact paragraph and page summaries as concise bullets without divider artifacts.
- Fixed Home reopening so cached Home content is not regenerated unless the similarity trigger or manual refresh requires it.
- Improved relevance suggestion behavior so it persists until whitespace or dismissal, uses a system/liquid-glass star style, and no longer triggers the normal link autocomplete popup.
- Added `.fcard/` git-ignore coverage for generated flashcard caches.
- Changed the app version to `1.2`.

## v1.1.1 (Mizan)

- Reworked the Sparkle update window into a wide layout with app/version identity on the left and a scrollable changelog on the right.
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
