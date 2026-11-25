#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"
configuration="$(printf '%s' "${1:-release}" | tr '[:upper:]' '[:lower:]')"
case "$configuration" in
  debug|release) ;;
  *) printf 'Usage: %s [debug|release]\n' "$0" >&2; exit 2 ;;
esac
source "$root/version.env"

# Preserve CodexBar's SDK stamp so AppKit opts into the system's current menu bar and window behavior.
sdk="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
build_args=(--sdk "$sdk"
  -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$sdk_version")
swift build --configuration "$configuration" "${build_args[@]}" --product InspireBar
products="$(swift build --configuration "$configuration" "${build_args[@]}" --show-bin-path)"
stage="$(mktemp -d "$root/.build/package.XXXXXX")"
trap 'if [[ ! -d "$root/InspireBar.app" && -d "$stage/previous.app" ]]; then
        mv "$stage/previous.app" "$root/InspireBar.app"
      fi
      rm -rf -- "$stage"' EXIT
bundle="$stage/InspireBar.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
install -m 755 "$products/InspireBar" "$bundle/Contents/MacOS/InspireBar"
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
if [[ -d "$root/InspireBar.app" ]]; then
  mv "$root/InspireBar.app" "$stage/previous.app"
fi
mv "$bundle" "$root/InspireBar.app"
printf '%s\n' "$root/InspireBar.app"
