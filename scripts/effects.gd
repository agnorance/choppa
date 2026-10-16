class_name Effects
extends RefCounted
## Shared particle setups. CPUParticles3D so they run on the Compatibility renderer and
## on any phone.


## Camera-facing soft puffs. `colors` fade over each particle's life.
static func puffs(colors: Gradient, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	# BILLBOARD_PARTICLES loses the per-particle scale on the Compatibility renderer.
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _soft_dot()
	quad.material = m
	p.mesh = quad
	p.color_ramp = colors
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func gradient(stops: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for k in stops.size():
		offsets.append(float(k) / (stops.size() - 1))
		colors.append(stops[k])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	return g


static var _dot: Texture2D


## A round, soft-edged white dot, made once.
static func _soft_dot() -> Texture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_dot = tex
	return _dot


## Fireball, smoke, flying debris and a flash of light. Cleans itself up.
class Explosion extends Node3D:
	var _t := 0.0
	var _light: OmniLight3D

	func _ready() -> void:
		var fire := Effects.puffs(Effects.gradient([
			Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.5, 0.1, 0.9),
			Color(0.3, 0.25, 0.2, 0.6), Color(0.15, 0.15, 0.15, 0.0),
		]), 40, 1.4)
		fire.one_shot = true
		fire.explosiveness = 0.9
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 1.5
		fire.direction = Vector3.UP
		fire.spread = 180.0
		fire.initial_velocity_min = 4.0
		fire.initial_velocity_max = 12.0
		fire.damping_min = 6.0
		fire.damping_max = 10.0
		fire.gravity = Vector3(0.0, 2.0, 0.0)
		fire.scale_amount_min = 3.0
		fire.scale_amount_max = 6.0
		add_child(fire)
		fire.emitting = true

		var debris := CPUParticles3D.new()
		var chunk := BoxMesh.new()
		chunk.size = Vector3(0.4, 0.25, 0.5)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.2, 0.22)
		chunk.material = m
		debris.mesh = chunk
		debris.amount = 16
		debris.lifetime = 2.0
		debris.one_shot = true
		debris.explosiveness = 1.0
		debris.local_coords = false
		debris.direction = Vector3.UP
		debris.spread = 120.0
		debris.initial_velocity_min = 10.0
		debris.initial_velocity_max = 22.0
		debris.angular_velocity_min = -360.0
		debris.angular_velocity_max = 360.0
		debris.gravity = Vector3(0.0, -20.0, 0.0)
		add_child(debris)
		debris.emitting = true

		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.25)
		_light.light_energy = 6.0
		_light.omni_range = 30.0
		add_child(_light)

	func _process(delta: float) -> void:
		_t += delta
		_light.light_energy = maxf(0.0, 6.0 * (1.0 - _t / 0.4))
		if _t > 2.5:
			queue_free()
