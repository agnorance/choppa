class_name Airframe
extends RefCounted
## The helicopter classes. Same controls, different numbers: hull, how tough the parts
## are, how fast it turns and how heavy it feels, the loadout, and which model it wears.
## The scout keeps the numbers the realistic model was tuned with.

const SCOUT := "scout"
const GUNSHIP := "gunship"
const HEAVY := "heavy"
const STRIKER := "striker"
const MULE := "mule"
const ORDER := [SCOUT, GUNSHIP, HEAVY, STRIKER, MULE]

## id -> numbers. "rates" scales pitch/roll/yaw rates, "inertia" the angular
## acceleration, "speed" level top speed and the afterburner, "climb" climb rate and
## power headroom, "size" the collision body, "camera" the chase distance (long tails);
## rounds (gun), rockets/missiles/flares are the loadout, "guns" the machine-gun damage
## per round, "fire" the time between rounds, "recoil" its kick, "spool" the engine
## start in seconds, "pitch" how high its rotor, engine and gun sound, "coaxial" two
## counter-rotating rotors (one mast, or tandem) and no tail rotor (a tail hit cannot
## spin it), "rotor" the blade radius, hub height and hub offset back (metres, for rotor
## strikes), "rotor2" the same for a second, tandem rotor.
## The classes are meant to feel apart (owner: "the difference should be feelable"):
## the scout darts and buzzes, the heavy wallows, booms and takes its time to start.
const TABLE := {
	SCOUT: {
		"nose": [-2.4, -0.45, 1.3],  ## Nose tip z, mouth height, mouth length (nose art).
		"name": "Scout", "model": "choppa", "hull": 100.0, "parts": 1.0,
		"rates": 1.2, "inertia": 1.35, "thrust_lag": 0.25, "speed": 1.12, "climb": 1.2, "size": 1.0, "camera": 1.0, "rotor": [5.0, 1.95, 0.3],
		"rounds": 360, "rockets": 8, "missiles": 1, "flares": 3, "guns": 0.8, "fire": 0.8, "recoil": 0.6,
		"spool": 2.5, "pitch": 1.15,
		"blurb": "Light and fast. Darts and buzzes, a quick light gun; breaks easily.",
	},
	GUNSHIP: {
		"nose": [-3.25, -0.35, 1.4],  ## Nose tip z, mouth height, mouth length (nose art).
		"name": "Gunship", "model": "gunship", "hull": 140.0, "parts": 1.35,
		"rates": 0.85, "inertia": 0.8, "thrust_lag": 0.45, "speed": 0.92, "climb": 0.95, "size": 1.1, "camera": 1.15, "rotor": [4.4, 1.72, 0.35],
		"rounds": 400, "rockets": 14, "missiles": 2, "flares": 2, "guns": 1.2, "fire": 1.0, "recoil": 1.0,
		"spool": 3.5, "pitch": 1.0,
		"blurb": "The all-rounder: more rockets, a second missile.",
	},
	HEAVY: {
		"nose": [-3.9, -0.55, 1.6],  ## Nose tip z, mouth height, mouth length (nose art).
		"name": "Heavy", "model": "heavy", "hull": 200.0, "parts": 2.0,
		"rates": 0.55, "inertia": 0.45, "thrust_lag": 0.75, "speed": 0.76, "climb": 0.7, "size": 1.3, "camera": 1.45, "rotor": [5.0, 2.17, 0.42],
		"rounds": 360, "rockets": 20, "missiles": 3, "flares": 4, "guns": 2.2, "fire": 1.45, "recoil": 1.9,
		"spool": 5.0, "pitch": 0.8,
		"blurb": "Armoured and slow to turn. A cannon of a gun; soaks hits, hits back hard.",
	},
	STRIKER: {
		"nose": [-3.35, -0.42, 1.5],  ## Nose tip z, mouth height, mouth length (nose art).
		"name": "Striker", "model": "striker", "hull": 125.0, "parts": 1.2,
		"rates": 1.05, "inertia": 1.1, "thrust_lag": 0.3, "speed": 1.04, "climb": 1.1, "size": 1.05, "camera": 1.1, "rotor": [4.0, 2.1, 0.27],
		"rounds": 300, "rockets": 10, "missiles": 2, "flares": 3, "guns": 1.5, "fire": 1.2, "recoil": 1.4,
		"spool": 3.0, "pitch": 0.92, "coaxial": true,
		"blurb": "Coaxial rotors, no tail rotor to lose: yaws hard, shrugs off tail hits. Twin 30 mm.",
	},
	MULE: {
		"nose": [-4.75, -0.62, 1.8],  ## Nose tip z, mouth height, mouth length (nose art).
		"name": "Mule", "model": "mule", "hull": 230.0, "parts": 2.2,
		"rates": 0.5, "inertia": 0.5, "thrust_lag": 0.6, "speed": 0.86, "climb": 0.85, "size": 1.4, "camera": 1.75,
		"rotor": [4.3, 1.95, -3.2], "rotor2": [4.3, 2.8, 3.6],
		"rounds": 700, "rockets": 0, "missiles": 4, "flares": 6, "guns": 0.9, "fire": 0.7, "recoil": 0.6,
		"spool": 5.5, "pitch": 0.72, "coaxial": true,
		"blurb": "Tandem rotors, a flying fortress: door miniguns, four missiles, six flares. Slow to turn, hard to kill.",
	},
}


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ORDER:
		out.append(TABLE[id].name)
	return out


static func spec(id: String) -> Dictionary:
	return TABLE.get(id, TABLE[SCOUT])


## The five numbers the class card shows, in order.
const STATS := ["Speed", "Agility", "Armour", "Gun", "Ordnance"]


## A class's raw rating for each of STATS: level top speed, roll rate, how much it soaks
## (hull plus tough parts), gun damage per second, and its ordnance weighted by punch.
static func raw_stats(id: String) -> Dictionary:
	var s := spec(id)
	return {
		"Speed": s.speed, "Agility": s.rates * sqrt(s.inertia), "Armour": s.hull * (0.5 + 0.5 * s.parts),
		"Gun": s.guns / s.fire, "Ordnance": s.rockets * 1.0 + s.missiles * 5.0 + s.flares * 1.5,
	}


## Each of STATS as 0..1 against the best class at it (never quite empty, so a bar shows).
static func stats(id: String) -> Dictionary:
	var best := {}
	for other: String in ORDER:
		var raw := raw_stats(other)
		for stat: String in STATS:
			best[stat] = maxf(best.get(stat, 0.0), raw[stat])
	var mine := raw_stats(id)
	var out := {}
	for stat: String in STATS:
		out[stat] = clampf(mine[stat] / best[stat], 0.08, 1.0)
	return out


## The real number behind a bar, for its label.
static func stat_text(id: String, stat: String) -> String:
	var s := spec(id)
	match stat:
		"Speed":
			return "%d km/h" % roundi(36.0 * s.speed * 3.6)
		"Agility":
			return "%d°/s" % roundi(rad_to_deg(2.8 * s.rates))
		"Armour":
			return "%d hp" % roundi(s.hull)
		"Gun":
			return "%d rnd" % s.rounds
		_:
			return "R%d M%d F%d" % [s.rockets, s.missiles, s.flares]
