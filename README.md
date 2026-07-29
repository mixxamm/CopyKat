# KopyKat

A fast, native clipboard manager for macOS. Press a hotkey, see everything you
copied — text **and images** — and paste it straight into the app you're
working in.

Built as a modern alternative to Flycut: same muscle memory, plus image
support and a Spotlight-style interface.

## Features

- **Text, images, and files** — everything you copy is captured, including
  screenshots and copied images.
- **Spotlight-style panel** — press ⇧⌘V (configurable), search, hit Enter.
  The panel never steals focus from the app you're in.
- **Direct paste** — selecting an item pastes it immediately into the active
  app (with your permission; falls back to copy-only).
- **Pins** — pin items to keep them at the top forever.
- **Privacy-aware** — entries from password managers are ignored
  automatically, and you can exclude any app yourself.
- **Persistent** — history survives restarts. You decide how much to keep.

## Install

Requires macOS 14 or later.

Build from source (no binaries yet):

```bash
brew install xcodegen
git clone https://github.com/mixxamm/KopyKat.git
cd KopyKat
xcodegen generate
xcodebuild -scheme KopyKat -destination 'platform=macOS' build
```

The app lands in Xcode's DerivedData; open the project in Xcode and ⌘R for
day-to-day use.

## How it works

KopyKat is a menubar app with a deliberately small core:

| Component | Role |
|---|---|
| `Monitor/` | Polls `NSPasteboard` (macOS offers no change notifications) and classifies new content |
| `Store/` | SwiftData-backed history; images live as PNG files on disk, deduplicated by content hash |
| `Panel/` | Non-activating `NSPanel` hosting the SwiftUI search panel, so focus stays in your app |
| `Paste/` | Writes the selection back to the clipboard and simulates ⌘V (Accessibility permission) |
| `Settings/` | Hotkey, history size, excluded apps, launch at login |

Sensitive clipboard entries marked with
[`org.nspasteboard.ConcealedType`](http://nspasteboard.org) are never stored.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and PRs welcome.

## License

[MIT](LICENSE)
