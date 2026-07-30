# App Store metadata

Copy and paste these into App Store Connect. Screenshots are in
`screenshots/` at 2880 x 1800, the largest size Apple accepts.

## Name

CopyKat: Clipboard Manager

## Subtitle (30 characters)

Copy and paste with a memory

## Promotional text (170 characters)

CopyKat remembers what you copy on your Mac: text, images and files. Press a
hotkey, pick an item, and it lands right where you are typing.

## Description

Your Mac remembers exactly one thing you copied. CopyKat remembers the rest.

Press a hotkey and a small panel appears with everything you have copied
lately: text, images, screenshots, and files. Start typing to find the one you
want, hit Return, and it is pasted into the app you were already working in.
The panel never steals focus, so your cursor stays where you left it.

WHAT IT KEEPS

Text, images and files, all searchable. Copy a screenshot and it shows up with
a thumbnail and its dimensions. Copy a file in the Finder and paste it again
later. Items you copied on your iPhone or iPad arrive through Universal
Clipboard and are marked as coming from another device.

FAST WHEN YOU ARE IN A HURRY

The top nine items have their own shortcuts, so Command-1 through Command-9
paste them instantly. Arrow keys walk the list. Turn on Fast paste and you can
hold the hotkey, tap V to run through recent items, and let go to paste,
without ever opening a menu.

SEARCH THAT FORGIVES

Typing "invoce" still finds your invoice. Search matches on content and on the
app you copied from, so "safari" brings up everything you grabbed while
browsing.

PIN WHAT YOU USE EVERY DAY

Pin your address, a license key, or that one snippet you keep retyping. Pinned
items stay at the top and never expire. Give any of them a shortcut of its own
and paste it from anywhere, without opening CopyKat at all.

PRIVATE BY DEFAULT

Everything stays on your Mac. There is no account, no sync service, and no
analytics. Passwords are skipped: apps that mark their clipboard entries as
sensitive are ignored automatically, and common password managers, including
Apple Passwords, are excluded out of the box. You can add any other app to the
ignore list yourself.

BUILT FOR macOS

CopyKat is a native app written in Swift. It lives in the menu bar, weighs a
couple of megabytes, and speaks 18 languages. Requires macOS 14 or later.

CopyKat is open source under the MIT license. You can read every line at
github.com/mixxamm/CopyKat.

## Keywords (100 characters)

clipboard,history,paste,copy,manager,snippet,pasteboard,shortcut,productivity,utility

## Support URL

https://github.com/mixxamm/CopyKat

## Marketing URL

https://copykat.dev

## What's New in this version

First release.

## App Review notes

CopyKat is a clipboard manager. To paste a selected item into the app the user
was working in, it asks for the Accessibility permission and uses it for one
purpose only: sending a Command-V keystroke to the frontmost application after
the user picks an item. It does not read, observe or record anything from other
applications through that permission.

The permission is optional. It is requested the first time the user pastes, and
if it is not granted the app simply copies the item to the clipboard so the
user can paste it manually. Everything else in the app works without it.

To test: copy a few things, press Shift-Command-V to open the panel, select an
item and press Return.

## Privacy

Data collection: none. The app has no network calls, no account, no analytics
and no third-party SDKs that collect data. Clipboard history is stored only in
the app's own container on the user's Mac.

Privacy policy URL: https://copykat.dev/privacy (to publish with the site)

## Age rating

4+, no objectionable content.

## Category

Primary: Productivity
Secondary: Utilities
