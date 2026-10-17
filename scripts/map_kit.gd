class_name MapKit
extends RefCounted
## Reusable building blocks for maps: terrain, solid blocks, tunnels, pickups.

const ROCK := Color(0.62, 0.42, 0.3)
const ROCK_DARK := Color(0.45, 0.3, 0.22)
const CONCRETE := Color(0.6, 0.6, 0.62)
const SANDSTONE := Color(0.78, 0.6, 0.42)
const BARK := Color(0.35, 0.24, 0.16)
const PINE := [Color(0.18, 0.38, 0.2), Color(0.22, 0.44, 0.22), Color(0.26, 0.4, 0.18)]

static var _meshes := {}  ## Shared meshes and materials, built on first use.


## Sky, sun, haze and post-processing. How much of it runs depends on Graphics.quality.
static func environment(parent: Node3D, sun_rotation := Vector3(-19.0, 70.0, 0.0)) -> void:
	var high := Graphics.at_least(Graphics.Quality.HIGH)
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05

	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.66, 0.56)
	env.fog_sun_scatter = 0.45
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.15
	env.fog_height = 6.0
	env.fog_height_density = 0.004

	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		# Desktop target: RTX 3060 class. Bounce light off the canyon walls and into
		# the tunnels, plus screen-space indirect light and reflections. Which of these
		# run is decided by Settings.apply_environment (quality preset or the player).
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.4
		env.sdfgi_energy = 1.0
		env.ssil_intensity = 0.8
		env.ssr_max_steps = 48
		env.ssao_radius = 2.0
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.volumetric_fog_density = 0.0012
		env.volumetric_fog_albedo = Color(0.92, 0.88, 0.82)
		env.volumetric_fog_anisotropy = 0.55
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_ambient_inject = 0.35
		env.volumetric_fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.05
	env.set_meta("quality", Graphics.quality)
	Settings.apply_environment(env)

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group("environment")  # Settings re-applies live changes.
	parent.add_child(world_env)

	# Low afternoon sun: warm light, long soft shadows.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rotation
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 2.0
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 280.0 if high else 150.0
	sun.light_volumetric_fog_energy = 1.4
	parent.add_child(sun)


## Textured, world-space triplanar stone for structures. Warm colours become sandstone,
## neutral ones rock; the colour tints the texture.
static func surface(color: Color) -> Material:
	var key := "surface_" + color.to_html()
	if _meshes.has(key):
		return _meshes[key]
	var kind := "sandstone" if color.r > color.b + 0.12 else "rock"
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s_albedo.png" % kind)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s_normal.png" % kind)
	m.normal_scale = 1.2
	m.roughness_texture = load("res://assets/textures/%s_rough.png" % kind)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * 0.12
	var peak := maxf(color.r, maxf(color.g, color.b))
	m.albedo_color = Color.WHITE.lerp(Color(color.r / peak, color.g / peak, color.b / peak), 0.35)
	_meshes[key] = m
	return m


## Distant mountain ranges with snow caps all around the arena: scenery only, no
## collision, mostly peeking over the arena's own cliffs.
static func backdrop(parent: Node3D, inner_radius: float, seed_value := 1) -> void:
	var ridges := FastNoiseLite.new()
	ridges.seed = seed_value
	ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 6
	ridges.frequency = 0.0008  # Broad ranges: narrow ones peeked over the cliffs as white spikes.
	var terrain := Terrain.new()
	terrain.size = 7000.0
	terrain.resolution = [140, 220, 350][Graphics.quality]
	terrain.collide = false
	terrain.height_fn = func(x: float, z: float) -> float:
		var r := Vector2(x, z).length()
		var rise := smoothstep(inner_radius, inner_radius + 1600.0, r)
		var ridge := ridges.get_noise_2d(x, z) * 0.5 + 0.5
		return -60.0 + rise * (160.0 + pow(ridge, 1.4) * 700.0)
	var material := terrain_material(-1000.0, "rock")
	material.set_shader_parameter("snow_height", 480.0)
	material.set_shader_parameter("cliff_slope", 0.3)
	material.set_shader_parameter("cliff_scale", 0.02)
	material.set_shader_parameter("ground_scale", 0.03)
	terrain.material = material
	parent.add_child(terrain)


