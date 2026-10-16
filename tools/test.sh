#!/usr/bin/env bash
# Runs the headless test suite (imports first, so new class_names and assets are known).
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
"$godot" --headless --path . --import >/dev/null 2>&1 || true
exec "$godot" --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd
