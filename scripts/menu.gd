class_name Menu
extends CanvasLayer
## Title screen. Big buttons so it works with a thumb, a mouse or a gamepad.

signal mode_chosen(mode: String)


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.35)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "CHOPPA"
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tagline := Label.new()
	tagline.text = "GET TO THE CHOPPA!"
	tagline.add_theme_font_size_override("font_size", 28)
	tagline.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tagline.add_theme_constant_override("outline_size", 6)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)

	var race := make_button("RACE  vs  3 BOTS")
	race.pressed.connect(mode_chosen.emit.bind("race"))
	box.add_child(race)
	var free := make_button("FREE FLIGHT")
	free.pressed.connect(mode_chosen.emit.bind("free"))
	box.add_child(free)
	if OS.get_name() != "Android":
		var quit := make_button("QUIT")
		quit.pressed.connect(func() -> void: get_tree().quit())
		box.add_child(quit)
	race.grab_focus()


static func make_button(text: String, font_size := 36) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(440, 84)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(14)
		style.bg_color = {
			"normal": Color(0.1, 0.12, 0.16, 0.85),
			"hover": Color(0.2, 0.24, 0.3, 0.9),
			"pressed": Color(0.95, 0.5, 0.1, 0.95),
			"focus": Color(0, 0, 0, 0),
		}[state]
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(1.0, 0.6, 0.15)
			style.set_border_width_all(4)
		button.add_theme_stylebox_override(state, style)
	return button
