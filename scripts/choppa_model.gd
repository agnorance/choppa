class_name ChoppaModel
extends Node3D
## The helicopter model (assets/models/choppa, built by tools/blender/make_choppa.py)
## with its hull materials, spinning rotors and effects.
## Purely visual: it never affects the simulation. Forward is -Z.

## Render layer bit for the local player's own choppa, hidden from the cockpit camera.
const OWN_LAYER := 1 << 1

var color := Color(0.95, 0.5, 0.1)  ## The pilot's colour: roundels and the tail marking.
var camo := "factory"  ## Progression.CAMOS id for the hull paint.
var silent := false  ## No engine sounds (the hangar turntable).
var _paint: ShaderMaterial  ## The hull material the camo lives on.
var _tips: ShaderMaterial  ## Rotor tips and hazard stripes (Apex paints them gold).
var own := false  ## Set before adding to the tree to put meshes on OWN_LAYER.
var pilot: Choppa  ## The choppa this model shows; feeds the cockpit instruments.
var cockpit: Marker3D  ## First-person camera mount.
var cockpit_view: Cockpit  ## Instrumented interior, local player only.

var _parts: Node3D  ## All meshes, so the spawn shield can blink them.
var _rotor: Node3D
var _tail_rotor: Node3D
var _rotor_upper: Node3D  ## Coaxial classes: the second rotor, turning the other way.
var _blur_material: StandardMaterial3D
var _rotor_speed := 0.0
var _dust: CPUParticles3D
var _trails: Array[CPUParticles3D] = []
var _smoke: CPUParticles3D
var _tail_smoke: CPUParticles3D
var _fire: CPUParticles3D  ## A wrecked engine burns.
var _tail_sparks: CPUParticles3D  ## Where the tail rotor was.
var _flashes: Array[Node3D] = []  ## Left, right.
var _flash_lights: Array[OmniLight3D] = []
var _casings: Array[CPUParticles3D] = []
var _barrel_smoke: Array[CPUParticles3D] = []  ## Hot barrels smoke between bursts.
var _haze: Array[CPUParticles3D] = []
var _downwash: MeshInstance3D
var _downwash_material: ShaderMaterial
var _dust_colors: Gradient
var _spray_colors: Gradient
var _cracks: Array[MeshInstance3D] = []
const ROTOR_DB := -4.0
const ENGINE_DB := -8.0
const BOOST_DB := -6.0
const INSIDE_DB := -9.0  ## Own rotor, guns and afterburner from the cockpit.
var _rotor_sound: AudioStreamPlayer3D
var _engine_sound: AudioStreamPlayer3D
var _boost_sound: AudioStreamPlayer3D
var _last_shot := -10.0
var _burst := 0  ## Rounds in the current burst, for the tail when it ends.


var airframe := Airframe.SCOUT  ## Which model to wear; see Airframe.TABLE.
## Where the model's guns and rocket pods are (body space, left then right); empty when
## the model has no such markers, and the choppa falls back to the scout's positions.
var muzzles: Array[Vector3] = []
var pods: Array[Vector3] = []


func _ready() -> void:
	_build()


## Repaints the hull with a camo (Progression.CAMOS id).
func set_camo(id: String) -> void:
	camo = id
	if _paint:
		_apply_camo()


func _apply_camo() -> void:
	Progression.apply_camo(_paint, camo)
	var tips: Color = Progression.CAMOS.get(camo, {}).get("tips", Color(0.85, 0.62, 0.12))
	_tips.set_shader_parameter("paint", tips)
	_tips.set_shader_parameter("paint_metal", 0.9 if camo == "apex" else 0.15)


## The Blender model itself (body, rotors), without the effects, discs and cockpit.
func airframe_model() -> Node3D:
	return _parts.get_child(0) as Node3D if _parts and _parts.get_child_count() > 0 else self


## Swaps the model for another airframe's (rebuilds everything the model owns).
func set_airframe(id: String) -> void:
	if id == airframe:
		return
	airframe = id
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_haze.clear()
	_trails.clear()
	_flashes.clear()
	_flash_lights.clear()
	_casings.clear()
	_barrel_smoke.clear()
	_cracks.clear()
	_build()


