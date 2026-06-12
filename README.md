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

Add your Mistral API key in the Configure Model sheet before using assistant generation or OCR.

## Over-the-air updates (Sparkle)

Zirn checks for updates via Sparkle. Use **Zirn → Check for Updates…** in the menu bar.

Setup, signing keys, and the automated `main` branch release workflow are documented in [Sparkle/README.md](Sparkle/README.md).

## Notes

- The sidebar search field searches matching page titles and document content.
- Duplicate note titles are automatically renamed with an incrementing suffix, for example `Title_(1)`.
- PDF OCR uploads follow Mistral API limits: up to 512 MB per file and 1,000 pages per request.
