extends Node
## Title menu, then a battle, free flight or a race on the chosen map.
##
## Command-line options (after `--`), mostly for automated screenshots:
##   --mode=battle|free|race  skip the menu (default with --shot/--autopilot: free)
##   --map=basin|canyon|range which map (race always uses range)
##   --menu                   show the menu even with --shot
##   --settings=<tab>         open the settings screen on the menu, tab 0-4 (for screenshots)
##   --pause=<tick>           open the pause menu at that tick (the --shot is taken then)
##   --laps=<n>               race laps (default 3)
##   --kills=<n>              battle kill limit (default 8)
##   --autopilot=<plan>       fly a ScriptedPilot plan (hover, forward, weapon:missile...);
##                            "bot" lets the mode's AI fly you
##   --spawn=x,y,z[,yaw]      start position, yaw in degrees (free flight)
##   --cam=fp|showcase        start in first-person view / a fixed front view of the choppa
##   --shot=<file.png>        save a screenshot after --frames physics ticks and quit
##   --frames=<n>             ticks before the screenshot (default 90)
##   --dummies=<n>            training targets in free flight (default 3)
##   --health=<n>             start with this much health (to see damage effects)
##   --wear=tail,rotor,engine start with these parts wrecked (spin, shaking, weak engine)
##   --easy                   fly the easy model whatever the setting says
##   --airframe=scout|gunship|heavy  fly that class whatever the setting says
##   --explode=<tick>         set off an explosion 26 m ahead of you at that tick
##   --timing                 print how long the map build and the first frame took

const RIVALS := [
	["Hawk", Color(0.2, 0.6, 0.95), 1.0],
	["Viper", Color(0.85, 0.25, 0.3), 0.9],
	["Moose", Color(0.3, 0.8, 0.35), 0.8],
	["Ghost", Color(0.7, 0.4, 0.9), 0.85],
	["Wasp", Color(0.95, 0.85, 0.2), 0.95],
]
const RACE_GRID_SLOT := 3  ## Start the race in the second row, like the underdog you are.
## Bot skill multiplier per difficulty (Settings "bot_difficulty"): easy, normal, hard.
const BOT_SKILL := [0.55, 1.0, 1.2]

## Survive reload_current_scene() so "again" skips the menu.
static var next_mode := ""
static var next_map := "basin"
## The command line picks mode and map for the first start only; after that the menus
## decide (otherwise "Main menu" from a `--mode=battle` start lands in another battle).
static var started := false

var mode := ""
var map: GameMap
var choppa: Choppa
var camera: Camera3D
var hud: Hud
var race: Race
var battle: Battle
var pause: PauseMenu
var _over := false  ## The match has ended and the results are up.

var _args := {}
var _ticks := 0
var _menu_orbit := 0.0


func _ready() -> void:
	_parse_args()
	Settings.keep_window = _args.has("shot")
	Settings.load_once(get_tree())
	var first_start := not started
	started = true
	mode = _args.get("mode", next_mode) if first_start else next_mode
	if first_start and mode == "" and not _args.has("menu") and (_args.has("shot") or _args.has("autopilot")):
		mode = "free"
	var map_id: String = _args.get("map", next_map) if first_start else next_map
	if mode != "race":
		next_map = map_id  # So the menu shows the map it opened on (races always use the range).
	if mode == "race":
		map_id = "range"
	next_mode = ""
	GameMap.timing = _args.has("timing")
	var started := Time.get_ticks_msec()
	map = GameMap.create(map_id)
	map.mode = mode
	add_child(map)
	GameMap.report("map", started)
	if mode == "":
		_show_menu()
	else:
		_start()
	if GameMap.timing:
		print("timing: map and players built in %d ms, %d ms after launch" % [Time.get_ticks_msec() - started, started])
		await RenderingServer.frame_post_draw
		print("timing: first frame drawn %d ms after launch" % Time.get_ticks_msec())


func _show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 8000.0
	add_child(camera)
	camera.make_current()
	var menu := Menu.new()
	var ids := GameMap.catalog().map(func(entry: Array) -> String: return entry[1])
	Menu.map_index = maxi(0, ids.find(next_map))
	menu.mode_chosen.connect(_restart_in)
	add_child(menu)
	if _args.has("settings"):
		menu.open_settings(int(_args.settings))


