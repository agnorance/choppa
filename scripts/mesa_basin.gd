class_name MesaBasin
extends GameMap
## Battle arena: a desert basin ringed by sandstone cliffs. In the middle a mesa with two
## crossing tunnels, around it a ring of ruined arches. A winding trench on the west side
## for sneaking up low, a lake in the south-east, hoodoo towers in the north-east, pine
## groves on the hills. The cliffs rise above the flight ceiling, so nobody leaves.

const SIZE := 760.0
const PLAY_RADIUS := 260.0
const LAKE := Vector2(150.0, 150.0)
const WATER_LEVEL := -2.5
## Service stations placed for fights (owner: "place them more tactically"). Repair pads
## are few and exposed or awkward: on top of the mesa (king of the hill), down in the
## trench, in a clearing inside the hoodoo field. Ammo pads are quick and in cover:
## inside the arch ring behind an arch, beside the trench bridge, on the lake shore.
const REPAIR_PADS: Array[Vector3] = [Vector3(150.0, 0.0, -150.0)]  # Plus the mesa top and the trench.
const AMMO_PADS: Array[Vector3] = [Vector3(28.8, 0.0, 124.7), Vector3(-28.8, 0.0, -124.7), Vector3(150.0, 0.0, 45.0)]
## Tall rock pillars between the arches: cover in the main fighting ring, and a slalom.
const PILLAR_ANGLES := [47.0, 107.0, 167.0, 227.0, 287.0, 347.0]
const PILLAR_RADIUS := 118.0

var terrain: Terrain
var _mesa: Node3D

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	ceiling = 95.0


func _ready() -> void:
	_noise.seed = 3
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_detail.seed = 11
	_detail.frequency = 0.03
	_rng.seed = 2024
	seed(2024)  # MapKit decorations use the global RNG; keep the map identical every time.

	var t0 := Time.get_ticks_msec()
	MapKit.environment(self)
	terrain = Terrain.new()
	terrain.size = SIZE
	terrain.resolution = [126, 252, 506][Graphics.quality]  # 1.5 m cells on desktop.
	terrain.height_fn = _height
	terrain.material = MapKit.terrain_material(WATER_LEVEL)
	add_child(terrain)
	GameMap.report("basin: terrain+env", t0)
	MapKit.backdrop(self, 420.0, 7)
	GameMap.report("basin: backdrop", t0)

	_mesa = MapKit.rock(self, "mesa", Vector3(0.0, -2.0, 0.0), 0.0, 1.0, Color(0.76, 0.47, 0.31))
	MapKit.tunnel_lights(self, Vector3.ZERO, 110.0, 12.0)

	# Ring of ruined arches around the mesa.
	for k in 6:
		var angle := TAU * k / 6.0 + 0.3
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 150.0
		at.y = _ground(at.x, at.z) - 1.0
		MapKit.rock(self, "arch_%d" % (k % 2 + 1), at, -(angle + PI * 0.5), _rng.randf_range(0.9, 1.1))
	for k in 10:
		var angle := _rng.randf() * TAU
		var at := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(115.0, 190.0)
		if _clear_of_structures(at):
			at.y = _ground(at.x, at.z) - 1.0
			MapKit.ruined_column(self, at, _rng.randi_range(1, 4))

	# Hoodoo field in the north-east.
	var placed := 0
	while placed < 16:
		var at := Vector3(_rng.randf_range(100.0, 200.0), 0.0, _rng.randf_range(-200.0, -90.0))
		if Vector2(at.x, at.z).length() > 215.0 or absf(Vector2(at.x, at.z).length() - 150.0) < 16.0:
			continue
		if Vector2(at.x - REPAIR_PADS[0].x, at.z - REPAIR_PADS[0].z).length() < 22.0:
			continue  # The clearing for the repair pad.
		placed += 1
		at.y = _ground(at.x, at.z) - 2.0
		MapKit.rock(self, "hoodoo_%d" % _rng.randi_range(1, 3), at, _rng.randf() * TAU,
			_rng.randf_range(0.8, 1.2), MapKit.SANDSTONE.lerp(MapKit.ROCK, _rng.randf() * 0.5))

	GameMap.report("basin: rocks", t0)
	# Bridge over the trench.
	var trench_x := _trench_center(0.0)
	MapKit.block(self, Vector3(trench_x, _ground(trench_x + 40.0, 0.0) - 1.0, 0.0),
		Vector3(80.0, 3.0, 10.0), MapKit.SANDSTONE.darkened(0.2))

	MapKit.water(self, Vector3(LAKE.x, WATER_LEVEL, LAKE.y), 200.0)

	GameMap.report("basin: water", t0)
	# Pine groves on the hills, boulders everywhere.
	var planted := 0
	while planted < 90:
		var at := Vector3(_rng.randf_range(-250.0, 250.0), 0.0, _rng.randf_range(-250.0, 250.0))
		var grove := _noise.get_noise_2d(at.x * 3.0, at.z * 3.0)
		var ground := _ground(at.x, at.z)
		if grove < 0.1 or ground < 0.5 or ground > 30.0 or not _clear_of_structures(at):
			continue
		MapKit.tree(self, Vector3(at.x, ground - 0.3, at.z), _rng.randf_range(0.9, 1.6), planted)
		planted += 1
	GameMap.report("basin: trees", t0)
	var grass_level := Settings.choice("grass")
	if grass_level == Settings.AUTO:
		grass_level = 2 if Graphics.at_least(Graphics.Quality.HIGH) else (1 if Graphics.at_least(Graphics.Quality.MEDIUM) else 0)
	if grass_level > 0:
		var grass := Grass.new()
		grass.terrain = terrain
		grass.radius = PLAY_RADIUS
		grass.inner_radius = 80.0  # Under the mesa.
		grass.water_level = WATER_LEVEL
		grass.density = 2.6 if grass_level == 2 else 0.6
		grass.view_distance = 110.0 if grass_level == 2 else 55.0
		grass.patches = _detail
		add_child(grass)
	for k in 45:
		var at := Vector3(_rng.randf_range(-260.0, 260.0), 0.0, _rng.randf_range(-260.0, 260.0))
		if _clear_of_structures(at):
			MapKit.rock(self, "boulder_%d" % _rng.randi_range(1, 4), Vector3(at.x, _ground(at.x, at.z), at.z),
				_rng.randf() * TAU, _rng.randf_range(1.0, 3.2), MapKit.ROCK)


	GameMap.report("basin: grass+boulders", t0)
	# Pillars between the arches.
	for degrees: float in PILLAR_ANGLES:
		var angle := deg_to_rad(degrees)
		var at := Vector3(cos(angle), 0.0, sin(angle)) * PILLAR_RADIUS
		at.y = _ground(at.x, at.z) - 2.0
		MapKit.rock(self, "hoodoo_%d" % (int(degrees) % 3 + 1), at, angle, 1.7,
			MapKit.SANDSTONE.lerp(MapKit.ROCK, 0.25))
	# Power lines across the trench: a hazard for whoever sneaks along it.
	for z: float in [80.0, -60.0]:
		var c := _trench_center(z)
		var bases: Array[Vector3] = []
		for side: float in [-48.0, 48.0]:
			bases.append(Vector3(c + side, _ground(c + side, z), z))
		Hazards.power_line(self, bases)

	# Service stations (see REPAIR_PADS).
	MapKit.station(self, Vector3(0.0, 0.0, 0.0), func(x: float, z: float) -> float: return MapKit.top_of(_mesa, x, z))
	MapKit.station(self, Vector3(_trench_center(-120.0), 0.0, -120.0), _ground)
	for at: Vector3 in REPAIR_PADS:
		MapKit.station(self, at, _ground)
	for at: Vector3 in AMMO_PADS:
		MapKit.station(self, at, _ground, true)
	# Beside the trench bridge, half in its shadow.
	MapKit.station(self, Vector3(_trench_center(10.0), 0.0, 11.0), _ground, true)

	for at: Vector3 in _spawn_spots():
		at.y = _ground(at.x, at.z)
		# On the ground, facing the middle of the arena.
		spawn_points.append(Transform3D(Basis(Vector3.UP, atan2(at.x, at.z)), at))
	for at: Vector3 in [Vector3(-30.0, 18.0, 110.0), Vector3(30.0, 22.0, 100.0), Vector3(0.0, 28.0, 75.0)]:
		dummy_posts.append(at)


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain and terrain.is_inside_tree() else _height(x, z)


