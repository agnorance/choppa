class_name Autopilot
extends RefCounted
## Turns "fly toward that velocity, look at that point" into stick, collective and
## pedals, for bots, training dummies and scripted flights. A plain proportional
## controller: the wanted acceleration picks a tilt, the tilt error picks the rates,
## the vertical part picks the collective with the tilt compensated.

const MAX_TILT := 0.65  ## rad, about 37 degrees of nose-down or bank.
const ACCEL_GAIN := 1.8  ## Wanted acceleration per m/s of velocity error.
const MAX_ACCEL := 9.0
const TILT_GAIN := 2.8  ## Stick per radian of tilt error. Softer gains let the race bots drift into tunnel walls.
const RATE_DAMPING := 0.25  ## Stick against the current rotation rate.


static func fly(c: Choppa, i: PilotInput, want_velocity: Vector3, look_at: Vector3) -> void:
	var yaw_local := c.facing().inverse() * (look_at - c.global_position)
	if c.easy:
		# Drone controls: a move stick in the yaw frame, collective as climb rate.
		var local_want := c.facing().inverse() * want_velocity
		i.move = (Vector2(local_want.x, -local_want.z) / c.max_speed).limit_length(1.0)
		i.collective = clampf(want_velocity.y / c.climb_speed, -1.0, 1.0)
		i.yaw = clampf(atan2(yaw_local.x, -yaw_local.z) * 2.5, -1.0, 1.0)
		i.cyclic.y = clampf(-c._aim * 3.0, -1.0, 1.0)  # Keep the nose level.
		return
	var want_accel := ((want_velocity - c.velocity) * ACCEL_GAIN).limit_length(MAX_ACCEL)
	var yaw_frame := c.facing()
	var local := yaw_frame.inverse() * want_accel
	# A level rotor pushes up; tipping it nose-down by a radians pushes forward by
	# about thrust * a. Forward is -Z in the yaw frame.
	var want_pitch := clampf(-local.z / c.hover_thrust, -MAX_TILT, MAX_TILT)
	var want_roll := clampf(local.x / c.hover_thrust, -MAX_TILT, MAX_TILT)
	i.cyclic.y = clampf((want_pitch - c.nose_down()) * TILT_GAIN + c.rates.x * RATE_DAMPING, -1.0, 1.0)
	i.cyclic.x = clampf((want_roll - c.bank_right()) * TILT_GAIN + c.rates.z * RATE_DAMPING, -1.0, 1.0)

	var up := clampf(c.global_transform.basis.y.y, 0.35, 1.0)
	var want_thrust := (Choppa.GRAVITY + want_accel.y) / up
	i.collective = clampf((want_thrust / c.hover_thrust - 1.0) / c.collective_range, -1.0, 1.0)

	var local_look := yaw_frame.inverse() * (look_at - c.global_position)
	var angle := atan2(local_look.x, -local_look.z)  # Positive: the look point is to the right.
	i.yaw = clampf(angle * 2.5 - c.rates.y * 0.2, -1.0, 1.0)
