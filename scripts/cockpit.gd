class_name Cockpit
extends Node3D
## First-person cockpit: the class's Blender interior (assets/models/choppa/
## cockpit_<class>.glb, built by tools/blender/make_cockpit.py) plus live instruments at
## its "mount_*" markers: needle gauges, a radar scope, multi-function displays (flight,
## radar and systems pages), a head-up display, a nixie kill counter, a health lamp bar,
## the loadout plate, warning lamps and a rotating missile beacon. A mount the model
## does not have is simply left out. Stick and collective follow the controls. Origin =
## the pilot's eye. Only built for the local player.

## Panel paint per class: the teal-green of old control rooms, Apache grey, Soviet
## turquoise, a modern blue-grey.
const PAINTS := {"scout": Color(0.27, 0.38, 0.34), "gunship": Color(0.2, 0.22, 0.22),
	"heavy": Color(0.24, 0.46, 0.47), "striker": Color(0.22, 0.25, 0.29), "mule": Color(0.3, 0.32, 0.27)}
const SIGHT_DISTANCE := 0.6  ## The reticle is sized for a sight glass this far from the eye.
const CREAM := Color(0.92, 0.86, 0.7)
const AMBER := Color(1.0, 0.62, 0.2)

var choppa: Choppa
var airframe := Airframe.SCOUT  ## Which interior to build.
## Returns the kill count to show, or -1 for "--" (free flight). Set by the game mode.
var kills_source: Callable = func() -> int: return -1
var reticle: Node3D  ## The gunsight glow; only shown from the pilot's seat.

var _gauges := {}
var _stick: Node3D
var _stick_copilot: Node3D
var _collective: Node3D
var _health_cells: Array[MeshInstance3D] = []
var _cell_off: StandardMaterial3D
var _item_label: Label3D
var _nixies: Array[Label3D] = []
var _lamps := {}
var _beacon: Node3D
var _beacon_light: SpotLight3D
var _beacon_dome: StandardMaterial3D
var _radar: RadarScreen
var _clock := 0.0
var _warning: AudioStreamPlayer


## The bare interior of a class (no live instruments), also what other choppas show
## through their canopy.
static func shell(id := Airframe.SCOUT) -> Node3D:
	var path := "res://assets/models/choppa/cockpit_%s.glb" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/choppa/cockpit_scout.glb"
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var materials := ChoppaModel.part_materials(PAINTS.get(id, PAINTS.scout), Vector2(0.32, 0.2))
	materials.fabric = ChoppaModel._material(Color(0.16, 0.16, 0.13), 0.0, 0.95)
	materials.screen = ChoppaModel._material(Color(0.02, 0.025, 0.03), 0.3, 0.15)
	materials.placard = ChoppaModel._material(Color(0.78, 0.75, 0.66), 0.0, 0.7)
	materials.lamp_off = ChoppaModel._material(Color(0.22, 0.16, 0.08), 0.1, 0.3)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		for k in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(k)
			mesh.set_surface_override_material(k, materials.get(source.resource_name if source else "paint", materials.paint))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model


