class_name Effects
extends RefCounted
## Shared particle setups. CPUParticles3D so they run on the Compatibility renderer and
## on any phone.


## Camera-facing soft puffs. `colors` fade over each particle's life.
## `glows`: fire and flame keep their light at night; other unshaded wisps (dust, spray,
## trails) dim with the time of day, or they would shine in the dark.
static func puffs(colors: Gradient, amount: int, lifetime: float, dense := false, glows := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	# Dense smoke is lit by the sun so it reads as a solid plume; wisps stay unshaded.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if dense else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	if not dense and not glows:
		var dim: float = MapKit.TIMES[MapKit.time_of_day()].get("unlit", 1.0)
		m.albedo_color = Color(dim, dim, dim)
	# BILLBOARD_PARTICLES loses the per-particle scale on the Compatibility renderer.
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _smoke_dot() if dense else _soft_dot()
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


## A soft, cloudy white puff (radial falloff times noise), made once.
static func _soft_dot() -> Texture2D:
	return Baked.texture("puff")


## A thick, lumpy puff for smoke plumes: nearly opaque in the middle. Baked, see Baked.
static func _smoke_dot() -> Texture2D:
	return Baked.texture("smoke")


static func smoke_image() -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var size := 128
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var cloud := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := 1.0 - smoothstep(0.45, 1.0, d + (cloud - 0.5) * 0.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(edge * (0.85 + cloud * 0.3), 0.0, 1.0)))
	return image


static func _soft_dot_image() -> Image:
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
	return image


## Muzzle flash: a hot core with a few uneven spikes.
static func star_texture() -> Texture2D:
	return Baked.texture("muzzle_star")


static func star_image() -> Image:
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
	return image


## Bullet strike in glass: a crushed white centre, jagged radial cracks and a few
## broken rings around them.
static func crack_texture() -> Texture2D:
	return Baked.texture("glass_cracks")


static func crack_image() -> Image:
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
	return image


static func _draw_line(image: Image, a: Vector2, b: Vector2, alpha: float) -> void:
	var steps := ceili((b - a).length() * 1.5)
	for k in steps + 1:
		var p := a.lerp(b, float(k) / maxf(steps, 1))
		for o: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var q := Vector2i(p) + o
			if q.x >= 0 and q.y >= 0 and q.x < image.get_width() and q.y < image.get_height():
				var weight := alpha if o == Vector2i.ZERO else alpha * 0.6
				image.set_pixelv(q, Color(1, 1, 1, maxf(image.get_pixelv(q).a, weight)))


