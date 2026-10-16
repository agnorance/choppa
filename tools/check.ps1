# The whole check in one go: import, tests, and the standard set of screenshots into
# build\shots\ (title, every settings tab, HUD, pause, cockpit, race, classes, canyon).
# Usage: tools\check.ps1 [-NoShots]
param([switch]$NoShots)
. "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot -Parent
& $Godot --headless --path $root --import | Out-Null
& $Godot --headless --fixed-fps 60 --path $root --script res://tests/run_tests.gd 2>&1 | Select-String "PASS|FAIL|check failed|TESTS PASSED|SCRIPT ERROR"
if ($LASTEXITCODE -ne 0) { Write-Error "tests failed"; exit 1 }
if ($NoShots) { exit 0 }

$dir = Join-Path $root "build\shots"
New-Item -ItemType Directory -Force $dir | Out-Null
# Godot must not import the screenshots as textures: build/ is marked ignored.
if (-not (Test-Path "$root\build\.gdignore")) { New-Item -ItemType File "$root\build\.gdignore" | Out-Null }
$shots = [ordered]@{
	"menu"            = "--menu --map=basin --frames=90"
	"settings_video"    = "--menu --settings=0 --map=basin --frames=90"
	"settings_graphics" = "--menu --settings=1 --map=basin --frames=90"
	"settings_gameplay" = "--menu --settings=2 --map=basin --frames=90"
	"settings_controls" = "--menu --settings=3 --map=basin --frames=90"
	"settings_audio"    = "--menu --settings=4 --map=basin --frames=90"
	"hangar"          = "--menu --hangar --map=basin --level=34 --frames=120"
	"hangar_apex"     = "--menu --hangar --map=basin --level=100 --entitle=apex --camo=apex --frames=120"
	"battle"          = "--mode=battle --map=basin --autopilot=bot --frames=240"
	"pause"           = "--mode=battle --map=basin --autopilot=bot --pause=200"
	"cockpit"         = "--map=basin --cam=fp --autopilot=hover --frames=40"
	"race"            = "--mode=race --autopilot=bot --frames=300"
	"showcase"        = "--map=basin --cam=showcase --autopilot=hover --frames=150 --dummies=0"
	"gunship"         = "--map=basin --airframe=gunship --cam=showcase --autopilot=hover --frames=150 --dummies=0"
	"heavy"           = "--map=basin --airframe=heavy --cam=showcase --autopilot=hover --frames=150 --dummies=0"
	"station"         = "--map=basin --spawn=79,8,110,40 --autopilot=hover --frames=120 --dummies=0"
	"canyon"          = "--map=canyon --autopilot=forward --frames=150 --dummies=0"
	"canyon_camp"     = "--map=canyon --spawn=77,25,190,0 --autopilot=hover --frames=100 --dummies=0"
	"canyon_battle"   = "--mode=battle --map=canyon --autopilot=bot --frames=600"
	"online"          = "--menu --online --map=basin --frames=90"
}
foreach ($name in $shots.Keys) {
	$out = Join-Path $dir "$name.png"
	& $Godot --path $root --fixed-fps 60 --resolution 1280x720 -- "--shot=$out" $shots[$name].Split(" ") 2>&1 |
		Select-String "SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Output "  $name : $_" }
	if (Test-Path $out) { Write-Output "shot: $out" } else { Write-Warning "no screenshot for $name" }
}
