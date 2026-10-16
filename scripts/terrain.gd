class_name Terrain
extends StaticBody3D
## Heightmap terrain: a smooth-shaded mesh plus matching collision, both built from a
## height function. Its look comes from `material` (see shaders/terrain.gdshader).

var size := 1200.0
var resolution := 120  ## Cells per side.
## (x, z) -> height.
var height_fn: Callable
var material: Material

var _heights := PackedFloat32Array()
var _step := 0.0


func _ready() -> void:
	var n := resolution + 1
	_step = size / resolution
	var half := size * 0.5
	_heights.resize(n * n)
	for j in n:
		for i in n:
			_heights[j * n + i] = height_fn.call(-half + i * _step, -half + j * _step)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var k := j * n + i
			vertices[k] = _vertex(i, j)
			# Central differences give smooth per-vertex normals.
			var dx := _h(i - 1, j) - _h(i + 1, j)
			var dz := _h(i, j - 1) - _h(i, j + 1)
			normals[k] = Vector3(dx, 2.0 * _step, dz).normalized()
	var indices := PackedInt32Array()
	indices.resize(resolution * resolution * 6)
	var w := 0
	for j in resolution:
		for i in resolution:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			# Clockwise seen from above = front face in Godot.
			for index in [a, b, c, b, d, c]:
				indices[w] = index
				w += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

	# HeightMapShape3D has 1 m spacing; scale it uniformly and shrink heights to match.
	var data := PackedFloat32Array()
	data.resize(n * n)
	for k in n * n:
		data[k] = _heights[k] / _step
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3.ONE * _step
	add_child(collision)


## Height of the rendered surface at (x, z), matching the mesh triangles exactly.
func height_at(x: float, z: float) -> float:
	var n := resolution + 1
	var half := size * 0.5
	var gx := clampf((x + half) / _step, 0.0, resolution - 0.001)
	var gz := clampf((z + half) / _step, 0.0, resolution - 0.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var a := _heights[j * n + i]
	var b := _heights[j * n + i + 1]
	var c := _heights[(j + 1) * n + i]
	var d := _heights[(j + 1) * n + i + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


func _h(i: int, j: int) -> float:
	var n := resolution + 1
	return _heights[clampi(j, 0, resolution) * n + clampi(i, 0, resolution)]


func _vertex(i: int, j: int) -> Vector3:
	var half := size * 0.5
	return Vector3(-half + i * _step, _heights[j * (resolution + 1) + i], -half + j * _step)
