# Patch Notes

## v1.1

- Added on-device Dice-Sorensen source similarity for Home generation so reopening a vault can skip unnecessary model calls when the vault has only marginal changes.
- Added persisted Home source signatures in generated summary metadata so similarity checks can work across vault reopen sessions.
- Added an automatic Sparkle update checker flow that notifies users when an update is available, shows what changed, and offers Update, Don't Update, or Skip This Version.
- Added release-note generation from `PATCH_NOTES.md` so OTA popup copy and GitHub release notes can use the same versioned source of truth.
- Fixed release delivery safety by requiring Developer ID signing for public builds and adding notarization support before Sparkle/GitHub distribution.
- Changed the app version to `1.1`.
- Improved rendered page spacing near the floating input pill so end-of-page text is not covered.
- Added git ignore coverage for local `.brain` vault files.
- Notes: OTA publishing, appcast updates, and release uploads should still only happen after an explicit ship/release instruction.
