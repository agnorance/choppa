class_name Hazards
extends RefCounted
## Arena hazards: power lines strung between pylons, and wind zones that push choppas.
## Both run on their own (physics process) and only read and nudge choppas.


## Cables strung from one pylon to the next, three side by side. Thin and dark, so they
## are hard to see against the sky. A rotor that touches one is chewed up; the body is
## thrown back and takes damage.
class PowerLine extends Node3D:
	const SAG := 0.06  ## Sag in the middle as a fraction of the span.
	const RADIUS := 0.06  ## Drawn radius; the hit test is generous (see HIT_DISTANCE).
	const BODY_REACH := 1.2  ## A cable this close to the body line (nose to tail) touches it.
	const ROTOR_REACH := 1.0  ## Or this close to a point on the rotor disc.
	const DAMAGE := 25.0
	const ROTOR_DAMAGE := 60.0

	var points: Array[Vector3] = []  ## Cable attachment points, from one pylon to the next.
	var _cables: Array[PackedVector3Array] = []  ## World-space polylines.
	var _cooldown := {}  ## Choppa -> seconds before it can be hurt again.

	func _ready() -> void:
		add_to_group("power_lines")
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.08, 0.08, 0.08)
		material.metallic = 0.6
		material.roughness = 0.5
		for k in range(0, points.size(), 2):
			if k + 1 >= points.size():
				break
			var from := points[k]
			var to := points[k + 1]
			var line := PackedVector3Array()
			var span := from.distance_to(to)
			for s in 25:
				var t := s / 24.0
				var p := from.lerp(to, t)
				p.y -= span * SAG * 4.0 * t * (1.0 - t)
				line.append(p)
			_cables.append(line)
			_draw(line, material)

	## The closest point on any cable to `point`.
	func nearest(point: Vector3) -> Vector3:
		var best := Vector3.INF
		for line in _cables:
			for k in line.size() - 1:
				var p := Geometry3D.get_closest_point_to_segment(point, line[k], line[k + 1])
				if best == Vector3.INF or p.distance_to(point) < best.distance_to(point):
					best = p
		return best

	## Every choppa near a cable is hurt; the rotor (above the body) is wrecked.
	func _physics_process(delta: float) -> void:
		for who in _cooldown.keys():
			_cooldown[who] -= delta
			if _cooldown[who] <= 0.0:
				_cooldown.erase(who)
		for node in get_tree().get_nodes_in_group("choppas"):
			var c := node as Choppa
			if not c.alive or _cooldown.has(c):
				continue
			var hit := _touch(c)
			if hit == Vector3.INF:
				continue
			_cooldown[c] = 1.0
			var local := c.to_local(hit)
			var push := (c.global_position - hit)
			push = push.normalized() if push.length() > 0.01 else Vector3.UP
			c.velocity = c.velocity * 0.3 + push * 8.0
			if local.y > 0.9:
				c.damage_part(Choppa.Part.ROTOR, ROTOR_DAMAGE)
			c.cause = "power line"
			c.damage(DAMAGE, null)
			var sparks := Effects.Impact.new()
			sparks.kind = Effects.Impact.Kind.METAL
			sparks.normal = push
			get_parent().add_child(sparks)
			sparks.global_position = hit
			c.bumped.emit(10.0)
			Sounds.play_at(get_parent(), "cable_strike", hit, 0.0, randf_range(0.9, 1.1), 1.2)

	## The point on a cable the choppa touches, or Vector3.INF. Tests the body and the
	## rotor disc (a ring of points around the mast).
	func _touch(c: Choppa) -> Vector3:
		var b := c.global_transform.basis
		var scale: float = Airframe.spec(c.airframe).size
		# The body as points from the nose to the tail rotor, the rotor as a ring of points.
		var body: Array[Vector3] = []
		for z: float in [-2.4, -1.0, 0.5, 2.0, 3.5, 4.5]:
			body.append(c.global_position + b * Vector3(0.0, 0.0, z * scale))
		var rotor: Array[Vector3] = []
		var mast := c.global_position + b.y * 1.9 * scale
		for k in 12:
			var a := TAU * k / 12.0
			rotor.append(mast + b * Vector3(cos(a), 0.0, sin(a)) * 4.3 * scale)
		for line in _cables:
			for k in line.size() - 1:
				for probe: Array in [[rotor, ROTOR_REACH], [body, BODY_REACH * scale]]:
					for p: Vector3 in probe[0]:
						var closest := Geometry3D.get_closest_point_to_segment(p, line[k], line[k + 1])
						if closest.distance_to(p) < probe[1]:
							return closest
		return Vector3.INF

	func _draw(line: PackedVector3Array, material: Material) -> void:
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var piece := CylinderMesh.new()
			piece.top_radius = RADIUS
			piece.bottom_radius = RADIUS
			piece.height = a.distance_to(b)
			piece.radial_segments = 5
			piece.rings = 1
			var mi := MeshInstance3D.new()
			mi.mesh = piece
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.global_position = (a + b) * 0.5
			var dir := (b - a).normalized()
			mi.global_basis = Basis(Quaternion(Vector3.UP, dir))


