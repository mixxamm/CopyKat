# Store screenshots and metadata pipeline

Everything the App Store listing needs, generated from the app itself and
uploaded in one command, for all 19 store languages.

## What is where

- `captions.json` holds the three headlines per language.
- `make.sh` launches the app in demo mode per language, captures the panel, the
  search state and the settings window, and composes each one onto the brand
  gradient at 2880 x 1800, the largest size Apple accepts.
- `compose.swift` does the cropping and the caption drawing. AppKit renders the
  text, so Arabic, Hindi and CJK shape correctly.
- `../../fastlane/metadata/<locale>/` holds the store texts per language.
- `../../fastlane/screenshots/<locale>/` is where the images land.

The demo history is seeded by the app when `COPYKAT_DEMO` is set, so the
screenshots never show real clipboard content.

## Regenerate the screenshots

```bash
xcodebuild -scheme CopyKat -destination 'platform=macOS' build
./scripts/screenshots/make.sh
```

Pass locales to do only some of them: `./scripts/screenshots/make.sh nl-NL de-DE`.

The script drives the real UI, so leave the machine alone while it runs. It
takes about five minutes for all languages.

## Upload

Install fastlane once:

```bash
brew install fastlane
```

Set the API key details, which are not secrets:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

The private key itself belongs at
`~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8` and should never be
committed.

```bash
fastlane mac metadata      # texts and screenshots, no submission
fastlane mac screenshots   # regenerate everything first, then upload
```

Neither lane submits the app for review. That stays a deliberate click in App
Store Connect.
