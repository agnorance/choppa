class_name Hud
extends CanvasLayer
## Speed, altitude, boost meter, item slot and trick call-outs for one choppa.

const HELP := """WASD fly   Q/E turn   Space/C up/down   Shift boost
F trick (+direction)   R item   V camera   Backspace respawn   F1 help"""

var choppa: Choppa
var touch: TouchControls

var _speed: Label
var _altitude: Label
var _fps: Label
var _boost: ProgressBar
var _item: Label
var _callout: Label
var _help: Label
var _callout_time := 0.0


func _init(target: Choppa) -> void:
	choppa = target


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_speed = _label(root, 40, Vector2(0, 0), Vector2(24, 16))
	_altitude = _label(root, 24, Vector2(0, 0), Vector2(24, 70))
	_fps = _label(root, 16, Vector2(0, 0), Vector2(24, 104))
	_fps.modulate.a = 0.6

	_item = _label(root, 28, Vector2(1, 0), Vector2(-24, 16))

	_boost = ProgressBar.new()
	_boost.max_value = 1.0
	_boost.show_percentage = false
	_boost.custom_minimum_size = Vector2(360, 22)
	_place(_boost, Vector2(0.5, 1), Vector2(0, -26))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.1)
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	back.set_corner_radius_all(6)
	_boost.add_theme_stylebox_override("fill", fill)
	_boost.add_theme_stylebox_override("background", back)
	root.add_child(_boost)
	var boost_label := _label(root, 16, Vector2(0.5, 1), Vector2(0, -52))
	boost_label.text = "BOOST"

	_callout = _label(root, 56, Vector2(0.5, 0.3), Vector2.ZERO)
	_callout.grow_vertical = Control.GROW_DIRECTION_END
	_callout.modulate.a = 0.0

	_help = _label(root, 18, Vector2(0, 1), Vector2(24, -24))
	_help.text = HELP

	touch = TouchControls.new()
	touch.anchor_right = 1.0
	touch.anchor_bottom = 1.0
	touch.visible = DisplayServer.is_touchscreen_available()
	_help.visible = not touch.visible
	root.add_child(touch)

	choppa.trick_landed.connect(_on_trick_landed)
	choppa.trick_botched.connect(func(_name: String) -> void: _show_callout("BOTCHED", Color(1, 0.3, 0.3)))
	choppa.item_changed.connect(func(_name: String) -> void: _update_item())
	_update_item()


func toggle_help() -> void:
	_help.visible = not _help.visible


func _process(delta: float) -> void:
	_speed.text = "%d km/h" % roundi(choppa.velocity.length() * 3.6)
	_altitude.text = "ALT %d m" % roundi(maxf(choppa.altitude, 0.0))
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	_boost.value = choppa.boost_meter
	if _callout_time > 0.0:
		_callout_time -= delta
		_callout.modulate.a = clampf(_callout_time / 0.4, 0.0, 1.0)


func _on_trick_landed(trick_name: String, reward: float, low: bool) -> void:
	var text := "%s!  +%d%%" % [trick_name, roundi(reward * 100.0)]
	if low:
		text += "\nLOW x2"
	_show_callout(text, Color(1.0, 0.85, 0.2))


func _show_callout(text: String, color: Color) -> void:
	_callout.text = text
	_callout.add_theme_color_override("font_color", color)
	_callout_time = 1.2


func _update_item() -> void:
	_item.text = "ITEM: %s" % (choppa.item if choppa.item != "" else "-")


## Pins a control's corner (or edge middle, for 0.5) at `anchor` (fractions of the
## screen) plus `offset` pixels, growing away from the screen edge.
func _place(control: Control, anchor: Vector2, offset: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_right = offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y
	control.grow_horizontal = _grow(anchor.x)
	control.grow_vertical = _grow(anchor.y)


func _grow(anchor: float) -> Control.GrowDirection:
	if anchor == 0.0:
		return Control.GROW_DIRECTION_END
	if anchor == 1.0:
		return Control.GROW_DIRECTION_BEGIN
	return Control.GROW_DIRECTION_BOTH


func _label(parent: Control, font_size: int, anchor: Vector2, offset: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = int(anchor.x * 2.0) as HorizontalAlignment
	parent.add_child(label)
	_place(label, anchor, offset)
	return label
