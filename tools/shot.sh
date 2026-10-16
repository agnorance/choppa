#!/usr/bin/env bash
# Renders the game under a virtual display and saves a screenshot.
# Usage: tools/shot.sh out.png [game args...]   e.g. tools/shot.sh out.png --autopilot=roll --frames=75
set -euo pipefail
out="$(realpath -m "$1")"
shift
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --path . --resolution 1280x720 --audio-driver Dummy -- --shot="$out" "$@" 2>&1 \
	| grep -vE "^\s*$|ALSA|audio driver" || true
test -f "$out"
