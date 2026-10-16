class_name PilotInput
extends RefCounted
## Everything a choppa needs to know about what its pilot wants this tick.
## Filled by keyboard/mouse/gamepad/touch, a bot, or (later) the network.

var cyclic := Vector2.ZERO  ## x: roll right, y: nose down (forward). Length <= 1.
var yaw := 0.0  ## +1 turns right.
var collective := 0.0  ## +1 full power, -1 idle; 0 holds a level hover.
var boost := false  ## Afterburner.
var fire := false
var use_item := false  ## Held state; the choppa reacts to the press edge.


func copy_from(other: PilotInput) -> void:
	cyclic = other.cyclic
	yaw = other.yaw
	collective = other.collective
	boost = other.boost
	fire = other.fire
	use_item = other.use_item


func clear() -> void:
	copy_from(PilotInput.new())
