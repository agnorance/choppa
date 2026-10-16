class_name Bullet
extends Node3D
## Machine gun round: light damage and a little knockback. Moves in straight steps and
## ray-checks each step, so it can't tunnel through thin walls.

const SPEED := 380.0  ## Fast enough that hits land the moment you see them line up.
const LIFETIME := 0.55  ## About 210 m of reach.
const KNOCKBACK := 1.2  ## Velocity added to the target per hit.
const DAMAGE := 4.0

static var _mesh: BoxMesh
static var _material: StandardMaterial3D

var shooter: Choppa
var direction := Vector3.FORWARD
var speed := SPEED
var damage := DAMAGE

var _age := 0.0


func _ready() -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.09, 0.09, 5.0)  # Long enough to read as a streak at this speed.
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.albedo_color = Color(4.0, 2.6, 1.0)  # Above 1: the glow pass makes it a streak of light.
	var tracer := MeshInstance3D.new()
	tracer.mesh = _mesh
	tracer.material_override = _material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
		basis = Basis.looking_at(direction)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var target := hit.collider as Choppa
	if target and target.take_hit(direction * KNOCKBACK, shooter, damage, hit.position) and is_instance_valid(shooter):
		shooter.scored_hit.emit(target)
	if target == null or not target.is_rolling_hard():
		_impact(hit)
		queue_free()
	else:
		global_position = to  # Dodged: fly on through.


func _impact(hit: Dictionary) -> void:
	var impact := Effects.Impact.new()
	var collider := hit.collider as Node
	if collider is Choppa:
		impact.kind = Effects.Impact.Kind.METAL
	elif collider.is_in_group("water"):
		impact.kind = Effects.Impact.Kind.WATER
	impact.normal = hit.normal
	get_parent().add_child(impact)
	impact.global_position = hit.position
