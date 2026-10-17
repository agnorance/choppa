class_name Hud
extends CanvasLayer
## The chase view's flight display for one choppa: a heading tape, speed and altitude
## tapes and a pitch ladder round the middle (Settings "hud_flight"), the gunsight, the
## radar (HudRadar, "hud_radar") over the hull bottom left, the afterburner bottom
## centre, what's left to shoot (HudAmmo) bottom right, call-outs and the controls
## overlay (settings or F1). The cockpit view hides most of it: the instruments show the same.

const CALLOUT_TIME := 1.2
const CONTROLS_AT := Vector2(1, 1)
const CONTROLS_OFFSET := Vector2(-28, -26 - HudAmmo.SIZE.y - 14)  ## Over the ammo panel.
const PART_NAMES := {Choppa.Part.ROTOR: "ROTOR", Choppa.Part.TAIL: "TAIL ROTOR", Choppa.Part.ENGINE: "ENGINE"}

var choppa: Choppa
var camera: Camera3D

var _root: Control
var _fps: Label
var _effects: Label
var _boost: UiKit.Bar
var _radar: HudRadar
var _ammo: HudAmmo
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
const HUD_LINE := Color(0.94, 0.95, 0.97, 0.78)  ## The flight display's lines (UiKit.TEXT, a touch see-through).
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

	# Top left: the frame rate, when asked for. Speed and altitude are the tapes in the middle.
	var corner := _column(Vector2(0, 0), Vector2(28, 14), BoxContainer.ALIGNMENT_BEGIN)
	_fps = UiKit.outlined(UiKit.caption("", 13, UiKit.FAINT))
	corner.add_child(_fps)

	# Top right: the class, then station status and running effects.
	var item_column := _column(Vector2(1, 0), Vector2(-28, 18), BoxContainer.ALIGNMENT_BEGIN)
	var item_caption := UiKit.outlined(UiKit.caption(Airframe.spec(choppa.airframe).name, 14))
	item_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(item_caption)
	_effects = UiKit.outlined(UiKit.label("", 18, UiKit.MUTED, "condensed"))
	_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_column.add_child(_effects)
	_flight.append(item_column)

	# Bottom centre: afterburner charge (the gun's heat is in the ammo panel).
	var boost_column := _column(Vector2(0.5, 1), Vector2(0, -26), BoxContainer.ALIGNMENT_END)
	boost_column.add_theme_constant_override("separation", 6)
	var boost_caption := UiKit.outlined(UiKit.caption("Afterburner", 13))
	boost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_column.add_child(boost_caption)
	_boost = UiKit.Bar.new(300.0, 5.0)
	boost_column.add_child(_boost)
	_flight.append(boost_column)

	# Bottom right: what's left to shoot. Bottom left, over the hull: the radar.
	_ammo = HudAmmo.new(choppa)
	_place(_ammo, Vector2(1, 1), Vector2(-28, -26))
	_root.add_child(_ammo)
	_flight.append(_ammo)
	_radar = HudRadar.new(choppa)
	_place(_radar, Vector2(0, 1), Vector2(28, -112))
	_root.add_child(_radar)

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
	_place(_controls, CONTROLS_AT, CONTROLS_OFFSET)
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
	_place(_controls, CONTROLS_AT, CONTROLS_OFFSET)
	_root.add_child(_controls)
	_controls.visible = Settings.flag("show_controls")
	_fps.visible = Settings.flag("show_fps")


