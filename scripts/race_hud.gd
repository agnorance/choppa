class_name RaceHud
extends CanvasLayer
## Race overlay for the local player: lap, place and time along the top, the countdown,
## the next-gate marker and the results.

signal restart_requested
signal menu_requested

const GATE_COLOR := Color(0.4, 0.85, 1.0, 0.9)

var race: Race
var choppa: Choppa
var camera: Camera3D

var _root: Control
var _lap: Label
var _place: Label
var _clock: Label
var _big: Label
var _big_time := 0.0
var _marker: Control
var _shown_next: RingGate


func _ready() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	_marker = Control.new()
	_marker.anchor_right = 1.0
	_marker.anchor_bottom = 1.0
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	_root.add_child(_marker)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 44)
	status.anchor_left = 0.5
	status.anchor_right = 0.5
	status.offset_top = 14.0
	status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(status)
	_lap = _readout(status, "Lap")
	_place = _readout(status, "Position")
	_clock = _readout(status, "Time")

	_big = UiKit.outlined(UiKit.display("", 120))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.anchor_top = 0.38
	_big.anchor_bottom = 0.38
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_big)

	race.countdown_changed.connect(_on_countdown)
	race.lap_started.connect(_on_lap_started)
	race.racer_finished.connect(_on_racer_finished)
	race.race_over.connect(_show_results)
	_flash_big(str(ceili(race.countdown)), UiKit.TEXT, 1.0)


func _process(delta: float) -> void:
	var minutes := int(race.time / 60.0)
	_lap.text = "%d / %d" % [race.lap_of(choppa), race.laps]
	_place.text = "%d / %d" % [race.place_of(choppa), race.racers.size()]
	_clock.text = "%d:%04.1f" % [minutes, race.time - minutes * 60.0]
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
	var on_screen := false
	var at := Vector2.ZERO
	if not camera.is_position_behind(target):
		at = camera.unproject_position(target)
		on_screen = Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(at)
	if on_screen:
		var d := 14.0
		var diamond := PackedVector2Array([
			at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0), at + Vector2(0, -d)
		])
		_marker.draw_polyline(diamond, GATE_COLOR, 2.0, true)
		return
	# Off screen: arrow at the edge, in the gate's direction relative to our heading.
	var local := choppa.facing().inverse() * (target - choppa.global_position)
	var dir := Vector2(local.x, local.z).normalized()
	if dir == Vector2.ZERO:
		return
	var edge := center + dir * (minf(size.x, size.y) * 0.5 - 60.0)
	var tip := edge + dir * 28.0
	var side := dir.orthogonal() * 16.0
	_marker.draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), GATE_COLOR)


func _on_countdown(seconds_left: int) -> void:
	if seconds_left > 0:
		_flash_big(str(seconds_left), UiKit.TEXT, 1.0)
	else:
		_flash_big("GO", UiKit.GOOD, 1.0)


func _on_lap_started(racer: Choppa, lap: int) -> void:
	if racer != choppa or lap == 1:
		return
	_flash_big("FINAL LAP" if lap == race.laps else "LAP %d" % lap, UiKit.ACCENT, 1.6)


func _on_racer_finished(racer: Choppa, place: int, _time: float) -> void:
	if racer == choppa:
		_flash_big(_ordinal(place), UiKit.ACCENT, 3.0)


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
	box.add_child(UiKit.display("RESULTS", 40))
	box.add_child(UiKit.rule())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 44)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for header in ["", "Pilot", "Time"]:
		grid.add_child(UiKit.caption(header, 13))
	var place := 1
	for racer in race.standings():
		var time := "DNF"
		for result in race.results:
			if result.choppa == racer:
				var m := int(result.time / 60.0)
				time = "%d:%04.1f" % [m, result.time - m * 60.0]
		var color := racer.team_color.lightened(0.35)
		grid.add_child(UiKit.label("%d" % place, 24, UiKit.MUTED, "condensed"))
		grid.add_child(UiKit.label(racer.pilot_name, 24, color, "condensed"))
		grid.add_child(UiKit.label(time, 24, color, "condensed"))
		place += 1

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var again := UiKit.button("Race again", 200.0)
	again.alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.pressed.connect(restart_requested.emit)
	buttons.add_child(again)
	var menu := UiKit.button("Menu", 160.0)
	menu.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.pressed.connect(menu_requested.emit)
	buttons.add_child(menu)
	again.grab_focus()


func _flash_big(text: String, color: Color, seconds: float) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
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


static func _ordinal(n: int) -> String:
	match n:
		1:
			return "1ST"
		2:
			return "2ND"
		3:
			return "3RD"
	return "%dTH" % n
