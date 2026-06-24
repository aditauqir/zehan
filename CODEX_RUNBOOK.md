# Codex Runbook

This repo ships the Zirn macOS app from three local branches:

- `feature`: implementation source of truth
- `debug`: manual testing branch
- `main`: public release branch

## Preflight

1. Check branch state:

```sh
git status --short --branch
git branch --list
git log --oneline --decorate --graph --all -8
```

2. Preserve uncommitted work. Do not reset, force-push, or discard user changes.
3. Fetch remotes:

```sh
git fetch --all --prune
```

4. Fast-forward clean involved branches only:

```sh
git switch main && git merge --ff-only main/main
git switch feature && git merge --ff-only main
git switch debug && git merge --ff-only main
```

If a branch contains intentional unreleased work, keep it and continue from the active branch.

## Local Debug Build

Use this for development verification and manual testing:

```sh
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build
```

Launch the fresh Debug build:

```sh
osascript -e 'quit app "Zirn"' 2>/dev/null || true
pkill -x Zirn 2>/dev/null || true
open /tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app
```

## Stability Acceptance

- Open a normal vault and confirm pages, sidebar search, Home, Help Desk, and Zirn Chat still work.
- Open or scan a vault containing corrupt or oversized Markdown files. Zirn should keep loading readable pages and show a clear status for skipped pages.
- Open a page larger than the supported note limit. Zirn should show a readable error instead of freezing or crashing.
- Edit a long page. The editor may skip rich Markdown styling for very large text, but typing, selection, and saving should remain responsive.

## Wiki-Link Acceptance

Create pages and links with spaces and special characters:

- `[[A page with spaces]]`
- `[[Research #1]]`
- `[[A&B + C]]`
- `[[Unicode سلام]]`

Click links in rendered Markdown surfaces. Valid links should open internally. Missing or malformed Zirn note URLs must not show a macOS "could not open" system dialog.

## GitHub Actions Release Setup

The manual Sparkle release workflow requires these repository secrets:

- `MACOS_CERTIFICATE`: base64 `.p12` Developer ID Application certificate
- `MACOS_CERTIFICATE_PASSWORD`: `.p12` password
- `KEYCHAIN_PASSWORD`: temporary CI keychain password
- `PROVISIONING_PROFILE_BASE64`: base64 Developer ID Application profile for `noortech.Zirn`
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID
- `APP_STORE_CONNECT_PRIVATE_KEY`: full `AuthKey_XXXX.p8` contents
- `SPARKLE_EDDSA_PRIVATE_KEY`: Sparkle EdDSA private key

Release workflow order:

1. Import Developer ID certificate and provisioning profile.
2. Build `build/Zirn.app`.
3. Notarize and staple the app.
4. Create and sign `dist/Zirn-<version>.dmg`.
5. Notarize and staple the DMG.
6. Generate the signed Sparkle zip and appcast.
7. Upload the DMG and zip to GitHub Releases.
8. Commit `Sparkle/appcast.xml`.

## Ship Checklist

- Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` when preparing an actual release.
- Add user-facing entries to `PATCH_NOTES.md`.
- Add `Sparkle/release-notes/<version>.html` only when custom OTA HTML is needed.
- Run the Debug build before handoff to testing.
- Trigger `.github/workflows/sparkle-release.yml` only after explicit release approval.

## Rollback

If notarization or Sparkle signing fails, do not ship partial artifacts. Revert the release commit, delete any failed draft release assets, fix the failing script or secret, and rerun the manual workflow.
