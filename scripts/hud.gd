class_name Hud
extends CanvasLayer
## Speed, altitude, afterburner, heat, hull, item and call-outs for one choppa, the controls
## overlay (settings or F1) and the touch controls on phones. Flat text and thin bars;
## the cockpit view hides most of it because the instruments show the same.

const CALLOUT_TIME := 1.2

var choppa: Choppa
var camera: Camera3D
var touch: TouchControls

var _root: Control
var _speed: Label
var _altitude: Label
var _fps: Label
var _item: Label
var _effects: Label
var _boost: UiKit.Bar
var _heat: UiKit.Bar
var _health: UiKit.Bar
var _health_text: Label
var _parts := {}  ## Choppa.Part -> Label, lit as the part wears.
var _vignette: TextureRect
var _smoke: ColorRect
var _warning: Label
var _crosshair: Control
var _callout: Label
var _callout_time := 0.0
var _hit_flash := 0.0
var _controls: Control
var _flight: Array[Control] = []  ## Hidden in the cockpit view.


func _init(target: Choppa) -> void:
	choppa = target


func _ready() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)

	# Full-screen tints first, so everything else draws over them.
	_smoke = ColorRect.new()
	_smoke.color = Color(0.12, 0.12, 0.14, 0.0)
	_smoke.anchor_right = 1.0
	_smoke.anchor_bottom = 1.0
	_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_smoke)
	var edge := Gradient.new()
	edge.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	edge.set_color(1, Color(0.8, 0.0, 0.0, 0.9))
	edge.set_offset(0, 0.55)
	var edge_texture := GradientTexture2D.new()
	edge_texture.gradient = edge
	edge_texture.fill = GradientTexture2D.FILL_RADIAL
	edge_texture.fill_from = Vector2(0.5, 0.5)
	edge_texture.fill_to = Vector2(1.0, 1.0)
	_vignette = TextureRect.new()
	_vignette.texture = edge_texture
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)

	# Top left: speed and altitude.
	var flight := _column(Vector2(0, 0), Vector2(28, 14), BoxContainer.ALIGNMENT_BEGIN)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 6)
	flight.add_child(speed_row)
	_speed = UiKit.outlined(UiKit.display("0", 54))
	speed_row.add_child(_speed)
	var unit := UiKit.outlined(UiKit.caption("km/h", 14))
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_row.add_child(unit)
	var altitude_row := HBoxContainer.new()
	altitude_row.add_theme_constant_override("separation", 8)
	flight.add_child(altitude_row)
	var alt := UiKit.outlined(UiKit.caption("ALT", 14))
	alt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	altitude_row.add_child(alt)
	_altitude = UiKit.outlined(UiKit.display("0 m", 24))
	altitude_row.add_child(_altitude)
	_fps = UiKit.outlined(UiKit.caption("", 13, UiKit.FAINT))
	flight.add_child(_fps)
	_flight.append(flight)

	# Top right: the held item and running effects.
	var item_column := _column(Vector2(1, 0), Vector2(-28, 18), BoxContainer.ALIGNMENT_BEGIN)
	var item_caption := UiKit.outlined(UiKit.caption("Item", 14))
	item_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(item_caption)
	_item = UiKit.outlined(UiKit.display("-", 30))
	_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_item)
	_effects = UiKit.outlined(UiKit.label("", 18, UiKit.MUTED, "condensed"))
	_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_effects)
	_flight.append(item_column)

	# Bottom centre: afterburner charge, with the gun heat as a hairline under it.
	var boost_column := _column(Vector2(0.5, 1), Vector2(0, -26), BoxContainer.ALIGNMENT_END)
	boost_column.add_theme_constant_override("separation", 6)
	var boost_caption := UiKit.outlined(UiKit.caption("Afterburner", 13))
	boost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_column.add_child(boost_caption)
	_boost = UiKit.Bar.new(300.0, 5.0)
	boost_column.add_child(_boost)
	_heat = UiKit.Bar.new(300.0, 2.0)
	_heat.color = Color(UiKit.TEXT, 0.7)
	_heat.track = Color(1, 1, 1, 0.06)
	boost_column.add_child(_heat)
	_flight.append(boost_column)

	# Bottom left: hull.
	var hull_column := _column(Vector2(0, 1), Vector2(28, -26), BoxContainer.ALIGNMENT_END)
	hull_column.add_theme_constant_override("separation", 6)
	var hull_row := HBoxContainer.new()
	hull_row.add_theme_constant_override("separation", 8)
	hull_column.add_child(hull_row)
	var hull_caption := UiKit.outlined(UiKit.caption("Hull", 13))
	hull_caption.size_flags_vertical = Control.SIZE_SHRINK_END
	hull_row.add_child(hull_caption)
	_health_text = UiKit.outlined(UiKit.display("100", 22))
	hull_row.add_child(_health_text)
	_health = UiKit.Bar.new(240.0, 5.0)
	hull_column.add_child(_health)
	var parts_row := HBoxContainer.new()
	parts_row.add_theme_constant_override("separation", 14)
	hull_column.add_child(parts_row)
	for entry: Array in [[Choppa.Part.ROTOR, "Rotor"], [Choppa.Part.TAIL, "Tail rotor"], [Choppa.Part.ENGINE, "Engine"]]:
		var lamp := UiKit.outlined(UiKit.caption(entry[1], 12, UiKit.FAINT))
		parts_row.add_child(lamp)
		_parts[entry[0]] = lamp
	_flight.append(hull_column)

	_warning = UiKit.outlined(UiKit.display("", 34, UiKit.DANGER))
	_place(_warning, Vector2(0.5, 0.62), Vector2.ZERO)
	_root.add_child(_warning)
	_callout = UiKit.outlined(UiKit.display("", 46, UiKit.ACCENT))
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.modulate.a = 0.0
	_place(_callout, Vector2(0.5, 0.3), Vector2.ZERO)
	_root.add_child(_callout)

	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.anchor_right = 1.0
	_crosshair.anchor_bottom = 1.0
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)

	_controls = _controls_sheet()
	_place(_controls, Vector2(1, 1), Vector2(-28, -26))
	_root.add_child(_controls)

	touch = TouchControls.new()
	touch.anchor_right = 1.0
	touch.anchor_bottom = 1.0
	_root.add_child(touch)
	refresh_settings()

	choppa.item_changed.connect(func(_name: String) -> void: _update_item())
	choppa.scored_hit.connect(func(_target: Choppa) -> void: _hit_flash = 0.12)
	choppa.damaged.connect(func(amount: float, _attacker: Choppa) -> void:
		if Settings.flag("damage_flash"):
			_vignette.modulate.a = minf(1.0, _vignette.modulate.a + amount / 20.0))
	choppa.scrambled_by.connect(func(by: Choppa) -> void:
		_show_callout("SCRAMBLED BY %s" % by.pilot_name.to_upper(), Color(0.8, 0.4, 1.0)))
	choppa.item_used.connect(func(item_name: String) -> void:
		if item_name == "GET TO THE CHOPPA":
			_show_callout("GET TO THE CHOPPA!", UiKit.ACCENT))
	choppa.gun_overheated.connect(func() -> void: _show_callout("OVERHEAT", UiKit.DANGER))
	_update_item()


