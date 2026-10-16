extends Node
## Title menu, then a battle, free flight or a race on the chosen map; or a battle over
## the internet (hosted here, on a dedicated server, or joined).
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
##   --camo=<id>              wear that camo (Progression.CAMOS)
##   --level=<n>              play as a pilot of that level (not saved)
##   --entitle=hangar,collector,apex  own those packs for this run (not saved)
##   --hangar                 open the hangar on the title screen
##   --leave=<tick>           go back to the main menu at that tick (checks the way out)
##   --explode=<tick>         set off an explosion 26 m ahead of you at that tick
##   --timing                 print how long the map build and the first frame took
## Multiplayer (NetGame):
##   --host[=port]            play a battle others can join (default port 7777)
##   --server[=port]          dedicated server: six bot seats, players take them over
##   --connect=addr[:port]    join a server
##   --name=<pilot>           your name online (else the setting, else "Pilot")
##   --lag=<ms>               simulate a slow line on this side (round trip, ms)
##   --loss=<percent>         and drop this share of unreliable packets

const RIVALS := [
	["Hawk", Color(0.2, 0.6, 0.95), 1.0],
	["Viper", Color(0.85, 0.25, 0.3), 0.9],
	["Moose", Color(0.3, 0.8, 0.35), 0.8],
	["Ghost", Color(0.7, 0.4, 0.9), 0.85],
	["Wasp", Color(0.95, 0.85, 0.2), 0.95],
	["Falcon", Color(0.4, 0.85, 0.85), 0.9],
]
const RACE_GRID_SLOT := 3  ## Start the race in the second row, like the underdog you are.
## Bot skill multiplier per difficulty (Settings "bot_difficulty"): easy, normal, hard.
const BOT_SKILL := [0.55, 1.0, 1.2]
const BOT_CAMOS := ["factory", "desert", "woodland", "tiger", "splinter", "digital", "arctic", "night"]
const ONLINE_SEATS := 6  ## Pilots in an online battle; bots fly the seats nobody took.
const JOIN_TIMEOUT := 8.0

## Survive reload_current_scene() so "again" skips the menu.
static var next_mode := ""
static var next_map := "basin"
## The command line picks mode and map for the first start only; after that the menus
## decide (otherwise "Main menu" from a `--mode=battle` start lands in another battle).
static var started := false
static var net_port := NetGame.PORT

var mode := ""
## "" offline, or "host", "server" (dedicated, nobody plays here) or "join". Online
## matches are always battles.
var net_role := ""
var map: GameMap
var choppa: Choppa
var camera: Camera3D
var hud: Hud
var race: Race
var battle: Battle
var pause: PauseMenu
var net: NetGame
var _battle_hud: BattleHud
var _pilot: LocalPilot
var _over := false  ## The match has ended and the results are up.
var _xp_stats := {}  ## Client: our stats for the round, sent by the server.

var _args := {}
var _ticks := 0
var _menu_orbit := 0.0


func _ready() -> void:
	_parse_args()
	Settings.keep_window = _args.has("shot")
	Settings.load_once(get_tree())
	_profile_args()
	var first_start := not started
	started = true
	mode = _args.get("mode", next_mode) if first_start else next_mode
	if first_start and mode == "" and not _args.has("menu") and (_args.has("shot") or _args.has("autopilot")):
		mode = "free"
	if first_start:
		mode = _net_args(mode)
	if mode in ["host", "server", "join"]:
		net_role = mode
		mode = "battle"
	var map_id: String = _args.get("map", next_map) if first_start else next_map
	if mode != "race":
		next_map = map_id  # So the menu shows the map it opened on (races always use the range).
	if mode == "race":
		map_id = "range"
	next_mode = ""
	if net_role == "join":
		_start_client()  # The server says which map.
		return
	GameMap.timing = _args.has("timing")
	# Not called `started`: a local of that name shadowed the static flag in the whole
	# function, so "Main menu" after a `--mode=battle` start began another battle.
	var build_start := Time.get_ticks_msec()
	map = GameMap.create(map_id)
	map.mode = mode
	add_child(map)
	GameMap.report("map", build_start)
	if mode == "":
		_show_menu()
	elif net_role == "server":
		_start_server()
	else:
		_start()
	if GameMap.timing:
		print("timing: map and players built in %d ms, %d ms after launch" % [Time.get_ticks_msec() - build_start, build_start])
		await RenderingServer.frame_post_draw
		print("timing: first frame drawn %d ms after launch" % Time.get_ticks_msec())


