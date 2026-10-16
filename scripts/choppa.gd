class_name Choppa
extends CharacterBody3D
## Arcade helicopter. Reads `input` every physics tick and never touches Input directly,
## so the same code runs for local players, bots and (later) network peers.

signal trick_started(trick_name: String)
signal trick_landed(trick_name: String, reward: float, low: bool)
signal trick_botched(trick_name: String)
signal bumped(impact: float)
signal item_changed(item_name: String)
signal hit_taken(impulse: Vector3, shooter: Choppa)
signal scored_hit(target: Choppa)
signal gun_overheated
signal damaged(amount: float, attacker: Choppa)
signal died(killer: Choppa)
signal healed(amount: float)
signal item_used(item_name: String)
signal scrambled_by(attacker: Choppa)

## Below this altitude a trick counts as "low" and its boost reward doubles.
const LOW_ALTITUDE := 6.0
## Distance from the body origin to the bottom of the skids.
const GROUND_CLEARANCE := 1.15
const BOUNCE_IMPACT := 14.0
const TRICK_COOLDOWN := 0.15
const GUN_INTERVAL := 0.08  ## Seconds between shots.
const GUN_HEAT_PER_SHOT := 0.035  ## About 2.3 s of continuous fire to overheat.
const GUN_COOL_RATE := 0.6  ## Heat lost per second when not firing.
const AIM_ASSIST_ANGLE := deg_to_rad(12.0)  ## Horizontal cone that snaps bullets.
const AIM_ASSIST_PITCH := deg_to_rad(35.0)
const AIM_ASSIST_RANGE := 160.0
const MAX_HEALTH := 100.0
const CRASH_DAMAGE_FROM := 22.0  ## Wall impacts harder than this hurt.
const SPAWN_SHIELD := 2.0  ## Seconds of invulnerability after respawning.
const SHIELD_HP := 40.0
const SHIELD_TIME := 12.0
const SCRAMBLE_TIME := 5.0
const RAMPAGE_TIME := 6.0  ## GET TO THE CHOPPA.
const MISSILE_CONE := deg_to_rad(45.0)
const MISSILE_RANGE := 250.0
## A crash this soon after being shot counts as a kill for whoever shot you.
const CRASH_CREDIT_TIME := 4.0
const TRICKS := {
	"BARREL ROLL": {"duration": 0.55, "reward": 0.15},
	"FRONT FLIP": {"duration": 0.6, "reward": 0.18},
	"180 SNAP": {"duration": 0.45, "reward": 0.12},
	"PIROUETTE": {"duration": 0.7, "reward": 0.12},
}

@export var team_color := Color(0.95, 0.5, 0.1)
@export var pilot_name := "Pilot"
@export var local_player := false  ## Hide own model from the cockpit camera.

@export_group("Flight")
@export var max_speed := 36.0
@export var boost_speed := 60.0
@export var turbo_speed := 72.0
@export var accel := 28.0
@export var climb_speed := 16.0
@export var climb_accel := 45.0
@export var turn_speed := 2.4  ## rad/s
@export var turn_accel := 14.0
@export var boost_drain := 0.35  ## meter per second
@export var max_altitude := 140.0

var input := PilotInput.new()
var heading := 0.0  ## Yaw in radians; 0 faces -Z.
var turn_rate := 0.0
var boost_meter := 0.5
var turbo_time := 0.0
var item := ""
var stun := 0.0
var locked := false  ## Ignores input, e.g. during a race countdown.
var altitude := 500.0  ## Height of the skids above whatever is below.
var heat := 0.0  ## Gun heat, 0..1.
var overheated := false
var health := MAX_HEALTH
var alive := true
var mortal := true  ## False in races: hits still push, but never hurt.
var standing := 0.5  ## 0 leading .. 1 last; set by the game mode, steers item odds.
var shield := 0.0  ## Damage the shield bubble still absorbs.
var shield_time := 0.0
var scrambled := 0.0  ## Seconds left with left/right swapped.
var rampage := 0.0  ## Seconds left of GET TO THE CHOPPA.
var invulnerable := 0.0
var clock := 0.0  ## Simulation seconds this choppa has existed.
var last_shot_time := -10.0  ## `clock` at the last shot, for the muzzle flash.

var trick := ""  ## Name of the trick in progress, "" when none.
var trick_time := 0.0
var trick_dir := 1.0

var model: ChoppaModel

