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
> Want to update?

Buttons: **Update**, **Don't Update**, **Skip This Update**