func _process(delta: float) -> void:
	# In the cockpit the instruments show all this; keep the screen clean.
	var cockpit := camera is ChaseCamera and (camera as ChaseCamera).first_person
	for control in _flight:
		control.visible = not cockpit
	_radar.visible = not cockpit and Settings.flag("hud_radar")
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_boost.set_value(choppa.boost_meter)
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
	var building: Choppa = choppa.lock_on if lock == null and choppa.lock_progress > 0.0 else null
	var boxed := target if target else (lock if lock else building)  # The guns' target, else the seeker's.
	if boxed != _bracketed:
		_bracketed = boxed
		_bracket_time = 0.0
	# Everything from the interpolated transforms the camera uses, or the symbols shake
	# against the picture at frame rates above the physics rate.
	if boxed and not camera.is_position_behind(_smooth(boxed)):
		_draw_brackets(camera.unproject_position(_smooth(boxed)), boxed, lock == boxed,
			choppa.lock_progress if boxed == choppa.lock_on else 0.0)
	var cockpit := camera is ChaseCamera and (camera as ChaseCamera).first_person
	if not cockpit and Settings.flag("hud_flight"):
		_draw_flight()
	# Where the guns cross on the nose line; on a target the guns snap onto it (and lead it).
	var body := choppa.get_global_transform_interpolated()
	var ahead := body.origin - body.basis.z * Choppa.GUN_CONVERGE
	if target:
		ahead = _smooth(target)
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
	var r := 6.0 + choppa.heat * 10.0  # The bloom, roughly as wide as the spread.
	_dot(c, 1.4, color)
	for k in 4:  # Four arcs on the diagonals, open at the cardinal points.
		var mid := PI * 0.25 + k * PI * 0.5
		_arc(c, r, mid - 0.45, mid + 0.45, color, 1.3)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		_line(c + d * (r + 3.0), c + d * (r + 8.0), color, 1.3)
	# Heat on the left, rounds on the right: thin arcs on a faint track.
	var track := Color(1, 1, 1, 0.16)
	var gauge := 22.0
	var heat_color := white.lerp(UiKit.ACCENT, smoothstep(0.3, 0.7, choppa.heat))
	if choppa.overheated or choppa.heat > 0.85:
		heat_color = UiKit.DANGER if fmod(choppa.clock, 0.3) < 0.18 else UiKit.ACCENT
	_crosshair.draw_arc(c, gauge, PI * 0.72, PI * 1.28, 24, track, 1.5, true)
	if choppa.heat > 0.01:
		_arc(c, gauge, PI * 1.28 - PI * 0.56 * choppa.heat, PI * 1.28, heat_color, 1.8)
	var rounds := float(choppa.ammo.gun) / maxf(1.0, choppa.full_ammo("gun"))
	_crosshair.draw_arc(c, gauge, -PI * 0.28, PI * 0.28, 24, track, 1.5, true)
	if rounds > 0.0:
		_arc(c, gauge, PI * 0.28 - PI * 0.56 * rounds, PI * 0.28, UiKit.ACCENT if rounds < 0.2 else Color(white, 0.7), 1.8)
	if hit:  # Hit marker: crisp diagonal ticks just outside the bloom.
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n := d.normalized()
			_line(c + n * (r + 3.0), c + n * (r + 9.0), Color.WHITE, 1.8)


## Corner brackets on the target, closing in when it is picked up. While the missile seeker
## builds its lock a thin diamond closes in from far out; locked, it sits tight and red.
func _draw_brackets(at: Vector2, target: Choppa, locked: bool, progress: float) -> void:
	_bracket_time += get_process_delta_time()
	var size := lerpf(32.0, 17.0, smoothstep(0.0, 0.25, _bracket_time))  # Closing in.
	var color := UiKit.DANGER if locked else UiKit.ACCENT
	var leg := size * 0.4
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := at + corner * size
		_line(p, p - Vector2(corner.x, 0.0) * leg, color, 1.2)
		_line(p, p - Vector2(0.0, corner.y) * leg, color, 1.2)
	if progress > 0.0:
		var reach := size * (0.8 if locked else lerpf(3.2, 0.8, progress))
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(at + Vector2.from_angle(k * PI * 0.5 - PI * 0.5) * reach)
		_crosshair.draw_polyline(pts, Color(0, 0, 0, 0.45), 2.8, true)
		_crosshair.draw_polyline(pts, color if locked else Color(UiKit.ACCENT, 0.5 + 0.5 * progress), 1.1, true)
	var label := "%s  %d m%s" % [target.pilot_name.to_upper(), roundi(choppa.global_position.distance_to(target.global_position)),
		"  ·  LOCK" if locked else ("  ·  LOCKING" if progress > 0.0 else "")]
	_text(at + Vector2(0.0, size + 15.0), label, 12, color, HORIZONTAL_ALIGNMENT_CENTER)