func _start() -> void:
	var slot := RACE_GRID_SLOT if mode == "race" else 0
	var mine: String = _args.get("airframe", Airframe.ORDER[Settings.choice("airframe")])
	choppa = _new_choppa("You", Color(0.95, 0.5, 0.1), map.spawn_points[slot], true, mine)
	choppa.aim_assist = Settings.flag("aim_assist")
	choppa.flight_assist = Settings.flag("flight_assist")
	choppa.easy = Settings.choice("flight_model") == 0 or _args.has("easy")
	if mode == "free" and _args.has("spawn"):
		choppa.respawn(_spawn_arg())
	if _args.has("health"):
		choppa.health = float(_args.health)
	if _args.has("wear"):
		for name in (_args.wear as String).split(","):
			var part: Choppa.Part = {"tail": Choppa.Part.TAIL, "rotor": Choppa.Part.ROTOR, "engine": Choppa.Part.ENGINE}[name]
			choppa.parts[part] = 0.0

	var chase := ChaseCamera.new()
	chase.target = choppa
	chase.first_person = _args.get("cam", "") == "fp" or (not _args.has("cam") and Settings.flag("cockpit_view"))
	chase.showcase = _args.get("cam", "") == "showcase"
	add_child(chase)
	chase.make_current()
	camera = chase

	hud = Hud.new(choppa)
	hud.camera = camera
	add_child(hud)

	match mode:
		"race":
			_start_race()
		"battle":
			_start_battle()
		_:
			for n in mini(int(_args.get("dummies", "3")), map.dummy_posts.size()):
				_spawn_dummy(map.dummy_posts[n], RIVALS[n][1])

	var autopilot: String = _args.get("autopilot", "")
	if autopilot == "bot" and race:
		_add_racer_bot(choppa, 1.0)
	elif autopilot == "bot" and battle:
		_add_fighter_bot(choppa, 1.0)
	elif autopilot != "":
		var bot := ScriptedPilot.new()
		bot.choppa = choppa
		bot.plan = autopilot
		add_child(bot)
	else:
		var pilot := LocalPilot.new()
		pilot.choppa = choppa
		add_child(pilot)
	_update_mouse()


## A choppa in the world. Rivals fly a class picked from their name, so a match mixes them.
func _new_choppa(pilot_name: String, color: Color, at: Transform3D, local := false, airframe := "") -> Choppa:
	var c := Choppa.new()
	c.local_player = local  # Must be set before _ready: it decides the cockpit and layers.
	c.airframe = airframe if airframe != "" else Airframe.ORDER[hash(pilot_name) % Airframe.ORDER.size()]
	c.pilot_name = pilot_name
	c.team_color = color
	c.max_altitude = map.ceiling
	add_child(c)
	c.respawn(at)
	return c


## The three rivals, on the spawn points the player isn't using.
func _rivals(player_slot: int) -> Array[Choppa]:
	var field: Array[Choppa] = []
	var slot := 0
	for rival in RIVALS.slice(0, 3):
		if slot == player_slot:
			slot += 1
		field.append(_new_choppa(rival[0], rival[1], map.spawn_points[slot]))
		slot += 1
	return field


func _start_race() -> void:
	var field: Array[Choppa] = [choppa]
	field.append_array(_rivals(RACE_GRID_SLOT))
	race = Race.new()
	add_child(race)
	race.setup(map.gates, field, int(_args.get("laps", "3")))
	for n in range(1, field.size()):
		_add_racer_bot(field[n], RIVALS[n - 1][2] * BOT_SKILL[Settings.choice("bot_difficulty")])

	var race_hud := RaceHud.new()
	race_hud.race = race
	race_hud.choppa = choppa
	race_hud.camera = camera
	race_hud.restart_requested.connect(_restart_in.bind("race", "range"))
	race_hud.menu_requested.connect(_restart_in.bind("", next_map))
	add_child(race_hud)
	race.race_over.connect(_on_match_over)


func _start_battle() -> void:
	var field: Array[Choppa] = [choppa]
	# Spread out: rivals take every other spawn point around the arena.
	var spawns := map.spawn_points
	var step := maxi(1, spawns.size() / 4)
	for n in 3:
		var rival: Array = RIVALS[n]
		field.append(_new_choppa(rival[0], rival[1], spawns[((n + 1) * step) % spawns.size()]))
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, map.spawn_points, int(_args.get("kills", "8")))
	if choppa.model.cockpit_view:
		choppa.model.cockpit_view.kills_source = func() -> int: return battle.kills_of(choppa)
	for n in range(1, field.size()):
		_add_fighter_bot(field[n], RIVALS[n - 1][2] * BOT_SKILL[Settings.choice("bot_difficulty")])

	var battle_hud := BattleHud.new()
	battle_hud.battle = battle
	battle_hud.choppa = choppa
	battle_hud.restart_requested.connect(_restart_in.bind("battle", next_map))
	battle_hud.menu_requested.connect(_restart_in.bind("", next_map))
	add_child(battle_hud)
	battle.match_over.connect(_on_match_over)


