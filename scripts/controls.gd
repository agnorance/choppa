extends Node
## Registers input actions for keyboard and gamepad at startup.

const DEADZONE := 0.2

# action -> list of bindings. Keys are Key constants, buttons are JoyButton constants,
# axes are [JoyAxis, direction].
var _bindings := {
	"move_forward": [KEY_W, [JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [KEY_S, [JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [KEY_A, [JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [KEY_D, [JOY_AXIS_LEFT_X, 1.0]],
	"yaw_left": [KEY_Q, KEY_LEFT, [JOY_AXIS_RIGHT_X, -1.0]],
	"yaw_right": [KEY_E, KEY_RIGHT, [JOY_AXIS_RIGHT_X, 1.0]],
	"lift_up": [KEY_SPACE, KEY_UP, [JOY_AXIS_RIGHT_Y, -1.0]],
	"lift_down": [KEY_C, KEY_DOWN, [JOY_AXIS_RIGHT_Y, 1.0]],
	"boost": [KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER, [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"trick": [KEY_F, JOY_BUTTON_A],
	"use_item": [KEY_R, JOY_BUTTON_X],
	"toggle_camera": [KEY_V, JOY_BUTTON_Y],
	"respawn": [KEY_BACKSPACE, JOY_BUTTON_BACK],
	"toggle_help": [KEY_F1],
}


func _ready() -> void:
	for action: String in _bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for binding: Variant in _bindings[action]:
			InputMap.action_add_event(action, _event_for(binding))


func _event_for(binding: Variant) -> InputEvent:
	if binding is Array:
		var axis := InputEventJoypadMotion.new()
		axis.axis = binding[0]
		axis.axis_value = binding[1]
		return axis
	# JoyButton values are all below 32; every Key constant we bind is 32 or above.
	if binding < 32:
		var button := InputEventJoypadButton.new()
		button.button_index = binding
		return button
	var key := InputEventKey.new()
	key.physical_keycode = binding
	return key
