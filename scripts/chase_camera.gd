class_name ChaseCamera
extends Camera3D
## Follows a choppa from right behind, or from the cockpit in first-person mode.

@export var target: Choppa
@export var first_person := false
@export var showcase := false  ## Fixed three-quarter front view, for screenshots.

@export var distance := 8.5
@export var height := 2.6
@export var look_ahead := 6.0
@export var follow_sharpness := 9.0
@export var base_fov := 70.0
@export var speed_fov := 18.0  ## Extra FOV at boost speed.

var _ready_to_follow := false
var _trauma := 0.0  ## Camera shake, 0..1; decays. Felt as its square.
var _shake_noise := FastNoiseLite.new()
var _shake_time := 0.0


func _ready() -> void:
	near = 0.1
	far = 8000.0  # The mountain backdrop is kilometres away.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("shake_cameras")
	_shake_noise.frequency = 2.0
	if target:
		target.damaged.connect(func(amount: float, _attacker: Choppa) -> void: _trauma += amount * 0.025)


## An explosion of the given size went off at `at`: shake if it's close.
func shake_from(at: Vector3, size: float) -> void:
	var near_ratio := 1.0 - global_position.distance_to(at) / (70.0 * size)
	_trauma = minf(1.0, _trauma + clampf(near_ratio, 0.0, 1.0) * 0.9 * size)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.4)
	if _trauma <= 0.0:
		return
	_shake_time += delta * 30.0
	var amount: float = _trauma * _trauma * Settings.SHAKE_AMOUNTS[Settings.choice("camera_shake")]
	rotate_object_local(Vector3.RIGHT, _shake_noise.get_noise_1d(_shake_time) * 0.06 * amount)
	rotate_object_local(Vector3.UP, _shake_noise.get_noise_1d(_shake_time + 100.0) * 0.06 * amount)
	rotate_object_local(Vector3.BACK, _shake_noise.get_noise_1d(_shake_time + 200.0) * 0.08 * amount)


func toggle_mode() -> void:
	first_person = not first_person
	_ready_to_follow = false


func _process(delta: float) -> void:
	if target == null:
		return
	var speed_ratio := clampf(target.velocity.length() / target.boost_speed, 0.0, 1.2)
	var wanted := base_fov if showcase else Settings.number("fov")
	fov = lerpf(fov, wanted + speed_fov * speed_ratio, 1.0 - exp(-4.0 * delta))

	if target.model.cockpit_view:
		target.model.cockpit_view.reticle.visible = first_person
	if first_person:
		# Rigidly mounted: you feel every roll and flip.
		cull_mask = ~ChoppaModel.OWN_LAYER & 0xFFFFF
		global_transform = target.model.cockpit.get_global_transform_interpolated()
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
	var back := body.basis * Vector3(0.0, height, distance + 3.0 * speed_ratio)
	var desired := body.origin + back
	desired = _avoid_walls(body.origin + Vector3.UP, desired)
	if _ready_to_follow:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	else:
		global_position = desired
		_ready_to_follow = true
	var focus := body.origin + body.basis * Vector3(0.0, 1.0, -look_ahead)
	if not global_position.is_equal_approx(focus):
		look_at(focus, Vector3.UP)
	_apply_shake(delta)


func _avoid_walls(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position + (from - to).normalized() * 0.6
	return to
