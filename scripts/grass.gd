class_name Grass
extends Node3D
## Dense grass over a Terrain: tufts of real blades in MultiMesh chunks that fade out
## with distance. Grows on flat, dry ground (not on cliffs, sand or under water). The
## rotor downwash of nearby choppas blows it flat (shaders/grass.gdshader). Skipped
## on LOW quality.

const CHUNK := 24.0  ## Metres per side.
const TUFT_HEIGHT := 0.55

var terrain: Terrain
var radius := 260.0  ## Grows within this distance of `center`...
var inner_radius := 0.0  ## ...but not closer than this (e.g. under a mesa).
var center := Vector3.ZERO
var water_level := -100.0
var density := 2.0  ## Tufts per square metre.
var view_distance := 110.0
var max_slope := 0.16  ## 1 - normal.y; matches where the terrain shader paints grass.
var patches: FastNoiseLite  ## Optional: grass only where this noise is above zero.

var _material: ShaderMaterial


func _ready() -> void:
	if terrain == null or density <= 0.0:
		return
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass.gdshader")
	var mesh := tuft_mesh()
	mesh.surface_set_material(0, _material)
	var started := Time.get_ticks_msec()
	var total := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var per_chunk := int(CHUNK * CHUNK * density)
	var cells := ceili(radius * 2.0 / CHUNK)
	for cj in cells:
		for ci in cells:
			var origin := center + Vector3(-radius + ci * CHUNK, 0.0, -radius + cj * CHUNK)
			var middle := origin + Vector3(CHUNK, 0.0, CHUNK) * 0.5
			if Vector2(middle.x - center.x, middle.z - center.z).length() > radius + CHUNK:
				continue
			var transforms: Array[Transform3D] = []
			for k in per_chunk:
				var x := origin.x + rng.randf() * CHUNK
				var z := origin.z + rng.randf() * CHUNK
				var r := Vector2(x - center.x, z - center.z).length()
				if r > radius or r < inner_radius:
					continue
				var y := terrain.height_at(x, z)
				if y < water_level + 1.8:
					continue
				if patches and patches.get_noise_2d(x, z) < -0.15:
					continue
				var slope := 1.0 - _normal(x, y, z).y
				if slope > max_slope:
					continue
				var s := rng.randf_range(0.7, 1.3) * (1.0 - slope / max_slope * 0.4)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
				transforms.append(Transform3D(basis, Vector3(x, y - 0.05, z)))
			if transforms.is_empty():
				continue
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = transforms.size()
			for k in transforms.size():
				multimesh.set_instance_transform(k, transforms[k])
			total += transforms.size()
			var chunk := MultiMeshInstance3D.new()
			chunk.multimesh = multimesh
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.visibility_range_end = view_distance
			chunk.visibility_range_end_margin = 25.0
			chunk.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(chunk)
	print_verbose("grass: %d tufts in %d ms" % [total, Time.get_ticks_msec() - started])


func _process(_delta: float) -> void:
	if _material == null:
		return
	var wash: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var k := 0
	for node in get_tree().get_nodes_in_group("choppas"):
		var c := node as Choppa
		if k >= 4 or not c.alive or c.altitude > 16.0 or c.over_water:
			continue
		var ground := c.global_position + Vector3.DOWN * (c.altitude + Choppa.GROUND_CLEARANCE)
		wash[k] = Vector4(ground.x, ground.y, ground.z, 1.0 - c.altitude / 16.0)
		k += 1
	_material.set_shader_parameter("wash", wash)


func _normal(x: float, y: float, z: float) -> Vector3:
	return Vector3(y - terrain.height_at(x + 1.0, z), 1.0, y - terrain.height_at(x, z + 1.0)).normalized()


## One tuft: a handful of curved, tapering blades fanning out from the root. Vertex
## colours carry a little per-blade shade variation in rgb and the height in alpha.
static func tuft_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := 7
	var segments := 3
	for b in blades:
		var yaw := rng.randf() * TAU
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-out.z, 0.0, out.x)
		var root := out * rng.randf_range(0.0, 0.12)
		var tall := TUFT_HEIGHT * rng.randf_range(0.6, 1.25)
		var lean := rng.randf_range(0.15, 0.5)
		var width := rng.randf_range(0.035, 0.055)
		var shade := rng.randf_range(0.8, 1.15)
		var points: Array[Vector3] = []
		for s in segments + 1:
			var t := float(s) / segments
			points.append(root + Vector3.UP * tall * t + out * lean * tall * t * t)
		for s in segments:
			var t0 := float(s) / segments
			var t1 := float(s + 1) / segments
			var w0 := width * (1.0 - t0)
			var w1 := width * (1.0 - t1) + 0.002
			var a := points[s] - side * w0
			var b2 := points[s] + side * w0
			var c := points[s + 1] + side * w1
			var d := points[s + 1] - side * w1
			var n := (points[s + 1] - points[s]).cross(side).normalized()
			for v: Array in [[a, t0], [b2, t0], [c, t1], [a, t0], [c, t1], [d, t1]]:
				st.set_color(Color(shade, shade, shade, v[1]))
				st.set_normal(n)
				st.add_vertex(v[0])
	return st.commit()
