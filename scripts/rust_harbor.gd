class_name RustHarbor
extends GameMap
## Battle arena built for close manoeuvring: a derelict port. A long harbour basin runs
## north to south between two concrete quays, hemmed in by hills. The west quay holds a
## maze of container stacks (narrow alleys, stacks of different heights to hop over),
## a line of gantry cranes with their booms over the water, and warehouses open at both
## ends to fly through (one with holes in its roof). A rusting freighter is moored in
## the basin and a second one lies sunk to its deck further north; jetties stick out
## from the east quay, past fuel tanks and a radio mast, and a power line is strung
## across the water at the south end.
##
## Owner 2026-10-17: "lacks obstacles... way more, but in a natural way, so players can
## use it tactically". Three layers to fight in: low (container alleys, trains, scrap
## heaps, tetrapods), middle (straddle carriers, pipe racks, conveyor bridges, walkways to
## fly under or over) and high (cranes, silos, lamp masts, the lighthouse), with the open
## basin (tugs, barges, a second freighter, buoys) as the fast, exposed route between.

const SIZE := 900.0
const QUAY := 3.0  ## Height of the quay tops above the water.
const WATER_LEVEL := 0.0
const BASIN_WEST := -40.0  ## The harbour water lies between these x.
const BASIN_EAST := 150.0
const PLAY := 270.0  ## Half the play area; the hills rise beyond it.
const CONTAINER := Vector3(12.2, 2.6, 2.44)  ## Long side along X.
const COLORS := ["container_red", "container_blue", "container_green", "container_orange"]

## Repair pads (scarce, exposed or awkward) and ammo pads (quick, in cover).
const REPAIR_PADS: Array[Vector3] = [Vector3(-138.0, QUAY, 45.0), Vector3(232.0, QUAY, -60.0)]
const AMMO_PADS: Array[Vector3] = [Vector3(-150.0, QUAY, -165.0), Vector3(205.0, QUAY, 140.0),
	Vector3(-232.0, QUAY, 160.0), Vector3(95.0, QUAY, -185.0)]
const CRANES := [-160.0, -80.0, 0.0, 80.0, 160.0]  ## z of the gantry cranes along the west quay.
const RAIL_X := -265.0  ## The freight line along the back of the west quay.
const BREAKWATER_Z := 262.0
const BREAKWATER_TIP := 52.0  ## x of the lighthouse; the breakwater runs east to the quay.

var terrain: Terrain
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _yard_shapes: StaticBody3D  ## One body for every container stack's box.
var _container_transforms := {}  ## colour -> Array[Transform3D], drawn as MultiMeshes.


func _init() -> void:
	ceiling = 110.0
	menu_center = Vector3(-40.0, 12.0, 0.0)
	menu_orbit = Vector2(150.0, 60.0)


func _ready() -> void:
	_noise.seed = 77
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_rng.seed = 1977
	var t0 := Time.get_ticks_msec()
	MapKit.environment(self, Vector3(-22.0, 120.0, 0.0))
	terrain = Terrain.new()
	terrain.size = SIZE
	terrain.resolution = [120, 220, 420][Graphics.quality]
	terrain.height_fn = _height
	terrain.material = MapKit.terrain_material(WATER_LEVEL + 0.3, "rock")
	add_child(terrain)
	MapKit.backdrop(self, 480.0, 21)
	MapKit.water(self, Vector3(55.0, WATER_LEVEL, 0.0), SIZE)
	GameMap.report("harbor: terrain", t0)

	_quays()
	_container_yard()
	_cranes()
	_buildings()
	_ships()
	_east_side()
	_rail_line()
	_yard_machines()
	_bulk_terminal()
	_east_yard()
	_scrapyard()
	_basin_traffic()
	_breakwater()
	_lamp_masts()
	_depot_and_dock()
	_draw_containers()
	_stations_and_spawns()
	GameMap.report("harbor: built", t0)


