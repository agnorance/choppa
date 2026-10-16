class_name Cockpit
extends Node3D
## First-person cockpit: the Blender shell (assets/models/choppa/cockpit.glb, built by
## tools/blender/make_cockpit.py) plus live instruments mounted at its "mount_*" markers:
## needle gauges, an amber radar, a nixie kill counter, a health lamp bar, the item
## plate, warning lamps and a rotating missile beacon. Stick and collective follow the
## controls. Origin = the pilot's eye. Only built for the local player.

const PANEL_PAINT := Color(0.27, 0.38, 0.34)  ## The teal-green of old control rooms.
const CREAM := Color(0.92, 0.86, 0.7)
const AMBER := Color(1.0, 0.62, 0.2)

var choppa: Choppa
## Returns the kill count to show, or -1 for "--" (free flight). Set by the game mode.
var kills_source: Callable = func() -> int: return -1

var _gauges := {}
var _stick: Node3D
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


func _ready() -> void:
	var shell: Node3D = (load("res://assets/models/choppa/cockpit.glb") as PackedScene).instantiate()
	add_child(shell)
	var materials := ChoppaModel.part_materials(PANEL_PAINT, Vector2(0.32, 0.2))
	for mesh: MeshInstance3D in shell.find_children("*", "MeshInstance3D"):
		for k in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(k)
			mesh.set_surface_override_material(k, materials.get(source.resource_name if source else "paint", materials.paint))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stick = shell.find_child("stick")
	_collective = shell.find_child("collective")

	_gauges.speed = _add_gauge(shell, "speed", "AIRSPEED", "km/h", 0.0, 300.0, 6)
	_gauges.altitude = _add_gauge(shell, "altitude", "ALTITUDE", "m", 0.0, 100.0, 5)
	_gauges.boost = _add_gauge(shell, "boost", "BOOST", "%", 0.0, 100.0, 4)
	_gauges.heat = _add_gauge(shell, "heat", "GUN TEMP", "", 0.0, 100.0, 4, 0.75)
	_build_radar(_mount(shell, "radar"))
	_build_nixies(_mount(shell, "kills"))
	_build_health(_mount(shell, "health"))
	_build_item_plate(_mount(shell, "item"))
	for lamp: Array in [["missile", Color(1.0, 0.1, 0.05), "MSL"], ["overheat", Color(1.0, 0.5, 0.05), "HOT"],
			["shield", Color(0.2, 0.8, 1.0), "SHLD"], ["scrambled", Color(0.75, 0.3, 1.0), "SCRM"]]:
		_lamps[lamp[0]] = _build_lamp(_mount(shell, "lamp_" + lamp[0]), lamp[1], lamp[2])
	_build_beacon(_mount(shell, "beacon"))
	_build_reticle(_mount(shell, "sight"))

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
	(_gauges.speed as Gauge).value = choppa.velocity.length() * 3.6
	(_gauges.altitude as Gauge).value = choppa.altitude
	(_gauges.boost as Gauge).value = choppa.boost_meter * 100.0
	(_gauges.heat as Gauge).value = choppa.heat * 100.0

	var i := choppa.input
	if _stick:
		_stick.rotation = Vector3(-i.move.y * 0.3, 0.0, -i.move.x * 0.3)
	if _collective:
		_collective.rotation.x = i.lift * 0.3

	var kills: int = kills_source.call()
	var text := "--" if kills < 0 else "%02d" % mini(kills, 99)
	for k in 2:
		_nixies[k].text = text[k]

	var lit := ceili(choppa.health / Choppa.MAX_HEALTH * _health_cells.size())
	for k in _health_cells.size():
		var on := k < lit
		var level := float(k) / _health_cells.size()
		var color := Color(0.9, 0.15, 0.05).lerp(Color(0.25, 1.0, 0.3), smoothstep(0.2, 0.7, level))
		_health_cells[k].material_override = _cell_material(color) if on else _cell_off

	_item_label.text = choppa.item if choppa.item != "" else "- - -"
	_item_label.modulate = (Items.color(choppa.item) if choppa.item != "" else AMBER * 0.5) * 2.0

	var blink := fmod(_clock, 0.5) < 0.3
	var hunted := _missile_incoming()
	_set_lamp("missile", hunted and blink)
	_set_lamp("overheat", choppa.overheated or (choppa.heat > 0.8 and blink))
	_set_lamp("shield", choppa.shield > 0.0 or choppa.rampage > 0.0)
	_set_lamp("scrambled", choppa.scrambled > 0.0)
	_beacon_light.visible = hunted
	_beacon_dome.emission_energy_multiplier = 4.0 if hunted else 0.2
	if hunted:
		_beacon.rotate_object_local(Vector3.UP, delta * 9.0)


