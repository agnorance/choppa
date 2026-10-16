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


static func environment(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.45, 0.8)
	sky_material.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_material.ground_horizon_color = Color(0.7, 0.8, 0.9)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.72, 0.85)
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	parent.add_child(sun)


static func ground(parent: Node3D, size: float) -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var odd := (x < 32) != (y < 32)
			image.set_pixel(x, y, Color(0.36, 0.55, 0.28) if odd else Color(0.4, 0.6, 0.31))
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(size / 16.0, size / 16.0, 1.0)
	material.roughness = 0.95

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
		mesh.material_override = material(color)
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
	mesh.material_override = material(ROCK_DARK.lerp(Color(0.4, 0.45, 0.4), randf() * 0.5))
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
	mesh.material_override = material(ROCK)
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
static func item_row(parent: Node3D, center: Vector3, yaw: float, count: int, spacing := 6.0) -> void:
	var across := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	for i in count:
		var box := ItemBox.new()
		box.position = center + across * (i - (count - 1) * 0.5) * spacing
		parent.add_child(box)


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
	var ledge := material(color.darkened(0.25))
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


## Low-poly pine with a solid trunk-and-crown collider.
static func tree(parent: Node3D, base: Vector3, size: float, variant: int) -> void:
	if not _meshes.has("trunk"):
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.25
		trunk.bottom_radius = 0.4
		trunk.height = 3.0
		trunk.radial_segments = 6
		trunk.rings = 1
		_meshes.trunk = trunk
		var crown := CylinderMesh.new()
		crown.top_radius = 0.0
		crown.bottom_radius = 2.4
		crown.height = 4.5
		crown.radial_segments = 7
		crown.rings = 1
		_meshes.crown = crown
		_meshes.bark = material(BARK)
		_meshes.pines = PINE.map(func(c: Color) -> StandardMaterial3D: return material(c))
	var body := StaticBody3D.new()
	body.position = base
	body.rotation.y = randf() * TAU
	body.scale = Vector3.ONE * size
	parent.add_child(body)
	_mesh_child(body, _meshes.trunk, _meshes.bark, Vector3(0.0, 1.5, 0.0))
	var pine: Material = _meshes.pines[variant % 3]
	for k in 3:
		var crown := _mesh_child(body, _meshes.crown, pine, Vector3(0.0, 4.2 + k * 2.2, 0.0))
		crown.scale = Vector3.ONE * (1.0 - k * 0.25)
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
	var mesh := _mesh_child(body, _meshes.boulder, material(color.darkened(randf() * 0.2)), Vector3.ZERO)
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
	_mesh_child(body, column, material(SANDSTONE.lerp(ROCK, randf())), Vector3(0.0, height * 0.5, 0.0))
	var cap := CylinderMesh.new()
	cap.top_radius = radius * 1.1
	cap.bottom_radius = radius * 1.3
	cap.height = radius * 0.8
	cap.radial_segments = 7
	_mesh_child(body, cap, material(ROCK_DARK), Vector3(0.0, height + radius * 0.4, 0.0))
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
	var stone := material(color)
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


## Gently waving water with a solid surface you can skim over.
static func water(parent: Node3D, center: Vector3, size: float) -> void:
	if not _meshes.has("water"):
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.04, 0.2, 0.3);
uniform vec3 shallow : source_color = vec3(0.12, 0.45, 0.5);
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sin(world_xz.x * 0.15 + TIME * 1.3) * 0.15 + cos(world_xz.y * 0.12 + TIME) * 0.15;
}
void fragment() {
	float ripple = sin(world_xz.x * 0.7 + TIME * 2.0) * sin(world_xz.y * 0.6 - TIME * 1.6);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(shallow, deep, facing) + ripple * 0.03;
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
	ALPHA = mix(0.95, 0.75, facing);
}
"""
		var water_material := ShaderMaterial.new()
		water_material.shader = shader
		_meshes.water = water_material
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = _meshes.water
	mesh.position = center
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	block(parent, center + Vector3.DOWN * 1.0, Vector3(size, 2.0, size), Color.WHITE, 0.0, false)


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