func _add_racer_bot(target: Choppa, skill: float) -> void:
	var bot := RacerBot.new()
	bot.choppa = target
	bot.race = race
	bot.skill = skill
	add_child(bot)


func _add_fighter_bot(target: Choppa, skill: float) -> void:
	var bot := FighterBot.new()
	bot.choppa = target
	bot.skill = skill
	bot.ceiling = map.ceiling
	bot.rng.seed = hash(target.pilot_name)
	add_child(bot)


func _spawn_dummy(post: Vector3, color: Color) -> void:
	# Face the player's spawn so they show their good side.
	var toward := map.spawn_points[0].origin - post
	var home := Transform3D(Basis(Vector3.UP, atan2(-toward.x, -toward.z)), post)
	var dummy := _new_choppa("Dummy", color, home)
	dummy.died.connect(func(_killer: Choppa) -> void:
		get_tree().create_timer(Battle.RESPAWN_DELAY).timeout.connect(dummy.respawn.bind(home)))
	var pilot := DummyPilot.new()
	pilot.choppa = dummy
	pilot.home = post
	add_child(pilot)


func _restart_in(new_mode: String, map_id: String) -> void:
	get_tree().paused = false
	next_mode = new_mode
	if new_mode != "race":  # Races always use the test range; keep the chosen map.
		next_map = map_id
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if mode != "":
		return
	# Slow orbit over the map behind the title menu.
	_menu_orbit += delta * 0.06
	camera.global_position = map.menu_center + Vector3(sin(_menu_orbit) * map.menu_orbit.x, map.menu_orbit.y, cos(_menu_orbit) * map.menu_orbit.x)
	camera.look_at(map.menu_center)


func _unhandled_input(event: InputEvent) -> void:
	if mode == "":
		return
	if event.is_action_pressed("toggle_camera"):
		(camera as ChaseCamera).toggle_mode()
	elif event.is_action_pressed("respawn") and not battle:
		choppa.respawn(race.respawn_point(choppa) if race else map.spawn_points[0])
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("pause"):
		_toggle_pause()


func _notification(what: int) -> void:
	# The window's back request (e.g. a gamepad's back button mapped by the OS).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "":
			get_tree().quit()
		else:
			_toggle_pause()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _args.has("explode") and _ticks == int(_args.explode) and choppa:
		var boom := Effects.Explosion.new()
		add_child(boom)
		boom.global_position = choppa.global_position + choppa.facing() * Vector3(0.0, 9.0, -26.0)
	if _args.has("pause") and _ticks == int(_args.pause):
		_toggle_pause()
		if _args.has("shot"):  # Physics stops with the pause, so the shot is taken now.
			_save_screenshot.call_deferred(_args.shot)
	elif _args.has("shot") and not _args.has("pause") and _ticks == int(_args.get("frames", "90")):
		_save_screenshot.call_deferred(_args.shot)


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw  # Controls added this frame are laid out and drawn in the next.
	path = path.replace("\\", "/")  # Godot reads a backslash path as relative to the project.
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _spawn_arg() -> Transform3D:
	var parts: PackedFloat64Array = (_args.spawn as String).split_floats(",")
	var yaw := deg_to_rad(parts[3]) if parts.size() > 3 else 0.0
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(parts[0], parts[1], parts[2]))


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		_args[pair[0]] = pair[1] if pair.size() > 1 else ""


## Esc or Start: the pause menu stops the whole match; closing it resumes.
func _toggle_pause() -> void:
	if pause:
		pause.queue_free()
		pause = null
		get_tree().paused = false
	else:
		pause = PauseMenu.new()
		pause.resumed.connect(_toggle_pause)
		pause.restart_requested.connect(_restart_in.bind(mode, next_map))
		pause.menu_requested.connect(_restart_in.bind("", next_map))
		pause.settings_changed.connect(_on_settings_changed)
		add_child(pause)
		get_tree().paused = true
	_update_mouse()


func _on_settings_changed() -> void:
	hud.refresh_settings()
	choppa.aim_assist = Settings.flag("aim_assist")
	choppa.flight_assist = Settings.flag("flight_assist")
	choppa.easy = Settings.choice("flight_model") == 0 or _args.has("easy")
	_update_mouse()


func _on_match_over() -> void:
	_over = true
	_update_mouse()


## The mouse is captured while you steer with it, and free whenever there is something
## to click: menus, the results, the pause screen.
func _update_mouse() -> void:
	var flying := mode != "" and Settings.flag("mouse_steer") and pause == null and not _over
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if flying else Input.MOUSE_MODE_VISIBLE
