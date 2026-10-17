class_name Settings
extends RefCounted
## Player settings, kept in user://settings.cfg. One dictionary keyed by name; DEFAULTS
## lists every setting with its default. apply() pushes what can change at once into
## the engine (window, viewport, shadows, audio, the live Environment, input deadzones);
## the graphics quality and the grass apply when the next map is built. Cameras and the
## HUD read their settings directly every frame.

const PATH := "user://settings.cfg"
## Where settings are read and saved. The tests point it elsewhere: they change and save
## settings (the radio, the key bindings) and used to wipe the player's own.
static var path := PATH
const AUTO := -1  ## For choices: let the quality preset or the platform decide.

const DEFAULTS := {
	# Video
	"window": 0,  ## 0 windowed, 1 fullscreen (borderless), 2 exclusive fullscreen
	"resolution": "1280x720",  ## Window size when windowed.
	"vsync": 1,  ## 0 off, 1 on, 2 adaptive
	"fps_limit": 0,  ## 0 = unlimited
	"render_scale": 1.0,  ## 3D resolution as a fraction of the window, 0.5..1.0.
	"upscaling": 0,  ## 0 bilinear, 1 FSR 1, 2 FSR 2 (Forward+ only)
	"antialiasing": AUTO,  ## 0 off, 1 FXAA, 2 TAA, 3 MSAA 2x, 4 MSAA 4x, 5 MSAA 8x
	"brightness": 1.0,  ## 0.8..1.2
	"show_fps": false,
	# Graphics
	"quality": AUTO,  ## Graphics.Quality
	"shadows": AUTO,  ## 0 low, 1 medium, 2 high, 3 ultra
	"gi": AUTO,  ## SDFGI. For these five: 0 off, 1 on, AUTO = what the quality preset says.
	"ambient_occlusion": AUTO,
	"reflections": AUTO,
	"volumetric_fog": AUTO,
	"bloom": AUTO,
	"grass": AUTO,  ## 0 off, 1 sparse, 2 dense
	"time_of_day": 0,  ## MapKit.TIMES: 0 afternoon, 1 dusk, 2 night. Applies to the next match.
	# Gameplay
	"airframe": 0,  ## Index into Airframe.ORDER: scout, gunship, heavy. Chosen on the title screen.
	"pilot_name": "",  ## Your name online; empty means "Pilot". Set on the multiplayer screen.
	"server_address": "127.0.0.1",  ## The last server joined (address or address:port).
	"radio_station": 0,  ## Index into Radio.stations(); N switches it in a match.
	"bot_difficulty": 1,  ## 0 easy, 1 normal, 2 hard; chosen on the title screen.
	"fov": 70,  ## Chase camera field of view, degrees.
	"camera_shake": 2,  ## 0 off, 1 half, 2 full
	"cockpit_view": false,  ## Start matches in the cockpit.
	"hud_scale": 1,  ## 0 small, 1 normal, 2 large
	"damage_flash": true,  ## Red screen edges when hit.
	"hud_flight": true,  ## Heading, speed and altitude tapes and the pitch ladder in the chase view.
	"hud_radar": true,  ## The radar bottom left in the chase view.
	"aim_assist": false,
	"flight_model": 1,  ## 0 easy (drone, hovers by itself), 1 realistic (forces). Also on the title screen.
	# Flight assists for the realistic model (the easy one flies itself): Choppa.ASSIST_*.
	# Owner's beginner set: level, landing and start on.
	"assist_level": true,  ## Levels out when you let go of the stick.
	"assist_hover": false,  ## Brakes to a hover when you let go of the stick.
	"assist_altitude": false,  ## Holds the height while the collective is centred.
	"assist_turn": false,  ## The nose follows a bank: coordinated turns.
	"assist_landing": true,  ## Cushions the touchdown.
	"assist_start": true,  ## Asking for power on the ground starts the engine.
	"camera_distance": 1,  ## Chase camera: 0 near, 1 normal, 2 far.
	"show_controls": true,  ## Key overlay on the HUD (desktop only).
	# Controls
	"mouse_steer": true,  ## The mouse flies the choppa.
	"mouse_mode": 0,  ## 0 pitch and roll on the mouse (yaw on A/D), 1 pitch and yaw (roll on A/D).
	"mouse_sensitivity": 5,  ## 1..10
	"invert_mouse": false,  ## Mouse forward pulls the nose up instead of pushing it down.
	"deadzone": 0.2,  ## Gamepad sticks, 0.1..0.4.
	"mouse_vertical": 1.0,  ## Mouse pitch against the horizontal sensitivity, 0.5..1.5.
	# Keys and gamepad: a share of the airframe's full rate (owner: A/D rolled far too fast).
	"roll_rate": 0.6,
	"pitch_rate": 0.8,
	"yaw_rate": 1.0,
	"stick_ramp": 0.15,  ## Seconds a key takes to push the stick all the way, 0..0.6.
	"bindings": {},  ## Action -> keyboard and mouse keys, replacing Controls.DEFAULTS.
	# Audio
	"volume": 8,  ## Master, 0..10.
	"effects_volume": 10,  ## Sound effects, 0..10.
	"music_volume": 6,  ## Music, 0..10.
}

