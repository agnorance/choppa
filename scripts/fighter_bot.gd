class_name FighterBot
extends Node
## AI pilot for battles: hunts an opponent, circles it at gun range and shoots when lined
## up, barrel-rolls when under fire, fetches repair kits when hurt, and feels its way
## around obstacles with ray probes.

const PREFERRED_RANGE := 45.0
const PROBE_LENGTH := 14.0

var choppa: Choppa
var skill := 1.0  ## 0..1: speed, dodging and trigger discipline.
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
var _under_fire := 0.0
var _cooling_gun := false
var _wander := Vector3.ZERO
var _wander_time := 0.0


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
	var crate := _crate_if_hurt()
	if _unstick > 0.0:
		goal = pos + _unstick_dir * 30.0
		look = goal
	elif crate:
		goal = crate.global_position
		look = goal
	elif target:
		var to := target.global_position - pos
		var flat := Vector3(to.x, 0.0, to.z)
		distance = flat.length()
		var away := -flat.normalized() if distance > 0.1 else Vector3.BACK
		var side := away.cross(Vector3.UP) * _orbit
		goal = target.global_position + away * PREFERRED_RANGE + side * 25.0
		goal.y = target.global_position.y + 2.0
		look = target.global_position + target.velocity * 0.25  # Lead the target.
	else:
		if _wander_time <= 0.0:
			var angle := rng.randf() * TAU
			_wander = Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.0, arena_radius)
			_wander.y = rng.randf_range(15.0, 35.0)
			_wander_time = 6.0
		goal = _wander
		look = goal
	goal.y = clampf(goal.y, 8.0, ceiling - 8.0)

	var to_local := choppa.facing().inverse()
	var local_look := to_local * (look - pos)
	var angle := atan2(local_look.x, -local_look.z)  # Positive: look point is to the right.
	i.yaw = clampf(angle * 2.5, -1.0, 1.0)

	var local_goal := to_local * (goal - pos)
	var local_velocity := to_local * choppa.velocity
	var move := Vector2(local_goal.x, -local_goal.z) * 0.06 - Vector2(local_velocity.x, -local_velocity.z) * 0.04
	var lift := (goal.y - pos.y) * 0.25 - choppa.velocity.y * 0.1
	var push := _avoidance()
	var local_push := to_local * push
	move += Vector2(local_push.x, -local_push.z)
	lift += push.y
	i.move = move.limit_length(lerpf(0.75, 1.0, skill))
	i.lift = clampf(lift, -1.0, 1.0)

	# Trigger discipline: let the gun cool before it overheats.
	if choppa.heat > lerpf(0.6, 0.9, skill):
		_cooling_gun = true
	elif choppa.heat < 0.3:
		_cooling_gun = false
	var in_sights := choppa.aim_target()
	i.fire = in_sights != null and not _cooling_gun and _can_see(in_sights)
	i.boost = target != null and distance > 110.0 and absf(angle) < 0.3 and choppa.boost_meter > 0.3
	i.use_item = choppa.item != ""

	if _under_fire > 0.0 and _dodge_cooldown <= 0.0 and rng.randf() < 0.05 * skill:
		i.trick = true
		i.move = Vector2(1.0 if rng.randf() < 0.5 else -1.0, 0.0)
		_dodge_cooldown = 3.0

	if choppa.velocity.length() < 3.0 and i.move.length() > 0.4:
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


func _crate_if_hurt() -> HealthCrate:
	if choppa.health > 40.0:
		return null
	var best: HealthCrate = null
	var best_distance := 250.0
	for node in choppa.get_tree().get_nodes_in_group("health_crates"):
		var crate := node as HealthCrate
		var d := choppa.global_position.distance_to(crate.global_position)
		if crate.is_available() and d < best_distance:
			best = crate
			best_distance = d
	return best


func _can_see(other: Choppa) -> bool:
	var query := PhysicsRayQueryParameters3D.create(choppa.global_position, other.global_position)
	query.exclude = [choppa.get_rid(), other.get_rid()]
	return choppa.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
	return push


func _on_hit_taken(_impulse: Vector3, shooter: Choppa) -> void:
	_under_fire = 0.8
	if shooter and shooter.alive and rng.randf() < 0.5:
		target = shooter  # Revenge.
		_retarget = 3.0
