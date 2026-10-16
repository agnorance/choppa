# Finds the Godot 4.7.2 console executable: $env:GODOT, then the PATH, then C:\Tools\Godot.
# Dot-source it from the other scripts: . "$PSScriptRoot\godot.ps1"
function Find-Godot {
	if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
	foreach ($name in @("godot", "Godot_v4.7.2-stable_win64_console", "godot_console")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	$default = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
	if (Test-Path $default) { return $default }
	throw "Godot not found. Set `$env:GODOT to Godot_v4.7.2-stable_win64_console.exe (see docs/SETUP_WINDOWS.md)."
}
$Godot = Find-Godot
