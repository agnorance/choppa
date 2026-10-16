#!/usr/bin/env bash
# Bakes the procedural textures (Baked.generators) to assets/textures/baked/*.png and
# re-imports them with VRAM compression and mipmaps. Run after changing a generator.
# Usage: tools/bake.sh
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-godot}"
"$godot" --headless --path "$root" --import > /dev/null 2>&1 || true  # New class_names must be known first.
"$godot" --headless --path "$root" --script res://tools/bake_textures.gd
"$godot" --headless --path "$root" --import > /dev/null 2>&1 || true
for import in "$root"/assets/textures/baked/*.png.import; do
	sed -i -e 's#compress/mode=0#compress/mode=2#' -e 's#compress/high_quality=false#compress/high_quality=true#' \
		-e 's#mipmaps/generate=false#mipmaps/generate=true#' -e 's#detect_3d/compress_to=1#detect_3d/compress_to=0#' "$import"
done
"$godot" --headless --path "$root" --import > /dev/null 2>&1 || true
echo "baked: $(ls "$root"/assets/textures/baked/*.png | wc -l) textures"
