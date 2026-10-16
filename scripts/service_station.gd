class_name ServiceStation
extends Node3D
## A helipad with a mast. Set down on it and it repairs the hull and parts and refills
## the loadout over SERVICE_TIME seconds; then it powers down for COOLDOWN seconds, for
## everyone. One choppa at a time. Replaces the old item boxes and health crates.

signal served(choppa: Choppa)

const SERVICE_TIME := 4.0
const COOLDOWN := 45.0
const RADIUS := 4.5  ## Skids within this distance of the centre (flat) count as on the pad.
const MAX_SPEED := 4.0  ## Faster than this and you are not landed, you are passing through.
const PAD_RADIUS := 6.0
const READY_COLOR := Color(0.35, 1.0, 0.45)
const BUSY_COLOR := Color(1.0, 0.7, 0.2)
const DOWN_COLOR := Color(1.0, 0.15, 0.1)

var occupant: Choppa  ## Who is being serviced, or null.
var cooldown := 0.0
var _work_sound: AudioStreamPlayer3D
var _progress := 0.0
var _lamp: StandardMaterial3D
var _light: OmniLight3D
var _rim: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("stations")
	_build()


## The pad surface's height, where skids rest.
func pad_top() -> float:
	return global_position.y + 0.3


func is_ready() -> bool:
	return cooldown <= 0.0


## 0..1 while someone is being serviced.
func progress() -> float:
	return _progress / SERVICE_TIME


func _physics_process(delta: float) -> void:
	tick(delta)


## One simulation step; public so tests can drive it by hand.
func tick(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
		occupant = null
		_progress = 0.0
		_show(DOWN_COLOR if cooldown > 0.0 else READY_COLOR)
		return
	if occupant and not _is_landed(occupant):
		occupant = null
		_progress = 0.0
		if is_instance_valid(_work_sound):
			_work_sound.stop()
	if occupant == null:
		for node in get_tree().get_nodes_in_group("choppas"):
			if _is_landed(node as Choppa):
				occupant = node as Choppa
				_work_sound = Sounds.play_on_returning(self, "station_service", -4.0)
				break
	if occupant == null:
		_show(READY_COLOR)
		return
	_show(BUSY_COLOR if fmod(_progress, 0.5) < 0.3 else READY_COLOR)
	_progress += delta
	occupant.repair(delta / SERVICE_TIME)
	if _progress >= SERVICE_TIME:
		occupant.restock()
		served.emit(occupant)
		Sounds.play_at(get_parent(), "station_done", global_position + Vector3.UP * 2.0, -2.0)
		occupant = null
		_progress = 0.0
		cooldown = COOLDOWN


func _is_landed(c: Choppa) -> bool:
	if c == null or not c.alive:
		return false
	var flat := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z)
	var skids := c.global_position.y - c.clearance
	return flat.length() < RADIUS and absf(skids - pad_top()) < 1.2 and c.velocity.length() < MAX_SPEED


func _show(color: Color) -> void:
	if _lamp == null:
		return
	_lamp.emission = color
	_lamp.albedo_color = color
	_light.light_color = color
	for m in _rim:
		m.emission = color


func _build() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = PAD_RADIUS
	cylinder.height = 0.6
	shape.shape = cylinder
	body.add_child(shape)

	var model := Props.instance("station_pad")
	if model:
		add_child(model)
	else:
		# Fallback until the Blender props exist: a concrete disc with an H.
		var pad := CylinderMesh.new()
		pad.top_radius = PAD_RADIUS
		pad.bottom_radius = PAD_RADIUS + 0.3
		pad.height = 0.6
		pad.radial_segments = 32
		_add(pad, MapKit.material(Color(0.55, 0.55, 0.53)), Vector3.ZERO)
		var paint := MapKit.material(Color(0.95, 0.85, 0.3))
		for bar: Array in [[Vector3(0.5, 0.05, 4.0), Vector3(-1.4, 0.32, 0.0)], [Vector3(0.5, 0.05, 4.0), Vector3(1.4, 0.32, 0.0)],
				[Vector3(2.4, 0.05, 0.5), Vector3(0.0, 0.32, 0.0)]]:
			var box := BoxMesh.new()
			box.size = bar[0]
			_add(box, paint, bar[1])
		var mast := CylinderMesh.new()
		mast.top_radius = 0.12
		mast.bottom_radius = 0.18
		mast.height = 6.0
		_add(mast, MapKit.material(Color(0.3, 0.3, 0.32)), Vector3(PAD_RADIUS + 1.2, 3.0, 0.0))

	# Lamp on the mast and lights round the rim: the colour is the station's state.
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	_lamp.emission_energy_multiplier = 4.0
	var bulb := SphereMesh.new()
	bulb.radius = 0.35
	bulb.height = 0.7
	_add(bulb, _lamp, Vector3(PAD_RADIUS + 1.2, 6.2, 0.0))
	_light = OmniLight3D.new()
	_light.position = Vector3(PAD_RADIUS + 1.2, 6.2, 0.0)
	_light.omni_range = 14.0
	_light.light_energy = 1.5
	add_child(_light)
	for k in 8:
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.emission_energy_multiplier = 2.5
		m.albedo_color = Color(0.1, 0.1, 0.1)
		_rim.append(m)
		var dot := SphereMesh.new()
		dot.radius = 0.15
		dot.height = 0.3
		var a := TAU * k / 8.0
		_add(dot, m, Vector3(cos(a) * (PAD_RADIUS - 0.3), 0.35, sin(a) * (PAD_RADIUS - 0.3)))
	_show(READY_COLOR)


func _add(mesh: Mesh, material: Material, pos: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	add_child(instance)
