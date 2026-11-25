#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"
bundle="$root/InspireBar.app"
binary="$bundle/Contents/MacOS/InspireBar"

stop_local_app() {
  local pid
  while read -r pid; do
    [[ -z "$pid" ]] || kill -TERM "$pid"
  done < <(ps -ax -o pid= -o comm= | awk -v executable="$binary" '
    { pid = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0 == executable) print pid }
  ')
}

configuration=debug
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --test) "$root/Scripts/test.sh"; shift ;;
    --release) configuration=release; shift ;;
    --stop) stop_local_app; exit 0 ;;
    --) shift; break ;;
    *) printf 'Usage: %s [--test] [--release] [--stop] [-- app-arguments]\n' "$0" >&2; exit 2 ;;
  esac
done

"$root/Scripts/package_app.sh" "$configuration"
stop_local_app
open -n "$bundle" --args "$@"