func _ready() -> void:
	var shell := Cockpit.shell(airframe)
	add_child(shell)
	_stick = shell.find_child("stick")
	_stick_copilot = shell.find_child("stick_copilot")
	_collective = shell.find_child("collective")

	for spec: Array in [["speed", "AIRSPEED", "km/h", 0.0, 300.0, 6, 2.0], ["altitude", "ALTITUDE", "m", 0.0, 100.0, 5, 2.0],
			["boost", "BOOST", "%", 0.0, 100.0, 4, 2.0], ["heat", "GUN TEMP", "", 0.0, 100.0, 4, 0.75],
			["rpm", "ROTOR", "rpm", 0.0, 500.0, 5, 0.85], ["vsi", "CLIMB", "m/s", -20.0, 20.0, 4, 2.0],
			["torque", "TORQUE", "%", 0.0, 150.0, 5, 0.8], ["heading", "HEADING", "", 0.0, 360.0, 4, 2.0]]:
		if _mount(shell, spec[0]):
			_gauges[spec[0]] = _add_gauge(shell, spec[0], spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])
	if _mount(shell, "radar"):
		_build_radar(_mount(shell, "radar"))
	for marker in shell.find_children("mount_mfd_*", "", true, false):
		_build_mfd(marker as Node3D, (marker.name as String).trim_prefix("mount_mfd_").get_slice("_", 0))
	if _mount(shell, "kills"):
		_build_nixies(_mount(shell, "kills"))
	if _mount(shell, "health"):
		_build_health(_mount(shell, "health"))
	if _mount(shell, "item"):
		_build_item_plate(_mount(shell, "item"))
	for lamp: Array in [["missile", Color(1.0, 0.1, 0.05), "MSL"], ["overheat", Color(1.0, 0.5, 0.05), "HOT"],
			["service", Color(0.3, 1.0, 0.4), "SVC"], ["lock", Color(0.2, 0.8, 1.0), "LOCK"]]:
		if _mount(shell, "lamp_" + lamp[0]):
			_lamps[lamp[0]] = _build_lamp(_mount(shell, "lamp_" + lamp[0]), lamp[1], lamp[2])
	_build_beacon(_mount(shell, "beacon") if _mount(shell, "beacon") else self)
	_warning = AudioStreamPlayer.new()
	_warning.stream = Sounds.stream("warning_loop")
	_warning.volume_db = -12.0
	_warning.bus = Sounds.bus()
	add_child(_warning)
	_warning.play()
	_warning.stream_paused = true
	reticle = _mount(shell, "sight")
	if reticle == null:
		reticle = Node3D.new()
		reticle.position = Vector3(0.0, 0.0, -SIGHT_DISTANCE)
		add_child(reticle)
	# Further off, the same symbol has to be bigger to look the same.
	reticle.scale = Vector3.ONE * maxf(1.0, reticle.position.length() / SIGHT_DISTANCE)
	_build_reticle(reticle)

	# A dim warm light so the panel reads even in the shade.
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.8, 0.6)
	fill.light_energy = 0.35
	fill.omni_range = 1.6
	fill.position = Vector3(0.0, 0.1, -0.3)
	add_child(fill)


func _process(delta: float) -> void:
	if choppa == null or not visible:
		return
	_clock += delta
	var i := choppa.input
	var readings := {
		"speed": choppa.velocity.length() * 3.6, "altitude": choppa.altitude, "boost": choppa.boost_meter * 100.0,
		"heat": choppa.heat * 100.0, "vsi": choppa.velocity.y,
		"rpm": choppa.spool * (330.0 + i.collective * 50.0 + (70.0 if choppa.is_boosting() else 0.0)),
		"torque": choppa.lift_share() * (1.0 + i.collective * choppa.collective_range) * 100.0,
		"heading": fposmod(-rad_to_deg(choppa.heading), 360.0),
	}
	for key: String in _gauges:
		(_gauges[key] as Gauge).value = readings[key]

	if _stick:
		_stick.rotation = Vector3(-i.cyclic.y * 0.3, 0.0, -i.cyclic.x * 0.3)
	if _stick_copilot:
		_stick_copilot.rotation = _stick.rotation
	if _collective:
		_collective.rotation.x = i.collective * 0.3

	var kills: int = kills_source.call()
	var text := "--" if kills < 0 else "%02d" % mini(kills, 99)
	for k in _nixies.size():
		_nixies[k].text = text[k]

	_update_plates()
	var blink := fmod(_clock, 0.5) < 0.3
	var hunted := _missile_incoming()
	_set_lamp("missile", hunted and blink)
	_set_lamp("overheat", choppa.overheated or (choppa.heat > 0.8 and blink))
	var serviced := false
	for node in choppa.get_tree().get_nodes_in_group("stations"):
		serviced = serviced or (node as ServiceStation).occupant == choppa
	_set_lamp("service", serviced and blink)
	_set_lamp("lock", choppa.ammo.missiles > 0 and choppa.missile_target() != null)
	_beacon_light.visible = hunted
	_warning.stream_paused = not hunted
	_beacon_dome.emission_energy_multiplier = 4.0 if hunted else 0.2
	if hunted:
		_beacon.rotate_object_local(Vector3.UP, delta * 9.0)


