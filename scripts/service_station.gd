class_name ServiceStation
extends Node3D
## A helipad with a mast. Set down on it and it repairs the hull and parts and refills
## the loadout over SERVICE_TIME seconds; then it powers down for COOLDOWN seconds, for
## everyone. An `ammo_only` station (blue, with crates) only rearms, in AMMO_TIME. One choppa at a time. Replaces the old item boxes and health crates.

signal served(choppa: Choppa)

const SERVICE_TIME := 4.0
const COOLDOWN := 45.0
const RADIUS := 4.5  ## Skids within this distance of the centre (flat) count as on the pad.
const MAX_SPEED := 4.0  ## Faster than this and you are not landed, you are passing through.
const PAD_RADIUS := 6.0
const READY_COLOR := Color(0.35, 1.0, 0.45)
const BUSY_COLOR := Color(1.0, 0.7, 0.2)
const DOWN_COLOR := Color(1.0, 0.15, 0.1)
const AMMO_TIME := 2.0
const AMMO_COOLDOWN := 20.0
const AMMO_COLOR := Color(0.3, 0.7, 1.0)  ## An ammo station's ready colour.

## Ammo stations rearm without repairing, quicker and back sooner. There are more of
## them, so running dry means a short hop rather than a trip across the map. Set before
## adding to the tree.
var ammo_only := false

var occupant: Choppa  ## Who is being serviced, or null.
var cooldown := 0.0
## False on a network client: the server decides who is serviced; the client shows it.
var authority := true
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
	return _progress / service_time()


func service_time() -> float:
	return AMMO_TIME if ammo_only else SERVICE_TIME


func _ready_color() -> Color:
	return AMMO_COLOR if ammo_only else READY_COLOR


func _physics_process(delta: float) -> void:
	tick(delta)


## One simulation step; public so tests can drive it by hand.
func tick(delta: float) -> void:
	if not authority:
		_show(DOWN_COLOR if cooldown > 0.0 else (BUSY_COLOR if occupant else _ready_color()))
		return
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
		occupant = null
		_progress = 0.0
		_show(DOWN_COLOR if cooldown > 0.0 else _ready_color())
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
		_show(_ready_color())
		return
	_show(BUSY_COLOR if fmod(_progress, 0.5) < 0.3 else _ready_color())
	_progress += delta
	if not ammo_only:
		occupant.repair(delta / SERVICE_TIME)
	if _progress >= service_time():
		occupant.restock()
		served.emit(occupant)
		Sounds.play_at(get_parent(), "station_done", global_position + Vector3.UP * 2.0, -2.0)
		occupant = null
		_progress = 0.0
		cooldown = AMMO_COOLDOWN if ammo_only else COOLDOWN


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
	if ammo_only:
		# Crates of rounds by the mast tell it apart from a repair pad at a glance.
		var crate := BoxMesh.new()
		crate.size = Vector3(1.3, 0.8, 0.9)
		var olive := StandardMaterial3D.new()  # Dark military olive; MapKit.material washes it pale.
		olive.albedo_color = Color(0.17, 0.19, 0.11)
		olive.roughness = 0.8
		for spot: Vector3 in [Vector3(0.0, 0.4, 1.6), Vector3(0.0, 0.4, 2.6), Vector3(0.0, 1.2, 2.1)]:
			_add(crate, olive, spot + Vector3(PAD_RADIUS + 1.4, 0.0, 0.0))
		var band := BoxMesh.new()
		band.size = Vector3(1.32, 0.12, 0.92)
		var yellow := MapKit.material(Color(0.95, 0.75, 0.15))
		for spot: Vector3 in [Vector3(0.0, 0.5, 1.6), Vector3(0.0, 0.5, 2.6), Vector3(0.0, 1.3, 2.1)]:
			_add(band, yellow, spot + Vector3(PAD_RADIUS + 1.4, 0.0, 0.0))
	_show(_ready_color())


func _add(mesh: Mesh, material: Material, pos: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	add_child(instance)


## Network client: the server's state of this station.
func net_state(new_cooldown: float, who: Choppa, done: float) -> void:
	cooldown = new_cooldown
	occupant = who
	_progress = done * service_time()
