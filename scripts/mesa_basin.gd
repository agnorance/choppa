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

var terrain: Terrain

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

	MapKit.environment(self)
	terrain = Terrain.new()
	terrain.size = SIZE
	terrain.resolution = [126, 252, 506][Graphics.quality]  # 1.5 m cells on desktop.
	terrain.height_fn = _height
	terrain.material = MapKit.terrain_material(WATER_LEVEL)
	add_child(terrain)

	MapKit.cross_mesa(self, Vector3(0.0, -2.0, 0.0), 110.0, 42.0, 22.0, 17.0, Color(0.76, 0.47, 0.31))
	MapKit.item_row(self, Vector3(0.0, 45.0, 0.0), 0.0, 2, 10.0)

	# Ring of ruined arches around the mesa.
	for k in 6:
		var angle := TAU * k / 6.0 + 0.3
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 150.0
		at.y = _ground(at.x, at.z) - 3.0
		MapKit.arch(self, at, -(angle + PI * 0.5), 24.0, 22.0, MapKit.SANDSTONE)
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
		placed += 1
		at.y = _ground(at.x, at.z) - 2.0
		MapKit.hoodoo(self, at, _rng.randf_range(3.0, 5.5), _rng.randf_range(22.0, 48.0))

	# Bridge over the trench.
	var trench_x := _trench_center(0.0)
	MapKit.block(self, Vector3(trench_x, _ground(trench_x + 40.0, 0.0) - 1.0, 0.0),
		Vector3(80.0, 3.0, 10.0), MapKit.SANDSTONE.darkened(0.2))

	MapKit.water(self, Vector3(LAKE.x, WATER_LEVEL, LAKE.y), 200.0)

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
	for k in 45:
		var at := Vector3(_rng.randf_range(-260.0, 260.0), 0.0, _rng.randf_range(-260.0, 260.0))
		if _clear_of_structures(at):
			MapKit.boulder(self, Vector3(at.x, _ground(at.x, at.z), at.z), _rng.randf_range(2.0, 6.0))


	# Pickups.
	for k in 4:
		var angle := TAU * k / 4.0
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 92.0
		MapKit.item_row(self, Vector3(at.x, _ground(at.x, at.z) + 7.0, at.z), angle, 3)
	MapKit.item_row(self, Vector3(_trench_center(-120.0), _ground(_trench_center(-120.0), -120.0) + 6.0, -120.0), 0.0, 2)
	MapKit.item_row(self, Vector3(LAKE.x, WATER_LEVEL + 6.0, LAKE.y), 0.8, 3)
	for at: Vector3 in [
		Vector3(0.0, 6.0, 0.0),  # Where the tunnels cross.
		Vector3(_trench_center(150.0), _ground(_trench_center(150.0), 150.0) + 5.0, 150.0),
		Vector3(170.0, _ground(170.0, -165.0) + 6.0, -165.0),
		Vector3(LAKE.x - 40.0, WATER_LEVEL + 5.0, LAKE.y + 30.0),
	]:
		var crate := HealthCrate.new()
		crate.position = at
		add_child(crate)

	for k in 8:
		var angle := TAU * k / 8.0 + 0.2
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 215.0
		at.y = _ground(at.x, at.z) + 8.0
		# Face the middle of the arena.
		spawn_points.append(Transform3D(Basis(Vector3.UP, atan2(at.x, at.z)), at))
	for at: Vector3 in [Vector3(-30.0, 18.0, 110.0), Vector3(30.0, 22.0, 100.0), Vector3(0.0, 28.0, 75.0)]:
		dummy_posts.append(at)


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain and terrain.is_inside_tree() else _height(x, z)


func _trench_center(z: float) -> float:
	return -175.0 + sin(z / 55.0) * 18.0


func _clear_of_structures(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
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
	h += rim * (125.0 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 25.0)
	# Winding trench on the west side.
	var trench := 1.0 - smoothstep(9.0, 24.0, absf(x - _trench_center(z)))
	h -= trench * 20.0 * (1.0 - smoothstep(200.0, 240.0, absf(z)))
	# Lake basin.
	var lake := 1.0 - smoothstep(55.0, 95.0, Vector2(x, z).distance_to(LAKE))
	h = lerpf(h, -9.0, lake)
	return h + _detail.get_noise_2d(x, z) * 0.8

