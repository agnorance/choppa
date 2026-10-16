# Starts the game straight into one scene, for a quick look. Without a name it lists them.
# Usage: tools\try.ps1 <scene> [more game args]
#   e.g. tools\try.ps1 settings        tools\try.ps1 battle --kills=3
param([string]$Scene = "", [Parameter(ValueFromRemainingArguments = $true)][string[]]$More)
$scenes = [ordered]@{
	"menu"     = @("--menu", "--map=basin")
	"settings" = @("--menu", "--settings=0", "--map=basin")
	"battle"   = @("--mode=battle", "--map=basin")
	"free"     = @("--mode=free", "--map=basin")
	"race"     = @("--mode=race")
	"cockpit"  = @("--mode=free", "--map=basin", "--cam=fp")
	"lake"     = @("--mode=free", "--map=basin", "--spawn=150,4,150,45")
	"damaged"  = @("--mode=free", "--map=basin", "--health=20")
	"touch"    = @("--mode=free", "--map=basin", "--touch")
	"bots"     = @("--mode=battle", "--map=basin", "--autopilot=bot")
	"missile"  = @("--mode=free", "--map=basin", "--autopilot=item:MISSILE")
	"explode"  = @("--mode=free", "--map=basin", "--explode=120")
}
if (-not $scenes.Contains($Scene)) {
	Write-Output "Scenes:"
	foreach ($name in $scenes.Keys) { Write-Output ("  {0,-9} {1}" -f $name, ($scenes[$name] -join " ")) }
	Write-Output "Any further arguments go to the game (see the top of scripts/main.gd)."
	exit 1
}
& "$PSScriptRoot\run.ps1" @($scenes[$Scene] + $More)
