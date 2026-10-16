extends Node
## Registers input actions for keyboard and gamepad at startup. Layout: the left stick
## or arrow keys are the cyclic (pitch and roll), W/S the collective, A/D the pedals; the
## mouse adds pitch plus roll or yaw (LocalPilot, Settings "mouse_mode").

const DEADZONE := 0.2

# action -> list of bindings. Keys are Key constants, buttons are JoyButton constants,
# axes are [JoyAxis, direction], mouse buttons are "mouse:<MouseButton>".
var _bindings := {
	"pitch_down": [KEY_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	"pitch_up": [KEY_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	"roll_left": [KEY_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	"roll_right": [KEY_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	"yaw_left": [KEY_A, KEY_Q, [JOY_AXIS_RIGHT_X, -1.0]],
	"yaw_right": [KEY_D, KEY_E, [JOY_AXIS_RIGHT_X, 1.0]],
	"collective_up": [KEY_W, KEY_SPACE, [JOY_AXIS_RIGHT_Y, -1.0]],
	"collective_down": [KEY_S, KEY_C, [JOY_AXIS_RIGHT_Y, 1.0]],
	"boost": [KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER],
	"fire": [KEY_CTRL, "mouse:%d" % MOUSE_BUTTON_LEFT, [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"use_item": [KEY_R, JOY_BUTTON_X],
	"toggle_camera": [KEY_V, JOY_BUTTON_Y],
	"respawn": [KEY_BACKSPACE, JOY_BUTTON_BACK],
	"toggle_help": [KEY_F1],
	"pause": [KEY_ESCAPE, JOY_BUTTON_START],
	"tab_left": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],  # Menus: previous tab.
	"tab_right": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
}


## Key bindings for the HUD overlay and the settings screen: [what, [keys...]] in display
## order. Entries starting with "~" are notes, not keys. Keyboard and mouse only; the
## gamepad follows the same actions. `mouse_yaws`: the "pitch & yaw" mouse layout.
static func cheat_sheet(mouse: bool, mouse_yaws := false) -> Array:
	var rows := []
	if mouse and mouse_yaws:
		rows.append(["Pitch / turn", ["~mouse"]])
		rows.append(["Roll", ["A", "D"]])
	elif mouse:
		rows.append(["Pitch / roll", ["~mouse"]])
		rows.append(["Turn", ["A", "D"]])
	else:
		rows.append(["Pitch / roll", ["Up", "Down", "Left", "Right"]])
		rows.append(["Turn", ["A", "D"]])
	rows.append_array([
		["Collective", ["W", "S"]],
		["Afterburner", ["Shift"]],
		["Fire", ["LMB", "Ctrl"]],
		["Item", ["R"]],
		["Camera", ["V"]],
		["Respawn", ["Backspace"]],
		["Pause", ["Esc"]],
		["This overlay", ["F1"]],
	])
	return rows

func _ready() -> void:
	for action: String in _bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for binding: Variant in _bindings[action]:
			InputMap.action_add_event(action, _event_for(binding))


func _event_for(binding: Variant) -> InputEvent:
	if binding is String:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (binding as String).split(":")[1].to_int()
		return mouse
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
