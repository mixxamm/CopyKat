# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Primary: developers and productivity-obsessed keyboard people on the Mac, the
kind who never reach for the mouse and live by hotkeys. The app must stay
understandable for less technical people, but the centre of gravity is the
power user; features like vim navigation, ⌘1-9 quick paste and fast paste
exist for them. The iPhone companion aims a notch broader than the Mac app.

## Product Purpose

CopyKat is a native clipboard manager: the Mac remembers everything you copy
(text, images, files), makes it searchable in a panel above everything
including Spotlight, and pastes it straight where you work. The iPhone app
carries that history in your pocket, pastes it through a custom keyboard, and
hands things back to the Mac. Success in a year: the free GitHub build and
the paid App Store build both first-class, reputation and revenue in balance.

## Positioning

Local-first and honest about it: everything stays on your devices, sync is
opt-in through the user's own iCloud, nothing ever touches our servers. The
keyboard works without Full Access. A neighbouring clipboard manager built on
a cloud account cannot truthfully copy this claim.

## Operating Context

Lives in the flow of work: a global hotkey (⇧⌘V), a panel that appears over
whatever the user is doing, one keystroke to paste, gone again. On iPhone:
the share sheet, a paste button, and the picker keyboard inside other apps.

## Capabilities and Constraints

- Dual distribution that must not drift apart: notarized Developer ID build
  with Sparkle on GitHub (free), sandboxed build on the Mac App Store
  (paid, €5.99), universal purchase with the iOS app under one bundle ID.
- 18 languages; every user-facing string ships translated in
  `CopyKat/Localizable.xcstrings`.
- Vision indexing (OCR, QR, labels) runs on device only.
- Password managers are excluded from capture by default; exclusions apply
  before sync, never after.
- Sync is transport-agnostic behind `SyncTransport`; CloudKit today, a
  local-network transport is anticipated for storage-conscious users.
- iOS cannot capture the clipboard in the background; capture there is
  always an explicit user act.

## Brand Commitments

- Name: CopyKat, styled with the capital K. Domain: copykat.dev.
- The cat: `cat.fill` in app surfaces, the white cat on the orange gradient
  tile as the icon everywhere.
- Brand orange sampled from the icon, #FFB758 falling to #F48037; used for
  identity and interaction, never for body text.
- Voice: human and direct, no em-dashes, never reads as AI-generated. Dutch
  founder, English-first product copy.

## Evidence on Hand

- Marketing site content at copykat.dev (support and privacy pages live).
- App Store listing in 19 locales with generated screenshots
  (`fastlane/metadata`, `scripts/screenshots/`).
- Real reviews and users exist; no testimonials collected yet, so none may
  be invented.

## Product Principles

- The keyboard is the interface: every core action must be reachable and
  fast without the mouse; the mouse path is the courtesy, not the design.
- Privacy claims are architecture, not copy: if the website says local,
  the code must make it true by construction.
- Both channels are first-class: a feature ships to GitHub and the App
  Store, or it ships to neither.
- Calm by default: no distracting motion, no surprise reordering; the
  user's eyes stay where they were.

## Accessibility & Inclusion

No explicit product commitment recorded (deliberate). Current practice that
should not regress: VoiceOver labels on custom controls including the
keyboard, reduced-motion respected on the Mac panel.
