class_name ChaseCamera
extends Camera3D
## Follows a choppa from right behind, or from the cockpit in first-person mode.

@export var target: Choppa
@export var first_person := false
@export var showcase := false  ## Fixed three-quarter front view, for screenshots.
## Camera moves for recording a video (`--cam=`): "orbit" circles the choppa, "side"
## tracks it from beside and ahead, "low" watches from the ground, "fp_look" sits in the
## cockpit and looks slowly round it.
@export var cinematic := ""

@export var distance := 8.5
@export var height := 2.6
@export var look_ahead := 6.0
@export var follow_sharpness := 6.0  ## Lower is lazier: the camera trails the body a touch, for weight.
@export var base_fov := 70.0
@export var speed_fov := 18.0  ## Extra FOV at boost speed.

var _ready_to_follow := false
var _trauma := 0.0  ## Camera shake, 0..1; decays. Felt as its square.
var _shake_noise := FastNoiseLite.new()
var _shake_time := 0.0
var _kick := 0.0  ## Recoil from our own gun: a short punch per round, gone in a blink.
var _last_shot := -10.0
var _fov := 70.0  ## The field of view before the recoil punch.
var look := Vector2.ZERO  ## Free look: yaw (x, left) and pitch (y, up) away from ahead, radians.
var fixed_look := Vector2.INF  ## Screenshots (--look=yaw,pitch in degrees): hold the head turned so.
var _cine_time := 0.0
var _killer: Choppa  ## Kill cam: who shot us down, watched until we respawn.
var _cine_spot := Vector3.INF  ## "low": where the camera stands.

const LOOK_GAIN := 0.004  ## Radians per pixel of mouse travel.
const LOOK_YAW := 2.6  ## About 150 degrees each way.
const LOOK_PITCH := 1.1


func _ready() -> void:
	near = 0.1
	far = 8000.0  # The mountain backdrop is kilometres away.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("shake_cameras")
	_shake_noise.frequency = 2.0
	if target:
		target.damaged.connect(func(amount: float, _attacker: Choppa) -> void: _trauma += amount * 0.025)
		target.died.connect(func(killer: Choppa) -> void: _killer = killer if killer != target else null)


## Free look (held key): the mouse turns the view; let go and it swings back ahead.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_action_pressed("free_look"):
		var rel := (event as InputEventMouseMotion).relative
		look = Vector2(clampf(look.x - rel.x * LOOK_GAIN, -LOOK_YAW, LOOK_YAW),
			clampf(look.y - rel.y * LOOK_GAIN, -LOOK_PITCH, LOOK_PITCH))


## An explosion of the given size went off at `at`: shake if it's close.
func shake_from(at: Vector3, size: float) -> void:
	var near_ratio := 1.0 - global_position.distance_to(at) / (70.0 * size)
	_trauma = minf(1.0, _trauma + clampf(near_ratio, 0.0, 1.0) * 0.9 * size)


func _apply_shake(delta: float) -> void:
	var setting: float = Settings.SHAKE_AMOUNTS[Settings.choice("camera_shake")]
	rotate_object_local(Vector3.RIGHT, _kick * 0.0045 * setting)  # The nose bucks up per round.
	_trauma = maxf(0.0, _trauma - delta * 1.4)
	if _trauma <= 0.0:
		return
	_shake_time += delta * 30.0
	var amount: float = _trauma * _trauma * setting
	rotate_object_local(Vector3.RIGHT, _shake_noise.get_noise_1d(_shake_time) * 0.06 * amount)
	rotate_object_local(Vector3.UP, _shake_noise.get_noise_1d(_shake_time + 100.0) * 0.06 * amount)
	rotate_object_local(Vector3.BACK, _shake_noise.get_noise_1d(_shake_time + 200.0) * 0.08 * amount)


func toggle_mode() -> void:
	first_person = not first_person
	_ready_to_follow = false


