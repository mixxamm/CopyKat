# iPhone companion app

Status: design, not yet planned or built.

## What this is

CopyKat for iPhone, sold as a universal purchase alongside the Mac app. It carries
the history you built up on your Mac in your pocket, lets you paste from it
anywhere through a custom keyboard, and lets you hand things back to the Mac.

The Mac stays the only device that records a clipboard automatically. That is not
a simplification, it is what the platform allows, and the design leans into it
rather than fighting it.

## What iOS allows, and what it does not

These constraints shaped every decision below, so they come first.

**No background capture.** iOS gives no background execution for polling the
pasteboard, and reading pasteboard *contents* raises the system "Allow Paste?"
prompt every time. Only metadata (item count, item types) is free. A Flycut-style
recorder cannot exist on iPhone.

**Reading the clipboard needs an explicit gesture.** `UIPasteControl` is the
sanctioned way: the user taps a system-drawn paste button and the read happens
silently. That is the only clipboard read the app performs.

**Writing the clipboard is free, and reaches the Mac.** The iOS general pasteboard
takes part in Universal Clipboard by default; there is an explicit `localOnly`
option to opt out of it. Writing an item to the pasteboard therefore hands it to
a nearby Mac with no infrastructure of our own.

**A keyboard extension can read the shared container without Full Access.** The
default keyboard sandbox blocks the network and blocks *writing* to the app group
container, but reading is permitted. A paste-from-history keyboard therefore never
has to ask for Full Access, which is both the honest choice and one less thing for
a reviewer to doubt. Custom keyboards never appear in secure text fields; iOS
substitutes the system keyboard there.

**Share extensions have no such restriction.** They may write to the app group
container, so capture from the share sheet is straightforward. They do run under a
tight memory limit, which matters for large images.

## Shape

One bundle identifier, `com.mixxamm.copykat`, across macOS and iOS, which is what
universal purchase requires. Buying either platform unlocks both.

The iPhone side is three targets:

- **The app.** Browse and search the history, own the settings, and run the sync.
  It is the only part that touches the network.
- **The keyboard extension.** The history wherever you type, with search. Reads a
  snapshot from the app group container. No network, no Full Access.
- **The share extension.** Adds whatever you share into the history.

## Sync

CloudKit private database, in the user's own iCloud. Off by default and always
optional.

One master switch, "Sync with iCloud". Under it, only meaningful when the switch is
on, individual toggles for what leaves the Mac:

- Text
- Files
- Images, marked as the one that costs real space
- A limit: everything, only pinned items, or the most recent N plus pinned

The app writes a snapshot into the app group container after each sync; the
keyboard reads only that. This keeps the keyboard free of network access.

**Exclusions apply before sync, not after.** Anything from an ignored app, and
anything marked as a password by the concealed-type convention, never leaves the
Mac at all. Without this the sync becomes a side door around the one guarantee the
app makes.

### What has to change in the existing code

- Every SwiftData attribute needs a default value. `kind`, `contentHash`,
  `createdAt` and `isPinned` currently have none, and CloudKit rejects that.
- Images live as PNG files on disk keyed by SHA256, outside the store. They have to
  move into the model to sync. Existing users need a migration.
- Sync ships in both builds, the free Developer ID one included. It costs us
  nothing, because the data sits in the user's own iCloud, and it is mainly
  worth having for people who also buy the iPhone app.

  Developer ID apps may use CloudKit, but not for free in effort: the build needs
  a Developer ID provisioning profile carrying the iCloud capability, embedded in
  the bundle, which means the release workflow gains a profile alongside the
  certificate it already imports. `com.apple.developer.icloud-container-environment`
  has to be set to Production explicitly; App Store builds get that inferred, and
  Developer ID builds do not, which is the usual place this comes apart.

  Both builds already share the bundle identifier, so they share one CloudKit
  container. Moving between the free and the paid build keeps the synced history.

## Getting things back to the Mac

Tapping an item writes it to the iPhone pasteboard. Universal Clipboard delivers it
to the Mac, where CopyKat records it and already marks it as coming from another
device. No servers, no protocol of our own.

This works only under Handoff's conditions: same Apple Account, Bluetooth and
Wi-Fi on, devices near each other. When those are not met the item still lands on
the iPhone clipboard, which is what tapping it should do anyway, so the failure
mode is invisible rather than broken.

## Capture on the iPhone

Two ways in v1:

- **The share sheet.** Select text in Safari, an image in Photos, a file in Files,
  share to CopyKat. No permission prompt, because the user is handing it over.
- **A paste button in the app**, drawn by `UIPasteControl`, for when something is
  already on the clipboard.

A Shortcuts action through App Intents, hangable off the Action Button or Back Tap,
is a natural third route and is deliberately left for later.

## Compliance

Routine, but none of it optional:

- Privacy manifest (`PrivacyInfo.xcprivacy`) for the app and for both extensions,
  declaring required-reason API use. UserDefaults and the disk-space APIs the
  storage screen uses both fall under this.
- App Privacy answers revisited on both platforms once sync exists.
- Export compliance and age rating for the new app.
- DSA trader status is already in place for the Mac app.

Two items are not routine:

- **The privacy policy and the website have to be rewritten.** "Everything stays on
  your Mac" stops being unconditionally true the moment sync exists, even though
  the data sits in the user's own iCloud rather than on our servers.
- **Guideline 4.2, minimum functionality.** An iPhone app that a reviewer reads as
  a reimplementation of Universal Clipboard gets rejected. The keyboard, the
  searchable history and share-sheet capture are the answer, and all three should
  ship in v1 rather than being held back.

The European Accessibility Act (Directive 2019/882, in force since 28 June 2025)
does not appear to reach us, for two independent reasons. Its product list is
hardware plus operating systems, and standalone applications are not on it; its
service list is telephony, audiovisual media, transport, consumer banking,
e-books, e-commerce and 112, none of which we provide. Even on the widest reading
of "e-commerce services", Article 4(5) exempts microenterprises providing
services, defined in Article 3(23) as fewer than ten people and turnover or
balance sheet at or below EUR 2 million. Worth revisiting if the business ever
outgrows that, and it is a directive, so the Belgian transposition is the text
that actually binds.

None of which is a reason to skip accessibility. A custom keyboard draws its own
keys, so VoiceOver gets nothing unless we label them; doing that while building is
cheap and retrofitting it is not.

## First version

Keyboard, searchable history, text and files, images off by default, opt-in sync,
share sheet and paste button for capture, tap to hand back to the Mac.

Images and the finer sync controls follow once the shape has proven itself.

## Risks

- Rejection under 4.2. Mitigated by shipping the keyboard in v1, not later.
- iCloud quota if images are enabled on a large history. Mitigated by defaulting
  them off and showing what sync would cost.
- Migrating existing Mac users onto a CloudKit-compatible model without losing
  history. This is the change most likely to hurt someone, and deserves its own
  plan.
- Memory limits in the share extension when handling large images.