## F1: flips the controls overlay setting.
func toggle_help() -> void:
	Settings.set_value("show_controls", not Settings.flag("show_controls"))
	Settings.save()
	refresh_settings()


## Re-reads the settings that change what the HUD shows.
func refresh_settings() -> void:
	touch.visible = Settings.touch_visible()
	_controls.queue_free()  # Rebuilt: the mouse notes follow the mouse steering setting.
	_controls = _controls_sheet()
	_place(_controls, Vector2(1, 1), Vector2(-28, -26))
	_root.add_child(_controls)
	_controls.visible = Settings.flag("show_controls") and not touch.visible
	_fps.visible = Settings.flag("show_fps")


func _process(delta: float) -> void:
	# In the cockpit the instruments show all this; keep the screen clean.
	var cockpit := camera is ChaseCamera and (camera as ChaseCamera).first_person
	for control in _flight:
		control.visible = not cockpit
	_speed.text = str(roundi(choppa.velocity.length() * 3.6))
	_altitude.text = "%d m" % roundi(maxf(choppa.altitude, 0.0))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_boost.set_value(choppa.boost_meter)
	_heat.set_value(choppa.heat, UiKit.DANGER if choppa.overheated else Color(UiKit.TEXT, 0.7))
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var hp := choppa.health / Choppa.MAX_HEALTH
	_health.set_value(hp, UiKit.DANGER.lerp(UiKit.GOOD, smoothstep(0.2, 0.6, hp)))
	_health_text.text = str(ceili(choppa.health))
	for part: Choppa.Part in _parts:
		var wear := choppa.wear(part)
		var lamp: Label = _parts[part]
		lamp.add_theme_color_override("font_color",
			UiKit.FAINT if wear <= 0.0 else (UiKit.DANGER if wear >= 1.0 else UiKit.ACCENT.lerp(UiKit.DANGER, wear)))
	_vignette.modulate.a = maxf(0.0, _vignette.modulate.a - delta * 1.5)
	_smoke.color.a = move_toward(_smoke.color.a, 0.82 if choppa.in_smoke() else 0.0, delta * 3.0)
	_warning.text = "MISSILE  -  ROLL!" if _missile_hunting() and fmod(choppa.clock, 0.4) < 0.25 else ""
	var effects := PackedStringArray()
	if choppa.shield > 0.0:
		effects.append("SHIELD %d" % ceili(choppa.shield))
	if choppa.scrambled > 0.0:
		effects.append("SCRAMBLED %d" % ceili(choppa.scrambled))
	if choppa.rampage > 0.0:
		effects.append("RAMPAGE %d" % ceili(choppa.rampage))
	_effects.text = "\n".join(effects)
	_crosshair.queue_redraw()
	if _callout_time > 0.0:
		_callout_time -= delta
		_callout.modulate.a = clampf(_callout_time / 0.4, 0.0, 1.0)


