class_name Airframe
extends RefCounted
## The helicopter classes. Same controls, different numbers: hull, how tough the parts
## are, how fast it turns and how heavy it feels, the loadout, and which model it wears.
## The scout keeps the numbers the realistic model was tuned with.

const SCOUT := "scout"
const GUNSHIP := "gunship"
const HEAVY := "heavy"
const ORDER := [SCOUT, GUNSHIP, HEAVY]

## id -> numbers. "rates" scales pitch/roll/yaw rates, "inertia" the angular
## acceleration, "speed" level top speed and the afterburner, "climb" climb rate and
## power headroom, "size" the collision body, "camera" the chase distance (long tails);
## rounds (gun), rockets/missiles/flares are the loadout, "guns" the machine-gun damage
## per round, "fire" the time between rounds, "recoil" its kick, "spool" the engine
## start in seconds, "pitch" how high its rotor, engine and gun sound.
## The classes are meant to feel apart (owner: "the difference should be feelable"):
## the scout darts and buzzes, the heavy wallows, booms and takes its time to start.
const TABLE := {
	SCOUT: {
		"name": "Scout", "model": "choppa", "hull": 100.0, "parts": 1.0,
		"rates": 1.2, "inertia": 1.35, "thrust_lag": 0.25, "speed": 1.12, "climb": 1.2, "size": 1.0, "camera": 1.0,
		"rounds": 360, "rockets": 8, "missiles": 1, "flares": 3, "guns": 0.8, "fire": 0.8, "recoil": 0.6,
		"spool": 2.5, "pitch": 1.15,
		"blurb": "Light and fast. Darts and buzzes, a quick light gun; breaks easily.",
	},
	GUNSHIP: {
		"name": "Gunship", "model": "gunship", "hull": 140.0, "parts": 1.35,
		"rates": 0.85, "inertia": 0.8, "thrust_lag": 0.45, "speed": 0.92, "climb": 0.95, "size": 1.1, "camera": 1.15,
		"rounds": 400, "rockets": 14, "missiles": 2, "flares": 2, "guns": 1.2, "fire": 1.0, "recoil": 1.0,
		"spool": 3.5, "pitch": 1.0,
		"blurb": "The all-rounder: more rockets, a second missile.",
	},
	HEAVY: {
		"name": "Heavy", "model": "heavy", "hull": 200.0, "parts": 2.0,
		"rates": 0.55, "inertia": 0.45, "thrust_lag": 0.75, "speed": 0.76, "climb": 0.7, "size": 1.3, "camera": 1.45,
		"rounds": 360, "rockets": 20, "missiles": 3, "flares": 4, "guns": 2.2, "fire": 1.45, "recoil": 1.9,
		"spool": 5.0, "pitch": 0.8,
		"blurb": "Armoured and slow to turn. A cannon of a gun; soaks hits, hits back hard.",
	},
}


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ORDER:
		out.append(TABLE[id].name)
	return out


static func spec(id: String) -> Dictionary:
	return TABLE.get(id, TABLE[SCOUT])
