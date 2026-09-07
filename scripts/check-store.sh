#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
sidequest_test_state="$(mktemp -d /tmp/sidequest-store.XXXXXX)"
trap 'rm -rf -- "$sidequest_test_state"' EXIT
mkdir -m 700 "$sidequest_test_state/run"
mkdir -p "$sidequest_test_state/runtime" "$sidequest_test_state/scripts"
cp tests/NativeStore.qml "$sidequest_test_state/shell.qml"
cp Model.js "$sidequest_test_state/"
cp runtime/Library.qml runtime/qmldir "$sidequest_test_state/runtime/"
cp scripts/sidequest.py "$sidequest_test_state/scripts/"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
XDG_STATE_HOME="$sidequest_test_state" XDG_RUNTIME_DIR="$sidequest_test_state/run" \
  env -u WAYLAND_DISPLAY -u DISPLAY timeout 20s quickshell -p "$sidequest_test_state/shell.qml" --no-color
