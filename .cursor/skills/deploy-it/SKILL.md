---
name: deploy-it
description: >-
  When the user approves a release (e.g. "deploy it", "ship the update", "looks
  good deploy", "release OTA"), build Zirn locally, publish Sparkle OTA artifacts,
  push appcast to main, and upload GitHub Release assets. Use for Zirn macOS OTA
  shipping after the user confirms the app looks good.
---

# Deploy It — OTA Release

Ship a Sparkle over-the-air update from the Mac. **Do not rely on GitHub Actions
auto-release** — local builds are properly signed and match what users expect.

## Trigger phrases

- deploy it
- ship the update
- release OTA
- looks good deploy
- deploy the update

Run **looks-good** first if the user has not already tested the app in this session.

## Prerequisites

Before shipping, bump **Build** (`CURRENT_PROJECT_VERSION`) in Xcode when the
marketing version stays the same. Sparkle compares `sparkle:version` (build number)
— it must increase for every OTA release.

## Workflow

```
Deploy progress:
- [ ] Step 1: Refresh app (Debug build + open)
- [ ] Step 2: Bump build number if needed
- [ ] Step 3: Run scripts/ship-update.sh
- [ ] Step 4: Commit code + Sparkle/appcast.xml
- [ ] Step 5: Push main and feature/addon
- [ ] Step 6: Upload GitHub Release assets
- [ ] Step 7: Report download URLs
```

### Step 1: Refresh app

```bash
.cursor/skills/native-mac-app/scripts/refresh-app.sh
```

Use `required_permissions: ["all"]`. Fix build errors before continuing.

### Step 2: Bump build number

If `CURRENT_PROJECT_VERSION` was not increased since the last release, increment
it in `Zehan.xcodeproj/project.pbxproj` (Debug and Release).

### Step 3: Ship update locally

EdDSA key must exist at `~/.sparkle_eddsa_private_key` (from Sparkle
`generate_keys`).

```bash
chmod +x scripts/ship-update.sh
scripts/ship-update.sh
```

Use `required_permissions: ["all"]`.

### Step 4: Commit

Commit app changes and `Sparkle/appcast.xml`. Never commit `dist/` or keys.

### Step 5: Push both branches

Remote is named `main` (not `origin`):

```bash
git push main main
git push main feature/addon
```

Sync `feature/addon` with `main` first if needed.

### Step 6: GitHub Release

Upload from `dist/`:

- `Zirn-<version>.dmg`
- `Zirn-<version>.zip`

Create or update release tag `v<version>` on GitHub. Use `gh release upload`
if `gh` is authenticated, otherwise tell the user to upload via the GitHub UI.

### Step 7: Report

Tell the user:

1. OTA feed: `https://raw.githubusercontent.com/aditauqir/zehan/main/Sparkle/appcast.xml`
2. Website download: `https://github.com/aditauqir/zehan/releases/latest/download/Zirn-<version>.dmg`
3. Users update via **Zirn → Check for Updates…**

## Rules

- Never commit private keys or `dist/` artifacts
- Never force-push to main
- Appcast signature and zip `length` must match the uploaded release zip
- Optional: verify with `sign_update --verify` before pushing appcast
