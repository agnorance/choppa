class_name SlotCanyon
extends GameMap
## Battle arena: a long canyon winding through a high sandstone plateau. The floor is a
## shallow river with gravel banks, 50 to 90 m wide, the walls rise far above the
## flight ceiling, so the fight stays low and tight. Two wide bends hold an old mining
## camp (headframe, shacks, water tower, fuel tank) and a basin with a pool. A timber
## trestle crosses the canyon, power lines are strung across it in two places, natural
## arches bridge it, and the narrows have gusting crosswinds.

const LENGTH := 900.0  ## Along Z, from one end of the canyon to the other.
const SIZE := 1100.0
const RIVER_LEVEL := -1.0
const RIM := 150.0  ## Plateau height; the ceiling is well below it.

var terrain: Terrain

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


var _wrecks: Array[Vector3] = []  ## Where the battlefield wrecks stand (rocks and trees keep off).


func _init() -> void:
	ceiling = 85.0
	# Above the mining camp, inside the canyon.
	menu_center = Vector3(77.0, 8.0, 120.0)
	menu_orbit = Vector2(45.0, 38.0)


func _ready() -> void:
	_noise.seed = 31
	_noise.frequency = 0.008
	_noise.fractal_octaves = 4
	_detail.seed = 17
	_detail.frequency = 0.035
	_rng.seed = 4242
	seed(4242)
	var t0 := Time.get_ticks_msec()

	MapKit.environment(self, Vector3(-24.0, 35.0, 0.0))
	terrain = Terrain.new()
	terrain.size = SIZE
	terrain.resolution = [140, 280, 550][Graphics.quality]  # 2 m cells on desktop.
	terrain.normal_reach = 2 if Graphics.at_least(Graphics.Quality.HIGH) else 1
	terrain.height_fn = _height
	terrain.material = MapKit.terrain_material(RIVER_LEVEL + 0.5)
	add_child(terrain)
	GameMap.report("canyon: terrain", t0)
	MapKit.water(self, Vector3(0.0, RIVER_LEVEL, 0.0), SIZE)

	_mining_camp()
	_crossings()
	_battlefield()
	_rocks_and_trees()
	_stations_and_spawns()
	_winds()
	GameMap.report("canyon: built", t0)


## The canyon's centre line: x as a function of z (an S with a couple of wiggles).
func center_x(z: float) -> float:
	return sin(z / 160.0) * 120.0 + sin(z / 55.0 + 1.3) * 14.0


## Half the canyon floor's width at z: wide in the bends and the camp, narrow between.
func half_width(z: float) -> float:
	var narrows := 0.5 + 0.5 * cos(z / 95.0)
	var camp := 1.0 - smoothstep(0.0, 70.0, absf(z - 120.0))
	var pool := 1.0 - smoothstep(0.0, 60.0, absf(z + 250.0))
	return lerpf(26.0, 44.0, narrows) + 22.0 * camp + 18.0 * pool


func _height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var along := clampf(z, -LENGTH * 0.5, LENGTH * 0.5)
	var off := absf(x - center_x(along))
	var w := half_width(along)
	# Floor: a shallow river channel in the middle, gravel banks rising to the walls.
	var floor := RIVER_LEVEL - 1.2 + smoothstep(0.0, w * 0.45, off) * 4.0
	# Walls: steep, with ledges (terraces from the noise) and overhang-ish steps.
	var wall_t := smoothstep(w, w + 18.0 + n * 14.0, off + (n - 0.5) * 10.0)
	var terraces := floor_step(wall_t * RIM, 22.0, 0.35)
	var h := lerpf(floor, terraces, wall_t)
	# The ends of the canyon close off into the plateau.
	var end := smoothstep(LENGTH * 0.5 - 70.0, LENGTH * 0.5 + 10.0, absf(z))
	h = lerpf(h, RIM + n * 20.0, end)
	return h + _detail.get_noise_2d(x, z) * (0.6 + wall_t * 2.5)


## Rounds h into terraces `step` tall, keeping `soft` of the slope between them.
static func floor_step(h: float, step: float, soft: float) -> float:
	var k := floorf(h / step)
	var t := (h - k * step) / step
	return (k + smoothstep(1.0 - soft, 1.0, t)) * step


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain and terrain.is_inside_tree() else _height(x, z)


## A point on the canyon floor `side` (-1..1) across from the centre at z.
func floor_point(z: float, side := 0.0) -> Vector3:
	var x := center_x(z) + side * half_width(z) * 0.8
	return Vector3(x, _ground(x, z), z)


func _place(prop_name: String, at: Vector3, yaw := 0.0, size := 1.0) -> Node3D:
	return Props.place(self, prop_name, Vector3(at.x, _ground(at.x, at.z) - 0.3, at.z), yaw, size)


