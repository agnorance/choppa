class_name IronDam
extends GameMap
## Battle arena: a river valley shut by a 57 m concrete dam. North of it a reservoir
## with drowned trees and rock islands, the water high up near the crest; south of it
## the old river bed with the power station at the foot of the dam, penstock pipes down
## the dam face, transmission lines strung across the valley, a ruined hamlet.
##
## The dam is the centrepiece: three spillway openings near the top to fly through from
## lake to valley, gate towers at both ends of the crest road, a repair pad in the middle
## of the crest and one on the power station roof. High and exposed, or low and fast
## along the river: the routes cross at the dam.

const LENGTH := 820.0
const WATER := 38.0  ## The reservoir, north of the dam.
const RIVER := -0.5  ## The river below it.
const CREST := 60.0  ## The dam's top.
const DAM_HALF := 14.0  ## Half the dam's thickness at the base (the top is thinner).
const OPENINGS := [-55.0, 0.0, 55.0]  ## x of the spillway openings, 18 m wide, 40..52 m up.
const STATION_ROOF := 25.0

var terrain: Terrain
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	ceiling = 110.0
	menu_center = Vector3(0.0, 45.0, 30.0)
	menu_orbit = Vector2(170.0, 70.0)


func _ready() -> void:
	_noise.seed = 59
	_noise.frequency = 0.007
	_noise.fractal_octaves = 4
	_rng.seed = 5959
	seed(5959)
	var t0 := Time.get_ticks_msec()
	MapKit.environment(self, Vector3(-26.0, 140.0, 0.0))
	terrain = Terrain.new()
	terrain.size = LENGTH + 200.0
	terrain.resolution = [130, 260, 500][Graphics.quality]
	terrain.normal_reach = 2 if Graphics.at_least(Graphics.Quality.HIGH) else 1
	terrain.height_fn = _height
	terrain.material = MapKit.terrain_material(RIVER + 0.6, "rock")
	add_child(terrain)
	MapKit.backdrop(self, 520.0, 33)
	MapKit.water(self, Vector3(0.0, WATER, -205.0), 410.0)
	MapKit.water(self, Vector3(0.0, RIVER, 205.0), 410.0)
	GameMap.report("dam: terrain", t0)

	_dam()
	_power_station()
	_lines()
	_reservoir()
	_valley()
	_stations_and_spawns()
	GameMap.report("dam: built", t0)


## Half the valley's width at z: it wanders a little.
func half_width(z: float) -> float:
	return 118.0 + 18.0 * sin(z / 95.0)


## North of the dam a reservoir bed that climbs to a narrow shore terrace at the water's
## edge; south of it the river bed with its banks; cliffs either side above the ceiling,
## hills closing both ends.
func _height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z)
	var e := absf(x) / half_width(z)
	var wall := smoothstep(0.92, 1.45, e + n * 0.05) * (175.0 + n * 40.0)
	var north := lerpf(-12.0, WATER + 3.0, smoothstep(0.25, 0.8, e)) + n * 3.0 * (1.0 - smoothstep(0.7, 0.8, e))
	var river := 1.0 - smoothstep(0.06, 0.16, e)
	var south := 3.0 + n * 1.5 - river * 6.0 + smoothstep(0.6, 0.9, e) * 6.0
	var side := smoothstep(-6.0, 6.0, z)  # 0 north of the dam, 1 south.
	var ends := smoothstep(330.0, 420.0, absf(z) + n * 25.0) * 180.0
	return maxf(lerpf(north, south, side) + wall, ends)


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain and terrain.is_inside_tree() else _height(x, z)


func _concrete() -> Color:
	return Color(0.6, 0.6, 0.57)


