class_name MatchStats
extends Node
## Counts what one pilot does in a battle, for XP (Progression.award): kills, assists,
## parts wrecked, damage dealt, and stations taken while an enemy was close. Listens to
## the battle and every choppa's signals; nothing else needs to know about it.

const DENY_RANGE := 150.0

var pilot: Choppa
var battle: Battle
var stats := {"kill": 0, "assist": 0, "part": 0, "damage": 0, "station_denied": 0}
var _hit_at := {}  ## victim -> clock of our last damage on it


func _ready() -> void:
	battle.kill.connect(_on_kill)
	battle.restarted.connect(reset)
	for c in battle.pilots:
		if c != pilot:
			c.damaged.connect(_on_damaged.bind(c))
			c.part_wrecked.connect(_on_part_wrecked)
	for node in get_tree().get_nodes_in_group("stations"):
		(node as ServiceStation).served.connect(_on_served)


## Back to zero for a new round on the same field (online rounds follow each other).
func reset() -> void:
	for key: String in stats:
		stats[key] = 0
	_hit_at.clear()


## The finished battle's stats, ready for Profile.add_battle.
func result() -> Dictionary:
	var out := stats.duplicate()
	out["finished"] = battle.over
	out["won"] = battle.over and battle.standings()[0] == pilot
	return out


func _on_damaged(amount: float, attacker: Choppa, victim: Choppa) -> void:
	if attacker == pilot:
		stats.damage += roundi(amount)
		_hit_at[victim] = victim.clock


func _on_part_wrecked(_part: Choppa.Part, by: Choppa) -> void:
	if by == pilot:
		stats.part += 1


func _on_kill(killer: Choppa, victim: Choppa) -> void:
	if killer == pilot and victim != pilot:
		stats.kill += 1
	elif victim != pilot and _hit_at.has(victim) and victim.clock - _hit_at[victim] < Progression.ASSIST_TIME:
		stats.assist += 1
	_hit_at.erase(victim)


func _on_served(choppa: Choppa) -> void:
	if choppa != pilot:
		return
	for c in battle.pilots:
		if c != pilot and c.alive and c.global_position.distance_to(pilot.global_position) < DENY_RANGE:
			stats.station_denied += 1
			return
