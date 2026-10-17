class_name SettingsMenu
extends Control
## The settings screen shared by the title and the pause menu: Video, Graphics,
## Gameplay, Flight, Controls and Audio tabs of SettingRows, with the key bindings (click
## one to change it) beside the Controls tab. Every change is saved and applied at once; the graphics
## quality and the grass apply when the next match starts, because the map is built
## with them.

signal closed
signal changed  ## A setting changed (and was saved and applied).

const TABS := ["Video", "Graphics", "Gameplay", "Flight", "Controls", "Audio"]
const CONTROLS_TAB := 4
const RAMPS := [0.0, 0.1, 0.15, 0.25, 0.4, 0.6]

var _panel: PanelContainer
var _box: VBoxContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _page_holder: Control
var _keys: Control
var _current := 0
var _key_buttons: Array = []  ## [action, slot, Button] for every key in the bindings panel.
var _capture: Array = []  ## [action, slot, Button] while waiting for a key press.


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
		_keys.visible = index == CONTROLS_TAB
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
	_build_flight(_pages[3])
	_build_controls(_pages[4])
	_build_audio(_pages[5])
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
	_pick(page, "Time of day", ["Afternoon", "Dusk", "Night"], "time_of_day")
	_note(page, "Auto follows the quality preset. The preset, the grass and the time of day apply when the next match starts; global illumination, fog and reflections need the high-end renderer.")


func _build_gameplay(page: VBoxContainer) -> void:
	var fovs := PackedStringArray()
	for k in 9:
		fovs.append("%d°" % (60 + k * 5))
	_row(page, "Field of view", fovs, clampi((Settings.choice("fov") - 60) / 5, 0, 8),
		func(i: int) -> void: Settings.set_value("fov", 60 + i * 5))
	_pick(page, "Camera distance", ["Near", "Normal", "Far"], "camera_distance")
	_pick(page, "Camera shake", ["Off", "Half", "Full"], "camera_shake")
	_row(page, "Default view", ["Chase", "Cockpit"], 1 if Settings.flag("cockpit_view") else 0,
		func(i: int) -> void: Settings.set_value("cockpit_view", i == 1))
	_pick(page, "HUD size", ["Small", "Normal", "Large"], "hud_scale")
	_toggle(page, "Flight display", "hud_flight")
	_toggle(page, "Radar", "hud_radar")
	_toggle(page, "Damage flash", "damage_flash")
	_toggle(page, "Aim assist", "aim_assist")
	_toggle(page, "Controls overlay", "show_controls")


## The flight model and the assists, each on or off (like Wardogs).
func _build_flight(page: VBoxContainer) -> void:
	_pick(page, "Flight model", ["Easy", "Realistic"], "flight_model")
	_toggle(page, "Auto-level", "assist_level")
	_toggle(page, "Auto-hover", "assist_hover")
	_toggle(page, "Altitude hold", "assist_altitude")
	_toggle(page, "Coordinated turns", "assist_turn")
	_toggle(page, "Landing assist", "assist_landing")
	_toggle(page, "Engine auto-start", "assist_start")
	_note(page, "Auto-level and auto-hover act when you let go of the stick, altitude hold when the collective is centred, coordinated turns when the pedals are. The easy model flies itself; only landing assist and auto-start change it.")


func _build_controls(page: VBoxContainer) -> void:
	_toggle(page, "Mouse steering", "mouse_steer")
	_pick(page, "Mouse controls", ["Pitch & roll", "Pitch & yaw"], "mouse_mode")
	var levels := PackedStringArray()
	for k in 10:
		levels.append(str(k + 1))
	_row(page, "Mouse sensitivity", levels, Settings.choice("mouse_sensitivity") - 1,
		func(i: int) -> void: Settings.set_value("mouse_sensitivity", i + 1))
	_percent(page, "Mouse vertical", "mouse_vertical", 0.5, 1.5, 0.1)
	_toggle(page, "Invert mouse", "invert_mouse")
	_percent(page, "Roll rate (keys, pad)", "roll_rate", 0.3, 1.0, 0.1)
	_percent(page, "Pitch rate (keys, pad)", "pitch_rate", 0.3, 1.0, 0.1)
	_percent(page, "Yaw rate (keys, pad)", "yaw_rate", 0.3, 1.0, 0.1)
	var ramp_names := PackedStringArray()
	for r: float in RAMPS:
		ramp_names.append("Off" if r == 0.0 else "%.2f s" % r)
	var ramp := 2
	for k in RAMPS.size():
		if is_equal_approx(RAMPS[k], Settings.number("stick_ramp")):
			ramp = k
	_row(page, "Key stick ramp", ramp_names, ramp, func(i: int) -> void: Settings.set_value("stick_ramp", RAMPS[i]))
	var zones := [0.1, 0.15, 0.2, 0.25, 0.3, 0.4]
	var zone_names := PackedStringArray()
	for z: float in zones:
		zone_names.append("%d%%" % roundi(z * 100.0))
	var zone := 2
	for k in zones.size():
		if is_equal_approx(zones[k], Settings.number("deadzone")):
			zone = k
	_row(page, "Gamepad deadzone", zone_names, zone, func(i: int) -> void: Settings.set_value("deadzone", zones[i]))
	_note(page, "Click a key on the right to change it (Esc cancels, Delete clears). The gamepad keeps its layout.")


