class_name SettingRow
extends Button
## One line of the settings menu: a name on the left, the chosen option on the right.
## Left/right (keys, d-pad, or a click on the arrows beside the value) step through the
## options; pressing the row steps forward. Being a Button, it takes focus and works
## with a gamepad.

signal changed(index: int)

const VALUE_WIDTH := 230.0  ## Room for "Exclusive fullscreen" without the arrows covering it.
const ARROW_WIDTH := 30.0

var options: PackedStringArray
var index := 0

var _value: Label
var _left: Label
var _right: Label


func _init(name_text: String, choices: PackedStringArray, current: int) -> void:
	text = name_text
	options = choices
	index = clampi(current, 0, choices.size() - 1)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, 36)
	add_theme_font_override("font", UiKit.font("text_medium"))
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_focus_color", UiKit.TEXT)
	add_theme_color_override("font_pressed_color", UiKit.TEXT)
	add_theme_color_override("font_hover_pressed_color", UiKit.TEXT)
	add_theme_stylebox_override("pressed", UiKit.style(UiKit.HOVER, Color(1, 1, 1, 0.2)))
	add_theme_stylebox_override("hover_pressed", UiKit.style(UiKit.HOVER, Color(1, 1, 1, 0.2)))
	_value = _side_label(options[index], -ARROW_WIDTH - VALUE_WIDTH, -ARROW_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
	_left = _side_label("<", -2.0 * ARROW_WIDTH - VALUE_WIDTH, -ARROW_WIDTH - VALUE_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
	_right = _side_label(">", -ARROW_WIDTH, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	pressed.connect(func() -> void: step(1))
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# The left arrow steps back; anywhere else steps forward through `pressed`.
		var from_right := size.x - (event as InputEventMouseButton).position.x
		if from_right > ARROW_WIDTH + VALUE_WIDTH and from_right < 2.0 * ARROW_WIDTH + VALUE_WIDTH:
			step(-1)
			accept_event()


func step(delta: int) -> void:
	index = posmod(index + delta, options.size())
	_refresh()
	changed.emit(index)


func _refresh() -> void:
	_value.text = options[index]
	var active := has_focus() or is_hovered()
	_left.visible = active
	_right.visible = active
	_value.add_theme_color_override("font_color", UiKit.ACCENT if active else UiKit.TEXT)


func _side_label(text_value: String, left: float, right: float, align: HorizontalAlignment) -> Label:
	var l := UiKit.label(text_value, 18, UiKit.MUTED, "condensed")
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = left
	l.offset_right = right
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l