## The splat material for Terrain and flat ground. `cliff` is the texture for steep
## slopes: "sandstone" or "rock".
static func terrain_material(water_level := -100.0, cliff := "sandstone") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	for slot: Array in [["grass", "grass"], ["dirt", "dirt"], ["sand", "sand"], ["cliff", cliff]]:
		m.set_shader_parameter(slot[0] + "_albedo", load("res://assets/textures/%s_albedo.png" % slot[1]))
		m.set_shader_parameter(slot[0] + "_normal", load("res://assets/textures/%s_normal.png" % slot[1]))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.01
	noise.fractal_octaves = 4
	var macro := NoiseTexture2D.new()
	macro.width = 512
	macro.height = 512
	macro.seamless = true
	macro.generate_mipmaps = true
	macro.noise = noise
	m.set_shader_parameter("macro_noise", macro)
	m.set_shader_parameter("water_level", water_level)
	return m


static func ground(parent: Node3D, size: float) -> void:
	var material := terrain_material()

	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = material

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	shape.shape = box
	shape.position.y = -1.0
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)

	# Invisible walls at the edge, mountains beyond them for looks.
	var half := size * 0.5
	for i in 4:
		var yaw := i * PI * 0.5
		var wall := Basis(Vector3.UP, yaw)
		block(parent, wall * Vector3(0.0, 100.0, -half), Vector3(size, 200.0, 4.0), Color.WHITE, yaw, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 48:
		var angle := TAU * i / 48.0 + rng.randf_range(-0.05, 0.05)
		var radius := half + rng.randf_range(10.0, 60.0)
		mountain(parent, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius),
			rng.randf_range(50.0, 110.0), rng.randf_range(60.0, 130.0))


static func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## A solid axis-aligned (then yawed) box. `visible_mesh = false` makes an invisible wall.
static func block(
	parent: Node3D, center: Vector3, size: Vector3, color: Color, yaw := 0.0,
	visible_mesh := true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	if visible_mesh:
		var box := BoxMesh.new()
		box.size = size
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = surface(color)
		body.add_child(mesh)
	parent.add_child(body)
	return body


static func mountain(parent: Node3D, base: Vector3, radius: float, height: float) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 7
	cone.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = cone
	mesh.material_override = surface(ROCK_DARK)
	mesh.position = base + Vector3.UP * height * 0.5
	parent.add_child(mesh)


## A mesa of rock with a lit tunnel straight through it, along its local Z axis.
static func mesa_tunnel(
	parent: Node3D, center: Vector3, yaw: float, length: float, width: float,
	height: float, tunnel_width: float, tunnel_height: float
) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	parent.add_child(root)
	var side := (width - tunnel_width) * 0.5
	var side_x := tunnel_width * 0.5 + side * 0.5
	block(root, Vector3(-side_x, height * 0.5, 0.0), Vector3(side, height, length), ROCK)
	block(root, Vector3(side_x, height * 0.5, 0.0), Vector3(side, height, length), ROCK)
	var roof := height - tunnel_height
	block(root, Vector3(0.0, tunnel_height + roof * 0.5, 0.0), Vector3(tunnel_width, roof, length), ROCK)

	# Guide strips along the walls and warm lights along the ceiling.
	var strip := material(Color(1.0, 0.6, 0.15), 3.0)
	for x in [-tunnel_width * 0.5 + 0.2, tunnel_width * 0.5 - 0.2]:
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, length)
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = strip
		mesh.position = Vector3(x, 1.0, 0.0)
		root.add_child(mesh)
	var count := int(length / 25.0)
	for i in count:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.45)
		light.light_energy = 2.0
		light.omni_range = 22.0
		light.position = Vector3(0.0, tunnel_height - 2.0, -length * 0.5 + (i + 0.5) * length / count)
		root.add_child(light)


