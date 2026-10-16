class_name ChoppaModel
extends Node3D
## The helicopter model (assets/models/choppa, built by tools/blender/make_choppa.py)
## with its hull materials, spinning rotors and effects.
## Purely visual: it never affects the simulation. Forward is -Z.

## Render layer bit for the local player's own choppa, hidden from the cockpit camera.
const OWN_LAYER := 1 << 1

var color := Color(0.95, 0.5, 0.1)
var own := false  ## Set before adding to the tree to put meshes on OWN_LAYER.
var pilot: Choppa  ## The choppa this model shows; feeds the cockpit instruments.
var cockpit: Marker3D  ## First-person camera mount.
var cockpit_view: Cockpit  ## Instrumented interior, local player only.

var _parts: Node3D  ## All meshes, so the spawn shield can blink them.
var _rotor: Node3D
var _tail_rotor: Node3D
var _blur_material: StandardMaterial3D
var _rotor_speed := 0.0
var _dust: CPUParticles3D
var _trails: Array[CPUParticles3D] = []
var _smoke: CPUParticles3D
var _flashes: Array[Node3D] = []  ## Left, right.
var _flash_lights: Array[OmniLight3D] = []
var _casings: Array[CPUParticles3D] = []
var _haze: Array[CPUParticles3D] = []
var _downwash: MeshInstance3D
var _downwash_material: ShaderMaterial
var _dust_colors: Gradient
var _spray_colors: Gradient
var _cracks: Array[MeshInstance3D] = []
var _rotor_sound: AudioStreamPlayer3D
var _engine_sound: AudioStreamPlayer3D
var _boost_sound: AudioStreamPlayer3D
var _last_shot := -10.0
var _bubble: MeshInstance3D
var _bubble_material: StandardMaterial3D
var _sparks: CPUParticles3D


