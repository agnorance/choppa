class_name Hud
extends CanvasLayer
## Speed, altitude, afterburner, heat, hull, loadout and call-outs for one choppa, the controls
## overlay (settings or F1). Flat text and thin bars;
## the cockpit view hides most of it because the instruments show the same.

const CALLOUT_TIME := 1.2
const PART_NAMES := {Choppa.Part.ROTOR: "ROTOR", Choppa.Part.TAIL: "TAIL ROTOR", Choppa.Part.ENGINE: "ENGINE"}

var choppa: Choppa
var camera: Camera3D

var _root: Control
var _speed: Label
var _altitude: Label
var _fps: Label
var _gun: Label
var _loadout: Label
var _loadout_extra: Label
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
const HUD_GREEN := Color(0.5, 1.0, 0.45, 0.95)  ## The cockpit sight's phosphor.
const SIGHT_ANGLE := 0.075  ## Half the sight glass's width as seen from the eye, radians.
var _bracketed: Choppa  ## The target the brackets are on, and since when.
var _bracket_time := 0.0
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

	# Top right: the loadout, then station status and running effects.
	var item_column := _column(Vector2(1, 0), Vector2(-28, 18), BoxContainer.ALIGNMENT_BEGIN)
	var item_caption := UiKit.outlined(UiKit.caption(Airframe.spec(choppa.airframe).name, 14))
	item_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(item_caption)
	_gun = UiKit.outlined(UiKit.display("", 26))
	_gun.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_gun)
	_loadout = UiKit.outlined(UiKit.display("", 26))
	_loadout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_loadout)
	_loadout_extra = UiKit.outlined(UiKit.label("", 16, UiKit.MUTED, "condensed"))
	_loadout_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_loadout_extra)
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
	for entry: Array in [[Choppa.Part.ROTOR, "Rotor"], [Choppa.Part.TAIL, "Tail" if choppa.coaxial else "Tail rotor"], [Choppa.Part.ENGINE, "Engine"]]:
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

	refresh_settings()

	choppa.scored_hit.connect(func(_target: Choppa) -> void:
		_hit_flash = 0.12
		Sounds.play_ui(self, "hit_marker", -10.0))
	choppa.wrecked_part.connect(func(target: Choppa, part: Choppa.Part) -> void:
		Sounds.play_ui(self, "part_hit", -4.0)
		_show_callout("%s  ·  %s" % [part_name(part, target), target.pilot_name.to_upper()], UiKit.ACCENT))
	choppa.part_wrecked.connect(func(part: Choppa.Part, _by: Choppa) -> void:
		_show_callout("%s DOWN" % part_name(part, choppa), UiKit.DANGER))
	choppa.damaged.connect(func(amount: float, _attacker: Choppa) -> void:
		if Settings.flag("damage_flash"):
			_vignette.modulate.a = minf(1.0, _vignette.modulate.a + amount / 20.0))
	choppa.restocked.connect(func() -> void:
		if choppa.clock > 0.5:
			_show_callout("SERVICED", UiKit.GOOD))
	choppa.fired.connect(func(weapon: String) -> void:
		if weapon == "flares":
			_show_callout("FLARES", UiKit.ACCENT))
	choppa.gun_overheated.connect(func() -> void: _show_callout("OVERHEAT", UiKit.DANGER))


## F1: flips the controls overlay setting.
func toggle_help() -> void:
	Settings.set_value("show_controls", not Settings.flag("show_controls"))
	Settings.save()
	refresh_settings()


