#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
sidequest_frames="$(mktemp -d /tmp/sidequest-film.XXXXXX)"
trap 'rm -rf -- "$sidequest_frames"' EXIT
sidequest_video="${1:-docs/assets/sidequest.webm}"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
"${SIDEQUEST_QT_BIN:-/usr/lib/qt6/bin}/qml" tests/Film.qml -- --output "$sidequest_frames"
ffmpeg -hide_banner -loglevel error -y -framerate 20 -i "$sidequest_frames/frame-%04d.png" \
  -c:v libvpx-vp9 -crf 34 -b:v 0 -pix_fmt yuv420p -an "$sidequest_video"
