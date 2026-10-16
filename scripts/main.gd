extends Node
## Title menu, then either free flight on the test range or a race against bots.
##
## Command-line options (after `--`), mostly for automated screenshots:
##   --mode=free|race        skip the menu (default with --shot/--autopilot: free)
##   --menu                  show the menu even with --shot
##   --laps=<n>              race laps (default 3)
##   --autopilot=<plan>      fly a ScriptedPilot plan instead of reading controls;
##                           "race" lets a RacerBot fly you around the course
##   --spawn=x,y,z[,yaw]     start position, yaw in degrees (free flight)
##   --cam=fp                start in first-person view
##   --touch                 show touch controls even without a touchscreen
##   --shot=<file.png>       save a screenshot after --frames physics ticks and quit
##   --frames=<n>            ticks before the screenshot (default 90)
##   --dummies=<n>           training targets in free flight (default 3)

const DUMMY_POSTS: Array[Vector3] = [
	Vector3(-25.0, 10.0, 50.0), Vector3(25.0, 13.0, 45.0), Vector3(0.0, 17.0, 15.0),
	Vector3(-40.0, 20.0, 0.0), Vector3(40.0, 8.0, 0.0),
]
const RIVALS := [
	["Hawk", Color(0.2, 0.6, 0.95), 1.0],
	["Viper", Color(0.85, 0.25, 0.3), 0.9],
	["Moose", Color(0.3, 0.8, 0.35), 0.8],
	["Ghost", Color(0.7, 0.4, 0.9), 0.85],
	["Wasp", Color(0.95, 0.85, 0.2), 0.95],
]
const PLAYER_GRID_SLOT := 3  ## Start in the second row, like the underdog you are.

## Survives reload_current_scene() so "race again" skips the menu.
static var next_mode := ""

var mode := ""
var map: TestRange
var choppa: Choppa
var camera: Camera3D
var hud: Hud
var race: Race

var _args := {}
var _ticks := 0
var _menu_orbit := 0.0


func _ready() -> void:
	_parse_args()
	mode = _args.get("mode", next_mode)
	if mode == "" and not _args.has("menu") and (_args.has("shot") or _args.has("autopilot")):
		mode = "free"
	next_mode = ""
	if mode == "":
		_show_menu()
	else:
		_start()


func _show_menu() -> void:
	map = TestRange.new()
	add_child(map)
	camera = Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	var menu := Menu.new()
	menu.mode_chosen.connect(_restart_in)
	add_child(menu)


func _start() -> void:
	map = TestRange.new()
	map.mode = mode
	add_child(map)

	choppa = Choppa.new()
	choppa.local_player = true
	choppa.pilot_name = "You"
	add_child(choppa)
	choppa.respawn(map.spawn_points[PLAYER_GRID_SLOT] if mode == "race" else _spawn_point())

	var chase := ChaseCamera.new()
	chase.target = choppa
	chase.first_person = _args.get("cam", "") == "fp"
	add_child(chase)
	chase.make_current()
	camera = chase

	hud = Hud.new(choppa)
	hud.camera = camera
	add_child(hud)
	if _args.has("touch"):
		hud.touch.visible = true
		hud.toggle_help()
	hud.touch.camera_pressed.connect(chase.toggle_mode)

	if mode == "race":
		_start_race()
	else:
		for n in mini(int(_args.get("dummies", "3")), DUMMY_POSTS.size()):
			_spawn_dummy(DUMMY_POSTS[n], RIVALS[n][1])

	var autopilot: String = _args.get("autopilot", "")
	if autopilot == "race" and race:
		_add_bot(choppa, 1.0)
	elif autopilot != "":
		var bot := ScriptedPilot.new()
		bot.choppa = choppa
		bot.plan = autopilot
		add_child(bot)
	else:
		var pilot := LocalPilot.new()
		pilot.choppa = choppa
		pilot.touch = hud.touch
		add_child(pilot)


func _start_race() -> void:
	var field: Array[Choppa] = [choppa]
	var slot := 0
	for rival in RIVALS.slice(0, 3):
		if slot == PLAYER_GRID_SLOT:
			slot += 1
		var bot_choppa := Choppa.new()
		bot_choppa.pilot_name = rival[0]
		bot_choppa.team_color = rival[1]
		add_child(bot_choppa)
		bot_choppa.respawn(map.spawn_points[slot])
		field.append(bot_choppa)
		slot += 1

	race = Race.new()
	add_child(race)
	race.setup(map.gates, field, int(_args.get("laps", "3")))
	for n in range(1, field.size()):
		_add_bot(field[n], RIVALS[n - 1][2])

	var race_hud := RaceHud.new()
	race_hud.race = race
	race_hud.choppa = choppa
	race_hud.camera = camera
	race_hud.restart_requested.connect(_restart_in.bind("race"))
	race_hud.menu_requested.connect(_restart_in.bind(""))
	add_child(race_hud)


func _add_bot(target: Choppa, skill: float) -> void:
	var bot := RacerBot.new()
	bot.choppa = target
	bot.race = race
	bot.skill = skill
	add_child(bot)


func _spawn_dummy(post: Vector3, color: Color) -> void:
	var dummy := Choppa.new()
	dummy.team_color = color
	dummy.pilot_name = "Dummy"
	add_child(dummy)
	# Face the player's spawn so they show their good side.
	dummy.respawn(Transform3D(Basis(Vector3.UP, PI), post))
	var pilot := DummyPilot.new()
	pilot.choppa = dummy
	pilot.home = post
	add_child(pilot)


func _restart_in(new_mode: String) -> void:
	next_mode = new_mode
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if mode != "":
		return
	# Slow orbit over the map behind the title menu.
	_menu_orbit += delta * 0.08
	camera.global_position = Vector3(sin(_menu_orbit) * 160.0, 70.0, cos(_menu_orbit) * 160.0 - 60.0)
	camera.look_at(Vector3(0.0, 10.0, -80.0))


func _unhandled_input(event: InputEvent) -> void:
	if mode == "":
		return
	if event.is_action_pressed("toggle_camera"):
		(camera as ChaseCamera).toggle_mode()
	elif event.is_action_pressed("respawn"):
		choppa.respawn(race.respawn_point(choppa) if race else _spawn_point())
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_restart_in("")


func _notification(what: int) -> void:
	# Android back button: leave to the menu, or quit from the menu.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "":
			get_tree().quit()
		else:
			_restart_in("")


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _args.has("shot") and _ticks == int(_args.get("frames", "90")):
		_save_screenshot.call_deferred(_args.shot)


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _spawn_point() -> Transform3D:
	if not _args.has("spawn"):
		return map.spawn_points[0]
	var parts: PackedFloat64Array = (_args.spawn as String).split_floats(",")
	var yaw := deg_to_rad(parts[3]) if parts.size() > 3 else 0.0
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(parts[0], parts[1], parts[2]))


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		_args[pair[0]] = pair[1] if pair.size() > 1 else ""
