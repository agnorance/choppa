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
	"settings_flight"   = "--menu --settings=3 --map=basin --frames=90"
	"settings_controls" = "--menu --settings=4 --map=basin --frames=90"
	"settings_audio"    = "--menu --settings=5 --map=basin --frames=90"
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
	"back_to_menu"    = "--mode=battle --map=basin --leave=30 --frames=120"
	"harbor_yard"     = "--map=harbor --spawn=-140,22,-60,180 --autopilot=hover --frames=60 --dummies=0"
	"harbor_battle"   = "--mode=battle --map=harbor --autopilot=bot --frames=600"
	"striker"         = "--map=harbor --airframe=striker --cam=showcase --autopilot=hover --frames=150 --dummies=0"
	"flares"          = "--map=basin --spawn=0,60,120,0 --autopilot=weapon:flares --cam=showcase --frames=150 --dummies=0"
	"mule"            = "--map=harbor --airframe=mule --cam=showcase --autopilot=hover --frames=150 --dummies=0"
	"cockpit_gunship" = "--map=basin --airframe=gunship --cam=fp --autopilot=hover --frames=60 --dummies=0"
	"cockpit_heavy"   = "--map=basin --airframe=heavy --cam=fp --autopilot=hover --frames=60 --dummies=0"
	"cockpit_striker" = "--map=basin --airframe=striker --cam=fp --autopilot=hover --frames=60 --dummies=0"
	"cockpit_mule"    = "--map=basin --airframe=mule --cam=fp --autopilot=hover --frames=60 --dummies=0"
	"shark"           = "--map=basin --airframe=gunship --camo=shark --cam=showcase --spawn=150,6,150,45 --autopilot=hover --frames=100 --dummies=0"
	"dam"             = "--map=dam --spawn=30,30,120,0 --cam=fp --autopilot=hover --frames=60 --dummies=0"
	"dam_battle"      = "--mode=battle --map=dam --autopilot=bot --frames=600"
	"night"           = "--map=harbor --time=night --spawn=-15,12,110,0 --cam=orbit --autopilot=hover --frames=260 --dummies=0 --clean"
	"dusk"            = "--map=dam --time=dusk --spawn=30,30,120,0 --cam=fp --autopilot=hover --frames=300 --dummies=0"
	"wreck"           = "--map=basin --autopilot=flip --health=1 --cam=low --frames=480 --dummies=0 --clean"
}
foreach ($name in $shots.Keys) {
	$out = Join-Path $dir "$name.png"
	& $Godot --path $root --fixed-fps 60 --resolution 1280x720 -- "--shot=$out" $shots[$name].Split(" ") 2>&1 |
		Select-String "SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Output "  $name : $_" }
	if (Test-Path $out) { Write-Output "shot: $out" } else { Write-Warning "no screenshot for $name" }
}
