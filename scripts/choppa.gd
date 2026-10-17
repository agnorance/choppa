class_name Choppa
extends CharacterBody3D
## Arcade helicopter. Two flight models (Settings "flight_model"): the realistic one
## integrates real forces (gravity, rotor thrust along the body, drag, inertia in the
## turns); the easy one is a drone that hovers by itself and flies where the nose points. Reads `input` every physics tick and never touches Input directly,
## so the same code runs for local players, bots and (later) network peers.

signal bumped(impact: float)
signal fired(weapon: String)  ## rockets, missiles, flares, mines, smoke
signal hit_taken(impulse: Vector3, shooter: Choppa)
signal scored_hit(target: Choppa)
signal gun_overheated
signal damaged(amount: float, attacker: Choppa)
signal part_damaged(part: Part, left: float)  ## A rotor, the tail rotor or the engine took a hit.
signal part_wrecked(part: Part, by: Choppa)  ## It just reached zero; `by` did it (or null).
signal wrecked_part(target: Choppa, part: Part)  ## On the shooter: we wrecked target's part.
signal died(killer: Choppa)
signal healed(amount: float)
signal restocked

## Distance from the body origin to the bottom of the skids.
const GROUND_CLEARANCE := 1.15
const SPOOL_UP_TIME := 3.5  ## Seconds from a cold engine to flight rpm.
const SPOOL_DOWN_TIME := 7.0  ## Rotor run-down after switching off.
const LIFT_FROM_SPOOL := 0.55  ## Below this share of flight rpm the rotor gives no lift.
const AUTOROTATION_SINK := 11.0  ## Easy model: how fast you come down with the engine off.
const BOUNCE_IMPACT := 10.0
const GRAVITY := 9.81

## Where a hit lands. HULL is everything that only costs health; the others also wreck
## something: ROTOR shakes and loses lift, TAIL spins you, ENGINE loses power.
enum Part { HULL, ROTOR, TAIL, ENGINE }
const DODGE_ROLL_RATE := 2.2  ## rad/s: rolling this fast throws off bullets and missiles (full stick is 2.8).
const LEVEL_GAIN := 2.5  ## Flight assist: rate per radian of tilt that brings the body level.
const GROUND_EFFECT := 0.08  ## Extra thrust fraction right above the ground...
const GROUND_EFFECT_HEIGHT := 6.0  ## ...fading out by this altitude.
## Translational lift: the rotor works better in clean air, so forward speed adds up to
## this fraction of thrust (reached at ETL_SPEED). You need less collective once moving.
const TRANSLATIONAL_LIFT := 0.12
const ETL_SPEED := 25.0
const GUN_INTERVAL := 0.08  ## Seconds between shots.
const GUN_HEAT_PER_SHOT := 0.0135  ## About 6 s of continuous fire to overheat.
const GUN_COOL_RATE := 0.6  ## Heat lost per second when not firing.
const GUN_SPREAD := 0.003  ## Cone half-angle (radians) with cold barrels.
const GUN_BLOOM := 0.022  ## Extra cone at full heat: bursts beat holding the trigger.
const GUN_RECOIL := 1.4  ## m/s per second of firing, against the nose: you feel a long burst.
const AIM_ASSIST_ANGLE := deg_to_rad(12.0)  ## Horizontal cone that snaps bullets.
const AIM_ASSIST_PITCH := deg_to_rad(35.0)
const AIM_ASSIST_RANGE := 160.0
const MAX_HEALTH := 100.0
const CRASH_DAMAGE_FROM := 8.0  ## Impacts (m/s into the obstacle) harder than this hurt.
const CRASH_DAMAGE_PER_MS := 2.0  ## Hull damage per m/s above that.
const TAIL_TORQUE := 2.2  ## rad/s the body spins with the tail rotor gone, at hover thrust.
const VIBRATION := 0.9  ## rad/s of shaking with the main rotor wrecked.
## Damage each part takes before it is wrecked. The hull is `health`.
const PART_HEALTH := {Part.ROTOR: 40.0, Part.TAIL: 30.0, Part.ENGINE: 50.0}
const SPAWN_SHIELD := 2.0  ## Seconds of invulnerability after respawning.
const MISSILE_CONE := deg_to_rad(45.0)
const MISSILE_RANGE := 250.0
## A crash this soon after being shot counts as a kill for whoever shot you.
const CRASH_CREDIT_TIME := 4.0
## Seconds between shots while the trigger is held, per weapon.
const WEAPON_INTERVAL := {"rockets": 0.22, "missiles": 1.5, "flares": 1.0, "mines": 1.0, "smoke": 1.0}
const DECOY_TIME := 2.0  ## Seconds a flare burst fools missiles.
const CRASH_WINDOW := 0.4  ## Seconds between crash damage events while scraping along.
const SKID_FRICTION := 4.0  ## How fast horizontal speed bleeds off with the skids on the ground, per second.
@export var team_color := Color(0.95, 0.5, 0.1)
@export var pilot_name := "Pilot"
var aim_assist := true  ## Guns snap onto a target in the cone; the player can turn it off in the settings.
@export var local_player := false  ## Hide own model from the cockpit camera.

