class_name ChoppaModel
extends Node3D
## The helicopter model (assets/models/choppa, built by tools/blender/make_choppa.py)
## with its hull materials, tilt and trick animations, spinning rotors and effects.
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
var _tilt := Vector2.ZERO  ## x: pitch, y: roll.
var _rotor_speed := 0.0
var _dust: CPUParticles3D
var _trail: CPUParticles3D
var _smoke: CPUParticles3D
var _flashes: Array[MeshInstance3D] = []
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
	_part(disc, _blur_material, Vector3(0.0, 1.8, 0.4))

	cockpit = Marker3D.new()
	cockpit.position = Vector3(0.0, 0.55, -1.15)
	add_child(cockpit)
	if own:
		cockpit_view = Cockpit.new()
		cockpit_view.choppa = pilot
		cockpit_view.position = cockpit.position
		cockpit_view.visible = false
		add_child(cockpit_view)

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.35
	flash_mesh.height = 0.7
	flash_mesh.radial_segments = 6
	flash_mesh.rings = 3
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.85, 0.4)
	for side in [-1.0, 1.0]:
		var flash := _part(flash_mesh, flash_material, Vector3(0.9 * side, -0.45, -2.3), Vector3.ZERO, Vector3(1, 1, 2))
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flashes.append(flash)

	# Rotor downwash kicking up dust when flying low.
	_dust = Effects.puffs(Effects.gradient([
		Color(0.8, 0.77, 0.7, 0.0), Color(0.8, 0.77, 0.7, 0.55), Color(0.78, 0.75, 0.68, 0.0),
	]), 48, 1.4)
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

	# Boost flame and exhaust trail.
	_trail = Effects.puffs(Effects.gradient([
		Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.1, 0.6), Color(0.4, 0.4, 0.4, 0.0),
	]), 40, 0.45)
	_trail.position = Vector3(0.0, 0.75, 2.1)
	_trail.direction = Vector3.BACK
	_trail.spread = 8.0
	_trail.initial_velocity_min = 6.0
	_trail.initial_velocity_max = 9.0
	_trail.scale_amount_min = 0.8
	_trail.scale_amount_max = 1.4
	_trail.emitting = false
	add_child(_trail)

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
	_smoke.position = Vector3(0.0, 0.8, 0.8)
	_smoke.direction = Vector3.UP
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 3.0
	_smoke.gravity = Vector3(0.0, 2.0, 0.0)
	_smoke.scale_amount_min = 1.5
	_smoke.scale_amount_max = 3.0
	_smoke.emitting = false
	add_child(_smoke)


## Tilts the body with motion, plays trick animations and spins the rotors.
func update_pose(c: Choppa, delta: float) -> void:
	var local_v := c.facing().inverse() * c.velocity
	var target := Vector2(
		clampf(local_v.z / c.boost_speed, -1.0, 1.0) * 0.45,
		clampf(-local_v.x / c.boost_speed, -1.0, 1.0) * 0.5 + c.turn_rate * 0.12
	)
	_tilt = _tilt.lerp(target, 1.0 - exp(-6.0 * delta))

	var pitch := _tilt.x
	var yaw := 0.0
	var roll := _tilt.y
	var p := smoothstep(0.0, 1.0, c.trick_progress())
	match c.trick:
		"BARREL ROLL":
			roll -= c.trick_dir * TAU * p
		"FRONT FLIP":
			pitch -= TAU * p
		"PIROUETTE":
			yaw += c.trick_dir * TAU * p
		"180 SNAP":
			roll -= 0.7 * sin(p * PI)
	transform.basis = Basis.from_euler(Vector3(pitch, yaw, roll))

	var target_rotor := 20.0 + (10.0 if c.is_boosting() else 0.0) + c.velocity.y * 0.3
	_rotor_speed = lerpf(_rotor_speed, target_rotor, 1.0 - exp(-3.0 * delta))
	_rotor.rotate_y(_rotor_speed * delta)
	_tail_rotor.rotate_x(_rotor_speed * 1.6 * delta)
	_blur_material.albedo_color.a = clampf((_rotor_speed - 8.0) / 80.0, 0.0, 0.1)

	_parts.visible = c.invulnerable <= 0.0 or fmod(c.invulnerable, 0.2) > 0.08
	for flash in _flashes:
		flash.visible = c.clock - c.last_shot_time < 0.05
	_trail.emitting = c.is_boosting()
	_sparks.emitting = c.scrambled > 0.0
	_bubble.visible = c.shield > 0.0 or c.rampage > 0.0
	if _bubble.visible:
		var gold := c.rampage > 0.0
		var pulse := 0.5 + 0.5 * sin(c.clock * 6.0)
		_bubble_material.albedo_color = Color(1.0, 0.8, 0.2, 0.18 + pulse * 0.1) if gold \
			else Color(0.3, 0.85, 1.0, 0.12 + 0.12 * c.shield / Choppa.SHIELD_HP)
	_smoke.emitting = c.health < 35.0
	_dust.emitting = c.altitude < 14.0
	if _dust.emitting:
		_dust.global_position = c.global_position + Vector3.DOWN * (c.altitude + Choppa.GROUND_CLEARANCE - 0.3)


static var _cached_scene: PackedScene


static func _scene() -> PackedScene:
	if _cached_scene == null:
		_cached_scene = load("res://assets/models/choppa/choppa.glb")
	return _cached_scene


## Materials by the names the Blender scripts give them; `paint` uses the hull shader.
static func part_materials(paint: Color, panel_size := Vector2(1.35, 0.75)) -> Dictionary:
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/hull.gdshader")
	hull.set_shader_parameter("paint", paint)
	hull.set_shader_parameter("panel_size", panel_size)
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
	return {
		"paint": hull,
		"metal": _material(Color(0.32, 0.32, 0.33), 0.85, 0.38),
		"dark": _material(Color(0.1, 0.1, 0.11), 0.4, 0.6),
		"glass": glass,
		"brass": _material(Color(0.78, 0.6, 0.3), 0.9, 0.3),
		"light_red": red,
		"light_green": green,
	}


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
