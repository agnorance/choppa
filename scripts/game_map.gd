class_name GameMap
extends Node3D
## What every map gives the game: where to spawn, the race gates and a flight ceiling.

var mode := "free"  ## "free", "battle" or "race"; set before adding the map to the tree.
var gates: Array[RingGate] = []  ## Race checkpoints in order (race mode only).
var spawn_points: Array[Transform3D] = []  ## Starting grid, pole position first.
var dummy_posts: Array[Vector3] = []  ## Where training dummies hover in free flight.
var ceiling := 140.0  ## Choppas can't climb above this, so nobody skips the course.

static var timing := false  ## Print build times (--timing).


## Prints how long a build step took, when --timing is on.
static func report(what: String, started_msec: int) -> void:
	if timing:
		print("timing: %s in %d ms" % [what, Time.get_ticks_msec() - started_msec])


## Display names and ids of all maps, for the menu.
static func catalog() -> Array:
	return [["MESA BASIN", "basin"], ["TEST RANGE", "range"]]


static func create(map_id: String) -> GameMap:
	match map_id:
		"range":
			return TestRange.new()
	return MesaBasin.new()
