class_name PauseMenu
extends CanvasLayer
## Esc (or Start) in a match: resume, settings, restart, back to the title, quit. Keeps
## running while the tree is paused.

signal resumed
signal restart_requested
signal menu_requested
signal settings_changed

var _home: Control
var _settings: SettingsMenu
var _resume: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.theme = UiKit.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	root.add_child(dim)

	_home = UiKit.panel(true, 28.0)
	_home.anchor_left = 0.5
	_home.anchor_right = 0.5
	_home.anchor_top = 0.5
	_home.anchor_bottom = 0.5
	_home.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_home.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_home)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_home.add_child(box)
	box.add_child(UiKit.display("PAUSED", 36))
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	box.add_child(gap)
	_resume = _button(box, "Resume", func() -> void: resumed.emit())
	_button(box, "Settings", _open_settings)
	_button(box, "Restart match", func() -> void: restart_requested.emit())
	_button(box, "Main menu", func() -> void: menu_requested.emit())
	_button(box, "Quit game", func() -> void: get_tree().quit())

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	_settings.changed.connect(func() -> void: settings_changed.emit())
	root.add_child(_settings)
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible:
		return  # The settings screen handles its own Esc.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		resumed.emit()
		get_viewport().set_input_as_handled()


func _open_settings() -> void:
	_home.visible = false
	_settings.open()


func _close_settings() -> void:
	_settings.visible = false
	_home.visible = true
	_resume.grab_focus()


func _button(box: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, 300.0)
	b.pressed.connect(on_pressed)
	box.add_child(b)
	return b
