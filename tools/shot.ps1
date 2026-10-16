# Plays the game until a physics tick and saves a screenshot (Windows, real GPU).
# Usage: tools\shot.ps1 out.png [game args...]
#   e.g. tools\shot.ps1 shot.png --map=basin --autopilot=hover --cam=showcase --frames=150
# --fixed-fps keeps every frame 1/60 s, so timed effects (--explode) land on the same frame
# however fast the machine is.
param([Parameter(Mandatory = $true)][string]$Out, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs)
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
$path = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
# Built as an array: a bare -- on the command line can be eaten by PowerShell.
$argv = @("--path", $root, "--fixed-fps", "60", "--resolution", "1280x720", "--", "--shot=$path")
if ($GameArgs) { $argv += $GameArgs }
& $Godot @argv
if (-not (Test-Path $path)) { Write-Error "no screenshot written"; exit 1 }
Write-Output "screenshot: $path"
