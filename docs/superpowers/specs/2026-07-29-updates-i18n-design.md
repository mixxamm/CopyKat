# Auto-update (Sparkle) en lokalisatie — Design

*29 juli 2026, goedgekeurd in gesprek*

## Auto-update via Sparkle

- Dependency: Sparkle 2 (SPM). `SPUStandardUpdaterController` start bij app-launch (niet onder tests); menu-item "Check for Updates…"; toggle "Automatically check for updates" in Settings > General (zelfde patroon als launch-at-login).
- Feed: `SUFeedURL` = `https://github.com/mixxamm/CopyKat/releases/latest/download/appcast.xml`. De release-workflow genereert `appcast.xml` met Sparkle's `generate_appcast` (EdDSA-key uit secret `SPARKLE_ED_PRIVATE_KEY`) en hangt die naast de zip aan de release. `--download-url-prefix` wijst naar de tag-assets.
- `CURRENT_PROJECT_VERSION` volgt voortaan ook de tag (Sparkle vergelijkt op build-versie).
- `SUPublicEDKey` komt in project.yml zodra de gebruiker die genereert (`generate_keys`); tot die tijd werken updates niet — gedocumenteerd in RELEASING.md. Sleutelmateriaal blijft volledig bij de gebruiker.

## Lokalisatie

- Eén String Catalog (`CopyKat/Localizable.xcstrings`), Engels als bron.
- Talen: nl, de, fr, es, it, pt-PT, pl, uk, ro, sv, ru, zh-Hans, zh-Hant, ja, ko, tr, ar, hi.
- SwiftUI-literals zijn al keys; NSAlert-teksten gaan door `String(localized:)`. App-naam "CopyKat" blijft onvertaald binnen zinnen.
- RTL (Arabisch): SwiftUI spiegelt automatisch; handmatige check van het paneel volstaat voor v1.

## Testen

- Bestaande suite blijft groen; lokalisatie en updater handmatig (updater end-to-end pas testbaar na eerste release met keys).
