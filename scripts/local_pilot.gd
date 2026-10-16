class_name LocalPilot
extends Node
## Feeds keyboard, mouse, gamepad and on-screen touch controls into a choppa's PilotInput.

## Yaw or lift per pixel of mouse travel at sensitivity 1; the setting scales it 1..10.
const MOUSE_GAIN := 0.012

var choppa: Choppa
var touch: TouchControls

var _mouse := Vector2.ZERO  ## Mouse travel since the last tick, in pixels.


func _ready() -> void:
	# Write the input before the choppa reads it in the same physics tick.
	process_physics_priority = -10


## Mouse motion arrives as events between ticks; it becomes yaw and lift on the next one.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += (event as InputEventMouseMotion).relative


## For tests: as if the mouse had moved by `relative` pixels.
func feed_mouse(relative: Vector2) -> void:
	_mouse += relative


func _physics_process(_delta: float) -> void:
	var i := choppa.input
	i.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	i.yaw = Input.get_axis("yaw_left", "yaw_right")
	i.lift = Input.get_axis("lift_down", "lift_up")
	i.boost = Input.is_action_pressed("boost")
	i.fire = Input.is_action_pressed("fire")
	i.trick = Input.is_action_pressed("trick")
	i.use_item = Input.is_action_pressed("use_item")
	if Settings.flag("mouse_steer") and _mouse != Vector2.ZERO:
		var gain := Settings.choice("mouse_sensitivity") * MOUSE_GAIN
		i.yaw = clampf(i.yaw + _mouse.x * gain, -1.0, 1.0)
		var climb := -_mouse.y * gain * (-1.0 if Settings.flag("invert_mouse") else 1.0)
		i.lift = clampf(i.lift + climb, -1.0, 1.0)
	_mouse = Vector2.ZERO
	if touch and touch.visible:
		i.move = (i.move + touch.move).limit_length(1.0)
		i.yaw = clampf(i.yaw + touch.look.x, -1.0, 1.0)
		i.lift = clampf(i.lift + touch.look.y, -1.0, 1.0)
		i.boost = i.boost or touch.is_pressed("boost")
		# Your right thumb is busy steering, so touch fires by itself once locked on.
		i.fire = i.fire or touch.is_pressed("fire") or choppa.aim_target() != null
		i.trick = i.trick or touch.is_pressed("trick")
		i.use_item = i.use_item or touch.is_pressed("use_item")
