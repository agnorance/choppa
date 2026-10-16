extends SceneTree
## Headless test runner:
##   godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd
## --fixed-fps lets physics run as fast as the CPU allows instead of in real time.
## Each test builds a tiny world, flies a choppa with scripted input and checks the result.

const TICK := 1.0 / 60.0

var _failures := 0
var _world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for test in [
		"test_neutral_input_hovers",
		"test_forward_input_flies_forward",
		"test_yaw_right_turns_right",
		"test_cannot_dive_through_ground",
		"test_boost_is_faster_and_drains_meter",
		"test_barrel_roll_dashes_sideways_and_rewards_boost",
		"test_low_trick_rewards_double",
		"test_180_snap_reverses_heading_and_keeps_speed",
		"test_wall_hit_bounces_and_stuns",
		"test_turbo_item",
		"test_item_box_gives_item_and_respawns",
		"test_item_roll_only_returns_known_items",
		"test_gun_fires_and_overheats",
		"test_gun_cools_down_after_overheat",
		"test_bullets_knock_target_back",
		"test_aim_assist_hits_target_above",
		"test_barrel_roll_dodges_bullets",
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
		"test_health_crate_heals",
		"test_terrain_collision_matches_mesh",
		"test_bots_battle_in_arena",
		"test_missile_homes_and_hits",
		"test_barrel_roll_shakes_off_missile",
		"test_mine_arms_then_explodes",
		"test_fake_item_box_explodes",
		"test_smoke_blocks_lock_on",
		"test_scrambler_hits_the_leader",
		"test_shield_absorbs_damage",
		"test_get_to_the_choppa",
		"test_effects_start_where_placed",
		"test_grass_only_on_flat_dry_ground",
		"test_canopy_cracks_follow_damage",
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


func test_forward_input_flies_forward() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	await _fly(choppa, 120, func(i: PilotInput, _t: int) -> void: i.move = Vector2(0.0, 1.0))
	_check(choppa.global_position.z < -30.0, "moved along -Z, z=%f" % choppa.global_position.z)
	_check(absf(choppa.global_position.x) < 0.1, "no sideways drift")
	_check(absf(choppa.velocity.length() - choppa.max_speed) < 1.0, "reached top speed")


func test_yaw_right_turns_right() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	await _fly(choppa, 30, func(i: PilotInput, _t: int) -> void: i.yaw = 1.0)
	# Turning right from facing -Z means the forward vector gains +X.
	_check((choppa.facing() * Vector3.FORWARD).x > 0.3, "turned right, heading=%f" % choppa.heading)


func test_cannot_dive_through_ground() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 4.0, 0.0))
	await _fly(choppa, 120, func(i: PilotInput, _t: int) -> void: i.lift = -1.0)
	_check(choppa.global_position.y > 0.9, "stopped on ground, y=%f" % choppa.global_position.y)
	_check(choppa.altitude < 0.2, "altitude near zero, alt=%f" % choppa.altitude)


func test_boost_is_faster_and_drains_meter() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	choppa.boost_meter = 1.0
	await _fly(choppa, 120, func(i: PilotInput, _t: int) -> void: i.boost = true)
	_check(choppa.velocity.length() > choppa.max_speed + 10.0, "faster than cruise, v=%f" % choppa.velocity.length())
	_check(choppa.boost_meter < 0.4, "meter drained, meter=%f" % choppa.boost_meter)


func test_barrel_roll_dashes_sideways_and_rewards_boost() -> void:
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	choppa.boost_meter = 0.0
	var landed := []
	choppa.trick_landed.connect(func(trick_name: String, _r: float, low: bool) -> void: landed.append([trick_name, low]))
	await _fly(choppa, 60, func(i: PilotInput, t: int) -> void:
		i.trick = t < 3
		i.move = Vector2(1.0, 0.0) if t < 3 else Vector2.ZERO)
	_check(choppa.global_position.x > 5.0, "dashed right, x=%f" % choppa.global_position.x)
	_check(landed == [["BARREL ROLL", false]], "landed a high barrel roll, got %s" % [landed])
	_check(is_equal_approx(choppa.boost_meter, 0.15), "boost reward, meter=%f" % choppa.boost_meter)


