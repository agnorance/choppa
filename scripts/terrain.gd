class_name Terrain
extends StaticBody3D
## Low-poly heightmap terrain: a flat-shaded, vertex-coloured mesh plus matching
## collision, both built from a height function.

var size := 1200.0
var resolution := 120  ## Cells per side.
## (x, z) -> height.
var height_fn: Callable
## (center: Vector3, slope: float 0 flat..1 vertical) -> Color.
var color_fn: Callable

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

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in resolution:
		for i in resolution:
			var a := _vertex(i, j)
			var b := _vertex(i + 1, j)
			var c := _vertex(i, j + 1)
			var d := _vertex(i + 1, j + 1)
			_triangle(st, a, b, c)
			_triangle(st, b, d, c)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = material
	add_child(mesh)

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


func _vertex(i: int, j: int) -> Vector3:
	var half := size * 0.5
	return Vector3(-half + i * _step, _heights[j * (resolution + 1) + i], -half + j * _step)


func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	# Godot treats clockwise triangles as front faces, seen from the normal's side.
	st.set_normal(normal)
	st.set_color(color_fn.call((a + b + c) / 3.0, 1.0 - normal.y))
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
