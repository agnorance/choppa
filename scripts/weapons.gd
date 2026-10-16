class_name Weapons
extends RefCounted
## Item weapons and their shared blast damage.


## Damages and shoves every choppa within `radius` of `at`, less at the edge.
static func blast(world: Node, at: Vector3, radius: float, amount: float, owner: Choppa, size := 1.0) -> void:
	var boom := Effects.Explosion.new()
	boom.size = size
	world.add_child(boom)
	boom.global_position = at
	for node in world.get_tree().get_nodes_in_group("choppas"):
		var c := node as Choppa
		if not c.alive:
			continue
		var offset := c.global_position - at
		var distance := offset.length()
		if distance > radius:
			continue
		var falloff := 1.0 - 0.5 * distance / radius
		var away := offset.normalized() if distance > 0.1 else Vector3.UP
		c.velocity += (away + Vector3.UP * 0.4) * 22.0 * falloff
		c.blast_damage(amount * falloff, owner, at)


## Seeks the target it locked at launch. Barrel-roll as it closes in to shake it off.
class Missile extends Node3D:
	const SPEED := 75.0
	const TURN := 2.6  ## rad/s
	const LIFETIME := 6.0
	const DAMAGE := 35.0
	const RADIUS := 7.0

	var shooter: Choppa
	var target: Choppa
	var direction := Vector3.FORWARD
	var _age := 0.0
	var _trail: CPUParticles3D

	func _ready() -> void:
		add_to_group("missiles")
		var body := CylinderMesh.new()
		body.top_radius = 0.18
		body.bottom_radius = 0.22
		body.height = 1.6
		body.radial_segments = 6
		var mesh := MeshInstance3D.new()
		mesh.mesh = body
		mesh.material_override = MapKit.material(Color(0.85, 0.85, 0.8))
		mesh.rotation_degrees.x = 90.0
		add_child(mesh)
		_trail = Effects.puffs(Effects.gradient([
			Color(1.0, 0.8, 0.4, 0.9), Color(0.6, 0.6, 0.6, 0.5), Color(0.7, 0.7, 0.7, 0.0),
		]), 40, 0.9)
		_trail.position.z = 0.9
		_trail.scale_amount_min = 0.8
		_trail.scale_amount_max = 1.6
		add_child(_trail)
		_trail.emitting = true
		Sounds.play_on(self, "missile_launch", -2.0)
		Sounds.loop_on(self, "missile_loop", -6.0, 0.8)
		_face()

	## True while it still homes in on `who`.
	func is_hunting(who: Choppa) -> bool:
		return target == who and is_instance_valid(target)

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age > LIFETIME:
			_explode(global_position)
			return
		if target and (not is_instance_valid(target) or not target.alive or target.in_smoke()):
			target = null
		if target:
			var to := target.global_position - global_position
			if to.length() < 25.0 and target.is_rolling_hard():
				# Shaken off: the seeker loses the lock and the missile veers wide.
				var side := direction.cross(Vector3.UP).normalized()
				if side.dot(to) > 0.0:
					side = -side
				direction = (direction + side * 0.8).normalized()
				target = null
			elif to.length() < 2.5:
				_explode(global_position)
				return
			else:
				var wanted := to.normalized()
				var angle := direction.angle_to(wanted)
				if angle > 0.001:
					direction = direction.slerp(wanted, minf(1.0, TURN * delta / angle)).normalized()
		var from := global_position
		var to_pos := from + direction * SPEED * delta
		var query := PhysicsRayQueryParameters3D.create(from, to_pos)
		if is_instance_valid(shooter):
			query.exclude = [shooter.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			_explode(hit.position)
			return
		global_position = to_pos
		_face()

	func _face() -> void:
		if absf(direction.dot(Vector3.UP)) < 0.99:
			basis = Basis.looking_at(direction)

	func _explode(at: Vector3) -> void:
		Weapons.blast(get_parent(), at, RADIUS, DAMAGE, shooter if is_instance_valid(shooter) else null)
		queue_free()


## Hovers where it was dropped and goes off when an enemy comes close.
class Mine extends Area3D:
	const ARM_TIME := 1.0
	const OWNER_SAFE_TIME := 3.0  ## Your own mine can't get you until then.
	const LIFETIME := 45.0
	const DAMAGE := 40.0
	const RADIUS := 9.0

	var owner_choppa: Choppa
	var _age := 0.0
	var _light: MeshInstance3D
	var _base_y := NAN  ## Hover height, taken from where it was dropped.

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 5.0
		shape.shape = sphere
		add_child(shape)
		var ball := SphereMesh.new()
		ball.radius = 0.9
		ball.height = 1.8
		ball.radial_segments = 10
		ball.rings = 5
		var mesh := MeshInstance3D.new()
		mesh.mesh = ball
		mesh.material_override = MapKit.material(Color(0.18, 0.18, 0.2))
		add_child(mesh)
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.18
		spike.height = 0.7
		spike.radial_segments = 5
		for dir: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var s := MeshInstance3D.new()
			s.mesh = spike
			s.material_override = mesh.material_override
			s.position = dir * 1.0
			# Turn the spike's Y axis to point along dir.
			s.basis = Basis(Vector3.RIGHT, PI) if dir == Vector3.DOWN else Basis(Quaternion(Vector3.UP, dir))
			add_child(s)
		var bulb := SphereMesh.new()
		bulb.radius = 0.25
		bulb.height = 0.5
		_light = MeshInstance3D.new()
		_light.mesh = bulb
		_light.material_override = MapKit.material(Color(1.0, 0.1, 0.05), 3.0)
		_light.position.y = 0.95
		add_child(_light)
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		_age += delta
		if is_nan(_base_y):
			_base_y = position.y
		position.y = _base_y + sin(_age * 1.5) * 0.3
		_light.visible = _age > ARM_TIME and fmod(_age, 0.6) < 0.3
		if _age > LIFETIME:
			queue_free()

	func _physics_process(_delta: float) -> void:
		if _age > ARM_TIME:
			for body in get_overlapping_bodies():
				_on_body_entered(body)

	func _on_body_entered(body: Node3D) -> void:
		if _age < ARM_TIME or not body is Choppa or not (body as Choppa).alive or is_queued_for_deletion():
			return
		if body == owner_choppa and _age < OWNER_SAFE_TIME:
			return
		Weapons.blast(get_parent(), global_position, RADIUS, DAMAGE, owner_choppa if is_instance_valid(owner_choppa) else null)
		queue_free()


## Looks just like an item box, except the question mark is upside down.
class FakeItemBox extends ItemBox:
	const DAMAGE := 30.0

	var owner_choppa: Choppa
	var _armed := 0.0

	func _ready() -> void:
		super._ready()
		for child in _visual.get_children():
			if child is Label3D:
				(child as Label3D).text = "¿"

	func _process(delta: float) -> void:
		_armed += delta
		super._process(delta)

	func _on_body_entered(body: Node3D) -> void:
		if not body is Choppa or (body == owner_choppa and _armed < 1.0) or is_queued_for_deletion():
			return
		Weapons.blast(get_parent(), global_position, 6.0, DAMAGE, owner_choppa if is_instance_valid(owner_choppa) else null, 0.7)
		queue_free()


## A thick cloud. Pilots inside can't see out (no lock-on, dark screen) and can't be
## locked onto.
class SmokeCloud extends Area3D:
	const RADIUS := 16.0
	const LIFETIME := 9.0

	var _age := 0.0
	var _puffs: CPUParticles3D

	func _ready() -> void:
		add_to_group("smoke")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = RADIUS
		shape.shape = sphere
		add_child(shape)
		_puffs = Effects.puffs(Effects.gradient([
			Color(0.25, 0.25, 0.28, 0.0), Color(0.22, 0.22, 0.25, 0.85),
			Color(0.25, 0.25, 0.28, 0.85), Color(0.3, 0.3, 0.32, 0.0),
		]), 60, 3.0)
		_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_puffs.emission_sphere_radius = RADIUS * 0.7
		_puffs.direction = Vector3.UP
		_puffs.spread = 180.0
		_puffs.initial_velocity_min = 0.5
		_puffs.initial_velocity_max = 2.0
		_puffs.scale_amount_min = 9.0
		_puffs.scale_amount_max = 14.0
		add_child(_puffs)
		_puffs.emitting = true

	func _process(delta: float) -> void:
		_age += delta
		if _age > LIFETIME - 3.0:
			_puffs.emitting = false
		if _age > LIFETIME:
			queue_free()

	## Whether `point` is inside the cloud while it is still thick.
	func covers(point: Vector3) -> bool:
		return _age < LIFETIME - 1.5 and point.distance_to(global_position) < RADIUS
