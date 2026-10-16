# Starts the game, passing any game arguments through (see the top of scripts/main.gd).
# Usage: tools\run.ps1 [--mode=battle --map=basin ...]
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
# Built as an array: a bare -- on the command line can be eaten by PowerShell.
$argv = @("--path", $root, "--") + $args
& $Godot @argv