@export_group("Flight")
@export var hover_thrust := 9.81  ## Rotor thrust at collective 0: holds a level hover.
@export var collective_range := 0.5  ## Collective +-1 adds or takes this fraction of hover thrust.
@export var pitch_rate := 2.0  ## rad/s at full stick.
@export var roll_rate := 2.8
@export var yaw_rate := 1.6
@export var angular_accel := 7.0  ## How fast the rates follow the stick: the inertia you feel.
## Drag per body axis (x across, y up, z along the nose), times speed squared. Lower
## along the nose, so the choppa flies best the way it points and drifts in a slide.
@export var drag := Vector3(0.016, 0.016, 0.0065)
@export var afterburner_thrust := 22.0  ## Extra acceleration along the nose while burning.
@export var boost_drain := 0.5  ## Afterburner charge used per second...
@export var boost_recharge := 0.2  ## ...and regained per second when off.
@export var max_speed := 36.0  ## About the level top speed at a 35 degree nose-down (bots, docs).
@export var boost_speed := 60.0  ## About the top speed with the afterburner (camera, visuals).
@export var max_altitude := 140.0
## Rotor thrust follows the collective with this time constant (seconds): the weight you
## feel when you pull power.
@export var thrust_lag := 0.35

@export_group("Easy model")
@export var easy_accel := 28.0  ## m/s^2 toward the wished velocity.
@export var climb_speed := 16.0
@export var climb_accel := 45.0
@export var turn_speed := 2.4  ## rad/s
@export var turn_accel := 14.0
@export var aim_rate := 2.0  ## rad/s the nose pitches at full stick (held where you leave it).
@export var aim_limit := 0.8  ## rad; the easy model never points more than ~45 degrees up or down.

var input := PilotInput.new()
var heading := 0.0  ## Yaw in radians; 0 faces -Z. Derived from the body each tick.
var turn_rate := 0.0  ## Yaw rate, rad/s (positive turns left).
var rates := Vector3.ZERO  ## Body rotation rates: x pitch (nose up), y yaw (left), z roll (left).
var flight_assist := false  ## Level out and hold height when the stick is centred (a setting).
var easy := false  ## The easy flight model (a setting): no gravity, auto-hover, fly where you look.
var _thrust := GRAVITY  ## Current rotor thrust; follows the collective with `thrust_lag`.
var _aim := 0.0  ## Easy model: nose-down angle set by the stick, held.
var _crash_cooldown := 0.0  ## Grinding along terrain hurts once per window, not every tick.
var boost_meter := 1.0  ## Afterburner charge, 0..1.
var stun := 0.0
var locked := false  ## Ignores input, e.g. during a race countdown.
var altitude := 500.0  ## Height of the skids above whatever is below.
var heat := 0.0  ## Gun heat, 0..1.
var overheated := false
var health := MAX_HEALTH
var parts := {}  ## Part -> health left; see PART_HEALTH.
var alive := true
var mortal := true  ## False in races: hits still push, but never hurt.
## The helicopter class (Airframe). Set before adding the choppa, or with set_airframe().
var airframe := Airframe.SCOUT
var camo := "factory"  ## Progression.CAMOS id; set before adding the choppa, or model.set_camo().
var max_health := MAX_HEALTH
var clearance := GROUND_CLEARANCE  ## Body origin to skid bottom for this airframe.
## The engine is running or starting; off, the rotor winds down. Matches start cold on
## the ground (owner: "players should start on the ground", like Wardogs).
var engine_on := true
var spool := 1.0  ## Rotor rpm as a share of flight rpm, 0..1. Lift and control follow it.
var _engine_held := false
var spool_up_time := SPOOL_UP_TIME  ## Per class (Airframe "spool").
var gun_interval := GUN_INTERVAL  ## Seconds between rounds, per class.
var recoil := GUN_RECOIL  ## Per class.
var gun_factor := 1.0  ## Machine-gun damage multiplier of the airframe.
## Rounds left: rockets, missiles, flares, mines, smoke. Refilled at service stations.
var ammo := {"gun": 0, "rockets": 0, "missiles": 0, "flares": 0, "mines": 0, "smoke": 0}
var decoy_time := 0.0  ## Seconds left that flares fool missiles.
var invulnerable := 0.0
var clock := 0.0  ## Simulation seconds this choppa has existed.
var last_shot_time := -10.0  ## `clock` at the last shot, for the muzzle flash.
var last_shot_side := 1.0  ## Which gun fired it: -1 left, 1 right.
var over_water := false  ## The ground below is water (for spray instead of dust).
## False on a network client: the server decides damage, repairs and deaths, and the
## client only shows what its snapshots say (NetGame).
var authority := true
var replaying := false  ## A client re-running inputs after a correction: no shots, no visuals.


