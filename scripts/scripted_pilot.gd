class_name ScriptedPilot
extends Node
## Canned flight plans for screenshots and smoke tests (`--autopilot=<plan>`).
## Plans: hover, shoot, forward, boost, roll, flip, snap, pirouette.

const CRUISE_ALTITUDE := 7.0

var choppa: Choppa
var plan := "forward"

var _tick := 0


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	_tick += 1
	var i := choppa.input
	i.clear()
	i.lift = clampf((CRUISE_ALTITUDE - choppa.altitude) * 0.3, -1.0, 1.0)
	if plan == "hover":
		return
	if plan == "shoot":
		i.fire = true
		return
	i.move.y = 1.0
	match plan:
		"boost":
			i.boost = true
		"roll":
			i.trick = _tick > 60 and _tick < 64
			i.move = Vector2(1.0, 0.0) if i.trick else Vector2(0.0, 1.0)
		"flip":
			i.trick = _tick > 60 and _tick < 64
		"snap":
			i.trick = _tick > 60 and _tick < 64
			i.move = Vector2(0.0, -1.0) if i.trick else Vector2(0.0, 1.0)
		"pirouette":
			i.trick = _tick > 60 and _tick < 64
			i.move = Vector2.ZERO if i.trick else Vector2(0.0, 1.0)