## The dam: a thick base, a thinner upper wall with three spillway openings through it,
## the crest road with its kerbs, gate towers at both ends, and buttress ribs on the
## valley face.
func _dam() -> void:
	var stone := _concrete()
	var span := 300.0
	MapKit.block(self, Vector3(0.0, 12.0, 0.0), Vector3(span, 36.0, DAM_HALF * 2.0), stone)
	# The upper wall, y 30..60, cut by the openings (18 wide, 40..52 up).
	var edges := [-span * 0.5]
	for x: float in OPENINGS:
		edges.append(x - 9.0)
		edges.append(x + 9.0)
	edges.append(span * 0.5)
	for k in range(0, edges.size(), 2):
		var x0: float = edges[k]
		var x1: float = edges[k + 1]
		MapKit.block(self, Vector3((x0 + x1) * 0.5, 45.0, 0.0), Vector3(x1 - x0, 30.0, 14.0), stone)
	for x: float in OPENINGS:
		MapKit.block(self, Vector3(x, 35.0, 0.0), Vector3(18.0, 10.0, 14.0), stone)  # Sill.
		MapKit.block(self, Vector3(x, 56.0, 0.0), Vector3(18.0, 8.0, 14.0), stone)  # Lintel under the road.
		# A spill chute down the valley face below each opening.
		MapKit.block(self, Vector3(x, 22.0, 17.0), Vector3(14.0, 1.0, 10.0), stone.darkened(0.15))
	MapKit.block(self, Vector3(0.0, CREST + 0.25, 0.0), Vector3(span, 0.5, 9.0), Color(0.22, 0.22, 0.23))
	for side in [-1.0, 1.0]:
		MapKit.block(self, Vector3(0.0, CREST + 0.9, side * 6.5), Vector3(span, 1.8, 1.0), stone)  # Parapets.
		MapKit.block(self, Vector3(side * 95.0, CREST + 8.0, 0.0), Vector3(12.0, 16.0, 14.0), stone.darkened(0.08))
		MapKit.block(self, Vector3(side * 95.0, CREST + 16.6, 0.0), Vector3(13.0, 1.2, 15.0), Color(0.3, 0.32, 0.3))
	for x in range(-120, 121, 30):  # Buttress ribs on the valley face.
		if absf(float(x)) > 14.0:
			MapKit.block(self, Vector3(float(x), 18.0, DAM_HALF + 2.0), Vector3(4.0, 36.0, 4.0), stone.darkened(0.05))
	# Construction joints: dark seams down both faces every 12 m, and the pour lines.
	var seam := MapKit.material(stone.darkened(0.45))
	for k in range(-12, 13):
		var x := k * 12.0
		for z: float in [-7.05, 7.05, DAM_HALF + 0.05]:
			var top := CREST if absf(z) < 8.0 else 30.0
			var bottom := 30.0 if absf(z) < 8.0 else -4.0
			_seam(Vector3(x, (top + bottom) * 0.5, z), Vector3(0.25, top - bottom, 0.1), seam)
	for y: float in [8.0, 16.0, 24.0]:
		_seam(Vector3(0.0, y, DAM_HALF + 0.05), Vector3(300.0, 0.2, 0.1), seam)
	for y: float in [36.0, 44.0]:
		_seam(Vector3(0.0, y, 7.05), Vector3(300.0, 0.2, 0.1), seam)
	# Water pouring out of the openings onto the chutes, spray where it lands.
	var sheet := StandardMaterial3D.new()
	sheet.albedo_color = Color(0.85, 0.9, 0.95, 0.45)
	sheet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheet.roughness = 0.1
	sheet.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x: float in OPENINGS:
		_seam(Vector3(x, 31.0, 9.5), Vector3(16.0, 18.0, 0.05), sheet, Vector3(-0.35, 0.0, 0.0))
		var spray := Effects.puffs(Effects.gradient([Color(1, 1, 1, 0.0), Color(0.95, 0.97, 1.0, 0.5),
			Color(0.95, 0.97, 1.0, 0.0)]), 40, 2.5)
		spray.position = Vector3(x, 23.0, 18.0)
		spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		spray.emission_box_extents = Vector3(7.0, 0.5, 3.0)
		spray.direction = Vector3(0.0, 1.0, 0.6)
		spray.spread = 35.0
		spray.initial_velocity_min = 2.0
		spray.initial_velocity_max = 5.0
		spray.scale_amount_min = 3.0
		spray.scale_amount_max = 6.0
		add_child(spray)
	# Lamps along the crest road, clear of the two pads up there (a rotor would hit them).
	for k in 9:
		var x := -80.0 + k * 20.0
		if absf(x) < 14.0 or absf(x + 75.0) < 14.0:
			continue
		Props.place(self, "lamp_mast", Vector3(x, CREST + 0.5, -5.5 if k % 2 == 0 else 5.5), 0.0, 0.3)
		MapKit.night_light(self, Vector3(x, CREST + 8.0, -5.5 if k % 2 == 0 else 5.5), Color(1.0, 0.85, 0.6), 22.0)