func _show_menu() -> void:
	Sounds.music(get_tree(), "menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_orbit_camera()
	var menu := Menu.new()
	var ids := GameMap.catalog().map(func(entry: Array) -> String: return entry[1])
	Menu.map_index = maxi(0, ids.find(next_map))
	menu.mode_chosen.connect(_restart_in)
	add_child(menu)
	if _args.has("settings"):
		menu.open_settings(int(_args.settings))
	elif _args.has("hangar"):
		menu.open_hangar()
	elif _args.has("online"):
		menu.open_online()


## The camera that slowly orbits the map behind the title menu (and on a dedicated server).
func _orbit_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 8000.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # Moved in _process.
	add_child(camera)
	camera.make_current()


func _start() -> void:
	if mode == "free":
		Sounds.music(get_tree(), "")  # Free flight: just the helicopter.
	var slot := RACE_GRID_SLOT if mode == "race" else 0
	var mine := _my_airframe()
	choppa = _new_choppa(_pilot_name() if net_role != "" else "You", Color(0.95, 0.5, 0.1),
		map.spawn_points[slot], true, mine, _args.get("camo", Progression.profile().camo_for(mine)))
	if mode == "free" and _args.has("spawn"):
		choppa.respawn(_spawn_arg())
	if _args.has("health"):
		choppa.health = float(_args.health)
	if _args.has("wear"):
		for name in (_args.wear as String).split(","):
			var part: Choppa.Part = {"tail": Choppa.Part.TAIL, "rotor": Choppa.Part.ROTOR, "engine": Choppa.Part.ENGINE}[name]
			choppa.parts[part] = 0.0
	_player_view()

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
		_add_local_pilot()
	_update_mouse()


## Chase camera and HUD for our choppa, with the player's settings applied.
func _player_view() -> void:
	_apply_flight_settings()
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


func _apply_flight_settings() -> void:
	choppa.aim_assist = Settings.flag("aim_assist")
	choppa.flight_assist = Settings.flag("flight_assist")
	choppa.easy = Settings.choice("flight_model") == 0 or _args.has("easy")


func _add_local_pilot() -> void:
	_pilot = LocalPilot.new()
	_pilot.choppa = choppa
	add_child(_pilot)


func _my_airframe() -> String:
	return _args.get("airframe", Airframe.ORDER[Settings.choice("airframe")])


func _pilot_name() -> String:
	var name: String = _args.get("name", Settings.value("pilot_name"))
	name = name.strip_edges().substr(0, 16)
	return name if name != "" else "Pilot"


## A choppa in the world. Rivals fly a class picked from their name, so a match mixes them.
func _new_choppa(pilot_name: String, color: Color, at: Transform3D, local := false, airframe := "",
		camo := "") -> Choppa:
	var c := Choppa.new()
	c.local_player = local  # Must be set before _ready: it decides the cockpit and layers.
	# Rivals wear an earned camo picked from their name.
	c.camo = camo if camo != "" else BOT_CAMOS[hash(pilot_name + "camo") % BOT_CAMOS.size()]
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
	Sounds.music(get_tree(), "battle")
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
	Sounds.music(get_tree(), "battle")
	var field: Array[Choppa] = [choppa]
	# Spread out: rivals take evenly spaced spawn points around the arena.
	var rivals := ONLINE_SEATS - 1 if net_role == "host" else 3
	var spawns := map.spawn_points
	var step := maxi(1, spawns.size() / (rivals + 1))
	for n in rivals:
		var rival: Array = RIVALS[n]
		field.append(_new_choppa(rival[0], rival[1], spawns[((n + 1) * step) % spawns.size()]))
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, map.spawn_points, int(_args.get("kills", "8")))
	if choppa.model.cockpit_view:
		choppa.model.cockpit_view.kills_source = func() -> int: return battle.kills_of(choppa)
	var bots := {}
	for n in range(1, field.size()):
		bots[field[n]] = _add_fighter_bot(field[n], RIVALS[n - 1][2] * BOT_SKILL[Settings.choice("bot_difficulty")])

	var stats := MatchStats.new()
	stats.pilot = choppa
	stats.battle = battle
	add_child(stats)
	_add_battle_hud(func() -> Dictionary:
		var result := Progression.profile().add_battle(stats.result())
		Progression.profile().save()
		return result)
	if net_role == "host":
		_open_server(field, bots, [choppa] as Array[Choppa])


func _add_battle_hud(xp_provider: Callable) -> void:
	_battle_hud = BattleHud.new()
	_battle_hud.battle = battle
	_battle_hud.choppa = choppa
	_battle_hud.online = net_role != ""
	_battle_hud.restart_requested.connect(_restart_in.bind("battle", next_map))
	_battle_hud.menu_requested.connect(_restart_in.bind("", next_map))
	_battle_hud.xp_provider = xp_provider
	add_child(_battle_hud)
	battle.match_over.connect(_on_match_over)
	battle.restarted.connect(func() -> void:
		_over = false
		_update_mouse())


