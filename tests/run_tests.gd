extends SceneTree
## Headless test runner:
##   godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd
## --fixed-fps lets physics run as fast as the CPU allows instead of in real time.
## Each test builds a tiny world, flies a choppa with scripted input and checks the result.

const TICK := 1.0 / 60.0

var _failures := 0
var _world: Node3D


func _initialize() -> void:
	Settings.path = "user://test_settings.cfg"  # Never touch the player's settings.
	_run.call_deferred()


func _run() -> void:
	for test in [
		"test_neutral_input_hovers",
		"test_nose_down_accelerates_forward",
		"test_yaw_right_turns_right",
		"test_cannot_dive_through_ground",
		"test_boost_is_faster_and_drains_meter",
		"test_wall_hit_bounces_and_stuns",
		"test_gun_fires_and_overheats",
		"test_gun_runs_dry_and_a_restock_fills_it",
		"test_gun_cools_down_after_overheat",
		"test_bullets_knock_target_back",
		"test_aim_assist_hits_target_above",
		"test_rolling_hard_dodges_bullets",
		"test_bullets_stop_at_walls",
		"test_race_counts_gates_in_order_and_laps",
		"test_race_standings_and_results",
		"test_bot_flies_the_course",
		"test_four_bots_all_finish",
		"test_bullets_damage_and_kill",
		"test_spawn_shield_blocks_damage",
		"test_crash_after_hit_credits_attacker",
		"test_battle_kills_respawn_and_limit",
		"test_battle_time_limit",
		"test_terrain_collision_matches_mesh",
		"test_bots_battle_in_arena",
		"test_missile_homes_and_hits",
		"test_rolling_hard_shakes_off_missile",
		"test_mine_arms_then_explodes",
		"test_smoke_blocks_lock_on",
		"test_effects_start_where_placed",
		"test_grass_only_on_flat_dry_ground",
		"test_canopy_cracks_follow_damage",
		"test_settings_roundtrip",
		"test_mouse_steers",
		"test_aim_assist_can_be_turned_off",
		"test_tail_rotor_hit_spins_the_choppa",
		"test_engine_hit_loses_lift",
		"test_crash_damages_hull_and_parts",
		"test_blast_wrecks_the_nearest_part",
		"test_landing_is_gentle_slamming_is_not",
		"test_wall_crashes_scale_with_speed",
		"test_rotor_strike_wrecks_the_rotor",
		"test_rollover_burns_out",
		"test_easy_model_hovers_and_flies_where_it_looks",
		"test_loadout_runs_out_and_waits_between_shots",
		"test_rocket_hits_the_part_it_strikes",
		"test_flares_break_a_missile_lock",
		"test_station_repairs_and_rearms_then_powers_down",
		"test_station_needs_a_landing",
		"test_ammo_station_rearms_but_does_not_repair",
		"test_gun_spread_blooms_with_heat",
		"test_airframes_differ",
		"test_hurt_bot_lands_at_a_station",
		"test_power_line_wrecks_a_rotor",
		"test_wind_pushes_choppas",
		"test_bots_battle_in_canyon",
		"test_bots_battle_in_harbor",
		"test_level_curve",
		"test_camo_unlock_rules",
		"test_battle_xp_and_profile",
		"test_match_stats_count_what_you_did",
		"test_camo_reaches_the_hull",
		"test_every_sound_exists_and_loops_loop",
		"test_wrecking_a_part_tells_the_shooter_and_shows",
		"test_loops_loop_and_takes_are_counted",
		"test_music_crossfades_between_tracks",
		"test_radio_stations_cycle",
		"test_classes_feel_apart",
		"test_coaxial_striker_shrugs_off_tail_hits",
		"test_cold_start_spools_up_before_lift",
		"test_engine_key_toggles_and_off_sinks",
		"test_easy_dive_key_only_dives",
		"test_assists_level_and_hover",
		"test_assist_altitude_hold",
		"test_assist_coordinated_turn",
		"test_assist_landing_cushions",
		"test_assist_auto_start_can_be_off",
		"test_key_rates_and_ramp",
		"test_rebinding_keys",
		"test_every_class_has_its_own_cockpit",
		"test_spawns_are_on_dry_clear_ground",
		"test_replay_is_deterministic",
		"test_net_client_predicts_and_server_agrees",
		"test_net_survives_lag_and_loss",
		"test_net_server_owns_damage_and_kills",
		"test_net_leaving_hands_the_seat_to_a_bot",
		"test_net_rounds_follow_each_other",
	]:
		_world = Node3D.new()
		root.add_child(_world)
		var before := _failures
		await call(test)
		print("%s %s" % ["PASS" if _failures == before else "FAIL", test])
		_world.queue_free()
		await process_frame
	print("\n%s" % ("ALL TESTS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers ---------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  check failed: ", message)


func _ground() -> void:
	MapKit.block(_world, Vector3(0.0, -1.0, 0.0), Vector3(1000.0, 2.0, 1000.0), Color.GRAY)


func _choppa(pos: Vector3) -> Choppa:
	var choppa := Choppa.new()
	_world.add_child(choppa)
	choppa.respawn(Transform3D(Basis(), pos))
	choppa.invulnerable = 0.0
	choppa.set_physics_process(false)  # The tests step it by hand.
	return choppa


## Steps the choppa `ticks` times. Physics queries need the space to be flushed, so it
## waits for a real physics frame every tick.
func _fly(choppa: Choppa, ticks: int, setup := Callable()) -> void:
	for t in ticks:
		if setup.is_valid():
			setup.call(choppa.input, t)
		await physics_frame
		choppa.step(TICK)


# --- tests -------------------------------------------------------------------

func test_neutral_input_hovers() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	await _fly(choppa, 120)
	_check(absf(choppa.global_position.y - 10.0) < 0.1, "altitude held, y=%f" % choppa.global_position.y)
	_check(choppa.velocity.length() < 0.1, "stays still, v=%s" % choppa.velocity)


func test_nose_down_accelerates_forward() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	# Push the stick for a moment: the nose stays down afterwards and the choppa keeps
	# accelerating, sinking a little because the rotor now pushes forward as well.
	await _fly(choppa, 180, func(i: PilotInput, t: int) -> void: i.cyclic.y = 1.0 if t < 15 else 0.0)
	_check(choppa.nose_down() > 0.3, "nose held down, %f rad" % choppa.nose_down())
	_check(choppa.global_position.z < -12.0, "moved along -Z, z=%f" % choppa.global_position.z)
	_check(absf(choppa.global_position.x) < 0.5, "no sideways drift, x=%f" % choppa.global_position.x)
	_check(choppa.global_position.y < 29.0, "sank a little without extra collective, y=%f" % choppa.global_position.y)


func test_yaw_right_turns_right() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	await _fly(choppa, 30, func(i: PilotInput, _t: int) -> void: i.yaw = 1.0)
	# Turning right from facing -Z means the forward vector gains +X.
	_check((choppa.facing() * Vector3.FORWARD).x > 0.3, "turned right, heading=%f" % choppa.heading)


func test_cannot_dive_through_ground() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 4.0, 0.0))
	await _fly(choppa, 120, func(i: PilotInput, _t: int) -> void: i.collective = -1.0)
	_check(choppa.global_position.y > 0.9, "stopped on ground, y=%f" % choppa.global_position.y)
	_check(choppa.altitude < 0.2, "altitude near zero, alt=%f" % choppa.altitude)


func test_boost_is_faster_and_drains_meter() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	choppa.boost_meter = 1.0
	await _fly(choppa, 120, func(i: PilotInput, _t: int) -> void: i.boost = true)
	_check(choppa.velocity.length() > 25.0, "the afterburner pushed it along, v=%f" % choppa.velocity.length())
	_check(choppa.boost_meter < 0.1, "charge used up, meter=%f" % choppa.boost_meter)
	choppa.input.clear()
	await _fly(choppa, 120)
	_check(choppa.boost_meter > 0.3, "charge comes back when off, meter=%f" % choppa.boost_meter)


func test_wall_hit_bounces_and_stuns() -> void:
	MapKit.block(_world, Vector3(0.0, 10.0, -20.0), Vector3(40.0, 40.0, 2.0), Color.GRAY)
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	var bumps := []
	choppa.bumped.connect(func(impact: float) -> void: bumps.append(impact))
	choppa.velocity = Vector3(0.0, 0.0, -40.0)
	await _fly(choppa, 40)
	_check(bumps.size() >= 1, "bumped the wall")
	_check(choppa.global_position.z > -20.0, "did not pass through, z=%f" % choppa.global_position.z)


func _bullets() -> Array:
	return _world.get_children().filter(func(n: Node) -> bool: return n is Bullet)


func _hold_fire(i: PilotInput, _t: int) -> void:
	i.fire = true


func test_gun_fires_and_overheats() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	var overheats := []
	choppa.gun_overheated.connect(func() -> void: overheats.append(true))
	await _fly(choppa, 6, _hold_fire)
	_check(_bullets().size() >= 1, "spawned bullets")
	_check(choppa.heat > 0.0, "heat rose")
	await _fly(choppa, 174, _hold_fire)
	_check(overheats.is_empty() and not choppa.overheated, "three seconds of fire do not overheat it")
	await _fly(choppa, 240, _hold_fire)
	_check(overheats.size() == 1, "overheated once, got %d" % overheats.size())
	_check(choppa.overheated, "still overheated while holding fire")


func test_gun_cools_down_after_overheat() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	choppa.heat = 1.0
	choppa.overheated = true
	await _fly(choppa, 30, _hold_fire)
	_check(_bullets().is_empty(), "no shots while overheated")
	choppa.input.clear()
	await _fly(choppa, 120)
	_check(not choppa.overheated and choppa.heat == 0.0, "cooled down, heat=%f" % choppa.heat)


func test_bullets_knock_target_back() -> void:
	var shooter := _choppa(Vector3(0.0, 10.0, 0.0))
	var target := _choppa(Vector3(0.0, 10.0, -40.0))
	var hits := []
	shooter.scored_hit.connect(func(t: Choppa) -> void: hits.append(t))
	for t in 60:
		shooter.input.fire = true
		await physics_frame
		shooter.step(TICK)
		target.step(TICK)
	_check(hits.size() >= 8, "scored hits, got %d" % hits.size())
	_check(hits.all(func(t: Choppa) -> bool: return t == target), "hit the target")
	_check(target.velocity.z < -0.2, "pushed away from shooter, v=%s" % target.velocity)


func test_aim_assist_hits_target_above() -> void:
	var shooter := _choppa(Vector3(0.0, 10.0, 0.0))
	var target := _choppa(Vector3(4.0, 18.0, -50.0))
	_check(shooter.aim_target() == target, "locked on")
	var hits := []
	shooter.scored_hit.connect(func(t: Choppa) -> void: hits.append(t))
	await _fly(shooter, 30, _hold_fire)
	_check(hits.size() >= 3, "assisted shots hit, got %d" % hits.size())


func test_rolling_hard_dodges_bullets() -> void:
	var shooter := _choppa(Vector3(0.0, 30.0, 0.0))
	var target := _choppa(Vector3(0.0, 30.0, -30.0))
	var taken := []
	target.hit_taken.connect(func(_i: Vector3, _s: Choppa) -> void: taken.append(true))
	# Full roll stick: the rate builds up over a few ticks, then the burst arrives mid-roll.
	for t in 40:
		shooter.input.fire = t >= 20 and t < 24
		target.input.cyclic.x = 1.0
		await physics_frame
		shooter.step(TICK)
		target.step(TICK)
	_check(target.is_rolling_hard(), "rolling hard, %f rad/s" % target.rates.z)
	_check(taken.is_empty(), "no hits taken while rolling, got %d" % taken.size())