## Two pillars and a beam to fly under.
static func arch(
	parent: Node3D, center: Vector3, yaw: float, span: float, height: float, color := CONCRETE
) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	parent.add_child(root)
	for x in [-span * 0.5 - 2.0, span * 0.5 + 2.0]:
		block(root, Vector3(x, height * 0.5, 0.0), Vector3(4.0, height, 4.0), color)
	block(root, Vector3(0.0, height + 2.0, 0.0), Vector3(span + 8.0, 4.0, 4.0), color)


static func pillar(parent: Node3D, base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = base + Vector3.UP * height * 0.5
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.8
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.material_override = surface(ROCK)
	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	shape.shape = cylinder_shape
	body.add_child(mesh)
	body.add_child(shape)
	parent.add_child(body)


static func ring(parent: Node3D, center: Vector3, yaw: float, radius := 5.0) -> RingGate:
	var gate := RingGate.new()
	gate.radius = radius
	gate.position = center
	gate.rotation.y = yaw
	parent.add_child(gate)
	return gate


## A row of item boxes across the local X axis.
## A service station (or an ammo-only one) centred at `at` (x, z). `ground` gives the terrain height; the pad
## sits on the highest point under it so no terrain pokes through.
static func station(parent: Node3D, at: Vector3, ground: Callable, ammo_only := false) -> ServiceStation:
	var top := -INF
	for k in 9:
		var a := TAU * k / 8.0
		var r := 0.0 if k == 8 else ServiceStation.PAD_RADIUS
		top = maxf(top, ground.call(at.x + cos(a) * r, at.z + sin(a) * r))
	var s := ServiceStation.new()
	s.ammo_only = ammo_only
	s.position = Vector3(at.x, top - 0.1, at.z)
	parent.add_child(s)
	return s


## A sculpted rock model from assets/models/rocks (see tools/blender/make_rocks.py),
## textured with triplanar stone and given an exact collision mesh.
static func rock(
	parent: Node3D, model: String, at: Vector3, yaw := 0.0, size := 1.0, color := SANDSTONE
) -> Node3D:
	var key := "rock_" + model
	if not _meshes.has(key):
		var scene: PackedScene = load("res://assets/models/rocks/%s.glb" % model)
		var probe := scene.instantiate()
		var mesh: Mesh = probe.find_children("*", "MeshInstance3D")[0].mesh
		probe.free()
		_meshes[key] = [mesh, mesh.create_trimesh_shape()]
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	body.scale = Vector3.ONE * size
	_mesh_child(body, _meshes[key][0], surface(color), Vector3.ZERO)
	var shape := CollisionShape3D.new()
	shape.shape = _meshes[key][1]
	body.add_child(shape)
	parent.add_child(body)
	return body


## The highest point of `node`'s meshes within `radius` of (x, z), in world space: where
## to set something down on a rock model (e.g. a station on top of the mesa).
static func top_of(node: Node3D, x: float, z: float, radius := 1.5) -> float:
	var best := -INF
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.global_transform if mi.is_inside_tree() else node.transform * mi.transform
		for v: Vector3 in mi.mesh.get_faces():
			var w := xf * v
			if Vector2(w.x - x, w.z - z).length() < radius:
				best = maxf(best, w.y)
	return best


## Warm lights along two crossing tunnels (along local X and Z), as in the mesa model.
static func tunnel_lights(parent: Node3D, center: Vector3, half_length: float, height: float) -> void:
	for at: Vector3 in [
		Vector3.ZERO, Vector3(half_length * 0.5, 0, 0), Vector3(-half_length * 0.5, 0, 0),
		Vector3(0, 0, half_length * 0.5), Vector3(0, 0, -half_length * 0.5),
	]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.42)
		light.light_energy = 2.5
		light.omni_range = 24.0
		light.shadow_enabled = Graphics.at_least(Graphics.Quality.HIGH)
		light.position = center + at + Vector3.UP * height
		parent.add_child(light)