## The power station at the dam's foot, three penstocks down the dam face into it, a
## transformer yard beside it.
func _power_station() -> void:
	var walls := Color(0.55, 0.5, 0.44)
	MapKit.block(self, Vector3(0.0, 3.0 + 11.0, 52.0), Vector3(70.0, 22.0, 24.0), walls)
	MapKit.block(self, Vector3(0.0, STATION_ROOF - 0.5, 52.0), Vector3(72.0, 1.0, 26.0), Color(0.3, 0.3, 0.32))
	MapKit.block(self, Vector3(0.0, 15.0, 64.2), Vector3(66.0, 3.0, 0.4), Color(0.12, 0.14, 0.16))  # Window band.
	for x: float in [-24.0, 0.0, 24.0]:  # The halls are lit at night.
		MapKit.night_light(self, Vector3(x, 15.0, 67.0), Color(1.0, 0.8, 0.5), 18.0)
	for x: float in [-24.0, 0.0, 24.0]:
		_pipe(Vector3(x, 34.0, DAM_HALF), Vector3(x, 10.0, 40.0), 2.2)
	for k in 6:
		var at := Vector3(-60.0 + (k % 3) * 9.0, 0.0, 40.0 + (k / 3) * 12.0)
		Props.place(self, "fuel_tank", Vector3(at.x, _ground(at.x, at.z), at.z), PI * 0.5, 0.9)
	Props.place(self, "shack_long", Vector3(52.0, _ground(52.0, 44.0), 44.0), 0.0)