## Terrain: the basin floor under the water, the quays just under their concrete slabs,
## hills rising all round beyond the play area.
func _height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	# The hills start beyond the quays' outer edges (x -290 and 400) and beyond z +-290.
	var edge := maxf(maxf(-290.0 - x, x - 400.0), absf(z) - (PLAY + 20.0))
	var hills := smoothstep(-20.0, 90.0, edge + (n - 0.5) * 60.0) * (90.0 + n * 50.0)
	var in_basin := 1.0 - smoothstep(-2.0, 6.0, maxf(BASIN_WEST - x, x - BASIN_EAST))
	var floor_height := lerpf(QUAY - 0.6, -9.0, in_basin)
	return floor_height + hills


## Where the ground (or a quay slab) is at (x, z), for placing things.
func _ground(x: float, z: float) -> float:
	if _on_quay(x, z):
		return QUAY
	return terrain.height_at(x, z) if terrain and terrain.is_inside_tree() else _height(x, z)


func _on_quay(x: float, z: float) -> bool:
	return absf(z) < PLAY + 10.0 and ((x < BASIN_WEST and x > -PLAY - 10.0) or (x > BASIN_EAST and x < 55.0 + PLAY + 30.0))


## Weathered dock concrete: the rock texture darkened and at a larger scale (MapKit.surface
## would lift any grey to pale stone).
func _concrete() -> StandardMaterial3D:
	var m := (MapKit.surface(Color(0.5, 0.5, 0.52)) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = Color(0.52, 0.52, 0.5)
	m.uv1_scale = Vector3.ONE * 0.05
	m.normal_scale = 0.6
	return m


func _slab(center: Vector3, size: Vector3) -> void:
	var body := MapKit.block(self, center, size, Color.GRAY)
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _concrete_material


var _concrete_material: StandardMaterial3D


func _quays() -> void:
	_concrete_material = _concrete()
	var concrete := Color(0.38, 0.38, 0.37)
	var west := (BASIN_WEST + (-PLAY - 10.0)) * 0.5
	_slab(Vector3(west, QUAY - 1.0, 0.0), Vector3(BASIN_WEST + PLAY + 10.0, 2.0, (PLAY + 10.0) * 2.0))
	var east_end := 55.0 + PLAY + 30.0
	_slab(Vector3((BASIN_EAST + east_end) * 0.5, QUAY - 1.0, 0.0), Vector3(east_end - BASIN_EAST, 2.0, (PLAY + 10.0) * 2.0))
	# Painted edge lines and bollards along both quay edges.
	var paint := MapKit.material(Color(0.85, 0.66, 0.12))
	var iron := MapKit.material(Color(0.12, 0.12, 0.13))
	for x: float in [BASIN_WEST - 2.0, BASIN_EAST + 2.0]:
		var line := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.4, 0.02, (PLAY + 10.0) * 2.0)
		line.mesh = strip
		line.material_override = paint
		line.position = Vector3(x, QUAY + 0.01, 0.0)
		add_child(line)
		var post := CylinderMesh.new()
		post.top_radius = 0.35
		post.bottom_radius = 0.45
		post.height = 0.9
		post.radial_segments = 10
		var bollards := MultiMesh.new()
		bollards.transform_format = MultiMesh.TRANSFORM_3D
		bollards.mesh = post
		var count := 26
		bollards.instance_count = count
		for k in count:
			var z := -PLAY + k * (PLAY * 2.0 / (count - 1))
			bollards.set_instance_transform(k, Transform3D(Basis(), Vector3(x + (0.8 if x > 0.0 else -0.8) * -1.0, QUAY + 0.45, z)))
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = bollards
		draw.material_override = iron
		add_child(draw)
	# Quay walls down to the water and a dark fender line.
	for x: float in [BASIN_WEST, BASIN_EAST]:
		MapKit.block(self, Vector3(x, -3.0, 0.0), Vector3(1.0, 12.0, (PLAY + 10.0) * 2.0), concrete.darkened(0.25))
	# Jetties out from the east quay.
	for z: float in [-185.0, 60.0, 200.0]:
		MapKit.block(self, Vector3(BASIN_EAST - 45.0, QUAY - 0.6, z), Vector3(90.0, 1.2, 12.0), concrete.darkened(0.1))
		for k in 5:
			MapKit.block(self, Vector3(BASIN_EAST - 10.0 - k * 18.0, -4.0, z), Vector3(1.6, 13.0, 10.0), concrete.darkened(0.35))


