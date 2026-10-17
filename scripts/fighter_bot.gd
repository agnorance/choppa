class_name FighterBot
extends Node
## AI pilot for battles: hunts an opponent, circles it at gun range and shoots when lined
## up, fires rockets and missiles, rolls hard or drops flares against missiles, lands at
## a service station when hurt or out of ammunition, and feels its way around obstacles
## with ray probes.

const PREFERRED_RANGE := 45.0
const PROBE_LENGTH := 14.0
const BRAKING := 7.0  ## m/s^2 a bot counts on to stop before a wall.

var choppa: Choppa
var skill := 1.0  ## Around 1: speed, dodging, aim lead and trigger discipline. Hard bots go above 1.
var ceiling := 90.0
var arena_radius := 200.0  ## Where to wander when nobody is around.
var rng := RandomNumberGenerator.new()

var target: Choppa

var _retarget := 0.0
var _orbit := 1.0
var _orbit_switch := 0.0
var _stuck := 0.0
var _unstick := 0.0
var _unstick_dir := Vector3.ZERO
var _dodge_cooldown := 0.0
var _dodge_time := 0.0
var _dodge_dir := 1.0
var _under_fire := 0.0
var _cooling_gun := false
var _wander := Vector3.ZERO
var _wander_time := 0.0
var _station: ServiceStation  ## Where we are heading to land, or null.
var _station_time := 0.0  ## Seconds spent trying to reach it.
var _ignored_stations := {}  ## ServiceStation -> seconds left to ignore it.


func _ready() -> void:
	process_physics_priority = -10
	choppa.hit_taken.connect(_on_hit_taken)


func _physics_process(delta: float) -> void:
	steer(delta)


func steer(delta: float) -> void:
	var i := choppa.input
	i.clear()
	if not choppa.alive or choppa.locked:
		return
	_retarget -= delta
	_orbit_switch -= delta
	_unstick -= delta
	_dodge_cooldown -= delta
	_under_fire -= delta
	_wander_time -= delta
	if _orbit_switch <= 0.0:
		_orbit = -_orbit
		_orbit_switch = rng.randf_range(3.0, 7.0)
	if _retarget <= 0.0 or target == null or not target.alive:
		target = _pick_target()
		_retarget = 2.0

	var pos := choppa.global_position
	var goal: Vector3
	var look: Vector3
	var distance := 0.0
	var station := _station_if_needed(delta)
	var landing := station != null
	if _unstick > 0.0:
		goal = pos + _unstick_dir * 30.0
		look = goal
	elif station:
		goal = Vector3(station.global_position.x, station.pad_top() + choppa.clearance, station.global_position.z)
		look = goal + choppa.facing() * Vector3.FORWARD * 30.0  # Keep the heading; just set down.
	elif target:
		var to := target.global_position - pos
		var flat := Vector3(to.x, 0.0, to.z)
		distance = flat.length()
		var away := -flat.normalized() if distance > 0.1 else Vector3.BACK
		var side := away.cross(Vector3.UP) * _orbit
		goal = target.global_position + away * PREFERRED_RANGE + side * 25.0
		goal.y = target.global_position.y + 2.0
		look = target.global_position + target.velocity * lerpf(0.0, 0.3, clampf(skill - 0.3, 0.0, 1.0))  # Lead the target.
	else:
		if _wander_time <= 0.0:
			var angle := rng.randf() * TAU
			_wander = Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.0, arena_radius)
			_wander.y = rng.randf_range(15.0, 35.0)
			_wander_time = 6.0
		goal = _wander
		look = goal
	# Keep off the ground and under the ceiling, unless landing at a station.
	if not landing:
		goal.y = clampf(goal.y, 11.0, ceiling - 10.0)  # Room for the rotor disc above and below.

	var local_look := choppa.facing().inverse() * (look - pos)
	var angle := atan2(local_look.x, -local_look.z)  # Positive: look point is to the right.
	var want := ((goal - pos) * 0.6).limit_length(lerpf(0.75, 1.0, skill) * choppa.max_speed)
	var flat_to_goal := Vector2(goal.x - pos.x, goal.z - pos.z).length()
	if landing and flat_to_goal < 40.0:
		# Final approach: slow down over the pad, then sink onto it gently.
		want = (goal - pos) * 0.5
		want.y = clampf(want.y, -2.5 if flat_to_goal < 4.0 else 0.0, 3.0)
		if station.occupant == choppa:
			want = Vector3(0.0, -1.0, 0.0)
	else:
		want += _avoidance() * 20.0
		want = _brake_for_walls(want)
	# Low down, tip the rotor less: a steep bank there puts the blades into the ground.
	var tilt := lerpf(0.3, Autopilot.MAX_TILT, clampf((choppa.altitude - 3.0) / 10.0, 0.0, 1.0))
	if landing:
		tilt = minf(tilt, 0.3)
	Autopilot.fly(choppa, i, want, look, tilt)

	# Trigger discipline: let the gun cool before it overheats.
	if choppa.heat > lerpf(0.6, 0.9, skill):
		_cooling_gun = true
	elif choppa.heat < 0.3:
		_cooling_gun = false
	var in_sights := choppa.aim_target()
	i.fire = in_sights != null and not _cooling_gun and _can_see(in_sights)
	i.boost = target != null and distance > 110.0 and absf(angle) < 0.3 and choppa.boost_meter > 0.3
	if not landing:
		_use_weapons(angle, distance)

	var dodge_chance := 0.05 * skill if _under_fire > 0.0 else 0.0
	if _missile_incoming():
		dodge_chance = 0.25 * skill
	if _dodge_cooldown <= 0.0 and choppa.altitude > 14.0 and rng.randf() < dodge_chance:
		_dodge_dir = 1.0 if rng.randf() < 0.5 else -1.0
		_dodge_time = 0.7
		_dodge_cooldown = 3.0
	if _dodge_time > 0.0:
		_dodge_time -= delta
		i.cyclic.x = _dodge_dir  # A full roll throws off bullets and missiles.

	if not landing and choppa.velocity.length() < 3.0 and want.length() > 5.0:
		_stuck += delta
	else:
		_stuck = maxf(0.0, _stuck - delta)
	if _stuck > 1.2:
		_stuck = 0.0
		_unstick = 1.5
		var angle_out := rng.randf() * TAU
		_unstick_dir = Vector3(cos(angle_out), 0.6, sin(angle_out)).normalized()