## Streaks of glowing metal or embers: thin bars stretched along their flight.
static func sparks(amount: int, lifetime: float, speed: Vector2, color: Color, length := 0.3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.03, length, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color  # Above 1: glows.
	m.disable_receive_shadows = true
	bar.material = m
	p.mesh = bar
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.particle_flag_align_y = true
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, -14.0, 0.0)
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Small chips of dirt, rock or metal tumbling away under gravity.
static func chips(amount: int, color: Color, size: float, speed: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3(1.0, 0.6, 0.8) * size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	chunk.material = m
	p.mesh = chunk
	p.amount = amount
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.particle_flag_rotate_y = true
	p.gravity = Vector3(0.0, -20.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	return p


## A bright star that pops up and fades: the first frames of a blast or a hit.
static func flash(size: float, color: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = star_texture()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Burnt ground: a dark, ragged blot fading out at the edge.
static func scorch_texture() -> Texture2D:
	return Baked.texture("scorch")


static func scorch_image() -> Image:
	var size := 128
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.06
	noise.fractal_octaves = 4
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := (Vector2(x, y) - Vector2.ONE * size * 0.5) / (size * 0.5)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - smoothstep(0.35, 1.0, p.length() + (n - 0.5) * 0.5)) * 1.2, 0.0, 0.92)
			var c := lerpf(0.03, 0.12, n)
			image.set_pixel(x, y, Color(c, c * 0.9, c * 0.8, a))
	return image


## A bullet striking something: sparks off metal, a dust puff and chips off the ground,
## a splash on water. Cleans itself up.
class Impact extends Node3D:
	enum Kind { METAL, GROUND, WATER }
	var kind := Kind.GROUND
	var normal := Vector3.UP
	var _t := 0.0
	var _light: OmniLight3D

	func _ready() -> void:
		# Callers place us right after add_child; emit once we're there, or the
		# world-space particles would burst at the origin.
		_start.call_deferred()

	func _start() -> void:
		var out := normal.normalized()
		var sound: String = ["impact_metal", "impact_dirt", "splash"][kind]
		Sounds.play_at(get_parent(), sound, global_position, -8.0, randf_range(0.9, 1.15), 0.6)
		match kind:
			Kind.METAL:
				var s := Effects.sparks(14, 0.35, Vector2(8.0, 20.0), Color(4.0, 2.2, 0.7), 0.25)
				_emit(s, out, 70.0)
				var f := Effects.flash(1.2, Color(1.0, 0.8, 0.5))
				add_child(f)
				_light = OmniLight3D.new()
				_light.light_color = Color(1.0, 0.7, 0.3)
				_light.light_energy = 2.0
				_light.omni_range = 4.0
				add_child(_light)
				var smoke := Effects.puffs(Effects.gradient([Color(0.3, 0.3, 0.3, 0.5), Color(0.25, 0.25, 0.25, 0.0)]), 3, 0.8)
				smoke.scale_amount_min = 0.6
				smoke.scale_amount_max = 1.0
				_emit(smoke, out, 30.0, Vector2(1.0, 2.0))
			Kind.GROUND:
				var dust := Effects.puffs(Effects.gradient([
					Color(0.66, 0.58, 0.46, 0.7), Color(0.62, 0.55, 0.45, 0.4), Color(0.6, 0.55, 0.47, 0.0)]), 5, 1.2)
				dust.scale_amount_min = 1.0
				dust.scale_amount_max = 2.2
				dust.damping_min = 4.0
				dust.damping_max = 6.0
				_emit(dust, out, 35.0, Vector2(2.0, 5.0))
				# A fast spurt straight out of the ground: readable from far away.
				var spurt := Effects.puffs(Effects.gradient([
					Color(0.55, 0.47, 0.36, 0.85), Color(0.6, 0.53, 0.43, 0.0)]), 4, 0.45)
				spurt.scale_amount_min = 0.6
				spurt.scale_amount_max = 1.0
				spurt.damping_min = 9.0
				spurt.damping_max = 12.0
				_emit(spurt, out, 8.0, Vector2(9.0, 14.0))
				_emit(Effects.chips(10, Color(0.3, 0.25, 0.2), 0.08, Vector2(5.0, 12.0)), out, 30.0)
				_emit(Effects.sparks(4, 0.2, Vector2(6.0, 12.0), Color(3.0, 1.8, 0.6), 0.18), out, 60.0)
			Kind.WATER:
				var spray := Effects.puffs(Effects.gradient([
					Color(0.95, 0.97, 1.0, 0.8), Color(0.9, 0.95, 1.0, 0.4), Color(0.9, 0.95, 1.0, 0.0)]), 7, 0.9)
				spray.gravity = Vector3(0.0, -9.0, 0.0)
				spray.scale_amount_min = 0.4
				spray.scale_amount_max = 0.9
				_emit(spray, Vector3.UP, 12.0, Vector2(4.0, 8.0))
				var drops := Effects.chips(8, Color(0.85, 0.92, 1.0), 0.07, Vector2(3.0, 7.0))
				drops.gravity = Vector3(0.0, -14.0, 0.0)
				_emit(drops, Vector3.UP, 30.0)

	func _emit(p: CPUParticles3D, direction: Vector3, spread: float, speed := Vector2.ZERO) -> void:
		p.direction = direction
		p.spread = spread
		p.one_shot = true
		p.explosiveness = 1.0
		if speed != Vector2.ZERO:
			p.initial_velocity_min = speed.x
			p.initial_velocity_max = speed.y
		add_child(p)
		p.emitting = true

	func _process(delta: float) -> void:
		_t += delta
		if _light:
			_light.light_energy = maxf(0.0, 2.0 * (1.0 - _t / 0.08))
		for child in get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = _t < 0.06
		if _t > 1.6:
			queue_free()


## Burnt ground left by a blast; fades away after a while.
class Scorch extends Decal:
	var _t := 0.0

	func _ready() -> void:
		texture_albedo = Effects.scorch_texture()
		upper_fade = 0.3
		lower_fade = 0.3
		rotation.y = randf() * TAU

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = 1.0 - smoothstep(20.0, 30.0, _t)
		if _t > 30.0:
			queue_free()


## Fireball, smoke column, embers, flying debris, a shock wave, a flash of light and a
## scorch mark on the ground. Shakes nearby cameras. Cleans itself up.
class Explosion extends Node3D:
	var size := 1.0  ## Scales the fireball, debris and flash.
	var _t := 0.0
	var _light: OmniLight3D
	var _flash: MeshInstance3D
	var _wave: MeshInstance3D
	var _wave_material: ShaderMaterial

	func _ready() -> void:
		set_process(false)
		# Callers place us right after add_child; emit once we're there, or the
		# world-space particles would burst at the origin.
		_start.call_deferred()

	func _start() -> void:
		set_process(true)
		var fire := Effects.puffs(Effects.gradient([
			Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.42, 0.06, 0.95), Color(0.45, 0.16, 0.04, 0.85),
			Color(0.12, 0.1, 0.09, 0.5), Color(0.1, 0.1, 0.1, 0.0),
		]), 46, 1.5, false, true)
		fire.one_shot = true
		fire.explosiveness = 0.92
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.direction = Vector3.UP
		fire.spread = 180.0
		fire.initial_velocity_min = 4.0
		fire.initial_velocity_max = 13.0
		fire.damping_min = 6.0
		fire.damping_max = 10.0
		fire.gravity = Vector3(0.0, 2.5, 0.0)
		fire.scale_amount_min = 3.0 * size
		fire.scale_amount_max = 6.5 * size
		fire.emission_sphere_radius = 1.5 * size
		add_child(fire)
		fire.emitting = true

		# A column of black smoke that lingers after the fire is gone.
		var smoke := Effects.puffs(Effects.gradient([
			Color(0.1, 0.09, 0.08, 0.0), Color(0.1, 0.09, 0.08, 0.75), Color(0.16, 0.15, 0.14, 0.45),
			Color(0.22, 0.21, 0.2, 0.0),
		]), 18, 4.0, true)
		smoke.one_shot = true
		smoke.explosiveness = 0.7
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 1.8 * size
		smoke.direction = Vector3.UP
		smoke.spread = 35.0
		smoke.initial_velocity_min = 2.0
		smoke.initial_velocity_max = 5.0
		smoke.damping_min = 1.0
		smoke.damping_max = 2.0
		smoke.gravity = Vector3(0.0, 1.5, 0.0)
		smoke.scale_amount_min = 4.0 * size
		smoke.scale_amount_max = 8.0 * size
		add_child(smoke)
		smoke.emitting = true

		var embers := Effects.sparks(int(36 * size), 1.3, Vector2(14.0, 34.0) * sqrt(size), Color(2.2, 0.75, 0.12),
			0.5 * size)
		embers.direction = Vector3.UP
		embers.spread = 180.0
		add_child(embers)
		embers.emitting = true

		var debris := Effects.chips(16, Color(0.14, 0.14, 0.15), 0.45 * size, Vector2(10.0, 22.0) * size)
		debris.direction = Vector3.UP
		debris.spread = 120.0
		debris.lifetime = 2.2
		add_child(debris)
		debris.emitting = true

		_flash = Effects.flash(10.0 * size, Color(1.0, 0.75, 0.4))
		add_child(_flash)

		# Shock wave: a disc of bent air racing outward.
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_wave_material = ShaderMaterial.new()
		_wave_material.shader = preload("res://shaders/heat_haze.gdshader")
		quad.material = _wave_material
		_wave = MeshInstance3D.new()
		_wave.mesh = quad
		_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_wave)

		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.25)
		_light.light_energy = 8.0
		_light.omni_range = 35.0 * size
		_light.shadow_enabled = Graphics.at_least(Graphics.Quality.HIGH)
		add_child(_light)

		_scorch_ground()
		# Bigger blasts are louder and deeper.
		Sounds.play_at(get_parent(), "explosion", global_position, 4.0 + linear_to_db(size),
			randf_range(0.9, 1.05) / pow(size, 0.25), 2.0)
		get_tree().call_group("shake_cameras", "shake_from", global_position, size)

	func _scorch_ground() -> void:
		if not is_inside_tree():
			return
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 8.0 * size)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider is Choppa or (hit.collider as Node).is_in_group("water"):
			return
		var scorch := Scorch.new()
		scorch.size = Vector3(9.0, 4.0, 9.0) * size
		get_parent().add_child(scorch)
		scorch.global_position = hit.position

	func _process(delta: float) -> void:
		_t += delta
		_light.light_energy = maxf(0.0, 8.0 * (1.0 - _t / 0.45))
		_flash.visible = _t < 0.12
		_flash.scale = Vector3.ONE * (0.6 + _t * 5.0)
		var w := clampf(_t / 0.4, 0.0, 1.0)
		_wave.visible = w < 1.0
		_wave.scale = Vector3.ONE * (2.0 + w * 26.0 * size)
		_wave_material.set_shader_parameter("strength", 0.04 * (1.0 - w))
		if _t > 4.5:
			queue_free()


