class_name Progression
extends RefCounted
## Pilot levels, XP and camos (docs/DESIGN.md, "Progression, camos and the store").
## Two tiers: earned camos come only from level (skill and time), paid packs only buy
## style, and Apex belongs to the world's #1 ranked pilot. Who owns a pack or Apex is an
## entitlement a server grants; offline there are none, except for testing.

const MAX_LEVEL := 100
const ACE_STAR_XP := 10000  ## Each this much XP past level 100 is an Ace star.

## XP per event in a battle.
const XP := {
	"kill": 100, "assist": 40, "part": 25, "damage": 1, "station_denied": 50,
	"finished": 100, "won": 200,
}
const ASSIST_TIME := 5.0  ## Damage this soon before someone else's kill is an assist.

## Who may wear a camo: "level" (needs `level`), "ace" (one Ace star), or an entitlement
## id: "hangar", "collector" (also has everything in "hangar"), "apex".
## pattern: hull shader pattern (0 solid .. 8 checker, 9 dazzle, 10 hex), colours a..d, finish
## (metal, gloss), wear, and Apex-style seams.
const CAMOS := {
	"factory": {"name": "Factory olive", "tier": "level", "level": 1, "pattern": 0,
		"colors": [Color(0.36, 0.38, 0.27)]},
	"desert": {"name": "Desert", "tier": "level", "level": 5, "pattern": 1,
		"colors": [Color(0.78, 0.66, 0.46), Color(0.5, 0.36, 0.22), Color(0.3, 0.23, 0.16), Color(0.9, 0.82, 0.64)]},
	"woodland": {"name": "Woodland", "tier": "level", "level": 10, "pattern": 1,
		"colors": [Color(0.38, 0.44, 0.25), Color(0.15, 0.21, 0.11), Color(0.42, 0.29, 0.16), Color(0.05, 0.05, 0.05)]},
	"dazzle": {"name": "Dazzle", "tier": "level", "level": 15, "pattern": 9,
		"colors": [Color(0.78, 0.8, 0.8), Color(0.12, 0.14, 0.17), Color(0.36, 0.44, 0.52)]},
	"tiger": {"name": "Tiger stripe", "tier": "level", "level": 20, "pattern": 2,
		"colors": [Color(0.56, 0.53, 0.34), Color(0.17, 0.23, 0.11), Color(0.04, 0.04, 0.04)]},
	"splinter": {"name": "Splinter", "tier": "level", "level": 30, "pattern": 3,
		"colors": [Color(0.62, 0.58, 0.43), Color(0.29, 0.38, 0.2), Color(0.44, 0.29, 0.17), Color(0.13, 0.15, 0.11)]},
	"urban": {"name": "Urban", "tier": "level", "level": 25, "pattern": 3,
		"colors": [Color(0.55, 0.56, 0.57), Color(0.32, 0.33, 0.35), Color(0.18, 0.18, 0.2), Color(0.72, 0.72, 0.7)]},
	"digital": {"name": "Digital", "tier": "level", "level": 40, "pattern": 4,
		"colors": [Color(0.6, 0.58, 0.46), Color(0.3, 0.37, 0.22), Color(0.16, 0.16, 0.13), Color(0.76, 0.72, 0.58)]},
	"hex": {"name": "Hex", "tier": "level", "level": 45, "pattern": 10,
		"colors": [Color(0.3, 0.33, 0.28), Color(0.2, 0.23, 0.18), Color(0.08, 0.09, 0.08), Color(0.6, 0.45, 0.15)]},
	"arctic": {"name": "Arctic", "tier": "level", "level": 50, "pattern": 1,
		"colors": [Color(0.86, 0.87, 0.88), Color(0.62, 0.64, 0.66), Color(0.4, 0.42, 0.45), Color(0.95, 0.95, 0.95)]},
	"night": {"name": "Night ops", "tier": "level", "level": 60, "pattern": 4,
		"colors": [Color(0.1, 0.11, 0.14), Color(0.15, 0.17, 0.22), Color(0.06, 0.06, 0.08), Color(0.2, 0.22, 0.28)],
		"gloss": 0.2},
	"veteran": {"name": "Veteran", "tier": "level", "level": 75, "pattern": 0,
		"colors": [Color(0.45, 0.46, 0.47)], "metal": 0.7, "gloss": 0.45, "wear": 0.6},
	"centurion": {"name": "Centurion", "tier": "level", "level": 100, "pattern": 0,
		"colors": [Color(0.86, 0.66, 0.3)], "metal": 0.95, "gloss": 0.75, "wear": 0.12},
	"ace": {"name": "Ace", "tier": "ace", "pattern": 0, "colors": [Color(0.06, 0.06, 0.07)],
		"metal": 0.3, "gloss": 0.65, "wear": 0.1, "seams": Color(0.85, 0.65, 0.25)},
	"racing": {"name": "Racing", "tier": "hangar", "pattern": 5,
		"colors": [Color(0.92, 0.92, 0.9), Color(0.1, 0.3, 0.75), Color(0.85, 0.15, 0.12)], "gloss": 0.7, "wear": 0.1},
	"hornet": {"name": "Hornet", "tier": "hangar", "pattern": 6,
		"colors": [Color(0.95, 0.72, 0.08), Color(0.06, 0.06, 0.06)], "gloss": 0.6, "wear": 0.12},
	"sunset": {"name": "Sunset", "tier": "hangar", "pattern": 7,
		"colors": [Color(0.95, 0.45, 0.12), Color(0.75, 0.2, 0.35), Color(0.25, 0.12, 0.4), Color(1.0, 0.85, 0.3)],
		"gloss": 0.6, "wear": 0.08},
	"checker": {"name": "Checkerboard", "tier": "hangar", "pattern": 8,
		"colors": [Color(0.92, 0.92, 0.9), Color(0.08, 0.08, 0.09)], "gloss": 0.6, "wear": 0.1},
	"chrome": {"name": "Chrome", "tier": "collector", "pattern": 0, "colors": [Color(0.8, 0.82, 0.85)],
		"metal": 1.0, "gloss": 0.92, "wear": 0.0},
	"pearl": {"name": "Pearl", "tier": "collector", "pattern": 0, "colors": [Color(0.93, 0.9, 0.86)],
		"metal": 0.35, "gloss": 0.85, "wear": 0.0},
	"candy": {"name": "Candy red", "tier": "collector", "pattern": 0, "colors": [Color(0.6, 0.02, 0.05)],
		"metal": 0.8, "gloss": 0.9, "wear": 0.0},
	"apex": {"name": "Apex", "tier": "apex", "pattern": 0, "colors": [Color(0.03, 0.03, 0.035)],
		"metal": 0.95, "gloss": 0.95, "wear": 0.0, "seams": Color(1.0, 0.72, 0.2), "glow": 2.5,
		"tips": Color(1.0, 0.75, 0.2)},
}
const ORDER := ["factory", "desert", "woodland", "dazzle", "tiger", "urban", "splinter", "digital", "hex", "arctic", "night", "veteran",
	"centurion", "ace", "racing", "hornet", "sunset", "checker", "chrome", "pearl", "candy", "apex"]
