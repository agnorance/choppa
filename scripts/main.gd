extends Node
## Boots the test range with one local choppa.
##
## Command-line options (after `--`), mostly for automated screenshots:
##   --autopilot=<plan>      fly a ScriptedPilot plan instead of reading controls
##   --spawn=x,y,z[,yaw]     start position, yaw in degrees
##   --cam=fp                start in first-person view
##   --touch                 show touch controls even without a touchscreen
##   --shot=<file.png>       save a screenshot after --frames physics ticks and quit
##   --frames=<n>            ticks before the screenshot (default 90)
##   --dummies=<n>           training targets to spawn (default 3)

const DUMMY_POSTS: Array[Vector3] = [
	Vector3(-25.0, 10.0, 50.0), Vector3(25.0, 13.0, 45.0), Vector3(0.0, 17.0, 15.0),
	Vector3(-40.0, 20.0, 0.0), Vector3(40.0, 8.0, 0.0),
]
const DUMMY_COLORS: Array[Color] = [
	Color(0.2, 0.6, 0.95), Color(0.85, 0.25, 0.3), Color(0.3, 0.8, 0.35),
	Color(0.7, 0.4, 0.9), Color(0.95, 0.85, 0.2),
]

var map: TestRange
var choppa: Choppa
var camera: ChaseCamera
var hud: Hud

var _args := {}
var _ticks := 0


func _ready() -> void:
	_parse_args()

	map = TestRange.new()
	add_child(map)

	choppa = Choppa.new()
	choppa.local_player = true
	add_child(choppa)
	choppa.respawn(_spawn_point())

	camera = ChaseCamera.new()
	camera.target = choppa
	camera.first_person = _args.get("cam", "") == "fp"
	add_child(camera)
	camera.make_current()

	for n in mini(int(_args.get("dummies", "3")), DUMMY_POSTS.size()):
		_spawn_dummy(DUMMY_POSTS[n], DUMMY_COLORS[n])

	hud = Hud.new(choppa)
	hud.camera = camera
	add_child(hud)
	if _args.has("touch"):
		hud.touch.visible = true
		hud.toggle_help()
	hud.touch.camera_pressed.connect(camera.toggle_mode)

	if _args.has("autopilot"):
		var bot := ScriptedPilot.new()
		bot.choppa = choppa
		bot.plan = _args.autopilot
		add_child(bot)
	else:
		var pilot := LocalPilot.new()
		pilot.choppa = choppa
		pilot.touch = hud.touch
		add_child(pilot)


func _spawn_dummy(post: Vector3, color: Color) -> void:
	var dummy := Choppa.new()
	dummy.team_color = color
	add_child(dummy)
	# Face the player's spawn so they show their good side.
	dummy.respawn(Transform3D(Basis(Vector3.UP, PI), post))
	var pilot := DummyPilot.new()
	pilot.choppa = dummy
	pilot.home = post
	add_child(pilot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		camera.toggle_mode()
	elif event.is_action_pressed("respawn"):
		choppa.respawn(_spawn_point())
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


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