func _trench_center(z: float) -> float:
	return -175.0 + sin(z / 55.0) * 18.0


## Where the choppas start: on the ground around the arena (kept clear of rocks and trees).
func _spawn_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	# Angles chosen around the lake (south-east) and the trench (west): spawns sit on
	# dry, open ground.
	for degrees: float in [-120.0, -90.0, -60.0, -25.0, 5.0, 85.0, 108.0, 126.0]:
		var angle := deg_to_rad(degrees)
		out.append(Vector3(cos(angle), 0.0, sin(angle)) * 205.0)
	return out


func _clear_of_structures(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	for s: Vector3 in _spawn_spots():
		if flat.distance_to(Vector2(s.x, s.z)) < 12.0:
			return false
	for s: Vector3 in REPAIR_PADS + AMMO_PADS:
		if flat.distance_to(Vector2(s.x, s.z)) < 14.0:
			return false
	for degrees: float in PILLAR_ANGLES:
		var angle := deg_to_rad(degrees)
		if flat.distance_to(Vector2(cos(angle), sin(angle)) * PILLAR_RADIUS) < 12.0:
			return false
	if flat.length() < 85.0:  # Mesa.
		return false
	if absf(flat.length() - 150.0) < 18.0:  # Arch ring.
		return false
	if absf(at.x - _trench_center(at.z)) < 32.0:  # Trench.
		return false
	return flat.distance_to(LAKE) > 90.0


func _height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := n * 14.0 * smoothstep(70.0, 160.0, r)
	# Cliffs all around, always taller than the flight ceiling.
	var rim := smoothstep(PLAY_RADIUS - 20.0, PLAY_RADIUS + 70.0, r + (n - 0.5) * 50.0)
	var cliff := rim * (125.0 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 25.0)
	# Sandstone ledges: the cliffs climb in steps, steep faces between shelves, so they
	# read as layered rock rather than a smooth ramp.
	var t := (cliff + (n - 0.5) * 10.0) / 21.0
	var stepped := (floorf(t) + smoothstep(0.55, 1.0, fposmod(t, 1.0))) * 21.0
	h += lerpf(cliff, stepped, 0.85 * smoothstep(0.05, 0.3, rim))
	# Winding trench on the west side.
	var trench := 1.0 - smoothstep(9.0, 24.0, absf(x - _trench_center(z)))
	h -= trench * 20.0 * (1.0 - smoothstep(200.0, 240.0, absf(z)))
	# Lake basin.
	var lake := 1.0 - smoothstep(55.0, 95.0, Vector2(x, z).distance_to(LAKE))
	h = lerpf(h, -9.0, lake)
	return h + _detail.get_noise_2d(x, z) * 0.8

