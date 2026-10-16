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
	var to_inverse := choppa.facing().inverse()
	var offset := to_inverse * (home - choppa.global_position)
	var vel := to_inverse * choppa.velocity
	# Proportional pull to the post, damped by current speed.
	var steer := Vector3(offset.x, offset.y, offset.z) * 0.15 - vel * 0.08
	i.move = Vector2(steer.x, -steer.z).limit_length(1.0)
	i.lift = clampf(steer.y * 2.0, -1.0, 1.0)