## Container stacks in blocks, with alleys between them: one box shape per stack for
## collision, and the containers drawn as one MultiMesh per colour.
func _container_yard() -> void:
	_yard_shapes = StaticBody3D.new()
	add_child(_yard_shapes)
	# Blocks: 3 stacks along X (one container long each) by 7 along Z.
	for bx in 3:
		for bz in 6:
			var corner := Vector3(-212.0 + bx * 50.0, QUAY, -110.0 + bz * 46.0)
			if Vector2(corner.x + 18.0 - REPAIR_PADS[0].x, corner.z + 9.0 - REPAIR_PADS[0].z).length() < 22.0:
				continue  # A clearing for the repair pad in the middle of the yard.
			for sx in 3:
				for sz in 7:
					if _rng.randf() < 0.12:
						continue  # A gap in the wall to slip through.
					var height := _rng.randi_range(1, 4)
					var at := corner + Vector3(sx * (CONTAINER.x + 0.6), 0.0, sz * (CONTAINER.z + 0.5))
					_stack(at, height)


## Every container placed so far as one MultiMesh per colour.
func _draw_containers() -> void:
	for color: String in _container_transforms:
		var mesh := Props.mesh_for(color)
		if mesh == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		var list: Array = _container_transforms[color]
		multi.instance_count = list.size()
		for k in list.size():
			multi.set_instance_transform(k, list[k])
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		add_child(draw)


## `height` containers on top of each other at `base`, turned by `turn` about the vertical.
func _stack(base: Vector3, height: int, turn := 0.0) -> void:
	for level in height:
		var color: String = COLORS[_rng.randi() % COLORS.size()]
		var yaw := turn + (PI if _rng.randf() < 0.5 else 0.0)
		var t := Transform3D(Basis(Vector3.UP, yaw), base + Vector3(0.0, level * CONTAINER.y, 0.0))
		if not _container_transforms.has(color):
			_container_transforms[color] = []
		_container_transforms[color].append(t)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CONTAINER.x, CONTAINER.y * height, CONTAINER.z)
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, turn), base + Vector3(0.0, CONTAINER.y * height * 0.5, 0.0))
	_yard_shapes.add_child(shape)


func _cranes() -> void:
	# Along the west quay edge, booms reaching out over the water (+X).
	for z: float in CRANES:
		Props.place(self, "gantry_crane", Vector3(BASIN_WEST - 10.0, QUAY, z), PI * 0.5)


func _buildings() -> void:
	# Warehouses, open at both ends: east-west through the two in the south, north-south
	# through the one by the yard.
	Props.place(self, "warehouse", Vector3(-150.0, QUAY, -165.0), 0.0)
	Props.place(self, "warehouse", Vector3(-150.0, QUAY, -215.0), 0.0)
	Props.place(self, "warehouse", Vector3(-238.0, QUAY, 60.0), PI * 0.5)
	Props.place(self, "radio_mast", Vector3(-240.0, QUAY, -120.0), 0.4)
	Props.place(self, "shack_long", Vector3(-90.0, QUAY, -150.0), 0.0)
	Props.place(self, "shack", Vector3(-95.0, QUAY, 215.0), 1.2)
	Props.place(self, "crates", Vector3(-70.0, QUAY, -120.0), 0.6)
	Props.place(self, "crates", Vector3(-60.0, QUAY, 110.0), 2.0)


