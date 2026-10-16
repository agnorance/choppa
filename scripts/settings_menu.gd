class_name SettingsMenu
extends Control
## The settings screen shared by the title and the pause menu: Video, Graphics,
## Gameplay, Controls and Audio tabs of SettingRows, with the key bindings beside the
## Controls tab on desktop. Every change is saved and applied at once; the graphics
## quality and the grass apply when the next match starts, because the map is built
## with them.

signal closed
signal changed  ## A setting changed (and was saved and applied).

const TABS := ["Video", "Graphics", "Gameplay", "Controls", "Audio"]

var _panel: PanelContainer
var _box: VBoxContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _page_holder: Control
var _keys: Control
var _current := 0
var _touch := false


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch = DisplayServer.is_touchscreen_available()

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

	_panel = UiKit.panel(true, 28.0)
	_panel.custom_minimum_size = Vector2(600.0, 560.0)
	columns.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_box)
	_box.add_child(UiKit.display("SETTINGS", 36))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_box.add_child(tabs)
	for k in TABS.size():
		var tab := Button.new()
		tab.text = (TABS[k] as String).to_upper()
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 18)
		tab.add_theme_stylebox_override("hover", UiKit.style(UiKit.HOVER, Color(0, 0, 0, 0)))
		tab.add_theme_stylebox_override("pressed", UiKit.style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		tab.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
		tab.pressed.connect(_show_tab.bind(k))
		tabs.add_child(tab)
		_tab_buttons.append(tab)
	_box.add_child(UiKit.rule())

	_page_holder = Control.new()
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_page_holder)
	_build_pages()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	_box.add_child(bottom)
	var back := UiKit.button("Back", 0.0)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: closed.emit())
	bottom.add_child(back)
	var reset := UiKit.button("Reset to defaults", 220.0)
	reset.alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset.pressed.connect(_reset)
	bottom.add_child(reset)

	if not _touch:
		_keys = _bindings()
		columns.add_child(_keys)
	_show_tab(0)