var _trick_cooldown := 0.0
var _trick_low := false
var _snap_from := 0.0
var _prev_trick := false
var _prev_item := false
var _gun_timer := 0.0
var _gun_side := 1.0
var _shape: CollisionShape3D
var _last_attacker: Choppa
var _last_attacker_time := -100.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	heading = rotation.y
	add_to_group("choppas")

	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.1
	capsule.height = 5.4
	_shape = CollisionShape3D.new()
	_shape.shape = capsule
	_shape.rotation_degrees.x = 90.0
	_shape.position.z = 0.8
	add_child(_shape)

	model = ChoppaModel.new()
	model.color = team_color
	model.own = local_player
	model.pilot = self
	add_child(model)


func _physics_process(delta: float) -> void:
	step(delta)


func is_boosting() -> bool:
	return turbo_time > 0.0 or (input.boost and boost_meter > 0.0 and stun <= 0.0)


func trick_progress() -> float:
	if trick == "":
		return 0.0
	return clampf(trick_time / TRICKS[trick].duration, 0.0, 1.0)


func facing() -> Basis:
	return Basis(Vector3.UP, heading)


## Advances the simulation by one tick.
func step(delta: float) -> void:
	clock += delta
	if not alive:
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	shield_time = maxf(0.0, shield_time - delta)
	if shield_time <= 0.0:
		shield = 0.0
	scrambled = maxf(0.0, scrambled - delta)
	rampage = maxf(0.0, rampage - delta)
	var i := input
	if scrambled > 0.0:
		var swapped := PilotInput.new()
		swapped.copy_from(i)
		swapped.yaw = -i.yaw
		swapped.move.x = -i.move.x
		i = swapped
	if stun > 0.0:
		stun -= delta
		i = PilotInput.new()
	if locked:
		i = PilotInput.new()

	if i.trick and not _prev_trick:
		_start_trick(i)
	if i.use_item and not _prev_item:
		use_item()
	_prev_trick = i.trick
	_prev_item = i.use_item

	_trick_cooldown = maxf(0.0, _trick_cooldown - delta)
	_update_trick(delta)
	_update_gun(i, delta)

	if trick == "180 SNAP":
		turn_rate = 0.0
	else:
		turn_rate = move_toward(turn_rate, -i.yaw * turn_speed, turn_accel * delta)
		heading = wrapf(heading + turn_rate * delta, -PI, PI)

	var boosting := is_boosting()
	var top := max_speed
	if turbo_time > 0.0:
		turbo_time -= delta
		top = turbo_speed
	elif boosting:
		boost_meter = maxf(0.0, boost_meter - boost_drain * delta)
		top = boost_speed

	var wish := facing() * Vector3(i.move.x, 0.0, -i.move.y)
	if boosting:
		# Boost always drives you forward, steering still blends in.
		wish += facing() * Vector3.FORWARD
	wish = wish.limit_length(1.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := accel * 2.0 if boosting else accel
	if wish.length_squared() < 0.01 or horizontal.length() > top:
		rate = accel * 0.6
	horizontal = horizontal.move_toward(wish * top, rate * delta)
	var vertical := move_toward(velocity.y, i.lift * climb_speed, climb_accel * delta)
	if global_position.y > max_altitude:
		vertical = minf(vertical, 0.0)
	velocity = horizontal + Vector3.UP * vertical

	rotation = Vector3(0.0, heading, 0.0)
	var before := velocity
	move_and_slide()
	_handle_collisions(before)
	_update_altitude()
	model.update_pose(self, delta)


## The choppa that aim assist would shoot at right now, or null.
func aim_target() -> Choppa:
	return _target_in_cone(AIM_ASSIST_ANGLE, AIM_ASSIST_RANGE)


## Who a missile fired now would chase: a wider cone than the guns.
func missile_target() -> Choppa:
	return _target_in_cone(MISSILE_CONE, MISSILE_RANGE)


## Whether a smoke cloud hides this choppa (it can't see out, nobody can lock on).
func in_smoke() -> bool:
	for cloud in get_tree().get_nodes_in_group("smoke"):
		if (cloud as Weapons.SmokeCloud).covers(global_position):
			return true
	return false


func _target_in_cone(cone: float, reach: float) -> Choppa:
	if in_smoke():
		return null
	var forward := facing() * Vector3.FORWARD
	var best: Choppa = null
	var best_angle := cone
	for node in get_tree().get_nodes_in_group("choppas"):
		var other := node as Choppa
		if other == self or not other.alive:
			continue
		var to := other.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		if to.length() > reach or flat.length() < 0.1:
			continue
		var angle := forward.angle_to(flat)
		if angle < best_angle and absf(atan2(to.y, flat.length())) < AIM_ASSIST_PITCH and not other.in_smoke():
			best = other
			best_angle = angle
	return best


## Called by a bullet. Returns false when the hit is dodged.
func take_hit(impulse: Vector3, shooter: Choppa, amount := 0.0) -> bool:
	if not alive or trick == "BARREL ROLL":
		return false
	velocity += impulse
	hit_taken.emit(impulse, shooter)
	damage(amount, shooter)
	return true


func damage(amount: float, attacker: Choppa) -> void:
	if not alive or not mortal or invulnerable > 0.0 or rampage > 0.0 or amount <= 0.0:
		return
	if attacker and attacker != self:
		_last_attacker = attacker
		_last_attacker_time = clock
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return
	health -= amount
	damaged.emit(amount, attacker)
	if health <= 0.0:
		_die(attacker)


func heal(amount: float) -> bool:
	if not alive or health >= MAX_HEALTH:
		return false
	var before := health
	health = minf(MAX_HEALTH, health + amount)
	healed.emit(health - before)
	return true


func _die(killer: Choppa) -> void:
	alive = false
	health = 0.0
	trick = ""
	velocity = Vector3.ZERO
	model.visible = false
	_shape.set_deferred("disabled", true)
	var boom := Effects.Explosion.new()
	get_parent().add_child(boom)
	boom.global_position = global_position
	died.emit(killer)


func give_item(item_name: String) -> bool:
	if item != "":
		return false
	item = item_name
	item_changed.emit(item)
	return true


func use_item() -> void:
	match item:
		"":
			return
		"TURBO":
			_turbo(1.6)
		"MISSILE":
			var missile := Weapons.Missile.new()
			missile.shooter = self
			missile.target = missile_target()
			missile.direction = facing() * Vector3.FORWARD
			_drop(missile, Vector3(0.0, -0.6, -3.0))
		"MINE":
			var mine := Weapons.Mine.new()
			mine.owner_choppa = self
			_drop(mine, Vector3(0.0, -1.0, 9.0))
		"FAKE BOX":
			var fake := Weapons.FakeItemBox.new()
			fake.owner_choppa = self
			_drop(fake, Vector3(0.0, -0.5, 7.0))
		"SMOKE":
			_drop(Weapons.SmokeCloud.new(), Vector3(0.0, 0.0, 10.0))
		"SCRAMBLER":
			var victim := _scramble_target()
			if victim:
				victim.scrambled = SCRAMBLE_TIME
				victim.scrambled_by.emit(self)
		"SHIELD":
			shield = SHIELD_HP
			shield_time = SHIELD_TIME
		"GET TO THE CHOPPA":
			rampage = RAMPAGE_TIME
			boost_meter = 1.0
			_turbo(2.0)
	var used := item
	item = ""
	item_changed.emit(item)
	item_used.emit(used)


func _turbo(seconds: float) -> void:
	turbo_time = seconds
	# Kick in instantly, like a mushroom.
	var forward := facing() * Vector3.FORWARD
	velocity = forward * maxf(velocity.length(), boost_speed) + Vector3.UP * velocity.y


## Puts an item object into the world at `offset` in this choppa's frame (-Z ahead).
func _drop(thing: Node3D, offset: Vector3) -> void:
	get_parent().add_child(thing)
	thing.global_position = global_position + facing() * offset
	thing.reset_physics_interpolation()


## The leader among everyone else (lowest standing), nearest one on a tie.
func _scramble_target() -> Choppa:
	var best: Choppa = null
	for node in get_tree().get_nodes_in_group("choppas"):
		var other := node as Choppa
		if other == self or not other.alive:
			continue
		if best == null or other.standing < best.standing or (
			other.standing == best.standing
			and global_position.distance_to(other.global_position) < global_position.distance_to(best.global_position)
		):
			best = other
	return best


func respawn(at: Transform3D) -> void:
	global_position = at.origin
	heading = at.basis.get_euler().y
	rotation = Vector3(0.0, heading, 0.0)
	velocity = Vector3.ZERO
	turn_rate = 0.0
	trick = ""
	stun = 0.0
	turbo_time = 0.0
	heat = 0.0
	overheated = false
	shield = 0.0
	shield_time = 0.0
	scrambled = 0.0
	rampage = 0.0
	if not alive:
		alive = true
		_shape.set_deferred("disabled", false)
	health = MAX_HEALTH
	invulnerable = SPAWN_SHIELD
	model.visible = true
	reset_physics_interpolation()
	_update_altitude()


func _update_gun(i: PilotInput, delta: float) -> void:
	_gun_timer = maxf(0.0, _gun_timer - delta)
	if overheated:
		heat = maxf(0.0, heat - GUN_COOL_RATE * delta)
		overheated = heat > 0.0
		return
	if not i.fire:
		heat = maxf(0.0, heat - GUN_COOL_RATE * delta)
		return
	if trick != "" or _gun_timer > 0.0:
		return
	_shoot()
	_gun_timer = GUN_INTERVAL
	heat += GUN_HEAT_PER_SHOT
	if heat >= 1.0:
		heat = 1.0
		overheated = true
		gun_overheated.emit()


func _shoot() -> void:
	var muzzle := global_position + facing() * Vector3(0.9 * _gun_side, -0.5, -2.2)
	_gun_side = -_gun_side
	var target := aim_target()
	var direction := facing() * Vector3.FORWARD
	if target:
		direction = (target.global_position - muzzle).normalized()
	last_shot_time = clock
	var bullet := Bullet.new()
	bullet.shooter = self
	if rampage > 0.0:
		bullet.damage *= 2.0
	bullet.direction = direction
	# Bullets inherit your speed so they never fall behind you while boosting.
	bullet.speed = Bullet.SPEED + maxf(0.0, velocity.dot(direction))
	get_parent().add_child(bullet)
	bullet.global_position = muzzle
	bullet.reset_physics_interpolation()


func _start_trick(i: PilotInput) -> void:
	if trick != "" or _trick_cooldown > 0.0:
		return
	var f := facing()
	if absf(i.move.x) > 0.5 and absf(i.move.x) >= absf(i.move.y):
		trick = "BARREL ROLL"
		trick_dir = signf(i.move.x)
		velocity += f * Vector3(trick_dir * 26.0, 2.0, 0.0)
	elif i.move.y > 0.5:
		trick = "FRONT FLIP"
		velocity += f * Vector3(0.0, 3.0, -24.0)
	elif i.move.y < -0.5:
		trick = "180 SNAP"
		_snap_from = heading
		# Keep your speed, but it now points where you are about to face.
		velocity = Vector3(-velocity.x, velocity.y, -velocity.z)
	else:
		trick = "PIROUETTE"
		trick_dir = -1.0 if i.yaw > 0.0 else 1.0
		velocity.y += 14.0
	trick_time = 0.0
	_trick_low = altitude < LOW_ALTITUDE
	trick_started.emit(trick)


func _update_trick(delta: float) -> void:
	if trick == "":
		return
	trick_time += delta
	if altitude < LOW_ALTITUDE:
		_trick_low = true
	if trick == "180 SNAP":
		heading = wrapf(_snap_from + PI * smoothstep(0.0, 1.0, trick_progress()), -PI, PI)
	if trick_time >= TRICKS[trick].duration:
		var reward: float = TRICKS[trick].reward * (2.0 if _trick_low else 1.0)
		boost_meter = minf(1.0, boost_meter + reward)
		trick_landed.emit(trick, reward, _trick_low)
		trick = ""
		_trick_cooldown = TRICK_COOLDOWN


func _botch_trick() -> void:
	var botched := trick
	trick = ""
	_trick_cooldown = TRICK_COOLDOWN
	trick_botched.emit(botched)


func _handle_collisions(before: Vector3) -> void:
	var impact := 0.0
	var normal := Vector3.ZERO
	for k in get_slide_collision_count():
		var collision := get_slide_collision(k)
		var hit := -before.dot(collision.get_normal())
		if hit > impact:
			impact = hit
			normal = collision.get_normal()
	if impact <= 0.0:
		return
	if trick != "":
		_botch_trick()
	var is_ground := normal.y > 0.7
	if impact > BOUNCE_IMPACT and not is_ground:
		velocity = before.bounce(normal) * 0.45
		stun = clampf(impact / 60.0, 0.15, 0.5)
		bumped.emit(impact)
	if impact > CRASH_DAMAGE_FROM:
		var credit := _last_attacker if clock - _last_attacker_time < CRASH_CREDIT_TIME else null
		damage((impact - CRASH_DAMAGE_FROM) * 1.2, credit)

func _update_altitude() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 500.0
	)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		altitude = global_position.y - hit.position.y - GROUND_CLEARANCE
	else:
		altitude = 500.0
