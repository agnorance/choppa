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
	# Fade out where puffs cut into the ground or walls instead of a hard edge.
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
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


## A soft, cloudy white puff (radial falloff times noise), made once.
static func _soft_dot() -> Texture2D:
	if _dot:
		return _dot
	var noise := FastNoiseLite.new()
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var size := 128
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var cloud := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d * d) * (0.35 + cloud * 0.9), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	image.generate_mipmaps()
	_dot = ImageTexture.create_from_image(image)
	return _dot


static var _star: Texture2D
static var _crack: Texture2D


## Muzzle flash: a hot core with a few uneven spikes.
static func star_texture() -> Texture2D:
	if _star:
		return _star
	var size := 128
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var spikes := [0.0, 0.9, 1.7, 2.5, 3.3, 4.1, 5.0, 5.7]
	for y in size:
		for x in size:
			var p := (Vector2(x, y) - Vector2.ONE * size * 0.5) / (size * 0.5)
			var r := p.length()
			var a := 0.0
			for k in spikes.size():
				var d := absf(angle_difference(p.angle(), spikes[k]))
				var reach := 0.55 + 0.45 * fmod(k * 0.37, 1.0)
				a = maxf(a, (1.0 - smoothstep(0.0, 0.18 * (1.0 - r / reach), d)) * (1.0 - smoothstep(0.0, reach, r)))
			a = maxf(a, 1.0 - smoothstep(0.0, 0.35, r))
			image.set_pixel(x, y, Color(1.0, 0.8 + 0.2 * (1.0 - r), 0.55 + 0.45 * (1.0 - r), clampf(a, 0.0, 1.0)))
	image.generate_mipmaps()
	_star = ImageTexture.create_from_image(image)
	return _star


## Bullet strike in glass: a crushed white centre, jagged radial cracks and a few
## broken rings around them.
static func crack_texture() -> Texture2D:
	if _crack:
		return _crack
	var size := 256
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var c := Vector2.ONE * size * 0.5
	var rays := 11
	for k in rays:
		var angle := TAU * k / rays + rng.randf_range(-0.2, 0.2)
		var length := rng.randf_range(0.55, 0.98) * size * 0.5
		var p := c
		var step := 0
		while (p - c).length() < length:
			angle += rng.randf_range(-0.25, 0.25)
			var next := p + Vector2.from_angle(angle) * 6.0
			_draw_line(image, p, next, 0.9 - 0.5 * (p - c).length() / (size * 0.5))
			# The odd side branch.
			if step % 5 == 4 and rng.randf() < 0.5:
				var branch := angle + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
				_draw_line(image, next, next + Vector2.from_angle(branch) * rng.randf_range(10.0, 24.0), 0.5)
			p = next
			step += 1
	for ring in 3:
		var radius := (0.15 + ring * 0.17) * size * 0.5
		var start := rng.randf() * TAU
		var arc := rng.randf_range(2.0, 4.5)
		var prev := c + Vector2.from_angle(start) * radius
		for k in 24:
			var a := start + arc * (k + 1) / 24.0
			var next := c + Vector2.from_angle(a) * radius * rng.randf_range(0.95, 1.05)
			_draw_line(image, prev, next, 0.45)
			prev = next
	# Crushed glass in the middle.
	for y in size:
		for x in size:
			var r := (Vector2(x, y) - c).length() / (size * 0.5)
			var core := (1.0 - smoothstep(0.0, 0.16, r)) * rng.randf_range(0.5, 1.0)
			var px := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1, 1, 1, maxf(px.a, core)))
	image.generate_mipmaps()
	_crack = ImageTexture.create_from_image(image)
	return _crack


static func _draw_line(image: Image, a: Vector2, b: Vector2, alpha: float) -> void:
	var steps := ceili((b - a).length() * 1.5)
	for k in steps + 1:
		var p := a.lerp(b, float(k) / maxf(steps, 1))
		for o: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var q := Vector2i(p) + o
			if q.x >= 0 and q.y >= 0 and q.x < image.get_width() and q.y < image.get_height():
				var weight := alpha if o == Vector2i.ZERO else alpha * 0.6
				image.set_pixelv(q, Color(1, 1, 1, maxf(image.get_pixelv(q).a, weight)))


## Fireball, smoke, flying debris and a flash of light. Cleans itself up.
class Explosion extends Node3D:
	var size := 1.0  ## Scales the fireball, debris and flash.
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
		fire.direction = Vector3.UP
		fire.spread = 180.0
		fire.initial_velocity_min = 4.0
		fire.initial_velocity_max = 12.0
		fire.damping_min = 6.0
		fire.damping_max = 10.0
		fire.gravity = Vector3(0.0, 2.0, 0.0)
		fire.scale_amount_min = 3.0 * size
		fire.scale_amount_max = 6.0 * size
		fire.emission_sphere_radius = 1.5 * size
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
		debris.initial_velocity_min = 10.0 * size
		debris.initial_velocity_max = 22.0 * size
		debris.angular_velocity_min = -360.0
		debris.angular_velocity_max = 360.0
		debris.gravity = Vector3(0.0, -20.0, 0.0)
		add_child(debris)
		debris.emitting = true

		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.25)
		_light.light_energy = 6.0
		_light.omni_range = 30.0 * size
		add_child(_light)

	func _process(delta: float) -> void:
		_t += delta
		_light.light_energy = maxf(0.0, 6.0 * (1.0 - _t / 0.4))
		if _t > 2.5:
			queue_free()