func _add_racer_bot(target: Choppa, skill: float) -> void:
	var bot := RacerBot.new()
	bot.choppa = target
	bot.race = race
	bot.skill = skill
	add_child(bot)


func _add_fighter_bot(target: Choppa, skill: float) -> FighterBot:
	var bot := FighterBot.new()
	bot.choppa = target
	bot.skill = skill
	bot.ceiling = map.ceiling
	bot.rng.seed = hash(target.pilot_name)
	add_child(bot)
	return bot


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


# --- online -------------------------------------------------------------------------

func _new_net() -> void:
	net = NetGame.new()
	net.name = "Net"  # The same path on every machine: RPCs are matched by it.
	net.lag_ms = float(_args.get("lag", "0"))
	net.loss = float(_args.get("loss", "0")) / 100.0
	add_child(net)


## Opens this battle to the internet: players take over bot seats, never `reserved` ones.
func _open_server(field: Array[Choppa], bots: Dictionary, reserved: Array[Choppa]) -> void:
	_new_net()
	net.battle = battle
	net.pilots = field
	net.bots = bots
	net.reserved = reserved
	for node in get_tree().get_nodes_in_group("stations"):
		net.stations.append(node as ServiceStation)
	net.welcome_info = {"map": next_map, "mode": "battle", "kills": battle.kill_limit}
	net.bot_factory = func(c: Choppa) -> Node:
		return _add_fighter_bot(c, BOT_SKILL[Settings.choice("bot_difficulty")])
	var err := net.host(net_port)
	if err != OK:
		push_error("Could not open port %d (error %d)." % [net_port, err])
		_note("Could not open port %d. Is another server running?" % net_port)
		if _battle_hud:
			_battle_hud.online = false  # Nobody will start the next round for us.
		return
	print("net: hosting %s on port %d" % [next_map, net_port])
	net.peer_joined.connect(func(who: String) -> void: _note("%s joined" % who))
	net.peer_left.connect(func(who: String) -> void: _note("%s left" % who))
	_note("Hosting on port %d" % net_port)


func _note(text: String) -> void:
	print("net: ", text)
	if _battle_hud:
		_battle_hud.note(text)


## Dedicated server: a battle of bots that players take over as they join.
func _start_server() -> void:
	_orbit_camera()
	var field: Array[Choppa] = []
	var spawns := map.spawn_points
	var step := maxi(1, spawns.size() / ONLINE_SEATS)
	for n in ONLINE_SEATS:
		var rival: Array = RIVALS[n]
		field.append(_new_choppa(rival[0], rival[1], spawns[(n * step) % spawns.size()]))
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, spawns, int(_args.get("kills", "8")))
	var bots := {}
	for n in field.size():
		bots[field[n]] = _add_fighter_bot(field[n], RIVALS[n][2] * BOT_SKILL[Settings.choice("bot_difficulty")])
	_open_server(field, bots, [] as Array[Choppa])


## Joins a server; the world is built when it answers (_on_welcomed).
func _start_client() -> void:
	Sounds.music(get_tree(), "")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.anchor_right = 1.0
	back.anchor_bottom = 1.0
	layer.add_child(back)
	var status := UiKit.display("CONNECTING TO %s" % Menu.join_address.to_upper(), 40, UiKit.TEXT)
	status.anchor_left = 0.5
	status.anchor_right = 0.5
	status.anchor_top = 0.5
	status.anchor_bottom = 0.5
	status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(status)
	_new_net()
	net.welcomed.connect(_on_welcomed.bind(layer))
	net.disconnected.connect(_on_net_lost)
	net.xp_received.connect(func(stats: Dictionary) -> void: _xp_stats = stats)
	var address := Menu.join_address.strip_edges()
	var port := NetGame.PORT
	if address.contains(":"):
		port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	var mine := _my_airframe()
	var hello := {"name": _pilot_name(), "airframe": mine, "camo": Progression.profile().camo_for(mine)}
	if net.join(address, port, hello) != OK:
		_on_net_lost("Could not start a connection to %s." % Menu.join_address)
		return
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(func() -> void:
		if net and net.own == null:
			_on_net_lost("No answer from %s." % Menu.join_address))