func _ships() -> void:
	# A freighter moored along the west quay (bow north), and a sunk one further out.
	Props.place(self, "ship_hulk", Vector3(-5.0, -6.0, -40.0), PI * 0.5)
	Props.place(self, "ship_hulk", Vector3(95.0, -9.5, 135.0), PI * 0.5 + 0.35)


func _east_side() -> void:
	for k in 4:
		Props.place(self, "fuel_tank", Vector3(200.0 + (k % 2) * 22.0, QUAY, -130.0 + (k / 2) * 30.0), 0.0, 2.2)
	Props.place(self, "radio_mast", Vector3(250.0, QUAY, 175.0), 0.0)
	Props.place(self, "warehouse", Vector3(215.0, QUAY, 20.0), PI * 0.5)
	Props.place(self, "water_tower", Vector3(250.0, QUAY, -200.0), 0.0)
	# A power line across the water at the south end, pylon to pylon over the basin.
	Hazards.power_line(self, [Vector3(BASIN_WEST - 22.0, QUAY, -245.0), Vector3(BASIN_EAST + 22.0, QUAY, -245.0)] as Array[Vector3])


## A freight line along the back of the west quay: three trains of container flatcars
## with gaps between them, low cover to duck behind.
func _rail_line() -> void:
	var iron := MapKit.material(Color(0.2, 0.19, 0.18))
	for x: float in [RAIL_X - 0.75, RAIL_X + 0.75]:
		var rail := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.12, 0.15, PLAY * 2.0)
		rail.mesh = bar
		rail.material_override = iron
		rail.position = Vector3(x, QUAY + 0.07, 0.0)
		add_child(rail)
	for train: Vector2 in [Vector2(-252.0, 8), Vector2(-75.0, 6), Vector2(112.0, 8)]:
		for k in int(train.y):
			var z := train.x + k * 15.0
			Props.place(self, "rail_wagon", Vector3(RAIL_X, QUAY, z), PI * 0.5)
			if _rng.randf() < 0.8:
				_stack(Vector3(RAIL_X, QUAY + 1.4, z), 1 if _rng.randf() < 0.75 else 2, PI * 0.5)


## Straddle carriers parked over the alleys between the stacks: portals to thread.
func _yard_machines() -> void:
	for at: Vector2 in [Vector2(-193.0, -77.0), Vector2(-93.0, -77.0), Vector2(-143.0, -31.0), Vector2(-193.0, 15.0),
			Vector2(-93.0, 61.0), Vector2(-143.0, 107.0), Vector2(-193.0, 153.0)]:
		Props.place(self, "straddle_carrier", Vector3(at.x, QUAY, at.y), (PI * 0.5) * float(_rng.randi() % 2))
	# A covered walkway between the two southern warehouses, 8 m up: under or over.
	for x: float in [-162.0, -138.0]:
		MapKit.block(self, Vector3(x, QUAY + 9.0, -190.0), Vector3(3.0, 2.6, 26.0), Color(0.42, 0.4, 0.37))
	# Waiting rows under the cranes, low and long.
	for z: float in [-120.0, -40.0, 40.0, 120.0]:
		for k in 3:
			_stack(Vector3(-66.0, QUAY, z + (k - 1) * 3.0), 1 + int(_rng.randf() < 0.4), PI * 0.5)


## A grain terminal on the east quay: two rows of silos and conveyor bridges at 16 m
## running out toward the water, with pipe racks off the fuel tanks.
func _bulk_terminal() -> void:
	for row: float in [300.0, 316.0]:
		for k in 4:
			Props.place(self, "silo", Vector3(row, QUAY, -66.0 + k * 15.0), 0.0)
	for x: float in [230.0, 270.0]:
		Props.place(self, "conveyor", Vector3(x, QUAY, -20.0), 0.0)
	Props.place(self, "pipe_rack", Vector3(178.0, QUAY, -115.0), 0.0)
	Props.place(self, "pipe_rack", Vector3(246.0, QUAY, -140.0), PI * 0.5)


