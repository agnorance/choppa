class_name Items
extends RefCounted
## The item table. See docs/DESIGN.md for the planned items.

## Item name -> relative weight. Only implemented items belong here.
const POOL := {
	"TURBO": 1.0,
}


static func roll(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for weight: float in POOL.values():
		total += weight
	var pick := rng.randf() * total
	for item_name: String in POOL:
		pick -= POOL[item_name]
		if pick <= 0.0:
			return item_name
	return POOL.keys()[0]