var model: ChoppaModel

var _cooldowns := {"rockets": 0.0, "missiles": 0.0, "flares": 0.0, "mines": 0.0, "smoke": 0.0}
var _rocket_side := 1.0
var _part_scale := 1.0
var _tick := 1.0 / 60.0  ## The current step's delta, for code that runs inside it.
var _gun_timer := 0.0
var _gun_side := 1.0
var _shots := 0  ## Rounds fired, for the spread pattern.
var _shape: CollisionShape3D
var _last_attacker: Choppa
var _last_attacker_time := -100.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_repair_all()
	restock()
	heading = rotation.y
	add_to_group("choppas")

	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.1
	capsule.height = 5.4
	_shape = CollisionShape3D.new()
	_shape.shape = capsule
	_shape.rotation_degrees.x = 90.0
	_shape.position.z = 0.3  # Cabin nose 2.4 m ahead of the centre; covers the tail cone.
	add_child(_shape)

	model = ChoppaModel.new()
	model.color = team_color
	model.own = local_player
	model.pilot = self
	model.airframe = airframe
	model.camo = camo
	add_child(model)
	set_airframe(airframe)


func _physics_process(delta: float) -> void:
	step(delta)


func is_boosting() -> bool:
	return input.boost and boost_meter > 0.0 and stun <= 0.0


func facing() -> Basis:
	return Basis(Vector3.UP, heading)


