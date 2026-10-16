# Bakes the procedural textures (Baked.generators) to assets/textures/baked/*.png and
# re-imports them with VRAM compression and mipmaps. Run after changing a generator.
# Usage: tools\bake.ps1
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
& $Godot --headless --path $root --import | Out-Null  # New class_names must be known first.
& $Godot --headless --path $root --script res://tools/bake_textures.gd
& $Godot --headless --path $root --import | Out-Null
foreach ($import in Get-ChildItem "$root\assets\textures\baked\*.png.import") {
	$text = Get-Content $import -Raw
	$text = $text -replace "compress/mode=0", "compress/mode=2" -replace "compress/high_quality=false", "compress/high_quality=true" -replace "mipmaps/generate=false", "mipmaps/generate=true" -replace "detect_3d/compress_to=1", "detect_3d/compress_to=0"
	[System.IO.File]::WriteAllText($import.FullName, $text)
}
& $Godot --headless --path $root --import | Out-Null
Write-Output "baked: $((Get-ChildItem "$root\assets\textures\baked\*.png").Count) textures"
