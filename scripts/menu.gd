class_name Menu
extends CanvasLayer
## Title screen over the slowly orbiting arena: the modes, the map, settings. Works
## with a mouse, a gamepad or a thumb.

signal mode_chosen(mode: String, map_id: String)

static var map_index := 0  ## Remembered across menu visits.

var _home: VBoxContainer
var _chrome: Array[Control] = []  ## Version and hints, hidden with the title.
var _settings: SettingsMenu
var _battle: Button


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.theme = UiKit.theme()
	add_child(root)

	# Darken the left side where the text sits; the arena stays visible on the right.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.03, 0.05, 0.92))
	gradient.set_color(1, Color(0.02, 0.03, 0.05, 0.0))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.15, 0.0)
	shade_texture.fill_to = Vector2(0.85, 0.0)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	_home = VBoxContainer.new()
	_home.anchor_top = 0.5
	_home.anchor_bottom = 0.5
	_home.offset_left = 110.0
	_home.offset_right = 110.0
	_home.grow_horizontal = Control.GROW_DIRECTION_END
	_home.grow_vertical = Control.GROW_DIRECTION_BOTH
	_home.add_theme_constant_override("separation", 6)
	root.add_child(_home)

	var title := UiKit.display("CHOPPA", 116)
	_home.add_child(title)
	_home.add_child(UiKit.caption("Get to the choppa!", 16, UiKit.ACCENT))
	_home.add_child(_gap(22))

	var maps := GameMap.catalog()
	var names := PackedStringArray()
	for entry: Array in maps:
		names.append((entry[0] as String).capitalize())
	_battle = _button("Battle  ·  3 bots", func() -> void: mode_chosen.emit("battle", maps[map_index][1]))
	_button("Free flight", func() -> void: mode_chosen.emit("free", maps[map_index][1]))
	_button("Race  ·  test range", func() -> void: mode_chosen.emit("race", "range"))
	_home.add_child(_gap(8))
	var map_row := SettingRow.new("MAP", names, map_index)
	map_row.custom_minimum_size = Vector2(380, 46)
	map_row.changed.connect(func(i: int) -> void: map_index = i)
	_home.add_child(map_row)
	var bots_row := SettingRow.new("BOTS", ["Easy", "Normal", "Hard"], Settings.choice("bot_difficulty"))
	bots_row.custom_minimum_size = Vector2(380, 46)
	bots_row.changed.connect(func(i: int) -> void:
		Settings.set_value("bot_difficulty", i)
		Settings.save())
	_home.add_child(bots_row)
	_button("Settings", open_settings)
	if OS.get_name() != "Android":
		_button("Quit", func() -> void: get_tree().quit())

	var version := UiKit.label("v%s  ·  Godot %s" % [ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info().string.split(" ")[0]], 13, UiKit.FAINT)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 110.0
	version.offset_top = -40.0
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(version)
	_chrome.append(version)
	if not DisplayServer.is_touchscreen_available():
		var hint := UiKit.label("Up / down  select      Enter  confirm      Esc  back", 13, UiKit.FAINT)
		hint.anchor_left = 1.0
		hint.anchor_right = 1.0
		hint.anchor_top = 1.0
		hint.anchor_bottom = 1.0
		hint.offset_right = -110.0
		hint.offset_top = -40.0
		hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		root.add_child(hint)
		_chrome.append(hint)

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	root.add_child(_settings)
	_battle.grab_focus()


## Shows the settings screen in place of the title.
func open_settings(tab := 0) -> void:
	_home.visible = false
	for c in _chrome:
		c.visible = false
	_settings.open(tab)


func _close_settings() -> void:
	_settings.visible = false
	_home.visible = true
	for c in _chrome:
		c.visible = true
	_battle.grab_focus()


func _button(text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, 380.0)
	b.pressed.connect(on_pressed)
	_home.add_child(b)
	return b


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c