func test_low_trick_rewards_double() -> void:
	_ground()
	var choppa := _choppa(Vector3(0.0, 4.0, 0.0))
	choppa.boost_meter = 0.0
	await _fly(choppa, 2)  # Let the altitude probe run.
	await _fly(choppa, 60, func(i: PilotInput, t: int) -> void:
		i.trick = t < 3
		i.move = Vector2(-1.0, 0.0) if t < 3 else Vector2.ZERO)
	_check(is_equal_approx(choppa.boost_meter, 0.3), "double reward, meter=%f" % choppa.boost_meter)


func test_180_snap_reverses_heading_and_keeps_speed() -> void:
	var choppa := _choppa(Vector3(0.0, 30.0, 0.0))
	await _fly(choppa, 90, func(i: PilotInput, _t: int) -> void: i.move = Vector2(0.0, 1.0))
	var speed_before := choppa.velocity.length()
	await _fly(choppa, 40, func(i: PilotInput, t: int) -> void:
		i.trick = t < 3
		i.move = Vector2(0.0, -1.0) if t < 3 else Vector2.ZERO)
	var forward := choppa.facing() * Vector3.FORWARD
	_check(forward.z > 0.99, "now facing +Z, forward=%s" % forward)
	_check(choppa.velocity.z > 0.0, "moving +Z, v=%s" % choppa.velocity)
	_check(choppa.velocity.length() > speed_before * 0.6, "kept most speed")


func test_wall_hit_bounces_and_stuns() -> void:
	MapKit.block(_world, Vector3(0.0, 10.0, -20.0), Vector3(40.0, 40.0, 2.0), Color.GRAY)
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	var bumps := []
	choppa.bumped.connect(func(impact: float) -> void: bumps.append(impact))
	choppa.velocity = Vector3(0.0, 0.0, -40.0)
	await _fly(choppa, 40, func(i: PilotInput, _t: int) -> void: i.move = Vector2(0.0, 1.0))
	_check(bumps.size() >= 1, "bumped the wall")
	_check(choppa.global_position.z > -20.0, "did not pass through, z=%f" % choppa.global_position.z)


func test_turbo_item() -> void:
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	choppa.boost_meter = 0.0
	_check(choppa.give_item("TURBO"), "slot was empty")
	_check(not choppa.give_item("TURBO"), "slot holds one item")
	await _fly(choppa, 80, func(i: PilotInput, t: int) -> void: i.use_item = t < 3)
	_check(choppa.item == "", "item consumed")
	_check(choppa.velocity.length() > choppa.boost_speed, "turbo speed, v=%f" % choppa.velocity.length())


func test_item_box_gives_item_and_respawns() -> void:
	var box := ItemBox.new()
	box.position = Vector3(0.0, 10.0, -15.0)
	_world.add_child(box)
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	await _fly(choppa, 60, func(i: PilotInput, _t: int) -> void: i.move = Vector2(0.0, 1.0))
	_check(Items.TABLE.has(choppa.item), "got an item, item=%s" % choppa.item)
	_check(not box.is_available(), "box broke")
	box._process(ItemBox.RESPAWN_TIME + 0.1)
	_check(box.is_available(), "box respawned")


func test_item_roll_only_returns_known_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var leader := {}
	var last := {}
	for n in 2000:
		var a := Items.roll(rng, 0.0)
		var b := Items.roll(rng, 1.0)
		leader[a] = leader.get(a, 0) + 1
		last[b] = last.get(b, 0) + 1
	_check(leader.keys().all(func(k: String) -> bool: return Items.TABLE.has(k)), "known items")
	_check(not leader.has("SCRAMBLER"), "the leader never gets the scrambler")
	_check(not leader.has("GET TO THE CHOPPA"), "the leader never gets the comeback item")
	_check(last.get("GET TO THE CHOPPA", 0) > 300, "last place gets the comeback item")
	_check(last.get("MISSILE", 0) > leader.get("MISSILE", 0) * 2, "missiles favour those behind")


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
	await _fly(choppa, 180, _hold_fire)
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


