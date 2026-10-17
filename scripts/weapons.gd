class_name Weapons
extends RefCounted
## Item weapons and their shared blast damage.


## Damages and shoves every choppa within `radius` of `at`, less at the edge.
static func blast(world: Node, at: Vector3, radius: float, amount: float, owner: Choppa, size := 1.0, how := "blast") -> void:
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
		c.blast_damage(amount * falloff, owner, at, how)


## Seeks the target it locked at launch. Flares, or rolling hard as it closes in, shake it off.
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

	## The seeker loses the lock and the missile veers wide of where it was going.
	func shake_off() -> void:
		if target == null:
			return
		var to := target.global_position - global_position
		var side := direction.cross(Vector3.UP).normalized()
		if side.dot(to) > 0.0:
			side = -side
		direction = (direction + side * 0.8).normalized()
		target = null

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
			if (to.length() < 25.0 and target.is_rolling_hard()) or target.decoy_time > 0.0:
				shake_off()
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
		Weapons.blast(get_parent(), at, RADIUS, DAMAGE, shooter if is_instance_valid(shooter) else null, 1.0, "missile")
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
		Weapons.blast(get_parent(), global_position, RADIUS, DAMAGE, owner_choppa if is_instance_valid(owner_choppa) else null,
			1.0, "mine")
		queue_free()


