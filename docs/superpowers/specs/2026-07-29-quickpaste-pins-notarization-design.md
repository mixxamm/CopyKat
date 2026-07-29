# Quick paste, pin shortcuts, panel level, notarization — Design

*29 juli 2026 (tweede feature-golf, goedgekeurd in gesprek)*

## 1. ⌘1-9 quick paste in het paneel

- De eerste 9 items van de zichtbare (gefilterde) lijst tonen rechts een subtiele badge `⌘1`…`⌘9` (caption, tertiary).
- ⌘+cijfer plakt dat item direct via het bestaande commit-pad, ook terwijl de zoekbalk focus heeft.
- Pins sorteren eerst en krijgen dus vanzelf de laagste nummers.
- Logica: `PanelViewModel.quickPasteItem(at: Int) -> ClipboardItem?` (1-gebaseerd, nil buiten bereik) — unit-getest.

## 2. Globale shortcuts per gepind item

- `ClipboardItem` krijgt `pinShortcutID: String?`. Toegekend (UUID) bij pinnen, gewist bij unpinnen.
- Nieuwe component `PinShortcutManager` (Paste/): registreert per gepind item een dynamische `KeyboardShortcuts.Name("pastePin-<uuid>")`; `sync()` vergelijkt geregistreerde ids met de huidige pins en registreert/reset het verschil. De diff-beslissing is een pure, geteste functie.
- Handler zoekt het item op en plakt via `AppState.paste(item)` — het plak-deel van `commit` wordt daartoe uitgetrokken (clipboard schrijven + ⌘V of Accessibility-fallback), zonder paneel-interactie.
- `HistoryStore` krijgt een `pinsChanged`-callback (togglePin, delete van gepind item); AppState koppelt die aan `sync()`. Onder tests geen registraties (zelfde guard als de paneel-hotkey).

## 3. Settings: Pins-tab + contextmenu in het paneel

- SettingsView wordt een TabView: **General** (bestaande inhoud) en **Pins**.
- Pins-tab: lijst van gepinde items (icoon/thumbnail + preview) met per item een `KeyboardShortcuts.Recorder` op de dynamische naam. Lege staat: uitleg dat je pint met ⌘P.
- Tab-selectie via `@AppStorage("selectedSettingsTab")` zodat het contextmenu Settings direct op Pins kan openen.
- Contextmenu op elke paneelrij: Pin/Unpin, bij gepinde items "Record Shortcut…" (opent Settings op Pins-tab via `NSApp.activate` + `showSettingsWindow:`-action in een klein `SettingsOpener`-hulpje), en Delete.
- PanelViewModel krijgt item-gerichte varianten `togglePin(_:)` en `delete(_:)` naast de selected-varianten.

## 4. Paneel boven Spotlight

- `FloatingPanel.level` gaat van `.floating` naar `.popUpMenu`, zodat het paneel niet achter Spotlight en vergelijkbare systeem-overlays verdwijnt.

## 5. Genotariseerde releases

- `release.yml` breidt uit: certificaat-import in een tijdelijke keychain, `codesign` met Developer ID + hardened runtime + timestamp, `notarytool submit --wait`, `stapler staple`, zip, release. `MARKETING_VERSION` volgt de tag.
- Vereist vijf door de gebruiker zelf aan te maken GitHub Secrets: `MACOS_CERT_P12` (base64 Developer ID Application p12), `MACOS_CERT_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_PASSWORD` (app-specifiek wachtwoord), `APPLE_TEAM_ID`. Claude raakt deze waardes nooit aan.
- `docs/RELEASING.md` beschrijft de eenmalige setup. README verliest de "isn't notarized"-disclaimer zodra de pipeline staat.

## Buiten scope

- Vim-modus (bewust overgeslagen na afweging: ⌘1-9 + pin-shortcuts dekken de snelheidsbehoefte; modaliteit is complex en raakt fragiele focus-logica).

## Testen

- Unit: quick-paste-indexlogica; pinShortcutID-levenscyclus (pin/unpin/delete); PinShortcutManager-diff.
- Handmatig: badges + ⌘cijfer, contextmenu, Pins-tab recorder, paneel boven Spotlight, en de release-workflow bij de eerstvolgende tag.
