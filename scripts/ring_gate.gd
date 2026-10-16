class_name RingGate
extends Area3D
## Upright golden ring. Flying through it tops up the boost meter.
## Later it doubles as a race checkpoint.

signal passed(choppa: Choppa)

const BOOST_REWARD := 0.1
const RADIUS := 5.0

var _material: StandardMaterial3D
var _flash := 0.0


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.6
	torus.outer_radius = RADIUS + 0.6
	torus.rings = 24
	torus.ring_segments = 8
	_material = MapKit.material(Color(1.0, 0.75, 0.15), 0.25)
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = _material
	mesh.rotation_degrees.x = 90.0
	add_child(mesh)

	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS - 0.4
	cylinder.height = 1.5
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.rotation_degrees.x = 90.0
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_material.emission_energy_multiplier = 0.25 + _flash * 4.0


func _on_body_entered(body: Node3D) -> void:
	if not body is Choppa:
		return
	var choppa := body as Choppa
	choppa.boost_meter = minf(1.0, choppa.boost_meter + BOOST_REWARD)
	_flash = 0.5
	passed.emit(choppa)
