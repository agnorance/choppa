class_name TouchControls
extends Control
## On-screen controls for phones: drag anywhere on the left half to fly, on the right
## half to turn and climb, plus buttons. Sticks appear wherever your thumb lands.

signal camera_pressed

const STICK_RADIUS := 90.0

var move := Vector2.ZERO  ## Same convention as PilotInput.move.
var look := Vector2.ZERO  ## x: yaw, y: lift.

var _pressed := {}  ## button name -> true while held
var _sticks := {}  ## finger index -> {"left": bool, "origin": Vector2, "pos": Vector2}
var _button_fingers := {}  ## finger index -> button name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_pressed(button: String) -> bool:
	return _pressed.get(button, false)


## Button name -> [center, radius, label].
func _buttons() -> Dictionary:
	var w := size.x
	var h := size.y
	return {
		"boost": [Vector2(w - 110.0, h - 110.0), 70.0, "BOOST"],
		"trick": [Vector2(w - 270.0, h - 80.0), 58.0, "TRICK"],
		"fire": [Vector2(w - 260.0, h - 230.0), 62.0, "FIRE"],
		"use_item": [Vector2(w - 100.0, h - 270.0), 55.0, "ITEM"],
		"toggle_camera": [Vector2(w - 60.0, 140.0), 38.0, "CAM"],
	}


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _sticks.has(drag.index):
			_sticks[drag.index].pos = drag.position
	else:
		return
	_update_axes()
	queue_redraw()


func _press(finger: int, pos: Vector2) -> void:
	var buttons := _buttons()
	for button: String in buttons:
		if pos.distance_to(buttons[button][0]) <= buttons[button][1]:
			_button_fingers[finger] = button
			_pressed[button] = true
			if button == "toggle_camera":
				camera_pressed.emit()
			return
	_sticks[finger] = {"left": pos.x < size.x * 0.5, "origin": pos, "pos": pos}


func _release(finger: int) -> void:
	if _button_fingers.has(finger):
		_pressed[_button_fingers[finger]] = false
		_button_fingers.erase(finger)
	_sticks.erase(finger)


func _update_axes() -> void:
	move = Vector2.ZERO
	look = Vector2.ZERO
	for stick: Dictionary in _sticks.values():
		var v: Vector2 = ((stick.pos - stick.origin) / STICK_RADIUS).limit_length(1.0)
		v.y = -v.y  # Screen up means forward / climb.
		if stick.left:
			move = v
		else:
			look = v


## Thin rings and translucent discs; a held button fills with the accent.
func _draw() -> void:
	var font := UiKit.spaced("condensed", 1)
	for stick: Dictionary in _sticks.values():
		draw_arc(stick.origin, STICK_RADIUS, 0.0, TAU, 64, Color(UiKit.TEXT, 0.35), 2.0, true)
		var knob: Vector2 = stick.origin + (stick.pos - stick.origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 28.0, Color(UiKit.TEXT, 0.45), true, -1.0, true)
	var buttons := _buttons()
	for button: String in buttons:
		var center: Vector2 = buttons[button][0]
		var radius: float = buttons[button][1]
		var held := is_pressed(button)
		draw_circle(center, radius, Color(UiKit.ACCENT, 0.85) if held else Color(0.05, 0.06, 0.08, 0.45), true, -1.0, true)
		draw_arc(center, radius - 1.0, 0.0, TAU, 64, UiKit.ACCENT if held else Color(UiKit.TEXT, 0.35), 2.0, true)
		var label: String = buttons[button][2]
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		draw_string(font, center + Vector2(-text_size.x * 0.5, 7.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 20, UiKit.INK if held else UiKit.TEXT)
