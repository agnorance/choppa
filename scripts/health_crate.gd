class_name HealthCrate
extends Area3D
## Floating repair kit: a white crate with a red cross. Restores health to a damaged
## choppa and comes back after a while.

const HEAL := 40.0
const RESPAWN_TIME := 12.0

var _visual: Node3D
var _respawn := 0.0
var _phase := randf() * TAU


func _ready() -> void:
	add_to_group("health_crates")
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * 3.2
	shape.shape = box_shape
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	var crate := BoxMesh.new()
	crate.size = Vector3.ONE * 1.8
	var white := MapKit.material(Color(0.92, 0.92, 0.9))
	var red := MapKit.material(Color(0.9, 0.12, 0.12), 0.6)
	_add_mesh(crate, white, Vector3.ZERO)
	# A red cross on every face: each bar runs through the crate and pokes out of two
	# opposite faces.
	for bar_size in [
		Vector3(1.2, 0.36, 1.86), Vector3(0.36, 1.2, 1.86),
		Vector3(1.86, 0.36, 1.2), Vector3(1.86, 1.2, 0.36),
		Vector3(1.2, 1.86, 0.36), Vector3(0.36, 1.86, 1.2),
	]:
		var bar := BoxMesh.new()
		bar.size = bar_size
		_add_mesh(bar, red, Vector3.ZERO)
	body_entered.connect(_on_body_entered)


func is_available() -> bool:
	return _respawn <= 0.0


func _process(delta: float) -> void:
	_phase += delta
	if _respawn > 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			_visual.visible = true
		return
	_visual.rotation.y = _phase * 0.8
	_visual.position.y = sin(_phase * 1.6) * 0.3


func _add_mesh(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	_visual.add_child(instance)
	return instance


func _on_body_entered(body: Node3D) -> void:
	if not is_available() or not body is Choppa:
		return
	if (body as Choppa).heal(HEAL):
		_respawn = RESPAWN_TIME
		_visual.visible = false
