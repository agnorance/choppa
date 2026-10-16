class_name Props
extends RefCounted
## Map props modelled in Blender (tools/blender/make_props.py -> assets/models/props/
## props.glb): one scene with a top-level mesh per prop, named after it. `place()` puts
## a copy into a map with the game's materials and, if asked, exact collision.

const PATH := "res://assets/models/props/props.glb"

static var _meshes := {}  ## prop name -> Mesh
static var _shapes := {}  ## prop name -> collision Shape3D
static var _materials := {}


## A copy of the prop's model, or null when it has not been built yet (callers can fall
## back to primitives).
static func instance(prop_name: String) -> Node3D:
	var mesh := _mesh(prop_name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_apply_materials(mi)
	return mi


## The prop placed in `parent` at `at` (its base), turned by `yaw`, scaled by `size`.
## `solid`: give it exact collision so choppas crash into it.
static func place(parent: Node3D, prop_name: String, at: Vector3, yaw := 0.0, size := 1.0, solid := true) -> Node3D:
	var model := instance(prop_name)
	if model == null:
		return null
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = at
	root.rotation.y = yaw
	root.scale = Vector3.ONE * size
	root.add_child(model)
	if solid:
		if not _shapes.has(prop_name):
			_shapes[prop_name] = _mesh(prop_name).create_trimesh_shape()
		var shape := CollisionShape3D.new()
		shape.shape = _shapes[prop_name]
		root.add_child(shape)
	parent.add_child(root)
	return root


static func _mesh(prop_name: String) -> Mesh:
	if _meshes.is_empty():
		if not ResourceLoader.exists(PATH):
			return null
		var scene: Node3D = (load(PATH) as PackedScene).instantiate()
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[node.name] = (node as MeshInstance3D).mesh
		scene.free()
	return _meshes.get(prop_name)


## Swaps the Blender materials for the game's by name: worn wood, rusty steel,
## concrete and painted panels share the hull shader's chips and grime.
static func _apply_materials(mi: MeshInstance3D) -> void:
	if _materials.is_empty():
		_materials = ChoppaModel.part_materials(Color(0.36, 0.38, 0.3), Vector2(1.2, 0.8))
		_materials.wood = _surface(Color(0.5, 0.36, 0.22), 0.0, 0.9)
		_materials.wood_dark = _surface(Color(0.28, 0.19, 0.12), 0.0, 0.92)
		_materials.rust = _surface(Color(0.45, 0.22, 0.11), 0.45, 0.75)
		_materials.concrete = _surface(Color(0.58, 0.56, 0.52), 0.0, 0.95)
		_materials.corrugated = _surface(Color(0.52, 0.5, 0.46), 0.65, 0.55)
	for k in mi.mesh.get_surface_count():
		var source := mi.mesh.surface_get_material(k)
		var key := source.resource_name if source else "concrete"
		mi.set_surface_override_material(k, _materials.get(key, _materials.concrete))


static func _surface(color: Color, metallic: float, roughness: float) -> Material:
	var m := MapKit.surface(color) as StandardMaterial3D
	var copy := m.duplicate() as StandardMaterial3D
	copy.albedo_color = color.lightened(0.15)
	copy.metallic = metallic
	copy.roughness = roughness
	copy.uv1_scale = Vector3.ONE * 0.4
	return copy
