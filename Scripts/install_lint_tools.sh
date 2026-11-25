#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
bin="$root/.build/lint-tools/bin"
mkdir -p "$bin"

install_tool() {
  local tool="$1" version="$2" url="$3" checksum="$4"
  if [[ -x "$bin/$tool" ]] && [[ "$("$bin/$tool" --version)" == "$version" ]]; then
    return
  fi
  (
    stage="$(mktemp -d "$root/.build/lint-tools/download.XXXXXX")"
    trap 'rm -rf -- "$stage"' EXIT
    curl -fLSs --max-time 90 -o "$stage/tool.zip" "$url"
    printf '%s  %s\n' "$checksum" "$stage/tool.zip" | shasum -a 256 --check --status
    unzip -q "$stage/tool.zip" -d "$stage"
    tool_path="$(find "$stage" -type f -name "$tool" -print -quit)"
    install -m 755 "$tool_path" "$bin/$tool"
  )
}

install_tool swiftformat 0.63.0 \
  https://github.com/nicklockwood/SwiftFormat/releases/download/0.63.0/swiftformat.zip \
  28c7802e11fa5ae113d903066439c6bb1be20a8ac1ad9709c42616a7e273fb0f
install_tool swiftlint 0.65.1 \
  https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip \
  c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
