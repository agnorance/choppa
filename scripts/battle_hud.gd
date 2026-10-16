class_name BattleHud
extends CanvasLayer
## Battle overlay for the local player: score, rank, clock, kill feed, the "shot down"
## screen with respawn countdown, and the final scoreboard.

signal restart_requested
signal menu_requested

const FEED_TIME := 6.0

var battle: Battle
var choppa: Choppa

var _status: Label
var _feed: VBoxContainer
var _death: Label
var _killed_by := ""
var _big: Label
var _big_time := 0.0


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_status = _label(root, 32)
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.offset_top = 14.0
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_feed = VBoxContainer.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_top = 64.0
	_feed.offset_right = -24.0
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)

	_death = _label(root, 48)
	_death.anchor_left = 0.5
	_death.anchor_right = 0.5
	_death.anchor_top = 0.4
	_death.anchor_bottom = 0.4
	_death.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

	_big = _label(root, 64)
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.anchor_top = 0.25
	_big.anchor_bottom = 0.25
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH
	_big.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	battle.kill.connect(_on_kill)
	battle.match_over.connect(_show_results)
	_flash_big("FIRST TO %d KILLS" % battle.kill_limit, 2.5)


func _process(delta: float) -> void:
	var minutes := int(battle.time_left / 60.0)
	_status.text = "KILLS %d/%d     #%d     %d:%02d" % [
		battle.kills_of(choppa), battle.kill_limit, battle.standings().find(choppa) + 1,
		minutes, int(battle.time_left) % 60,
	]
	if not choppa.alive and not battle.over:
		_death.text = "%s\nRespawn in %d" % [_killed_by, ceili(battle.respawn_in(choppa))]
	else:
		_death.text = ""
	if _big_time > 0.0:
		_big_time -= delta
		_big.modulate.a = clampf(_big_time / 0.4, 0.0, 1.0)
	for entry: Label in _feed.get_children():
		entry.set_meta("age", entry.get_meta("age") + delta)
		entry.modulate.a = clampf((FEED_TIME - entry.get_meta("age")) / 1.0, 0.0, 1.0)
		if entry.get_meta("age") > FEED_TIME:
			entry.queue_free()


func _on_kill(killer: Choppa, victim: Choppa) -> void:
	var line := _label(_feed, 22)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.set_meta("age", 0.0)
	if killer and killer != victim:
		line.text = "%s  shot down  %s" % [killer.pilot_name, victim.pilot_name]
	else:
		line.text = "%s  crashed" % victim.pilot_name
	if killer == choppa or victim == choppa:
		line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	if _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()

	if victim == choppa:
		_killed_by = "SHOT DOWN BY %s" % killer.pilot_name.to_upper() if killer and killer != choppa else "CRASHED"
	elif killer == choppa:
		var kills := battle.kills_of(choppa)
		var left := battle.kill_limit - kills
		_flash_big("SPLASHED %s!%s" % [victim.pilot_name.to_upper(),
			"\n%d TO GO" % left if left > 0 and left <= 3 else ""], 1.6)


func _show_results() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var winner := battle.standings()[0]
	var title := _label(box, 44)
	title.text = "YOU WIN!" if winner == choppa else "%s WINS" % winner.pilot_name.to_upper()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 36)
	box.add_child(grid)
	for header in ["", "PILOT", "KILLS", "DEATHS"]:
		var cell := _label(grid, 20)
		cell.text = header
		cell.modulate.a = 0.7
	var place := 1
	for pilot in battle.standings():
		for text in ["%d." % place, pilot.pilot_name, str(battle.kills_of(pilot)), str(battle.deaths_of(pilot))]:
			var cell := _label(grid, 28)
			cell.text = text
			cell.add_theme_color_override("font_color", pilot.team_color.lightened(0.3))
		place += 1

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var again := Menu.make_button("FIGHT AGAIN", 30)
	again.pressed.connect(restart_requested.emit)
	buttons.add_child(again)
	var menu := Menu.make_button("MENU", 30)
	menu.pressed.connect(menu_requested.emit)
	buttons.add_child(menu)
	again.grab_focus()


func _flash_big(text: String, seconds: float) -> void:
	_big.text = text
	_big_time = seconds
	_big.modulate.a = 1.0


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label