func _missile_incoming() -> bool:
	for node in get_tree().get_nodes_in_group("missiles"):
		var missile := node as Weapons.Missile
		if missile.is_hunting(choppa) and missile.global_position.distance_to(choppa.global_position) < 250.0:
			return true
	return false


# --- builders ------------------------------------------------------------------

func _mount(shell: Node3D, mount_name: String) -> Node3D:
	var marker: Node3D = shell.find_child("mount_" + mount_name)
	return marker if marker else self


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


## Green collimator reticle on the gunsight glass: ring, four ticks, centre dot.
## It sits dead ahead of the eye, so it lines up with where the guns point.
func _build_reticle(mount: Node3D) -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.45, 1.6, 0.35)
	glow.no_depth_test = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.0225
	ring.outer_radius = 0.0245
	ring.rings = 48
	ring.ring_segments = 4
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.material_override = glow
	ring_mesh.rotation_degrees.x = 90.0
	mount.add_child(ring_mesh)
	for k in 4:
		var tick := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.0016, 0.011, 0.0005)
		tick.mesh = bar
		tick.material_override = glow
		var a := k * PI * 0.5
		tick.position = Vector3(sin(a), cos(a), 0.0) * 0.031
		tick.rotation.z = -a
		mount.add_child(tick)
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.0016
	sphere.height = 0.0032
	dot.mesh = sphere
	dot.material_override = glow
	mount.add_child(dot)


func _set_lamp(lamp_name: String, on: bool) -> void:
	(_lamps[lamp_name] as StandardMaterial3D).emission_energy_multiplier = 5.0 if on else 0.0


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


func _glass_disc(radius: float, offset: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.8, 0.8, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.02
	m.metallic = 0.5
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.001
	disc.radial_segments = 40
	var glass := MeshInstance3D.new()
	glass.mesh = disc
	glass.material_override = m
	glass.rotation_degrees.x = 90.0
	glass.position.z = offset
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return glass


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
		var face := CylinderMesh.new()
		face.top_radius = RADIUS
		face.bottom_radius = RADIUS
		face.height = 0.004
		face.radial_segments = 40
		var face_mesh := MeshInstance3D.new()
		face_mesh.mesh = face
		face_mesh.material_override = ChoppaModel._material(Color(0.05, 0.05, 0.045), 0.0, 0.85)
		face_mesh.rotation_degrees.x = 90.0
		add_child(face_mesh)
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
		var needle := MeshInstance3D.new()
		var stick := BoxMesh.new()
		stick.size = Vector3(0.0028, RADIUS * 0.85, 0.0012)
		needle.mesh = stick
		needle.position.y = RADIUS * 0.33
		needle.material_override = Cockpit._cell_material(Color(1.0, 0.45, 0.1))
		_needle.add_child(needle)
		var cap := MeshInstance3D.new()
		var hub := CylinderMesh.new()
		hub.top_radius = 0.007
		hub.bottom_radius = 0.007
		hub.height = 0.004
		cap.mesh = hub
		cap.rotation_degrees.x = 90.0
		cap.material_override = ChoppaModel._material(Color(0.78, 0.6, 0.3), 0.9, 0.3)
		_needle.add_child(cap)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.7, 0.8, 0.8, 0.07)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.02
		glass.metallic = 0.5
		var glass_mesh := MeshInstance3D.new()
		glass_mesh.mesh = face.duplicate()
		(glass_mesh.mesh as CylinderMesh).height = 0.001
		glass_mesh.material_override = glass
		glass_mesh.rotation_degrees.x = 90.0
		glass_mesh.position.z = 0.009
		add_child(glass_mesh)

	func _process(delta: float) -> void:
		# Needles have a little inertia, like the real thing.
		_shown = lerpf(_shown, value, 1.0 - exp(-8.0 * delta))
		_needle.rotation.z = _angle(clampf(inverse_lerp(low, high, _shown), 0.0, 1.03))

	func _angle(t: float) -> float:
		return SWEEP * 0.5 - t * SWEEP


## The radar picture, drawn into a SubViewport: amber phosphor rings, a sweeping beam,
## blips for other choppas (relative to your heading, up = ahead) and repair crates.
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
		for node in me.get_tree().get_nodes_in_group("health_crates"):
			var p := _project(to_local * ((node as Node3D).global_position - me.global_position), c, r)
			if p != Vector2.INF and (node as HealthCrate).is_available():
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
