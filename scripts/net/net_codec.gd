class_name NetCodec
extends RefCounted
## What goes over the wire, packed tight: pilot inputs (client to server, every tick)
## and snapshots (server to client, 30 per second). Everything else (hello, welcome,
## events) is small and rare and uses var_to_bytes.

const INPUT_BYTES := 4 + 6 * 4 + 1
const INPUTS_PER_PACKET := 4  ## Each input packet repeats the last few, so a lost one costs nothing.

const _FLAGS := ["boost", "fire", "rockets", "missile", "flares", "mine", "smoke", "engine"]


static func write_input(buf: StreamPeerBuffer, tick: int, i: PilotInput) -> void:
	buf.put_u32(tick)
	for v: float in [i.cyclic.x, i.cyclic.y, i.move.x, i.move.y, i.yaw, i.collective]:
		buf.put_float(v)
	var flags := 0
	for k in _FLAGS.size():
		if i.get(_FLAGS[k]):
			flags |= 1 << k
	buf.put_u8(flags)


static func read_input(buf: StreamPeerBuffer, into: PilotInput) -> int:
	var tick := buf.get_u32()
	into.cyclic = Vector2(buf.get_float(), buf.get_float())
	into.move = Vector2(buf.get_float(), buf.get_float())
	into.yaw = buf.get_float()
	into.collective = buf.get_float()
	var flags := buf.get_u8()
	for k in _FLAGS.size():
		into.set(_FLAGS[k], flags & (1 << k) != 0)
	return tick


## A choppa's full simulation state: enough for a client to put its own predicted
## choppa back where the server has it, and to draw everyone else.
static func write_choppa(buf: StreamPeerBuffer, c: Choppa) -> void:
	var t := c.global_transform
	var q := t.basis.get_rotation_quaternion()
	for v: float in [t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w,
			c.velocity.x, c.velocity.y, c.velocity.z, c.rates.x, c.rates.y, c.rates.z,
			c.heading, c.turn_rate, c._thrust, c._aim, c.boost_meter, c.stun, c.heat, c._gun_timer,
			c.decoy_time, c.invulnerable, c.health,
			c.parts[Choppa.Part.ROTOR], c.parts[Choppa.Part.TAIL], c.parts[Choppa.Part.ENGINE], c.spool]:
		buf.put_float(v)
	buf.put_u16(c.ammo.gun)
	for weapon: String in ["rockets", "missiles", "flares", "mines", "smoke"]:
		buf.put_u8(c.ammo[weapon])
	var flags := (1 if c.alive else 0) | (2 if c.overheated else 0) | (4 if c.input.fire else 0) \
		| (8 if c.input.boost else 0) | (16 if c.locked else 0) | (32 if c.engine_on else 0)
	buf.put_u8(flags)


static func read_choppa(buf: StreamPeerBuffer) -> Dictionary:
	var f := []
	for k in 28:
		f.append(buf.get_float())
	var ammo := {"gun": buf.get_u16()}
	for weapon: String in ["rockets", "missiles", "flares", "mines", "smoke"]:
		ammo[weapon] = buf.get_u8()
	var flags := buf.get_u8()
	return {
		"origin": Vector3(f[0], f[1], f[2]), "rotation": Quaternion(f[3], f[4], f[5], f[6]),
		"velocity": Vector3(f[7], f[8], f[9]), "rates": Vector3(f[10], f[11], f[12]),
		"heading": f[13], "turn_rate": f[14], "thrust": f[15], "aim": f[16], "boost_meter": f[17],
		"stun": f[18], "heat": f[19], "gun_timer": f[20], "decoy": f[21], "invulnerable": f[22],
		"health": f[23], "parts": [f[24], f[25], f[26]], "spool": f[27], "ammo": ammo,
		"alive": flags & 1 != 0, "overheated": flags & 2 != 0, "fire": flags & 4 != 0,
		"boost": flags & 8 != 0, "locked": flags & 16 != 0, "engine_on": flags & 32 != 0,
	}


## Puts the simulation part of a snapshot state onto a choppa (prediction correction).
static func apply_motion(c: Choppa, s: Dictionary) -> void:
	c.global_transform = Transform3D(Basis(s.rotation), s.origin)
	c.velocity = s.velocity
	c.rates = s.rates
	c.heading = s.heading
	c.turn_rate = s.turn_rate
	c._thrust = s.thrust
	c._aim = s.aim
	c.boost_meter = s.boost_meter
	c.stun = s.stun
	c.spool = s.spool
	c.engine_on = s.engine_on


## The server-owned numbers: health, parts, ammo, heat, shields.
static func apply_status(c: Choppa, s: Dictionary) -> void:
	c.health = s.health
	c.parts[Choppa.Part.ROTOR] = s.parts[0]
	c.parts[Choppa.Part.TAIL] = s.parts[1]
	c.parts[Choppa.Part.ENGINE] = s.parts[2]
	c.ammo = s.ammo
	c.heat = s.heat
	c.overheated = s.overheated
	c.decoy_time = s.decoy
	c.invulnerable = s.invulnerable
	c.locked = s.locked


## How far a predicted state is from the server's (metres plus m/s), to decide on a
## correction.
static func error(c: Choppa, s: Dictionary) -> float:
	return c.global_position.distance_to(s.origin) + c.velocity.distance_to(s.velocity) * 0.2 \
		+ c.global_transform.basis.get_rotation_quaternion().angle_to(s.rotation) * 2.0
