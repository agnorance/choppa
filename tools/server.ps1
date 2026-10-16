# Starts a dedicated server without a window: six bot seats that players take over as
# they join. Ctrl+C stops it.
# Usage: tools\server.ps1 [--map=canyon] [--server=7778] [--kills=10] [--lag=100 --loss=2]
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
& $Godot --headless --path $root --import | Out-Null
# Built as an array: a bare -- on the command line can be eaten by PowerShell.
$argv = @("--headless", "--path", $root, "--", "--server") + $args
& $Godot @argv