func _update_plates() -> void:
	var lit := ceili(choppa.health / choppa.max_health * _health_cells.size())
	for k in _health_cells.size():
		var on := k < lit
		var level := float(k) / _health_cells.size()
		var color := Color(0.9, 0.15, 0.05).lerp(Color(0.25, 1.0, 0.3), smoothstep(0.2, 0.7, level))
		_health_cells[k].material_override = _cell_material(color) if on else _cell_off

	if _item_label:
		_item_label.text = "G%d R%d M%d F%d" % [choppa.ammo.gun, choppa.ammo.rockets, choppa.ammo.missiles, choppa.ammo.flares]
		_item_label.modulate = AMBER * (2.0 if choppa.ammo.rockets + choppa.ammo.missiles > 0 else 0.6)


func _missile_incoming() -> bool:
	for node in get_tree().get_nodes_in_group("missiles"):
		var missile := node as Weapons.Missile
		if missile.is_hunting(choppa) and missile.global_position.distance_to(choppa.global_position) < 250.0:
			return true
	return false


# --- builders ------------------------------------------------------------------

## The model's marker for an instrument, or null if this cockpit has none.
func _mount(shell: Node3D, mount_name: String) -> Node3D:
	return shell.find_child("mount_" + mount_name) as Node3D


func _add_gauge(shell: Node3D, mount_name: String, title: String, unit: String,
		low: float, high: float, majors: int, red_from := 2.0) -> Gauge:
	var gauge := Gauge.new()
	gauge.title = title
	gauge.unit = unit
	gauge.low = low
	gauge.high = high
	gauge.majors = majors
	gauge.red_from = red_from
	_mount(shell, mount_name).add_child(gauge)
	return gauge


func _build_radar(mount: Node3D) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true  # The screen is round; corners stay see-through.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_radar = RadarScreen.new()
	_radar.cockpit = self
	_radar.size = Vector2(320, 320)
	viewport.add_child(_radar)
	add_child(viewport)
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.albedo_texture = viewport.get_texture()
	screen.albedo_color = Color(1.6, 1.6, 1.6)
	screen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var quad := QuadMesh.new()
	quad.size = Vector2(0.168, 0.168)
	var tube := MeshInstance3D.new()
	tube.mesh = quad
	tube.material_override = screen
	tube.position.z = 0.001
	mount.add_child(tube)
	mount.add_child(glass_cover(0.084, 0.01))


func _build_nixies(mount: Node3D) -> void:
	var tube_glass := StandardMaterial3D.new()
	tube_glass.albedo_color = Color(0.9, 0.6, 0.35, 0.12)
	tube_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tube_glass.roughness = 0.05
	tube_glass.metallic = 0.3
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.015
	cylinder.bottom_radius = 0.015
	cylinder.height = 0.055
	for k in 2:
		var x := -0.018 + k * 0.036
		var tube := MeshInstance3D.new()
		tube.mesh = cylinder
		tube.material_override = tube_glass
		tube.position = Vector3(x, 0.0, 0.02)
		mount.add_child(tube)
		var digit := _label(mount, "0", 72, Color(2.6, 1.1, 0.35), Vector3(x, 0.0, 0.02))
		digit.outline_size = 10
		digit.outline_modulate = Color(1.0, 0.35, 0.05, 0.5)
		_nixies.append(digit)
	_label(mount, "KILLS", 20, CREAM, Vector3(0.0, -0.042, 0.002)).pixel_size = 0.0004


func _build_health(mount: Node3D) -> void:
	_cell_off = StandardMaterial3D.new()
	_cell_off.albedo_color = Color(0.08, 0.06, 0.05)
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.022, 0.005)
	for k in 10:
		var cell := MeshInstance3D.new()
		cell.mesh = box
		cell.position = Vector3(-0.072 + k * 0.016, 0.004, 0.0)
		cell.material_override = _cell_off
		mount.add_child(cell)
		_health_cells.append(cell)
	_label(mount, "HULL", 22, CREAM, Vector3(0.0, -0.022, 0.0)).pixel_size = 0.0004


func _build_item_plate(mount: Node3D) -> void:
	_item_label = _label(mount, "- - -", 40, AMBER, Vector3(0.0, 0.006, 0.002))
	_item_label.pixel_size = 0.0004
	_label(mount, "ORDNANCE", 20, CREAM, Vector3(0.0, -0.024, 0.0)).pixel_size = 0.0004