func _mining_camp() -> void:
	var z := 120.0
	var c := center_x(z)
	var w := half_width(z)
	_place("headframe", Vector3(c + w * 0.55, 0.0, z + 18.0), PI * 0.5)
	_place("water_tower", Vector3(c - w * 0.6, 0.0, z - 22.0), 0.3)
	_place("shack_long", Vector3(c + w * 0.45, 0.0, z - 25.0), 0.1)
	_place("shack", Vector3(c + w * 0.2, 0.0, z - 45.0), -0.4)
	_place("shack", Vector3(c - w * 0.5, 0.0, z + 30.0), 1.2)
	_place("fuel_tank", Vector3(c - w * 0.15, 0.0, z + 48.0), 0.5)
	_place("crates", Vector3(c + w * 0.1, 0.0, z - 8.0), 0.0)
	_place("crates", Vector3(c - w * 0.3, 0.0, z + 8.0), 1.0)


## Wrecks on the canyon floor: a convoy caught in the south, crashed helicopters, a
## sandbag post at the north end. Only on dry ground clear of the other features.
func _battlefield() -> void:
	for entry: Array in [["wreck_truck", -200.0, -0.35, 0.2], ["wreck_tank", -214.0, 0.3, 2.8],
			["wreck_truck", -228.0, -0.1, 0.1], ["wreck_heli", 0.0, -0.45, 1.4], ["wreck_heli", 165.0, 0.45, 3.6],
			["wreck_truck", 300.0, -0.35, 1.7], ["sandbags", -340.0, 0.4, 0.0], ["sandbags", -345.0, -0.4, 3.1]]:
		var at := floor_point(entry[1], entry[2])
		if at.y > RIVER_LEVEL + 0.5 and not _near_feature(at):
			_wrecks.append(at)
			_place(entry[0], at, entry[3])


func _crossings() -> void:
	# The trestle: a span on two piers across the narrows, deck at about 12 m.
	var tz := -60.0
	var tc := center_x(tz)
	var deck := 12.0
	var span := Props.place(self, "trestle", Vector3(tc, _ground(tc, tz) - 0.3, tz), atan2(-1.0, 0.0) * 0.0, 1.0)
	if span:
		span.rotation.y = -atan(_slope(tz))  # Square across the canyon.
		span.scale = Vector3(half_width(tz) * 2.4 / 32.0, 1.0, 1.0)
	else:
		MapKit.block(self, Vector3(tc, deck, tz), Vector3(half_width(tz) * 2.4, 1.0, 4.0), MapKit.SANDSTONE.darkened(0.3))
	# Natural arches spanning the canyon (the sculpted rock arches, scaled up).
	for z: float in [260.0, -330.0]:
		var at := floor_point(z)
		MapKit.rock(self, "arch_1" if z > 0.0 else "arch_2", Vector3(at.x, at.y - 2.0, z), -atan(_slope(z)) + PI * 0.5,
			half_width(z) / 30.0)
	# Power lines across the canyon in two places, pylons on the ledges.
	for z: float in [40.0, -180.0]:
		var c := center_x(z)
		var w := half_width(z)
		var left := Vector3(c - w - 6.0, 0.0, z)
		var right := Vector3(c + w + 6.0, 0.0, z)
		left.y = _ground(left.x, left.z) - 0.5
		right.y = _ground(right.x, right.z) - 0.5
		Hazards.power_line(self, [left, right] as Array[Vector3])
	# And one strung along the camp, low, between the headframe and the water tower.
	var a := Vector3(center_x(70.0) - 10.0, 0.0, 70.0)
	var b := Vector3(center_x(170.0) - 10.0, 0.0, 170.0)
	a.y = _ground(a.x, a.z) - 0.5
	b.y = _ground(b.x, b.z) - 0.5
	Hazards.power_line(self, [a, b] as Array[Vector3])