const PACKS := {
	"hangar": {"name": "Hangar Pack", "price": "5 EUR"},
	"collector": {"name": "Collector Pack", "price": "15 EUR"},
}


## XP needed to go from `level` to `level + 1`.
static func xp_for_level(level: int) -> int:
	return 1000 + 50 * (level - 1)


## Total XP needed to reach `level` from nothing.
static func total_xp_for(level: int) -> int:
	var total := 0
	for n in range(1, level):
		total += xp_for_level(n)
	return total


## The level a total of `xp` reaches (1..MAX_LEVEL).
static func level_for(xp: int) -> int:
	var level := 1
	var left := xp
	while level < MAX_LEVEL and left >= xp_for_level(level):
		left -= xp_for_level(level)
		level += 1
	return level


## Ace stars: every ACE_STAR_XP past level 100.
static func ace_stars(xp: int) -> int:
	return maxi(0, (xp - total_xp_for(MAX_LEVEL)) / ACE_STAR_XP)


## 0..1 progress through the current level.
static func level_progress(xp: int) -> float:
	var level := level_for(xp)
	if level >= MAX_LEVEL:
		return float((xp - total_xp_for(MAX_LEVEL)) % ACE_STAR_XP) / ACE_STAR_XP
	return float(xp - total_xp_for(level)) / xp_for_level(level)


## Whether a pilot with `xp` and `entitlements` may wear `camo`.
static func unlocked(camo: String, xp: int, entitlements: PackedStringArray) -> bool:
	var c: Dictionary = CAMOS.get(camo, {})
	match c.get("tier", ""):
		"level":
			return level_for(xp) >= c.level
		"ace":
			return ace_stars(xp) >= 1
		"hangar":
			return entitlements.has("hangar") or entitlements.has("collector")
		"collector":
			return entitlements.has("collector")
		"apex":
			return entitlements.has("apex")
	return false


## What it takes to unlock `camo`, for the hangar.
static func requirement(camo: String) -> String:
	var c: Dictionary = CAMOS[camo]
	match c.tier:
		"level":
			return "Level %d" % c.level
		"ace":
			return "First Ace star (past level 100)"
		"hangar":
			return "Hangar Pack"
		"collector":
			return "Collector Pack"
		"apex":
			return "World #1 ranked pilot"
	return ""


