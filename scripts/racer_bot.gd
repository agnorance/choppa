class_name RacerBot
extends Node
## AI pilot for races: flies through the next gate, boosts on straights, shoots whoever
## is in its sights.

var choppa: Choppa
var race: Race
var skill := 1.0  ## 0..1, scales top speed and how eagerly it boosts.

var rng := RandomNumberGenerator.new()

var _stuck := 0.0  ## Seconds spent barely moving while wanting to.
var _unstick := 0.0  ## Seconds left of backing up and climbing away from whatever we hit.


func _ready() -> void:
	process_physics_priority = -10


const MIN_ALTITUDE := 4.0


func _physics_process(delta: float) -> void:
	steer(delta)


func steer(delta := 1.0 / 60.0) -> void:
	var i := choppa.input
	i.clear()
	if race == null or race.is_done(choppa):
		Autopilot.fly(choppa, i, Vector3.ZERO, choppa.global_position + choppa.facing() * Vector3.FORWARD * 10.0)
		return
	var target := approach_point(race.next_gate(choppa))
	var to := target - choppa.global_position
	var local := choppa.facing().inverse() * to
	var angle := atan2(local.x, -local.z)  # Positive: target is to the right.
	var distance := Vector2(local.x, local.z).length()

	# Ease off for sharp turns so we don't overshoot the gate.
	var speed := clampf(1.0 - absf(angle) / 1.4, 0.15, 1.0) * lerpf(0.84, 0.9, skill) * choppa.max_speed
	# Lining up for a tight gate (a tunnel): slow down while off its line, as a pilot
	# would; at full speed the heavy model slides wide out of a turn into the rock.
	var gate := race.next_gate(choppa)
	if gate.radius < 6.0 and choppa.global_position.distance_to(gate.global_position) < 130.0:
		var off_line := (choppa.global_position - gate.global_position).slide(gate.global_basis.z.normalized()).length()
		speed *= clampf(1.0 - (off_line - gate.radius) / 15.0, 0.3, 1.0)
	# Never skim the ground: climb back to a few metres before anything else.
	if choppa.altitude < MIN_ALTITUDE:
		target.y = maxf(target.y, choppa.global_position.y + (MIN_ALTITUDE - choppa.altitude) * 2.0)
		to = target - choppa.global_position
	# Pinned against a wall or a tunnel mouth: back off upward for a moment, then try again.
	if choppa.velocity.length() < 3.0 and distance > 15.0:
		_stuck += delta
	else:
		_stuck = maxf(0.0, _stuck - delta)
	if _stuck > 1.2:
		_stuck = 0.0
		_unstick = 1.5
	if _unstick > 0.0:
		_unstick -= delta
		Autopilot.fly(choppa, i, (-to.normalized() + Vector3.UP).normalized() * 10.0, target)
		return
	Autopilot.fly(choppa, i, to.normalized() * speed, target)
	i.boost = absf(angle) < 0.12 and distance > 70.0 and choppa.boost_meter > lerpf(0.6, 0.25, skill)
	i.fire = choppa.aim_target() != null


## Where to aim for `gate`: a point in front of it on the side facing away from the
## gate after it, so we fly through already lined up for the next one. Close to the
## gate we aim straight at its center.
func approach_point(gate: RingGate) -> Vector3:
	var center := gate.global_position
	var distance := choppa.global_position.distance_to(center)
	if distance < 25.0:
		return center
	var axis := gate.global_basis.z
	var after := race.gates[(gate.index + 1) % race.gates.size()].global_position
	if axis.dot(after - center) < 0.0:
		axis = -axis
	return center - axis * clampf(distance * 0.5, 0.0, 50.0)