func test_bullets_stop_at_walls() -> void:
	MapKit.block(_world, Vector3(0.0, 10.0, -20.0), Vector3(40.0, 40.0, 0.5), Color.GRAY)
	var shooter := _choppa(Vector3(0.0, 10.0, 0.0))
	var target := _choppa(Vector3(0.0, 10.0, -40.0))
	var taken := []
	target.hit_taken.connect(func(_i: Vector3, _s: Choppa) -> void: taken.append(true))
	await _fly(shooter, 30, _hold_fire)
	_check(taken.is_empty(), "wall blocked the bullets")


## A race on a bare course of gates (no map) with racers parked behind gate 0.
func _mini_race(field: Array[Choppa], gate_count := 3, laps := 2) -> Race:
	var course: Array[RingGate] = []
	for n in gate_count:
		var gate := RingGate.new()
		gate.index = n
		gate.position = Vector3(0.0, 10.0, -100.0 * n)
		_world.add_child(gate)
		course.append(gate)
	var race := Race.new()
	race.set_physics_process(false)
	_world.add_child(race)
	race.setup(course, field, laps)
	race.tick(Race.COUNTDOWN + 0.01)
	return race


func test_race_counts_gates_in_order_and_laps() -> void:
	var a := _choppa(Vector3(0.0, 10.0, 20.0))
	var race := _mini_race([a], 3, 2)
	_check(race.running and not a.locked, "countdown over, racer unlocked")
	var g := race.gates
	g[1].passed.emit(a)  # Out of order: ignored.
	_check(race._checkpoints(a) == 0, "skipping the start line does not count")
	g[0].passed.emit(a)
	_check(race.lap_of(a) == 1 and race.next_gate(a) == g[1], "lap 1 started")
	var back := race.respawn_point(a)
	_check(back.origin.is_equal_approx(g[0].global_position), "respawn at the last gate")
	_check((back.basis * Vector3.FORWARD).dot(Vector3.FORWARD) > 0.99, "respawn facing the next gate")
	g[2].passed.emit(a)  # Skipped gate 1: ignored.
	_check(race.next_gate(a) == g[1], "must take gates in order")
	g[1].passed.emit(a)
	g[2].passed.emit(a)
	g[0].passed.emit(a)
	_check(race.lap_of(a) == 2, "lap 2 started")
	_check(not race.is_done(a), "not finished yet")
	g[1].passed.emit(a)
	g[2].passed.emit(a)
	g[0].passed.emit(a)
	_check(race.is_done(a), "finished after 2 laps")
	_check(race.over and race.results.size() == 1, "race over when everyone finished")


func test_race_standings_and_results() -> void:
	var a := _choppa(Vector3(0.0, 10.0, 20.0))
	var b := _choppa(Vector3(5.0, 10.0, 20.0))
	var c := _choppa(Vector3(10.0, 10.0, 20.0))
	var race := _mini_race([a, b, c], 3, 1)
	var g := race.gates
	for r: Choppa in [a, b, c]:
		g[0].passed.emit(r)
	g[1].passed.emit(b)
	_check(race.standings()[0] == b, "b leads after more gates")
	c.global_position = Vector3(0.0, 10.0, -95.0)  # Closest to gate 1.
	_check(race.place_of(c) == 2 and race.place_of(a) == 3, "ties broken by distance")
	for gate in [g[2], g[0]]:
		gate.passed.emit(c)  # c is still on gate 1: ignored.
	for gate in [g[2], g[0]]:
		gate.passed.emit(b)
	_check(race.is_done(b) and race.place_of(b) == 1, "b finished first")
	_check(not race.over, "race continues for the others")
	race.tick(Race.FINISH_GRACE + 0.1)
	_check(race.over, "grace period ends the race")


func test_bot_flies_the_course() -> void:
	var map := TestRange.new()
	map.mode = "race"
	_world.add_child(map)
	var bot_choppa := Choppa.new()
	_world.add_child(bot_choppa)
	bot_choppa.spawn_on_ground(map.spawn_points[0])
	var race := Race.new()
	_world.add_child(race)
	race.setup(map.gates, [bot_choppa], 2)
	var bot := RacerBot.new()
	bot.choppa = bot_choppa
	bot.race = race
	_world.add_child(bot)
	var bumps := []
	bot_choppa.bumped.connect(func(impact: float) -> void:
		bumps.append(impact)
		print("      BUMP %.0f at %s next gate %d" % [impact, bot_choppa.global_position.snapped(Vector3.ONE), race.next_gate(bot_choppa).index]))
	var laps := []
	race.lap_started.connect(func(_c: Choppa, lap: int) -> void: laps.append([lap, race.time]))
	var limit := 60 * 240
	while not race.over and limit > 0:
		await physics_frame
		limit -= 1
	print("    laps started at %s, finished=%s in %.1fs, bumps=%s, stuck at gate %d" % [
		laps, race.is_done(bot_choppa), race.time, bumps, race.next_gate(bot_choppa).index])
	_check(race.is_done(bot_choppa), "bot finished 2 laps")
	_check(race.time < 220.0, "in reasonable time, %.1fs" % race.time)  # Heavier model: laps take ~100 s.
	_check(bumps.is_empty(), "no wall hits, got %d" % bumps.size())


func test_four_bots_all_finish() -> void:
	var map := TestRange.new()
	map.mode = "race"
	_world.add_child(map)
	var field: Array[Choppa] = []
	for n in 4:
		var c := Choppa.new()
		_world.add_child(c)
		c.spawn_on_ground(map.spawn_points[n])
		field.append(c)
	var race := Race.new()
	_world.add_child(race)
	race.setup(map.gates, field, 1)
	for n in 4:
		var bot := RacerBot.new()
		bot.choppa = field[n]
		bot.race = race
		bot.skill = 1.0 - n * 0.1
		_world.add_child(bot)
	var limit := 60 * 180
	while not race.over and limit > 0:
		await physics_frame
		limit -= 1
	var times := race.results.map(func(r: Dictionary) -> String: return "%.1f" % r.time)
	print("    finish times %s, race time %.1fs" % [times, race.time])
	for c in field:
		if not race.is_done(c):
			print("    unfinished: lap %d, next gate %d, at %s, speed %.1f" % [race.lap_of(c), race.next_gate(c).index, c.global_position, c.velocity.length()])
	_check(race.results.size() == 4, "all four finished, got %d" % race.results.size())


func test_bullets_damage_and_kill() -> void:
	var shooter := _choppa(Vector3(0.0, 10.0, 0.0))
	var target := _choppa(Vector3(0.0, 10.0, -30.0))
	var deaths := []
	target.died.connect(func(killer: Choppa) -> void: deaths.append(killer))
	for t in 600:
		shooter.input.fire = shooter.heat < 0.8
		await physics_frame
		shooter.step(TICK)
		target.step(TICK)
		if not target.alive:
			break
	_check(deaths == [shooter], "killed by the shooter, got %s" % [deaths])
	_check(not target.alive and target.health == 0.0, "dead")
	_check(shooter.aim_target() == null, "dead choppas are not targets")
	target.input.cyclic = Vector2(0.0, 1.0)
	var at := target.global_position
	target.step(TICK)
	_check(target.global_position == at, "dead choppas don't fly")
	target.respawn(Transform3D(Basis(), Vector3(0.0, 10.0, -30.0)))
	_check(target.alive and target.health == Choppa.MAX_HEALTH, "respawned at full health")


func test_spawn_shield_blocks_damage() -> void:
	var a := _choppa(Vector3(0.0, 10.0, 0.0))
	a.respawn(Transform3D(Basis(), Vector3(0.0, 10.0, 0.0)))
	a.damage(50.0, null)
	_check(a.health == Choppa.MAX_HEALTH, "shielded right after spawning")
	await _fly(a, int(Choppa.SPAWN_SHIELD / TICK) + 2)
	a.damage(50.0, null)
	_check(a.health == 50.0, "shield wears off")


func test_crash_after_hit_credits_attacker() -> void:
	MapKit.block(_world, Vector3(0.0, 10.0, -30.0), Vector3(40.0, 40.0, 2.0), Color.GRAY)
	var shooter := _choppa(Vector3(50.0, 10.0, 0.0))
	var victim := _choppa(Vector3(0.0, 10.0, 0.0))
	victim.damage(Choppa.MAX_HEALTH - 5.0, shooter)
	var deaths := []
	victim.died.connect(func(killer: Choppa) -> void: deaths.append(killer))
	victim.velocity = Vector3(0.0, 0.0, -70.0)
	await _fly(victim, 30)
	_check(deaths == [shooter], "crash kill credited to the shooter, got %s" % [deaths])


func test_battle_kills_respawn_and_limit() -> void:
	var a := _choppa(Vector3(0.0, 10.0, 0.0))
	var b := _choppa(Vector3(0.0, 10.0, -20.0))
	var spawns: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(0.0, 10.0, 5.0)), Transform3D(Basis(), Vector3(0.0, 10.0, 300.0)),
	]
	var battle := Battle.new()
	battle.set_physics_process(false)
	_world.add_child(battle)
	battle.setup([a, b], spawns, 2, 60.0)
	b.damage(500.0, a)
	_check(battle.kills_of(a) == 1 and battle.deaths_of(b) == 1, "kill counted")
	_check(battle.respawn_in(b) > 0.0, "victim waits to respawn")
	battle.tick(Battle.RESPAWN_DELAY + 0.01)
	_check(b.alive, "victim respawned")
	_check(b.global_position.distance_to(spawns[1].origin + Vector3.UP * (b.clearance + 0.05)) < 0.1, "respawned far from the killer, skids on the spawn point")
	_check(battle.standings()[0] == a, "killer leads")
	b.invulnerable = 0.0
	b.damage(500.0, a)
	_check(battle.over, "kill limit ends the match")
	_check(a.locked and b.locked, "everyone stops at the end")


func test_battle_time_limit() -> void:
	var a := _choppa(Vector3(0.0, 10.0, 0.0))
	var battle := Battle.new()
	battle.set_physics_process(false)
	_world.add_child(battle)
	battle.setup([a], [Transform3D()], 10, 5.0)
	battle.tick(4.0)
	_check(not battle.over, "still running")
	battle.tick(1.5)
	_check(battle.over and battle.time_left == 0.0, "time runs out")


func test_terrain_collision_matches_mesh() -> void:
	var terrain := Terrain.new()
	terrain.size = 200.0
	terrain.resolution = 20
	terrain.height_fn = func(x: float, z: float) -> float: return sin(x * 0.05) * 10.0 + z * 0.1
	_world.add_child(terrain)
	await physics_frame
	var space := _world.get_world_3d().direct_space_state
	for p: Vector2 in [Vector2(0, 0), Vector2(33, -12), Vector2(-71, 58), Vector2(12.5, 7.5)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 100, p.y), Vector3(p.x, -100, p.y)))
		var expected := terrain.height_at(p.x, p.y)
		_check(hit and absf(hit.position.y - expected) < 0.05, "collision at %s: %s vs %f" % [p, hit.get("position"), expected])


func test_bots_battle_in_arena() -> void:
	await _bot_battle(MesaBasin.new())


func test_bots_battle_in_canyon() -> void:
	await _bot_battle(SlotCanyon.new())


## Rust Harbor: container alleys, cranes and warehouses must not trap the bots.
func test_bots_battle_in_harbor() -> void:
	await _bot_battle(RustHarbor.new())