func _build_lamp(mount: Node3D, color: Color, text: String) -> StandardMaterial3D:
	var dome := SphereMesh.new()
	dome.radius = 0.018
	dome.height = 0.02
	dome.is_hemisphere = true
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.0
	var lamp := MeshInstance3D.new()
	lamp.mesh = dome
	lamp.material_override = m
	lamp.rotation_degrees.x = 90.0
	mount.add_child(lamp)
	_label(mount, text, 20, CREAM, Vector3(0.0, -0.033, -0.01))
	return m


## The gunsight's picture is drawn by the HUD (Hud._draw_pipper, in green from the
## seat): a collimated sight sits at infinity, so it is a screen overlay along the
## boresight. Here only the faint glow of the combiner glass, so the glass reads lit.
func _build_reticle(mount: Node3D) -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.04, 0.12, 0.03)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var sheen := MeshInstance3D.new()
	sheen.mesh = quad
	sheen.material_override = glow
	sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(sheen)


func _set_lamp(lamp_name: String, on: bool) -> void:
	if _lamps.has(lamp_name):
		(_lamps[lamp_name] as StandardMaterial3D).emission_energy_multiplier = 5.0 if on else 0.0


## A multi-function display: a page drawn into a SubViewport, shown on the screen glass.
## The mount is sized for a 0.2 m screen.
func _build_mfd(mount: Node3D, page: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var screen := Mfd.new()
	screen.cockpit = self
	screen.page = page
	screen.size = Vector2(320, 320)
	viewport.add_child(screen)
	add_child(viewport)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	m.albedo_color = Color(1.25, 1.25, 1.25)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var glass := MeshInstance3D.new()
	glass.mesh = quad
	glass.material_override = m
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(glass)
	mount.add_child(glass_cover(0.1, 0.002))


## Head-up display numbers round the reticle: speed left, altitude right, heading above,
## loadout below. Green like the reticle; they show only from the seat.
func _build_beacon(mount: Node3D) -> void:
	_beacon = Node3D.new()
	mount.add_child(_beacon)
	var base := CylinderMesh.new()
	base.top_radius = 0.035
	base.bottom_radius = 0.04
	base.height = 0.02
	var foot := MeshInstance3D.new()
	foot.mesh = base
	foot.material_override = ChoppaModel._material(Color(0.15, 0.15, 0.15), 0.6, 0.4)
	mount.add_child(foot)
	var dome := SphereMesh.new()
	dome.radius = 0.032
	dome.height = 0.05
	_beacon_dome = StandardMaterial3D.new()
	_beacon_dome.albedo_color = Color(0.8, 0.05, 0.02, 0.85)
	_beacon_dome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_dome.emission_enabled = true
	_beacon_dome.emission = Color(1.0, 0.1, 0.02)
	var glass := MeshInstance3D.new()
	glass.mesh = dome
	glass.material_override = _beacon_dome
	glass.position.y = 0.03
	_beacon.add_child(glass)
	_beacon_light = SpotLight3D.new()
	_beacon_light.light_color = Color(1.0, 0.12, 0.05)
	_beacon_light.light_energy = 6.0
	_beacon_light.spot_range = 3.0
	_beacon_light.spot_angle = 35.0
	_beacon_light.position.y = 0.03
	_beacon_light.rotation_degrees.y = 90.0
	_beacon_light.visible = false
	_beacon.add_child(_beacon_light)


## Convex-looking cover glass: faint tint plus a soft crescent glint.
static func glass_cover(radius: float, offset: float) -> Node3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _glint_texture()
	m.albedo_color = Color(0.55, 0.55, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glass := MeshInstance3D.new()
	glass.mesh = quad
	glass.material_override = m
	glass.position.z = offset
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return glass


## An old instrument face: near-black enamel, a faded track, grime toward the rim, and
## a few stains and scratches. Made once, shared by every gauge.
static func dial_texture() -> Texture2D:
	return Baked.texture("dial")


static func dial_image() -> Image:
	var size := 256
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var c := Vector2.ONE * size * 0.5
	for y in size:
		for x in size:
			var d := (Vector2(x, y) - c).length() / (size * 0.5)
			if d > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var grime := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var col := Color(0.075, 0.07, 0.06).lerp(Color(0.17, 0.13, 0.08), smoothstep(0.55, 1.0, d) * grime)
			col = col.lerp(Color(0.2, 0.17, 0.11), maxf(0.0, grime - 0.72) * 1.4)
			# Faded cream track rings.
			for r in [0.78, 0.97]:
				col = col.lerp(Color(0.6, 0.55, 0.42), (1.0 - smoothstep(0.0, 0.012, absf(d - r))) * 0.5)
			image.set_pixel(x, y, col)
	for k in 5:  # Hairline scratches.
		var from := c + Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for t in rng.randi_range(15, 50):
			var p := from + dir * t
			if (p - c).length() < size * 0.48:
				image.set_pixelv(Vector2i(p), image.get_pixelv(Vector2i(p)).lightened(0.12))
	return image


static func _glint_texture() -> Texture2D:
	return Baked.texture("glint")


static func _glint_image() -> Image:
	var size := 128
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var c := Vector2.ONE * size * 0.5
	for y in size:
		for x in size:
			var p := (Vector2(x, y) - c) / (size * 0.5)
			if p.length() > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# A crescent near the upper left rim, and a faint overall sheen.
			var crescent := smoothstep(0.62, 0.86, p.length()) * (1.0 - smoothstep(0.88, 1.0, p.length()))
			crescent *= clampf(-(p.x + p.y) * 0.9, 0.0, 1.0)
			var a := crescent * 0.55 + 0.04
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return image


static func _label(parent: Node3D, text: String, font_size: int, color: Color, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0005
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.position = pos
	parent.add_child(label)
	return label


static var _cell_materials := {}


static func _cell_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _cell_materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
		_cell_materials[key] = m
	return _cell_materials[key]


## Round needle instrument: dark face, cream ticks and numbers, red zone, glass.
class Gauge extends Node3D:
	const RADIUS := 0.05
	const SWEEP := 4.71  ## 270 degrees.

	var title := ""
	var unit := ""
	var low := 0.0
	var high := 100.0
	var majors := 5
	var red_from := 2.0  ## Fraction of the scale where the red zone starts (>1: none).
	var value := 0.0

	var _shown := 0.0
	var _needle: Node3D

	func _ready() -> void:
		var face := QuadMesh.new()
		face.size = Vector2.ONE * RADIUS * 2.0
		var face_material := StandardMaterial3D.new()
		face_material.albedo_texture = Cockpit.dial_texture()
		face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		face_material.roughness = 0.8
		var face_mesh := MeshInstance3D.new()
		face_mesh.mesh = face
		face_mesh.material_override = face_material
		face_mesh.position.z = 0.001
		add_child(face_mesh)
		# Red zone: a painted arc just inside the ticks.
		if red_from <= 1.0:
			var steps := ceili((1.0 - red_from) * 40.0)
			for k in steps:
				var t := lerpf(red_from, 1.0, (k + 0.5) / steps)
				var arc := MeshInstance3D.new()
				var bit := BoxMesh.new()
				bit.size = Vector3(RADIUS * SWEEP * (1.0 - red_from) / steps * 1.05, 0.004, 0.0008)
				arc.mesh = bit
				arc.material_override = Cockpit._cell_material(Color(0.55, 0.06, 0.04))
				var a := _angle(t)
				arc.position = Vector3(-sin(a), cos(a), 0.0) * RADIUS * 0.94 + Vector3(0, 0, 0.0025)
				arc.rotation.z = a
				add_child(arc)
		var ticks := majors * 5
		for k in ticks + 1:
			var t := float(k) / ticks
			var major := k % 5 == 0
			var tick := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.0022 if major else 0.0012, 0.011 if major else 0.006, 0.001)
			tick.mesh = box
			var color := Color(0.9, 0.15, 0.1) if t >= red_from else Cockpit.CREAM
			tick.material_override = Cockpit._cell_material(color * 0.6)
			var angle := _angle(t)
			tick.position = Vector3(-sin(angle), cos(angle), 0.0) * (RADIUS * (0.84 if major else 0.87)) + Vector3(0, 0, 0.003)
			tick.rotation.z = angle
			add_child(tick)
			if major:
				var number := Cockpit._label(self, str(roundi(lerpf(low, high, t))), 26, Cockpit.CREAM,
					Vector3(-sin(angle), cos(angle), 0.0) * RADIUS * 0.62 + Vector3(0, 0, 0.003))
				number.pixel_size = 0.0003
		Cockpit._label(self, title, 22, Cockpit.CREAM, Vector3(0.0, -RADIUS * 0.42, 0.003)).pixel_size = 0.0003
		if unit != "":
			Cockpit._label(self, unit, 20, Cockpit.CREAM * 0.8, Vector3(0.0, RADIUS * 0.3, 0.003)).pixel_size = 0.0003
		_needle = Node3D.new()
		_needle.position.z = 0.005
		add_child(_needle)
		# Tapered pointer with a luminous tip and a counterweight tail.
		var pointer := PrismMesh.new()
		pointer.size = Vector3(0.005, RADIUS * 0.78, 0.0012)
		var needle := MeshInstance3D.new()
		needle.mesh = pointer
		needle.position.y = RADIUS * 0.39
		needle.material_override = ChoppaModel._material(Color(0.92, 0.88, 0.78), 0.0, 0.5)
		_needle.add_child(needle)
		var tip := MeshInstance3D.new()
		var tip_box := BoxMesh.new()
		tip_box.size = Vector3(0.0022, RADIUS * 0.22, 0.0014)
		tip.mesh = tip_box
		tip.position.y = RADIUS * 0.66
		tip.material_override = Cockpit._cell_material(Color(1.0, 0.45, 0.1))
		_needle.add_child(tip)
		var tail := MeshInstance3D.new()
		var tail_box := BoxMesh.new()
		tail_box.size = Vector3(0.006, RADIUS * 0.25, 0.0012)
		tail.mesh = tail_box
		tail.position.y = -RADIUS * 0.12
		tail.material_override = ChoppaModel._material(Color(0.08, 0.08, 0.08), 0.5, 0.4)
		_needle.add_child(tail)
		var cap := MeshInstance3D.new()
		var hub := CylinderMesh.new()
		hub.top_radius = 0.007
		hub.bottom_radius = 0.007
		hub.height = 0.004
		cap.mesh = hub
		cap.rotation_degrees.x = 90.0
		cap.material_override = ChoppaModel._material(Color(0.78, 0.6, 0.3), 0.9, 0.3)
		_needle.add_child(cap)
		add_child(Cockpit.glass_cover(RADIUS, 0.009))

	func _process(delta: float) -> void:
		# Needles have a little inertia, like the real thing.
		_shown = lerpf(_shown, value, 1.0 - exp(-8.0 * delta))
		_needle.rotation.z = _angle(clampf(inverse_lerp(low, high, _shown), 0.0, 1.03))

	func _angle(t: float) -> float:
		return SWEEP * 0.5 - t * SWEEP


## A display page for the glass cockpits: "flight" (attitude, speed and altitude tapes,
## heading), "radar" (the scope in green) or "systems" (hull and parts, engine, gun, loadout).
class Mfd extends Control:
	const GREEN := Color(0.4, 1.0, 0.45)
	const AMBER_LINE := Color(1.0, 0.7, 0.2)
	var cockpit: Cockpit
	var page := "flight"
	var _sweep := 0.0

	func _process(delta: float) -> void:
		_sweep = fmod(_sweep + delta * 2.2, TAU)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.02))
		if cockpit == null or cockpit.choppa == null:
			return
		match page:
			"radar":
				_draw_radar()
			"systems":
				_draw_systems()
			_:
				_draw_flight()
		draw_rect(Rect2(Vector2.ZERO, size), Color(GREEN, 0.35), false, 3.0)

	func _text(at: Vector2, text: String, font_size := 22, color := GREEN, align := HORIZONTAL_ALIGNMENT_CENTER, width := 120.0) -> void:
		var font := UiKit.font("condensed")
		var x := at.x - (width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else (width if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
		draw_string(font, Vector2(x, at.y), text, align, width, font_size, color)

	func _draw_flight() -> void:
		var me := cockpit.choppa
		var c := size * 0.5
		# Attitude: sky over ground, rolled by the bank, shifted by the pitch.
		var bank := -me.bank_right()
		var pitch := me.nose_down()
		var per_degree := 3.2
		var shift := Vector2(0.0, -rad_to_deg(pitch) * per_degree).rotated(bank)
		var across := Vector2(cos(bank), sin(bank))
		var down := Vector2(-sin(bank), cos(bank))
		var mid := c + shift
		var far := 400.0
		draw_colored_polygon(PackedVector2Array([mid - across * far, mid + across * far, mid + across * far - down * far,
			mid - across * far - down * far]), Color(0.05, 0.13, 0.28))
		draw_colored_polygon(PackedVector2Array([mid - across * far, mid + across * far, mid + across * far + down * far,
			mid - across * far + down * far]), Color(0.22, 0.13, 0.05))
		draw_line(mid - across * far, mid + across * far, Color.WHITE, 2.0)
		for k in range(-4, 5):  # Pitch ladder every 10 degrees.
			if k == 0:
				continue
			var p := mid - down * k * 10.0 * per_degree
			var half := 30.0 if k % 2 == 0 else 18.0
			draw_line(p - across * half, p + across * half, Color(1, 1, 1, 0.8), 2.0)
		# The aircraft symbol, fixed in the middle.
		draw_line(c + Vector2(-50, 0), c + Vector2(-16, 0), AMBER_LINE, 4.0)
		draw_line(c + Vector2(16, 0), c + Vector2(50, 0), AMBER_LINE, 4.0)
		draw_circle(c, 4.0, AMBER_LINE)
		# Speed and altitude boxes, the heading on top, climb rate and rotor at the bottom.
		draw_rect(Rect2(8, c.y - 18, 70, 36), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(8, c.y - 18, 70, 36), GREEN, false, 2.0)
		_text(Vector2(43, c.y + 9), "%d" % roundi(me.velocity.length() * 3.6), 26)
		draw_rect(Rect2(size.x - 78, c.y - 18, 70, 36), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(size.x - 78, c.y - 18, 70, 36), GREEN, false, 2.0)
		_text(Vector2(size.x - 43, c.y + 9), "%d" % roundi(me.altitude), 26)
		var heading := fposmod(-rad_to_deg(me.heading), 360.0)
		draw_rect(Rect2(0, 0, size.x, 34), Color(0, 0, 0, 0.75))
		for k in range(-4, 5):
			var mark := roundi(heading / 10.0) * 10 + k * 10
			var x := c.x + (mark - heading) * 3.0
			draw_line(Vector2(x, 26), Vector2(x, 34), GREEN, 2.0)
			if mark % 30 == 0:
				_text(Vector2(x, 22), "%02d" % (posmod(mark, 360) / 10), 18)
		draw_line(Vector2(c.x, 30), Vector2(c.x, 42), AMBER_LINE, 3.0)
		_text(Vector2(60, size.y - 12), "VS %+.1f" % me.velocity.y, 20)
		_text(Vector2(size.x - 60, size.y - 12), "NR %d%%" % roundi(me.spool * 100.0), 20)
		_text(Vector2(c.x, size.y - 12), "ENG ON" if me.engine_on else "ENG OFF", 20, GREEN if me.engine_on else AMBER_LINE)

	func _draw_radar() -> void:
		var me := cockpit.choppa
		var c := size * 0.5
		var r := size.x * 0.44
		for k in [0.33, 0.66, 1.0]:
			draw_arc(c, r * k, 0.0, TAU, 64, Color(GREEN, 0.5), 2.0)
		for k in 24:
			var a := _sweep - k * 0.03
			draw_line(c, c + Vector2(sin(a), -cos(a)) * r, Color(GREEN, 0.6 * (1.0 - k / 24.0)), 3.0)
		var to_local := me.facing().inverse()
		for node in me.get_tree().get_nodes_in_group("stations"):
			var station := node as ServiceStation
			var p := _project(to_local * (station.global_position - me.global_position), c, r)
			if p != Vector2.INF and station.is_ready():
				draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.5, 0.8, 1.0), false, 2.0)
		for node in me.get_tree().get_nodes_in_group("choppas"):
			var other := node as Choppa
			if other == me or not other.alive:
				continue
			var p := _project(to_local * (other.global_position - me.global_position), c, r)
			if p != Vector2.INF:
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(8, 7), p + Vector2(-8, 7)]),
					Color(1.0, 0.35, 0.25))
		for node in me.get_tree().get_nodes_in_group("missiles"):
			var p := _project(to_local * ((node as Node3D).global_position - me.global_position), c, r)
			if p != Vector2.INF:
				draw_circle(p, 5.0, Color(1.0, 0.9, 0.2))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, 8), c + Vector2(-7, 8)]), GREEN)
		_text(Vector2(50, 26), "TSD", 22)
		_text(Vector2(size.x - 60, 26), "%d M" % roundi(RadarScreen.RANGE), 20)

	func _project(local: Vector3, c: Vector2, r: float) -> Vector2:
		var flat := Vector2(local.x, local.z) / RadarScreen.RANGE
		return Vector2.INF if flat.length() > 1.0 else c + flat * r

	func _draw_systems() -> void:
		var me := cockpit.choppa
		_text(Vector2(size.x * 0.5, 28), "SYSTEMS", 24)
		var rows := [["HULL", me.health / me.max_health], ["ROTOR", 1.0 - me.wear(Choppa.Part.ROTOR)],
			["TAIL", 1.0 - me.wear(Choppa.Part.TAIL)], ["ENGINE", 1.0 - me.wear(Choppa.Part.ENGINE)],
			["BOOST", me.boost_meter], ["GUN HEAT", me.heat]]
		for k in rows.size():
			var y := 50.0 + k * 38.0
			var share: float = rows[k][1]
			_text(Vector2(14, y + 20), rows[k][0], 20, GREEN, HORIZONTAL_ALIGNMENT_LEFT, 100.0)
			var color := GREEN
			if k == 5:
				color = AMBER_LINE if share > 0.7 else GREEN
			elif share < 0.3:
				color = Color(1.0, 0.3, 0.2)
			elif share < 0.6:
				color = AMBER_LINE
			draw_rect(Rect2(118, y + 4, 180, 20), Color(GREEN, 0.15))
			draw_rect(Rect2(118, y + 4, 180 * clampf(share, 0.0, 1.0), 20), color)
		var ammo: Dictionary = me.ammo
		_text(Vector2(size.x * 0.5, 292), "GUN %d   RKT %d   MSL %d   FLR %d" % [ammo.gun, ammo.rockets, ammo.missiles, ammo.flares], 20)