func _ready() -> void:
	_parts = Node3D.new()
	add_child(_parts)
	var model: Node3D = _scene().instantiate()
	_parts.add_child(model)
	var materials := part_materials(color.lerp(Color(0.36, 0.38, 0.3), 0.42))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		for k in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(k)
			var name := source.resource_name if source else "paint"
			mesh.set_surface_override_material(k, materials.get(name, materials.paint))
		if own:
			mesh.layers = OWN_LAYER
	_rotor = model.find_child("rotor")
	_tail_rotor = model.find_child("tail_rotor")
	var eye := _marker(model, "eye")

	var disc := CylinderMesh.new()
	disc.top_radius = 4.3
	disc.bottom_radius = 4.3
	disc.height = 0.02
	disc.radial_segments = 32
	_blur_material = StandardMaterial3D.new()
	_blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blur_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blur_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blur_material.albedo_color = Color(0.35, 0.35, 0.36, 0.0)
	_part(disc, _blur_material, _rotor.position + Vector3(0.0, -0.05, 0.0))

	cockpit = Marker3D.new()
	cockpit.position = eye
	add_child(cockpit)
	if own:
		# The live instruments, seen through the canopy in chase view too.
		cockpit_view = Cockpit.new()
		cockpit_view.choppa = pilot
		cockpit_view.position = eye
		add_child(cockpit_view)
	else:
		var shell := Cockpit.shell()
		shell.position = eye
		_parts.add_child(shell)

	_build_guns(model)
	_build_cracks(model)
	for exhaust in ["exhaust_l", "exhaust_r"]:
		_haze.append(_build_haze(_marker(model, exhaust)))
	_build_downwash()

	# Rotor slap carries furthest; the engine and boost roar are closer up.
	_rotor_sound = Sounds.loop_on(self, "rotor_loop", -4.0, 1.4)
	_rotor_sound.position = _rotor.position
	_engine_sound = Sounds.loop_on(self, "engine_loop", -8.0)
	_engine_sound.position = _rotor.position * Vector3(1.0, 0.6, 1.0)
	_boost_sound = Sounds.loop_on(self, "boost_loop", -6.0)
	_boost_sound.position = _engine_sound.position + Vector3(0.0, 0.0, 1.0)
	_boost_sound.stream_paused = true
	if own and pilot:
		pilot.item_changed.connect(func(item: String) -> void:
			if item != "":
				Sounds.play_ui(self, "pickup", -6.0))

	# Rotor downwash kicking up dust (or spray over water) when flying low.
	_dust_colors = Effects.gradient([
		Color(0.8, 0.77, 0.7, 0.0), Color(0.8, 0.77, 0.7, 0.55), Color(0.78, 0.75, 0.68, 0.0),
	])
	_spray_colors = Effects.gradient([
		Color(0.9, 0.95, 1.0, 0.0), Color(0.88, 0.94, 1.0, 0.6), Color(0.85, 0.92, 1.0, 0.0),
	])
	_dust = Effects.puffs(_dust_colors, 48, 1.4)
	_dust.top_level = true
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_dust.emission_ring_axis = Vector3.UP
	_dust.emission_ring_radius = 3.5
	_dust.emission_ring_inner_radius = 2.0
	_dust.emission_ring_height = 0.2
	_dust.direction = Vector3.RIGHT
	_dust.spread = 180.0
	_dust.flatness = 0.8
	_dust.initial_velocity_min = 5.0
	_dust.initial_velocity_max = 9.0
	_dust.damping_min = 3.0
	_dust.damping_max = 4.0
	_dust.gravity = Vector3(0.0, 3.0, 0.0)  # Billows up and out.
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 3.0
	_dust.emitting = false
	add_child(_dust)

	# Boost flames out of both exhaust stubs.
	for exhaust in ["exhaust_l", "exhaust_r"]:
		var trail := Effects.puffs(Effects.gradient([
			Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.1, 0.6), Color(0.4, 0.4, 0.4, 0.0),
		]), 28, 0.4)
		trail.position = _marker(model, exhaust)
		trail.direction = Vector3(0.1 * signf(trail.position.x), -0.1, 1.0)
		trail.spread = 8.0
		trail.initial_velocity_min = 6.0
		trail.initial_velocity_max = 9.0
		trail.scale_amount_min = 0.5
		trail.scale_amount_max = 1.0
		trail.emitting = false
		add_child(trail)
		_trails.append(trail)

	# Shield bubble; turns gold during GET TO THE CHOPPA.
	var sphere := SphereMesh.new()
	sphere.radius = 3.6
	sphere.height = 5.4
	sphere.radial_segments = 20
	sphere.rings = 10
	_bubble_material = StandardMaterial3D.new()
	_bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble = MeshInstance3D.new()
	_bubble.mesh = sphere
	_bubble.material_override = _bubble_material
	_bubble.position = Vector3(0.0, 0.2, 0.8)
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = false
	add_child(_bubble)

	# Purple sparks while the controls are scrambled.
	_sparks = Effects.puffs(Effects.gradient([
		Color(0.9, 0.5, 1.0, 1.0), Color(0.6, 0.2, 1.0, 0.0),
	]), 30, 0.5)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 2.5
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 5.0
	_sparks.scale_amount_min = 0.3
	_sparks.scale_amount_max = 0.6
	_sparks.local_coords = true
	_sparks.emitting = false
	add_child(_sparks)

	# Black smoke when badly damaged.
	_smoke = Effects.puffs(Effects.gradient([
		Color(0.15, 0.15, 0.15, 0.0), Color(0.12, 0.12, 0.12, 0.7), Color(0.2, 0.2, 0.2, 0.0),
	]), 24, 1.6)
	_smoke.position = _rotor.position * Vector3(1.0, 0.7, 1.0)  # Out of the engine.
	_smoke.direction = Vector3.UP
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 3.0
	_smoke.gravity = Vector3(0.0, 2.0, 0.0)
	_smoke.scale_amount_min = 1.5
	_smoke.scale_amount_max = 3.0
	_smoke.emitting = false
	add_child(_smoke)


