# Contributing to KopyKat

## Building

The Xcode project is generated — it is not checked in.

```bash
brew install xcodegen
xcodegen generate
open KopyKat.xcodeproj
```

Re-run `xcodegen generate` whenever you add, move, or delete files, or edit
`project.yml`.

## Testing

```bash
xcodebuild -scheme KopyKat -destination 'platform=macOS' test
```

Core logic (classifier, stores, panel view model) is unit-tested; keep it
that way. Window behavior, pasting, and permissions are verified by hand —
note in your PR what you checked.

## Code style

Plain, idiomatic Swift. A few ground rules:

- Small files with one responsibility; follow the existing folder layout.
- Comments explain *why*, only where the code can't (e.g. why we poll the
  pasteboard). No decorative comments.
- No new dependencies without prior discussion in an issue.

## Pull requests

- Branch from `main`, keep PRs focused on one change.
- Make sure `xcodebuild … test` passes.
- Describe any manual verification you did.
