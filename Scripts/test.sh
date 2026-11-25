#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -B -m unittest discover -s Tests/InspireReaderTests
exec swift test "$@"