## Advances the simulation by one tick.
func step(delta: float) -> void:
	_tick = delta
	clock += delta
	if not alive:
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	decoy_time = maxf(0.0, decoy_time - delta)
	var i := input
	if stun > 0.0:
		stun -= delta
		i = PilotInput.new()
	if locked:
		i = PilotInput.new()

	_update_engine(i, delta)
	if not replaying:
		_update_gun(i, delta)
		_update_weapons(i, delta)
	# Recoil, here rather than in _update_gun so a network replay (which skips the gun)
	# still feels it and the prediction stays right.
	if i.fire and not overheated and ammo.gun > 0:
		velocity += global_transform.basis.z * recoil * delta
	_crash_cooldown = maxf(0.0, _crash_cooldown - delta)
	if easy:
		_step_easy(i, delta)
		return

	# Attitude: the stick asks for rotation rates and the body follows with some inertia.
	# Nothing pulls the nose back by itself unless flight assist is on.
	var wanted := Vector3(-i.cyclic.y * pitch_rate, -i.yaw * yaw_rate, -i.cyclic.x * roll_rate)
	if flight_assist and i.cyclic.is_zero_approx():
		wanted.x += nose_down() * LEVEL_GAIN
		wanted.z += bank_right() * LEVEL_GAIN
	# Damage: a wrecked tail rotor leaves the main rotor's torque unopposed, so the body
	# spins and the pedals do little; a chewed-up main rotor shakes the whole machine.
	var tail := wear(Part.TAIL)
	var rotor := wear(Part.ROTOR)
	var engine := wear(Part.ENGINE)
	wanted.y = wanted.y * (1.0 - 0.75 * tail) - TAIL_TORQUE * tail * tail * (1.0 + i.collective * collective_range)
	if rotor > 0.0:
		wanted.x += sin(clock * 31.0) * VIBRATION * rotor
		wanted.z += sin(clock * 23.0 + 1.0) * VIBRATION * rotor
	var lift := lift_share()
	wanted *= lift  # No rotor rpm, no control: a parked choppa does not wobble on its skids.
	rates = rates.move_toward(wanted, angular_accel * delta)
	var b := (global_transform.basis * Basis.from_euler(rates * delta)).orthonormalized()
	turn_rate = rates.y
	var forward := -b.z
	if Vector2(forward.x, forward.z).length() > 0.05:
		heading = atan2(-forward.x, -forward.z)

	# Forces: gravity, rotor thrust along the body's up axis, the afterburner along the
	# nose, and drag that is lower along the body than across it.
	var wanted_thrust := hover_thrust * (1.0 + i.collective * collective_range)
	if flight_assist:
		wanted_thrust /= clampf(b.y.y, 0.5, 1.0)  # Hold height when tilted.
	wanted_thrust *= 1.0 + GROUND_EFFECT * clampf(1.0 - altitude / GROUND_EFFECT_HEIGHT, 0.0, 1.0)
	wanted_thrust *= 1.0 + TRANSLATIONAL_LIFT * clampf(Vector2(velocity.x, velocity.z).length() / ETL_SPEED, 0.0, 1.0)
	wanted_thrust *= (1.0 - 0.15 * rotor) * (1.0 - 0.35 * engine)  # Damaged lift and power.
	# A winding-down rotor still bites a little (autorotation); a cold one does not.
	wanted_thrust *= lift if engine_on else maxf(lift, 0.55 * spool)
	_thrust = lerpf(_thrust, wanted_thrust, 1.0 - exp(-delta / thrust_lag))
	var thrust := _thrust
	var accel := b.y * thrust + Vector3.DOWN * GRAVITY
	if is_boosting() and engine < 1.0 and lift > 0.9:
		boost_meter = maxf(0.0, boost_meter - boost_drain * delta)
		accel += forward * afterburner_thrust
	elif not i.boost:
		boost_meter = minf(1.0, boost_meter + boost_recharge * delta)
	var local_v := b.inverse() * velocity
	accel += b * Vector3(-local_v.x * absf(local_v.x) * drag.x, -local_v.y * absf(local_v.y) * drag.y,
		-local_v.z * absf(local_v.z) * drag.z)
	velocity += accel * delta
	if global_position.y > max_altitude:
		velocity.y = minf(velocity.y, 0.0)

	global_transform.basis = b
	var before := velocity
	move_and_slide()
	_handle_collisions(before)
	_update_altitude()
	if not replaying:
		model.update_pose(self, delta)