## Spins the rotors and drives the effects; the body's attitude is the choppa's own
## transform now, so the model sits straight on it.
func update_pose(c: Choppa, delta: float) -> void:
	var target_rotor := 20.0 + (10.0 if c.is_boosting() else 0.0) + c.velocity.y * 0.3
	_rotor_speed = lerpf(_rotor_speed, target_rotor, 1.0 - exp(-3.0 * delta))
	_rotor.rotate_y(_rotor_speed * delta)
	_tail_rotor.rotate_x(_rotor_speed * 1.6 * delta)
	_blur_material.albedo_color.a = clampf((_rotor_speed - 8.0) / 80.0, 0.0, 0.1)
	_rotor_sound.pitch_scale = clampf(_rotor_speed / 22.0, 0.5, 1.6)
	_engine_sound.pitch_scale = clampf(0.85 + _rotor_speed / 80.0 + c.input.collective * 0.08, 0.6, 1.5)
	_rotor_sound.stream_paused = not c.alive
	_engine_sound.stream_paused = not c.alive
	_boost_sound.stream_paused = not c.is_boosting() or not c.alive
	if c.last_shot_time != _last_shot and c.last_shot_time > _last_shot:
		_last_shot = c.last_shot_time
		var muzzle := global_transform * (_flashes[1 if c.last_shot_side > 0.0 else 0].position)
		Sounds.play_at(get_tree().current_scene, "gun", muzzle, -6.0, randf_range(0.92, 1.08))

	_parts.visible = c.invulnerable <= 0.0 or fmod(c.invulnerable, 0.2) > 0.08
	if cockpit_view:  # Blinks with the hull in chase view; always there from the seat.
		cockpit_view.visible = _parts.visible or cockpit_view.reticle.visible
	var firing := c.clock - c.last_shot_time < 0.05
	for k in 2:
		var on := firing and (k == 1) == (c.last_shot_side > 0.0)
		if on and not _flashes[k].visible:
			# A fresh star every shot.
			_flashes[k].rotation.z = randf() * TAU
			_flashes[k].scale = Vector3.ONE * randf_range(0.8, 1.25)
		_flashes[k].visible = on
		_flash_lights[k].visible = on
		_casings[k].emitting = c.alive and c.clock - c.last_shot_time < Choppa.GUN_INTERVAL * 1.5
	for haze in _haze:
		haze.emitting = c.alive
	var visible_cracks := clampi(floori((Choppa.MAX_HEALTH - c.health) / 12.0), 0, _cracks.size()) if c.alive else 0
	for k in _cracks.size():
		_cracks[k].visible = k < visible_cracks
	for trail in _trails:
		trail.emitting = c.is_boosting()
	_sparks.emitting = c.scrambled > 0.0
	_bubble.visible = c.shield > 0.0 or c.rampage > 0.0
	if _bubble.visible:
		var gold := c.rampage > 0.0
		var pulse := 0.5 + 0.5 * sin(c.clock * 6.0)
		_bubble_material.albedo_color = Color(1.0, 0.8, 0.2, 0.18 + pulse * 0.1) if gold \
			else Color(0.3, 0.85, 1.0, 0.12 + 0.12 * c.shield / Choppa.SHIELD_HP)
	_smoke.emitting = c.health < 35.0
	_dust.emitting = c.altitude < 14.0
	var ground := c.global_position + Vector3.DOWN * (c.altitude + Choppa.GROUND_CLEARANCE - 0.3)
	if _dust.emitting:
		_dust.global_position = ground
		_dust.color_ramp = _spray_colors if c.over_water else _dust_colors
	var wash := clampf(1.0 - c.altitude / 16.0, 0.0, 1.0) if c.alive else 0.0
	_downwash.visible = wash > 0.0
	if _downwash.visible:
		_downwash.global_position = ground + Vector3.UP * 0.15
		_downwash_material.set_shader_parameter("power", wash * 0.7)
		_downwash_material.set_shader_parameter("tint",
			Color(0.88, 0.94, 1.0) if c.over_water else Color(0.8, 0.76, 0.66))