## Shows the screen on a tab and puts the keyboard focus on its first row.
func open(tab := 0) -> void:
	visible = true
	_show_tab(tab)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		_show_tab(posmod(_current - 1, TABS.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_right"):
		_show_tab(posmod(_current + 1, TABS.size()))
		get_viewport().set_input_as_handled()


func _show_tab(index: int) -> void:
	_current = index
	for k in TABS.size():
		_pages[k].visible = k == index
		_tab_buttons[k].add_theme_color_override("font_color", UiKit.ACCENT if k == index else UiKit.MUTED)
		_tab_buttons[k].add_theme_stylebox_override("normal",
			_tab_style(UiKit.ACCENT) if k == index else _tab_style(Color(0, 0, 0, 0)))
	if _keys:
		_keys.visible = index == 3
	for child in _pages[index].get_children():
		if child is SettingRow:
			(child as SettingRow).grab_focus()
			break


## A flat tab with only an underline.
func _tab_style(underline: Color) -> StyleBoxFlat:
	var s := UiKit.style(Color(0, 0, 0, 0), underline, 0, 0)
	s.border_width_bottom = 2
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


func _build_pages() -> void:
	for page in _pages:
		page.queue_free()
	_pages.clear()
	for k in TABS.size():
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		page.anchor_right = 1.0
		page.offset_top = 6.0
		_page_holder.add_child(page)
		_pages.append(page)
	_build_video(_pages[0])
	_build_graphics(_pages[1])
	_build_gameplay(_pages[2])
	_build_controls(_pages[3])
	_build_audio(_pages[4])
	# Room for the tallest tab, so the panel keeps its height when switching. Counted
	# by hand: a wrapped note reports a silly minimum height before it has a width.
	var tallest := 0.0
	for page in _pages:
		var height := 24.0
		for child in page.get_children():
			height += 40.0 if child is SettingRow else 56.0
		tallest = maxf(tallest, height)
	_page_holder.custom_minimum_size.y = tallest


func _build_video(page: VBoxContainer) -> void:
	if OS.get_name() != "Android":
		_pick(page, "Window", ["Windowed", "Fullscreen", "Exclusive fullscreen"], "window")
		var sizes := Settings.resolutions()
		_row(page, "Resolution", sizes, sizes.find(Settings.value("resolution")),
			func(i: int) -> void: Settings.set_value("resolution", sizes[i]))
	_pick(page, "V-Sync", ["Off", "On", "Adaptive"], "vsync")
	var limits := [0, 30, 60, 90, 120, 144, 165, 240]
	var limit_names := PackedStringArray(["Unlimited"])
	for k in range(1, limits.size()):
		limit_names.append(str(limits[k]))
	_row(page, "FPS limit", limit_names, maxi(0, limits.find(Settings.choice("fps_limit"))),
		func(i: int) -> void: Settings.set_value("fps_limit", limits[i]))
	_percent(page, "Render scale", "render_scale", 0.5, 1.0, 0.1)
	var upscalers := PackedStringArray(["Bilinear", "FSR 1.0"])
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		upscalers.append("FSR 2.2")
	_row(page, "Upscaling", upscalers, mini(Settings.choice("upscaling"), upscalers.size() - 1),
		func(i: int) -> void: Settings.set_value("upscaling", i))
	_pick(page, "Anti-aliasing", ["Auto", "Off", "FXAA", "TAA", "MSAA 2x", "MSAA 4x", "MSAA 8x"], "antialiasing", 1)
	_percent(page, "Brightness", "brightness", 0.8, 1.2, 0.1)
	_toggle(page, "FPS counter", "show_fps")


func _build_graphics(page: VBoxContainer) -> void:
	_pick(page, "Quality preset", ["Auto", "Low", "Medium", "High"], "quality", 1)
	_pick(page, "Shadows", ["Auto", "Low", "Medium", "High", "Ultra"], "shadows", 1)
	_pick(page, "Global illumination", ["Auto", "Off", "On"], "gi", 1)
	_pick(page, "Ambient occlusion", ["Auto", "Off", "On"], "ambient_occlusion", 1)
	_pick(page, "Reflections", ["Auto", "Off", "On"], "reflections", 1)
	_pick(page, "Volumetric fog", ["Auto", "Off", "On"], "volumetric_fog", 1)
	_pick(page, "Bloom", ["Auto", "Off", "On"], "bloom", 1)
	_pick(page, "Grass", ["Auto", "Off", "Sparse", "Dense"], "grass", 1)
	_note(page, "Auto follows the quality preset. The preset and the grass apply when the next match starts; global illumination, fog and reflections need the high-end renderer.")


func _build_gameplay(page: VBoxContainer) -> void:
	var fovs := PackedStringArray()
	for k in 9:
		fovs.append("%d°" % (60 + k * 5))
	_row(page, "Field of view", fovs, clampi((Settings.choice("fov") - 60) / 5, 0, 8),
		func(i: int) -> void: Settings.set_value("fov", 60 + i * 5))
	_pick(page, "Camera shake", ["Off", "Half", "Full"], "camera_shake")
	_row(page, "Default view", ["Chase", "Cockpit"], 1 if Settings.flag("cockpit_view") else 0,
		func(i: int) -> void: Settings.set_value("cockpit_view", i == 1))
	_pick(page, "HUD size", ["Small", "Normal", "Large"], "hud_scale")
	_toggle(page, "Damage flash", "damage_flash")
	_toggle(page, "Aim assist", "aim_assist")
	_toggle(page, "Flight assist", "flight_assist")
	if not _touch:
		_toggle(page, "Controls overlay", "show_controls")


func _build_controls(page: VBoxContainer) -> void:
	if not _touch:
		_toggle(page, "Mouse steering", "mouse_steer")
		_pick(page, "Mouse controls", ["Pitch & roll", "Pitch & yaw"], "mouse_mode")
		var levels := PackedStringArray()
		for k in 10:
			levels.append(str(k + 1))
		_row(page, "Mouse sensitivity", levels, Settings.choice("mouse_sensitivity") - 1,
			func(i: int) -> void: Settings.set_value("mouse_sensitivity", i + 1))
		_toggle(page, "Invert mouse", "invert_mouse")
	var zones := [0.1, 0.15, 0.2, 0.25, 0.3, 0.4]
	var zone_names := PackedStringArray()
	for z: float in zones:
		zone_names.append("%d%%" % roundi(z * 100.0))
	var zone := 2
	for k in zones.size():
		if is_equal_approx(zones[k], Settings.number("deadzone")):
			zone = k
	_row(page, "Gamepad deadzone", zone_names, zone, func(i: int) -> void: Settings.set_value("deadzone", zones[i]))
	_pick(page, "Touch controls", ["Auto", "Off", "On"], "touch_controls", 1)
	if _touch:
		_note(page, "Left half flies, right half turns and climbs.")
	else:
		_note(page, "Key bindings are listed on the right; a gamepad follows the same actions.")


func _build_audio(page: VBoxContainer) -> void:
	var levels := PackedStringArray(["Off"])
	for k in 10:
		levels.append("%d%%" % ((k + 1) * 10))
	_row(page, "Master volume", levels, Settings.choice("volume"), func(i: int) -> void: Settings.set_value("volume", i))
	_row(page, "Effects volume", levels, Settings.choice("effects_volume"),
		func(i: int) -> void: Settings.set_value("effects_volume", i))


## Small print under a group of rows; wraps instead of widening the panel.
func _note(page: VBoxContainer, text: String) -> void:
	var note := UiKit.label(text, 14, UiKit.FAINT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.size_flags_horizontal = Control.SIZE_FILL
	page.add_child(note)


## A choice setting whose options map to the stored integers in order (offset by
## `shift`, 1 when the first option is "Auto", stored as -1).
func _pick(page: VBoxContainer, name_text: String, options: PackedStringArray, key: String, shift := 0) -> void:
	_row(page, name_text, options, Settings.choice(key) + shift, func(i: int) -> void: Settings.set_value(key, i - shift))


func _toggle(page: VBoxContainer, name_text: String, key: String) -> void:
	_row(page, name_text, ["Off", "On"], 1 if Settings.flag(key) else 0, func(i: int) -> void: Settings.set_value(key, i == 1))


## A float setting shown as percentages from `low` to `high` in `step`s.
func _percent(page: VBoxContainer, name_text: String, key: String, low: float, high: float, step: float) -> void:
	var names := PackedStringArray()
	var steps := roundi((high - low) / step)
	for k in steps + 1:
		names.append("%d%%" % roundi((low + k * step) * 100.0))
	_row(page, name_text, names, clampi(roundi((Settings.number(key) - low) / step), 0, steps),
		func(i: int) -> void: Settings.set_value(key, low + i * step))


func _row(page: VBoxContainer, name_text: String, options: PackedStringArray, current: int, on_change: Callable) -> SettingRow:
	var row := SettingRow.new(name_text, options, current)
	row.changed.connect(func(i: int) -> void:
		on_change.call(i)
		_apply())
	page.add_child(row)
	return row


func _apply() -> void:
	Settings.save()
	Settings.apply(get_tree())
	changed.emit()


func _reset() -> void:
	Settings.reset()
	_apply()
	_build_pages()
	_show_tab(_current)


## Key bindings, read-only, beside the Controls tab on desktop.
func _bindings() -> Control:
	var panel := UiKit.panel(true, 28.0)
	panel.custom_minimum_size = Vector2(320.0, 560.0)
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
	for row: Array in Controls.cheat_sheet(true, Settings.choice("mouse_mode") == 1):
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
	box.add_child(UiKit.label("Gamepad: left stick flies, right stick turns and climbs,\nRB boost, RT fire, A trick, X item, Y camera, Start pause.\nIn menus: LB / RB (or Q / E) switch tabs.", 14, UiKit.FAINT))
	return panel


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
