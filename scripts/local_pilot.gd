class_name LocalPilot
extends Node
## Feeds keyboard, mouse and gamepad into a choppa's PilotInput.
##
## Realistic model: two mouse layouts (Settings "mouse_mode"), 0 pitch and roll on the
## mouse with yaw on A/D, 1 pitch and yaw on the mouse with roll on A/D; arrows and the
## left stick are the cyclic, W/S the collective. Easy model: WASD moves, Q/E and the
## mouse turn, mouse Y aims the nose, Space/C climb and dive.

## Stick per pixel of mouse travel at sensitivity 1; the setting scales it 1..10.
const MOUSE_GAIN := 0.012

var choppa: Choppa

var _mouse := Vector2.ZERO  ## Mouse travel since the last tick, in pixels.


func _ready() -> void:
	# Write the input before the choppa reads it in the same physics tick.
	process_physics_priority = -10


## Mouse motion arrives as events between ticks; it becomes stick on the next one.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += (event as InputEventMouseMotion).relative


## For tests: as if the mouse had moved by `relative` pixels.
func feed_mouse(relative: Vector2) -> void:
	_mouse += relative


func _physics_process(_delta: float) -> void:
	var i := choppa.input
	i.boost = Input.is_action_pressed("boost")
	i.fire = Input.is_action_pressed("fire")
	i.rockets = Input.is_action_pressed("rockets")
	i.missile = Input.is_action_pressed("missile")
	i.flares = Input.is_action_pressed("flares")
	i.mine = Input.is_action_pressed("mine")
	i.smoke = Input.is_action_pressed("smoke")
	var gain := Settings.choice("mouse_sensitivity") * MOUSE_GAIN
	var mouse := _mouse if Settings.flag("mouse_steer") else Vector2.ZERO
	_mouse = Vector2.ZERO
	var invert := -1.0 if Settings.flag("invert_mouse") else 1.0
	if choppa.easy:
		# Drone layout: W/S forward and back, A/D strafe, Q/E and mouse X turn, mouse Y
		# aims the nose up or down, Space/C (or W/S on the right stick) climb and dive.
		i.move = Input.get_vector("yaw_left", "yaw_right", "collective_down", "collective_up")
		i.yaw = Input.get_axis("turn_left", "turn_right")
		i.collective = Input.get_axis("vertical_down", "vertical_up")
		i.cyclic = Vector2(0.0, Input.get_axis("pitch_up", "pitch_down"))
		i.yaw = clampf(i.yaw + mouse.x * gain, -1.0, 1.0)
		i.cyclic.y = clampf(i.cyclic.y - mouse.y * gain * invert, -1.0, 1.0)
	else:
		var pitch_roll := Input.get_vector("roll_left", "roll_right", "pitch_up", "pitch_down")
		var side := Input.get_axis("yaw_left", "yaw_right")  # A/D, Q/E, right stick X.
		i.collective = Input.get_axis("collective_down", "collective_up")
		var mouse_yaws := Settings.choice("mouse_mode") == 1
		i.cyclic = pitch_roll
		i.yaw = 0.0
		if mouse_yaws:
			i.cyclic.x = clampf(i.cyclic.x + side, -1.0, 1.0)
		else:
			i.yaw = side
		# Pushing the mouse forward (negative y) puts the nose down, unless inverted.
		i.cyclic.y = clampf(i.cyclic.y - mouse.y * gain * invert, -1.0, 1.0)
		if mouse_yaws:
			i.yaw = clampf(i.yaw + mouse.x * gain, -1.0, 1.0)
		else:
			i.cyclic.x = clampf(i.cyclic.x + mouse.x * gain, -1.0, 1.0)
