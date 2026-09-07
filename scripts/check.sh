#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 -m unittest discover -s tests -p 'test_*.py' -v
node tests/model.test.cjs
if command -v omarchy >/dev/null 2>&1; then omarchy plugin validate .; fi
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
"${SIDEQUEST_QT_BIN:-/usr/lib/qt6/bin}/qmltestrunner" -input tests -o -,txt
