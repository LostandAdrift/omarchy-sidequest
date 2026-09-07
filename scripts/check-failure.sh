#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
sidequest_fault="${1:-malformed}"
case "$sidequest_fault" in malformed|crash|stall) ;; *) exit 2 ;; esac
sidequest_test_dir="$(mktemp -d /tmp/sidequest-fault.XXXXXX)"
trap 'rm -rf -- "$sidequest_test_dir"' EXIT
mkdir -m 700 "$sidequest_test_dir/run"
mkdir -p "$sidequest_test_dir/runtime" "$sidequest_test_dir/scripts"
cp tests/NativeFailure.qml "$sidequest_test_dir/shell.qml"
cp Model.js "$sidequest_test_dir/"
cp runtime/Library.qml runtime/qmldir "$sidequest_test_dir/runtime/"
cp tests/failing_helper.py "$sidequest_test_dir/scripts/sidequest.py"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
SIDEQUEST_FIXTURE_FAILURE="$sidequest_fault" XDG_STATE_HOME="$sidequest_test_dir" XDG_RUNTIME_DIR="$sidequest_test_dir/run" \
  env -u WAYLAND_DISPLAY -u DISPLAY timeout 20s quickshell -p "$sidequest_test_dir/shell.qml" --no-color