func _process(delta: float) -> void:
	if target == null:
		return
	if not target.alive and _killer and is_instance_valid(_killer) and _killer.alive:
		_kill_cam(delta)
		return
	if _killer and target.alive:
		_killer = null
		_ready_to_follow = false  # Back behind our own choppa at once.
	var speed_ratio := clampf(target.velocity.length() / target.boost_speed, 0.0, 1.2)
	var wanted := base_fov if showcase else Settings.number("fov")
	_fov = lerpf(_fov, wanted + speed_fov * speed_ratio, 1.0 - exp(-4.0 * delta))
	# Every round punches the view: instant, then gone within a tenth of a second, so
	# the gun feels heavy without blurring your aim. A long burst adds a rumble.
	if target.last_shot_time > _last_shot:
		_last_shot = target.last_shot_time
		# A heavier gun kicks harder.
		_kick = minf(_kick + target.recoil / Choppa.GUN_RECOIL, 2.5)
		_trauma = minf(_trauma + 0.05, 0.38)
	_kick *= exp(-22.0 * delta)
	fov = _fov + _kick * 1.1 * Settings.SHAKE_AMOUNTS[Settings.choice("camera_shake")]

	_cine_time += delta
	if fixed_look != Vector2.INF:
		look = fixed_look
	elif cinematic == "fp_look":
		# Down at the panel, round to the left, across to the right, back ahead.
		look = Vector2(sin(_cine_time * 0.45) * 1.1, -0.35 + 0.3 * cos(_cine_time * 0.3))
	elif not InputMap.has_action("free_look") or not Input.is_action_pressed("free_look"):
		look = look.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	if target.model.cockpit_view:
		target.model.cockpit_view.reticle.visible = first_person
	if first_person:
		# Rigidly mounted: you feel every roll and flip. Free look turns your head.
		cull_mask = ~ChoppaModel.OWN_LAYER & 0xFFFFF
		global_transform = target.model.cockpit.get_global_transform_interpolated()
		rotate_object_local(Vector3.UP, look.x)
		rotate_object_local(Vector3.RIGHT, look.y * 0.8)
		_apply_shake(delta)
		return

	cull_mask = 0xFFFFF
	# Follow the heading only: the body pitches and rolls, the chase camera stays level.
	var body := Transform3D(target.facing(), target.get_global_transform_interpolated().origin)
	if showcase:
		global_position = body.origin + body.basis * Vector3(7.0, 1.2, -8.0)
		look_at(body.origin + Vector3.UP * 0.5, Vector3.UP)
		_apply_shake(delta)
		return
	if cinematic in ["orbit", "side", "low"]:
		_cinematic_move(body, delta)
		_apply_shake(delta)
		return
	var reach: float = Airframe.spec(target.airframe).camera * Settings.CAMERA_DISTANCES[Settings.choice("camera_distance")]
	# Free look swings the camera round the choppa.
	var orbit := body.basis * Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, -look.y * 0.8)
	var back := orbit * Vector3(0.0, height * reach, distance * reach + 3.0 * speed_ratio)
	var desired := body.origin + back
	desired = _avoid_walls(body.origin + Vector3.UP, desired)
	if _ready_to_follow:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	else:
		global_position = desired
		_ready_to_follow = true
	var looking := clampf(look.length() * 2.0, 0.0, 1.0)  # Free look watches the choppa itself.
	var focus := body.origin + body.basis * Vector3(0.0, 1.0, -look_ahead * (1.0 - looking))
	if not global_position.is_equal_approx(focus):
		look_at(focus, Vector3.UP)
	_apply_shake(delta)


## Shot down: swing round to whoever did it and keep them in view from about 22 m.
func _kill_cam(delta: float) -> void:
	cull_mask = 0xFFFFF
	if target.model.cockpit_view:
		target.model.cockpit_view.reticle.visible = false
	var them := _killer.get_global_transform_interpolated().origin
	var away := global_position - them
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var wanted := _avoid_walls(them + Vector3.UP, them + away * 22.0 + Vector3.UP * 6.0)
	global_position = global_position.lerp(wanted, 1.0 - exp(-2.5 * delta))
	if not global_position.is_equal_approx(them):
		var look := global_transform.looking_at(them, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(look.basis, 1.0 - exp(-6.0 * delta)).orthonormalized()
	fov = lerpf(fov, Settings.number("fov") * 0.8, 1.0 - exp(-3.0 * delta))


func _cinematic_move(body: Transform3D, delta: float) -> void:
	var reach: float = Airframe.spec(target.airframe).camera
	var wanted: Vector3
	var focus := body.origin + Vector3.UP * 0.8
	match cinematic:
		"orbit":
			var a := _cine_time * 0.35
			wanted = body.origin + Vector3(sin(a), 0.0, cos(a)) * 11.0 * reach + Vector3.UP * 3.0
		"side":
			wanted = body.origin + body.basis * Vector3(9.0 * reach, 1.5, -6.0 * reach)
			focus = body.origin + body.basis * Vector3(0.0, 0.6, -3.0)
		_:
			if _cine_spot == Vector3.INF:
				var side := body.basis * Vector3(14.0, 0.0, -10.0)
				_cine_spot = body.origin + side
				_cine_spot.y = body.origin.y - target.altitude - target.clearance + 0.6
			wanted = _cine_spot
	wanted = _avoid_walls(body.origin + Vector3.UP, wanted)
	if _ready_to_follow:
		global_position = global_position.lerp(wanted, 1.0 - exp(-3.0 * delta))
	else:
		global_position = wanted
		_ready_to_follow = true
	look_at(focus, Vector3.UP)


func _avoid_walls(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position + (from - to).normalized() * 0.6
	return to