## A small cross where your guns point, or a ring around the locked-on target.
func _draw_crosshair() -> void:
	if camera == null or not choppa.alive:
		return
	var color := UiKit.DANGER if _hit_flash > 0.0 else Color(UiKit.TEXT, 0.9)
	var target := choppa.aim_target()
	if target:
		if not camera.is_position_behind(target.global_position):
			var at := camera.unproject_position(target.global_position)
			_crosshair.draw_arc(at, 30.0, 0.0, TAU, 48, color if _hit_flash > 0.0 else UiKit.ACCENT, 2.0, true)
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_crosshair.draw_line(at + d * 30.0, at + d * 38.0, color, 2.0, true)
		return
	if camera is ChaseCamera and (camera as ChaseCamera).first_person:
		return  # The gunsight in the cockpit is the crosshair.
	var ahead := choppa.global_position - choppa.global_transform.basis.z * 80.0
	if camera.is_position_behind(ahead):
		return
	var c := camera.unproject_position(ahead)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_crosshair.draw_line(c + d * 5.0, c + d * 13.0, color, 1.5, true)


func _show_callout(text: String, color: Color) -> void:
	_callout.text = text
	_callout.add_theme_color_override("font_color", color)
	_callout_time = CALLOUT_TIME


func _update_item() -> void:
	_item.text = choppa.item if choppa.item != "" else "-"
	_item.add_theme_color_override("font_color", Items.color(choppa.item) if choppa.item != "" else UiKit.MUTED)


func _missile_hunting() -> bool:
	for node in choppa.get_tree().get_nodes_in_group("missiles"):
		var missile := node as Weapons.Missile
		if missile.is_hunting(choppa) and missile.global_position.distance_to(choppa.global_position) < 200.0:
			return true
	return false


## The key bindings, as a compact table in the corner.
func _controls_sheet() -> Control:
	var panel := UiKit.panel(false, 14.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.caption("Controls", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.caption("F1 hides", 13, UiKit.FAINT))
	box.add_child(UiKit.rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)
	for row: Array in Controls.cheat_sheet(Settings.flag("mouse_steer"), Settings.choice("mouse_mode") == 1, Settings.choice("flight_model") == 0):
		var what := UiKit.label(row[0], 15, UiKit.MUTED)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(what)
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 4)
		keys.alignment = BoxContainer.ALIGNMENT_END
		keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key: String in row[1]:
			if key.begins_with("~"):
				var note := UiKit.label(key.substr(1), 14, UiKit.MUTED)
				note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				keys.add_child(note)
			else:
				keys.add_child(UiKit.keycap(key))
		grid.add_child(keys)
	return panel


## A VBox pinned to a corner or an edge, growing away from it.
func _column(anchor: Vector2, offset: Vector2, alignment: BoxContainer.AlignmentMode) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = alignment
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_place(box, anchor, offset)
	return box


## Pins a control's corner (or edge middle, for 0.5) at `anchor` (fractions of the
## screen) plus `offset` pixels, growing away from the screen edge.
func _place(control: Control, anchor: Vector2, offset: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_right = offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y
	control.grow_horizontal = _grow(anchor.x)
	control.grow_vertical = _grow(anchor.y)


func _grow(anchor: float) -> Control.GrowDirection:
	if anchor == 0.0:
		return Control.GROW_DIRECTION_END
	if anchor == 1.0:
		return Control.GROW_DIRECTION_BEGIN
	return Control.GROW_DIRECTION_BOTH
