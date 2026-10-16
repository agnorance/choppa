class_name Settings
extends RefCounted
## Player settings, kept in user://settings.cfg. Static so anything can read them; the
## settings menu changes them and calls apply(). Window mode, v-sync, volume and render
## scale take effect at once; the graphics quality is read when a map is built, so it
## applies when the next match starts.

const PATH := "user://settings.cfg"

static var quality := -1  ## Graphics.Quality, or -1 for the platform default.
static var fullscreen := false
static var vsync := true
static var render_scale := 1.0  ## 3D resolution as a fraction of the window, 0.5..1.0.
static var show_fps := false
static var mouse_steer := true  ## Moving the mouse yaws and climbs.
static var mouse_sensitivity := 5  ## 1..10
static var invert_mouse := false  ## Mouse forward dives instead of climbing.
static var show_controls := true  ## Key overlay on the HUD (desktop only).
static var volume := 8  ## Master volume, 0..10.

static var _loaded := false


## Reads the file once per run and applies what applies at once.
static func load_once(tree: SceneTree) -> void:
	if _loaded:
		return
	_loaded = true
	read(PATH)
	apply(tree)


## Reads settings from a file (missing file: defaults stay).
static func read(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in keys():
		var value: Variant = file.get_value("settings", key, null)
		if value != null and typeof(value) == typeof(_defaults()[key]):
			_set_key(key, value)


static func save(path := PATH) -> void:
	var file := ConfigFile.new()
	for key in keys():
		file.set_value("settings", key, _get_key(key))
	file.save(path)


## Pushes the settings into the engine. Headless runs (tests) have no window or audio.
static func apply(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if quality >= 0:
		Graphics.quality = quality as Graphics.Quality
	if OS.get_name() != "Android":  # Phones are always full screen.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	tree.root.scaling_3d_scale = render_scale
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, volume <= 0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxi(volume, 1) / 10.0))


## Every saved setting, in menu order.
static func keys() -> PackedStringArray:
	return PackedStringArray(_defaults().keys())


static func _defaults() -> Dictionary:
	return {
		"quality": -1, "fullscreen": false, "vsync": true, "render_scale": 1.0, "show_fps": false,
		"mouse_steer": true, "mouse_sensitivity": 5, "invert_mouse": false, "show_controls": true,
		"volume": 8,
	}


# Static vars can't be reached with get()/set() by name, hence the two switches.
static func _get_key(key: String) -> Variant:
	match key:
		"quality": return quality
		"fullscreen": return fullscreen
		"vsync": return vsync
		"render_scale": return render_scale
		"show_fps": return show_fps
		"mouse_steer": return mouse_steer
		"mouse_sensitivity": return mouse_sensitivity
		"invert_mouse": return invert_mouse
		"show_controls": return show_controls
		"volume": return volume
	return null


static func _set_key(key: String, value: Variant) -> void:
	match key:
		"quality": quality = value
		"fullscreen": fullscreen = value
		"vsync": vsync = value
		"render_scale": render_scale = value
		"show_fps": show_fps = value
		"mouse_steer": mouse_steer = value
		"mouse_sensitivity": mouse_sensitivity = value
		"invert_mouse": invert_mouse = value
		"show_controls": show_controls = value
		"volume": volume = value