## The easy model: a drone with no gravity that hovers when you let go. The mouse (or
## the right stick) aims the nose, and the move stick flies along it, so pointing the
## nose down and pushing forward descends. Momentum comes from easing toward the wish.
func _step_easy(i: PilotInput, delta: float) -> void:
	var tail := wear(Part.TAIL)
	var rotor := wear(Part.ROTOR)
	var engine := wear(Part.ENGINE)
	var lift := lift_share()
	var yaw_wish := (-i.yaw * turn_speed * (1.0 - 0.75 * tail) - TAIL_TORQUE * tail * tail) * lift
	turn_rate = move_toward(turn_rate, yaw_wish, turn_accel * delta)
	heading = wrapf(heading + turn_rate * delta, -PI, PI)
	_aim = clampf(_aim + i.cyclic.y * aim_rate * delta, -aim_limit, aim_limit)
	rates = Vector3(0.0, turn_rate, 0.0)

	var boosting := is_boosting() and engine < 1.0 and lift > 0.9
	var top := max_speed * (1.0 - 0.15 * rotor) * (1.0 - 0.35 * engine) * lift
	if boosting:
		boost_meter = maxf(0.0, boost_meter - boost_drain * delta)
		top = boost_speed
	elif not i.boost:
		boost_meter = minf(1.0, boost_meter + boost_recharge * delta)
	var nose := Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, -_aim)
	var wish := nose * Vector3(0.0, 0.0, -i.move.y) + facing() * Vector3(i.move.x, 0.0, 0.0)
	if boosting:
		wish += nose * Vector3.FORWARD  # The afterburner always drives you along the nose.
	wish = wish.limit_length(1.0)
	var rate := easy_accel * (2.0 if boosting else 1.0)
	if wish.length_squared() < 0.01 or velocity.length() > top:
		rate = easy_accel * 0.6
	var climb := i.collective * climb_speed * (1.0 - 0.35 * engine) - 6.0 * engine * engine
	climb = lerpf(-AUTOROTATION_SINK, climb, lift)  # Engine off: you come down.
	var wanted := wish * top + Vector3.UP * climb
	# Horizontal and vertical ease separately, so a climb does not wait for the run-on to bleed off.
	var level := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(wanted.x, 0.0, wanted.z), rate * delta)
	velocity = level + Vector3.UP * move_toward(velocity.y, wanted.y, climb_accel * delta)
	if global_position.y > max_altitude:
		velocity.y = minf(velocity.y, 0.0)

	# The body leans into the motion, like a real one would have to.
	var local_v := facing().inverse() * velocity
	var lean_pitch := clampf(local_v.z / boost_speed, -1.0, 1.0) * 0.35
	var bank := clampf(-local_v.x / boost_speed, -1.0, 1.0) * 0.5 + turn_rate * 0.12
	if rotor > 0.0:
		lean_pitch += sin(clock * 31.0) * 0.05 * rotor
		bank += sin(clock * 23.0 + 1.0) * 0.05 * rotor
	global_transform.basis = Basis.from_euler(Vector3(lean_pitch - _aim, heading, bank))
	var before := velocity
	move_and_slide()
	_handle_collisions(before)
	_update_altitude()
	if not replaying:
		model.update_pose(self, delta)


## How much of its lift the rotor can give at the current rpm, 0..1.
func lift_share() -> float:
	return smoothstep(LIFT_FROM_SPOOL, 1.0, spool)


## The engine key toggles it; on the ground, asking for lift starts it too, so nobody
## has to know the key to take off. The rotor spools up and runs down over seconds.
func _update_engine(i: PilotInput, delta: float) -> void:
	if i.engine and not _engine_held:
		engine_on = not engine_on
	_engine_held = i.engine
	if not engine_on and altitude < 0.8 and (i.collective > 0.3 or i.boost):
		engine_on = true
	var target := 1.0 if engine_on else 0.0
	spool = move_toward(spool, target, delta / (spool_up_time if target > spool else SPOOL_DOWN_TIME))


## Pitch of the nose below the horizon, radians (negative: nose up).
func nose_down() -> float:
	return -asin(clampf(-global_transform.basis.z.y, -1.0, 1.0))


## Bank to the right, radians (negative: left).
func bank_right() -> float:
	return -asin(clampf(global_transform.basis.x.y, -1.0, 1.0))


## Rolling fast enough to throw off bullets and missiles.
func is_rolling_hard() -> bool:
	return not easy and absf(rates.z) > DODGE_ROLL_RATE


## The choppa that aim assist would shoot at right now, or null.
func aim_target() -> Choppa:
	if not aim_assist:
		return null
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


## Called by a bullet. `at` is where it struck (world space); a hit on the tail rotor,
## main rotor or engine wrecks that part and costs less hull. Returns false when dodged.
func take_hit(impulse: Vector3, shooter: Choppa, amount := 0.0, at := Vector3.INF) -> bool:
	if not alive or is_rolling_hard():
		return false
	velocity += impulse
	hit_taken.emit(impulse, shooter)
	var part := part_at(at) if at.is_finite() else Part.HULL
	if part == Part.HULL:
		damage(amount, shooter)
	else:
		damage_part(part, amount, shooter)
		damage(amount * 0.6, shooter)
	return true


## A blast centred at `from`: full hull damage, and the part nearest the blast suffers.
func blast_damage(amount: float, attacker: Choppa, from: Vector3) -> void:
	var part := part_at(from)
	if part != Part.HULL:
		damage_part(part, amount * 0.8, attacker)
	damage(amount, attacker)


## Which part a world position is closest to, by where it sits on the body: the cabin
## reaches about 1 m behind the centre, the engine sits on top behind it, the tail boom
## runs on from there (the collision capsule ends at z = 3), the rotor is above it all.
func part_at(at: Vector3) -> Part:
	var local := to_local(at)
	if local.z > 2.2:
		return Part.TAIL
	if local.y > 1.1:
		return Part.ROTOR
	if local.z > 0.6 and local.y > 0.3:
		return Part.ENGINE
	return Part.HULL


