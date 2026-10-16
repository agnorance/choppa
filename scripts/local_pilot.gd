class_name LocalPilot
extends Node
## Feeds keyboard, mouse, gamepad and on-screen touch controls into a choppa's PilotInput.
##
## Two mouse layouts (Settings "mouse_mode"): 0 puts pitch and roll on the mouse with
## yaw on A/D (the usual shooter helicopter layout); 1 puts pitch and yaw on the mouse
## with roll on A/D. Arrow keys and the left stick always give pitch and roll, W/S,
## Space/C and the right stick Y the collective.

## Stick per pixel of mouse travel at sensitivity 1; the setting scales it 1..10.
const MOUSE_GAIN := 0.012

var choppa: Choppa
var touch: TouchControls

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
	var pitch_roll := Input.get_vector("roll_left", "roll_right", "pitch_up", "pitch_down")
	var side := Input.get_axis("yaw_left", "yaw_right")  # A/D, Q/E, right stick X.
	i.collective = Input.get_axis("collective_down", "collective_up")
	i.boost = Input.is_action_pressed("boost")
	i.fire = Input.is_action_pressed("fire")
	i.use_item = Input.is_action_pressed("use_item")
	var mouse_yaws := Settings.choice("mouse_mode") == 1
	i.cyclic = pitch_roll
	i.yaw = 0.0
	if mouse_yaws:
		i.cyclic.x = clampf(i.cyclic.x + side, -1.0, 1.0)
	else:
		i.yaw = side
	if Settings.flag("mouse_steer") and _mouse != Vector2.ZERO:
		var gain := Settings.choice("mouse_sensitivity") * MOUSE_GAIN
		# Pushing the mouse forward (negative y) puts the nose down, unless inverted.
		var pitch := -_mouse.y * gain * (-1.0 if Settings.flag("invert_mouse") else 1.0)
		i.cyclic.y = clampf(i.cyclic.y + pitch, -1.0, 1.0)
		if mouse_yaws:
			i.yaw = clampf(i.yaw + _mouse.x * gain, -1.0, 1.0)
		else:
			i.cyclic.x = clampf(i.cyclic.x + _mouse.x * gain, -1.0, 1.0)
	_mouse = Vector2.ZERO
	if touch and touch.visible:
		i.cyclic = (i.cyclic + touch.cyclic).limit_length(1.0)
		i.yaw = clampf(i.yaw + touch.look.x, -1.0, 1.0)
		i.collective = clampf(i.collective + touch.look.y, -1.0, 1.0)
		i.boost = i.boost or touch.is_pressed("boost")
		# Your right thumb is busy steering, so touch fires by itself once locked on.
		i.fire = i.fire or touch.is_pressed("fire") or choppa.aim_target() != null
		i.use_item = i.use_item or touch.is_pressed("use_item")
