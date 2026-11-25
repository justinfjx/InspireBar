#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
mkdir -p "$root/.build"
stage="$(mktemp -d "$root/.build/icon.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
mkdir "$stage/InspireBar.iconset"
CLANG_MODULE_CACHE_PATH="$root/.build/module-cache" \
  swift "$root/Scripts/render_icon.swift" "$stage/InspireBar.iconset"
iconutil -c icns -o "$stage/Icon.icns" "$stage/InspireBar.iconset"
install -m 644 "$stage/Icon.icns" "$root/Icon.icns"