## A smaller container yard in the north-east, lower stacks, two straddle carriers.
func _east_yard() -> void:
	for bx in 2:
		for bz in 3:
			var corner := Vector3(278.0 + bx * 38.0, QUAY, 95.0 + bz * 52.0)
			for sx in 2:
				for sz in 7:
					if _rng.randf() < 0.18:
						continue
					_stack(corner + Vector3(sx * (CONTAINER.x + 0.6), 0.0, sz * (CONTAINER.z + 0.5)), _rng.randi_range(1, 3))
	Props.place(self, "straddle_carrier", Vector3(290.0, QUAY, 132.0), 0.0)
	Props.place(self, "straddle_carrier", Vector3(328.0, QUAY, 184.0), 0.0)


## Heaps of crushed cars in the south-east: rough, low cover by the water tower.
func _scrapyard() -> void:
	for at: Vector3 in [Vector3(305.0, 0.0, -245.0), Vector3(332.0, 2.0, -218.0), Vector3(300.0, 4.0, -196.0),
			Vector3(334.0, 1.0, -170.0), Vector3(282.0, 3.0, -226.0)]:
		Props.place(self, "scrap_pile_1" if int(at.y) % 2 == 0 else "scrap_pile_2", Vector3(at.x, QUAY, at.z), at.y, 1.2)


## Boats in the basin: a second freighter at the east quay, tugs, container barges and a
## line of buoys down the channel.
func _basin_traffic() -> void:
	Props.place(self, "ship_hulk", Vector3(136.0, -6.0, -100.0), -PI * 0.5)
	for t: Vector4 in [Vector4(108.0, -172.0, 0.0, 0.0), Vector4(40.0, 50.0, PI, 0.0), Vector4(25.0, -140.0, 0.6, 0.0),
			Vector4(75.0, 215.0, -0.4, 0.0)]:
		Props.place(self, "tugboat", Vector3(t.x, -1.8, t.y), t.z)
	_barge(Vector3(62.0, -1.5, -110.0), PI * 0.5)
	_barge(Vector3(88.0, -1.5, 25.0), 0.0)
	for k in 8:
		var z := -230.0 + k * 62.0
		Props.place(self, "buoy", Vector3(55.0 + (25.0 if k % 2 == 0 else -25.0), 0.0, z), 0.0)


## A barge (40 m along its length) with a deck load of containers.
func _barge(at: Vector3, turn: float) -> void:
	Props.place(self, "barge", at, turn)
	var deck := at + Vector3.UP * 3.0
	var along := Basis(Vector3.UP, turn) * Vector3(1.0, 0.0, 0.0)
	var across := Basis(Vector3.UP, turn) * Vector3(0.0, 0.0, 1.0)
	for i in 3:
		for j in 4:
			if _rng.randf() < 0.25:
				continue
			_stack(deck + along * (i - 1) * (CONTAINER.x + 0.6) + across * (j - 1.5) * (CONTAINER.z + 0.5),
				1 + int(_rng.randf() < 0.4), turn)


## A rubble breakwater across the north end of the basin, armoured with tetrapods, a
## lighthouse at its tip: it half closes the basin, so the way out is a gap to aim for.
func _breakwater() -> void:
	var rock := Color(0.4, 0.38, 0.35)
	MapKit.block(self, Vector3(BREAKWATER_TIP + 47.0, -2.5, BREAKWATER_Z), Vector3(94.0, 9.0, 10.0), rock)
	for k in 46:
		var x := BREAKWATER_TIP + 4.0 + k * 2.0 + _rng.randf_range(-0.6, 0.6)
		var side := -1.0 if k % 2 == 0 else 1.0
		Props.place(self, "tetrapod", Vector3(x, 0.6 + _rng.randf() * 1.2, BREAKWATER_Z + side * _rng.randf_range(4.0, 7.0)),
			_rng.randf() * TAU, _rng.randf_range(0.9, 1.15))
	MapKit.block(self, Vector3(BREAKWATER_TIP, 1.0, BREAKWATER_Z), Vector3(12.0, 4.0, 12.0), rock)
	Props.place(self, "lighthouse", Vector3(BREAKWATER_TIP, 3.0, BREAKWATER_Z), 0.0)
	if MapKit.time_of_day() > 0:
		var beacon := MapKit.Beacon.new()
		beacon.position = Vector3(BREAKWATER_TIP, 3.0 + 25.9, BREAKWATER_Z)
		add_child(beacon)


