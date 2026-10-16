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
## acceleration, "speed" level top speed and the afterburner, "size" the collision
## body; rockets/missiles/flares are the loadout, "guns" the machine-gun damage factor.
const TABLE := {
	SCOUT: {
		"name": "Scout", "model": "choppa", "hull": 100.0, "parts": 1.0,
		"rates": 1.0, "inertia": 1.0, "thrust_lag": 0.35, "speed": 1.0, "size": 1.0,
		"rockets": 8, "missiles": 1, "flares": 3, "guns": 1.0,
		"blurb": "Light and fast. Turns on a coin, breaks easily.",
	},
	GUNSHIP: {
		"name": "Gunship", "model": "gunship", "hull": 130.0, "parts": 1.3,
		"rates": 0.85, "inertia": 0.8, "thrust_lag": 0.45, "speed": 0.92, "size": 1.1,
		"rockets": 14, "missiles": 2, "flares": 2, "guns": 1.2,
		"blurb": "The all-rounder: more rockets, a second missile.",
	},
	HEAVY: {
		"name": "Heavy", "model": "heavy", "hull": 170.0, "parts": 1.8,
		"rates": 0.65, "inertia": 0.6, "thrust_lag": 0.6, "speed": 0.8, "size": 1.3,
		"rockets": 20, "missiles": 3, "flares": 4, "guns": 1.6,
		"blurb": "Armoured and slow. Soaks hits, hits back hard.",
	},
}


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ORDER:
		out.append(TABLE[id].name)
	return out


static func spec(id: String) -> Dictionary:
	return TABLE.get(id, TABLE[SCOUT])