const HUD_SCALES := [0.85, 1.0, 1.2]
const CAMERA_DISTANCES := [0.8, 1.0, 1.3]
const ASSIST_KEYS := {
	"assist_level": Choppa.ASSIST_LEVEL, "assist_hover": Choppa.ASSIST_HOVER,
	"assist_altitude": Choppa.ASSIST_ALTITUDE, "assist_turn": Choppa.ASSIST_TURN,
	"assist_landing": Choppa.ASSIST_LANDING, "assist_start": Choppa.ASSIST_START,
}
const SHAKE_AMOUNTS := [0.0, 0.5, 1.0]

static var _values := {}
## Screenshot runs keep the window the command line asked for, whatever the player saved.
static var keep_window := false
static var _loaded := false
## The project's own anti-aliasing and shadow settings, kept for "Auto".
static var _project := {}


static func value(key: String) -> Variant:
	return _values.get(key, DEFAULTS[key])


static func flag(key: String) -> bool:
	return value(key)


static func number(key: String) -> float:
	return value(key)


static func choice(key: String) -> int:
	return value(key)


static func set_value(key: String, new_value: Variant) -> void:
	assert(DEFAULTS.has(key), "unknown setting " + key)
	_values[key] = new_value


static func reset() -> void:
	_values.clear()


## The flight assists switched on, as Choppa.ASSIST_* bits.
static func assists() -> int:
	var bits := 0
	for key: String in ASSIST_KEYS:
		if flag(key):
			bits |= ASSIST_KEYS[key]
	return bits


## Whether a quality-tier feature is on: the setting, or `by_quality` when it is Auto.
static func feature(key: String, by_quality: bool) -> bool:
	var c := choice(key)
	return by_quality if c == AUTO else c == 1


## Reads the file once per run and applies what applies at once.
static func load_once(tree: SceneTree) -> void:
	if _loaded:
		return
	_loaded = true
	read(path)
	apply(tree)


## Reads settings from a file (missing file or key: defaults stay).
static func read(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in DEFAULTS:
		if not file.has_section_key("settings", key):
			continue
		var stored: Variant = file.get_value("settings", key)
		if typeof(stored) == typeof(DEFAULTS[key]):
			_values[key] = stored


static func save(to := "") -> void:
	var file := ConfigFile.new()
	for key: String in DEFAULTS:
		file.set_value("settings", key, value(key))
	file.save(to if to != "" else path)


## Pushes the settings into the engine. Headless runs (tests) have no window or audio.
static func apply(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _project.is_empty():
		_project = {
			"msaa": tree.root.msaa_3d, "fxaa": tree.root.screen_space_aa, "taa": tree.root.use_taa,
			"shadow_size": int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/size")),
			"shadow_quality": int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")),
			"positional_size": tree.root.positional_shadow_atlas_size,
		}
	if choice("quality") >= 0:
		Graphics.quality = choice("quality") as Graphics.Quality

	if not keep_window:
		_apply_window()
	Engine.max_fps = choice("fps_limit")
	var root := tree.root
	root.scaling_3d_scale = number("render_scale")
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	root.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
		Viewport.SCALING_3D_MODE_FSR2 if forward_plus else Viewport.SCALING_3D_MODE_FSR][choice("upscaling")]
	var aa := choice("antialiasing")
	if aa == AUTO:
		root.msaa_3d = _project.msaa
		root.screen_space_aa = _project.fxaa
		root.use_taa = _project.taa
	else:
		root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED,
			Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][aa]
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		root.use_taa = aa == 2
	_apply_shadows(root)
	root.content_scale_factor = HUD_SCALES[choice("hud_scale")]

	for node in tree.get_nodes_in_group("environment"):
		apply_environment((node as WorldEnvironment).environment)

	for action in InputMap.get_actions():
		if not (action as String).begins_with("ui_"):
			InputMap.action_set_deadzone(action, number("deadzone"))

	_apply_audio()


