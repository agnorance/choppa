class_name MapKit
extends RefCounted
## Reusable building blocks for maps: terrain, solid blocks, tunnels, pickups.

const ROCK := Color(0.62, 0.42, 0.3)
const ROCK_DARK := Color(0.45, 0.3, 0.22)
const CONCRETE := Color(0.6, 0.6, 0.62)


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
static func arch(parent: Node3D, center: Vector3, yaw: float, span: float, height: float) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	parent.add_child(root)
	for x in [-span * 0.5 - 2.0, span * 0.5 + 2.0]:
		block(root, Vector3(x, height * 0.5, 0.0), Vector3(4.0, height, 4.0), CONCRETE)
	block(root, Vector3(0.0, height + 2.0, 0.0), Vector3(span + 8.0, 4.0, 4.0), CONCRETE)


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