## XP for one battle from its stats, as [[label, xp], ...] plus the total.
static func award(stats: Dictionary) -> Dictionary:
	var lines := []
	for key: String in ["kill", "assist", "part", "damage", "station_denied"]:
		var count: int = int(stats.get(key, 0))
		if count > 0:
			lines.append([_label(key, count), count * XP[key]])
	if stats.get("finished", false):
		lines.append(["Match finished", XP.finished])
	if stats.get("won", false):
		lines.append(["Victory", XP.won])
	var total := 0
	for line: Array in lines:
		total += line[1]
	if stats.get("first_win_today", false) and stats.get("won", false):
		lines.append(["First win of the day", total])
		total *= 2
	return {"lines": lines, "total": total}


static func _label(key: String, count: int) -> String:
	match key:
		"kill":
			return "%d kill%s" % [count, "" if count == 1 else "s"]
		"assist":
			return "%d assist%s" % [count, "" if count == 1 else "s"]
		"part":
			return "%d part%s wrecked" % [count, "" if count == 1 else "s"]
		"damage":
			return "%d damage dealt" % count
		"station_denied":
			return "%d station%s denied" % [count, "" if count == 1 else "s"]
	return key


## Puts a camo on a hull ShaderMaterial (see shaders/hull.gdshader).
static func apply_camo(material: ShaderMaterial, camo: String) -> void:
	var c: Dictionary = CAMOS.get(camo, CAMOS.factory)
	var colors: Array = c.colors
	material.set_shader_parameter("paint", colors[0])
	for k in 3:
		material.set_shader_parameter(["camo_b", "camo_c", "camo_d"][k], colors[mini(k + 1, colors.size() - 1)])
	material.set_shader_parameter("pattern", c.pattern)
	material.set_shader_parameter("paint_metal", c.get("metal", 0.15))
	material.set_shader_parameter("paint_gloss", c.get("gloss", 0.38))
	material.set_shader_parameter("wear", c.get("wear", 0.28))
	material.set_shader_parameter("seam_color", c.get("seams", Color.BLACK))
	material.set_shader_parameter("seam_glow", c.get("glow", 0.0))


## The player's saved progress: XP, chosen camo per helicopter class, stats. Offline it
## lives in user://profile.cfg; online the server owns it (docs/DESIGN.md).
class Profile extends RefCounted:
	const PATH := "user://profile.cfg"

	var xp := 0
	var camos := {}  ## airframe id -> camo id
	var stats := {"matches": 0, "wins": 0, "kills": 0, "parts": 0}
	var last_win_day := ""
	## Granted by a server. Offline only --entitle=... fills it (for testing); never saved.
	var entitlements := PackedStringArray()
	var testing := false  ## --level or --entitle: play with it, but never save it.

	func level() -> int:
		return Progression.level_for(xp)

	func camo_for(airframe: String) -> String:
		var camo: String = camos.get(airframe, "factory")
		return camo if Progression.unlocked(camo, xp, entitlements) else "factory"

	func choose(airframe: String, camo: String) -> bool:
		if not Progression.unlocked(camo, xp, entitlements):
			return false
		camos[airframe] = camo
		return true

	## Adds a battle's XP and stats. Returns {total, lines, level_before, level_after,
	## unlocked: camo ids newly unlocked}.
	func add_battle(battle: Dictionary) -> Dictionary:
		var today := Time.get_date_string_from_system()
		battle["first_win_today"] = battle.get("won", false) and last_win_day != today
		var result := Progression.award(battle)
		var before_level := level()
		var before := []
		for id: String in Progression.ORDER:
			if Progression.unlocked(id, xp, entitlements):
				before.append(id)
		xp += result.total
		stats.matches += 1
		stats.kills += int(battle.get("kill", 0))
		stats.parts += int(battle.get("part", 0))
		if battle.get("won", false):
			stats.wins += 1
			last_win_day = today
		var fresh := []
		for id: String in Progression.ORDER:
			if Progression.unlocked(id, xp, entitlements) and not before.has(id):
				fresh.append(id)
		result["level_before"] = before_level
		result["level_after"] = level()
		result["unlocked"] = fresh
		return result

	func save(path := PATH) -> void:
		if testing:
			return
		var f := ConfigFile.new()
		f.set_value("profile", "xp", xp)
		f.set_value("profile", "camos", camos)
		f.set_value("profile", "stats", stats)
		f.set_value("profile", "last_win_day", last_win_day)
		f.save(path)

	func load_from(path := PATH) -> void:
		var f := ConfigFile.new()
		if f.load(path) != OK:
			return
		xp = int(f.get_value("profile", "xp", 0))
		camos = f.get_value("profile", "camos", {})
		var saved: Dictionary = f.get_value("profile", "stats", {})
		for key: String in saved:
			stats[key] = saved[key]
		last_win_day = f.get_value("profile", "last_win_day", "")


static var _profile: Profile


## The local player's profile, loaded once.
static func profile() -> Profile:
	if _profile == null:
		_profile = Profile.new()
		if DisplayServer.get_name() != "headless":
			_profile.load_from()
	return _profile
