class_name BattleHud
extends CanvasLayer
## Battle overlay for the local player: kills, rank and clock along the top, a kill
## feed, the "shot down" screen with the respawn countdown, and the final results.

signal restart_requested
signal menu_requested

const FEED_TIME := 6.0

var battle: Battle
var choppa: Choppa

var _root: Control
var _kills: Label
var _rank: Label
var _clock: Label
var _feed: VBoxContainer
var _death: Label
var _death_sub: Label
var _killed_by := ""
var _big: Label
var _big_time := 0.0


func _ready() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 44)
	status.anchor_left = 0.5
	status.anchor_right = 0.5
	status.offset_top = 14.0
	status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(status)
	_kills = _readout(status, "Kills")
	_rank = _readout(status, "Rank")
	_clock = _readout(status, "Time")

	_feed = VBoxContainer.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_top = 112.0
	_feed.offset_right = -28.0
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.add_theme_constant_override("separation", 2)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)

	var death_box := VBoxContainer.new()
	death_box.anchor_left = 0.5
	death_box.anchor_right = 0.5
	death_box.anchor_top = 0.4
	death_box.anchor_bottom = 0.4
	death_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	death_box.add_theme_constant_override("separation", 2)
	_root.add_child(death_box)
	_death = UiKit.outlined(UiKit.display("", 44, UiKit.DANGER))
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_box.add_child(_death)
	_death_sub = UiKit.outlined(UiKit.label("", 20, UiKit.MUTED, "condensed"))
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_box.add_child(_death_sub)

	_big = UiKit.outlined(UiKit.display("", 56, UiKit.ACCENT))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.anchor_top = 0.25
	_big.anchor_bottom = 0.25
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_big)

	battle.kill.connect(_on_kill)
	battle.match_over.connect(_show_results)
	_flash_big("FIRST TO %d KILLS" % battle.kill_limit, 2.5)


func _process(delta: float) -> void:
	var minutes := int(battle.time_left / 60.0)
	_kills.text = "%d / %d" % [battle.kills_of(choppa), battle.kill_limit]
	_rank.text = "#%d" % (battle.standings().find(choppa) + 1)
	_clock.text = "%d:%02d" % [minutes, int(battle.time_left) % 60]
	if not choppa.alive and not battle.over:
		_death.text = _killed_by
		_death_sub.text = "Respawn in %d" % ceili(battle.respawn_in(choppa))
	else:
		_death.text = ""
		_death_sub.text = ""
	if _big_time > 0.0:
		_big_time -= delta
		_big.modulate.a = clampf(_big_time / 0.4, 0.0, 1.0)
	for entry: Control in _feed.get_children():
		entry.set_meta("age", entry.get_meta("age") + delta)
		entry.modulate.a = clampf((FEED_TIME - entry.get_meta("age")) / 1.0, 0.0, 1.0)
		if entry.get_meta("age") > FEED_TIME:
			entry.queue_free()


func _on_kill(killer: Choppa, victim: Choppa) -> void:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_theme_constant_override("separation", 8)
	line.set_meta("age", 0.0)
	var mine := killer == choppa or victim == choppa
	if killer and killer != victim:
		line.add_child(_feed_name(killer, mine))
		line.add_child(UiKit.outlined(UiKit.label("shot down", 15, UiKit.MUTED)))
		line.add_child(_feed_name(victim, mine))
	else:
		line.add_child(_feed_name(victim, mine))
		line.add_child(UiKit.outlined(UiKit.label("crashed", 15, UiKit.MUTED)))
	_feed.add_child(line)
	if _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()

	if victim == choppa:
		_killed_by = "SHOT DOWN BY %s" % killer.pilot_name.to_upper() if killer and killer != choppa else "CRASHED"
	elif killer == choppa:
		var left := battle.kill_limit - battle.kills_of(choppa)
		_flash_big("SPLASHED %s%s" % [victim.pilot_name.to_upper(),
			"\n%d TO GO" % left if left > 0 and left <= 3 else ""], 1.6)


func _feed_name(pilot: Choppa, highlight: bool) -> Label:
	var l := UiKit.outlined(UiKit.label(pilot.pilot_name, 18, UiKit.ACCENT if highlight else UiKit.TEXT, "condensed"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _show_results() -> void:
	var panel := UiKit.panel(true, 32.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var winner := battle.standings()[0]
	var won := winner == choppa
	box.add_child(UiKit.display("YOU WIN" if won else "%s WINS" % winner.pilot_name.to_upper(), 40,
		UiKit.ACCENT if won else UiKit.TEXT))
	box.add_child(UiKit.rule())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 44)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for header in ["", "Pilot", "Kills", "Deaths"]:
		grid.add_child(UiKit.caption(header, 13))
	var place := 1
	for pilot in battle.standings():
		var color := pilot.team_color.lightened(0.35)
		grid.add_child(UiKit.label("%d" % place, 24, UiKit.MUTED, "condensed"))
		grid.add_child(UiKit.label(pilot.pilot_name, 24, color, "condensed"))
		grid.add_child(UiKit.label(str(battle.kills_of(pilot)), 24, color, "condensed"))
		grid.add_child(UiKit.label(str(battle.deaths_of(pilot)), 24, color, "condensed"))
		place += 1

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var again := UiKit.button("Fight again", 200.0)
	again.alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.pressed.connect(restart_requested.emit)
	buttons.add_child(again)
	var menu := UiKit.button("Menu", 160.0)
	menu.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.pressed.connect(menu_requested.emit)
	buttons.add_child(menu)
	again.grab_focus()


func _flash_big(text: String, seconds: float) -> void:
	_big.text = text
	_big_time = seconds
	_big.modulate.a = 1.0


## A caption with a big value under it; returns the value label.
func _readout(parent: Control, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var c := UiKit.outlined(UiKit.caption(caption, 13))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(c)
	var value := UiKit.outlined(UiKit.display("", 30))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return value