## Four fighter bots for two minutes on `map`: they must move, fight, use rockets and
## the service stations.
func _bot_battle(map: GameMap) -> void:
	map.mode = "battle"
	_world.add_child(map)
	var field: Array[Choppa] = []
	for n in 4:
		var c := Choppa.new()
		c.pilot_name = "Bot%d" % n
		c.max_altitude = map.ceiling
		_world.add_child(c)
		c.spawn_on_ground(map.spawn_points[n * 2], true)  # As in a match: on the ground, engine off.
		field.append(c)
	var battle := Battle.new()
	_world.add_child(battle)
	battle.setup(field, map.spawn_points, 99, 120.0)
	var bumps := {}
	var travelled := {}
	var used := []
	var serviced := []
	var dealt := [0.0]
	for c in field:
		c.damaged.connect(func(amount: float, attacker: Choppa) -> void:
			if attacker and attacker != c:
				dealt[0] += amount)
		bumps[c] = 0
		travelled[c] = 0.0
		c.bumped.connect(func(_i: float) -> void: bumps[c] += 1)
		c.fired.connect(func(weapon: String) -> void: used.append(weapon))
		var bot := FighterBot.new()
		bot.choppa = c
		bot.ceiling = map.ceiling
		bot.rng.seed = hash(c.pilot_name)
		_world.add_child(bot)
	for node in _world.get_tree().get_nodes_in_group("stations"):
		(node as ServiceStation).served.connect(func(c: Choppa) -> void: serviced.append(c.pilot_name))
	var last := {}
	for c in field:
		last[c] = c.global_position
	while not battle.over:
		await physics_frame
		for c in field:
			if c.alive:
				travelled[c] += c.global_position.distance_to(last[c])
			last[c] = c.global_position
	var summary := field.map(func(c: Choppa) -> String:
		return "%s k%d d%d bumps%d %.0fm" % [c.pilot_name, battle.kills_of(c), battle.deaths_of(c), bumps[c], travelled[c]])
	var counts := {}
	for weapon in used:
		counts[weapon] = counts.get(weapon, 0) + 1
	print("    ", summary, " damage dealt: %d, weapons fired: %s, serviced: %s" % [dealt[0], counts, serviced])
	var kills := 0
	for c in field:
		kills += battle.kills_of(c)
		_check(travelled[c] > 800.0, "%s kept moving" % c.pilot_name)
	# Exact kill counts vary between machines; what matters is that they fight.
	_check(dealt[0] >= 300.0, "bots deal real damage, got %d" % dealt[0])
	_check(kills >= 2, "bots score kills, got %d" % kills)
	_check(counts.get("rockets", 0) >= 4, "bots fire rockets, got %s" % [counts])
	_check(serviced.size() >= 1, "bots land at service stations, got %s" % [serviced])


## Steps choppas by hand for `ticks` ticks while the weapon objects run on their own.
func _step_all(field: Array, ticks: int) -> void:
	for t in ticks:
		await physics_frame
		for c: Choppa in field:
			c.step(TICK)


func test_missile_homes_and_hits() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	# Off to the side and higher: only a homing missile can hit this.
	var target := _choppa(Vector3(40.0, 35.0, -90.0))
	_check(shooter.missile_target() == target, "locks on")
	_check(shooter.fire_missile(), "fired")
	await _step_all([shooter, target], 150)
	_check(target.health < Choppa.MAX_HEALTH - 20.0, "missile hit, hp=%f" % target.health)
	_check(shooter.health == Choppa.MAX_HEALTH, "shooter unhurt")


func test_rolling_hard_shakes_off_missile() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	var target := _choppa(Vector3(0.0, 20.0, -120.0))
	shooter.fire_missile()
	var missile: Weapons.Missile = _world.get_children().filter(func(n: Node) -> bool: return n is Weapons.Missile)[0]
	for t in 150:
		await physics_frame
		var close := missile and is_instance_valid(missile) and target.global_position.distance_to(missile.global_position) < 60.0
		target.input.cyclic.x = 1.0 if close else 0.0
		shooter.step(TICK)
		target.step(TICK)
	_check(target.health == Choppa.MAX_HEALTH, "dodged, hp=%f" % target.health)


func test_mine_arms_then_explodes() -> void:
	var layer := _choppa(Vector3(0.0, 20.0, 0.0))
	var victim := _choppa(Vector3(0.0, 20.0, 60.0))
	_check(layer.drop_mine(), "dropped")
	await _step_all([layer, victim], 10)
	_check(layer.health == Choppa.MAX_HEALTH, "doesn't go off under its owner before arming")
	await _step_all([layer], 60)
	# Fly the victim into it.
	for t in 120:
		victim.velocity = Vector3(0.0, 0.0, -30.0)  # Held at speed; drag would slow it.
		await physics_frame
		victim.step(TICK)
	_check(victim.health <= Choppa.MAX_HEALTH - 25.0, "mine went off, hp=%f" % victim.health)


func test_smoke_blocks_lock_on() -> void:
	var a := _choppa(Vector3(0.0, 20.0, 0.0))
	var b := _choppa(Vector3(0.0, 20.0, -60.0))
	_check(a.aim_target() == b, "locked before smoke")
	var cloud := Weapons.SmokeCloud.new()
	_world.add_child(cloud)
	cloud.global_position = b.global_position
	_check(b.in_smoke(), "b is in the cloud")
	_check(a.aim_target() == null, "can't lock onto a choppa in smoke")
	_check(b.aim_target() == null, "can't lock from inside smoke")


func test_effects_start_where_placed() -> void:
	# Callers add an effect and then move it; nothing may fire before the move, or the
	# world-space particles burst at the origin.
	var boom := Effects.Explosion.new()
	_world.add_child(boom)
	_check(boom.get_child_count() == 0, "explosion waits to be placed")
	boom.global_position = Vector3(50.0, 10.0, -30.0)
	var impact := Effects.Impact.new()
	_world.add_child(impact)
	_check(impact.get_child_count() == 0, "impact waits to be placed")
	impact.global_position = Vector3(-20.0, 3.0, 5.0)
	await process_frame
	await process_frame
	var fire := boom.get_child(0) as CPUParticles3D
	_check(fire != null and fire.emitting, "explosion fires once placed")
	_check(fire != null and fire.global_position.is_equal_approx(Vector3(50.0, 10.0, -30.0)), "...at its spot")
	_check(impact.get_child_count() > 0, "impact fires once placed")


func test_grass_only_on_flat_dry_ground() -> void:
	# Flat ground at y=5 west of x=0, a 45 degree slope east of it.
	var terrain := Terrain.new()
	terrain.size = 120.0
	terrain.resolution = 60
	terrain.height_fn = func(x: float, _z: float) -> float: return 5.0 + maxf(0.0, x)
	_world.add_child(terrain)
	var grass := Grass.new()
	grass.terrain = terrain
	grass.radius = 40.0
	grass.density = 0.5
	_world.add_child(grass)
	var tufts := 0
	var on_slope := 0
	for chunk: MultiMeshInstance3D in grass.get_children():
		for k in chunk.multimesh.instance_count:
			tufts += 1
			if chunk.multimesh.get_instance_transform(k).origin.x > 2.5:
				on_slope += 1
	_check(tufts > 500, "grass grows on the flat, got %d tufts" % tufts)
	_check(on_slope == 0, "none on the slope, got %d" % on_slope)
	var flooded := Grass.new()
	flooded.terrain = terrain
	flooded.radius = 40.0
	flooded.density = 0.5
	flooded.water_level = 10.0
	_world.add_child(flooded)
	_check(flooded.get_child_count() == 0, "none under water")


func test_canopy_cracks_follow_damage() -> void:
	var c := _choppa(Vector3(0.0, 20.0, 0.0))
	await _fly(c, 2)
	var cracked := func() -> int:
		return c.model._cracks.filter(func(m: MeshInstance3D) -> bool: return m.visible).size()
	_check(c.model._cracks.size() >= 6, "crack spots on the glass, got %d" % c.model._cracks.size())
	_check(cracked.call() == 0, "intact at full health")
	c.damage(60.0, null)
	await _fly(c, 2)
	_check(cracked.call() >= 4, "cracked when hurt, got %d" % cracked.call())
	c.heal(100.0)
	await _fly(c, 2)
	_check(cracked.call() == 0, "repaired when healed")


func test_settings_roundtrip() -> void:
	var path := "user://settings_test.cfg"
	Settings.set_value("mouse_sensitivity", 7)
	Settings.set_value("invert_mouse", true)
	Settings.set_value("render_scale", 0.8)
	Settings.set_value("resolution", "1920x1080")
	Settings.save(path)
	Settings.reset()
	_check(Settings.choice("mouse_sensitivity") == 5, "reset restores the default")
	Settings.read(path)
	_check(Settings.choice("mouse_sensitivity") == 7, "sensitivity read back: %d" % Settings.choice("mouse_sensitivity"))
	_check(Settings.flag("invert_mouse"), "invert flag read back")
	_check(is_equal_approx(Settings.number("render_scale"), 0.8), "render scale read back")
	_check(Settings.value("resolution") == "1920x1080", "resolution read back")
	_check(Settings.feature("gi", true) and not Settings.feature("gi", false), "Auto follows the quality")
	Settings.set_value("gi", 0)
	_check(not Settings.feature("gi", true), "an explicit Off wins over the quality")
	Settings.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_mouse_steers() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	var pilot := LocalPilot.new()
	pilot.choppa = choppa
	pilot.set_physics_process(false)  # Stepped by hand below.
	_world.add_child(pilot)
	Settings.reset()
	pilot.feed_mouse(Vector2(40.0, -40.0))  # Right, and forward (up the screen).
	pilot._physics_process(TICK)
	_check(choppa.input.cyclic.x > 0.5, "mouse right rolls right: %f" % choppa.input.cyclic.x)
	_check(choppa.input.cyclic.y > 0.5, "mouse forward puts the nose down: %f" % choppa.input.cyclic.y)
	_check(choppa.input.yaw == 0.0, "no yaw from the mouse in the pitch & roll layout")
	pilot._physics_process(TICK)
	_check(choppa.input.cyclic == Vector2.ZERO, "mouse travel is used up each tick")
	Settings.set_value("invert_mouse", true)
	pilot.feed_mouse(Vector2(0.0, -40.0))
	pilot._physics_process(TICK)
	_check(choppa.input.cyclic.y < -0.5, "inverted: mouse forward pulls the nose up: %f" % choppa.input.cyclic.y)
	Settings.set_value("invert_mouse", false)
	Settings.set_value("mouse_mode", 1)
	pilot.feed_mouse(Vector2(40.0, 0.0))
	pilot._physics_process(TICK)
	_check(choppa.input.yaw > 0.5 and choppa.input.cyclic.x == 0.0, "pitch & yaw layout: mouse right turns right")
	Settings.set_value("mouse_steer", false)
	pilot.feed_mouse(Vector2(40.0, 0.0))
	pilot._physics_process(TICK)
	_check(choppa.input.yaw == 0.0, "mouse steering off: the mouse does nothing")
	Settings.reset()


func test_aim_assist_can_be_turned_off() -> void:
	_ground()
	var shooter := _choppa(Vector3(0.0, 10.0, 0.0))
	var target := _choppa(Vector3(0.0, 10.0, -30.0))
	await physics_frame
	await physics_frame
	_check(shooter.aim_target() == target, "the guns lock onto a choppa straight ahead")
	shooter.aim_assist = false
	_check(shooter.aim_target() == null, "with aim assist off nothing locks on")


