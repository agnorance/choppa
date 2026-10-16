class_name Items
extends RefCounted
## The item table. Odds depend on where you stand: `standing` is 0 for the leader and
## 1 for last place, and each item's weight slides between its two values.

## name -> [weight when leading, weight when last, HUD colour]
const TABLE := {
	"TURBO": [2.0, 1.0, Color(1.0, 0.6, 0.15)],
	"MISSILE": [1.0, 3.0, Color(1.0, 0.3, 0.25)],
	"MINE": [2.0, 1.5, Color(0.9, 0.2, 0.2)],
	"FAKE BOX": [2.0, 1.0, Color(0.85, 0.5, 1.0)],
	"SMOKE": [1.5, 1.5, Color(0.6, 0.6, 0.65)],
	"SCRAMBLER": [0.0, 2.0, Color(0.7, 0.3, 1.0)],
	"SHIELD": [2.5, 1.0, Color(0.3, 0.85, 1.0)],
	"GET TO THE CHOPPA": [0.0, 0.0, Color(1.0, 0.85, 0.2)],  # Last place only, see roll().
}
## Chance that the very last pilot gets GET TO THE CHOPPA.
const COMEBACK_CHANCE := 0.25


static func color(item_name: String) -> Color:
	return TABLE[item_name][2] if TABLE.has(item_name) else Color.WHITE


static func roll(rng: RandomNumberGenerator, standing := 0.5) -> String:
	if standing >= 0.99 and rng.randf() < COMEBACK_CHANCE:
		return "GET TO THE CHOPPA"
	var total := 0.0
	for item_name: String in TABLE:
		total += _weight(item_name, standing)
	var pick := rng.randf() * total
	for item_name: String in TABLE:
		pick -= _weight(item_name, standing)
		if pick <= 0.0 and _weight(item_name, standing) > 0.0:
			return item_name
	return "TURBO"


static func _weight(item_name: String, standing: float) -> float:
	return lerpf(TABLE[item_name][0], TABLE[item_name][1], standing)