func _pick_target() -> Choppa:
	var best: Choppa = null
	var best_score := INF
	for node in choppa.get_tree().get_nodes_in_group("choppas"):
		var other := node as Choppa
		if other == choppa or not other.alive:
			continue
		var score := choppa.global_position.distance_to(other.global_position)
		if _can_see(other):
			score *= 0.5
		if score < best_score:
			best_score = score
			best = other
	return best


## Rockets when lined up and close, a missile with a lock, flares against an incoming
## missile, a mine for whoever is on our tail, smoke when hurt and under fire.
func _use_weapons(angle: float, distance: float) -> void:
	var i := choppa.input
	var a := choppa.ammo
	var lined_up := target != null and absf(angle) < lerpf(0.06, 0.12, skill) and distance < 130.0
	i.rockets = a.rockets > 0 and lined_up and _can_see(target)
	i.missile = a.missiles > 0 and target != null and choppa.missile_target() == target and distance < 220.0
	i.flares = a.flares > 0 and _missile_incoming(60.0)
	i.mine = a.mines > 0 and _enemy_behind(70.0)
	i.smoke = a.smoke > 0 and _under_fire > 0.0 and choppa.health < choppa.max_health * 0.5


## The nearest ready station when hurt or low on ammo, else null (an ammo-only one does
## not help when hurt). Gives
## up on one it cannot reach in 20 s.
func _station_if_needed(delta: float) -> ServiceStation:
	for ignored in _ignored_stations.keys():
		_ignored_stations[ignored] -= delta
		if _ignored_stations[ignored] <= 0.0:
			_ignored_stations.erase(ignored)
	if _station and _station.occupant == choppa:
		return _station  # Already on the pad: stay until it is done.
	var worn := choppa.wear(Choppa.Part.TAIL) > 0.5 or choppa.wear(Choppa.Part.ENGINE) > 0.5 or choppa.wear(Choppa.Part.ROTOR) > 0.6
	var dry: bool = choppa.ammo.rockets + choppa.ammo.missiles == 0 or choppa.ammo.gun < choppa.full_ammo("gun") * 0.2
	var hurt := choppa.health < choppa.max_health * 0.65  # Early enough to make it there alive.
	if not (worn or dry or hurt):
		_station = null
		return null
	if _station and _station.is_ready() and (_station.occupant == null or _station.occupant == choppa):
		_station_time += delta
		if _station_time > 20.0 and _station.occupant != choppa:
			_ignored_stations[_station] = 30.0
			_station = null
		return _station
	_station = null
	_station_time = 0.0
	var best_distance := 400.0
	for node in choppa.get_tree().get_nodes_in_group("stations"):
		var st := node as ServiceStation
		var d := choppa.global_position.distance_to(st.global_position)
		if st.ammo_only and (worn or hurt):
			continue
		if st.is_ready() and st.occupant == null and d < best_distance and not _ignored_stations.has(st):
			_station = st
			best_distance = d
	return _station


func _enemy_behind(reach: float) -> bool:
	var forward := choppa.facing() * Vector3.FORWARD
	for node in choppa.get_tree().get_nodes_in_group("choppas"):
		var other := node as Choppa
		if other == choppa or not other.alive:
			continue
		var to := other.global_position - choppa.global_position
		if to.length() < reach and forward.dot(to.normalized()) < -0.3:
			return true
	return false