func test_tail_rotor_hit_spins_the_choppa() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	var tail := choppa.to_global(Vector3(0.0, 0.3, 3.6))
	var hull := choppa.health
	choppa.take_hit(Vector3.ZERO, null, 10.0, tail)
	_check(choppa.parts[Choppa.Part.TAIL] == Choppa.PART_HEALTH[Choppa.Part.TAIL] - 10.0, "tail rotor took the hit")
	_check(is_equal_approx(choppa.health, hull - 6.0), "a tail hit costs less hull, hp=%f" % choppa.health)
	for k in 4:
		choppa.take_hit(Vector3.ZERO, null, 10.0, tail)
	_check(choppa.wear(Choppa.Part.TAIL) == 1.0, "tail rotor wrecked")
	await _fly(choppa, 90)
	_check(absf(choppa.rates.y) > 1.5, "spins without the tail rotor, yaw rate %f" % choppa.rates.y)
	await _fly(choppa, 60, func(i: PilotInput, _t: int) -> void: i.yaw = -signf(choppa.rates.y))
	_check(absf(choppa.rates.y) > 0.6, "the pedals cannot stop the spin, yaw rate %f" % choppa.rates.y)


func test_engine_hit_loses_lift() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	choppa.parts[Choppa.Part.ENGINE] = 0.0
	await _fly(choppa, 60)
	_check(choppa.velocity.y < -2.0, "sinks at hover collective with the engine wrecked, vy=%f" % choppa.velocity.y)
	choppa.boost_meter = 1.0
	await _fly(choppa, 30, func(i: PilotInput, _t: int) -> void: i.boost = true)
	_check(is_equal_approx(choppa.boost_meter, 1.0), "no afterburner without an engine")
	_check(choppa.heal(50.0), "a repair kit fixes parts too")
	_check(choppa.parts[Choppa.Part.ENGINE] == Choppa.PART_HEALTH[Choppa.Part.ENGINE], "engine repaired")


func test_crash_damages_hull_and_parts() -> void:
	MapKit.block(_world, Vector3(0.0, 10.0, -20.0), Vector3(40.0, 40.0, 2.0), Color.GRAY)
	var choppa := _choppa(Vector3(0.0, 10.0, -5.0))
	choppa.velocity = Vector3(0.0, 0.0, -25.0)
	await _fly(choppa, 60)
	_check(choppa.health < Choppa.MAX_HEALTH - 10.0, "a 25 m/s wall hit hurts, hp=%f" % choppa.health)
	_check(choppa.health > 0.0, "but does not kill outright")
	# Backing into it tail first (facing -Z, moving +Z) wrecks the tail rotor.
	var tail_first := _choppa(Vector3(0.0, 10.0, -33.0))
	tail_first.velocity = Vector3(0.0, 0.0, 25.0)
	await _fly(tail_first, 60)
	_check(tail_first.wear(Choppa.Part.TAIL) > 0.5, "tail strike wrecked the tail rotor, wear %f" % tail_first.wear(Choppa.Part.TAIL))


func test_blast_wrecks_the_nearest_part() -> void:
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	choppa.blast_damage(20.0, null, choppa.to_global(Vector3(0.0, 0.5, 4.0)))
	_check(choppa.parts[Choppa.Part.TAIL] == Choppa.PART_HEALTH[Choppa.Part.TAIL] - 16.0, "blast at the tail hit the tail rotor")
	_check(is_equal_approx(choppa.health, Choppa.MAX_HEALTH - 20.0), "and the hull")
	var other := _choppa(Vector3(0.0, 30.0, 50.0))
	other.blast_damage(20.0, null, other.to_global(Vector3(0.0, 2.0, 0.0)))
	_check(other.parts[Choppa.Part.ROTOR] < Choppa.PART_HEALTH[Choppa.Part.ROTOR], "blast above hit the main rotor")


func test_landing_is_gentle_slamming_is_not() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 4.0, 0.0))
	choppa.velocity = Vector3(12.0, -4.0, 0.0)  # A brisk touchdown with some run-on.
	await _fly(choppa, 90, func(i: PilotInput, _t: int) -> void: i.collective = -0.3)
	_check(choppa.health == Choppa.MAX_HEALTH, "a 4 m/s touchdown does not hurt, hp=%f" % choppa.health)
	_check(choppa.altitude < 0.3, "on the ground, alt=%f" % choppa.altitude)
	_check(Vector2(choppa.velocity.x, choppa.velocity.z).length() < 2.0, "the skids brought it to a stop, v=%s" % choppa.velocity)
	var slammed := _choppa(Vector3(0.0, 4.0, 50.0))
	slammed.velocity = Vector3(0.0, -9.0, 0.0)
	await _fly(slammed, 30, func(i: PilotInput, _t: int) -> void: i.collective = -1.0)
	_check(slammed.health < Choppa.MAX_HEALTH * 0.8 and slammed.alive, "a 9 m/s slam hurts badly but does not kill, hp=%f" % slammed.health)
	var flattened := _choppa(Vector3(0.0, 4.0, 100.0))
	flattened.velocity = Vector3(0.0, -15.0, 0.0)
	await _fly(flattened, 30, func(i: PilotInput, _t: int) -> void: i.collective = -1.0)
	_check(not flattened.alive, "a 15 m/s slam destroys it, hp=%f" % flattened.health)


func test_easy_model_hovers_and_flies_where_it_looks() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 90.0, 0.0))  # Room for the dive: the ground hurts now.
	choppa.easy = true
	await _fly(choppa, 60)
	_check(absf(choppa.global_position.y - 90.0) < 0.1 and choppa.velocity.length() < 0.1, "hovers by itself")
	# Aim the nose down a little, then push forward: it descends while flying ahead.
	await _fly(choppa, 120, func(i: PilotInput, t: int) -> void:
		i.cyclic.y = 1.0 if t < 15 else 0.0
		i.move.y = 1.0)
	_check(choppa.global_position.z < -20.0, "flew forward, z=%f" % choppa.global_position.z)
	_check(choppa.global_position.y < 87.0, "and down along the nose, y=%f" % choppa.global_position.y)
	_check(choppa.nose_down() > 0.2, "the nose stays where it was aimed, %f" % choppa.nose_down())
	choppa.input.clear()  # Let go of the move stick before pulling collective.
	await _fly(choppa, 60, func(i: PilotInput, _t: int) -> void: i.collective = 1.0)
	_check(choppa.velocity.y > 8.0, "collective climbs, vy=%f" % choppa.velocity.y)


func test_loadout_runs_out_and_waits_between_shots() -> void:
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	var rockets: int = choppa.ammo.rockets
	_check(rockets == Airframe.spec(Airframe.SCOUT).rockets, "full loadout at spawn, %d rockets" % rockets)
	_check(choppa.fire_rocket(), "first rocket")
	_check(not choppa.fire_rocket(), "the pods need a moment between rockets")
	var fired := 1
	for t in 200:
		choppa.input.rockets = true
		await physics_frame
		choppa.step(TICK)
	fired = rockets - choppa.ammo.rockets
	_check(choppa.ammo.rockets == 0 and fired == rockets, "fired them all, then nothing: %d left" % choppa.ammo.rockets)
	_check(not choppa.fire_rocket(), "empty pods do not fire")
	choppa.restock()
	_check(choppa.ammo.rockets == rockets and choppa.ammo.mines == 1, "restock fills everything")


func test_rocket_hits_the_part_it_strikes() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	# Straight ahead, facing away, in line with the shooter's left pod: the rocket meets
	# the end of its tail boom first.
	var target := _choppa(Vector3(-1.45, 20.0 - 0.9, -40.0))
	shooter._rocket_side = -1.0
	shooter.fire_rocket()
	await _step_all([shooter, target], 30)
	_check(target.health < Choppa.MAX_HEALTH, "the rocket hit, hp=%f" % target.health)
	_check(target.wear(Choppa.Part.TAIL) > 0.2, "and wrecked the tail rotor it struck, wear %f" % target.wear(Choppa.Part.TAIL))


func test_flares_break_a_missile_lock() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	var target := _choppa(Vector3(0.0, 20.0, -120.0))
	shooter.fire_missile()
	await _step_all([shooter, target], 30)
	var missile: Weapons.Missile = _world.get_children().filter(func(n: Node) -> bool: return n is Weapons.Missile)[0]
	_check(missile.is_hunting(target), "the missile is chasing the target")
	_check(target.fire_flares(), "flares out")
	_check(not missile.is_hunting(target), "the lock is broken")
	await _step_all([shooter, target], 150)
	_check(target.health == Choppa.MAX_HEALTH, "the missile missed, hp=%f" % target.health)
	var second := _choppa(Vector3(0.0, 20.0, 40.0))
	second.global_transform.basis = Basis(Vector3.UP, PI)
	second.fire_missile()
	var m2: Weapons.Missile = _world.get_children().filter(func(n: Node) -> bool: return n is Weapons.Missile and n != missile)[0]
	await _step_all([second, shooter], 2)
	_check(m2.target == null or not m2.is_hunting(shooter) or shooter.decoy_time == 0.0, "sanity: second missile")


## A flat ground and a station on it at the origin.
func _station_on_ground(ammo_only := false) -> ServiceStation:
	_ground()
	var station := ServiceStation.new()
	station.ammo_only = ammo_only
	_world.add_child(station)
	return station


func test_station_repairs_and_rearms_then_powers_down() -> void:
	var station := _station_on_ground()
	var choppa := _choppa(Vector3(0.0, station.pad_top() + Choppa.GROUND_CLEARANCE + 0.5, 0.0))
	choppa.damage(60.0, null)
	choppa.parts[Choppa.Part.TAIL] = 0.0
	choppa.ammo.rockets = 0
	var served := []
	station.served.connect(func(c: Choppa) -> void: served.append(c))
	# Settle onto the pad with a little less than hover power, then sit.
	for t in 60 * 6:
		choppa.input.collective = -0.2
		await physics_frame
		choppa.step(TICK)
		station.tick(TICK)
	_check(served == [choppa], "serviced once, got %s" % [served])
	_check(choppa.health == choppa.max_health, "hull repaired, hp=%f" % choppa.health)
	_check(choppa.wear(Choppa.Part.TAIL) == 0.0, "tail rotor repaired")
	_check(choppa.ammo.rockets == choppa.full_ammo("rockets"), "rearmed, %d rockets" % choppa.ammo.rockets)
	_check(not station.is_ready(), "the station powered down")
	choppa.damage(30.0, null)
	for t in 60 * 5:
		await physics_frame
		choppa.step(TICK)
		station.tick(TICK)
	_check(served.size() == 1 and choppa.health < choppa.max_health, "nothing while it is down")
	station.tick(ServiceStation.COOLDOWN)
	_check(station.is_ready(), "and back after the cooldown")


func test_station_needs_a_landing() -> void:
	var station := _station_on_ground()
	var hovering := _choppa(Vector3(0.0, station.pad_top() + 6.0, 0.0))
	hovering.damage(50.0, null)
	for t in 60 * 5:
		await physics_frame
		hovering.step(TICK)
		station.tick(TICK)
	_check(station.occupant == null and hovering.health == Choppa.MAX_HEALTH - 50.0, "hovering 6 m up does not count")
	var passing := _choppa(Vector3(-20.0, station.pad_top() + Choppa.GROUND_CLEARANCE + 0.2, 0.0))
	passing.velocity = Vector3(12.0, 0.0, 0.0)
	for t in 60:
		passing.velocity.x = 12.0
		await physics_frame
		passing.step(TICK)
		station.tick(TICK)
	_check(station.occupant != passing, "skimming across at speed does not count")