## Re-reads the settings that change what the HUD shows.
func refresh_settings() -> void:
	_controls.queue_free()  # Rebuilt: the mouse notes follow the mouse steering setting.
	_controls = _controls_sheet()
	_place(_controls, Vector2(1, 1), Vector2(-28, -26))
	_root.add_child(_controls)
	_controls.visible = Settings.flag("show_controls")
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
	var hp := choppa.health / choppa.max_health
	_health.set_value(hp, UiKit.DANGER.lerp(UiKit.GOOD, smoothstep(0.2, 0.6, hp)))
	_health_text.text = str(ceili(choppa.health))
	for part: Choppa.Part in _parts:
		var wear := choppa.wear(part)
		var lamp: Label = _parts[part]
		lamp.add_theme_color_override("font_color",
			UiKit.FAINT if wear <= 0.0 else (UiKit.DANGER if wear >= 1.0 else UiKit.ACCENT.lerp(UiKit.DANGER, wear)))
	_vignette.modulate.a = maxf(0.0, _vignette.modulate.a - delta * 1.5)
	_smoke.color.a = move_toward(_smoke.color.a, 0.82 if choppa.in_smoke() else 0.0, delta * 3.0)
	_warning.text = "MISSILE  -  FLARES!" if choppa.ammo.flares > 0 and _missile_hunting() and fmod(choppa.clock, 0.4) < 0.25 else "MISSILE  -  ROLL!" if _missile_hunting() and fmod(choppa.clock, 0.4) < 0.25 else ""
	var a := choppa.ammo
	_gun.text = "GUN %d" % a.gun if a.gun > 0 else "GUN EMPTY"
	_gun.add_theme_color_override("font_color", UiKit.DANGER if a.gun < choppa.full_ammo("gun") * 0.2 else UiKit.TEXT)
	_loadout.text = "RKT %d   MSL %d   FLR %d" % [a.rockets, a.missiles, a.flares]
	_loadout_extra.text = "MINE %d   SMOKE %d" % [a.mines, a.smoke]
	_loadout.add_theme_color_override("font_color", UiKit.DANGER if a.rockets + a.missiles == 0 else UiKit.TEXT)
	var effects := PackedStringArray()
	if not choppa.engine_on and choppa.alive:
		effects.append("ENGINE OFF  ·  I or throttle up")
	elif choppa.spool < 0.999 and choppa.alive:
		effects.append("ENGINE START  %d%%" % roundi(choppa.spool * 100.0))
	var station := _my_station()
	if station:
		effects.append("%s  %d%%" % ["REARMING" if station.ammo_only else "SERVICING", roundi(station.progress() * 100.0)])
	elif a.missiles > 0 and choppa.missile_target():
		effects.append("MISSILE LOCK")
	if choppa.decoy_time > 0.0:
		effects.append("DECOY")
	_effects.text = "\n".join(effects)
	_crosshair.queue_redraw()
	if _callout_time > 0.0:
		_callout_time -= delta
		_callout.modulate.a = clampf(_callout_time / 0.4, 0.0, 1.0)


## The gunsight: a pipper whose segments spread as the barrels heat (the bloom), with
## thin gauges round it for gun heat (left) and rounds left (right); corner brackets
## close in on the target the guns are on, with its name and range, and go red with a
## turning diamond when a missile can lock. Everything has a dark edge so it reads
## against a bright sky.
func _draw_crosshair() -> void:
	if camera == null or not choppa.alive:
		return
	var target := choppa.aim_target()
	var lock: Choppa = choppa.missile_target() if choppa.ammo.missiles > 0 else null
	var boxed := target if target else lock  # The guns' target, else the missile's.
	if boxed != _bracketed:
		_bracketed = boxed
		_bracket_time = 0.0
	if boxed and not camera.is_position_behind(boxed.global_position):
		_draw_brackets(camera.unproject_position(boxed.global_position), boxed, lock == boxed)
	var cockpit := camera is ChaseCamera and (camera as ChaseCamera).first_person
	var ahead := choppa.global_position - choppa.global_transform.basis.z * 80.0
	if cockpit:
		# The sight is collimated: its picture sits at infinity along the boresight, so it
		# stays put on the world however the head moves (free look swings it away).
		ahead = camera.global_position - choppa.global_transform.basis.z * 400.0
	if target:
		ahead = target.global_position  # The guns snap onto it.
	if camera.is_position_behind(ahead):
		return
	if cockpit:
		_draw_sight(camera.unproject_position(ahead))
	else:
		_draw_pipper(camera.unproject_position(ahead), Color(UiKit.TEXT, 0.92))


## From the seat: a fine reflex-sight reticle that sits inside the sight's glass. A thin
## ring with ticks and a dot, glowing like phosphor; it opens up as the barrels heat,
## goes amber when rounds run low and red on a hit.
func _draw_sight(c: Vector2) -> void:
	# The glass is about 4.5 degrees across from the eye; size the picture to fit in it.
	var px := tan(SIGHT_ANGLE) / tan(deg_to_rad(camera.fov) * 0.5) * get_viewport().get_visible_rect().size.y * 0.5
	var rounds := float(choppa.ammo.gun) / maxf(1.0, choppa.full_ammo("gun"))
	var color := HUD_GREEN
	if rounds < 0.2:
		color = UiKit.ACCENT
	if choppa.overheated or (choppa.heat > 0.85 and fmod(choppa.clock, 0.3) < 0.18):
		color = UiKit.ACCENT
	if _hit_flash > 0.0:
		color = UiKit.DANGER
	var r := px * (0.62 + choppa.heat * 0.25)
	_glow_arc(c, r, 0.0, TAU, color, 1.3)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_glow_line(c + d * r * 0.35, c + d * r * 0.72, color, 1.3)
		_glow_line(c + d * r, c + d * (r + px * 0.12), color, 1.3)
	_crosshair.draw_circle(c, 3.2, Color(color, 0.25))
	_crosshair.draw_circle(c, 1.5, color)
	if choppa.heat > 0.01:  # Gun heat: a short arc creeping round the bottom of the ring.
		_glow_arc(c, r + px * 0.2, PI * 0.5 - PI * 0.4 * choppa.heat, PI * 0.5 + PI * 0.4 * choppa.heat, Color(color, 0.8), 1.6)


func _glow_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_crosshair.draw_line(a, b, Color(color, 0.18), width + 3.0, true)
	_crosshair.draw_line(a, b, color, width, true)


