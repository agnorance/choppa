class_name ItemBox
extends Area3D
## Floating, spinning "?" box. Breaks when a choppa flies through it, gives an item if
## the choppa's slot is empty, and respawns after a few seconds.

const RESPAWN_TIME := 4.0

var rng := RandomNumberGenerator.new()

var _visual: Node3D
var _material: StandardMaterial3D
var _respawn := 0.0
var _phase := randf() * TAU


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * 3.0
	shape.shape = box_shape
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 0.8
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = _material
	_visual.add_child(mesh)

	var label := Label3D.new()
	label.text = "?"
	label.font_size = 160
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	_visual.add_child(label)

	body_entered.connect(_on_body_entered)


func is_available() -> bool:
	return _respawn <= 0.0


func _process(delta: float) -> void:
	_phase += delta
	if _respawn > 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			_visual.visible = true
		return
	_visual.rotation = Vector3(_phase * 0.7, _phase * 1.3, 0.0)
	_visual.position.y = sin(_phase * 2.0) * 0.3
	var hue := fmod(_phase * 0.15, 1.0)
	_material.albedo_color = Color.from_hsv(hue, 0.6, 1.0, 0.75)
	_material.emission = Color.from_hsv(hue, 0.8, 1.0)


func _on_body_entered(body: Node3D) -> void:
	if not is_available() or not body is Choppa:
		return
	(body as Choppa).give_item(Items.roll(rng))
	_respawn = RESPAWN_TIME
	_visual.visible = false