func _smooth(on: Choppa) -> Vector3:
	return on.get_global_transform_interpolated().origin


## Text on the sight layer with a dark outline, aligned left of, centred on or right of `at`.
func _text(at: Vector2, text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT,
		kind := "condensed") -> void:
	var font := UiKit.font(kind)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var shift := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		shift = width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		shift = width
	var spot := at - Vector2(shift, 0.0)
	_crosshair.draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.55))
	_crosshair.draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Pitch and bank of the airframe, in radians: nose up and right side down are positive.
static func attitude(on: Choppa) -> Vector2:
	var b := on.global_transform.basis
	var forward := -b.z
	return Vector2(asin(clampf(forward.y, -1.0, 1.0)), atan2(-b.x.y, b.y.y))


## The flight display round the middle of the chase view, the way a head-up display
## frames it: a heading tape over the top, the speed tape (km/h) left with the climb rate
## under it, the altitude tape (m above the ground) right, and between them a pitch
## ladder that tilts with the bank. Thin lines with a dark edge, nothing filled.
func _draw_flight() -> void:
	var view := _crosshair.size
	var h := view.y
	var c := Vector2(view.x * 0.5, h * 0.47)
	var w := h * 0.3  # Half the frame's width, and half its height.
	var half := h * 0.16
	var faint := Color(HUD_LINE, 0.4)
	# The pitch ladder: every 5 degrees, numbered every 10, the horizon long.
	var att := attitude(choppa)
	var pitch := rad_to_deg(att.x)
	var per_degree := half / 14.0
	var across := Vector2(1, 0).rotated(-att.y)
	for step in range(-18, 19):
		var deg := step * 5
		var offset := (pitch - deg) * per_degree
		if absf(offset) > half:
			continue
		var mid := c + Vector2(0, offset).rotated(-att.y)
		if deg == 0:
			_line(mid - across * w * 0.78, mid - across * w * 0.12, faint, 1.2)
			_line(mid + across * w * 0.12, mid + across * w * 0.78, faint, 1.2)
			continue
		var long := w * (0.42 if deg % 10 == 0 else 0.3)
		var gap := w * 0.14
		var tip := Vector2(0, 7 if deg > 0 else -7).rotated(-att.y)  # The ends turn toward the horizon.
		for side: float in [-1.0, 1.0]:
			var inner := mid + across * side * gap
			var outer := mid + across * side * long
			if deg > 0:
				_line(inner, outer, faint, 1.0)
			else:
				for k in 3:  # Below the horizon: dashed.
					_line(inner.lerp(outer, k / 3.0), inner.lerp(outer, k / 3.0 + 0.2), faint, 1.0)
			_line(outer, outer + tip, faint, 1.0)
			if deg % 10 == 0:
				_text(outer + across * side * 16.0 + Vector2(0, 5), str(absi(deg)), 12, faint, HORIZONTAL_ALIGNMENT_CENTER)
	# The waterline: the reference the ladder moves against.
	_line(c + Vector2(-16, 0), c + Vector2(-6, 0), HUD_LINE, 1.4)
	_line(c + Vector2(-6, 0), c + Vector2(-3, 4), HUD_LINE, 1.4)
	_line(c + Vector2(3, 4), c + Vector2(6, 0), HUD_LINE, 1.4)
	_line(c + Vector2(6, 0), c + Vector2(16, 0), HUD_LINE, 1.4)
	# Speed, left: a tape scrolling past a readout, the climb rate under it.
	var speed := choppa.velocity.length() * 3.6
	_tape(Vector2(c.x - w, c.y), half, speed, 10.0, half / 60.0, -1.0)
	_readout(Vector2(c.x - w - 10.0, c.y), str(roundi(speed)), -1.0)
	_text(Vector2(c.x - w - 12.0, c.y - 22.0), "KM/H", 11, faint, HORIZONTAL_ALIGNMENT_RIGHT)
	var climb := choppa.velocity.y
	_text(Vector2(c.x - w - 12.0, c.y + 36.0), "%+.1f m/s" % climb if absf(climb) >= 0.05 else "0.0 m/s", 14,
		UiKit.ACCENT if climb < -8.0 else HUD_LINE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Altitude, right.
	var altitude := maxf(choppa.altitude, 0.0)
	_tape(Vector2(c.x + w, c.y), half, altitude, 5.0, half / 40.0, 1.0)
	_readout(Vector2(c.x + w + 10.0, c.y), str(roundi(altitude)), 1.0)
	_text(Vector2(c.x + w + 12.0, c.y - 22.0), "ALT M", 11, faint)
	# Heading, over the top: ticks every 5 degrees, numbers every 15, the cardinal points.
	var heading := fposmod(-rad_to_deg(choppa.heading), 360.0)
	var top := c.y - half - 30.0
	var span := 40.0
	var per := w * 0.8 / span
	for d in range(int(heading - span) - 5, int(heading + span) + 6):
		if d % 5 != 0:
			continue
		var x := c.x + (d - heading) * per
		if absf(x - c.x) > w * 0.8:
			continue
		var long := d % 15 == 0
		_line(Vector2(x, top), Vector2(x, top + (8.0 if long else 4.0)), HUD_LINE if long else faint, 1.0)
		if long:
			var name: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(posmod(d, 360), str(posmod(d, 360)))
			var color := UiKit.ACCENT if name == "N" else (HUD_LINE if name.length() == 1 else faint)
			_text(Vector2(x, top - 5.0), name, 13 if name.length() == 1 else 12, color, HORIZONTAL_ALIGNMENT_CENTER)
	_line(Vector2(c.x, top + 12.0), Vector2(c.x - 5.0, top + 18.0), HUD_LINE, 1.4)  # The caret.
	_line(Vector2(c.x, top + 12.0), Vector2(c.x + 5.0, top + 18.0), HUD_LINE, 1.4)
	_text(Vector2(c.x, top + 34.0), "%03d" % (roundi(heading) % 360), 15, HUD_LINE, HORIZONTAL_ALIGNMENT_CENTER)


## A vertical tape with its middle at `at`, `half` tall each way, showing `value`:
## ticks every `step` (long ones every five), `scale` pixels per unit, on the side
## facing the middle (`side` -1 for the left tape, 1 for the right).
func _tape(at: Vector2, half: float, value: float, step: float, scale: float, side: float) -> void:
	var faint := Color(HUD_LINE, 0.4)
	_line(at + Vector2(0, -half), at + Vector2(0, half), faint, 1.0)
	var mark := floorf((value - half / scale) / step) * step
	while mark <= value + half / scale:
		var y := at.y + (value - mark) * scale
		if mark >= 0.0 and absf(y - at.y) <= half:
			var long := is_zero_approx(fmod(mark, step * 5.0))
			_line(Vector2(at.x, y), Vector2(at.x - side * (10.0 if long else 5.0), y), HUD_LINE if long else faint, 1.0)
		mark += step


## A readout box pointing at its tape: the number in a frame with an arrow tip at `tip`.
func _readout(tip: Vector2, text: String, side: float) -> void:
	var w := 64.0
	var hh := 14.0
	var back := tip + Vector2(side * (w + 8.0), 0)
	var points := PackedVector2Array([tip, tip + Vector2(side * 8.0, -hh), back + Vector2(0, -hh), back + Vector2(0, hh),
		tip + Vector2(side * 8.0, hh), tip])
	_crosshair.draw_colored_polygon(points.slice(0, 5), Color(0, 0, 0, 0.28))
	_crosshair.draw_polyline(points, Color(0, 0, 0, 0.45), 3.0, true)
	_crosshair.draw_polyline(points, HUD_LINE, 1.2, true)
	_text(tip + Vector2(side * (8.0 + w * 0.5), 8.0), text, 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, "display")


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