## Twin machine guns: a star-shaped flash with a light at each muzzle (shown for the gun
## that just fired), and brass casings spilling out of the receivers.
func _build_guns(model: Node3D) -> void:
	var star := StandardMaterial3D.new()
	star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star.cull_mode = BaseMaterial3D.CULL_DISABLED
	star.albedo_texture = Effects.star_texture()
	star.albedo_color = Color(1.0, 0.75, 0.4)
	star.disable_receive_shadows = true
	var side_quad := QuadMesh.new()
	side_quad.size = Vector2(0.55, 1.1)
	var front_quad := QuadMesh.new()
	front_quad.size = Vector2(0.75, 0.75)
	var brass := _material(Color(0.8, 0.6, 0.28), 0.9, 0.3)
	var casing := CylinderMesh.new()
	casing.top_radius = 0.009
	casing.bottom_radius = 0.009
	casing.height = 0.035
	casing.radial_segments = 6
	casing.rings = 1
	casing.material = brass
	for muzzle in ["muzzle_l", "muzzle_r"]:
		var at := _marker(model, muzzle)
		var flash := Node3D.new()
		flash.position = at + Vector3(0.0, 0.0, -0.3)
		flash.visible = false
		add_child(flash)
		# Two crossed planes along the barrel and one facing forward.
		for roll in [0.0, PI * 0.5]:
			var plane := MeshInstance3D.new()
			plane.mesh = side_quad
			plane.material_override = star
			plane.rotation = Vector3(PI * 0.5, 0.0, roll)
			plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if own:
				plane.layers = OWN_LAYER
			flash.add_child(plane)
		var front := MeshInstance3D.new()
		front.mesh = front_quad
		front.material_override = star
		front.position.z = 0.25
		front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if own:
			front.layers = OWN_LAYER
		flash.add_child(front)
		_flashes.append(flash)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.35)
		light.light_energy = 3.0
		light.omni_range = 7.0
		light.position = at + Vector3(0.0, 0.3, -0.2)
		light.visible = false
		add_child(light)
		_flash_lights.append(light)

		var shells := CPUParticles3D.new()
		shells.mesh = casing
		shells.amount = 16
		shells.lifetime = 1.2
		shells.local_coords = false
		shells.position = at + Vector3(0.12 * signf(at.x), 0.0, 1.75)  # The receiver's ejection port.
		shells.direction = Vector3(signf(at.x), -0.4, 0.3)
		shells.spread = 18.0
		shells.initial_velocity_min = 2.5
		shells.initial_velocity_max = 4.0
		shells.gravity = Vector3(0.0, -12.0, 0.0)
		shells.angular_velocity_min = -720.0
		shells.angular_velocity_max = 720.0
		shells.particle_flag_rotate_y = true
		shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shells.emitting = false
		add_child(shells)
		_casings.append(shells)


