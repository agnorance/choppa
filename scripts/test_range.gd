class_name TestRange
extends Node3D
## Sandbox map: open field, a ring course through a mesa tunnel, a second tunnel, an arch,
## pillars to weave through and item boxes.

const SIZE := 800.0

var spawn_points: Array[Transform3D] = [
	Transform3D(Basis(), Vector3(0.0, 3.0, 90.0)),
	Transform3D(Basis(), Vector3(-12.0, 3.0, 90.0)),
	Transform3D(Basis(), Vector3(12.0, 3.0, 90.0)),
	Transform3D(Basis(), Vector3(-24.0, 3.0, 90.0)),
]


func _ready() -> void:
	MapKit.environment(self)
	MapKit.ground(self, SIZE)

	# Main course: rings lead north into the big tunnel and out the far side.
	MapKit.mesa_tunnel(self, Vector3(0.0, 0.0, -180.0), 0.0, 120.0, 110.0, 45.0, 22.0, 16.0)
	for z in [40.0, -20.0, -90.0, -180.0, -270.0]:
		MapKit.ring(self, Vector3(0.0, 8.0, z), 0.0)
	MapKit.item_row(self, Vector3(0.0, 6.0, 10.0), 0.0, 4)
	MapKit.item_row(self, Vector3(0.0, 7.0, -300.0), 0.0, 3)

	# A narrower, longer tunnel to the west running east-west.
	MapKit.mesa_tunnel(self, Vector3(-200.0, 0.0, -60.0), PI * 0.5, 160.0, 70.0, 35.0, 16.0, 12.0)
	MapKit.ring(self, Vector3(-200.0, 6.0, -60.0), PI * 0.5)

	MapKit.arch(self, Vector3(140.0, 0.0, -40.0), 0.4, 24.0, 18.0)
	MapKit.item_row(self, Vector3(140.0, 8.0, -40.0), 0.4, 3)

	# Pillar forest to the east.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 30:
		var base := Vector3(rng.randf_range(80.0, 300.0), 0.0, rng.randf_range(40.0, 300.0))
		MapKit.pillar(self, base, rng.randf_range(2.0, 5.0), rng.randf_range(15.0, 60.0))
