#!/bin/bash
# Draws the captions onto captures that make.sh already took. Useful when only
# the translations changed: no need to drive the UI again.
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT=$(pwd)
RAW="${COPYKAT_RAW_DIR:-/tmp/copykat-shots}"
CAPTIONS="$ROOT/scripts/screenshots/captions.json"
COMPOSE="$ROOT/scripts/screenshots/compose.swift"
OUT_ROOT="$ROOT/fastlane/screenshots"

scene_index() {
  case "$1" in
    panel) echo 0 ;;
    search) echo 1 ;;
    settings) echo 2 ;;
  esac
}

for rect_file in "$RAW"/*.rect; do
  base=$(basename "$rect_file" .rect)
  scene=${base##*-}
  locale=${base%-*}
  index=$(scene_index "$scene")

  caption=$(python3 -c "
import json
data = json.load(open('$CAPTIONS'))
entry = data.get('$locale')
print(entry[$index].replace(chr(10), '\\\\n') if entry else '')
")
  if [ -z "$caption" ]; then
    echo "  ! $locale: no caption, skipped"
    continue
  fi

  rtl=ltr
  [ "$locale" = "ar-SA" ] && rtl=rtl
  keys=nokeys
  [ "$scene" = "panel" ] && keys=keys

  read -r x y w h < "$rect_file"
  mkdir -p "$OUT_ROOT/$locale"
  swift "$COMPOSE" "$RAW/$base.png" "$x" "$y" "$w" "$h" "$caption" \
    "$OUT_ROOT/$locale/$((index + 1))-$scene.png" "$rtl" "$keys" >/dev/null
  echo "  $locale/$scene"
done

echo "Done."