## Cracks in the canopy glass at the "crack_*" markers; more show as the hull takes
## damage. On the default layer so the pilot sees them from inside too.
func _build_cracks(model: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Effects.crack_texture()
	m.albedo_color = Color(0.95, 0.97, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.1
	m.metallic_specular = 1.0
	m.emission_enabled = true
	m.emission = Color(0.25, 0.27, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var markers := model.find_children("crack_*", "Node3D")
	markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	for marker: Node3D in markers:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * rng.randf_range(0.3, 0.45)
		var crack := MeshInstance3D.new()
		crack.mesh = quad
		crack.material_override = m
		# Blender's marker +Z (the glass normal) arrives as +Y; the quad faces +Z.
		crack.transform = marker.transform * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		crack.rotate_object_local(Vector3.BACK, rng.randf() * TAU)
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.visible = false
		add_child(crack)
		_cracks.append(crack)



## Heat shimmer trailing from an exhaust stub.
func _build_haze(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var haze := ShaderMaterial.new()
	haze.shader = preload("res://shaders/heat_haze.gdshader")
	quad.material = haze
	p.mesh = quad
	p.amount = 10
	p.lifetime = 0.7
	p.local_coords = false
	p.position = at
	p.direction = Vector3(0.15 * signf(at.x), 0.35, 1.0)
	p.spread = 10.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, 1.5, 0.0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = grow
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	p.color_initial_ramp = Effects.gradient([Color(0, 0, 1, 1), Color(1, 1, 1, 1)])  # Random phase per puff.
	p.color_ramp = Effects.gradient([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## A disc on the ground under the rotor, rings racing outward.
func _build_downwash() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.0, 18.0)
	_downwash_material = ShaderMaterial.new()
	_downwash_material.shader = preload("res://shaders/downwash.gdshader")
	_downwash = MeshInstance3D.new()
	_downwash.mesh = plane
	_downwash.material_override = _downwash_material
	_downwash.top_level = true
	_downwash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_downwash.visible = false
	add_child(_downwash)


static var _cached_scene: PackedScene


## Position of an empty from the Blender model, in model space.
static func _marker(model: Node3D, marker_name: String) -> Vector3:
	var node: Node3D = model.find_child(marker_name)
	return node.position if node else Vector3.ZERO


static func _scene() -> PackedScene:
	if _cached_scene == null:
		_cached_scene = load("res://assets/models/choppa/choppa.glb")
	return _cached_scene


## Materials by the names the Blender scripts give them; `paint` uses the hull shader.
static func part_materials(paint: Color, panel_size := Vector2(1.35, 0.75)) -> Dictionary:
	var hull := _hull(paint, panel_size)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.32, 0.35, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var red := _material(Color(1.0, 0.1, 0.05), 0.0, 0.4)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.1, 0.05)
	red.emission_energy_multiplier = 4.0
	var green := _material(Color(0.1, 1.0, 0.2), 0.0, 0.4)
	green.emission_enabled = true
	green.emission = Color(0.1, 1.0, 0.2)
	green.emission_energy_multiplier = 4.0
	var lamp := _material(Color(1.0, 0.92, 0.75), 0.0, 0.1)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.6)
	lamp.emission_energy_multiplier = 1.5
	return {
		"paint": hull,
		"metal": _material(Color(0.32, 0.32, 0.33), 0.85, 0.38),
		"dark": _material(Color(0.1, 0.1, 0.11), 0.4, 0.6),
		"glass": glass,
		"brass": _material(Color(0.78, 0.6, 0.3), 0.9, 0.3),
		"rubber": _material(Color(0.05, 0.05, 0.05), 0.0, 0.9),
		"exhaust": _material(Color(0.24, 0.15, 0.1), 0.75, 0.62),
		"lamp": lamp,
		# Markings share the hull's chips, grime and seams.
		"hazard": _hull(Color(0.85, 0.62, 0.12), panel_size),
		"decal": _hull(Color(0.86, 0.82, 0.68), panel_size),
		"marking_red": _hull(Color(0.6, 0.1, 0.06), panel_size),
		"light_red": red,
		"light_green": green,
	}


static func _hull(paint: Color, panel_size: Vector2) -> ShaderMaterial:
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/hull.gdshader")
	hull.set_shader_parameter("paint", paint)
	hull.set_shader_parameter("panel_size", panel_size)
	return hull


static func _material(albedo: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	return material


func _part(
	mesh: Mesh, material: Material, pos: Vector3, rot_degrees := Vector3.ZERO,
	scl := Vector3.ONE, parent: Node3D = null
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_degrees
	instance.scale = scl
	if own:
		instance.layers = OWN_LAYER
	(parent if parent else _parts).add_child(instance)
	return instance
