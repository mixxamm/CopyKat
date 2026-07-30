#!/bin/bash
# Builds App Store screenshots for every language, straight from the running
# app. Each scene is launched in demo mode with a seeded history, captured, and
# composed onto the brand gradient with a translated caption.
#
#   ./scripts/screenshots/make.sh            all locales
#   ./scripts/screenshots/make.sh en-US nl-NL  just these
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT=$(pwd)
CAPTIONS="$ROOT/scripts/screenshots/captions.json"
RAW="${COPYKAT_RAW_DIR:-/tmp/copykat-shots}"
mkdir -p "$RAW"
OUT_ROOT="$ROOT/fastlane/screenshots"
COMPOSE="$ROOT/scripts/screenshots/compose.swift"

# App Store locale -> the language the app itself should run in. A case, not an
# associative array, because macOS still ships bash 3.2.
app_language() {
  case "$1" in
    en-US) echo en ;;
    nl-NL) echo nl ;;
    de-DE) echo de ;;
    fr-FR) echo fr ;;
    es-ES) echo es ;;
    pt-PT) echo pt-PT ;;
    ar-SA) echo ar ;;
    *) echo "$1" ;;
  esac
}

LOCALES=("$@")
if [ ${#LOCALES[@]} -eq 0 ]; then
  LOCALES=(en-US nl-NL de-DE fr-FR es-ES it pt-PT pl uk ro sv ru zh-Hans zh-Hant ja ko tr ar-SA hi)
fi

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*CopyKat*/Build/Products/Debug/CopyKat.app' -maxdepth 8 | head -1)
if [ -z "$APP" ]; then
  echo "No built CopyKat.app found. Run: xcodebuild -scheme CopyKat -destination 'platform=macOS' build"
  exit 1
fi

# Window sizes tell the panel and the settings window apart in the window list.
window_rect() {
  local want_w=$1
  swift - "$want_w" <<'SWIFT'
import CoreGraphics
import Foundation
let want = Int(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == "CopyKat" {
    let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    if Int(b["Width"] ?? 0) == want {
        print("\(Int(b["X"]!)) \(Int(b["Y"]!)) \(Int(b["Width"]!)) \(Int(b["Height"]!))")
        exit(0)
    }
}
SWIFT
}

capture_scene() {
  local locale=$1 scene=$2 index=$3 width=$4
  local lang
  lang=$(app_language "$locale")
  local caption
  # Missing translation is fine here: capture now, add the caption later.
  caption=$(python3 -c "
import json
data = json.load(open('$CAPTIONS'))
entry = data.get('$locale')
print(entry[$index].replace(chr(10), '\\\\n') if entry else '')
")
  local rtl=ltr
  [ "$locale" = "ar-SA" ] && rtl=rtl

  pkill -x CopyKat 2>/dev/null || true
  sleep 0.8
  COPYKAT_DEMO="$scene" "$APP/Contents/MacOS/CopyKat" -AppleLanguages "($lang)" >/dev/null 2>&1 &
  sleep 3.6

  local rect
  rect=$(window_rect "$width")
  if [ -z "$rect" ]; then
    echo "  ! $locale/$scene: window not found, skipped"
    pkill -x CopyKat 2>/dev/null || true
    return
  fi

  screencapture -x "$RAW/$locale-$scene.png"
  echo "$rect" > "$RAW/$locale-$scene.rect"
  pkill -x CopyKat 2>/dev/null || true

  if [ -n "$caption" ]; then
    mkdir -p "$OUT_ROOT/$locale"
    # shellcheck disable=SC2086
    local keys=nokeys
    [ "$scene" = "panel" ] && keys=keys
    swift "$COMPOSE" "$RAW/$locale-$scene.png" $rect "$caption" \
      "$OUT_ROOT/$locale/$((index + 1))-$scene.png" "$rtl" "$keys" >/dev/null
  fi
  echo "  $locale/$scene"
}

for locale in "${LOCALES[@]}"; do
  echo "$locale"
  capture_scene "$locale" panel 0 720
  capture_scene "$locale" search 1 720
  capture_scene "$locale" settings 2 480
done

echo "Done. Screenshots in fastlane/screenshots/<locale>/"