## Unguided, fast, straight: 12 damage on the part it strikes plus a small blast.
class Rocket extends Node3D:
	const SPEED := 150.0
	const LIFETIME := 2.5
	const DAMAGE := 12.0
	const SPLASH := 6.0
	const SPLASH_RADIUS := 4.0

	var shooter: Choppa
	var direction := Vector3.FORWARD
	var speed := SPEED
	var _age := 0.0

	func _ready() -> void:
		add_to_group("rockets")
		var body := CylinderMesh.new()
		body.top_radius = 0.07
		body.bottom_radius = 0.09
		body.height = 1.0
		body.radial_segments = 6
		var mesh := MeshInstance3D.new()
		mesh.mesh = body
		mesh.material_override = MapKit.material(Color(0.4, 0.42, 0.35))
		mesh.rotation_degrees.x = 90.0
		add_child(mesh)
		var trail := Effects.puffs(Effects.gradient([
			Color(1.0, 0.75, 0.35, 0.9), Color(0.65, 0.65, 0.65, 0.4), Color(0.7, 0.7, 0.7, 0.0),
		]), 24, 0.5)
		trail.position.z = 0.6
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.9
		add_child(trail)
		trail.emitting = true
		Sounds.play_on(self, "rocket_launch", -4.0, randf_range(0.92, 1.08))
		_face()

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age > LIFETIME:
			queue_free()
			return
		var from := global_position
		var to := from + direction * speed * delta
		var query := PhysicsRayQueryParameters3D.create(from, to)
		if is_instance_valid(shooter):
			query.exclude = [shooter.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			var owner_choppa := shooter if is_instance_valid(shooter) else null
			var target := hit.collider as Choppa
			if target and target.take_hit(direction * 3.0, owner_choppa, DAMAGE, hit.position, "rocket") and owner_choppa:
				owner_choppa.scored_hit.emit(target)
			Weapons.blast(get_parent(), hit.position, SPLASH_RADIUS, SPLASH, owner_choppa, 0.5, "rocket")
			queue_free()
			return
		global_position = to
		_face()

	func _face() -> void:
		if absf(direction.dot(Vector3.UP)) < 0.99:
			basis = Basis.looking_at(direction)


## A burst of burning flares falling away behind a choppa; the choppa does the decoying.
## A salvo of flares like real ones: PELLETS burning pellets kicked out one after
## another, left and right of the tail, each falling in an arc, blazing white-hot and
## trailing smoke. Purely visual: the decoy itself is Choppa.fire_flares.
class Flares extends Node3D:
	const PELLETS := 8
	const INTERVAL := 0.09

	var carrier: Node3D  ## Who fired them: the pellets leave its launchers as it flies on.
	var _fired := 0
	var _clock := 0.0
	var _started := false

	func _ready() -> void:
		_start.call_deferred()  # The caller places us right after add_child.

	func _start() -> void:
		_started = true
		Sounds.play_at(get_parent(), "flares", global_position, -2.0)

	func _physics_process(delta: float) -> void:
		if not _started:
			return
		_clock += delta
		while _fired < PELLETS and _clock >= _fired * INTERVAL:
			_eject()
			_fired += 1
		if _fired >= PELLETS and get_child_count() == 0:
			queue_free()

	func _eject() -> void:
		var side := -1.0 if _fired % 2 == 0 else 1.0
		var b := global_basis
		var at := global_position
		var inherit := Vector3.ZERO
		if is_instance_valid(carrier):
			b = carrier.global_basis
			at = carrier.global_transform * Vector3(0.7 * side, -0.7, 1.6)
			if carrier is CharacterBody3D:
				inherit = (carrier as CharacterBody3D).velocity
		var pellet := FlarePellet.new()
		# Out sideways and down, a little back, never two the same.
		var kick := Vector3(side * randf_range(6.0, 9.0), randf_range(-5.0, -2.5), randf_range(2.0, 4.0))
		pellet.velocity = inherit * 0.9 + b * kick
		add_child(pellet)
		pellet.global_position = at


## One burning flare pellet: white-hot core, orange halo, its own light, a smoke trail.
class FlarePellet extends Node3D:
	const BURN := 3.0
	const SMOKE_LIFE := 2.6

	var velocity := Vector3.ZERO
	var _age := 0.0
	var _core: MeshInstance3D
	var _halo: MeshInstance3D
	var _light: OmniLight3D
	var _smoke: CPUParticles3D

	func _ready() -> void:
		top_level = true
		# White-hot: well above 1 on purpose, tone mapping takes it to a blazing white.
		_core = Effects.flash(1.5, Color(3.0, 2.4, 1.7))
		add_child(_core)
		_halo = Effects.flash(3.6, Color(1.0, 0.55, 0.2, 0.7))
		# A round glow around the star-shaped core.
		(_halo.material_override as StandardMaterial3D).albedo_texture = Effects._soft_dot()
		add_child(_halo)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.75, 0.45)
		_light.light_energy = 4.0
		_light.omni_range = 14.0
		add_child(_light)
		_smoke = Effects.puffs(Effects.gradient([
			Color(0.95, 0.93, 0.9, 0.0), Color(0.93, 0.91, 0.88, 0.8),
			Color(0.84, 0.84, 0.84, 0.45), Color(0.8, 0.8, 0.8, 0.0)]), 160, SMOKE_LIFE, true)
		((_smoke.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture = Effects._soft_dot()
		_smoke.direction = Vector3.UP
		_smoke.spread = 180.0
		_smoke.initial_velocity_min = 0.1
		_smoke.initial_velocity_max = 0.6
		_smoke.gravity = Vector3(0.0, 0.5, 0.0)  # The trail drifts up a little as it cools.
		_smoke.scale_amount_min = 1.2
		_smoke.scale_amount_max = 2.4
		_smoke.emitting = false  # World-space particles: start once we are in place.
		add_child(_smoke)

	func _physics_process(delta: float) -> void:
		_age += delta
		var burning := _age < BURN
		if burning and not _smoke.emitting:
			_smoke.emitting = true
		velocity += Vector3.DOWN * 7.0 * delta
		velocity *= exp(-0.9 * delta)
		var step := velocity * delta
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			# Lands and burns on where it fell, with a small bounce.
			velocity = velocity.bounce((hit.normal as Vector3)) * 0.25
			global_position = (hit.position as Vector3) + (hit.normal as Vector3) * 0.15
		else:
			global_position += step
		var fade := clampf((BURN - _age) / 0.6, 0.0, 1.0)
		var flicker := randf_range(0.85, 1.15)
		_core.scale = Vector3.ONE * flicker * (0.4 + 0.6 * fade)
		_halo.scale = Vector3.ONE * randf_range(0.9, 1.1) * fade
		_light.light_energy = 4.0 * flicker * fade
		if not burning:
			_core.visible = false
			_halo.visible = false
			_light.visible = false
			_smoke.emitting = false
		if _age > BURN + SMOKE_LIFE:
			queue_free()


## A thick cloud. Pilots inside can't see out (no lock-on, dark screen) and can't be
## locked onto.
class SmokeCloud extends Area3D:
	const RADIUS := 24.0
	const LIFETIME := 12.0

	var _age := 0.0
	var _puffs: CPUParticles3D

	func _ready() -> void:
		add_to_group("smoke")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = RADIUS
		shape.shape = sphere
		add_child(shape)
		# A wall you can't see through: many big, thick puffs filling the whole sphere.
		_puffs = Effects.puffs(Effects.gradient([
			Color(0.24, 0.24, 0.27, 0.0), Color(0.22, 0.22, 0.25, 0.97),
			Color(0.25, 0.25, 0.28, 0.97), Color(0.3, 0.3, 0.32, 0.0),
		]), 170, 4.0)
		_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_puffs.emission_sphere_radius = RADIUS * 0.75
		_puffs.direction = Vector3.UP
		_puffs.spread = 180.0
		_puffs.initial_velocity_min = 0.4
		_puffs.initial_velocity_max = 1.6
		_puffs.scale_amount_min = 14.0
		_puffs.scale_amount_max = 22.0
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

	## Whether the line from `a` to `b` runs through the thick of the cloud.
	func blocks(a: Vector3, b: Vector3) -> bool:
		if _age >= LIFETIME - 1.5:
			return false
		var closest := Geometry3D.get_closest_point_to_segment(global_position, a, b)
		return closest.distance_to(global_position) < RADIUS * 0.8

	## Whether any cloud stands between `a` and `b`: locks can't see through smoke.
	static func screens(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
		for cloud in tree.get_nodes_in_group("smoke"):
			if (cloud as SmokeCloud).blocks(a, b):
				return true
		return false
