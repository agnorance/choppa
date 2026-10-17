class_name NetGame
extends Node
## Internet multiplayer (docs/DESIGN.md, "Multiplayer"). One node, two roles:
##
## Server (dedicated, or a player hosting): owns the battle. Clients send their
## PilotInput every tick; the server applies one per tick to that pilot's choppa, runs
## the simulation, decides hits, damage, scores and stations, and sends each client a
## snapshot 30 times a second plus reliable events (kills, shots, services, round end).
##
## Client: predicts its own choppa by running Choppa.step on its own inputs, keeps the
## inputs it has not had acknowledged, and when a snapshot disagrees puts the choppa
## where the server has it and replays them. Everyone else is drawn INTERP_TICKS in
## the past, between two snapshots. Clients never decide damage (Choppa.authority).
##
## The node sits at the same path on both sides (RPCs are matched by path). `lag_ms` and
## `loss` simulate a bad connection on this side (outgoing and incoming).

signal welcomed(info: Dictionary)  ## Client: the server accepted us; build the world from `info`.
signal disconnected(reason: String)
signal peer_joined(pilot_name: String)
signal peer_left(pilot_name: String)
signal xp_received(stats: Dictionary)  ## Client: our battle stats, sent before the round ends.

const PORT := 7777
const SNAPSHOT_EVERY := 2  ## Ticks between snapshots: 30 per second at 60 Hz.
const INTERP_TICKS := 6  ## Others are drawn 100 ms behind the newest snapshot.
const CORRECT_ABOVE := 0.12  ## Prediction error (see NetCodec.error) worth a correction.
const MAX_QUEUE := 4  ## Server: inputs buffered per client before it catches up.
const ROUND_BREAK := 12.0  ## Server: seconds between a round's end and the next.
const PROTOCOL := 3  ## Raise whenever the wire format changes.

enum Role { NONE, SERVER, CLIENT }

var role := Role.NONE
var lag_ms := 0.0
var loss := 0.0  ## 0..1
var tick := 0

# Server
var battle: Battle
var pilots: Array[Choppa] = []
var stations: Array[ServiceStation] = []
var bots := {}  ## Choppa -> the bot flying it (removed when a player takes the seat).
var reserved: Array[Choppa] = []  ## Seats players cannot take (the host's own).
var welcome_info := {}  ## map, mode, kill limit; the roster is added per client.
## Server: makes a bot for a seat a player left: func(choppa) -> Node.
var bot_factory: Callable
var _peers := {}  ## peer id -> {choppa, queue: [[tick, PilotInput]], ack, name, stats}
var _round_break := -1.0

# Client
var own: Choppa
var own_index := -1
var _history := {}  ## tick -> PilotInput we applied
var _states := {}  ## tick -> our motion after that tick's step: [origin, rotation, velocity]
var _snapshots: Array = []  ## [server tick, {index: state}] newest last, for interpolation
var _server_tick := 0
var _server_tick_at := 0  ## our tick when _server_tick arrived
var _last_ack := -1
var _pending_events: Array = []
var corrections := 0  ## Client: how often the server disagreed with our prediction.
var _hello := {}

var _rng := RandomNumberGenerator.new()
var _delayed: Array = []  ## [due msec, Callable] for lag simulation


func _ready() -> void:
	process_physics_priority = -5  # After the pilots wrote their input, before the choppas step.
	_rng.seed = 99


# --- starting -----------------------------------------------------------------------

## Starts listening. Returns OK or an Error.
func host(port := PORT, max_clients := 7) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.SERVER
	multiplayer.peer_disconnected.connect(_on_peer_left)
	for c in pilots:
		c.fired.connect(_on_fired.bind(c))
		c.part_wrecked.connect(func(part: Choppa.Part, by: Choppa) -> void:
			_event_all(["wrecked", pilots.find(c), part, pilots.find(by)]))
	battle.kill.connect(func(killer: Choppa, victim: Choppa) -> void:
		_event_all(["kill", pilots.find(killer), pilots.find(victim)]))
	battle.match_over.connect(_on_match_over)
	for k in stations.size():
		stations[k].served.connect(func(c: Choppa) -> void: _event_all(["served", k, pilots.find(c)]))
	return OK


## Connects to a server; `hello` is {name, airframe, camo}. Listen for `welcomed`.
func join(address: String, port := PORT, hello := {}) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_hello = hello
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_closed)
	return OK