## The radar picture, drawn into a SubViewport: amber phosphor rings, a sweeping beam,
## blips for other choppas (relative to your heading, up = ahead) and ready service stations.
class RadarScreen extends Control:
	const RANGE := 300.0
	var cockpit: Cockpit
	var _sweep := 0.0

	func _process(delta: float) -> void:
		_sweep = fmod(_sweep + delta * 2.2, TAU)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.46
		var phosphor := Color(1.0, 0.62, 0.15)
		draw_circle(c, size.x * 0.5, Color(0.05, 0.035, 0.015))
		for k in [0.33, 0.66, 1.0]:
			draw_arc(c, r * k, 0.0, TAU, 64, Color(phosphor, 0.6), 3.0)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(phosphor, 0.45), 2.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(phosphor, 0.45), 2.0)
		for k in 30:
			var a := _sweep - k * 0.025
			draw_line(c, c + Vector2(sin(a), -cos(a)) * r, Color(phosphor, 0.85 * (1.0 - k / 30.0)), 4.0)
		if cockpit == null or cockpit.choppa == null:
			return
		var me := cockpit.choppa
		var to_local := me.facing().inverse()
		for node in me.get_tree().get_nodes_in_group("stations"):
			var p := _project(to_local * ((node as Node3D).global_position - me.global_position), c, r)
			if p != Vector2.INF and (node as ServiceStation).is_ready():
				draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color(0.4, 1.0, 0.4, 0.8), 2.0)
				draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color(0.4, 1.0, 0.4, 0.8), 2.0)
		for node in me.get_tree().get_nodes_in_group("choppas"):
			var other := node as Choppa
			if other == me or not other.alive:
				continue
			var p := _project(to_local * (other.global_position - me.global_position), c, r)
			if p != Vector2.INF:
				draw_circle(p, 14.0, Color(phosphor, 0.35))
				draw_circle(p, 8.0, Color(1.0, 0.9, 0.6))
		for node in me.get_tree().get_nodes_in_group("missiles"):
			var p := _project(to_local * ((node as Node3D).global_position - me.global_position), c, r)
			if p != Vector2.INF:
				draw_circle(p, 5.0, Color(1.0, 0.15, 0.1))
		draw_circle(c, 4.0, phosphor)

	func _project(local: Vector3, c: Vector2, r: float) -> Vector2:
		var flat := Vector2(local.x, local.z) / RANGE
		if flat.length() > 1.0:
			return Vector2.INF
		return c + flat * r
