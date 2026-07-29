# Contributing to CopyKat

## Building

The Xcode project is generated and not checked in:

```bash
brew install xcodegen
xcodegen generate
open CopyKat.xcodeproj
```

Re-run `xcodegen generate` whenever you add, move, or delete files, or edit
`project.yml`.

## Testing

```bash
xcodebuild -scheme CopyKat -destination 'platform=macOS' test
```

Core logic (the classifier, the stores, the panel view model) is unit-tested,
and we'd like to keep it that way. Window behavior, pasting, and permissions
are verified by hand, so note in your PR what you checked.

## Code style

Plain, idiomatic Swift. A few ground rules:

- Small files with one responsibility. Follow the existing folder layout.
- Comments explain *why*, and only where the code can't (for example, why we
  poll the pasteboard). No decorative comments.
- No new dependencies without prior discussion in an issue.

## Pull requests

- Branch from `main` and keep PRs focused on one change.
- Make sure `xcodebuild … test` passes.
- Describe any manual verification you did.
