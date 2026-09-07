#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
exec "${SIDEQUEST_QT_BIN:-/usr/lib/qt6/bin}/qml" tests/Render.qml -- "$@"
