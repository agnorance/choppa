class_name TestRange
extends GameMap
## Sandbox map: open field, two tunnels through mesas, an arch, a pillar forest and item
## boxes. In "free" mode it has a few loose boost rings; in "race" mode a checkpoint
## course loops through both tunnels.

const SIZE := 800.0

## Race course: [center, yaw, ring radius]. Gate 0 is start/finish.
const COURSE := [
	[Vector3(0.0, 9.0, 60.0), 0.0, 8.0],
	[Vector3(0.0, 8.0, -60.0), 0.0, 8.0],
	[Vector3(0.0, 8.0, -180.0), 0.0, 6.0],  # Big tunnel.
	[Vector3(0.0, 10.0, -300.0), 0.0, 8.0],
	[Vector3(-130.0, 10.0, -280.0), PI * 0.5, 8.0],
	[Vector3(-80.0, 7.0, -60.0), PI * 0.5, 7.0],
	[Vector3(-200.0, 6.0, -60.0), PI * 0.5, 5.0],  # West tunnel.
	[Vector3(-300.0, 10.0, -60.0), PI * 0.5, 8.0],
	[Vector3(-220.0, 12.0, 80.0), PI * 0.5, 8.0],
	[Vector3(-90.0, 10.0, 100.0), PI * 0.5, 8.0],
]


func _init() -> void:
	spawn_points = [
		Transform3D(Basis(), Vector3(0.0, 3.0, 90.0)),
		Transform3D(Basis(), Vector3(-14.0, 3.0, 90.0)),
		Transform3D(Basis(), Vector3(14.0, 3.0, 90.0)),
		Transform3D(Basis(), Vector3(-7.0, 3.0, 108.0)),
		Transform3D(Basis(), Vector3(7.0, 3.0, 108.0)),
		Transform3D(Basis(), Vector3(-21.0, 3.0, 108.0)),
	]
	dummy_posts = [
		Vector3(-25.0, 10.0, 50.0), Vector3(25.0, 13.0, 45.0), Vector3(0.0, 17.0, 15.0),
	]


func _ready() -> void:
	MapKit.environment(self)
	MapKit.ground(self, SIZE)

	MapKit.mesa_tunnel(self, Vector3(0.0, 0.0, -180.0), 0.0, 120.0, 110.0, 45.0, 22.0, 16.0)
	MapKit.station(self, Vector3(40.0, 0.0, 70.0), func(_x: float, _z: float) -> float: return 0.0)
	MapKit.station(self, Vector3(-40.0, 0.0, 70.0), func(_x: float, _z: float) -> float: return 0.0)
	MapKit.station(self, Vector3(0.0, 0.0, 55.0), func(_x: float, _z: float) -> float: return 0.0, true)

	# A narrower, longer tunnel to the west running east-west.
	MapKit.mesa_tunnel(self, Vector3(-200.0, 0.0, -60.0), PI * 0.5, 160.0, 70.0, 35.0, 16.0, 12.0)

	MapKit.arch(self, Vector3(140.0, 0.0, -40.0), 0.4, 24.0, 18.0)

	# Pillar forest to the east.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 30:
		var base := Vector3(rng.randf_range(80.0, 300.0), 0.0, rng.randf_range(40.0, 300.0))
		MapKit.pillar(self, base, rng.randf_range(2.0, 5.0), rng.randf_range(15.0, 60.0))

	if mode == "race":
		for n in COURSE.size():
			var gate := RingGate.new()
			gate.index = n
			gate.radius = COURSE[n][2]
			gate.label = "START / FINISH" if n == 0 else ""
			gate.position = COURSE[n][0]
			gate.rotation.y = COURSE[n][1]
			add_child(gate)
			gates.append(gate)
	else:
		for z in [40.0, -20.0, -90.0, -180.0, -270.0]:
			MapKit.ring(self, Vector3(0.0, 8.0, z), 0.0)
		MapKit.ring(self, Vector3(-200.0, 6.0, -60.0), PI * 0.5)
