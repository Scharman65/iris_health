#!/usr/bin/env bash
set -euo pipefail
if command -v fvm >/dev/null 2>&1; then FLUTTER="fvm flutter"; else FLUTTER="flutter"; fi
$FLUTTER --version
dart format lib/ test/ || true
dart analyze
( cd ios && pod install )
echo "OK"
