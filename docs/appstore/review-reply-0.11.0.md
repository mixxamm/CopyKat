# App Review reply, 0.11.0 (Guideline 2.1 information request)

Paste the block below into the reply thread in App Store Connect, and copy it
into App Review Information → Notes for future submissions. Point 1 needs the
screen recording; the shooting script is at the bottom.

---

Hello,

Thank you for the review. Here is the requested information.

**1. Screen recording**

Attached is a recording captured on a physical MacBook Pro running macOS,
starting at app launch and walking through the core flow: onboarding (including
the optional Accessibility permission prompt for direct pasting), copying
several items, opening the panel with Shift-Command-V, fuzzy searching,
pasting into another app, pinning an item, and the Settings window. The app
has no account system, no registration, no login, no purchases or
subscriptions inside the app, and no user-generated content that is shared
with anyone; everything stays on the user's own machine.

**2. Devices and operating systems tested**

- MacBook Pro (Apple silicon), macOS 26 and the current macOS beta
- Build verification through Xcode Cloud/CI on release macOS runners

**3. Purpose and audience**

CopyKat is a clipboard manager for people who work primarily with the
keyboard, such as developers and writers. macOS only remembers the last thing
you copied; CopyKat keeps a searchable history of text, images and files, and
pastes any item straight into the app you are working in via a global
shortcut. The value is not losing work you already copied and not breaking
your flow to recover it.

**4. Setup and access instructions**

No login or sample files are needed. Launch the app, follow the four-step
onboarding, and copy a few pieces of text. Press Shift-Command-V to open the
panel above your current app, type to search, press Return to paste. The
optional Accessibility permission (explained in onboarding and requested via
the standard system prompt) enables pasting directly into other apps; without
it, items are copied to the clipboard for manual pasting. All features are
available immediately after install.

**5. External services**

None. The app uses no data providers, no authentication services, no payment
processors, no analytics, and no AI services. All functionality, including
on-device text recognition in copied images (Apple's Vision framework), runs
locally. The app makes no network connections.

**6. Regional differences**

None. The app functions identically in all regions. The interface is
localized into 18 languages; functionality does not differ per region.

**7. Regulated industries / protected material**

Not applicable. The app contains no third-party protected material and does
not operate in a regulated industry.

Best regards,
Maxim Janssens

---

## Shooting script for the recording (2-3 minutes, QuickTime or ⇧⌘5)

1. Start the recording, then launch CopyKat from the Applications folder.
2. Walk through the onboarding, including the "paste directly" step so the
   system Accessibility prompt appears on camera (you may decline or accept).
3. Copy three things: a sentence from a website, an image, a file in Finder.
4. Press ⇧⌘V: panel appears above the frontmost app. Cycle with arrows.
5. Type a few letters to show fuzzy search finding an item, and one word that
   only appears inside the copied image, to show image search.
6. Press Return to paste into TextEdit or Notes.
7. Pin an item (⌘P), reopen the panel to show it on top.
8. Open Settings from the menu bar icon, scroll through once, close.
9. Stop the recording. No account, purchase or sensitive-data flows exist, so
   nothing else needs to be shown.

Record on the TestFlight (App Store) build, not the GitHub build, so what the
reviewer sees matches the submitted binary: /Applications/CopyKat.app.