## Features and brightness on a map's Environment, now and whenever a setting changes.
## "Auto" features follow the quality the map was built with (meta "quality").
static func apply_environment(env: Environment) -> void:
	var quality: int = env.get_meta("quality", Graphics.quality)
	var high := quality >= Graphics.Quality.HIGH
	var medium := quality >= Graphics.Quality.MEDIUM
	env.glow_enabled = feature("bloom", medium)
	env.adjustment_brightness = number("brightness")
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.sdfgi_enabled = feature("gi", high)
		env.ssil_enabled = feature("gi", high)
		env.ssr_enabled = feature("reflections", high)
		env.ssao_enabled = feature("ambient_occlusion", high)
		env.volumetric_fog_enabled = feature("volumetric_fog", high)


## Window sizes that fit the screen, for the resolution setting.
static func resolutions() -> PackedStringArray:
	var screen := DisplayServer.screen_get_size()
	var out := PackedStringArray()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
			Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]:
		if size.x <= screen.x and size.y <= screen.y:
			out.append("%dx%d" % [size.x, size.y])
	var current: String = value("resolution")
	if not out.has(current):
		out.append(current)
	return out


static func _apply_window() -> void:
	match choice("window"):
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var parts: PackedStringArray = (value("resolution") as String).split("x")
			var size := Vector2i(parts[0].to_int(), parts[1].to_int())
			if DisplayServer.window_get_size() != size:
				DisplayServer.window_set_size(size)
				DisplayServer.window_set_position((DisplayServer.screen_get_size() - size) / 2 + DisplayServer.screen_get_position())
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode([DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
		DisplayServer.VSYNC_ADAPTIVE][choice("vsync")])


static func _apply_shadows(root: Viewport) -> void:
	var level := choice("shadows")
	if level == AUTO:
		RenderingServer.directional_shadow_atlas_set_size(_project.shadow_size, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(_project.shadow_quality)
		RenderingServer.positional_soft_shadow_filter_set_quality(_project.shadow_quality)
		root.positional_shadow_atlas_size = _project.positional_size
		return
	var sizes := [2048, 4096, 4096, 8192]
	var filters := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA]
	RenderingServer.directional_shadow_atlas_set_size(sizes[level], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(filters[level])
	RenderingServer.positional_soft_shadow_filter_set_quality(filters[level])
	root.positional_shadow_atlas_size = sizes[level]


static func _apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	_set_bus_volume(master, choice("volume"))
	var effects := AudioServer.get_bus_index(Sounds.BUS)
	if effects < 0:
		effects = AudioServer.bus_count
		AudioServer.add_bus(effects)
		AudioServer.set_bus_name(effects, Sounds.BUS)
		AudioServer.set_bus_send(effects, "Master")
	_set_bus_volume(effects, choice("effects_volume"))
	var music := AudioServer.get_bus_index(Sounds.MUSIC_BUS)
	if music < 0:
		music = AudioServer.bus_count
		AudioServer.add_bus(music)
		AudioServer.set_bus_name(music, Sounds.MUSIC_BUS)
		AudioServer.set_bus_send(music, "Master")
	_set_bus_volume(music, choice("music_volume"))
	# The mix: a limiter keeps a pile of explosions from clipping, and the music ducks
	# under loud effects (keyed from the Effects bus) so fights stay readable.
	if AudioServer.get_bus_effect_count(effects) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(effects, limiter)
	if AudioServer.get_bus_effect_count(music) == 0:
		var duck := AudioEffectCompressor.new()
		duck.sidechain = Sounds.BUS
		duck.threshold = -24.0
		duck.ratio = 4.0
		duck.attack_us = 20000.0
		duck.release_ms = 500.0
		AudioServer.add_bus_effect(music, duck)


static func _set_bus_volume(bus: int, level: int) -> void:
	AudioServer.set_bus_mute(bus, level <= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxi(level, 1) / 10.0))
