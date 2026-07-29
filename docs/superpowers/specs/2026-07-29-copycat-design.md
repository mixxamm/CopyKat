# CopyCat — Design

*29 juli 2026*

## Doel

Een open-source macOS clipboard manager als modern alternatief voor Flycut. Belangrijkste verschillen met Flycut: ondersteuning voor afbeeldingen, en een eigentijdse, native uitstraling. Doelgroep: macOS-gebruikers en open-source contributors.

## Productoverzicht

- Menubar-app zonder Dock-icoon (`LSUIElement`).
- Globale hotkey (standaard ⇧⌘V, aanpasbaar) opent een zwevend, Spotlight-achtig paneel in het midden van het scherm.
- In het paneel: zoeken, navigeren met pijltjestoetsen, Enter plakt het geselecteerde item direct in de app die actief was.
- Ondersteunde inhoud: platte tekst, afbeeldingen (PNG/TIFF), bestands-URL's.

## Kernbeslissingen

| Onderwerp | Keuze | Reden |
|---|---|---|
| Stack | Swift + SwiftUI, macOS 14+ | Native performance, native pasteboard-API's, standaard voor moderne open-source macOS-tools |
| UI-vorm | Zwevend paneel (non-activating `NSPanel`) | Modern, ruimte voor previews; focus blijft bij de actieve app zodat direct plakken werkt |
| Stijl | Native glas (vibrancy/blur), SF Symbols, automatisch light/dark | Voelt als onderdeel van macOS |
| Opslag | SwiftData voor metadata/tekst; afbeeldingen als PNG op schijf | Geen zware dependencies; grote blobs horen niet in de database |
| Monitoring | Timer pollt `NSPasteboard.changeCount` (~0,2 s) | macOS biedt geen pasteboard-notificaties |
| Hotkey | `KeyboardShortcuts` (sindresorhus) — enige dependency | Bewezen package, gebruikers kunnen shortcut zelf instellen |
| Licentie | MIT | Maximale toegankelijkheid voor contributors |

## Features (v1)

1. **Clipboard-history** — tekst, afbeeldingen en bestands-URL's; opeenvolgende identieke kopieën worden gededupliceerd; bron-app wordt per item bewaard.
2. **Persistentie** — history overleeft herstarts. Maximum instelbaar (standaard 200 items); afbeeldingen op schijf in Application Support, met thumbnail-cache voor de lijst.
3. **Pins/favorieten** — vastgepinde items staan bovenaan, tellen niet mee voor het maximum en worden nooit automatisch verwijderd.
4. **Privacy** — items met `org.nspasteboard.ConcealedType` of `org.nspasteboard.TransientType` worden genegeerd (wachtwoordmanagers); daarnaast een handmatige lijst van uitgesloten apps (bundle-ID's) in de instellingen.
5. **Direct plakken** — Enter zet het item op het clipboard en simuleert ⌘V via `CGEvent`. Vereist Accessibility-permissie: eenmalige uitleg-UI, met fallback naar alleen-kopiëren als de gebruiker weigert.
6. **Zoeken** — live filteren op tekstinhoud en bron-app-naam.
7. **Instellingen** — hotkey, history-grootte, uitgesloten apps, start bij inloggen (`SMAppService`).

## Architectuur

Kleine, gescheiden componenten met één verantwoordelijkheid:

```
CopyCat/
├── App/            — app-entry, menubar-item, levenscyclus
├── Monitor/        — ClipboardMonitor: pollt NSPasteboard, herkent inhoudstypes,
│                     filtert concealed/transient en uitgesloten apps
├── Store/          — HistoryStore: SwiftData-model, dedupe, limieten, pins;
│                     ImageStore: PNG-bestanden + thumbnails op schijf
├── Panel/          — PanelController (non-activating NSPanel) + SwiftUI-views
│                     (zoekbalk, lijst, preview-pane)
├── Paste/          — PasteService: clipboard zetten + ⌘V simuleren,
│                     Accessibility-permissiecheck
├── Settings/       — SwiftUI Settings-scene
└── Support/        — kleine helpers (app-icoon ophalen, formattering)
```

**Dataflow:** Monitor ziet nieuwe pasteboard-inhoud → geeft een `ClipboardItem`-kandidaat aan de Store → Store dedupliceert, slaat op, handhaaft limiet. Paneel leest uit de Store (gesorteerd: pins eerst, dan op datum). Selectie → PasteService → clipboard + ⌘V → paneel sluit.

**Foutafhandeling:** ontbrekende afbeeldingsbestanden worden stil uit de history verwijderd; geweigerde Accessibility-permissie degradeert naar kopiëren-zonder-plakken met een subtiele hint; opslagfouten loggen via `os.Logger` en laten de app doordraaien.

## UI-detail

- Paneel: zoekbalk bovenin, lijst daaronder, preview-pane rechts van het geselecteerde item.
- Tekstitems: 2-3 regels preview, bron-app-icoon, relatieve tijd.
- Afbeeldingen: thumbnail + afmetingen (bijv. "1280 × 800").
- Pins: pin-icoon, gegroepeerd bovenaan.
- Esc sluit het paneel; klikken buiten het paneel sluit het ook.

## Open source-inrichting

- README met screenshots, feature-overzicht, installatie-instructies en een kort architectuur-overzicht.
- CONTRIBUTING.md (bouwen, teststrategie, code-stijl), MIT LICENSE.
- GitHub Actions: build + tests op elke push/PR.
- Codestijl: gewone, idiomatische Swift; comments alleen waar een keuze niet uit de code blijkt (waarom polling, waarom non-activating panel).

## Testen

- Unit tests: HistoryStore (dedupe, limieten, pin-gedrag), monitor-filterlogica (concealed types, uitgesloten apps), ImageStore (opslaan/laden/opruimen).
- UI: handmatig; het paneel- en plakgedrag is lastig zinvol te automatiseren.

## Buiten scope (v1)

- Sync tussen apparaten, rich text/RTF-opmaak behouden, meerdere clipboards/slots, iOS-versie, Sparkle-updates, App Store-distributie.
