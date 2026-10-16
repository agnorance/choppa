class_name Grass
extends Node3D
## Dense grass over a Terrain: tufts of real blades in MultiMesh chunks that fade out
## with distance. Grows on flat, dry ground (not on cliffs, sand or under water). The
## rotor downwash of nearby choppas blows it flat (shaders/grass.gdshader). Skipped
## on LOW quality.

const CHUNK := 24.0  ## Metres per side.
const TUFT_HEIGHT := 0.55
const FLOATS_PER_TUFT := 12  ## A 3x4 transform in MultiMesh.buffer.
const PATCH_STEP := 4.0  ## Metres between samples of the patch noise.

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
## The patch noise sampled on a grid before the threads start (see _place).
var _patch_values := PackedFloat32Array()
var _patch_origin := Vector2.ZERO
var _patch_n := 0


func _ready() -> void:
	if terrain == null or density <= 0.0:
		return
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass.gdshader")
	var mesh := tuft_mesh()
	mesh.surface_set_material(0, _material)
	var started := Time.get_ticks_msec()

	# Chunks within the radius; each is placed on its own worker thread (the terrain
	# and the noise are only read), then uploaded to the GPU as one buffer.
	var cells := ceili(radius * 2.0 / CHUNK)
	var origins: Array[Vector3] = []
	for cj in cells:
		for ci in cells:
			var origin := center + Vector3(-radius + ci * CHUNK, 0.0, -radius + cj * CHUNK)
			var middle := origin + Vector3(CHUNK, 0.0, CHUNK) * 0.5
			if Vector2(middle.x - center.x, middle.z - center.z).length() <= radius + CHUNK:
				origins.append(origin)
	if patches:
		var reach := radius + CHUNK
		_patch_origin = Vector2(center.x, center.z) - Vector2.ONE * reach
		_patch_n = ceili(reach * 2.0 / PATCH_STEP) + 2
		_patch_values.resize(_patch_n * _patch_n)
		for j in _patch_n:
			for i in _patch_n:
				_patch_values[j * _patch_n + i] = patches.get_noise_2d(
					_patch_origin.x + i * PATCH_STEP, _patch_origin.y + j * PATCH_STEP)
	var buffers: Array[PackedFloat32Array] = []
	buffers.resize(origins.size())
	var lock := Mutex.new()
	var group := WorkerThreadPool.add_group_task(func(k: int) -> void:
		var buffer := _place(origins[k], k)
		lock.lock()
		buffers[k] = buffer
		lock.unlock(), origins.size(), -1, true, "grass")
	WorkerThreadPool.wait_for_group_task_completion(group)

	var total := 0
	for buffer in buffers:
		if buffer.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = buffer.size() / FLOATS_PER_TUFT
		multimesh.buffer = buffer
		total += multimesh.instance_count
		var chunk := MultiMeshInstance3D.new()
		chunk.multimesh = multimesh
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.visibility_range_end = view_distance
		chunk.visibility_range_end_margin = 25.0
		chunk.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(chunk)
	GameMap.report("grass: %d tufts in %d chunks" % [total, origins.size()], started)


## Tuft transforms for one chunk, packed the way MultiMesh.buffer wants them (the three
## rows of the 3x4 transform). Deterministic per chunk, so the lawn is the same every
## game and on every machine. Runs on a worker thread, so it only reads plain arrays
## and samples them inline: every call on an object from a worker (the terrain, the
## noise, even a RandomNumberGenerator) goes through a shared lock and eats the
## speed-up, so the terrain's height grid and the patch noise come pre-sampled.
func _place(origin: Vector3, index: int) -> PackedFloat32Array:
	var heights := terrain.height_data()
	var patch_values := _patch_values
	var patch_n := _patch_n
	var patch_origin := _patch_origin
	var resolution := terrain.resolution
	var n := resolution + 1
	var half := terrain.size * 0.5
	var step := terrain.size / resolution
	var state := (77 + index * 7919) & 0x7FFFFFFF  # A plain LCG, see above.
	var per_chunk := int(CHUNK * CHUNK * density)
	var buffer := PackedFloat32Array()
	buffer.resize(per_chunk * FLOATS_PER_TUFT)
	var w := 0
	for k in per_chunk:
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var x := origin.x + state * (CHUNK / 2147483648.0)
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var z := origin.z + state * (CHUNK / 2147483648.0)
		var r := Vector2(x - center.x, z - center.z).length()
		if r > radius or r < inner_radius:
			continue
		# Terrain.height_at, inlined, plus the slope of the triangle we landed on.
		var gx := clampf((x + half) / step, 0.0, resolution - 0.001)
		var gz := clampf((z + half) / step, 0.0, resolution - 0.001)
		var i := int(gx)
		var j := int(gz)
		var fx := gx - i
		var fz := gz - j
		var a := heights[j * n + i]
		var b := heights[j * n + i + 1]
		var c := heights[(j + 1) * n + i]
		var d := heights[(j + 1) * n + i + 1]
		var y: float
		var rise: Vector2  # Height gained per metre in x and z.
		if fx + fz <= 1.0:
			y = a + (b - a) * fx + (c - a) * fz
			rise = Vector2(b - a, c - a) / step
		else:
			y = d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)
			rise = Vector2(d - c, d - b) / step
		if y < water_level + 1.8:
			continue
		if patch_n > 0:
			var px := clampf((x - patch_origin.x) / PATCH_STEP, 0.0, patch_n - 1.001)
			var pz := clampf((z - patch_origin.y) / PATCH_STEP, 0.0, patch_n - 1.001)
			var pi := int(px)
			var pj := int(pz)
			var p0 := lerpf(patch_values[pj * patch_n + pi], patch_values[pj * patch_n + pi + 1], px - pi)
			var p1 := lerpf(patch_values[(pj + 1) * patch_n + pi], patch_values[(pj + 1) * patch_n + pi + 1], px - pi)
			if lerpf(p0, p1, pz - pj) < -0.15:
				continue
		var slope := 1.0 - 1.0 / sqrt(1.0 + rise.length_squared())  # 1 - normal.y
		if slope > max_slope:
			continue
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var s := (0.7 + state * (0.6 / 2147483648.0)) * (1.0 - slope / max_slope * 0.4)
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var yaw := state * (TAU / 2147483648.0)
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var stretch := 0.8 + state * (0.4 / 2147483648.0)
		var cs := cos(yaw) * s
		var sn := sin(yaw) * s
		# Rows of (yaw rotation scaled by s, s * stretch, s) with the position.
		buffer[w] = cs
		buffer[w + 1] = 0.0
		buffer[w + 2] = sn
		buffer[w + 3] = x
		buffer[w + 4] = 0.0
		buffer[w + 5] = s * stretch
		buffer[w + 6] = 0.0
		buffer[w + 7] = y - 0.05
		buffer[w + 8] = -sn
		buffer[w + 9] = 0.0
		buffer[w + 10] = cs
		buffer[w + 11] = z
		w += FLOATS_PER_TUFT
	buffer.resize(w)
	return buffer


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
