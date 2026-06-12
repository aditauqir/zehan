# Zirn Sparkle OTA Updates

Zirn uses [Sparkle](https://sparkle-project.org/) for over-the-air updates on macOS.

## How it works

1. **App** — On launch, Sparkle reads `SUFeedURL` and can check the feed automatically. **Zirn → Check for Updates…** runs a manual check.
2. **Appcast** — `Sparkle/appcast.xml` lists available versions, download URLs, file size, and an EdDSA signature.
3. **Download & verify** — Sparkle downloads the zip, verifies the signature against `SUPublicEDKey` in the app, and installs the update.
4. **Release pipeline** — Pushing to `main` runs `.github/workflows/sparkle-release.yml`, which builds a Release app, zips it, signs it, publishes a GitHub Release, and updates the appcast.

## One-time setup

### 1. Generate signing keys

```bash
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/sparkle-2.6.4.tar.xz" \
  | tar -xJ -C /tmp --strip-components=1
/tmp/bin/generate_keys
```

- Copy the **public key** into `Zirn-Info.plist` as `SUPublicEDKey` (already set for this project).
- Export the **private key** for CI: run `/tmp/bin/generate_keys -x` and save the output as GitHub secret `SPARKLE_EDDSA_PRIVATE_KEY`.
- Keep the private key out of git.

### 2. First release (v1.0.0)

```bash
chmod +x scripts/build-release.sh scripts/create-dmg.sh scripts/sparkle-release.sh
scripts/build-release.sh
scripts/sparkle-release.sh 1.0.0
```

This produces:

- `dist/Zirn-<version>.dmg` — drag-to-Applications installer for new users
- `dist/Zirn-<version>.zip` — Sparkle OTA update package (signed via appcast)

Upload **both** to GitHub Releases for `v1.0.0`, then update `Sparkle/appcast.xml` (or let `generate_appcast` rewrite it from the zip).

### 3. GitHub Actions secret

Add `SPARKLE_EDDSA_PRIVATE_KEY` in **Settings → Secrets and variables → Actions** so pushes to `main` can sign and publish updates automatically.

## Update prompt

When an update is found, Zirn shows:

> **New update for Zirn vX.X.X available.**  
> Want to update?

Buttons: **Update**, **Don't Update**, **Skip This Update**

## Feed URL

```
https://raw.githubusercontent.com/aditauqir/zehan/main/Sparkle/appcast.xml
```

Change this in `INFOPLIST_KEY_SUFeedURL` if you use a fork or custom hosting.