## Strings power lines between pylons standing at `bases` (ground positions). Each pylon
## has three cable points on its cross arm. Returns the line.
static func power_line(parent: Node3D, bases: Array[Vector3]) -> PowerLine:
	var line := PowerLine.new()
	var arms := [Vector3(-4.5, 26.0, 0.0), Vector3(0.0, 26.0, 0.0), Vector3(4.5, 26.0, 0.0)]
	for k in bases.size():
		var yaw := 0.0
		var ahead := bases[mini(k + 1, bases.size() - 1)] - bases[maxi(k - 1, 0)]
		if Vector2(ahead.x, ahead.z).length() > 0.1:
			yaw = atan2(ahead.x, ahead.z) + PI * 0.5
		if Props.place(parent, "pylon", bases[k], yaw) == null:
			MapKit.pillar(parent, bases[k], 1.2, 26.0)
	for k in bases.size() - 1:
		var yaw_a := atan2((bases[k + 1] - bases[k]).x, (bases[k + 1] - bases[k]).z) + PI * 0.5
		for arm: Vector3 in arms:
			line.points.append(bases[k] + Basis(Vector3.UP, yaw_a) * arm)
			line.points.append(bases[k + 1] + Basis(Vector3.UP, yaw_a) * arm)
	parent.add_child(line)
	return line


## A box of moving air: choppas inside are pushed by `wind` (m/s^2 at the centre),
## gusting, and dust blows through it so you can see it.
class WindZone extends Area3D:
	var size := Vector3(40.0, 40.0, 40.0)
	var wind := Vector3(6.0, 0.0, 0.0)
	var _time := 0.0
	var _dust: CPUParticles3D

	func _ready() -> void:
		add_to_group("wind")
		monitoring = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(shape)
		_start.call_deferred()

	func _start() -> void:
		_dust = Effects.puffs(Effects.gradient([
			Color(0.82, 0.72, 0.58, 0.0), Color(0.82, 0.72, 0.58, 0.35), Color(0.8, 0.7, 0.56, 0.0),
		]), 40, 3.0)
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_dust.emission_box_extents = size * Vector3(0.5, 0.35, 0.5)
		_dust.direction = wind.normalized()
		_dust.spread = 12.0
		_dust.initial_velocity_min = wind.length() * 1.5
		_dust.initial_velocity_max = wind.length() * 2.5
		_dust.scale_amount_min = 2.0
		_dust.scale_amount_max = 5.0
		add_child(_dust)
		_dust.emitting = true
		var howl := Sounds.loop_on(self, "wind_loop", -6.0, 2.0)
		howl.max_distance = maxf(size.x, size.z) * 1.5

	## The push on a body at `at` right now: strongest in the middle, gusting.
	func force_at(at: Vector3) -> Vector3:
		var local := (at - global_position) / (size * 0.5)
		if absf(local.x) > 1.0 or absf(local.y) > 1.0 or absf(local.z) > 1.0:
			return Vector3.ZERO
		var falloff := (1.0 - absf(local.x) * 0.5) * (1.0 - absf(local.z) * 0.5)
		var gust := 0.7 + 0.5 * sin(_time * 1.3) + 0.2 * sin(_time * 3.7)
		return wind * falloff * gust

	func _physics_process(delta: float) -> void:
		_time += delta
		for node in get_tree().get_nodes_in_group("choppas"):
			var c := node as Choppa
			if c.alive:
				c.velocity += force_at(c.global_position) * delta


static func wind(parent: Node3D, center: Vector3, size: Vector3, push: Vector3) -> WindZone:
	var zone := WindZone.new()
	zone.size = size
	zone.wind = push
	zone.position = center
	parent.add_child(zone)
	return zone