func damage_part(part: Part, amount: float, by: Choppa = null) -> void:
	if not authority or part == Part.HULL or not alive or not mortal or invulnerable > 0.0 or amount <= 0.0:
		return
	var before: float = parts[part]
	parts[part] = maxf(0.0, parts[part] - amount)
	part_damaged.emit(part, parts[part])
	if before > 0.0 and parts[part] <= 0.0:
		part_wrecked.emit(part, by)
		if by and by != self:
			by.wrecked_part.emit(self, part)


## How wrecked a part is: 0 intact .. 1 gone.
func wear(part: Part) -> float:
	return 1.0 - parts[part] / part_max(part)


## How much damage this airframe's part takes before it is wrecked.
func part_max(part: Part) -> float:
	return PART_HEALTH[part] * _part_scale


func _repair_all() -> void:
	for part: Part in PART_HEALTH:
		parts[part] = part_max(part)


func damage(amount: float, attacker: Choppa) -> void:
	if not authority or not alive or not mortal or invulnerable > 0.0 or amount <= 0.0:
		return
	if attacker and attacker != self:
		_last_attacker = attacker
		_last_attacker_time = clock
	health -= amount
	damaged.emit(amount, attacker)
	if health <= 0.0:
		_die(attacker)


func heal(amount: float) -> bool:
	if not authority or not alive or not needs_repair():
		return false
	var before := health
	health = minf(max_health, health + amount)
	for part: Part in PART_HEALTH:
		parts[part] = minf(part_max(part), parts[part] + amount * _part_scale)
	healed.emit(health - before)
	return true


## A share of a full repair (a service station calls this every tick it works on you).
func repair(fraction: float) -> void:
	if not authority or not alive:
		return
	var before := health
	health = minf(max_health, health + max_health * fraction)
	for part: Part in PART_HEALTH:
		parts[part] = minf(part_max(part), parts[part] + part_max(part) * fraction)
	if health > before:
		healed.emit(health - before)


func needs_repair() -> bool:
	if health < max_health:
		return true
	for part: Part in PART_HEALTH:
		if parts[part] < part_max(part):
			return true
	return false


## Full loadout for the airframe (a service station, or a respawn).
func restock() -> void:
	var spec := Airframe.spec(airframe)
	ammo = {"gun": spec.rounds, "rockets": spec.rockets, "missiles": spec.missiles, "flares": spec.flares,
		"mines": 1, "smoke": 1}
	restocked.emit()


## Rounds the airframe carries of `weapon` when full.
func full_ammo(weapon: String) -> int:
	var spec := Airframe.spec(airframe)
	if weapon == "gun":
		return spec.rounds
	return spec.get(weapon, 1) if weapon in ["rockets", "missiles", "flares"] else 1


## Anything short of a full loadout (what an ammo station fixes).
func needs_ammo() -> bool:
	for weapon: String in ammo:
		if ammo[weapon] < full_ammo(weapon):
			return true
	return false


## Turns this choppa into one of the Airframe classes: numbers, hull, loadout, size.
func set_airframe(id: String) -> void:
	airframe = id
	var spec := Airframe.spec(id)
	max_health = spec.hull
	health = max_health
	_part_scale = spec.parts
	pitch_rate = 2.0 * spec.rates
	roll_rate = 2.8 * spec.rates
	yaw_rate = 1.6 * spec.rates
	turn_speed = 2.4 * spec.rates
	angular_accel = 7.0 * spec.inertia
	thrust_lag = spec.thrust_lag
	max_speed = 36.0 * spec.speed
	boost_speed = 60.0 * spec.speed
	afterburner_thrust = 22.0 * spec.speed
	gun_factor = spec.guns
	gun_interval = GUN_INTERVAL * spec.fire
	recoil = GUN_RECOIL * spec.recoil
	spool_up_time = spec.spool
	climb_speed = 16.0 * spec.climb
	collective_range = 0.5 * spec.climb
	easy_accel = 28.0 * spec.inertia
	turn_accel = 14.0 * spec.inertia
	clearance = GROUND_CLEARANCE * spec.size
	if _shape:
		var capsule := _shape.shape as CapsuleShape3D
		capsule.radius = 1.1 * spec.size
		capsule.height = 5.4 * spec.size
	if model:
		model.set_airframe(id)
	_repair_all()
	restock()


