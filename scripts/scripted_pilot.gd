class_name ScriptedPilot
extends Node
## Canned flight plans for screenshots and smoke tests (`--autopilot=<plan>`).
## Plans: hover, shoot, forward, boost, roll, flip, pirouette, and weapon:<NAME>
## (hover, then fire rockets, missile, flares, mine or smoke, e.g. weapon:missile).

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
	var pos := choppa.global_position
	var forward := choppa.facing() * Vector3.FORWARD
	var want := Vector3(0.0, (CRUISE_ALTITUDE - choppa.altitude) * 0.5, 0.0)
	if plan.begins_with("weapon:"):
		# Hover, then fire that weapon once at tick 30 (rockets: a salvo for half a second).
		var weapon := plan.substr(7)
		var on := _tick >= 30 and _tick < (60 if weapon == "rockets" else 31)
		match weapon:
			"rockets": i.rockets = on
			"missile": i.missile = on
			"flares": i.flares = on
			"mine": i.mine = on
			"smoke": i.smoke = on
	elif plan == "shoot":
		i.fire = true
	elif plan != "hover":
		want += forward * 25.0
	Autopilot.fly(choppa, i, want, pos + forward * 50.0)
	match plan:
		"boost":
			i.boost = true
		"roll":  # Full stick after a run-up: a barrel roll.
			if _tick > 60 and _tick < 100:
				i.cyclic.x = 1.0
		"flip":  # Full back stick: a loop.
			if _tick > 60 and _tick < 130:
				i.cyclic.y = -1.0
		"pirouette":
			if _tick > 60 and _tick < 120:
				i.yaw = 1.0