func test_barrel_roll_dodges_bullets() -> void:
	var shooter := _choppa(Vector3(0.0, 30.0, 0.0))
	var target := _choppa(Vector3(0.0, 30.0, -30.0))
	var taken := []
	target.hit_taken.connect(func(_i: Vector3, _s: Choppa) -> void: taken.append(true))
	# Start rolling, then fire a burst that arrives while the roll lasts.
	target.input.trick = true
	target.input.move = Vector2(1.0, 0.0)
	target.step(TICK)
	_check(target.trick == "BARREL ROLL", "rolling")
	target.input.clear()
	for t in 12:
		shooter.input.fire = t < 4
		await physics_frame
		shooter.step(TICK)
		target.set("trick_time", 0.0)  # Freeze the roll so every round arrives mid-roll.
		target.step(TICK)
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
	bot_choppa.respawn(map.spawn_points[0])
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
	_check(race.time < 150.0, "in reasonable time, %.1fs" % race.time)
	_check(bumps.is_empty(), "no wall hits, got %d" % bumps.size())


func test_four_bots_all_finish() -> void:
	var map := TestRange.new()
	map.mode = "race"
	_world.add_child(map)
	var field: Array[Choppa] = []
	for n in 4:
		var c := Choppa.new()
		_world.add_child(c)
		c.respawn(map.spawn_points[n])
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
	target.input.move = Vector2(0.0, 1.0)
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
	_check(b.global_position.distance_to(spawns[1].origin) < 0.1, "respawned far from the killer")
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


func test_health_crate_heals() -> void:
	var crate := HealthCrate.new()
	crate.position = Vector3(0.0, 10.0, -15.0)
	_world.add_child(crate)
	var choppa := _choppa(Vector3(0.0, 10.0, 0.0))
	choppa.damage(70.0, null)
	await _fly(choppa, 60, func(i: PilotInput, _t: int) -> void: i.move = Vector2(0.0, 1.0))
	_check(is_equal_approx(choppa.health, 30.0 + HealthCrate.HEAL), "healed, hp=%f" % choppa.health)
	_check(not crate.is_available(), "crate used up")


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
	var map := MesaBasin.new()
	map.mode = "battle"
	_world.add_child(map)
	var field: Array[Choppa] = []
	for n in 4:
		var c := Choppa.new()
		c.pilot_name = "Bot%d" % n
		c.max_altitude = map.ceiling
		_world.add_child(c)
		c.respawn(map.spawn_points[n * 2])
		field.append(c)
	var battle := Battle.new()
	_world.add_child(battle)
	battle.setup(field, map.spawn_points, 99, 120.0)
	var bumps := {}
	var travelled := {}
	var used := []
	var dealt := [0.0]
	for c in field:
		c.damaged.connect(func(amount: float, attacker: Choppa) -> void:
			if attacker and attacker != c:
				dealt[0] += amount)
		bumps[c] = 0
		travelled[c] = 0.0
		c.bumped.connect(func(_i: float) -> void: bumps[c] += 1)
		c.item_used.connect(func(item_name: String) -> void: used.append(item_name))
		var bot := FighterBot.new()
		bot.choppa = c
		bot.ceiling = map.ceiling
		bot.rng.seed = hash(c.pilot_name)
		_world.add_child(bot)
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
	print("    ", summary, " damage dealt: %d, items used: %s" % [dealt[0], used])
	var kills := 0
	for c in field:
		kills += battle.kills_of(c)
		_check(travelled[c] > 800.0, "%s kept moving" % c.pilot_name)
	# Exact kill counts vary between machines; what matters is that they fight.
	_check(dealt[0] >= 300.0, "bots deal real damage, got %d" % dealt[0])
	_check(kills >= 2, "bots score kills, got %d" % kills)
	_check(used.size() >= 4, "bots use items, got %s" % [used])


## Steps choppas by hand for `ticks` ticks while the item objects run on their own.
func _step_all(field: Array, ticks: int) -> void:
	for t in ticks:
		await physics_frame
		for c: Choppa in field:
			c.step(TICK)


func test_missile_homes_and_hits() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	# Off to the side and higher: only a homing missile can hit this.
	var target := _choppa(Vector3(40.0, 35.0, -90.0))
	shooter.give_item("MISSILE")
	_check(shooter.missile_target() == target, "locks on")
	shooter.use_item()
	await _step_all([shooter, target], 150)
	_check(target.health < Choppa.MAX_HEALTH - 20.0, "missile hit, hp=%f" % target.health)
	_check(shooter.health == Choppa.MAX_HEALTH, "shooter unhurt")