func _die(killer: Choppa) -> void:
	_wreck()
	died.emit(killer)


## The visible part of dying: also what a network client does when a snapshot says so.
func _wreck() -> void:
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	model.visible = false
	_shape.set_deferred("disabled", true)
	var boom := Effects.Explosion.new()
	get_parent().add_child(boom)
	boom.global_position = global_position


## Network client: the server says this choppa was shot down.
func net_wreck() -> void:
	if alive:
		_wreck()


func _update_weapons(i: PilotInput, delta: float) -> void:
	for weapon: String in _cooldowns:
		_cooldowns[weapon] = maxf(0.0, _cooldowns[weapon] - delta)
	if i.rockets:
		fire_rocket()
	if i.missile:
		fire_missile()
	if i.flares:
		fire_flares()
	if i.mine:
		drop_mine()
	if i.smoke:
		drop_smoke()


## True when `weapon` has a round and its interval has passed; uses up the round.
func _take(weapon: String) -> bool:
	if not alive or ammo[weapon] <= 0 or _cooldowns[weapon] > 0.0:
		return false
	ammo[weapon] -= 1
	_cooldowns[weapon] = WEAPON_INTERVAL[weapon]
	fired.emit(weapon)
	return true


## One unguided rocket from the pods, alternating sides, straight along the nose.
func fire_rocket() -> bool:
	if not _take("rockets"):
		return false
	var rocket := Weapons.Rocket.new()
	rocket.shooter = self
	rocket.direction = -global_transform.basis.z
	rocket.speed = Weapons.Rocket.SPEED + maxf(0.0, velocity.dot(rocket.direction))
	var pod := Vector3(1.45 * _rocket_side, -0.9, -1.4)
	if model and model.pods.size() == 2:
		pod = model.pods[0 if _rocket_side < 0.0 else 1]
	_drop(rocket, pod, true)
	_rocket_side = -_rocket_side
	return true


## A homing missile at whoever is in the missile cone, or straight ahead.
func fire_missile() -> bool:
	if not _take("missiles"):
		return false
	var missile := Weapons.Missile.new()
	missile.shooter = self
	missile.target = missile_target()
	missile.direction = -global_transform.basis.z
	_drop(missile, Vector3(0.0, -0.6, -3.0), true)
	return true


## Flares: every missile chasing this choppa loses it, and for DECOY_TIME new ones do too.
func fire_flares() -> bool:
	if not _take("flares"):
		return false
	decoy_time = DECOY_TIME
	for node in get_tree().get_nodes_in_group("missiles"):
		var missile := node as Weapons.Missile
		if missile.is_hunting(self):
			missile.shake_off()
	var flares := Weapons.Flares.new()
	flares.carrier = self
	_drop(flares, Vector3(0.0, -0.8, 1.5))
	return true


func drop_mine() -> bool:
	if not _take("mines"):
		return false
	var mine := Weapons.Mine.new()
	mine.owner_choppa = self
	_drop(mine, Vector3(0.0, -1.0, 9.0))
	return true


func drop_smoke() -> bool:
	if not _take("smoke"):
		return false
	_drop(Weapons.SmokeCloud.new(), Vector3(0.0, 0.0, 10.0))
	return true


## Puts a weapon object into the world at `offset` in this choppa's frame (-Z ahead):
## the body frame for things fired along the nose, the yaw frame for things dropped.
func _drop(thing: Node3D, offset: Vector3, along_body := false) -> void:
	get_parent().add_child(thing)
	thing.global_position = global_position + (global_transform.basis if along_body else facing()) * offset
	thing.reset_physics_interpolation()


## Respawn standing on the ground at `at` (a point on the ground), skids down; `cold`
## with the engine off, as at the start of a match.
func spawn_on_ground(at: Transform3D, cold := false) -> void:
	respawn(Transform3D(at.basis, at.origin + Vector3.UP * (clearance + 0.05)))
	if cold:
		engine_on = false
		spool = 0.0
		_thrust = 0.0


