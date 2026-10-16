class_name Bullet
extends Node3D
## Machine gun round: light damage and a little knockback. Moves in straight steps and
## ray-checks each step, so it can't tunnel through thin walls.

const SPEED := 180.0
const LIFETIME := 0.9
const KNOCKBACK := 1.2  ## Velocity added to the target per hit.
const DAMAGE := 4.0

static var _mesh: BoxMesh
static var _material: StandardMaterial3D

var shooter: Choppa
var direction := Vector3.FORWARD
var speed := SPEED

var _age := 0.0


func _ready() -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.1, 0.1, 2.6)
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.albedo_color = Color(1.0, 0.85, 0.35)
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
	if target and target.take_hit(direction * KNOCKBACK, shooter, DAMAGE) and is_instance_valid(shooter):
		shooter.scored_hit.emit(target)
	if target == null or not target.trick == "BARREL ROLL":
		_spark(hit.position)
		queue_free()
	else:
		global_position = to  # Dodged: fly on through.


func _spark(at: Vector3) -> void:
	var spark := Spark.new()
	get_parent().add_child(spark)
	spark.global_position = at


class Spark extends MeshInstance3D:
	var _t := 0.0

	func _ready() -> void:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 6
		sphere.rings = 3
		mesh = sphere
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.75, 0.3)
		material_override = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(delta: float) -> void:
		_t += delta
		scale = Vector3.ONE * (0.4 + _t * 6.0)
		(material_override as StandardMaterial3D).albedo_color.a = 1.0 - _t / 0.15
		if _t >= 0.15:
			queue_free()