func _rocks_and_trees() -> void:
	# Boulders on the banks, hoodoos on the ledges, a few pines in the wide bends.
	for k in 70:
		var z := _rng.randf_range(-LENGTH * 0.45, LENGTH * 0.45)
		var side := _rng.randf_range(0.45, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var at := floor_point(z, side)
		if at.y < RIVER_LEVEL + 0.4 or _near_feature(at):
			continue
		MapKit.rock(self, "boulder_%d" % _rng.randi_range(1, 4), at + Vector3.DOWN * 0.5, _rng.randf() * TAU,
			_rng.randf_range(0.8, 2.4), MapKit.ROCK)
	for k in 18:
		var z := _rng.randf_range(-LENGTH * 0.4, LENGTH * 0.4)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var x := center_x(z) + side * (half_width(z) + _rng.randf_range(2.0, 8.0))
		var y := _ground(x, z)
		if y > 40.0:
			continue
		MapKit.rock(self, "hoodoo_%d" % _rng.randi_range(1, 3), Vector3(x, y - 2.0, z), _rng.randf() * TAU,
			_rng.randf_range(0.7, 1.1), MapKit.SANDSTONE.lerp(MapKit.ROCK, _rng.randf() * 0.4))
	var planted := 0
	var tries := 0
	while planted < 40 and tries < 600:
		tries += 1
		var z := _rng.randf_range(-LENGTH * 0.45, LENGTH * 0.45)
		var at := floor_point(z, _rng.randf_range(-1.0, 1.0))
		if at.y < RIVER_LEVEL + 1.0 or at.y > 6.0 or _near_feature(at) or half_width(z) < 40.0:
			continue
		MapKit.tree(self, at + Vector3.DOWN * 0.3, _rng.randf_range(0.8, 1.4), planted)
		planted += 1
	if Graphics.at_least(Graphics.Quality.MEDIUM) and Settings.choice("grass") != 0:
		var grass := Grass.new()
		grass.terrain = terrain
		grass.radius = LENGTH * 0.5
		grass.water_level = RIVER_LEVEL
		grass.density = 1.6 if Graphics.at_least(Graphics.Quality.HIGH) else 0.4
		grass.view_distance = 100.0 if Graphics.at_least(Graphics.Quality.HIGH) else 50.0
		grass.patches = _detail
		add_child(grass)


## Keeps scattered rocks and trees off the camp, the stations and the crossings.
## Where the choppas start: on dry ground, alternating sides along the canyon.
func _spawn_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 8:
		var z := lerpf(-LENGTH * 0.4, LENGTH * 0.4, k / 7.0)
		var side := 1.0 if k % 2 == 0 else -1.0
		var at := floor_point(z, 0.4 * side)
		for spot: Vector3 in _station_spots() + _ammo_spots():  # Not on top of a station.
			if absf(spot.z - z) < 28.0:
				z += 28.0 if z < 0.0 else -28.0  # Toward the middle, never past the ends.
				at = floor_point(z, 0.4 * side)
		for push: float in [0.5, 0.6, 0.7]:  # Off the river onto the bank.
			if at.y > RIVER_LEVEL + 0.5:
				break
			at = floor_point(z, push * side)
		out.append(at)
	return out


func _near_feature(at: Vector3) -> bool:
	for s: Vector3 in _wrecks:
		if Vector2(at.x - s.x, at.z - s.z).length() < 10.0:
			return true
	for s: Vector3 in _spawn_spots():
		if Vector2(at.x - s.x, at.z - s.z).length() < 12.0:
			return true
	for z: float in [120.0, -60.0, 40.0, -180.0, 260.0, -330.0]:
		if absf(at.z - z) < (60.0 if z == 120.0 else 14.0):
			return true
	for s: Vector3 in _station_spots() + _ammo_spots() + _pillar_spots():
		if Vector2(at.x - s.x, at.z - s.z).length() < 14.0:
			return true
	return false


func _station_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	# Repair pads are scarce (owner: "place them more tactically"): the open mining camp
	# and one mid-canyon. The ends only rearm (see _ammo_spots).
	for entry: Array in [[120.0, -0.25], [-250.0, 0.45]]:
		var z: float = entry[0]
		out.append(Vector3(center_x(z) + entry[1] * half_width(z), 0.0, z))
	return out


## Ammo-only stations: between the repair pads, clear of the power lines, and at the ends.
func _ammo_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for entry: Array in [[-110.0, 0.35], [190.0, -0.3], [330.0, 0.3], [-370.0, 0.0]]:
		var z: float = entry[0]
		out.append(Vector3(center_x(z) + entry[1] * half_width(z), 0.0, z))
	return out


## Rock pillars standing on the canyon floor between the crossings: cover to duck behind.
func _pillar_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for entry: Array in [[-150.0, -0.3], [-20.0, 0.32], [80.0, -0.35], [230.0, 0.3], [-290.0, 0.25]]:
		var z: float = entry[0]
		out.append(floor_point(z, entry[1]))
	return out


func _stations_and_spawns() -> void:
	for at: Vector3 in _pillar_spots():
		MapKit.rock(self, "hoodoo_%d" % (absi(int(at.z)) % 3 + 1), at + Vector3.DOWN * 2.0, at.z * 0.1, 1.5,
			MapKit.SANDSTONE.lerp(MapKit.ROCK, 0.3))
	for at in _station_spots():
		MapKit.station(self, at, _ground)
	for at in _ammo_spots():
		MapKit.station(self, at, _ground, true)
	# Spawns spread along the canyon, alternating sides, facing up or down it.
	for at: Vector3 in _spawn_spots():
		var z := at.z
		# Face along the canyon toward the middle (forward is -Z; the canyon runs along z).
		var toward := -1.0 if z > 0.0 else 1.0
		var dir := Vector3(_slope(z) * toward, 0.0, toward).normalized()
		spawn_points.append(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), at))
	for z: float in [60.0, 20.0, -20.0]:
		var at := floor_point(z)
		dummy_posts.append(Vector3(at.x, maxf(at.y, RIVER_LEVEL) + 14.0, z))


func _winds() -> void:
	# Gusting crosswinds in the two narrows, blowing across the canyon.
	for z: float in [-120.0, 210.0]:
		var c := center_x(z)
		var across := Vector3(1.0, 0.0, _slope(z)).normalized()
		Hazards.wind(self, Vector3(c, 30.0, z), Vector3(half_width(z) * 2.2, 60.0, 60.0),
			across * (5.0 if z < 0.0 else -5.0))


## dx/dz of the centre line: how the canyon runs at z.
func _slope(z: float) -> float:
	return (center_x(z + 1.0) - center_x(z - 1.0)) * 0.5
