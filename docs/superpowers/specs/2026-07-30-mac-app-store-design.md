# CopyKat in de Mac App Store — Design

*30 juli 2026, goedgekeurd in gesprek*

## Doel

CopyKat als betaalde app (€5,99) in de Mac App Store, functioneel identiek aan de
huidige versie, inclusief direct plakken via de Accessibility-permissie. De
gratis, genotariseerde download op GitHub blijft bestaan naast de betaalde
App Store-versie.

## Beslissingen

| Onderwerp | Keuze |
|---|---|
| Functionaliteit | Identiek aan de directe versie, inclusief direct plakken |
| Distributie | Beide: GitHub gratis (met Sparkle), App Store betaald |
| Prijs | €5,99 |
| Bundle ID | `dev.mixxamm.CopyKat` voor beide builds |
| Migratie bestaande geschiedenis | Niet in v1 (sandbox-container is gescheiden) |
| Eerste upload | Handmatig via Xcode Organizer; CI-automatisering later |

## 1. Twee builds uit één codebase

`project.yml` krijgt een tweede applicatietarget dat dezelfde bronnen deelt:

- **CopyKat** (bestaand): Developer ID, ongesandboxed, Sparkle, `release.yml`.
- **CopyKat-MAS** (nieuw): App Sandbox, geen Sparkle-dependency, Apple
  Distribution-ondertekening, compilatievlag `MAS`.

Sparkle wordt alleen in `CopyKat/App/AppState.swift` gebruikt (updater-property,
init, menu-item). Die plekken komen in `#if !MAS`-blokken; het menu-item
"Check for Updates…" verdwijnt daarmee uit de App Store-build.

Gedeelde targetinstellingen gaan naar een XcodeGen-template zodat de twee
targets niet uit elkaar lopen.

## 2. Sandbox

Entitlements voor het MAS-target:

- `com.apple.security.app-sandbox`: true (verplicht)
- `com.apple.security.files.user-selected.read-only`: true (bladerknop bij
  "Ignored apps")

Werkt ongewijzigd binnen de sandbox: klembord lezen/schrijven, globale sneltoets
(`RegisterEventHotKey` via KeyboardShortcuts), lokale event-monitors voor fast
paste, `SMAppService` voor start bij inloggen, app-iconen via LaunchServices,
SwiftData in de container, en het openen van de Systeeminstellingen-URL.

Bekende gevolgen:

1. **Gescheiden opslag.** De sandbox-container is een ander pad dan
   `~/Library/Application Support/CopyKat`. Wie overstapt begint leeg. Geen
   migratie in v1; een importfunctie via een bladervenster is een latere klus.
2. **Bestands-items.** Bij het terugplakken schrijven we een file-URL zonder de
   sandbox-toegang van het origineel. Moet getest worden zodra de sandbox-build
   draait; als het niet betrouwbaar werkt, tonen we bestands-items in de
   MAS-build als alleen-kopieerbaar in plaats van stilletjes te falen.

## 3. Eigen Instellingen-venster (vervangt de verborgen selector)

`SettingsOpener` roept nu `Selector(("showSettingsWindow:"))` aan: een
ongedocumenteerde methode. Dat is een afwijzingsgrond (richtlijn 2.5.1, alleen
publieke API's) en kan bij elke macOS-update breken.

Vervanging: een `SettingsWindowController` naar het model van de bestaande
`OnboardingController` — `NSWindow` + `NSHostingController` rond de huidige
`SettingsView`, met titel en herbruikbaar venster. Het menubalk-item en ⌘,
openen dat venster; het contextmenu in het paneel ("Record Shortcut…") roept
dezelfde controller aan met de Pins-tab geselecteerd. De SwiftUI
`Settings`-scene en `SettingsLink` verdwijnen. Geldt voor beide builds.

## 4. Reviewrisico rond direct plakken

Apple wijst clipboardmanagers geregeld af onder richtlijn 2.4.5 wanneer ze
`CGEvent.post` gebruiken; Paste en Pastebot 3 staan er wél mee in de Store.
Risicobeperking:

- De app is volledig bruikbaar zonder de permissie (valt terug op alleen
  kopiëren) en vraagt hem pas bij de eerste plakpoging.
- Reviewnotitie in App Store Connect legt uit: de permissie dient uitsluitend om
  ⌘V naar de actieve app te sturen nadat de gebruiker een item koos, er wordt
  niets gelezen van andere apps, en de app werkt zonder de permissie.
- Bij afwijzing is de terugvaloptie: MAS-build zonder direct plakken uitbrengen
  (alleen kopiëren) en de directe download houdt de functie.

## 5. Metadata en teksten

Nodig voor het app-record: naam CopyKat, categorie Productiviteit, prijs €5,99,
leeftijdsclassificatie, privacylabel "geen gegevensverzameling", screenshots
(1280×800 of 2560×1600), beschrijving en trefwoorden, plus twee URL's:

- **Privacyverklaring**: te schrijven en te publiceren op de marketingsite
  (`~/Developer/Projects/design-github-pages-copykat`), die daarvoor eerst
  gedeployed moet worden.
- **Support**: de GitHub-repository.

De beschrijving komt er in het Engels; extra talen zijn optioneel later.

## 6. Wat de gebruiker zelf doet

Niet door Claude uit te voeren: de Paid Apps-overeenkomst accepteren, bank- en
belastinggegevens invullen, en het uiteindelijke indienen. Claude kan de
schermen wel via de browser aanwijzen en alle voorbereidende stappen doen.

## Volgorde

1. App App Store-klaar maken: MAS-target, entitlements, Sparkle achter `MAS`,
   eigen Instellingen-venster, sandbox-build lokaal testen (inclusief
   bestands-items en direct plakken).
2. Metadata voorbereiden: privacyverklaring, screenshots, beschrijving,
   reviewnotitie.
3. App Store Connect samen doorlopen en indienen.

## Testen

Bestaande suite (64 tests) blijft groen voor beide targets. Nieuw: unittests
blijven op het bestaande target draaien; het sandbox-gedrag en het
Instellingen-venster worden handmatig geverifieerd in een sandbox-build.