func _build() -> void:
	_parts = Node3D.new()
	add_child(_parts)
	var model: Node3D = _scene(airframe).instantiate()
	_parts.add_child(model)
	var materials := part_materials(Color(0.36, 0.38, 0.27))
	# The pilot's colour on the roundels, so rivals stay recognisable whatever their camo.
	materials.marking_red = _hull(color, Vector2(1.35, 0.75))
	_paint = materials.paint
	_tips = materials.hazard
	var nose: Array = Airframe.spec(airframe).nose
	for k in 3:
		_paint.set_shader_parameter(["nose_tip", "nose_y", "nose_len"][k], nose[k])
	_apply_camo()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		for k in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(k)
			var name := source.resource_name if source else "paint"
			mesh.set_surface_override_material(k, materials.get(name, materials.paint))
		if own:
			mesh.layers = OWN_LAYER
	muzzles.clear()
	pods.clear()
	for side in ["l", "r"]:
		if model.find_child("muzzle_" + side):
			muzzles.append(_marker(model, "muzzle_" + side))
		if model.find_child("pod_" + side):
			pods.append(_marker(model, "pod_" + side))
	_rotor = model.find_child("rotor")
	_tail_rotor = model.find_child("tail_rotor")
	_rotor_upper = model.find_child("rotor_upper")
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
		cockpit_view.airframe = airframe
		cockpit_view.position = eye
		add_child(cockpit_view)
	else:
		var shell := Cockpit.shell(airframe)
		shell.position = eye
		_parts.add_child(shell)

	_build_guns(model)
	_build_cracks(model)
	for exhaust in ["exhaust_l", "exhaust_r"]:
		_haze.append(_build_haze(_marker(model, exhaust)))
	_build_downwash()

	if not silent:
		# Rotor slap carries furthest; the engine and boost roar are closer up.
		_rotor_sound = Sounds.loop_on(self, "rotor_loop", ROTOR_DB, 1.4)
		_rotor_sound.position = _rotor.position
		_engine_sound = Sounds.loop_on(self, "engine_loop", ENGINE_DB)
		_engine_sound.position = _rotor.position * Vector3(1.0, 0.6, 1.0)
		_boost_sound = Sounds.loop_on(self, "boost_loop", BOOST_DB)
		_boost_sound.position = _engine_sound.position + Vector3(0.0, 0.0, 1.0)
		_boost_sound.stream_paused = true
	if own and pilot and not pilot.restocked.is_connected(_on_restocked):
		pilot.restocked.connect(_on_restocked)

	# Rotor downwash kicking up dust (or spray over water) when flying low.
	_dust_colors = Effects.gradient([
		Color(0.66, 0.58, 0.46, 0.0), Color(0.66, 0.58, 0.46, 0.32), Color(0.64, 0.57, 0.47, 0.0),
	])
	_spray_colors = Effects.gradient([
		Color(0.9, 0.95, 1.0, 0.0), Color(0.88, 0.94, 1.0, 0.6), Color(0.85, 0.92, 1.0, 0.0),
	])
	# Lit and earth-coloured: unlit pale puffs glowed like separate white blobs on grass.
	_dust = Effects.puffs(_dust_colors, 72, 1.8, true)
	# Lit, but with the soft dot: the dense smoke texture showed each puff as a disc.
	((_dust.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture = Effects._soft_dot()
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
	_dust.scale_amount_min = 2.5
	_dust.scale_amount_max = 5.0
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


	# Thick black smoke out of the engine when badly damaged: many big, slow, dark puffs
	# that keep growing, so it reads as a plume from across the arena.
	_smoke = Effects.puffs(Effects.gradient([
		Color(0.12, 0.12, 0.12, 0.0), Color(0.1, 0.1, 0.1, 1.0), Color(0.16, 0.16, 0.16, 0.9),
		Color(0.3, 0.3, 0.3, 0.0),
	]), 110, 3.6, true)
	_smoke.position = _rotor.position * Vector3(1.0, 0.7, 1.0)  # Out of the engine.
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 4.5
	_smoke.damping_min = 0.5
	_smoke.damping_max = 1.0
	_smoke.gravity = Vector3(0.0, 2.5, 0.0)
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 6.0
	_smoke.emitting = false
	add_child(_smoke)
	_tail_smoke = Effects.puffs(Effects.gradient([
		Color(0.25, 0.25, 0.25, 0.0), Color(0.2, 0.2, 0.2, 0.95), Color(0.3, 0.3, 0.3, 0.7),
		Color(0.4, 0.4, 0.4, 0.0),
	]), 80, 3.0, true)
	_tail_smoke.position = _tail_rotor.position
	_tail_smoke.direction = Vector3.BACK
	_tail_smoke.spread = 30.0
	_tail_smoke.initial_velocity_min = 1.5
	_tail_smoke.initial_velocity_max = 3.5
	_tail_smoke.damping_min = 0.5
	_tail_smoke.damping_max = 1.0
	_tail_smoke.gravity = Vector3(0.0, 2.0, 0.0)
	_tail_smoke.scale_amount_min = 2.2
	_tail_smoke.scale_amount_max = 4.5
	_tail_smoke.emitting = false
	add_child(_tail_smoke)
	_fire = Effects.puffs(Effects.gradient([
		Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.25, 0.05, 0.6), Color(0.2, 0.2, 0.2, 0.0),
	]), 40, 0.7)
	_fire.position = _rotor.position * Vector3(1.0, 0.75, 1.0) + Vector3(0.0, 0.0, 0.6)
	_fire.direction = Vector3.UP
	_fire.spread = 25.0
	_fire.initial_velocity_min = 2.0
	_fire.initial_velocity_max = 4.0
	_fire.scale_amount_min = 0.6
	_fire.scale_amount_max = 1.4
	_fire.emitting = false
	add_child(_fire)
	_tail_sparks = Effects.sparks(18, 0.4, Vector2(3.0, 9.0), Color(4.0, 2.2, 0.7), 0.2)
	_tail_sparks.position = _tail_rotor.position
	_tail_sparks.emitting = false
	add_child(_tail_sparks)


## Spins the rotors and drives the effects; the body's attitude is the choppa's own
## transform now, so the model sits straight on it.
func update_pose(c: Choppa, delta: float) -> void:
	var target_rotor := (20.0 + (10.0 if c.is_boosting() else 0.0) + c.velocity.y * 0.3) * c.spool
	_rotor_speed = lerpf(_rotor_speed, target_rotor, 1.0 - exp(-3.0 * delta))
	# A chewed-up main rotor wobbles on its mast; a wrecked tail rotor is gone.
	var rotor_wear := c.wear(Choppa.Part.ROTOR)
	var wobble := 0.08 * rotor_wear * rotor_wear
	_rotor.rotation = Vector3(sin(c.clock * 21.0) * wobble, _rotor.rotation.y + _rotor_speed * delta, cos(c.clock * 17.0) * wobble)
	if _rotor_upper:
		_rotor_upper.rotation = Vector3(-_rotor.rotation.x, _rotor_upper.rotation.y - _rotor_speed * delta, -_rotor.rotation.z)
	var tail_gone := c.wear(Choppa.Part.TAIL) >= 1.0
	_tail_rotor.visible = not tail_gone
	if not tail_gone:
		_tail_rotor.rotate_x(_rotor_speed * 1.6 * delta)
	_tail_sparks.emitting = tail_gone and c.alive and fmod(c.clock, 1.3) < 0.25
	_fire.emitting = c.alive and c.wear(Choppa.Part.ENGINE) >= 1.0
	_blur_material.albedo_color.a = clampf((_rotor_speed - 8.0) / 80.0, 0.0, 0.1)
	var voice: float = Airframe.spec(c.airframe).pitch  # The scout buzzes, the heavy drones.
	_rotor_sound.pitch_scale = clampf(_rotor_speed / 22.0, 0.5, 1.6) * voice
	_engine_sound.pitch_scale = clampf(0.85 + _rotor_speed / 80.0 + c.input.collective * 0.08, 0.6, 1.5) * voice
	_rotor_sound.stream_paused = not c.alive
	_engine_sound.stream_paused = not c.alive
	_boost_sound.stream_paused = not c.is_boosting() or not c.alive
	# In the cockpit the listener sits right at the rotor and the guns: without this they
	# play at full volume (owner: "inside is way too loud"). The engine whine stays more.
	var inside := cockpit_view != null and cockpit_view.reticle.visible
	# Spooling up from cold: the turbine whine rises first, the rotor slap follows.
	var spin := sqrt(c.spool)
	_rotor_sound.volume_db = ROTOR_DB + (INSIDE_DB if inside else 0.0) + lerpf(-30.0, 0.0, spin)
	_engine_sound.volume_db = ENGINE_DB + (INSIDE_DB * 0.55 if inside else 0.0) + lerpf(-18.0, 0.0, spin)
	_engine_sound.pitch_scale *= lerpf(0.45, 1.0, spin)
	_rotor_sound.stream_paused = not c.alive or c.spool < 0.02
	_engine_sound.stream_paused = not c.alive or c.spool < 0.02
	_boost_sound.volume_db = BOOST_DB + (INSIDE_DB if inside else 0.0)
	var gun_db := (0.0 if own else -3.0) + (INSIDE_DB if inside else 0.0)
	if c.last_shot_time != _last_shot and c.last_shot_time > _last_shot:
		_last_shot = c.last_shot_time
		_burst += 1
		var muzzle := global_transform * (_flashes[1 if c.last_shot_side > 0.0 else 0].position)
		Sounds.play_at(get_tree().current_scene, "gun", muzzle, gun_db + (voice - 1.0) * -8.0, randf_range(0.94, 1.06) * voice)
	elif _burst > 0 and c.clock - c.last_shot_time > c.gun_interval * 1.6:
		# The burst ended: its sound rolls on over the terrain. Longer bursts, a bigger tail.
		Sounds.play_at(get_tree().current_scene, "gun_tail", global_position,
			gun_db - 4.0 + minf(_burst, 12.0) * 0.25, randf_range(0.95, 1.05), 1.5)
		_burst = 0

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
		_casings[k].emitting = c.alive and c.clock - c.last_shot_time < c.gun_interval * 1.5
		_barrel_smoke[k].emitting = c.alive and (c.overheated or c.heat > 0.45) \
			and c.clock - c.last_shot_time > c.gun_interval * 2.0
	for haze in _haze:
		haze.emitting = c.alive
	var visible_cracks := clampi(floori((Choppa.MAX_HEALTH - c.health) / 12.0), 0, _cracks.size()) if c.alive else 0
	for k in _cracks.size():
		_cracks[k].visible = k < visible_cracks
	for trail in _trails:
		trail.emitting = c.is_boosting()
	_smoke.emitting = c.health < 35.0 or c.wear(Choppa.Part.ENGINE) > 0.5
	_tail_smoke.emitting = c.wear(Choppa.Part.TAIL) > 0.5
	_dust.emitting = c.altitude < 14.0 and c.spool > 0.5  # A stopped rotor blows nothing.
	var ground := c.global_position + Vector3.DOWN * (c.altitude + c.clearance - 0.3)
	if _dust.emitting:
		_dust.global_position = ground
		_dust.color_ramp = _spray_colors if c.over_water else _dust_colors
	var wash := clampf(1.0 - c.altitude / 16.0, 0.0, 1.0) if c.alive else 0.0
	_downwash.visible = wash > 0.0
	if _downwash.visible:
		_downwash.global_position = ground + Vector3.UP * 0.15
		_downwash_material.set_shader_parameter("power", wash * 0.7 * c.lift_share())
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

		var smoke := Effects.puffs(Effects.gradient([
			Color(0.75, 0.75, 0.75, 0.0), Color(0.7, 0.7, 0.72, 0.35), Color(0.7, 0.7, 0.72, 0.0)]), 14, 1.1)
		smoke.position = at
		smoke.direction = Vector3.UP
		smoke.spread = 25.0
		smoke.initial_velocity_min = 0.4
		smoke.initial_velocity_max = 1.0
		smoke.gravity = Vector3(0.0, 1.2, 0.0)
		smoke.scale_amount_min = 0.25
		smoke.scale_amount_max = 0.5
		smoke.emitting = false
		add_child(smoke)
		_barrel_smoke.append(smoke)


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


static var _cached_scenes := {}


## Position of an empty from the Blender model, in model space.
static func _marker(model: Node3D, marker_name: String) -> Vector3:
	var node: Node3D = model.find_child(marker_name)
	return node.position if node else Vector3.ZERO


## The airframe's model (assets/models/choppa/<model>.glb), or the scout's until that
## model has been built in Blender.
static func _scene(id := Airframe.SCOUT) -> PackedScene:
	var model_name: String = Airframe.spec(id).model
	if not _cached_scenes.has(model_name):
		var path := "res://assets/models/choppa/%s.glb" % model_name
		if not ResourceLoader.exists(path):
			path = "res://assets/models/choppa/choppa.glb"
		_cached_scenes[model_name] = load(path)
	return _cached_scenes[model_name]


func _on_restocked() -> void:
	if is_inside_tree() and pilot and pilot.clock > 0.5:  # Not the restock at spawn.
		Sounds.play_ui(self, "pickup", -6.0)


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