## A mesa with two tunnels crossing at its center, along local X and Z.
static func cross_mesa(
	parent: Node3D, center: Vector3, size: float, height: float, tunnel_width: float,
	tunnel_height: float, color := ROCK
) -> void:
	var root := Node3D.new()
	root.position = center
	parent.add_child(root)
	var corner := (size - tunnel_width) * 0.5
	var offset := tunnel_width * 0.5 + corner * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			block(root, Vector3(sx * offset, height * 0.5, sz * offset), Vector3(corner, height, corner), color)
	var roof := height - tunnel_height
	var roof_y := tunnel_height + roof * 0.5
	block(root, Vector3(0.0, roof_y, 0.0), Vector3(size, roof, tunnel_width), color)
	block(root, Vector3(0.0, roof_y, 0.0), Vector3(tunnel_width, roof, size), color)
	# Rock strata: thin darker ledges sticking out of the walls.
	var ledge := surface(color.darkened(0.25))
	var y := 5.0
	while y < height - 2.0:
		var band := BoxMesh.new()
		band.size = Vector3(corner + 0.6, 1.2, corner + 0.6)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var mesh := MeshInstance3D.new()
				mesh.mesh = band
				mesh.material_override = ledge
				mesh.position = Vector3(sx * offset, y, sz * offset)
				root.add_child(mesh)
		y += 6.5
	var strip := material(Color(1.0, 0.6, 0.15), 3.0)
	for yaw in [0.0, PI * 0.5]:
		var basis := Basis(Vector3.UP, yaw)
		for side in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.3, corner)
			for end in [-1.0, 1.0]:
				var mesh := MeshInstance3D.new()
				mesh.mesh = box
				mesh.material_override = strip
				mesh.position = basis * Vector3(side * (tunnel_width * 0.5 - 0.2), 1.0, end * offset)
				mesh.rotation.y = yaw
				root.add_child(mesh)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.45)
		light.light_energy = 2.0
		light.omni_range = 26.0
		light.position = basis * Vector3(0.0, tunnel_height - 2.0, offset)
		root.add_child(light)
	var middle := OmniLight3D.new()
	middle.light_color = Color(1.0, 0.75, 0.45)
	middle.light_energy = 2.0
	middle.omni_range = 26.0
	middle.position = Vector3(0.0, tunnel_height - 2.0, 0.0)
	root.add_child(middle)


## Pine from assets/models/trees (tools/blender/make_trees.py) with a solid
## trunk-and-crown collider. `variant` picks the model and a slightly different green.
static func tree(parent: Node3D, base: Vector3, size: float, variant: int) -> void:
	if not _meshes.has("pines"):
		var scene: Node3D = (load("res://assets/models/trees/trees.glb") as PackedScene).instantiate()
		_meshes.pine_meshes = []
		for k in 3:
			_meshes.pine_meshes.append((scene.find_child("pine_%d" % (k + 1)) as MeshInstance3D).mesh)
		scene.free()
		var bark := StandardMaterial3D.new()
		bark.albedo_texture = load("res://assets/textures/bark_albedo.png")
		bark.normal_enabled = true
		bark.normal_texture = load("res://assets/textures/bark_normal.png")
		bark.roughness = 0.9
		_meshes.bark = bark
		var needles: Texture2D = load("res://assets/textures/needles_albedo.png")
		_meshes.pines = PINE.map(func(c: Color) -> ShaderMaterial:
			var m := ShaderMaterial.new()
			m.shader = preload("res://shaders/foliage.gdshader")
			m.set_shader_parameter("needles", needles)
			m.set_shader_parameter("tint", c.lightened(0.55) * 1.6)
			return m)
	var body := StaticBody3D.new()
	body.position = base
	body.rotation.y = randf() * TAU
	body.scale = Vector3.ONE * size
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _meshes.pine_meshes[variant % 3]
	mesh.set_surface_override_material(0, _meshes.bark)
	mesh.set_surface_override_material(1, _meshes.pines[(variant / 3) % 3])
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.6
	capsule.height = 11.0
	shape.shape = capsule
	shape.position.y = 5.5
	body.add_child(shape)


## A rough boulder, half sunk into the ground.
static func boulder(parent: Node3D, base: Vector3, size: float, color := ROCK) -> void:
	if not _meshes.has("boulder"):
		var rock := SphereMesh.new()
		rock.radial_segments = 7
		rock.rings = 4
		_meshes.boulder = rock
	var body := StaticBody3D.new()
	body.position = base
	body.rotation = Vector3(randf() * 0.4, randf() * TAU, randf() * 0.4)
	parent.add_child(body)
	var mesh := _mesh_child(body, _meshes.boulder, surface(color), Vector3.ZERO)
	mesh.scale = Vector3(size * randf_range(0.9, 1.4), size * randf_range(0.6, 1.0), size)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = size * 0.5
	shape.shape = sphere
	body.add_child(shape)


