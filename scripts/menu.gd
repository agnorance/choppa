class_name Menu
extends CanvasLayer
## Title screen over the slowly orbiting arena: the modes, the map, settings. Works
## with a mouse, a gamepad or a thumb.

signal mode_chosen(mode: String, map_id: String)

static var map_index := 0  ## Remembered across menu visits.
static var join_address := "127.0.0.1"  ## The server "join" connects to (main.gd reads it).
static var notice := ""  ## Shown once on the title screen, e.g. why a connection ended.

var _home: VBoxContainer
var _chrome: Array[Control] = []  ## Version and hints, hidden with the title.
var _settings: SettingsMenu
var _hangar: Hangar
var _battle: Button
var _blurb: Label  ## One line about the chosen helicopter.
var _online: VBoxContainer
var _name: LineEdit
var _address: LineEdit
var _join: Button


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
	_home.add_theme_constant_override("separation", 4)
	root.add_child(_home)

	var title := UiKit.display("CHOPPA", 92)
	_home.add_child(title)
	_home.add_child(UiKit.caption("Get to the choppa!", 16, UiKit.ACCENT))
	if notice != "":
		_home.add_child(UiKit.label(notice, 16, UiKit.DANGER))
		notice = ""
	_home.add_child(_gap(10))

	var maps := GameMap.catalog()
	var names := PackedStringArray()
	for entry: Array in maps:
		names.append((entry[0] as String).capitalize())
	_battle = _button("Battle  ·  3 bots", func() -> void: mode_chosen.emit("battle", maps[map_index][1]))
	_button("Free flight", func() -> void: mode_chosen.emit("free", maps[map_index][1]))
	_button("Race  ·  test range", func() -> void: mode_chosen.emit("race", "range"))
	_button("Multiplayer", open_online)
	_home.add_child(_gap(4))
	var map_row := SettingRow.new("MAP", names, map_index)
	map_row.custom_minimum_size = Vector2(380, 46)
	map_row.changed.connect(func(i: int) -> void: map_index = i)
	_home.add_child(map_row)
	var class_row := SettingRow.new("HELICOPTER", Airframe.names(), Settings.choice("airframe"))
	class_row.custom_minimum_size = Vector2(380, 46)
	class_row.changed.connect(func(i: int) -> void:
		Settings.set_value("airframe", i)
		Settings.save()
		_blurb.text = Airframe.spec(Airframe.ORDER[i]).blurb)
	_home.add_child(class_row)
	_blurb = UiKit.label(Airframe.spec(Airframe.ORDER[Settings.choice("airframe")]).blurb, 14, UiKit.MUTED)
	_home.add_child(_blurb)
	var model_row := SettingRow.new("FLIGHT", ["Easy", "Realistic"], Settings.choice("flight_model"))
	model_row.custom_minimum_size = Vector2(380, 46)
	model_row.changed.connect(func(i: int) -> void:
		Settings.set_value("flight_model", i)
		Settings.save())
	_home.add_child(model_row)
	var bots_row := SettingRow.new("BOTS", ["Easy", "Normal", "Hard"], Settings.choice("bot_difficulty"))
	bots_row.custom_minimum_size = Vector2(380, 46)
	bots_row.changed.connect(func(i: int) -> void:
		Settings.set_value("bot_difficulty", i)
		Settings.save())
	_home.add_child(bots_row)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	_home.add_child(pair)
	for entry: Array in [["Hangar", open_hangar], ["Settings", open_settings], ["Quit", get_tree().quit]]:
		var b := UiKit.button(entry[0], 122.0)
		b.pressed.connect(entry[1])
		pair.add_child(b)

	var version := UiKit.label("v%s  ·  Godot %s" % [ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info().string.split(" ")[0]], 13, UiKit.FAINT)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 110.0
	version.offset_top = -40.0
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(version)
	_chrome.append(version)
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
	_hangar = Hangar.new()
	_hangar.visible = false
	_hangar.closed.connect(_close_hangar)
	root.add_child(_hangar)
	_build_online(root)
	_battle.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _online.visible and event.is_action_pressed("ui_cancel"):
		_close_online()
		get_viewport().set_input_as_handled()


## Join a server or host a battle: your name, the address, two buttons.
func _build_online(root: Control) -> void:
	_online = VBoxContainer.new()
	_online.anchor_top = 0.5
	_online.anchor_bottom = 0.5
	_online.offset_left = 110.0
	_online.offset_right = 110.0
	_online.grow_horizontal = Control.GROW_DIRECTION_END
	_online.grow_vertical = Control.GROW_DIRECTION_BOTH
	_online.add_theme_constant_override("separation", 4)
	_online.visible = false
	root.add_child(_online)
	_online.add_child(UiKit.display("MULTIPLAYER", 64))
	_online.add_child(UiKit.caption("Battle over the internet  ·  up to 6 pilots", 16, UiKit.ACCENT))
	_online.add_child(_gap(14))
	_online.add_child(UiKit.caption("Pilot name", 13))
	_name = _field(Settings.value("pilot_name"), "Pilot", 16)
	_online.add_child(_gap(8))
	_online.add_child(UiKit.caption("Server address", 13))
	_address = _field(Settings.value("server_address"), "address or address:port", 64)
	_address.text_submitted.connect(func(_text: String) -> void: _join_server())
	_join = _online_button("Join", _join_server)
	_online.add_child(_gap(14))
	_online_button("Host a battle", func() -> void:
		_save_online()
		mode_chosen.emit("host", GameMap.catalog()[map_index][1]))
	var hint := UiKit.label("Hosting uses the map from the title screen and UDP port %d.\nFriends outside your network need that port forwarded to this PC." % NetGame.PORT, 14, UiKit.MUTED)
	_online.add_child(hint)
	_online.add_child(_gap(14))
	_online_button("Back", _close_online)


func _field(text: String, placeholder: String, max_length: int) -> LineEdit:
	var f := LineEdit.new()
	f.text = text
	f.placeholder_text = placeholder
	f.max_length = max_length
	f.custom_minimum_size = Vector2(380, 46)
	_online.add_child(f)
	return f


func _online_button(text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, 380.0)
	b.pressed.connect(on_pressed)
	_online.add_child(b)
	return b


func _save_online() -> void:
	Settings.set_value("pilot_name", _name.text.strip_edges())
	Settings.set_value("server_address", _address.text.strip_edges())
	Settings.save()


func _join_server() -> void:
	_save_online()
	join_address = _address.text.strip_edges() if _address.text.strip_edges() != "" else "127.0.0.1"
	mode_chosen.emit("join", GameMap.catalog()[map_index][1])


## Shows the multiplayer screen in place of the title.
func open_online() -> void:
	_home.visible = false
	_online.visible = true
	_join.grab_focus()


func _close_online() -> void:
	_online.visible = false
	_home.visible = true
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


## Shows the hangar (level, camos, store) in place of the title.
func open_hangar() -> void:
	_home.visible = false
	for c in _chrome:
		c.visible = false
	_hangar.open()


func _close_hangar() -> void:
	_hangar.visible = false
	_home.visible = true
	for c in _chrome:
		c.visible = true
	_battle.grab_focus()
