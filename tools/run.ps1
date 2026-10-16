# Starts the game, passing any game arguments through (see the top of scripts/main.gd).
# Usage: tools\run.ps1 [--mode=battle --map=basin ...]
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
# A script added or renamed since the last import (e.g. after git pull) is unknown to the
# class cache, and every script that mentions it fails to compile. Re-import when needed.
$cache = Get-Item "$root\.godot\global_script_class_cache.cfg" -ErrorAction SilentlyContinue
$newest = (Get-ChildItem "$root\scripts\*.gd", "$root\assets" -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
if (-not $cache -or $cache.LastWriteTime -lt $newest) {
	Write-Output "importing..."
	& $Godot --headless --path $root --import | Out-Null
}
# Built as an array: a bare -- on the command line can be eaten by PowerShell.
$argv = @("--path", $root, "--") + $args
& $Godot @argv
