class_name PilotInput
extends RefCounted
## Everything a choppa needs to know about what its pilot wants this tick.
## Filled by keyboard/mouse/gamepad/touch, a bot, or (later) the network.

var cyclic := Vector2.ZERO  ## x: roll right, y: nose down (forward). Length <= 1.
var move := Vector2.ZERO  ## Easy model only: x strafe right, y forward. Length <= 1.
var yaw := 0.0  ## +1 turns right.
var collective := 0.0  ## +1 full power, -1 idle; 0 holds a level hover.
var boost := false  ## Afterburner.
var fire := false  ## Machine gun, held.
var rockets := false  ## Held: a salvo, one rocket per interval.
var missile := false  ## Weapons below fire while held, at most once per their interval.
var flares := false
var mine := false
var smoke := false
var engine := false  ## Held: each press switches the engine on or off.


func copy_from(other: PilotInput) -> void:
	cyclic = other.cyclic
	move = other.move
	yaw = other.yaw
	collective = other.collective
	boost = other.boost
	fire = other.fire
	rockets = other.rockets
	missile = other.missile
	flares = other.flares
	mine = other.mine
	smoke = other.smoke
	engine = other.engine


func clear() -> void:
	copy_from(PilotInput.new())