## A thin mesh with no collision (seams, a water sheet), optionally tilted.
func _seam(center: Vector3, size: Vector3, material: Material, tilt := Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	mesh.rotation = tilt
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## A solid pipe from a to b (collision included).
func _pipe(a: Vector3, b: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_transform = Transform3D(Basis(), (a + b) * 0.5)
	var up := (b - a).normalized()
	var basis := Basis(Quaternion(Vector3.UP, up))
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = a.distance_to(b)
	shape.shape = cylinder
	shape.basis = basis
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = cylinder.height
	tube.radial_segments = 20
	mesh.mesh = tube
	mesh.basis = basis
	mesh.material_override = MapKit.surface(Color(0.32, 0.3, 0.28))
	body.add_child(mesh)


## Transmission lines: one from the station down the valley, one across it lower down
## (fly under it, not into it).
func _lines() -> void:
	var down: Array[Vector3] = []
	for z: float in [70.0, 165.0, 260.0]:
		var x := 0.62 * half_width(z)
		down.append(Vector3(x, _ground(x, z), z))
	Hazards.power_line(self, down)
	var across: Array[Vector3] = []
	for x: float in [-0.85, 0.0, 0.85]:
		var xx := x * half_width(150.0)
		across.append(Vector3(xx, _ground(xx, 150.0), 150.0))
	Hazards.power_line(self, across)


## Drowned trees standing out of the reservoir, rock islands, pines on the terraces.
func _reservoir() -> void:
	var placed := 0
	while placed < 26:
		var at := Vector3(_rng.randf_range(-100.0, 100.0), 0.0, _rng.randf_range(-320.0, -40.0))
		var g := _ground(at.x, at.z)
		if g < WATER - 9.0 or g > WATER - 1.0:
			continue
		placed += 1
		MapKit.tree(self, Vector3(at.x, g - 0.3, at.z), _rng.randf_range(1.0, 1.5), _rng.randi_range(0, 2))
	for at: Vector2 in [Vector2(-30.0, -120.0), Vector2(40.0, -200.0), Vector2(-10.0, -280.0), Vector2(55.0, -90.0)]:
		MapKit.rock(self, "boulder_%d" % _rng.randi_range(1, 4), Vector3(at.x, WATER - 6.0, at.y), _rng.randf() * TAU,
			_rng.randf_range(5.0, 8.0), MapKit.ROCK)


## The river valley: a ruined hamlet, wrecks, boulders, pines on the banks.
func _valley() -> void:
	for spec: Array in [["shack", -70.0, 180.0, 0.4], ["shack_long", -58.0, 200.0, 1.9], ["water_tower", -82.0, 214.0, 0.0],
			["wreck_truck", 30.0, 120.0, 0.9], ["wreck_heli", -40.0, 290.0, 2.0], ["crates", -64.0, 168.0, 0.3],
			["radar_station", 70.0, 300.0, 3.6]]:
		var x: float = spec[1]
		var z: float = spec[2]
		Props.place(self, spec[0], Vector3(x, _ground(x, z) - 0.2, z), spec[3])
	var placed := 0
	while placed < 40:
		var at := Vector3(_rng.randf_range(-110.0, 110.0), 0.0, _rng.randf_range(80.0, 330.0))
		var g := _ground(at.x, at.z)
		if g < RIVER + 1.5 or not _clear(at):
			continue
		placed += 1
		if _rng.randf() < 0.7:
			MapKit.tree(self, Vector3(at.x, g - 0.3, at.z), _rng.randf_range(0.9, 1.5), _rng.randi_range(0, 2))
		else:
			MapKit.rock(self, "boulder_%d" % _rng.randi_range(1, 4), Vector3(at.x, g, at.z), _rng.randf() * TAU,
				_rng.randf_range(1.5, 3.5), MapKit.ROCK)


## Open ground for spawns: away from pads, props, the power station and the lines.
func _clear(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	for s: Vector3 in _spawn_spots() + _pad_spots():
		if flat.distance_to(Vector2(s.x, s.z)) < 16.0:
			return false
	if absf(at.x) < 80.0 and at.z < 75.0:
		return false  # The power station, the tanks.
	for p: Vector2 in [Vector2(-70.0, 180.0), Vector2(-58.0, 200.0), Vector2(-82.0, 214.0), Vector2(30.0, 120.0),
			Vector2(-40.0, 290.0), Vector2(-64.0, 168.0), Vector2(70.0, 300.0)]:
		if flat.distance_to(p) < 14.0:
			return false
	return absf(at.z - 150.0) > 12.0  # Under the line across the valley.


func _spawn_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for spec: Vector2 in [Vector2(-0.38, 110.0), Vector2(0.4, 205.0), Vector2(-0.35, 255.0), Vector2(0.35, 310.0)]:
		var x := spec.x * half_width(spec.y)
		out.append(Vector3(x, 0.0, spec.y))
	# The shore terraces either side of the reservoir.
	for spec: Vector2 in [Vector2(-0.86, -130.0), Vector2(0.86, -170.0), Vector2(-0.86, -250.0), Vector2(0.86, -290.0)]:
		var x := spec.x * half_width(spec.y)
		out.append(Vector3(x, 0.0, spec.y))
	return out


## [position, ground function, ammo only]: two repair pads (crest, station roof), the
## rest ammo.
func _pad_spots() -> Array[Vector3]:
	return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 52.0), Vector3(-75.0, 0.0, 0.0),
		Vector3(0.86 * half_width(-215.0), 0.0, -215.0), Vector3(0.0, 0.0, 240.0)]


func _stations_and_spawns() -> void:
	var crest := func(_x: float, _z: float) -> float: return CREST + 0.5
	var roof := func(_x: float, _z: float) -> float: return STATION_ROOF
	var pads := _pad_spots()
	MapKit.station(self, pads[0], crest)
	MapKit.station(self, pads[1], roof)
	MapKit.station(self, pads[2], crest, true)
	MapKit.station(self, pads[3], _ground, true)
	MapKit.station(self, pads[4], _ground, true)
	for at: Vector3 in _spawn_spots():
		var toward := Vector3(0.0, 0.0, 0.0) - at
		var y := _ground(at.x, at.z)
		spawn_points.append(Transform3D(Basis(Vector3.UP, atan2(-toward.x, -toward.z)), Vector3(at.x, y, at.z)))
	for at in [Vector3(-20.0, 30.0, 120.0), Vector3(30.0, 35.0, 90.0), Vector3(0.0, 55.0, -60.0)]:
		dummy_posts.append(at)