func respawn(at: Transform3D) -> void:
	global_position = at.origin
	engine_on = true
	spool = 1.0
	heading = at.basis.get_euler().y
	global_transform.basis = Basis(Vector3.UP, heading)
	velocity = Vector3.ZERO
	turn_rate = 0.0
	rates = Vector3.ZERO
	_thrust = GRAVITY
	_aim = 0.0
	stun = 0.0
	heat = 0.0
	overheated = false
	decoy_time = 0.0
	if not alive:
		alive = true
		_shape.set_deferred("disabled", false)
	health = max_health
	_repair_all()
	restock()
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
	if not i.fire or ammo.gun <= 0:
		heat = maxf(0.0, heat - GUN_COOL_RATE * delta)
		return
	if _gun_timer > 0.0:
		return
	ammo.gun -= 1
	_shoot()
	_gun_timer = gun_interval
	heat += GUN_HEAT_PER_SHOT * gun_interval / GUN_INTERVAL
	if heat >= 1.0:
		heat = 1.0
		overheated = true
		gun_overheated.emit()


func _shoot() -> void:
	var offset := Vector3(1.12 * _gun_side, -0.8, -2.35)
	if model and model.muzzles.size() == 2:
		offset = model.muzzles[0 if _gun_side < 0.0 else 1]
	var muzzle := global_position + global_transform.basis * offset
	last_shot_side = _gun_side
	_gun_side = -_gun_side
	var target := aim_target()
	var direction := -global_transform.basis.z
	if target:
		direction = (target.global_position - muzzle).normalized()
	# Bloom: the hotter the barrels, the wider the cone. A fixed spiral rather than random
	# numbers, so server and client agree on every round.
	_shots += 1
	var cone := GUN_SPREAD + GUN_BLOOM * heat
	var angle := _shots * 2.39996
	var off := sqrt(fposmod(_shots * 0.618034, 1.0)) * cone
	var side := direction.cross(Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT).normalized()
	direction = (direction + (side * cos(angle) + side.cross(direction) * sin(angle)) * off).normalized()
	last_shot_time = clock
	var bullet := Bullet.new()
	bullet.shooter = self
	bullet.damage *= gun_factor
	bullet.direction = direction
	# Bullets inherit your speed so they never fall behind you while boosting.
	bullet.speed = Bullet.SPEED + maxf(0.0, velocity.dot(direction))
	get_parent().add_child(bullet)
	bullet.global_position = muzzle
	bullet.reset_physics_interpolation()


func _handle_collisions(before: Vector3) -> void:
	var impact := 0.0
	var normal := Vector3.ZERO
	var where := global_position
	for k in get_slide_collision_count():
		var collision := get_slide_collision(k)
		var hit := -before.dot(collision.get_normal())
		if hit > impact:
			impact = hit
			normal = collision.get_normal()
			where = collision.get_position()
	if impact <= 0.0:
		return
	var is_ground := normal.y > 0.7
	if is_ground:
		# Skids on the ground: only the sink rate counts, and the skids drag you to a stop.
		impact = maxf(0.0, -before.y)
		var braking := exp(-SKID_FRICTION * _tick)
		velocity.x *= braking
		velocity.z *= braking
		# Resting on the skids: the ground takes the weight. Without this the floating body
		# kept gathering downward speed while parked and had to burn it off before lifting.
		velocity.y = maxf(velocity.y, 0.0)
	if impact > BOUNCE_IMPACT and not is_ground:
		velocity = before.bounce(normal) * 0.45
		stun = clampf(impact / 60.0, 0.15, 0.5)
		rates *= 0.3  # The knock takes most of the spin out.
		bumped.emit(impact)
	if impact > CRASH_DAMAGE_FROM and _crash_cooldown <= 0.0:
		_crash_cooldown = CRASH_WINDOW
		var credit := _last_attacker if clock - _last_attacker_time < CRASH_CREDIT_TIME else null
		var excess := impact - CRASH_DAMAGE_FROM
		# Whatever struck first takes the brunt: tail strikes wreck the tail rotor, and a
		# body tilted this far has its blades in the obstacle too.
		var part := part_at(where)
		if part != Part.HULL:
			damage_part(part, excess * 3.0, credit)
		if absf(bank_right()) > 0.6 or absf(nose_down()) > 0.6:
			damage_part(Part.ROTOR, excess * 2.0, credit)
		damage(excess * CRASH_DAMAGE_PER_MS, credit)

func _update_altitude() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 500.0
	)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		altitude = global_position.y - hit.position.y - clearance
		over_water = (hit.collider as Node).is_in_group("water")
	else:
		altitude = 500.0
		over_water = false
