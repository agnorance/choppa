class_name Race
extends Node
## Runs a checkpoint race: countdown, gate order, laps, placings and results.
## Gates must be passed in order; gate 0 is start/finish. Racers start behind gate 0,
## so flying through it the first time starts lap 1.

signal countdown_changed(seconds_left: int)  ## 3, 2, 1, then 0 for GO.
signal lap_started(choppa: Choppa, lap: int)
signal racer_finished(choppa: Choppa, place: int, time: float)
signal race_over

const COUNTDOWN := 3.0
## After the first finisher, the others get this long before the race ends anyway.
const FINISH_GRACE := 30.0

var laps := 3
var gates: Array[RingGate] = []
var racers: Array[Choppa] = []
var time := 0.0
var countdown := COUNTDOWN
var running := false
var over := false
var results: Array[Dictionary] = []  ## [{choppa, time}] in finishing order.

var _progress := {}  ## Choppa -> {lap: int, next: int, done: bool}
var _grace := -1.0


func setup(course: Array[RingGate], field: Array[Choppa], lap_count := 3) -> void:
	gates = course
	racers = field
	laps = lap_count
	for choppa in racers:
		_progress[choppa] = {"lap": 0, "next": 0, "done": false}
		choppa.locked = true
		choppa.mortal = false
	for gate in gates:
		gate.passed.connect(_on_gate_passed.bind(gate))


## Whole laps started so far, clamped to 1..laps for display.
func lap_of(choppa: Choppa) -> int:
	return clampi(_progress[choppa].lap, 1, laps)


func next_gate(choppa: Choppa) -> RingGate:
	return gates[_progress[choppa].next]


func is_done(choppa: Choppa) -> bool:
	return _progress[choppa].done


## Where to put a racer who respawns: at the last gate they passed, facing the next.
func respawn_point(choppa: Choppa) -> Transform3D:
	var p: Dictionary = _progress[choppa]
	var next := gates[p.next].global_position
	var last := gates[(p.next - 1 + gates.size()) % gates.size()].global_position
	if p.lap == 0:
		last = next + Vector3(0.0, 0.0, 30.0)
	var flat := Vector3(next.x - last.x, 0.0, next.z - last.z)
	var yaw := atan2(-flat.x, -flat.z)
	return Transform3D(Basis(Vector3.UP, yaw), last)


## Racers sorted by race position, leader first.
func standings() -> Array[Choppa]:
	var order := racers.duplicate()
	order.sort_custom(func(a: Choppa, b: Choppa) -> bool: return _ahead(a, b))
	return order


func place_of(choppa: Choppa) -> int:
	return standings().find(choppa) + 1


## Advances the race clock. Called every physics tick.
func tick(delta: float) -> void:
	if over:
		return
	if not running:
		var before := ceili(countdown)
		countdown -= delta
		if ceili(countdown) != before:
			countdown_changed.emit(maxi(ceili(countdown), 0))
		if countdown <= 0.0:
			running = true
			for choppa in racers:
				choppa.locked = false
		return
	time += delta
	var order := standings()
	for n in order.size():
		order[n].standing = float(n) / maxi(1, order.size() - 1)
	if _grace >= 0.0:
		_grace -= delta
		if _grace <= 0.0:
			_end()


func _physics_process(delta: float) -> void:
	tick(delta)


func _on_gate_passed(choppa: Choppa, gate: RingGate) -> void:
	if not running or over or not _progress.has(choppa):
		return
	var p: Dictionary = _progress[choppa]
	if p.done or gate.index != p.next:
		return
	p.next = (p.next + 1) % gates.size()
	if gate.index != 0:
		return
	p.lap += 1
	if p.lap <= laps:
		lap_started.emit(choppa, p.lap)
		return
	p.done = true
	results.append({"choppa": choppa, "time": time})
	racer_finished.emit(choppa, results.size(), time)
	if results.size() == racers.size():
		_end()
	elif _grace < 0.0:
		_grace = FINISH_GRACE


func _end() -> void:
	over = true
	running = false
	race_over.emit()


## Checkpoints passed so far, counting the start line as the first one.
func _checkpoints(choppa: Choppa) -> int:
	var p: Dictionary = _progress[choppa]
	if p.lap == 0:
		return 0
	var into_lap: int = gates.size() if p.next == 0 else p.next
	return (p.lap - 1) * gates.size() + into_lap


func _ahead(a: Choppa, b: Choppa) -> bool:
	var pa: Dictionary = _progress[a]
	var pb: Dictionary = _progress[b]
	if pa.done or pb.done:
		if pa.done and pb.done:
			return _finish_index(a) < _finish_index(b)
		return pa.done
	var ca := _checkpoints(a)
	var cb := _checkpoints(b)
	if ca != cb:
		return ca > cb
	var da := a.global_position.distance_squared_to(next_gate(a).global_position)
	var db := b.global_position.distance_squared_to(next_gate(b).global_position)
	return da < db


func _finish_index(choppa: Choppa) -> int:
	for n in results.size():
		if results[n].choppa == choppa:
			return n
	return results.size()
