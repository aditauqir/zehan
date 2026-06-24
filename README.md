# Zirn

Zirn is a local-first macOS writing and knowledge workspace. It stores notes in a brain vault, keeps document links stable, and includes AI assistance through Mistral.

## Requirements

- macOS with Xcode installed
- Xcode command line tools
- A Mistral API key for the default assistant model and OCR

Install or refresh command line tools if needed:

```sh
xcode-select --install
```

## Compile From Xcode

1. Open `Zehan.xcodeproj` in Xcode.
2. Select the `Zehan` scheme.
3. Choose `Product > Clean Build Folder`.
4. Choose `Product > Run`.

## Compile From Terminal

From the repository root, run a clean Debug build:

```sh
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build
```

The compiled app will be created at:

```sh
/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app
```

## Run The App

Open the compiled app from Terminal:

```sh
open /tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app
```

You can also run it directly from Xcode with `Product > Run`.

## Configure AI

In the app, open `Settings > Configure Model`.

- `Mistral` is the assistant provider.
- The default Mistral model is `mistral-large-latest`.
- Mistral OCR uses `mistral-ocr-latest` for PDF uploads.
- Your Mistral API key is stored locally in the app. Use **Add to Keychain** in Configure Model to save it to Apple Passwords as **Zirn** for `api.mistral.ai`.

Add your Mistral or DeepSeek API key in the Configure Models sheet before using assistant generation. Document OCR currently uses Mistral OCR.

## Install Zirn (new users)

Download the latest **Zirn.dmg** from [GitHub Releases](https://github.com/aditauqir/zehan/releases/latest):

```
https://github.com/aditauqir/zehan/releases/latest/download/Zirn-1.4.dmg
```

1. Open the DMG.
2. Drag **Zirn** into **Applications**.
3. Open Zirn from Applications.

### First launch

Each DMG includes `README.txt` with install instructions. Release builds are
**Developer ID signed and notarized** by Apple, so macOS should open them without
a Gatekeeper warning. If macOS still blocks an older download, use **Open** from
the Finder context menu or **Open Anyway** in **System Settings > Privacy & Security**.

Full copy for your website: [Sparkle/INSTALL.md](Sparkle/INSTALL.md)

For a website download button, link to the latest DMG release asset.

Existing users receive updates through Sparkle (**Zirn → Check for Updates…**). The `.zip` on Releases is for OTA only; ship the **`.dmg`** for new installs.

## Over-the-air updates (Sparkle)

Zirn checks for updates via Sparkle. Use **Zirn → Check for Updates…** in the menu bar.

Setup, signing keys, and the automated `main` branch release workflow are documented in [Sparkle/README.md](Sparkle/README.md).

## Continuous Integration

GitHub Actions runs a clean Debug build on pushes and pull requests to `main`, `feature`, and `debug`. Signed Sparkle releases are manual-only and require the Developer ID, notarization, and Sparkle secrets documented in [Sparkle/README.md](Sparkle/README.md).

## Notes

- The sidebar search field searches matching page titles and document content.
- Duplicate note titles are automatically renamed with an incrementing suffix, for example `Title_(1)`.
- PDF OCR uploads follow Mistral API limits: up to 512 MB per file and 1,000 pages per request.