func _missile_incoming(reach := 30.0) -> bool:
	for node in choppa.get_tree().get_nodes_in_group("missiles"):
		var missile := node as Weapons.Missile
		if missile.is_hunting(choppa) and missile.global_position.distance_to(choppa.global_position) < reach:
			return true
	return false


func _can_see(other: Choppa) -> bool:
	var query := PhysicsRayQueryParameters3D.create(choppa.global_position, other.global_position)
	query.exclude = [choppa.get_rid(), other.get_rid()]
	return choppa.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Slows the part of `want` that heads into a wall ahead to what can still stop in time:
## at 25 m/s a wall hurts badly, at 32 it kills, so bots must not trust the push alone.
func _brake_for_walls(want: Vector3) -> Vector3:
	var speed := choppa.velocity.length()
	if speed < 8.0:
		return want
	var pos := choppa.global_position
	var ahead := choppa.velocity / speed
	var query := PhysicsRayQueryParameters3D.create(pos, pos + ahead * (speed * 1.6 + choppa.rotor_radius + 6.0))
	query.exclude = [choppa.get_rid()]
	var hit := choppa.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider is Choppa:
		return want
	var normal: Vector3 = hit.normal
	var room := maxf(0.0, pos.distance_to(hit.position) - choppa.rotor_radius - 2.0)
	var allowed := sqrt(2.0 * BRAKING * room)
	var into := -want.dot(normal)
	if into > allowed:
		want += normal * (into - allowed)
	return want


## A push away from nearby walls and the ground, from rays fanned out ahead.
func _avoidance() -> Vector3:
	var pos := choppa.global_position
	var speed := choppa.velocity.length()
	var ahead := choppa.velocity / speed if speed > 4.0 else choppa.facing() * Vector3.FORWARD
	var reach := PROBE_LENGTH + speed * 0.8
	var space := choppa.get_world_3d().direct_space_state
	var push := Vector3.ZERO
	for probe: Array in [
		[ahead, reach], [ahead.rotated(Vector3.UP, 0.6), reach * 0.8],
		[ahead.rotated(Vector3.UP, -0.6), reach * 0.8],
		[(ahead + Vector3.DOWN * 0.5).normalized(), reach * 0.7], [Vector3.DOWN, 7.0],
		[Vector3.UP, 8.0],
	]:
		var dir: Vector3 = probe[0]
		var length: float = probe[1]
		var query := PhysicsRayQueryParameters3D.create(pos, pos + dir * length)
		query.exclude = [choppa.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and not hit.collider is Choppa:
			var closeness := 1.0 - pos.distance_to(hit.position) / length
			push += (hit.normal + Vector3.UP * 0.3) * closeness * 2.0
	# The rotor disc reaches well past the body: feel around it at hub height, sideways
	# and diagonally ahead, so the blades never touch a wall or a roof.
	for rotor_hub in choppa.rotor_hubs:
		push += _rotor_clearance(pos + choppa.global_transform.basis * rotor_hub, ahead, reach, space)
	# Power lines have no collision for the rays to find: keep well clear of the cables,
	# passing under them rather than over.
	var look_ahead := pos + choppa.velocity * 0.8
	for node in choppa.get_tree().get_nodes_in_group("power_lines"):
		var cable := (node as Hazards.PowerLine).nearest(look_ahead)
		var away := look_ahead - cable
		if away.length() < 12.0:
			var down := Vector3.DOWN if look_ahead.y < cable.y + 3.0 else Vector3.UP
			push += (away.normalized() * 0.5 + down) * (1.0 - away.length() / 12.0) * 2.5
	return push


## A push away from walls and roofs round one rotor disc, felt at its hub height
## sideways and diagonally, so the blades never touch.
func _rotor_clearance(hub: Vector3, ahead: Vector3, reach: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	var push := Vector3.ZERO
	var side := choppa.facing() * Vector3.RIGHT
	var front := choppa.facing() * Vector3.FORWARD
	var disc := choppa.rotor_radius + 3.0
	for dir: Vector3 in [side, -side, (front + side).normalized(), (front - side).normalized(), Vector3.UP,
			(side + Vector3.DOWN).normalized(), (-side + Vector3.DOWN).normalized(), ahead,
			(side + Vector3.UP).normalized(), (-side + Vector3.UP).normalized(), (front + Vector3.UP).normalized(),
			(ahead + Vector3.UP * 0.5).normalized()]:
		var query := PhysicsRayQueryParameters3D.create(hub, hub + dir * (disc if dir != ahead else reach))
		query.exclude = [choppa.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and not hit.collider is Choppa:
			var closeness := clampf(1.0 - hub.distance_to(hit.position) / disc, 0.0, 1.0)
			push += (hit.normal - dir * 0.5) * closeness * 5.0
	return push


func _on_hit_taken(_impulse: Vector3, shooter: Choppa) -> void:
	_under_fire = 0.8
	if shooter and shooter.alive and rng.randf() < 0.5:
		target = shooter  # Revenge.
		_retarget = 3.0
