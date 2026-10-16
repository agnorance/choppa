class_name SettingsMenu
extends Control
## The settings screen shared by the title menu and the pause menu: graphics, controls
## and audio as columns of SettingRows, with the key bindings beside them on desktop.
## Every change is saved and applied at once; the graphics quality applies when the
## next match starts, because the map is built with it.

signal closed
signal changed  ## A setting changed (and was saved and applied).

var _first: Control


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.anchor_left = 0.5
	columns.anchor_right = 0.5
	columns.anchor_top = 0.5
	columns.anchor_bottom = 0.5
	columns.grow_horizontal = Control.GROW_DIRECTION_BOTH
	columns.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(columns)

	var panel := UiKit.panel(true, 28.0)
	panel.custom_minimum_size.x = 560.0
	columns.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiKit.display("SETTINGS", 36))
	box.add_child(_spacer(4))

	_section(box, "Graphics")
	var qualities := PackedStringArray(["Auto", "Low", "Medium", "High"])
	_first = _row(box, "Quality", qualities, Settings.quality + 1, func(i: int) -> void: Settings.quality = i - 1)
	if OS.get_name() != "Android":
		_row(box, "Window", ["Windowed", "Fullscreen"], 1 if Settings.fullscreen else 0,
			func(i: int) -> void: Settings.fullscreen = i == 1)
	_row(box, "V-Sync", ["Off", "On"], 1 if Settings.vsync else 0, func(i: int) -> void: Settings.vsync = i == 1)
	var scales := PackedStringArray()
	for k in 6:
		scales.append("%d%%" % (50 + k * 10))
	_row(box, "Render scale", scales, roundi((Settings.render_scale - 0.5) / 0.1),
		func(i: int) -> void: Settings.render_scale = 0.5 + i * 0.1)
	_row(box, "FPS counter", ["Off", "On"], 1 if Settings.show_fps else 0, func(i: int) -> void: Settings.show_fps = i == 1)
	var note := UiKit.label("Quality applies when the next match starts.", 14, UiKit.FAINT)
	box.add_child(note)

	_section(box, "Controls")
	var touch := DisplayServer.is_touchscreen_available()
	if not touch:
		_row(box, "Mouse steering", ["Off", "On"], 1 if Settings.mouse_steer else 0,
			func(i: int) -> void: Settings.mouse_steer = i == 1)
		var levels := PackedStringArray()
		for k in 10:
			levels.append(str(k + 1))
		_row(box, "Mouse sensitivity", levels, Settings.mouse_sensitivity - 1,
			func(i: int) -> void: Settings.mouse_sensitivity = i + 1)
		_row(box, "Invert mouse", ["Off", "On"], 1 if Settings.invert_mouse else 0,
			func(i: int) -> void: Settings.invert_mouse = i == 1)
		_row(box, "Controls overlay", ["Off", "On"], 1 if Settings.show_controls else 0,
			func(i: int) -> void: Settings.show_controls = i == 1)
	else:
		box.add_child(UiKit.label("Touch: left half flies, right half turns and climbs.", 14, UiKit.FAINT))

	_section(box, "Audio")
	var volumes := PackedStringArray(["Off"])
	for k in 10:
		volumes.append("%d%%" % ((k + 1) * 10))
	_row(box, "Volume", volumes, Settings.volume, func(i: int) -> void: Settings.volume = i)

	box.add_child(_spacer(10))
	var back := UiKit.button("Back", 0.0)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)

	if not touch:
		columns.add_child(_bindings())


## Puts the keyboard focus on the first row.
func open() -> void:
	visible = true
	_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _section(box: VBoxContainer, title: String) -> void:
	box.add_child(_spacer(6))
	box.add_child(UiKit.caption(title, 13, UiKit.ACCENT))
	box.add_child(UiKit.rule())


func _row(box: VBoxContainer, name_text: String, options: PackedStringArray, current: int, on_change: Callable) -> SettingRow:
	var row := SettingRow.new(name_text, options, current)
	row.changed.connect(func(i: int) -> void:
		on_change.call(i)
		Settings.save()
		Settings.apply(get_tree())
		changed.emit())
	box.add_child(row)
	return row


## Key bindings, read-only, beside the settings on desktop.
func _bindings() -> Control:
	var panel := UiKit.panel(true, 28.0)
	panel.custom_minimum_size.x = 320.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiKit.display("KEYS", 36))
	box.add_child(_spacer(20))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for row: Array in Controls.cheat_sheet(true):
		var what := UiKit.label(row[0], 16, UiKit.MUTED)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(what)
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 4)
		keys.alignment = BoxContainer.ALIGNMENT_END
		for key: String in row[1]:
			if key.begins_with("~"):
				var text := UiKit.label(key.substr(1), 14, UiKit.MUTED)
				text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				keys.add_child(text)
			else:
				keys.add_child(UiKit.keycap(key))
		grid.add_child(keys)
	box.add_child(_spacer(16))
	box.add_child(UiKit.rule())
	box.add_child(_spacer(8))
	var pad := UiKit.label("Gamepad: left stick flies, right stick turns and climbs,\nRB boost, RT fire, A trick, X item, Y camera, Start pause.", 14, UiKit.FAINT)
	box.add_child(pad)
	return panel


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