## What is left of a shot-down choppa: its body, charred, tumbling down from where it
## blew up, then lying on the ground burning and smoking for half a minute before it
## fades. Purely visual (no collision), so nobody crashes into a wreck they cannot see
## coming on a network client.
class Wreck extends Node3D:
	const LIFETIME := 30.0
	const BURN_TIME := 22.0
	const GRAVITY := 14.0
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO  ## rad/s while it falls.
	var _t := 0.0
	var _landed := false
	var _fire: CPUParticles3D
	var _smoke: CPUParticles3D
	var _light: OmniLight3D
	var _charred: StandardMaterial3D

	## Copies the body meshes of `model` (not the rotors: they flew off) in place.
	func take_from(model: Node3D) -> void:
		_charred = StandardMaterial3D.new()
		_charred.albedo_color = Color(0.06, 0.055, 0.05)
		_charred.roughness = 0.95
		_charred.metallic = 0.2
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var source := node as MeshInstance3D
			var name := String(source.name)
			if name.begins_with("rotor") or name.begins_with("tail_rotor") or not source.is_visible_in_tree():
				continue
			if source.mesh == null or source.mesh.get_aabb().size.length() < 1.5:
				continue  # Small bits: glass glints, effect quads.
			var copy := MeshInstance3D.new()
			copy.mesh = source.mesh
			copy.material_override = _charred
			add_child(copy)
			copy.transform = global_transform.affine_inverse() * source.global_transform

	func _ready() -> void:
		_fire = Effects.puffs(Effects.gradient([
			Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.25, 0.05, 0.6), Color(0.2, 0.2, 0.2, 0.0),
		]), 50, 0.8, false, true)
		_fire.direction = Vector3.UP
		_fire.spread = 35.0
		_fire.initial_velocity_min = 2.0
		_fire.initial_velocity_max = 5.0
		_fire.scale_amount_min = 0.8
		_fire.scale_amount_max = 2.0
		_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_fire.emission_sphere_radius = 1.4
		add_child(_fire)
		_smoke = Effects.puffs(Effects.gradient([
			Color(0.1, 0.1, 0.1, 0.0), Color(0.08, 0.08, 0.08, 0.9), Color(0.14, 0.14, 0.14, 0.8), Color(0.3, 0.3, 0.3, 0.0),
		]), 70, 6.0, true)
		_smoke.direction = Vector3.UP
		_smoke.spread = 12.0
		_smoke.initial_velocity_min = 3.0
		_smoke.initial_velocity_max = 5.0
		_smoke.gravity = Vector3(0.6, 1.5, 0.0)  # A column, leaning a little with the wind.
		_smoke.scale_amount_min = 3.0
		_smoke.scale_amount_max = 7.0
		add_child(_smoke)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.55, 0.2)
		_light.light_energy = 3.0
		_light.omni_range = 9.0
		_light.position = Vector3.UP * 1.5
		add_child(_light)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _landed:
			velocity.y -= GRAVITY * delta
			var step := velocity * delta
			var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step + Vector3.DOWN * 1.0)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit and not hit.collider is Choppa:
				global_position = hit.position + Vector3.UP * 0.6
				_landed = true
				# Settle: keep the heading, nose about level, rolled over on a side if it hit
				# rolling (a wreck does not stand on its nose).
				var roll := wrapf(rotation.z, -PI, PI)
				rotation = Vector3(clampf(wrapf(rotation.x, -PI, PI), -0.25, 0.25), rotation.y,
					clampf(roll, -1.3, 1.3) if absf(roll) > 0.5 else roll * 0.3)
			else:
				global_position += step
				rotation += spin * delta
		var burning := clampf(1.0 - (_t - BURN_TIME) / 4.0, 0.0, 1.0)
		_fire.emitting = burning > 0.2
		_smoke.emitting = _t < LIFETIME - 6.0
		_light.light_energy = 3.0 * burning * (0.75 + 0.25 * sin(_t * 23.0) * sin(_t * 7.0))
		if _t > LIFETIME - 3.0:
			_charred.albedo_color.a = 0.0
			scale = Vector3.ONE * maxf(0.01, (LIFETIME - _t) / 3.0)  # Sinks away at the end.
		if _t > LIFETIME:
			queue_free()

