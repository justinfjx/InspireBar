#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$root/version.env"

output="$root/.build/dist"
mkdir -p "$output"
stage="$(mktemp -d "$root/.build/dmg.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT

volume="$stage/volume"
mkdir "$volume"
"$root/Scripts/package_app.sh" release --universal --output-dir "$volume"
ln -s /Applications "$volume/Applications"

filename="InspireBar-${MARKETING_VERSION}-macos-universal.dmg"
hdiutil create -quiet -volname InspireBar -srcfolder "$volume" -fs HFS+ -format UDZO "$stage/$filename"
mv -f "$stage/$filename" "$output/$filename"
printf '%s\n' "$output/$filename"