func _on_connected() -> void:
	_send(func() -> void: _hello_rpc.rpc_id(1, var_to_bytes(_hello.merged({"protocol": PROTOCOL}))))


func _on_connection_failed() -> void:
	disconnected.emit("Could not reach the server.")


func _on_server_closed() -> void:
	disconnected.emit("The server closed the connection.")


## Client: after building the world from `welcomed`, hand over the choppas in roster
## order (the same order on every machine) and the mirror battle and stations.
func attach(field: Array[Choppa], own_seat: int, mirror: Battle, station_list: Array[ServiceStation]) -> void:
	pilots = field
	own_index = own_seat
	own = pilots[own_seat]
	battle = mirror
	battle.authority = false
	stations = station_list
	for s in stations:
		s.authority = false
	for k in pilots.size():
		var c := pilots[k]
		c.authority = false
		if c != own:
			c.set_physics_process(false)
			c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for event in _pending_events:
		_handle_event(event)
	_pending_events.clear()


func stop() -> void:
	# The multiplayer object outlives this node (it belongs to the tree), so let go of it.
	for pair: Array in [[multiplayer.peer_disconnected, _on_peer_left],
			[multiplayer.connected_to_server, _on_connected],
			[multiplayer.connection_failed, _on_connection_failed],
			[multiplayer.server_disconnected, _on_server_closed]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_delayed.clear()  # Nothing left to send on a closed line.
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = Role.NONE


func _exit_tree() -> void:
	if role != Role.NONE:
		stop()


func players() -> PackedStringArray:
	var out := PackedStringArray()
	for id: int in _peers:
		out.append(_peers[id].name)
	return out


# --- the tick -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_flush_delayed()
	if role == Role.SERVER:
		_server_tick_step(delta)
	elif role == Role.CLIENT and own:
		_client_tick_step()
	tick += 1


func _server_tick_step(delta: float) -> void:
	if tick % SNAPSHOT_EVERY == 0:
		for id: int in _peers:
			var data := _snapshot_for(id)
			_send(func() -> void: _snapshot_rpc.rpc_id(id, data), false)
	for id: int in _peers:
		var p: Dictionary = _peers[id]
		var queue: Array = p.queue
		while queue.size() > MAX_QUEUE:
			queue.pop_front()
		if not queue.is_empty():
			var next: Array = queue.pop_front()
			(p.choppa as Choppa).input.copy_from(next[1])
			p.ack = next[0]
	if battle.over and _round_break >= 0.0:
		_round_break -= delta
		if _round_break <= 0.0:
			_round_break = -1.0
			battle.restart()
			_event_all(["restart"])


func _client_tick_step() -> void:
	# Our input for this tick (LocalPilot wrote it already), kept for replays, sent with
	# the few before it.
	_states[tick - 1] = [own.global_position, own.global_transform.basis.get_rotation_quaternion(), own.velocity]
	var mine := PilotInput.new()
	mine.copy_from(own.input)
	_history[tick] = mine
	var buf := StreamPeerBuffer.new()
	for k in range(NetCodec.INPUTS_PER_PACKET - 1, -1, -1):
		if _history.has(tick - k):
			NetCodec.write_input(buf, tick - k, _history[tick - k])
	var data := buf.data_array
	_send(func() -> void: _input_rpc.rpc_id(1, data), false)
	for old: int in _history.keys():
		if old < tick - 240:
			_history.erase(old)
			_states.erase(old)
	# Cosmetic guns for everyone else: they fire tracers when the server says they do.
	for c in pilots:
		if c != own and c.alive:
			c._update_gun(c.input, 1.0 / Engine.physics_ticks_per_second)


# --- server side --------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello_rpc(data: PackedByteArray) -> void:
	if role != Role.SERVER:
		return
	var id := multiplayer.get_remote_sender_id()
	var hello: Dictionary = bytes_to_var(data)
	if int(hello.get("protocol", 0)) != PROTOCOL:
		_send(func() -> void: _event_rpc.rpc_id(id, var_to_bytes(["refused", "Different game version."])))
		return
	var seat: Choppa = null
	for c in pilots:
		if bots.has(c) and not reserved.has(c) and not _taken(c):
			seat = c
			break
	if seat == null:
		_send(func() -> void: _event_rpc.rpc_id(id, var_to_bytes(["refused", "The server is full."])))
		return
	(bots[seat] as Node).queue_free()
	bots.erase(seat)
	seat.pilot_name = str(hello.get("name", "Pilot")).substr(0, 16)
	var airframe := str(hello.get("airframe", Airframe.SCOUT))
	if Airframe.TABLE.has(airframe):
		seat.set_airframe(airframe)
	var camo := str(hello.get("camo", "factory"))
	if Progression.CAMOS.has(camo) and Progression.CAMOS[camo].tier == "level":
		seat.model.set_camo(camo)  # Packs and Apex need a server-side entitlement check first.
		seat.camo = camo
	var stats := MatchStats.new()
	stats.pilot = seat
	stats.battle = battle
	add_child(stats)
	_peers[id] = {"choppa": seat, "queue": [], "ack": -1, "name": seat.pilot_name, "stats": stats}
	var info := welcome_info.duplicate()
	info["seat"] = pilots.find(seat)
	info["over"] = battle.over
	info["roster"] = _roster()
	_send(func() -> void: _welcome_rpc.rpc_id(id, var_to_bytes(info)))
	_event_all(["roster", _roster()], id)
	peer_joined.emit(seat.pilot_name)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _input_rpc(data: PackedByteArray) -> void:
	if role != Role.SERVER:
		return
	var p: Dictionary = _peers.get(multiplayer.get_remote_sender_id(), {})
	if p.is_empty():
		return
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var queue: Array = p.queue
	var newest: int = queue.back()[0] if not queue.is_empty() else p.ack
	while buf.get_position() + NetCodec.INPUT_BYTES <= data.size():
		var i := PilotInput.new()
		var t := NetCodec.read_input(buf, i)
		if t > newest:
			queue.append([t, i])
			newest = t


func _taken(c: Choppa) -> bool:
	for id: int in _peers:
		if _peers[id].choppa == c:
			return true
	return false


func _on_peer_left(id: int) -> void:
	if not _peers.has(id):
		return
	var p: Dictionary = _peers[id]
	_peers.erase(id)
	(p.stats as Node).queue_free()
	var c: Choppa = p.choppa
	c.input.clear()
	c.pilot_name = "Bot " + p.name
	if bot_factory.is_valid():
		bots[c] = bot_factory.call(c)  # A bot takes the seat back.
	_event_all(["roster", _roster()])
	peer_left.emit(p.name)



func _on_fired(weapon: String, c: Choppa) -> void:
	var dir := -c.global_transform.basis.z
	var target := -1
	if weapon == "missiles":
		target = pilots.find(c.missile_target())
	_event_all(["fired", pilots.find(c), weapon, c.global_position, dir, target, c._rocket_side])


func _on_match_over() -> void:
	for id: int in _peers:
		var stats: Dictionary = (_peers[id].stats as MatchStats).result()
		_send(func() -> void: _event_rpc.rpc_id(id, var_to_bytes(["xp", stats])))
	_event_all(["over"])
	_round_break = ROUND_BREAK


func _roster() -> Array:
	var out := []
	for c in pilots:
		out.append({"name": c.pilot_name, "color": c.team_color, "airframe": c.airframe, "camo": c.camo})
	return out


func _snapshot_for(id: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(tick)
	buf.put_32(_peers[id].ack)
	buf.put_float(battle.time_left)
	buf.put_u8(1 if battle.over else 0)
	buf.put_u8(pilots.size())
	for c in pilots:
		buf.put_u8(battle.kills_of(c))
		buf.put_u8(battle.deaths_of(c))
		buf.put_float(battle.respawn_in(c))
		NetCodec.write_choppa(buf, c)
	buf.put_u8(stations.size())
	for s in stations:
		buf.put_float(s.cooldown)
		buf.put_8(pilots.find(s.occupant))
		buf.put_float(s.progress())
	return buf.data_array


func _event_all(event: Array, except := -1) -> void:
	var data := var_to_bytes(event)
	for id: int in _peers:
		if id != except:
			_send(func() -> void: _event_rpc.rpc_id(id, data))


# --- client side --------------------------------------------------------------------

@rpc("authority", "reliable")
func _welcome_rpc(data: PackedByteArray) -> void:
	_receive(func() -> void: welcomed.emit(bytes_to_var(data)))


@rpc("authority", "unreliable_ordered", "call_remote", 2)
func _snapshot_rpc(data: PackedByteArray) -> void:
	_receive(_on_snapshot.bind(data))


@rpc("authority", "reliable")
func _event_rpc(data: PackedByteArray) -> void:
	_receive(func() -> void:
		var event: Array = bytes_to_var(data)
		if own == null and event[0] != "refused":
			_pending_events.append(event)
		else:
			_handle_event(event))


func _on_snapshot(data: PackedByteArray) -> void:
	if own == null:
		return
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var server_tick := buf.get_u32()
	if server_tick <= _server_tick and _server_tick > 0:
		return  # Out of order.
	_server_tick = server_tick
	_server_tick_at = tick
	var ack := buf.get_32()
	battle.time_left = buf.get_float()
	buf.get_u8()  # Round over. Ignored: the reliable "over" event says so, after our XP.
	var count := buf.get_u8()
	var states := {}
	for k in count:
		var kills := buf.get_u8()
		var deaths := buf.get_u8()
		var respawn_left := buf.get_float()
		var s := NetCodec.read_choppa(buf)
		states[k] = s
		if k < pilots.size():
			battle.net_score(pilots[k], kills, deaths, respawn_left)
	var station_count := buf.get_u8()
	for k in station_count:
		var cooldown := buf.get_float()
		var who := buf.get_8()
		var done := buf.get_float()
		if k < stations.size():
			stations[k].net_state(cooldown, pilots[who] if who >= 0 and who < pilots.size() else null, done)
	_snapshots.append([server_tick, states])
	while _snapshots.size() > 30:
		_snapshots.pop_front()
	for k: int in states:
		if k >= pilots.size():
			continue
		var c := pilots[k]
		var s: Dictionary = states[k]
		NetCodec.apply_status(c, s)
		_life(c, s)
		if c != own:
			c.input.fire = s.fire
			c.input.boost = s.boost
	_reconcile(ack, states.get(own_index, {}))


## Puts our choppa where the server had it after input `ack`, then replays the inputs
## the server has not seen yet.
func _reconcile(ack: int, s: Dictionary) -> void:
	if s.is_empty() or ack < 0 or ack <= _last_ack or not own.alive:
		return
	_last_ack = ack
	var predicted: Array = _states.get(ack, [])
	if not predicted.is_empty():
		var off: float = (predicted[0] as Vector3).distance_to(s.origin) \
			+ (predicted[2] as Vector3).distance_to(s.velocity) * 0.2 \
			+ (predicted[1] as Quaternion).angle_to(s.rotation) * 2.0
		if off < CORRECT_ABOVE:
			return  # We predicted that tick right; the ticks after it stand.
	corrections += 1
	var now := PilotInput.new()
	now.copy_from(own.input)
	var before := own.global_transform
	NetCodec.apply_motion(own, s)
	own.replaying = true
	for t in range(ack + 1, tick):
		if _history.has(t):
			own.input.copy_from(_history[t])
			own.step(1.0 / Engine.physics_ticks_per_second)
	own.replaying = false
	own.input.copy_from(now)
	if before.origin.distance_to(own.global_position) > 4.0:
		own.reset_physics_interpolation()  # A big correction: snap rather than glide.


func _life(c: Choppa, s: Dictionary) -> void:
	if c.alive and not s.alive:
		c.net_wreck()
	elif not c.alive and s.alive:
		c.respawn(Transform3D(Basis(s.rotation), s.origin))


func _process(_delta: float) -> void:
	if role != Role.CLIENT or own == null or _snapshots.size() < 2:
		return
	# Everyone but us, drawn between the two snapshots around (server now - INTERP_TICKS).
	var render := float(_server_tick + (tick - _server_tick_at)) - INTERP_TICKS \
		+ Engine.get_physics_interpolation_fraction()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[-1]
	for k in range(_snapshots.size() - 1):
		if _snapshots[k][0] <= render and _snapshots[k + 1][0] >= render:
			a = _snapshots[k]
			b = _snapshots[k + 1]
			break
	var span := float(b[0] - a[0])
	var t := clampf((render - a[0]) / span, 0.0, 1.0) if span > 0.0 else 1.0
	for k in pilots.size():
		var c := pilots[k]
		if c == own or not a[1].has(k) or not b[1].has(k) or not c.alive:
			continue
		var sa: Dictionary = a[1][k]
		var sb: Dictionary = b[1][k]
		c.global_transform = Transform3D(Basis((sa.rotation as Quaternion).slerp(sb.rotation, t)),
			(sa.origin as Vector3).lerp(sb.origin, t))
		c.velocity = (sa.velocity as Vector3).lerp(sb.velocity, t)
		c.rates = sb.rates
		c.heading = lerp_angle(sa.heading, sb.heading, t)
		c.clock += _delta
		c.model.update_pose(c, _delta)


func _handle_event(event: Array) -> void:
	match event[0]:
		"refused":
			disconnected.emit(event[1])
		"kill":
			battle.kill.emit(_pilot(event[1]), _pilot(event[2]))
		"wrecked":
			var target := _pilot(event[1])
			var by := _pilot(event[3])
			if target:
				target.part_wrecked.emit(event[2], by)
				if by and by != target:
					by.wrecked_part.emit(target, event[2])
		"served":
			var c := _pilot(event[2])
			if event[1] < stations.size() and c:
				stations[event[1]].served.emit(c)
				c.restocked.emit()
		"fired":
			_show_fire(event)
		"roster":
			_apply_roster(event[1])
		"xp":
			xp_received.emit(event[1])
		"over":
			battle.net_end()
		"restart":
			battle.restart()
			_last_ack = -1


func _pilot(k: int) -> Choppa:
	return pilots[k] if k >= 0 and k < pilots.size() else null


func _apply_roster(roster: Array) -> void:
	for k in mini(roster.size(), pilots.size()):
		var c := pilots[k]
		var r: Dictionary = roster[k]
		c.pilot_name = r.name
		if c.airframe != r.airframe:
			c.set_airframe(r.airframe)
		if c.camo != r.camo:
			c.camo = r.camo
			c.model.set_camo(r.camo)


## Another pilot fired a rocket, missile, flares, a mine or smoke: show it here. (Our
## own were predicted already.) These copies cannot hurt anyone: damage is the server's.
func _show_fire(event: Array) -> void:
	var c := _pilot(event[1])
	if c == null or c == own:
		return
	var weapon: String = event[2]
	var at: Vector3 = event[3]
	var dir: Vector3 = event[4]
	match weapon:
		"rockets":
			var rocket := Weapons.Rocket.new()
			rocket.shooter = c
			rocket.direction = dir
			c.get_parent().add_child(rocket)
			rocket.global_position = at + c.global_transform.basis * Vector3(1.45 * -float(event[6]), -0.9, -1.4)
		"missiles":
			var missile := Weapons.Missile.new()
			missile.shooter = c
			missile.target = _pilot(event[5])
			missile.direction = dir
			c.get_parent().add_child(missile)
			missile.global_position = at + c.global_transform.basis * Vector3(0.0, -0.6, -3.0)
		"flares":
			var flares := Weapons.Flares.new()
			flares.carrier = c
			c.get_parent().add_child(flares)
			flares.global_position = at + c.facing() * Vector3(0.0, -0.8, 1.5)
		"mines":
			var mine := Weapons.Mine.new()
			mine.owner_choppa = c
			c.get_parent().add_child(mine)
			mine.global_position = at + c.facing() * Vector3(0.0, -1.0, 9.0)
		"smoke":
			var cloud := Weapons.SmokeCloud.new()
			c.get_parent().add_child(cloud)
			cloud.global_position = at + c.facing() * Vector3(0.0, 0.0, 10.0)


# --- a bad connection, on purpose ----------------------------------------------------

## Sends now, or later and maybe not at all when simulating a bad line. Only
## unreliable messages can be lost (ENet re-sends reliable ones on a real line).
## Delays count ticks, so a test at --fixed-fps sees the same lag as a real game.
func _send(call: Callable, reliable := true) -> void:
	if lag_ms <= 0.0 and loss <= 0.0:
		call.call()
		return
	if not reliable and loss > 0.0 and _rng.randf() < loss:
		return
	var jitter := _rng.randf_range(0.8, 1.2) if not reliable else 1.0
	_delayed.append([tick + _lag_ticks(0.5 * jitter), call])


func _receive(handle: Callable) -> void:
	if lag_ms <= 0.0:
		handle.call()
		return
	_delayed.append([tick + _lag_ticks(0.5), handle])


func _lag_ticks(share: float) -> int:
	return roundi(lag_ms * share / 1000.0 * Engine.physics_ticks_per_second)


func _flush_delayed() -> void:
	if _delayed.is_empty():
		return
	var keep := []
	for entry: Array in _delayed:
		if entry[0] <= tick:
			(entry[1] as Callable).call()
		else:
			keep.append(entry)
	_delayed = keep
