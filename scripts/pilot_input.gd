class_name PilotInput
extends RefCounted
## Everything a choppa needs to know about what its pilot wants this tick.
## Filled by keyboard/gamepad/touch, a bot, or (later) the network.

var move := Vector2.ZERO  ## x: strafe right, y: forward. Length <= 1.
var yaw := 0.0  ## +1 turns right.
var lift := 0.0  ## +1 climbs.
var boost := false
var fire := false
var trick := false  ## Held state; the choppa reacts to the press edge.
var use_item := false  ## Held state; the choppa reacts to the press edge.


func copy_from(other: PilotInput) -> void:
	move = other.move
	yaw = other.yaw
	lift = other.lift
	boost = other.boost
	fire = other.fire
	trick = other.trick
	use_item = other.use_item


func clear() -> void:
	copy_from(PilotInput.new())
