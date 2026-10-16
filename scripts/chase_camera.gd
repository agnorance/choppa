class_name ChaseCamera
extends Camera3D
## Follows a choppa from right behind, or from the cockpit in first-person mode.

@export var target: Choppa
@export var first_person := false

@export var distance := 8.5
@export var height := 2.6
@export var look_ahead := 6.0
@export var follow_sharpness := 9.0
@export var base_fov := 70.0
@export var speed_fov := 18.0  ## Extra FOV at boost speed.

var _ready_to_follow := false


func _ready() -> void:
	near = 0.1
	far = 8000.0  # The mountain backdrop is kilometres away.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func toggle_mode() -> void:
	first_person = not first_person
	_ready_to_follow = false


func _process(delta: float) -> void:
	if target == null:
		return
	var speed_ratio := clampf(target.velocity.length() / target.boost_speed, 0.0, 1.2)
	fov = lerpf(fov, base_fov + speed_fov * speed_ratio, 1.0 - exp(-4.0 * delta))

	if first_person:
		# Rigidly mounted: you feel every roll and flip.
		cull_mask = ~ChoppaModel.OWN_LAYER & 0xFFFFF
		global_transform = target.model.cockpit.get_global_transform_interpolated()
		return

	cull_mask = 0xFFFFF
	var body := target.get_global_transform_interpolated()
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


func _avoid_walls(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position + (from - to).normalized() * 0.6
	return to