func test_barrel_roll_shakes_off_missile() -> void:
	var shooter := _choppa(Vector3(0.0, 20.0, 0.0))
	var target := _choppa(Vector3(0.0, 20.0, -120.0))
	shooter.give_item("MISSILE")
	shooter.use_item()
	var missile: Weapons.Missile = _world.get_children().filter(func(n: Node) -> bool: return n is Weapons.Missile)[0]
	for t in 150:
		await physics_frame
		target.input.trick = missile and is_instance_valid(missile) and target.global_position.distance_to(missile.global_position) < 22.0
		target.input.move = Vector2(1.0, 0.0) if target.input.trick else Vector2.ZERO
		shooter.step(TICK)
		target.step(TICK)
	_check(target.health == Choppa.MAX_HEALTH, "dodged, hp=%f" % target.health)


func test_mine_arms_then_explodes() -> void:
	var layer := _choppa(Vector3(0.0, 20.0, 0.0))
	var victim := _choppa(Vector3(0.0, 20.0, 60.0))
	layer.give_item("MINE")
	layer.use_item()
	await _step_all([layer, victim], 10)
	_check(layer.health == Choppa.MAX_HEALTH, "doesn't go off under its owner before arming")
	await _step_all([layer], 60)
	# Fly the victim into it.
	victim.velocity = Vector3(0.0, 0.0, -30.0)
	for t in 120:
		victim.input.move = Vector2(0.0, 1.0)
		await physics_frame
		victim.step(TICK)
	_check(victim.health <= Choppa.MAX_HEALTH - 25.0, "mine went off, hp=%f" % victim.health)


func test_fake_item_box_explodes() -> void:
	var layer := _choppa(Vector3(0.0, 20.0, 0.0))
	layer.give_item("FAKE BOX")
	layer.use_item()
	await _step_all([layer], 70)
	var victim := _choppa(Vector3(0.0, 20.0, 40.0))
	victim.velocity = Vector3(0.0, 0.0, -25.0)
	for t in 120:
		victim.input.move = Vector2(0.0, 1.0)
		await physics_frame
		victim.step(TICK)
	_check(victim.health < Choppa.MAX_HEALTH, "fake box hurt, hp=%f" % victim.health)
	_check(victim.item == "", "and gave no item")


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


func test_scrambler_hits_the_leader() -> void:
	var user := _choppa(Vector3(0.0, 20.0, 0.0))
	var leader := _choppa(Vector3(50.0, 20.0, 0.0))
	var other := _choppa(Vector3(-20.0, 20.0, 0.0))
	user.standing = 1.0
	leader.standing = 0.0
	other.standing = 0.5
	user.give_item("SCRAMBLER")
	user.use_item()
	_check(leader.scrambled > 0.0 and other.scrambled == 0.0, "the leader got scrambled")
	await _fly(leader, 30, func(i: PilotInput, _t: int) -> void: i.yaw = 1.0)
	_check((leader.facing() * Vector3.FORWARD).x < -0.3, "steering right turned it left")


func test_shield_absorbs_damage() -> void:
	var a := _choppa(Vector3(0.0, 20.0, 0.0))
	a.give_item("SHIELD")
	a.use_item()
	a.damage(30.0, null)
	_check(a.health == Choppa.MAX_HEALTH, "first 40 damage absorbed")
	a.damage(30.0, null)
	_check(a.health == Choppa.MAX_HEALTH - 20.0, "the rest gets through, hp=%f" % a.health)


func test_get_to_the_choppa() -> void:
	var a := _choppa(Vector3(0.0, 20.0, 0.0))
	var b := _choppa(Vector3(0.0, 20.0, -30.0))
	a.give_item("GET TO THE CHOPPA")
	a.use_item()
	a.damage(90.0, b)
	_check(a.health == Choppa.MAX_HEALTH, "invulnerable during the rampage")
	_check(a.velocity.length() >= a.boost_speed, "turbo kick")
	var hits := []
	b.damaged.connect(func(amount: float, _by: Choppa) -> void: hits.append(amount))
	a.velocity = Vector3.ZERO
	for t in 20:
		a.input.fire = true
		await physics_frame
		a.step(TICK)
	_check(not hits.is_empty() and hits[0] == Bullet.DAMAGE * 2.0, "double damage, got %s" % [hits])


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
