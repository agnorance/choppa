# Runs the headless test suite (imports first, so new class_names and assets are known).
# Usage: tools\test.ps1
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
& $Godot --headless --path $root --import | Out-Null
& $Godot --headless --fixed-fps 60 --path $root --script res://tests/run_tests.gd
exit $LASTEXITCODE