## The south-west corner: an empty-container depot of tall towers (pillars to circle);
## the north-west: a freighter up on blocks in dry dock; another shed on the east quay.
func _depot_and_dock() -> void:
	for i in 3:
		for j in 3:
			var at := Vector3(-240.0 + i * 24.0 + _rng.randf_range(-3.0, 3.0), QUAY, -258.0 + j * 40.0)
			_stack(at, _rng.randi_range(3, 6), PI * 0.5 * float(_rng.randi() % 2))
	var dock := Vector3(-185.0, QUAY, 238.0)
	for x: float in [-20.0, -8.0, 4.0, 16.0]:
		MapKit.block(self, dock + Vector3(x, 1.0, 0.0), Vector3(2.0, 2.0, 6.0), Color(0.3, 0.29, 0.28))
	Props.place(self, "ship_hulk", dock + Vector3.UP * 2.0, 0.0, 0.7)
	Props.place(self, "warehouse", Vector3(290.0, QUAY, 50.0), 0.0)


## Floodlight masts over both quays: tall, thin, easy to clip with a rotor.
func _lamp_masts() -> void:
	for at: Vector2 in [Vector2(-250.0, -200.0), Vector2(-250.0, -60.0), Vector2(-250.0, 110.0), Vector2(-250.0, 230.0),
			Vector2(-155.0, -77.0), Vector2(-105.0, 15.0), Vector2(-205.0, 107.0), Vector2(-120.0, 235.0),
			Vector2(170.0, -160.0), Vector2(170.0, 100.0), Vector2(240.0, -250.0), Vector2(345.0, -100.0),
			Vector2(345.0, 60.0), Vector2(230.0, 120.0), Vector2(345.0, 265.0)]:
		Props.place(self, "lamp_mast", Vector3(at.x, QUAY, at.y), 0.0)
		MapKit.night_light(self, Vector3(at.x, QUAY + 25.0, at.y), Color(1.0, 0.85, 0.6), 34.0)


func _stations_and_spawns() -> void:
	for at: Vector3 in REPAIR_PADS:
		MapKit.station(self, at, _ground)
	for at: Vector3 in AMMO_PADS:
		MapKit.station(self, at, _ground, true)
	for at: Vector3 in _spawn_spots():
		var toward := Vector3(55.0, 0.0, 0.0) - at  # Face the basin.
		spawn_points.append(Transform3D(Basis(Vector3.UP, atan2(-toward.x, -toward.z)), Vector3(at.x, QUAY, at.z)))
	for at: Vector3 in [Vector3(20.0, 18.0, 80.0), Vector3(60.0, 22.0, 20.0), Vector3(100.0, 16.0, -60.0)]:
		dummy_posts.append(at)


## On the quays, in the open, away from stacks, buildings and pads.
func _spawn_spots() -> Array[Vector3]:
	return [Vector3(-75.0, 0.0, -230.0), Vector3(-75.0, 0.0, 240.0), Vector3(-250.0, 0.0, -10.0),
		Vector3(-62.0, 0.0, 122.0), Vector3(180.0, 0.0, -230.0), Vector3(180.0, 0.0, 235.0),
		Vector3(250.0, 0.0, 70.0), Vector3(175.0, 0.0, -20.0)]
