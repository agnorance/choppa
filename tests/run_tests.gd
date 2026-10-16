extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_tests.gd
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
	_check(choppa.item == "TURBO", "got an item, item=%s" % choppa.item)
	_check(not box.is_available(), "box broke")
	box._process(ItemBox.RESPAWN_TIME + 0.1)
	_check(box.is_available(), "box respawned")


func test_item_roll_only_returns_known_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for n in 200:
		_check(Items.POOL.has(Items.roll(rng)), "rolled a known item")