func test_airframes_differ() -> void:
	var scout := _choppa(Vector3(0.0, 40.0, 0.0))
	var heavy := _choppa(Vector3(50.0, 40.0, 0.0))
	heavy.set_airframe(Airframe.HEAVY)
	_check(heavy.max_health > scout.max_health and heavy.health == heavy.max_health, "the heavy has more hull")
	_check(heavy.part_max(Choppa.Part.TAIL) > scout.part_max(Choppa.Part.TAIL), "and tougher parts")
	_check(heavy.ammo.rockets > scout.ammo.rockets, "and more rockets")
	var roll := func(i: PilotInput, _t: int) -> void: i.cyclic.x = 1.0
	await _fly(scout, 20, roll)
	await _fly(heavy, 20, roll)
	_check(absf(scout.rates.z) > absf(heavy.rates.z) * 1.3, "the scout rolls faster: %f vs %f" % [scout.rates.z, heavy.rates.z])
	var bullet_damage := []
	heavy.damaged.connect(func(amount: float, _by: Choppa) -> void: bullet_damage.append(amount))
	var gunship := _choppa(Vector3(50.0, 40.0, 30.0))
	gunship.set_airframe(Airframe.GUNSHIP)
	_check(gunship.gun_factor > scout.gun_factor, "the gunship's guns hit harder")
	_check(gunship.model.airframe == Airframe.GUNSHIP, "and it wears its own model")


func test_hurt_bot_lands_at_a_station() -> void:
	var station := _station_on_ground()
	station.position = Vector3(0.0, 0.0, -60.0)
	var c := Choppa.new()
	_world.add_child(c)
	c.respawn(Transform3D(Basis(), Vector3(0.0, 15.0, 0.0)))
	c.invulnerable = 0.0
	c.damage(70.0, null)
	var bot := FighterBot.new()
	bot.choppa = c
	bot.ceiling = 90.0
	_world.add_child(bot)
	var served := []
	station.served.connect(func(who: Choppa) -> void: served.append(who))
	for t in 60 * 40:
		await physics_frame
		if not served.is_empty():
			break
	_check(served == [c], "the bot landed and got serviced, hp=%f, %.1f m from the pad" % [c.health,
		Vector2(c.global_position.x, c.global_position.z + 60.0).length()])


func test_power_line_wrecks_a_rotor() -> void:
	_ground()
	var line := Hazards.power_line(_world, [Vector3(-30.0, 0.0, -20.0), Vector3(30.0, 0.0, -20.0)] as Array[Vector3])
	# Fly level into the cables at rotor height: in the middle the cables sag to about
	# 22.4 m, so at 21 m the body passes under and the rotor (1.9 m up) meets them.
	var choppa := _choppa(Vector3(0.0, 21.0, 0.0))
	var hp := choppa.health
	for t in 120:
		choppa.velocity = Vector3(0.0, 0.0, -12.0)
		await physics_frame
		choppa.step(TICK)
		line._physics_process(TICK)
		if choppa.health < hp:
			break
	_check(choppa.health < hp, "touching the cables hurts, hp=%f" % choppa.health)
	_check(choppa.wear(Choppa.Part.ROTOR) > 0.5, "the rotor took the cable, wear %f" % choppa.wear(Choppa.Part.ROTOR))
	var below := _choppa(Vector3(5.0, 10.0, 10.0))
	for t in 200:
		below.velocity = Vector3(0.0, 0.0, -12.0)
		await physics_frame
		below.step(TICK)
		line._physics_process(TICK)
	_check(below.health == Choppa.MAX_HEALTH and below.global_position.z < -20.0, "flying under them is fine")


func test_wind_pushes_choppas() -> void:
	var zone := Hazards.wind(_world, Vector3(0.0, 30.0, 0.0), Vector3(60.0, 60.0, 60.0), Vector3(6.0, 0.0, 0.0))
	var inside := _choppa(Vector3(0.0, 30.0, 0.0))
	var outside := _choppa(Vector3(0.0, 30.0, 120.0))
	for t in 120:
		await physics_frame
		zone._physics_process(TICK)
		inside.step(TICK)
		outside.step(TICK)
	_check(inside.global_position.x > 3.0, "the wind pushed it along +X, x=%f" % inside.global_position.x)
	_check(absf(outside.global_position.x) < 0.1, "nothing outside the zone")


func test_level_curve() -> void:
	_check(Progression.level_for(0) == 1, "everyone starts at level 1")
	_check(Progression.level_for(999) == 1 and Progression.level_for(1000) == 2, "1000 XP for level 2")
	_check(Progression.xp_for_level(2) == 1050, "each level costs 50 more")
	var top := Progression.total_xp_for(Progression.MAX_LEVEL)
	_check(Progression.level_for(top) == 100 and Progression.level_for(top - 1) == 99, "level 100 at %d XP" % top)
	_check(Progression.level_for(top * 3) == 100, "capped at 100")
	_check(Progression.ace_stars(top + Progression.ACE_STAR_XP * 2 + 5) == 2, "Ace stars past 100")
	_check(is_equal_approx(Progression.level_progress(Progression.total_xp_for(10) + 525), 525.0 / 1450.0), "progress in a level")
	for id: String in Progression.ORDER:
		_check(Progression.CAMOS.has(id), "%s is in the catalogue" % id)


func test_camo_unlock_rules() -> void:
	var none := PackedStringArray()
	_check(Progression.unlocked("factory", 0, none), "factory olive for everyone")
	_check(not Progression.unlocked("tiger", Progression.total_xp_for(19), none), "tiger needs level 20")
	_check(Progression.unlocked("tiger", Progression.total_xp_for(20), none), "and has it at 20")
	var maxed := Progression.total_xp_for(100) + Progression.ACE_STAR_XP
	for id: String in Progression.ORDER:
		var tier: String = Progression.CAMOS[id].tier
		var earned := Progression.unlocked(id, maxed, none)
		_check(earned == (tier == "level" or tier == "ace"), "%s: no amount of XP buys a %s camo" % [id, tier])
	_check(Progression.unlocked("racing", 0, PackedStringArray(["hangar"])), "the Hangar Pack has Racing at level 1")
	_check(not Progression.unlocked("chrome", 0, PackedStringArray(["hangar"])), "but not the Collector finishes")
	_check(Progression.unlocked("racing", 0, PackedStringArray(["collector"])), "the Collector Pack includes the Hangar Pack")
	_check(not Progression.unlocked("apex", maxed, PackedStringArray(["hangar", "collector"])), "Apex cannot be bought or earned")
	_check(Progression.unlocked("apex", 0, PackedStringArray(["apex"])), "only the apex entitlement")
	var profile := Progression.Profile.new()
	_check(not profile.choose(Airframe.SCOUT, "tiger"), "a level 1 pilot cannot pick tiger")
	_check(profile.camo_for(Airframe.SCOUT) == "factory", "and keeps factory olive")
	profile.camos[Airframe.HEAVY] = "apex"  # A tampered save file.
	_check(profile.camo_for(Airframe.HEAVY) == "factory", "a saved camo you do not own is not worn")


