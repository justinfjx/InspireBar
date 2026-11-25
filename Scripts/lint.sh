#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"
export PATH="$root/.build/lint-tools/bin:$PATH"

case "${1:-lint}" in
  lint)
    command -v swiftformat >/dev/null && command -v swiftlint >/dev/null || {
      echo "Run ./Scripts/install_lint_tools.sh to install SwiftFormat and SwiftLint locally." >&2
      exit 1
    }
    swiftformat Sources Tests --lint
    swiftlint lint --strict
    ;;
  format)
    swiftformat Sources Tests
    ;;
  *) printf 'Usage: %s [lint|format]\n' "$0" >&2; exit 2 ;;
esac
