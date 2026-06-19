# Zirn Sparkle OTA Updates

Zirn uses [Sparkle](https://sparkle-project.org/) for over-the-air updates on macOS.

## How it works

1. **App** — On launch, Sparkle reads `SUFeedURL` and checks automatically. **Zirn → Check for Updates…** runs a manual check.
2. **Appcast** — `Sparkle/appcast.xml` on `main` lists versions, download URLs, file size, and an EdDSA signature.
3. **Download & verify** — Sparkle downloads the zip, verifies the signature against `SUPublicEDKey` in `Zirn-Info.plist`, and installs the update.

## Ship an OTA update (recommended)

From your Mac, after bumping **Build** in Xcode:

```bash
scripts/ship-update.sh
```

Then:

1. Upload `dist/Zirn-<version>.dmg` and `dist/Zirn-<version>.zip` to the GitHub Release for `v<version>`.
2. Commit and push `Sparkle/appcast.xml` to `main`.

Or say **"deploy it"** in Cursor — the `deploy-it` skill runs this workflow.
The script signs with a **Developer ID Application** certificate and notarizes
both `build/Zirn.app` and the installer DMG before publishing artifacts. Set
`SKIP_NOTARIZATION=1` only for private local testing.

### Notarization credentials

Install a **Developer ID Application** certificate in Keychain, then store notary
credentials once:

```bash
xcrun notarytool store-credentials ZirnNotary \
  --apple-id "you@example.com" \
  --team-id L22992699P \
  --password "xxxx-xxxx-xxxx-xxxx"
```

The ship scripts default to `NOTARYTOOL_PROFILE=ZirnNotary`. Release signing runs
in `/tmp/ZirnReleaseStage` because codesign rejects Sparkle binaries inside the
iCloud `nosync` workspace folder.

**First-time Apple Developer accounts:** after enrolling, sign all agreements at
[developer.apple.com/account](https://developer.apple.com/account) and
[appstoreconnect.apple.com/agreements](https://appstoreconnect.apple.com/agreements).
The first notarization can take 15–60 minutes; if a submission stays **In
Progress** for hours, check agreements and [Apple System Status](https://developer.apple.com/system-status/)
before submitting again. Duplicate stuck submissions do not affect eligibility —
wait for one result instead of uploading more copies.

If `scripts/ship-update.sh` is interrupted during `--wait`, resume with:

```bash
NOTARY_SUBMISSION_ID=<uuid-from-history> scripts/finish-notarized-release.sh
```

### Website download link

```
https://github.com/aditauqir/zehan/releases/latest/download/Zirn-<version>.dmg
```

### OTA feed URL

```
https://raw.githubusercontent.com/aditauqir/zehan/main/Sparkle/appcast.xml
```

## One-time setup

### EdDSA keys

```bash
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/sparkle-2.6.4.tar.xz" \
  | tar -xJ -C /tmp --strip-components=1
/tmp/bin/generate_keys
/tmp/bin/generate_keys -x ~/.sparkle_eddsa_private_key
```

- **Public key** → `Zirn-Info.plist` as `SUPublicEDKey`
- **Private key** → `~/.sparkle_eddsa_private_key` (local) or GitHub secret `SPARKLE_EDDSA_PRIVATE_KEY` (optional manual CI)

## GitHub Actions (optional)

`.github/workflows/sparkle-release.yml` is **manual only** (`workflow_dispatch`). Use local `scripts/ship-update.sh` for reliable signed releases.

## Update prompt

When an update is found, Zirn shows:

> **New update for Zirn vX.X.X available.**  
> Review what changed, then choose whether to install it now.

Buttons: **Update**, **Don't Update**, **Skip This Version**

After the app relaunches, Zirn shows a **Successfully updated** window with the version and changelog from the appcast.

## Changelog for each release

Before shipping, add release notes for that version:

```bash
Sparkle/release-notes/<version>.html
```

Example: `Sparkle/release-notes/1.0.2.html`

```html
<h2>Zirn 1.0.2</h2>
<ul>
  <li>Your change here</li>
</ul>
```

`scripts/sparkle-release.sh` embeds this HTML into `Sparkle/appcast.xml`. If no version-specific HTML exists, it generates release-note HTML from `PATCH_NOTES.md`. Users see it before choosing to update and after a successful update.