## A tall rock column with a wider cap stone, like the hoodoos of Bryce Canyon.
static func hoodoo(parent: Node3D, base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = base
	parent.add_child(body)
	var column := CylinderMesh.new()
	column.top_radius = radius * 0.7
	column.bottom_radius = radius
	column.height = height
	column.radial_segments = 7
	column.rings = 3
	_mesh_child(body, column, surface(SANDSTONE), Vector3(0.0, height * 0.5, 0.0))
	var cap := CylinderMesh.new()
	cap.top_radius = radius * 1.1
	cap.bottom_radius = radius * 1.3
	cap.height = radius * 0.8
	cap.radial_segments = 7
	_mesh_child(body, cap, surface(ROCK_DARK), Vector3(0.0, height + radius * 0.4, 0.0))
	for part: Array in [[radius, height, height * 0.5], [radius * 1.3, radius * 0.8, height + radius * 0.4]]:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = part[0]
		cylinder.height = part[1]
		shape.shape = cylinder
		shape.position.y = part[2]
		body.add_child(shape)


## A ruined column: a few drums stacked slightly askew.
static func ruined_column(parent: Node3D, base: Vector3, drums: int, color := SANDSTONE) -> void:
	var body := StaticBody3D.new()
	body.position = base
	parent.add_child(body)
	var drum := CylinderMesh.new()
	drum.top_radius = 1.6
	drum.bottom_radius = 1.7
	drum.height = 3.2
	drum.radial_segments = 8
	var stone := surface(color)
	for k in drums:
		var piece := _mesh_child(body, drum, stone, Vector3(randf_range(-0.2, 0.2), 1.6 + k * 3.2, randf_range(-0.2, 0.2)))
		piece.rotation.y = randf() * TAU
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.8
	cylinder.height = drums * 3.2
	shape.shape = cylinder
	shape.position.y = drums * 1.6
	body.add_child(shape)


## A layer of puffy low-poly clouds that drifts slowly with the wind.
static func clouds(parent: Node3D, count: int, extent: float, height: float) -> void:
	var layer := CloudLayer.new()
	layer.extent = extent
	parent.add_child(layer)
	var puff := SphereMesh.new()
	puff.radial_segments = 8
	puff.rings = 4
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1.0, 1.0, 1.0)
	white.roughness = 1.0
	white.emission_enabled = true
	white.emission = Color(0.55, 0.6, 0.7)
	for i in count:
		var cloud := Node3D.new()
		cloud.position = Vector3(randf_range(-extent, extent), height + randf_range(-15.0, 25.0), randf_range(-extent, extent))
		layer.add_child(cloud)
		for k in randi_range(3, 6):
			var mesh := _mesh_child(cloud, puff, white, Vector3(k * 9.0 + randf_range(-3, 3), randf_range(-2, 3), randf_range(-6, 6)))
			mesh.scale = Vector3(randf_range(14, 22), randf_range(7, 11), randf_range(12, 18))
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A lake (see Water) with a solid surface you can skim over.
static func water(parent: Node3D, center: Vector3, size: float) -> void:
	var surface := Water.new()
	surface.size = size
	surface.position = center
	parent.add_child(surface)
	block(parent, center + Vector3.DOWN * 1.0, Vector3(size, 2.0, size), Color.WHITE, 0.0, false).add_to_group("water")


static func _mesh_child(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance


class CloudLayer extends Node3D:
	var extent := 400.0
	var wind := Vector3(2.5, 0.0, 1.0)

	func _process(delta: float) -> void:
		for cloud: Node3D in get_children():
			cloud.position += wind * delta
			if cloud.position.x > extent:
				cloud.position.x -= extent * 2.0
			if cloud.position.z > extent:
				cloud.position.z -= extent * 2.0