func _build_audio(page: VBoxContainer) -> void:
	var levels := PackedStringArray(["Off"])
	for k in 10:
		levels.append("%d%%" % ((k + 1) * 10))
	_row(page, "Master volume", levels, Settings.choice("volume"), func(i: int) -> void: Settings.set_value("volume", i))
	_row(page, "Effects volume", levels, Settings.choice("effects_volume"),
		func(i: int) -> void: Settings.set_value("effects_volume", i))
	_row(page, "Music volume", levels, Settings.choice("music_volume"),
		func(i: int) -> void: Settings.set_value("music_volume", i))


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
	Controls.apply_bindings()
	_apply()
	_build_pages()
	_refresh_keys()
	_show_tab(_current)


## Key bindings beside the Controls tab: every rebindable action with two keys; click
## one, then press the new key or mouse button.
func _bindings() -> Control:
	var panel := UiKit.panel(true, 28.0)
	panel.custom_minimum_size = Vector2(400.0, 560.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiKit.display("KEYS", 36))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_key_buttons.clear()
	for group: Array in Controls.REBINDABLE:
		list.add_child(_spacer(8))
		list.add_child(UiKit.caption(group[0]))
		for entry: Array in group[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var what := UiKit.label(entry[1], 15, UiKit.MUTED)
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(what)
			for slot in Controls.SLOTS:
				var key := _key_button()
				key.pressed.connect(_start_capture.bind(entry[0], slot, key))
				_key_buttons.append([entry[0], slot, key])
				row.add_child(key)
			list.add_child(row)
	_refresh_keys()
	box.add_child(_spacer(8))
	box.add_child(UiKit.rule())
	box.add_child(UiKit.label("Gamepad: left stick pitch and roll, right stick yaw and\ncollective. RT gun, LT rockets, RB missile, B flares,\nX mine, LB afterburner, Y camera, Start pause.\nIn menus: LB / RB (or Q / E) switch tabs.", 14, UiKit.FAINT))
	return panel


## A key in the bindings panel: looks like a keycap, works like a button.
func _key_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(92.0, 30.0)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", UiKit.font("text_medium"))
	for state in ["normal", "disabled"]:
		var s := UiKit.style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.22), 3)
		s.set_content_margin_all(3.0)
		b.add_theme_stylebox_override(state, s)
	for state in ["hover", "focus", "pressed"]:
		var s := UiKit.style(UiKit.HOVER, UiKit.ACCENT, 3)
		s.set_content_margin_all(3.0)
		b.add_theme_stylebox_override(state, s)
	return b


func _refresh_keys() -> void:
	for entry: Array in _key_buttons:
		var keys := Controls.keys_for(entry[0])
		var button: Button = entry[2]
		button.text = keys[entry[1]] if entry[1] < keys.size() else "—"


func _start_capture(action: String, slot: int, button: Button) -> void:
	_capture = [action, slot, button]
	button.text = "PRESS A KEY"


## While waiting for a new key, the next key press or click is the binding.
func _input(event: InputEvent) -> void:
	if _capture.is_empty() or not event.is_pressed() or event.is_echo():
		return
	var binding: Variant = Controls.binding_from(event)
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		binding = null
	elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_DELETE:
		Controls.rebind(_capture[0], _capture[1], null)
	elif binding != null:
		Controls.rebind(_capture[0], _capture[1], binding)
	elif not (event is InputEventKey or event is InputEventMouseButton):
		return  # A gamepad button or a wheel: keep waiting.
	get_viewport().set_input_as_handled()
	var button: Button = _capture[2]
	_capture = []
	_refresh_keys()
	button.grab_focus()
	changed.emit()


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
