class_name LocalPilot
extends Node
## Feeds keyboard, gamepad and on-screen touch controls into a choppa's PilotInput.

var choppa: Choppa
var touch: TouchControls


func _ready() -> void:
	# Write the input before the choppa reads it in the same physics tick.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	var i := choppa.input
	i.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	i.yaw = Input.get_axis("yaw_left", "yaw_right")
	i.lift = Input.get_axis("lift_down", "lift_up")
	i.boost = Input.is_action_pressed("boost")
	i.fire = Input.is_action_pressed("fire")
	i.trick = Input.is_action_pressed("trick")
	i.use_item = Input.is_action_pressed("use_item")
	if touch and touch.visible:
		i.move = (i.move + touch.move).limit_length(1.0)
		i.yaw = clampf(i.yaw + touch.look.x, -1.0, 1.0)
		i.lift = clampf(i.lift + touch.look.y, -1.0, 1.0)
		i.boost = i.boost or touch.is_pressed("boost")
		# Your right thumb is busy steering, so touch fires by itself once locked on.
		i.fire = i.fire or touch.is_pressed("fire") or choppa.aim_target() != null
		i.trick = i.trick or touch.is_pressed("trick")
		i.use_item = i.use_item or touch.is_pressed("use_item")