func _glow_arc(c: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	_crosshair.draw_arc(c, radius, from, to, 48, Color(color, 0.18), width + 3.0, true)
	_crosshair.draw_arc(c, radius, from, to, 48, color, width, true)


func _draw_pipper(c: Vector2, white: Color) -> void:
	var hit := _hit_flash > 0.0
	var color := UiKit.DANGER if hit else white
	var r := 10.0 + choppa.heat * 16.0  # The bloom, roughly as wide as the spread.
	_dot(c, 1.8, color)
	for k in 4:  # Four arcs on the diagonals, open at the cardinal points.
		var mid := PI * 0.25 + k * PI * 0.5
		_arc(c, r, mid - 0.45, mid + 0.45, color, 1.6)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		_line(c + d * (r + 5.0), c + d * (r + 12.0), color, 1.6)
	# Heat on the left, rounds on the right: thin arcs on a faint track.
	var track := Color(1, 1, 1, 0.16)
	var gauge := 34.0
	var heat_color := white.lerp(UiKit.ACCENT, smoothstep(0.3, 0.7, choppa.heat))
	if choppa.overheated or choppa.heat > 0.85:
		heat_color = UiKit.DANGER if fmod(choppa.clock, 0.3) < 0.18 else UiKit.ACCENT
	_crosshair.draw_arc(c, gauge, PI * 0.72, PI * 1.28, 24, track, 2.0, true)
	if choppa.heat > 0.01:
		_arc(c, gauge, PI * 1.28 - PI * 0.56 * choppa.heat, PI * 1.28, heat_color, 2.4)
	var rounds := float(choppa.ammo.gun) / maxf(1.0, choppa.full_ammo("gun"))
	_crosshair.draw_arc(c, gauge, -PI * 0.28, PI * 0.28, 24, track, 2.0, true)
	if rounds > 0.0:
		_arc(c, gauge, PI * 0.28 - PI * 0.56 * rounds, PI * 0.28, UiKit.ACCENT if rounds < 0.2 else Color(white, 0.7), 2.4)
	if hit:  # Hit marker: crisp diagonal ticks just outside the bloom.
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n := d.normalized()
			_line(c + n * (r + 4.0), c + n * (r + 12.0), Color.WHITE, 2.2)


func _draw_brackets(at: Vector2, target: Choppa, locked: bool) -> void:
	_bracket_time += get_process_delta_time()
	var size := lerpf(64.0, 34.0, smoothstep(0.0, 0.25, _bracket_time))  # Closing in.
	var color := UiKit.DANGER if locked else UiKit.ACCENT
	var leg := size * 0.45
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := at + corner * size
		_line(p, p - Vector2(corner.x, 0.0) * leg, color, 2.0)
		_line(p, p - Vector2(0.0, corner.y) * leg, color, 2.0)
	if locked:  # A turning diamond and the word.
		var a := choppa.clock * 2.5
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(at + Vector2.from_angle(a + k * PI * 0.5) * (size * 0.62))
		_crosshair.draw_polyline(pts, Color(0, 0, 0, 0.5), 4.0, true)
		_crosshair.draw_polyline(pts, color, 2.0, true)
	var font := UiKit.font("condensed")
	var label := "%s  %d m%s" % [target.pilot_name.to_upper(), roundi(choppa.global_position.distance_to(target.global_position)),
		"  ·  LOCK" if locked else ""]
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var spot := at + Vector2(-width * 0.5, size + 20.0)
	_crosshair.draw_string_outline(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.6))
	_crosshair.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)


# Sight primitives with a dark edge under them.
func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_crosshair.draw_line(a, b, Color(0, 0, 0, 0.45), width + 2.0, true)
	_crosshair.draw_line(a, b, color, width, true)


func _arc(c: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	_crosshair.draw_arc(c, radius, from, to, 16, Color(0, 0, 0, 0.45), width + 2.0, true)
	_crosshair.draw_arc(c, radius, from, to, 16, color, width, true)


func _dot(c: Vector2, radius: float, color: Color) -> void:
	_crosshair.draw_circle(c, radius + 1.0, Color(0, 0, 0, 0.45))
	_crosshair.draw_circle(c, radius, color)


## What a part is called on this choppa: a coaxial one has a tail, not a tail rotor.
static func part_name(part: Choppa.Part, on: Choppa) -> String:
	if part == Choppa.Part.TAIL and on and on.coaxial:
		return "TAIL"
	return PART_NAMES[part]


## A message in the middle of the screen for a moment (e.g. the radio station).
func callout(text: String) -> void:
	_show_callout(text, UiKit.TEXT)


func _show_callout(text: String, color: Color) -> void:
	_callout.text = text
	_callout.add_theme_color_override("font_color", color)
	_callout_time = CALLOUT_TIME


## The station working on this choppa right now, or null.
func _my_station() -> ServiceStation:
	for node in choppa.get_tree().get_nodes_in_group("stations"):
		if (node as ServiceStation).occupant == choppa:
			return node
	return null


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
