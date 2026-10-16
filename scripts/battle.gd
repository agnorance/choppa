class_name Battle
extends Node
## Free-for-all deathmatch: shoot each other down, respawn after a moment, first to the
## kill limit wins, or whoever leads when time runs out.

signal kill(killer: Choppa, victim: Choppa)  ## killer is null for a plain crash.
signal respawned(choppa: Choppa)
signal match_over
signal restarted  ## A new round began (restart()).

const RESPAWN_DELAY := 3.0

var kill_limit := 8
var time_limit := 300.0
var time_left := 300.0
var pilots: Array[Choppa] = []
var spawn_points: Array[Transform3D] = []
var over := false
## False on a network client: scores, respawns and the clock come from the server.
var authority := true

var _score := {}  ## Choppa -> {kills: int, deaths: int}
var _respawn := {}  ## Choppa -> seconds until respawn


func setup(field: Array[Choppa], spawns: Array[Transform3D], kills := 10, seconds := 300.0) -> void:
	pilots = field
	spawn_points = spawns
	kill_limit = kills
	time_limit = seconds
	time_left = seconds
	for choppa in pilots:
		_score[choppa] = {"kills": 0, "deaths": 0}
		choppa.died.connect(_on_died.bind(choppa))


func kills_of(choppa: Choppa) -> int:
	return _score[choppa].kills


func deaths_of(choppa: Choppa) -> int:
	return _score[choppa].deaths


## Seconds until `choppa` respawns, or 0 if it is alive.
func respawn_in(choppa: Choppa) -> float:
	return _respawn.get(choppa, 0.0)


## Pilots sorted by kills (then fewest deaths), leader first.
func standings() -> Array[Choppa]:
	var order := pilots.duplicate()
	order.sort_custom(func(a: Choppa, b: Choppa) -> bool:
		if kills_of(a) != kills_of(b):
			return kills_of(a) > kills_of(b)
		return deaths_of(a) < deaths_of(b))
	return order


## The spawn point farthest from every living opponent of `choppa`.
func best_spawn(choppa: Choppa) -> Transform3D:
	var best := spawn_points[0]
	var best_distance := -1.0
	for spawn in spawn_points:
		var nearest := INF
		for other in pilots:
			if other != choppa and other.alive:
				nearest = minf(nearest, spawn.origin.distance_to(other.global_position))
		if nearest > best_distance:
			best_distance = nearest
			best = spawn
	return best


func tick(delta: float) -> void:
	if over or not authority:
		return
	time_left -= delta
	for choppa: Choppa in _respawn.keys():
		_respawn[choppa] -= delta
		if _respawn[choppa] <= 0.0:
			_respawn.erase(choppa)
			choppa.respawn(best_spawn(choppa))
			respawned.emit(choppa)
	if time_left <= 0.0:
		time_left = 0.0
		_end()


func _physics_process(delta: float) -> void:
	tick(delta)


func _on_died(killer: Choppa, victim: Choppa) -> void:
	if over or not authority:
		return
	_score[victim].deaths += 1
	if killer and killer != victim and _score.has(killer):
		_score[killer].kills += 1
	_respawn[victim] = RESPAWN_DELAY
	kill.emit(killer, victim)
	if killer and _score.has(killer) and _score[killer].kills >= kill_limit:
		_end()


func _end() -> void:
	over = true
	for choppa in pilots:
		choppa.locked = true
	match_over.emit()


## A new round on the same field: scores and clock reset, everyone respawns (server).
func restart() -> void:
	over = false
	time_left = time_limit
	_respawn.clear()
	for choppa in pilots:
		_score[choppa] = {"kills": 0, "deaths": 0}
		choppa.locked = false
		if authority:
			choppa.respawn(best_spawn(choppa))
	restarted.emit()


## Network client: the server's numbers for one pilot.
func net_score(choppa: Choppa, kills: int, deaths: int, respawn_left: float) -> void:
	_score[choppa] = {"kills": kills, "deaths": deaths}
	if respawn_left > 0.0:
		_respawn[choppa] = respawn_left
	else:
		_respawn.erase(choppa)


## Network client: the match ended on the server.
func net_end() -> void:
	if not over:
		_end()
