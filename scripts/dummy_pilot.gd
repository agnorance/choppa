class_name DummyPilot
extends Node
## Training target: hovers at its post and flies back after being knocked away.

var choppa: Choppa
var home := Vector3.ZERO


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	var i := choppa.input
	i.clear()
	# Proportional pull to the post; the autopilot turns it into stick and collective.
	var want := ((home - choppa.global_position) * 0.6).limit_length(12.0)
	Autopilot.fly(choppa, i, want, choppa.global_position + choppa.facing() * Vector3.FORWARD * 10.0)
