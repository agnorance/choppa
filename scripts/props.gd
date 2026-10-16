class_name Props
extends RefCounted
## Map props modelled in Blender (tools/blender/make_props.py -> assets/models/props/
## props.glb): one scene with a top-level node per prop. `instance("water_tower")`
## returns a copy of that node, or null when the prop has not been built yet, so
## callers can fall back to primitives.

const PATH := "res://assets/models/props/props.glb"

static var _scene: Node3D


static func instance(prop_name: String) -> Node3D:
	if _scene == null:
		if not ResourceLoader.exists(PATH):
			return null
		_scene = (load(PATH) as PackedScene).instantiate()
	var source := _scene.get_node_or_null(prop_name) as Node3D
	if source == null:
		return null
	var copy := source.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	return copy


## A prop with exact collision (trimesh of every mesh in it), for things you can crash
## into. Returns null like `instance`.
static func solid(prop_name: String) -> Node3D:
	var node := instance(prop_name)
	if node == null:
		return null
	var body := StaticBody3D.new()
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		shape.transform = node.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _relative(node, mi)
		body.add_child(shape)
	node.add_child(body)
	return node


static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