func test_battle_xp_and_profile() -> void:
	var award := Progression.award({"kill": 3, "assist": 1, "part": 2, "damage": 240, "finished": true, "won": true})
	_check(award.total == 300 + 40 + 50 + 240 + 100 + 200, "XP adds up, got %d" % award.total)
	var profile := Progression.Profile.new()
	profile.xp = Progression.total_xp_for(4) + 900
	var result := profile.add_battle({"kill": 3, "assist": 1, "part": 2, "damage": 240, "finished": true, "won": true})
	_check(result.total == award.total * 2, "first win of the day doubles it, got %d" % result.total)
	_check(result.level_before == 4 and result.level_after > 4, "level up %d > %d" % [result.level_before, result.level_after])
	_check(result.unlocked.has("desert"), "level 5 unlocks Desert, got %s" % [result.unlocked])
	var second := profile.add_battle({"kill": 1, "finished": true, "won": true})
	_check(second.total == 400, "the second win today is not doubled, got %d" % second.total)
	_check(profile.stats.matches == 2 and profile.stats.wins == 2 and profile.stats.kills == 4, "stats counted")
	var path := "user://profile_test.cfg"
	profile.choose(Airframe.GUNSHIP, "desert")
	profile.save(path)
	var loaded := Progression.Profile.new()
	loaded.load_from(path)
	_check(loaded.xp == profile.xp and loaded.camo_for(Airframe.GUNSHIP) == "desert", "saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var tester := Progression.Profile.new()
	tester.testing = true
	tester.xp = 12345
	tester.save(path)
	_check(not FileAccess.file_exists(path), "a --level / --entitle run never saves")


func test_match_stats_count_what_you_did() -> void:
	var me := _choppa(Vector3(0.0, 20.0, 0.0))
	var a := _choppa(Vector3(0.0, 20.0, -40.0))
	var b := _choppa(Vector3(30.0, 20.0, -40.0))
	var battle := Battle.new()
	_world.add_child(battle)
	battle.setup([me, a, b] as Array[Choppa], [Transform3D(Basis(), Vector3(0, 20, 0))] as Array[Transform3D], 3)
	var stats := MatchStats.new()
	stats.pilot = me
	stats.battle = battle
	_world.add_child(stats)
	a.damage(30.0, me)
	a.damage(80.0, me)  # Our kill.
	b.damage(20.0, me)
	b.damage(90.0, a)  # Someone else finishes b: our assist.
	var c := _choppa(Vector3(0.0, 20.0, 60.0))
	c.damage_part(Choppa.Part.TAIL, 100.0, me)
	_check(stats.stats.kill == 1, "one kill, got %d" % stats.stats.kill)
	_check(stats.stats.assist == 1, "one assist, got %d" % stats.stats.assist)
	_check(stats.stats.damage >= 120, "damage counted, got %d" % stats.stats.damage)
	_check(stats.stats.part == 0, "parts are only counted on battle pilots (c is not in it)")
	var part_hits := []
	a.respawn(Transform3D(Basis(), Vector3(0.0, 20.0, -40.0)))
	a.invulnerable = 0.0
	a.part_wrecked.connect(func(p: Choppa.Part, by: Choppa) -> void: part_hits.append([p, by]))
	a.damage_part(Choppa.Part.TAIL, 100.0, me)
	_check(part_hits == [[Choppa.Part.TAIL, me]] and stats.stats.part == 1, "wrecking a rival's tail rotor counts")


func test_camo_reaches_the_hull() -> void:
	var c := Choppa.new()
	c.camo = "tiger"
	_world.add_child(c)
	var hull := (c.model.find_child("body", true, false) as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	_check(hull.get_shader_parameter("pattern") == Progression.CAMOS.tiger.pattern, "the hull wears the tiger pattern")
	c.model.set_camo("apex")
	_check(hull.get_shader_parameter("seam_glow") > 0.0, "apex lights the seams")


func test_every_sound_exists_and_loops_loop() -> void:
	# Every name the game plays, so a typo or a missing file fails here, not in a match.
	var used := {}
	var re := RegEx.create_from_string(r'Sounds\.(?:play_at|play_on|play_ui|loop_on|play_on_returning)\([^"]*"([a-z_]+)"')
	for path in ["res://scripts/"]:
		for file in DirAccess.get_files_at(path):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(path + file)
			for m in re.search_all(text):
				used[m.get_string(1)] = file
	_check(used.size() >= 12, "found the sound calls, %d" % used.size())
	for name: String in used:
		var found := ResourceLoader.exists("res://assets/sounds/%s.wav" % name) or Sounds._take_count(name) > 0
		_check(found, "%s.wav (or %s_1.wav ...) exists (used in %s)" % [name, name, used[name]])
	for track in ["menu", "techno"]:
		var stream := Sounds.stream("music_%s_loop" % track) as AudioStreamOggVorbis
		_check(stream != null and stream.loop, "music %s loops" % track)
	for name in ["rotor_loop", "engine_loop", "boost_loop", "missile_loop", "warning_loop", "wind_loop"]:
		_check((Sounds.stream(name) as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % name)


func test_wrecking_a_part_tells_the_shooter_and_shows() -> void:
	var shooter := _choppa(Vector3(0.0, 30.0, 0.0))
	var target := _choppa(Vector3(0.0, 30.0, -40.0))
	var told := []
	shooter.wrecked_part.connect(func(who: Choppa, part: Choppa.Part) -> void: told.append([who, part]))
	target.damage_part(Choppa.Part.TAIL, 999.0, shooter)
	target.damage_part(Choppa.Part.TAIL, 10.0, shooter)  # Already wrecked: no second report.
	_check(told == [[target, Choppa.Part.TAIL]], "the shooter heard once, got %s" % [told])
	target.model.update_pose(target, TICK)
	var tail := target.model.find_child("tail_rotor", true, false) as Node3D
	_check(tail != null and not tail.visible, "the wrecked tail rotor is gone from the model")
	target.repair(1.0)
	target.model.update_pose(target, TICK)
	_check(tail.visible, "and back after a repair")


## The same inputs from the same start give exactly the same flight, crash included.
func test_replay_is_deterministic() -> void:
	var inputs := []
	for t in 400:
		var i := PilotInput.new()
		i.cyclic = Vector2(sin(t * 0.03) * 0.6, 0.5 if t < 200 else -0.3)
		i.collective = 0.3 if t < 120 else -0.4
		i.yaw = cos(t * 0.02) * 0.5
		inputs.append(i)
	var ends := []
	for run in 2:
		var world := Node3D.new()
		_world.add_child(world)
		MapKit.block(world, Vector3(0.0, -1.0, 0.0), Vector3(400.0, 2.0, 400.0), Color.GRAY)
		MapKit.block(world, Vector3(0.0, 10.0, -60.0), Vector3(80.0, 40.0, 2.0), Color.GRAY)
		var c := Choppa.new()
		world.add_child(c)
		c.respawn(Transform3D(Basis(), Vector3(0.0, 10.0, 0.0)))
		c.invulnerable = 0.0
		c.set_physics_process(false)
		for t in 400:
			c.input.copy_from(inputs[t])
			await physics_frame
			c.step(TICK)
		ends.append([c.global_transform, c.velocity, c.health])
		world.queue_free()
		await physics_frame
	_check(ends[0][0].is_equal_approx(ends[1][0]) and ends[0][1].is_equal_approx(ends[1][1]),
		"identical runs end in the same place: %s vs %s" % [ends[0][0].origin, ends[1][0].origin])
	_check(ends[0][2] == ends[1][2], "and with the same damage, %f vs %f" % [ends[0][2], ends[1][2]])


## A server and a client in one process: two physics worlds (SubViewports) and two
## multiplayer instances, talking over ENet on localhost. Returns {server, client,
## seat (the server's choppa the client flies), other (a server choppa), own, remote}.
func _net_pair(lag_ms := 0.0, loss := 0.0) -> Dictionary:
	var port := 20000 + randi() % 20000
	var sides := {}
	for side in ["server", "client"]:
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.name = side
		_world.add_child(vp)
		var world := Node3D.new()
		vp.add_child(world)
		MapKit.block(world, Vector3(0.0, -1.0, 0.0), Vector3(600.0, 2.0, 600.0), Color.GRAY)
		set_multiplayer(SceneMultiplayer.new(), vp.get_path())
		var net := NetGame.new()
		net.name = "Net"
		net.lag_ms = lag_ms
		net.loss = loss
		vp.add_child(net)
		sides[side] = {"vp": vp, "world": world, "net": net}
	var spawns: Array[Transform3D] = [Transform3D(Basis(), Vector3(0.0, 10.0, 0.0)), Transform3D(Basis(), Vector3(40.0, 10.0, 0.0))]
	var field: Array[Choppa] = []
	for k in 2:
		var c := Choppa.new()
		c.pilot_name = "S%d" % k
		sides.server.world.add_child(c)
		c.respawn(spawns[k])
		c.invulnerable = 0.0
		field.append(c)
	var battle := Battle.new()
	sides.server.world.add_child(battle)
	battle.setup(field, spawns, 5)
	var server: NetGame = sides.server.net
	server.battle = battle
	server.pilots = field
	var placeholder := Node.new()
	sides.server.world.add_child(placeholder)
	server.bots = {field[0]: placeholder}
	server.welcome_info = {"map": "test", "kills": 5}
	_check(server.host(port) == OK, "server listens on %d" % port)
	var client: NetGame = sides.client.net
	var welcome := []
	client.welcomed.connect(func(info: Dictionary) -> void: welcome.append(info))
	var flight := {"easy": false, "assists": Choppa.ASSIST_LANDING | Choppa.ASSIST_START}
	_check(client.join("127.0.0.1", port, {"name": "Tester", "airframe": Airframe.GUNSHIP, "flight": flight}) == OK,
		"client connects")
	for t in 240:
		await physics_frame
		if not welcome.is_empty():
			break
	_check(not welcome.is_empty(), "the server welcomed the client")
	if welcome.is_empty():
		return {}
	var info: Dictionary = welcome[0]
	_check(field[info.seat].assists == flight.assists, "the server flies the seat with the client's assists")
	var mine: Array[Choppa] = []
	for k in info.roster.size():
		var r: Dictionary = info.roster[k]
		var c := Choppa.new()
		c.pilot_name = r.name
		c.airframe = r.airframe
		c.local_player = k == info.seat
		if k == info.seat:
			c.assists = flight.assists
		sides.client.world.add_child(c)
		c.respawn(spawns[k])
		mine.append(c)
	var mirror := Battle.new()
	sides.client.world.add_child(mirror)
	mirror.setup(mine, spawns, int(info.kills))
	client.attach(mine, info.seat, mirror, [] as Array[ServiceStation])
	return {"server": server, "client": client, "seat": field[info.seat], "other": field[1 - info.seat],
		"own": mine[info.seat], "remote": mine[1 - info.seat], "info": info, "battle": battle, "mirror": mirror}


func _net_fly(pair: Dictionary, ticks: int, own_input: Callable, other_input := Callable()) -> void:
	for t in ticks:
		own_input.call(pair.own.input, t)
		if other_input.is_valid():
			other_input.call(pair.other.input, t)
		await physics_frame


func _net_close(pair: Dictionary) -> void:
	pair.client.stop()
	pair.server.stop()
	await physics_frame
	for net: NetGame in [pair.client, pair.server]:
		net.get_parent().queue_free()
	await physics_frame


func test_net_client_predicts_and_server_agrees() -> void:
	var pair := await _net_pair()
	if pair.is_empty():
		return
	_check(pair.info.seat == 0 and pair.seat.pilot_name == "Tester", "took the free seat as Tester")
	_check(pair.seat.airframe == Airframe.GUNSHIP, "in the helicopter it asked for")
	var fly := func(i: PilotInput, t: int) -> void:
		i.cyclic = Vector2(0.0, 0.6 if t < 40 else 0.0)
		i.collective = 0.4 if t < 90 else 0.0
	var other := func(i: PilotInput, t: int) -> void: i.yaw = 0.5 if t < 60 else 0.0
	await _net_fly(pair, 150, fly, other)
	await _net_fly(pair, 90, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(pair.seat.global_position.distance_to(Vector3(0.0, 10.0, 0.0)) > 8.0, "the server flew our inputs, at %s" % pair.seat.global_position)
	var gap: float = pair.own.global_position.distance_to(pair.seat.global_position)
	_check(gap < 1.5, "our prediction matches the server within 1.5 m, gap %.2f m" % gap)
	var remote_gap: float = pair.remote.global_position.distance_to(pair.other.global_position)
	_check(remote_gap < 2.0, "the other choppa is drawn where the server has it, gap %.2f m" % remote_gap)
	_check(pair.client.corrections < 20, "few corrections without lag, %d" % pair.client.corrections)
	await _net_close(pair)


func test_net_survives_lag_and_loss() -> void:
	var pair := await _net_pair(120.0, 0.05)
	if pair.is_empty():
		return
	var fly := func(i: PilotInput, t: int) -> void:
		i.cyclic = Vector2(0.3 * sin(t * 0.05), 0.5 if t < 60 else 0.0)
		i.collective = 0.3 if t < 100 else 0.0
	await _net_fly(pair, 180, fly)
	await _net_fly(pair, 120, func(i: PilotInput, _t: int) -> void: i.clear())
	var gap: float = pair.own.global_position.distance_to(pair.seat.global_position)
	_check(gap < 2.0, "at 120 ms and 5 percent loss our choppa still ends where the server has it, gap %.2f m" % gap)
	_check(pair.seat.global_position.distance_to(Vector3(0.0, 10.0, 0.0)) > 5.0, "and the server got our inputs")
	await _net_close(pair)


func test_net_server_owns_damage_and_kills() -> void:
	var pair := await _net_pair()
	if pair.is_empty():
		return
	pair.own.damage(50.0, null)
	_check(pair.own.health == pair.own.max_health, "a client cannot damage itself")
	pair.seat.damage(30.0, pair.other)
	await _net_fly(pair, 10, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(is_equal_approx(pair.own.health, pair.seat.health), "the server's damage reaches us, %f vs %f" % [pair.own.health, pair.seat.health])
	var kills := []
	pair.mirror.kill.connect(func(killer: Choppa, victim: Choppa) -> void: kills.append([killer, victim]))
	pair.seat.damage(500.0, pair.other)
	await _net_fly(pair, 10, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(kills == [[pair.remote, pair.own]], "the kill feed says the other one shot us down, got %s" % [kills])
	_check(not pair.own.alive and pair.mirror.kills_of(pair.remote) == 1, "we are down and they have the kill")
	await _net_fly(pair, 60 * 4, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(pair.own.alive and pair.seat.alive, "and back after the respawn")
	await _net_close(pair)


func test_net_leaving_hands_the_seat_to_a_bot() -> void:
	var pair := await _net_pair()
	if pair.is_empty():
		return
	var made := []
	pair.server.bot_factory = func(c: Choppa) -> Node:
		var bot := Node.new()
		c.add_child(bot)
		made.append(c)
		return bot
	_check(pair.server.players() == PackedStringArray(["Tester"]), "the server lists us, %s" % pair.server.players())
	pair.client.stop()
	for t in 180:
		await physics_frame
		if not made.is_empty():
			break
	_check(made == [pair.seat] and pair.server.bots.has(pair.seat), "a bot took our seat back")
	_check(pair.seat.pilot_name == "Bot Tester", "under our name, %s" % pair.seat.pilot_name)
	_check(pair.server.players().is_empty(), "and nobody is listed any more")
	await _net_close(pair)


## The server starts the next round by itself after ROUND_BREAK; both sides reset, and
## our XP for the round arrives before the round ends on our side.
func test_net_rounds_follow_each_other() -> void:
	var pair := await _net_pair()
	if pair.is_empty():
		return
	var got := []
	pair.client.xp_received.connect(func(stats: Dictionary) -> void: got.append(["xp", stats]))
	pair.mirror.match_over.connect(func() -> void: got.append(["over"]))
	var restarted := []
	pair.mirror.restarted.connect(func() -> void: restarted.append(true))
	pair.other.damage(500.0, pair.seat)  # We shoot the other one down...
	await _net_fly(pair, 10, func(i: PilotInput, _t: int) -> void: i.clear())
	pair.battle.time_left = 0.05  # ...and the clock runs out.
	await _net_fly(pair, 20, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(pair.battle.over and pair.mirror.over, "the round ended on both sides")
	_check(got.size() == 2 and got[0][0] == "xp" and got[1][0] == "over", "XP first, then the end, got %s" % [got])
	if got.size() == 2:
		_check(got[0][1].kill == 1 and got[0][1].won, "with our kill and the win, %s" % got[0][1])
	await _net_fly(pair, roundi(NetGame.ROUND_BREAK * 60.0) + 20, func(i: PilotInput, _t: int) -> void: i.clear())
	_check(not pair.battle.over and not pair.mirror.over and restarted.size() == 1, "a new round began by itself")
	_check(pair.mirror.kills_of(pair.own) == 0 and pair.battle.kills_of(pair.seat) == 0, "with the scores back at zero")
	_check(pair.own.alive and pair.remote.alive, "and everyone flying")
	await _net_close(pair)


func test_gun_runs_dry_and_a_restock_fills_it() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	_check(choppa.ammo.gun == choppa.full_ammo("gun") and choppa.ammo.gun > 100, "a full belt, %d rounds" % choppa.ammo.gun)
	choppa.ammo.gun = 5
	await _fly(choppa, 60, _hold_fire)
	_check(choppa.ammo.gun == 0, "fired the last rounds")
	var fired := _bullets().size()
	await _fly(choppa, 20, _hold_fire)
	_check(_bullets().size() <= fired, "and then nothing comes out")
	choppa.restock()
	_check(choppa.ammo.gun == choppa.full_ammo("gun"), "a restock fills the belt")


func test_ammo_station_rearms_but_does_not_repair() -> void:
	var station := _station_on_ground(true)
	var choppa := _choppa(Vector3(0.0, station.pad_top() + Choppa.GROUND_CLEARANCE + 0.5, 0.0))
	choppa.damage(40.0, null)
	choppa.ammo.gun = 0
	choppa.ammo.rockets = 0
	var served := []
	station.served.connect(func(c: Choppa) -> void: served.append(c))
	var hurt := choppa.health
	for t in 60 * 4:
		choppa.input.collective = -0.2
		await physics_frame
		choppa.step(TICK)
		station.tick(TICK)
	_check(served == [choppa], "rearmed once, got %s" % [served])
	_check(not choppa.needs_ammo(), "with a full loadout, gun %d" % choppa.ammo.gun)
	_check(choppa.health == hurt, "but no repairs, hp=%f" % choppa.health)
	_check(station.cooldown > 0.0 and station.cooldown <= ServiceStation.AMMO_COOLDOWN, "and back soon, in %.0f s" % station.cooldown)


## Cold barrels group tightly; hot ones spray. The pattern is fixed, not random, so a
## network client and the server agree.
func test_gun_spread_blooms_with_heat() -> void:
	var spreads := []
	for hot in [0.0, 0.9]:
		var choppa := _choppa(Vector3(0.0, 40.0, 0.0))
		var worst := 0.0
		for k in 12:
			choppa.heat = hot
			choppa._shoot()
		for b: Bullet in _bullets():
			if b.shooter == choppa:
				worst = maxf(worst, b.direction.angle_to(-choppa.global_transform.basis.z))
		spreads.append(worst)
		for b: Bullet in _bullets():
			b.free()
		choppa.free()
	_check(spreads[0] < 0.004, "cold: tight, %.4f rad" % spreads[0])
	_check(spreads[1] > 0.012 and spreads[1] < 0.03, "hot: wider, %.4f rad" % spreads[1])


## `*_loop` sounds loop even when their import settings forgot to; sounds without
## numbered takes play their single file.
func test_loops_loop_and_takes_are_counted() -> void:
	var rotor := Sounds.stream("rotor_loop") as AudioStreamWAV
	_check(rotor != null and rotor.loop_mode != AudioStreamWAV.LOOP_DISABLED, "the rotor loops")
	_check(Sounds._take_count("hit_marker") == 0 and Sounds.stream("hit_marker") != null, "a sound without takes plays its one file")
	_check(Sounds.stream("gun") != null and Sounds.stream("gun_tail") != null, "the gun and its tail play, recorded or stand-in")
	_check(Sounds._take_count("no_such_sound") == 0, "no takes of a missing sound")


## A new track fades in after the old one fades out, at the music level.
func test_music_crossfades_between_tracks() -> void:
	Sounds.music(self, "menu")
	for t in 120:
		await process_frame
	_check(Sounds._music.playing and Sounds._music.stream.resource_path.contains("menu"), "the menu music plays")
	Sounds.music(self, "techno")
	for t in 20:
		await process_frame
	_check(Sounds._music.volume_db < Sounds.MUSIC_DB - 3.0 or Sounds._music.stream.resource_path.contains("techno"),
		"the menu music fades out first")
	for t in 200:
		await process_frame
	_check(Sounds._music.stream.resource_path.contains("techno") and is_equal_approx(Sounds._music.volume_db, Sounds.MUSIC_DB),
		"then the techno plays at full level, %.1f dB" % Sounds._music.volume_db)
	Sounds.music(self, "")
	for t in 120:
		await process_frame
	_check(not Sounds._music.playing, "and stops")


## A cold choppa on the ground: no lift without the engine; throttle up starts it, and
## it only lifts off once the rotor has spooled up.
func test_cold_start_spools_up_before_lift() -> void:
	_ground()
	var c := _choppa(Vector3.ZERO)
	c.spawn_on_ground(Transform3D(), true)
	var start := c.global_position.y
	await _fly(c, 60)
	_check(not c.engine_on and c.spool == 0.0, "the engine stays off by itself")
	_check(absf(c.global_position.y - start) < 0.2, "and the choppa sits on its skids")
	await _fly(c, 60, func(i: PilotInput, _t: int) -> void: i.collective = 1.0)
	_check(c.engine_on, "throttle up starts the engine")
	_check(c.global_position.y - start < 0.5, "but one second in, the rotor is still too slow to lift, %.2f m" % (c.global_position.y - start))
	await _fly(c, 60 * 4, func(i: PilotInput, _t: int) -> void: i.collective = 1.0)
	_check(c.spool == 1.0 and c.global_position.y - start > 5.0, "spooled up and climbing, %.1f m" % (c.global_position.y - start))


## The engine key switches the engine off in the air: you come down. Again: it restarts.
func test_engine_key_toggles_and_off_sinks() -> void:
	for easy in [false, true]:
		var c := _choppa(Vector3(0.0, 80.0, 0.0))
		c.easy = easy
		await _fly(c, 30)
		await _fly(c, 2, func(i: PilotInput, _t: int) -> void: i.engine = true)
		_check(not c.engine_on, "easy=%s: the key switched it off" % easy)
		await _fly(c, 60 * 3, func(i: PilotInput, _t: int) -> void: i.engine = false)
		_check(c.global_position.y < 76.0 and c.velocity.y < -2.0, "easy=%s: coming down, %.1f m at %.1f m/s" % [easy, c.global_position.y, c.velocity.y])
		await _fly(c, 2, func(i: PilotInput, _t: int) -> void: i.engine = true)
		_check(c.engine_on, "easy=%s: and on again" % easy)
		c.free()


## Easy model, the real keys: C dives and does nothing else (it used to fly you
## backwards too, because the forward/back keys shared it).
func test_easy_dive_key_only_dives() -> void:
	_ground()
	var c := Choppa.new()
	c.easy = true
	_world.add_child(c)
	c.respawn(Transform3D(Basis(), Vector3(0.0, 30.0, 0.0)))
	var pilot := LocalPilot.new()
	pilot.choppa = c
	_world.add_child(pilot)
	for t in 20:
		await physics_frame
	Input.action_press("vertical_down")
	for t in 60:
		await physics_frame
	Input.action_release("vertical_down")
	_check(c.global_position.y < 22.0, "C dives, now at %.1f m" % c.global_position.y)
	_check(Vector2(c.global_position.x, c.global_position.z).length() < 1.0, "and does not drive anywhere, %s" % c.global_position)
	pilot.free()
	c.free()


## Every battle map: each spawn point is on the ground, above water, with room for a
## choppa (no rock, tree or prop in the way).
func test_spawns_are_on_dry_clear_ground() -> void:
	for entry: Array in GameMap.catalog():
		var map := GameMap.create(entry[1])
		map.mode = "battle"
		_world.add_child(map)
		await physics_frame
		await physics_frame
		var space := _world.get_world_3d().direct_space_state
		var ball := SphereShape3D.new()
		ball.radius = 2.6
		var bad := []
		for t: Transform3D in map.spawn_points:
			var down := PhysicsRayQueryParameters3D.create(t.origin + Vector3.UP * 5.0, t.origin + Vector3.DOWN * 5.0)
			var hit := space.intersect_ray(down)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = ball
			query.transform = Transform3D(Basis(), t.origin + Vector3.UP * 3.2)
			var blocked := space.intersect_shape(query, 4)
			if hit.is_empty() or absf((hit.position as Vector3).y - t.origin.y) > 0.6 or (hit.collider as Node).is_in_group("water") \
					or not blocked.is_empty():
				bad.append(t.origin)
		_check(bad.is_empty(), "%s: every spawn on dry, clear ground; bad: %s" % [entry[1], bad])
		map.free()
		await physics_frame


## The scout darts, the heavy wallows: turn, climb, engine start and gun all differ
## clearly between the classes (owner: the difference should be feelable).
func test_classes_feel_apart() -> void:
	var turned := {}
	var climbed := {}
	for id: String in Airframe.ORDER:
		var c := _choppa(Vector3(0.0, 40.0, 0.0))
		c.set_airframe(id)
		var start_heading := c.heading
		var start_y := c.global_position.y
		await _fly(c, 60, func(i: PilotInput, _t: int) -> void:
			i.yaw = 1.0
			i.collective = 1.0)
		turned[id] = absf(angle_difference(start_heading, c.heading))
		climbed[id] = c.global_position.y - start_y
		c.free()
	_check(turned.scout > turned.gunship * 1.15 and turned.gunship > turned.heavy * 1.15,
		"turn in a second: %s" % [turned])
	_check(climbed.scout > climbed.heavy * 1.3, "climb in a second: %s" % [climbed])
	var scout := Airframe.spec(Airframe.SCOUT)
	var heavy := Airframe.spec(Airframe.HEAVY)
	_check(scout.spool < heavy.spool and scout.fire < heavy.fire and scout.guns < heavy.guns,
		"the scout starts and fires faster, the heavy hits harder per round")


## The radio: CHOPPA FM first, off last; N cycles through and the choice is kept.
func test_radio_stations_cycle() -> void:
	var saved: int = Settings.value("radio_station")
	var all := Radio.stations()
	_check(all[0].name == Radio.BUILT_IN and all[-1].name == Radio.OFF, "built in first, off last: %s" % [all.map(func(s: Dictionary) -> String: return s.name)])
	Settings.set_value("radio_station", 0)
	Radio.play(self)
	for t in 100:
		await process_frame
	_check(Sounds._music.playing and Sounds._music.stream.resource_path.contains("techno"), "CHOPPA FM plays the techno")
	var seen := []
	for k in all.size():
		seen.append(Radio.next_station(self))
	_check(seen[-1] == "RADIO  ·  " + Radio.BUILT_IN and seen.has(Radio.OFF), "round the dial and back: %s" % [seen])
	Settings.set_value("radio_station", saved)
	Sounds.music(self, "")


## A wrecked tail rotor spins a normal choppa round; the coaxial Striker has none to
## lose and keeps its heading.
func test_coaxial_striker_shrugs_off_tail_hits() -> void:
	var spun := {}
	for id: String in [Airframe.GUNSHIP, Airframe.STRIKER]:
		var c := _choppa(Vector3(0.0, 50.0, 0.0))
		c.set_airframe(id)
		c.parts[Choppa.Part.TAIL] = 0.0
		var start := c.heading
		await _fly(c, 120)
		spun[id] = absf(angle_difference(start, c.heading))
		c.free()
	_check(spun.gunship > 1.0, "the gunship spins without its tail rotor, %.2f rad" % spun.gunship)
	_check(spun.striker < 0.1, "the striker holds its heading, %.2f rad" % spun.striker)


## Owner: environment hits must hurt like a real crash. 12 m/s into a wall scrapes the
## paint, 25 nearly kills, 35 kills any class.
func test_wall_crashes_scale_with_speed() -> void:
	var left := {}
	for speed: float in [12.0, 25.0, 35.0]:
		var x := speed * 10.0
		MapKit.block(_world, Vector3(x, 30.0, -20.0), Vector3(20.0, 60.0, 2.0), Color.GRAY)
		var choppa := _choppa(Vector3(x, 30.0, -8.0))
		choppa.set_airframe(Airframe.HEAVY)  # The toughest hull.
		choppa.velocity = Vector3(0.0, 0.0, -speed)
		await _fly(choppa, 90)
		left[speed] = choppa.health / choppa.max_health if choppa.alive else 0.0
	_check(left[12.0] > 0.6 and left[12.0] < 1.0, "12 m/s costs a little, %s" % [left])
	_check(left[25.0] > 0.0 and left[25.0] < 0.4, "25 m/s nearly kills, %s" % [left])
	_check(left[35.0] == 0.0, "35 m/s kills even the heavy, %s" % [left])


## Blades into a wall: the rotor takes the hit, the choppa is shoved away, and a wrecked
## rotor that strikes again comes apart. In a race the blades are only paint.
func test_rotor_strike_wrecks_the_rotor() -> void:
	MapKit.block(_world, Vector3(4.0, 30.0, 0.0), Vector3(2.0, 60.0, 40.0), Color.GRAY)
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))  # Body 2 m clear of the wall, the blades not.
	await _fly(choppa, 2)
	_check(choppa.parts[Choppa.Part.ROTOR] < choppa.part_max(Choppa.Part.ROTOR), "the rotor took the strike")
	_check(choppa.velocity.x < -1.0, "shoved away from the wall, v=%s" % choppa.velocity)
	_check(choppa.alive, "one strike is survivable")
	for t in 3:
		choppa.global_position = Vector3(0.0, 30.0, 0.0)
		choppa._strike_cooldown = 0.0
		await _fly(choppa, 1)
	_check(not choppa.alive, "a wrecked rotor striking again comes apart")
	var racer := _choppa(Vector3(0.0, 30.0, 10.0))
	racer.mortal = false
	await _fly(racer, 2)
	_check(racer.velocity.length() < 0.5, "races ignore rotor strikes, v=%s" % racer.velocity)


## On its side on the ground, it burns out after a couple of seconds.
func test_rollover_burns_out() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 1.2, 0.0))
	choppa.engine_on = false
	choppa.spool = 0.0  # No blades turning: only the rollover can do it.
	choppa.global_transform.basis = Basis(Vector3.FORWARD, PI * 0.5)
	await _fly(choppa, 60)
	_check(choppa.alive, "not at once")
	await _fly(choppa, 90)
	_check(not choppa.alive, "burned out on its side, up=%f" % choppa.global_transform.basis.y.y)


## Hands off the stick: auto-level rights a banked choppa; auto-hover also kills the drift.
func test_assists_level_and_hover() -> void:
	var leveled := _choppa(Vector3(0.0, 60.0, 0.0))
	leveled.assists = Choppa.ASSIST_LEVEL
	leveled.global_transform.basis = Basis(Vector3.FORWARD, 0.5)
	await _fly(leveled, 120)
	_check(absf(leveled.bank_right()) < 0.05, "auto-level: level again, bank %.2f" % leveled.bank_right())
	var bare := _choppa(Vector3(100.0, 60.0, 0.0))
	bare.assists = 0
	bare.global_transform.basis = Basis(Vector3.FORWARD, 0.5)
	await _fly(bare, 120)
	_check(absf(bare.bank_right()) > 0.4, "without it the bank stays, %.2f" % bare.bank_right())
	var hover := _choppa(Vector3(200.0, 60.0, 0.0))
	hover.assists = Choppa.ASSIST_HOVER
	hover.velocity = Vector3(15.0, 0.0, -15.0)
	await _fly(hover, 420)
	var drift := Vector2(hover.velocity.x, hover.velocity.z).length()
	_check(drift < 2.0, "auto-hover brakes to a stop, %.1f m/s left" % drift)


## Collective centred: altitude hold keeps the height even nosed down at speed.
func test_assist_altitude_hold() -> void:
	var sinks := {}
	for bits: int in [0, Choppa.ASSIST_ALTITUDE]:
		var c := _choppa(Vector3(bits * 30.0, 80.0, 0.0))
		c.assists = bits
		await _fly(c, 180, func(i: PilotInput, t: int) -> void: i.cyclic.y = 0.6 if t < 35 else 0.0)
		sinks[bits] = 80.0 - c.global_position.y
	_check(sinks[0] > 4.0, "a tilted rotor loses height by itself, %.1f m" % sinks[0])
	_check(absf(sinks[Choppa.ASSIST_ALTITUDE]) < 1.5, "altitude hold keeps it, %.1f m" % sinks[Choppa.ASSIST_ALTITUDE])


## Pedals centred: with coordinated turns a bank swings the nose round.
func test_assist_coordinated_turn() -> void:
	var turned := {}
	for bits: int in [0, Choppa.ASSIST_TURN]:
		var c := _choppa(Vector3(bits * 20.0, 60.0, 0.0))
		c.assists = bits
		c.global_transform.basis = Basis(Vector3.FORWARD, 0.4)  # Banked right.
		var start := c.heading
		await _fly(c, 60)
		turned[bits] = angle_difference(start, c.heading)
	_check(absf(turned[0]) < 0.05, "no assist, no turn: %.2f" % turned[0])
	_check(turned[Choppa.ASSIST_TURN] < -0.2, "a right bank turns right: %.2f" % turned[Choppa.ASSIST_TURN])


## Landing assist: a dive at the ground with the collective down still sets down whole.
func test_assist_landing_cushions() -> void:
	_ground()
	var left := {}
	for bits: int in [0, Choppa.ASSIST_LANDING]:
		var c := _choppa(Vector3(bits * 20.0, 12.0, 0.0))
		c.assists = bits
		c.velocity = Vector3(0.0, -11.0, 0.0)
		await _fly(c, 120, func(i: PilotInput, _t: int) -> void: i.collective = -1.0)
		left[bits] = c.health if c.alive else 0.0
	_check(left[0] < Choppa.MAX_HEALTH * 0.5, "without it the skids give, hp %s" % [left])
	_check(left[Choppa.ASSIST_LANDING] == Choppa.MAX_HEALTH, "with it a clean touchdown, hp %s" % [left])


## Engine auto-start off: power on the ground does nothing, the key starts it.
func test_assist_auto_start_can_be_off() -> void:
	_ground()
	var c := Choppa.new()
	_world.add_child(c)
	c.set_physics_process(false)
	c.spawn_on_ground(Transform3D.IDENTITY, true)
	c.assists = 0
	await _fly(c, 30, func(i: PilotInput, _t: int) -> void: i.collective = 1.0)
	_check(not c.engine_on, "power alone does not start it")
	await _fly(c, 2, func(i: PilotInput, _t: int) -> void: i.engine = true)
	_check(c.engine_on, "the key does")


## Keys: the roll rate setting scales a full key press, and the ramp eases into it.
func test_key_rates_and_ramp() -> void:
	var saved := [Settings.value("roll_rate"), Settings.value("stick_ramp"), Settings.value("mouse_mode")]
	Settings.set_value("roll_rate", 0.5)
	Settings.set_value("stick_ramp", 0.25)
	Settings.set_value("mouse_mode", 0)
	var c := _choppa(Vector3(0.0, 60.0, 0.0))
	var pilot := LocalPilot.new()
	pilot.choppa = c
	_world.add_child(pilot)
	Input.action_press("roll_right")
	await physics_frame
	await physics_frame
	var early := c.input.cyclic.x
	for t in 30:
		await physics_frame
	var held := c.input.cyclic.x
	Input.action_release("roll_right")
	_check(early > 0.0 and early < 0.2, "the stick eases in, %.2f after two ticks" % early)
	_check(is_equal_approx(held, 0.5), "and stops at the roll rate setting, %.2f" % held)
	Settings.set_value("roll_rate", saved[0])
	Settings.set_value("stick_ramp", saved[1])
	Settings.set_value("mouse_mode", saved[2])
	pilot.free()


## Rebinding: a new key works at once, a clashing key moves, and defaults come back.
func test_rebinding_keys() -> void:
	var controls: GDScript = load("res://scripts/controls.gd")
	var key := func(code: Key) -> InputEventKey:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = true
		return e
	controls.rebind("fire", 0, KEY_J)
	_check(InputMap.action_has_event("fire", key.call(KEY_J)), "J fires now")
	_check(not InputMap.action_has_event("fire", key.call(KEY_CTRL)), "Ctrl no longer does")
	_check(controls.keys_for("fire")[0] == "J", "the overlay says J: %s" % [controls.keys_for("fire")])
	var lost: Array = controls.rebind("missile", 0, KEY_X)
	_check(lost.has("flares") and controls.keys_for("flares").is_empty(), "X moved from flares to the missile: %s" % [lost])
	controls.rebind("move_forward", 0, KEY_UP)
	_check(controls.keys_for("pitch_down").has("Up"), "the easy model's keys do not steal the realistic one's")
	Settings.set_value("bindings", {})
	controls.apply_bindings()
	_check(InputMap.action_has_event("fire", key.call(KEY_CTRL)) and not InputMap.action_has_event("fire", key.call(KEY_J)),
		"defaults back after a reset")
	_check(InputMap.action_has_event("flares", key.call(KEY_X)), "flares on X again")


## Owner: "each helicopter's cockpit should be individual". Every class loads its own
## interior with a frame, controls, a sight dead ahead and live instruments; the glass
## cockpits have their displays.
func test_every_class_has_its_own_cockpit() -> void:
	var seen := {}
	for id: String in Airframe.ORDER:
		var shell := Cockpit.shell(id)
		var meshes := shell.find_children("*", "MeshInstance3D", true, false)
		var tris := 0
		for m: MeshInstance3D in meshes:
			tris += m.mesh.get_faces().size() / 3
		seen[tris] = id
		for part in ["shell", "frame", "stick", "collective", "mount_sight", "mount_speed", "mount_altitude",
				"mount_health", "mount_item", "mount_kills", "mount_beacon", "mount_lamp_missile", "mount_lamp_lock"]:
			_check(shell.find_child(part) != null, "%s cockpit has %s" % [id, part])
		var sight := shell.find_child("mount_sight") as Node3D
		if sight:
			_check(absf(sight.position.x) < 0.01 and absf(sight.position.y) < 0.01 and sight.position.z < -0.3,
				"%s: the sight is dead ahead of the eye, %s" % [id, sight.position])
		var screens := shell.find_children("mount_mfd_*", "", true, false).size()
		if id in [Airframe.GUNSHIP, Airframe.STRIKER]:
			_check(screens >= 2, "%s is a glass cockpit, %d displays" % [id, screens])
		shell.free()
	_check(seen.size() == Airframe.ORDER.size(), "four different interiors: %s" % [seen])
	# The live instruments build on every one, displays included.
	for id: String in Airframe.ORDER:
		var c := _choppa(Vector3(0.0, 40.0, 0.0))
		var cockpit := Cockpit.new()
		cockpit.choppa = c
		cockpit.airframe = id
		_world.add_child(cockpit)
		await process_frame
		_check(cockpit.reticle != null and not cockpit._gauges.is_empty(), "%s: instruments built, %s" % [id, cockpit._gauges.keys()])
		cockpit.free()
