#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"
usage() {
  printf 'Usage: %s [debug|release] [--universal] [--output-dir DIRECTORY]\n' "$0" >&2
  exit 2
}

configuration=release
if [[ "$#" -gt 0 && "$1" != --* ]]; then
  configuration="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  shift
fi
case "$configuration" in
  debug|release) ;;
  *) usage ;;
esac
universal=false
destination="$root"
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --universal) universal=true; shift ;;
    --output-dir) [[ "$#" -ge 2 ]] || usage; destination="$(cd "$2" && pwd -P)"; shift 2 ;;
    *) usage ;;
  esac
done
application="$destination/InspireBar.app"
source "$root/version.env"

# Preserve CodexBar's SDK stamp so AppKit opts into the system's current menu bar and window behavior.
sdk="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
build_args=(--sdk "$sdk"
  -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$sdk_version")
build_products() {
  swift build --configuration "$configuration" "${build_args[@]}" "$@" --product InspireBar >&2 || return
  swift build --configuration "$configuration" "${build_args[@]}" "$@" --show-bin-path
}

mkdir -p "$root/.build"
stage="$(mktemp -d "$root/.build/package.XXXXXX")"
trap 'if [[ ! -d "$application" && -d "$stage/previous.app" ]]; then
        mv "$stage/previous.app" "$application"
      fi
      rm -rf -- "$stage"' EXIT
bundle="$stage/InspireBar.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
executable="$bundle/Contents/MacOS/InspireBar"
if "$universal"; then
  products="$(build_products --triple arm64-apple-macosx14.0 --scratch-path "$root/.build/universal/arm64")"
  intel="$(build_products --triple x86_64-apple-macosx14.0 --scratch-path "$root/.build/universal/x86_64")"
  lipo -create "$products/InspireBar" "$intel/InspireBar" -output "$executable"
  chmod 755 "$executable"
else
  products="$(build_products)"
  install -m 755 "$products/InspireBar" "$executable"
fi
ditto "$products/InspireBar_InspireBar.bundle" "$bundle/Contents/Resources/InspireBar_InspireBar.bundle"
install -m 644 "$root/Icon.icns" "$bundle/Contents/Resources/Icon.icns"
install -m 644 "$root/LICENSE" "$bundle/Contents/Resources/LICENSE"
cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleDisplayName</key><string>InspireBar</string>
    <key>CFBundleName</key><string>InspireBar</string>
    <key>CFBundleExecutable</key><string>InspireBar</string>
    <key>CFBundleIdentifier</key><string>io.github.justinfjx.inspirebar</string>
    <key>CFBundleIconFile</key><string>Icon.icns</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>io.github.justinfjx.inspirebar.menu-layout-item</string>
            <key>UTTypeDescription</key><string>InspireBar menu layout item</string>
            <key>UTTypeConformsTo</key><array><string>public.data</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST
plutil -lint "$bundle/Contents/Info.plist"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
if [[ -d "$application" ]]; then
  mv "$application" "$stage/previous.app"
fi
mv "$bundle" "$application"
printf '%s\n' "$application"