func _on_welcomed(info: Dictionary, connecting: CanvasLayer) -> void:
	connecting.queue_free()
	next_map = info.map
	map = GameMap.create(info.map)
	map.mode = "battle"
	add_child(map)
	var field: Array[Choppa] = []
	var spawns := map.spawn_points
	for k in (info.roster as Array).size():
		var r: Dictionary = info.roster[k]
		field.append(_new_choppa(r.name, r.color, spawns[k % spawns.size()], k == info.seat, r.airframe, r.camo))
	choppa = field[info.seat]
	_player_view()
	Sounds.music(get_tree(), "battle")
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, spawns, int(info.kills))
	var stations: Array[ServiceStation] = []
	for node in get_tree().get_nodes_in_group("stations"):
		stations.append(node as ServiceStation)
	net.attach(field, info.seat, battle, stations)
	_add_battle_hud(func() -> Dictionary:
		if _xp_stats.is_empty():
			return {}
		var result := Progression.profile().add_battle(_xp_stats)
		Progression.profile().save()
		_xp_stats = {}
		return result)
	if info.get("over", false):
		battle.net_end()  # Joined during the break between rounds.
	_add_local_pilot()
	_update_mouse()


func _on_net_lost(reason: String) -> void:
	if net == null or net.role == NetGame.Role.NONE:
		return
	print("net: ", reason)
	Menu.notice = reason
	net.stop()
	_restart_in("", next_map)


## --host, --server, --connect on the command line: returns the mode they ask for.
func _net_args(requested: String) -> String:
	for role: String in ["host", "server"]:
		if _args.has(role):
			if _args[role] != "":
				net_port = int(_args[role])
			return role
	if _args.has("connect"):
		Menu.join_address = _args.connect
		return "join"
	return requested


func _restart_in(new_mode: String, map_id: String) -> void:
	get_tree().paused = false
	next_mode = new_mode
	if new_mode != "race":  # Races always use the test range; keep the chosen map.
		next_map = map_id
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if mode != "" and net_role != "server":
		return
	# Slow orbit over the map behind the title menu.
	_menu_orbit += delta * 0.06
	camera.global_position = map.menu_center + Vector3(sin(_menu_orbit) * map.menu_orbit.x, map.menu_orbit.y, cos(_menu_orbit) * map.menu_orbit.x)
	camera.look_at(map.menu_center)


func _unhandled_input(event: InputEvent) -> void:
	if mode == "" or choppa == null:
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
		if mode == "" or choppa == null:
			get_tree().quit()
		else:
			_toggle_pause()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _args.has("explode") and _ticks == int(_args.explode) and choppa:
		var boom := Effects.Explosion.new()
		add_child(boom)
		boom.global_position = choppa.global_position + choppa.facing() * Vector3(0.0, 9.0, -26.0)
	if _args.has("leave") and _ticks == int(_args.leave) and mode != "":
		print("leaving for the menu")
		_restart_in("", next_map)
		return
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


## Esc or Start: the pause menu stops the whole match; closing it resumes. Online the
## match goes on without us: our choppa just gets no input meanwhile.
func _toggle_pause() -> void:
	if pause:
		pause.queue_free()
		pause = null
		get_tree().paused = false
	else:
		pause = PauseMenu.new()
		pause.online = net_role != ""
		pause.resumed.connect(_toggle_pause)
		pause.restart_requested.connect(_restart_in.bind(mode, next_map))
		pause.menu_requested.connect(_restart_in.bind("", next_map))
		pause.settings_changed.connect(_on_settings_changed)
		add_child(pause)
		get_tree().paused = net_role == ""
	if _pilot and net_role != "":
		_pilot.set_physics_process(pause == null)
		choppa.input.clear()
	_update_mouse()


func _on_settings_changed() -> void:
	hud.refresh_settings()
	_apply_flight_settings()
	_update_mouse()


func _on_match_over() -> void:
	_over = true
	_update_mouse()


## The mouse is captured while you steer with it, and free whenever there is something
## to click: menus, the results, the pause screen.
func _update_mouse() -> void:
	var flying := mode != "" and choppa != null and Settings.flag("mouse_steer") and pause == null and not _over
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if flying else Input.MOUSE_MODE_VISIBLE


## Testing aids: --level=N plays as a pilot of that level, --entitle=hangar,collector,apex
## grants packs. Neither is saved; the real profile stays as it was.
func _profile_args() -> void:
	var profile := Progression.profile()
	profile.testing = _args.has("level") or _args.has("entitle") or _args.has("camo")
	if _args.has("level"):
		profile.xp = Progression.total_xp_for(int(_args.level))
	if _args.has("entitle"):
		profile.entitlements = PackedStringArray((_args.entitle as String).split(","))
	if _args.has("camo"):  # Shown in the hangar too (for screenshots).
		for id: String in Airframe.ORDER:
			profile.camos[id] = _args.camo
