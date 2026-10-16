class_name RaceHud
extends CanvasLayer
## Race overlay for the local player: lap, place, time, countdown, next-gate marker and
## the results screen.

signal restart_requested
signal menu_requested

var race: Race
var choppa: Choppa
var camera: Camera3D

var _status: Label
var _big: Label
var _big_time := 0.0
var _marker: Control
var _results: PanelContainer
var _shown_next: RingGate


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_marker = Control.new()
	_marker.anchor_right = 1.0
	_marker.anchor_bottom = 1.0
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	root.add_child(_marker)

	_status = _label(root, 34)
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.offset_top = 14.0
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_big = _label(root, 120)
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.anchor_top = 0.38
	_big.anchor_bottom = 0.38
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH

	race.countdown_changed.connect(_on_countdown)
	race.lap_started.connect(_on_lap_started)
	race.racer_finished.connect(_on_racer_finished)
	race.race_over.connect(_show_results)
	_flash_big(str(ceili(race.countdown)), Color.WHITE, 1.0)


func _process(delta: float) -> void:
	var minutes := int(race.time / 60.0)
	_status.text = "LAP %d/%d     POS %d/%d     %d:%04.1f" % [
		race.lap_of(choppa), race.laps, race.place_of(choppa), race.racers.size(),
		minutes, race.time - minutes * 60.0,
	]
	if _big_time > 0.0:
		_big_time -= delta
		_big.modulate.a = clampf(_big_time / 0.3, 0.0, 1.0)
	_update_gate_highlights()
	_marker.queue_redraw()


func _update_gate_highlights() -> void:
	var next := race.next_gate(choppa)
	if next == _shown_next:
		return
	_shown_next = next
	var after := race.gates[(next.index + 1) % race.gates.size()]
	for gate in race.gates:
		gate.set_state("next" if gate == next else ("normal" if gate == after else "later"))


## A diamond over the next gate, or an arrow on the screen edge pointing to it.
func _draw_marker() -> void:
	if race.over or race.is_done(choppa) or camera == null:
		return
	var target := race.next_gate(choppa).global_position
	var size := _marker.size
	var center := size * 0.5
	var color := Color(0.2, 0.9, 1.0, 0.9)
	var on_screen := false
	var at := Vector2.ZERO
	if not camera.is_position_behind(target):
		at = camera.unproject_position(target)
		on_screen = Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(at)
	if on_screen:
		var d := 14.0
		_marker.draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)
		]), Color(color, 0.35))
		_marker.draw_polyline(PackedVector2Array([
			at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0),
			at + Vector2(0, -d)
		]), color, 3.0)
		return
	# Off screen: arrow at the edge, in the gate's direction relative to our heading.
	var local := choppa.facing().inverse() * (target - choppa.global_position)
	var dir := Vector2(local.x, local.z).normalized()
	if dir == Vector2.ZERO:
		return
	var edge := center + dir * (minf(size.x, size.y) * 0.5 - 60.0)
	var tip := edge + dir * 28.0
	var side := dir.orthogonal() * 18.0
	_marker.draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), color)


func _on_countdown(seconds_left: int) -> void:
	if seconds_left > 0:
		_flash_big(str(seconds_left), Color.WHITE, 1.0)
	else:
		_flash_big("GO!", Color(0.4, 1.0, 0.4), 1.0)


func _on_lap_started(racer: Choppa, lap: int) -> void:
	if racer != choppa or lap == 1:
		return
	_flash_big("FINAL LAP" if lap == race.laps else "LAP %d" % lap, Color(1.0, 0.85, 0.2), 1.6)


func _on_racer_finished(racer: Choppa, place: int, _time: float) -> void:
	if racer == choppa:
		_flash_big("%s!" % _ordinal(place), Color(1.0, 0.85, 0.2), 3.0)


func _show_results() -> void:
	_results = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.85)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	_results.add_theme_stylebox_override("panel", style)
	_results.anchor_left = 0.5
	_results.anchor_right = 0.5
	_results.anchor_top = 0.5
	_results.anchor_bottom = 0.5
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_results)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_results.add_child(box)
	var title := _label(box, 44)
	title.text = "RESULTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var place := 1
	for racer in race.standings():
		var line := _label(box, 28)
		var time := "DNF"
		for result in race.results:
			if result.choppa == racer:
				var m := int(result.time / 60.0)
				time = "%d:%04.1f" % [m, result.time - m * 60.0]
		line.text = "%d.  %-12s %s" % [place, racer.pilot_name, time]
		line.add_theme_color_override("font_color", racer.team_color.lightened(0.3))
		place += 1

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var again := Menu.make_button("RACE AGAIN", 30)
	again.pressed.connect(restart_requested.emit)
	buttons.add_child(again)
	var menu := Menu.make_button("MENU", 30)
	menu.pressed.connect(menu_requested.emit)
	buttons.add_child(menu)
	again.grab_focus()


func _flash_big(text: String, color: Color, seconds: float) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
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


static func _ordinal(n: int) -> String:
	match n:
		1:
			return "1ST"
		2:
			return "2ND"
		3:
			return "3RD"
	return "%dTH" % n
