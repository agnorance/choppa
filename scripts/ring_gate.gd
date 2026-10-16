class_name RingGate
extends Area3D
## Upright golden ring. Flying through it tops up the boost meter.
## In a race it is also a checkpoint: `index` is its place in the course.

signal passed(choppa: Choppa)

const BOOST_REWARD := 0.1
const GOLD := Color(1.0, 0.75, 0.15)
const NEXT := Color(0.2, 0.9, 1.0)

var radius := 5.0
var index := -1  ## Checkpoint number, -1 for a free ring.
var label := ""  ## Optional banner text above the ring.

var _material: StandardMaterial3D
var _flash := 0.0
var _glow := 0.25


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.6
	torus.outer_radius = radius + 0.6
	torus.rings = 32
	torus.ring_segments = 8
	_material = MapKit.material(GOLD, _glow)
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = _material
	mesh.rotation_degrees.x = 90.0
	add_child(mesh)

	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius - 0.4
	cylinder.height = 1.5
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.rotation_degrees.x = 90.0
	add_child(shape)

	if label != "":
		var banner := Label3D.new()
		banner.text = label
		banner.font_size = 96
		banner.outline_size = 18
		banner.pixel_size = 0.02
		banner.position.y = radius + 2.0
		add_child(banner)

	body_entered.connect(_on_body_entered)


## Race display: "next" glows cyan, "later" is dimmed, "normal" is plain gold.
func set_state(state: String) -> void:
	match state:
		"next":
			_material.albedo_color = NEXT
			_material.emission = NEXT
			_glow = 1.2
		"later":
			_material.albedo_color = GOLD.darkened(0.5)
			_material.emission = GOLD.darkened(0.5)
			_glow = 0.05
		_:
			_material.albedo_color = GOLD
			_material.emission = GOLD
			_glow = 0.25
	_material.emission_energy_multiplier = _glow


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_material.emission_energy_multiplier = _glow + _flash * 4.0


func _on_body_entered(body: Node3D) -> void:
	if not body is Choppa:
		return
	var choppa := body as Choppa
	choppa.boost_meter = minf(1.0, choppa.boost_meter + BOOST_REWARD)
	_flash = 0.5
	passed.emit(choppa)
