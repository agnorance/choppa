extends Node
## Registers input actions for keyboard and gamepad at startup. Layout: the left stick
## or arrow keys are the cyclic (pitch and roll), W/S the collective, A/D the pedals; the
## mouse adds pitch plus roll or yaw (LocalPilot, Settings "mouse_mode").
##
## Keyboard and mouse bindings can be changed in the settings (Controls tab): Settings
## "bindings" maps an action to its keys and replaces the defaults below. The gamepad
## keeps its layout.

const DEADZONE := 0.2

# action -> list of bindings. Keys are Key constants, buttons are JoyButton constants,
# axes are [JoyAxis, direction], mouse buttons are "mouse:<MouseButton>".
const DEFAULTS := {
	"pitch_down": [KEY_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	"pitch_up": [KEY_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	"roll_left": [KEY_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	"roll_right": [KEY_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	"yaw_left": [KEY_A, KEY_Q, [JOY_AXIS_RIGHT_X, -1.0]],
	"yaw_right": [KEY_D, KEY_E, [JOY_AXIS_RIGHT_X, 1.0]],
	"collective_up": [KEY_W, KEY_SPACE, [JOY_AXIS_RIGHT_Y, -1.0]],
	"collective_down": [KEY_S, KEY_C, [JOY_AXIS_RIGHT_Y, 1.0]],
	# The easy model has its own actions, so no key does two things there: Space/C only
	# climb and dive (they used to drive forward and back too, owner: "C doesn't go down").
	"move_forward": [KEY_W, [JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [KEY_S, [JOY_AXIS_LEFT_Y, 1.0]],
	"strafe_left": [KEY_A, [JOY_AXIS_LEFT_X, -1.0]],
	"strafe_right": [KEY_D, [JOY_AXIS_LEFT_X, 1.0]],
	"turn_left": [KEY_Q, [JOY_AXIS_RIGHT_X, -1.0]],
	"turn_right": [KEY_E, [JOY_AXIS_RIGHT_X, 1.0]],
	"vertical_up": [KEY_SPACE, [JOY_AXIS_RIGHT_Y, -1.0]],
	"vertical_down": [KEY_C, [JOY_AXIS_RIGHT_Y, 1.0]],
	"aim_up": [KEY_DOWN],
	"aim_down": [KEY_UP],
	"engine": [KEY_I, JOY_BUTTON_DPAD_UP],
	"radio": [KEY_N, JOY_BUTTON_DPAD_RIGHT],
	"boost": [KEY_SHIFT, JOY_BUTTON_LEFT_SHOULDER],
	"fire": [KEY_CTRL, "mouse:%d" % MOUSE_BUTTON_LEFT, [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"rockets": ["mouse:%d" % MOUSE_BUTTON_RIGHT, [JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"missile": [KEY_F, JOY_BUTTON_RIGHT_SHOULDER],
	"flares": [KEY_X, JOY_BUTTON_B],
	"mine": [KEY_R, JOY_BUTTON_X],
	"smoke": [KEY_G, JOY_BUTTON_DPAD_DOWN],
	"free_look": [KEY_ALT, JOY_BUTTON_RIGHT_STICK],
	"toggle_camera": [KEY_V, JOY_BUTTON_Y],
	"respawn": [KEY_BACKSPACE, JOY_BUTTON_BACK],
	"toggle_help": [KEY_F1],
	"pause": [KEY_ESCAPE, JOY_BUTTON_START],
	"tab_left": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],  # Menus: previous tab.
	"tab_right": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
}

## What the settings let you rebind, in display order: [section, [[action, label]...]].
## A key bound in one section is taken from the others in that section and in "Both
## models"; the two flight models never fly at once, so they may share keys.
const BOTH := "Both models"
const REBINDABLE := [
	["Realistic model", [
		["pitch_down", "Nose down"], ["pitch_up", "Nose up"], ["roll_left", "Roll left"],
		["roll_right", "Roll right"], ["yaw_left", "Turn left"], ["yaw_right", "Turn right"],
		["collective_up", "More power"], ["collective_down", "Less power"]]],
	["Easy model", [
		["move_forward", "Forward"], ["move_back", "Back"], ["strafe_left", "Strafe left"],
		["strafe_right", "Strafe right"], ["turn_left", "Turn left"], ["turn_right", "Turn right"],
		["vertical_up", "Climb"], ["vertical_down", "Dive"], ["aim_down", "Nose down"], ["aim_up", "Nose up"]]],
	[BOTH, [
		["fire", "Gun"], ["rockets", "Rockets"], ["missile", "Missile"], ["flares", "Flares"],
		["mine", "Mine"], ["smoke", "Smoke"], ["boost", "Afterburner"], ["engine", "Engine on / off"],
		["free_look", "Free look (hold)"], ["toggle_camera", "Camera"], ["radio", "Radio station"],
		["respawn", "Respawn"], ["toggle_help", "Key overlay"]]],
]
const SLOTS := 2  ## Keyboard or mouse bindings per action in the settings.
const NAMES := {"Escape": "Esc"}


## Key bindings for the HUD overlay: [what, [keys...]] in display order. Entries starting
## with "~" are notes, not keys. Keyboard and mouse only; the gamepad follows the same
## actions. `mouse_yaws`: the "pitch & yaw" mouse layout.
static func cheat_sheet(mouse: bool, mouse_yaws := false, easy := false) -> Array:
	var rows := []
	if easy:
		rows.append(["Fly", _first(["move_forward", "strafe_left", "move_back", "strafe_right"])])
		rows.append(["Turn", _first(["turn_left", "turn_right"]) + (["~or mouse"] if mouse else [])])
		rows.append(["Nose up / down", ["~mouse"] if mouse else _first(["aim_up", "aim_down"])])
		rows.append(["Climb / dive", _first(["vertical_up", "vertical_down"])])
	elif mouse and mouse_yaws:
		rows.append(["Pitch / turn", ["~mouse"]])
		rows.append(["Roll", _first(["yaw_left", "yaw_right"])])
	elif mouse:
		rows.append(["Pitch / roll", ["~mouse"]])
		rows.append(["Turn", _first(["yaw_left", "yaw_right"])])
	else:
		rows.append(["Pitch / roll", _first(["pitch_down", "pitch_up", "roll_left", "roll_right"])])
		rows.append(["Turn", _first(["yaw_left", "yaw_right"])])
	if not easy:
		rows.append(["Collective", _first(["collective_up", "collective_down"])])
	rows.append(["Afterburner", _first(["boost"])])
	rows.append(["Engine on / off", _first(["engine"])])
	rows.append(["Radio station", _first(["radio"])])
	rows.append(["Fire", Array(keys_for("fire"))])
	rows.append(["Rockets", _first(["rockets"])])
	rows.append(["Missile", _first(["missile"])])
	rows.append(["Flares", _first(["flares"])])
	rows.append(["Mine / smoke", _first(["mine", "smoke"])])
	rows.append(["Free look", _first(["free_look"])])
	rows.append(["Camera", _first(["toggle_camera"])])
	rows.append(["Respawn", _first(["respawn"])])
	rows.append(["Pause", ["Esc"]])
	rows.append(["This overlay", _first(["toggle_help"])])
	return rows


## The first key of each action (for the overlay); "—" where an action has none.
static func _first(actions: Array) -> Array:
	var out := []
	for action: String in actions:
		var keys := keys_for(action)
		out.append(keys[0] if not keys.is_empty() else "—")
	return out


## Names of an action's keyboard and mouse bindings now, e.g. ["Ctrl", "LMB"].
static func keys_for(action: String) -> PackedStringArray:
	var out := PackedStringArray()
	for binding: Variant in bindings_of(action):
		out.append(binding_name(binding))
	return out


## An action's keyboard and mouse bindings now: Key constants and "mouse:<n>".
static func bindings_of(action: String) -> Array:
	var stored: Dictionary = Settings.value("bindings")
	if stored.has(action):
		return (stored[action] as Array).duplicate()
	return (DEFAULTS.get(action, []) as Array).filter(_is_desk)


## A keyboard key or mouse button, not a gamepad binding.
static func _is_desk(binding: Variant) -> bool:
	return binding is String or (binding is int and binding >= 32)


static func binding_name(binding: Variant) -> String:
	if binding is String:
		var button := (binding as String).split(":")[1].to_int()
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
			MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get(button, "Mouse %d" % button)
	var text := OS.get_keycode_string(binding as int)
	return NAMES.get(text, text)


## The stored form of a key press or mouse click, or null for anything else.
static func binding_from(event: InputEvent) -> Variant:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return int(code) if code >= 32 else null
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return null
		return "mouse:%d" % button
	return null


## Binds `binding` to `slot` of `action` (null clears the slot) and takes it from the
## actions it would clash with, then saves and applies. Returns the actions that lost it.
static func rebind(action: String, slot: int, binding: Variant) -> Array:
	var stored: Dictionary = (Settings.value("bindings") as Dictionary).duplicate(true)
	var lost := []
	if binding != null:
		for other: String in _clashing(action):
			var keys := bindings_of(other)
			if other != action and keys.has(binding):
				keys.erase(binding)
				stored[other] = keys
				lost.append(other)
	var mine := bindings_of(action)
	if binding != null:
		mine.erase(binding)
	if slot < mine.size():
		mine[slot] = binding
	elif binding != null:
		mine.append(binding)
	stored[action] = mine.filter(func(b: Variant) -> bool: return b != null)
	Settings.set_value("bindings", stored)
	Settings.save()
	apply_bindings()
	return lost


## Actions a key bound to `action` would clash with: its own section and "Both models".
static func _clashing(action: String) -> Array:
	var out := []
	var section := _section_of(action)
	for group: Array in REBINDABLE:
		if group[0] == section or group[0] == BOTH or section == BOTH:
			for entry: Array in group[1]:
				out.append(entry[0])
	return out


static func _section_of(action: String) -> String:
	for group: Array in REBINDABLE:
		for entry: Array in group[1]:
			if entry[0] == action:
				return group[0]
	return ""


## Puts the keyboard and mouse bindings (stored or default) into the InputMap; the
## gamepad's stay as they are. Called at start, after loading the settings and on change.
static func apply_bindings() -> void:
	for group: Array in REBINDABLE:
		for entry: Array in group[1]:
			var action: String = entry[0]
			if not InputMap.has_action(action):
				continue
			for event in InputMap.action_get_events(action):
				if event is InputEventKey or event is InputEventMouseButton:
					InputMap.action_erase_event(action, event)
			for binding: Variant in bindings_of(action):
				InputMap.action_add_event(action, event_for(binding))


func _ready() -> void:
	for action: String in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for binding: Variant in DEFAULTS[action]:
			InputMap.action_add_event(action, event_for(binding))
	apply_bindings()


static func event_for(binding: Variant) -> InputEvent:
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
