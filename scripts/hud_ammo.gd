class_name HudAmmo
extends Control
## What's left to shoot, bottom right of the chase view: rounds with a bar and the gun's
## heat under it, then one icon per missile (amber while a lock is on), the rocket count,
## and pips for flares, mines and smoke. Spent ones stay as faint outlines, so you see
## at a glance what the next service will bring back.

const SIZE := Vector2(340, 104)

var choppa: Choppa


func _init(target: Choppa) -> void:
	choppa = target
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, SIZE)
	draw_rect(box, UiKit.PANEL)
	draw_rect(box, UiKit.LINE, false, 1.0)
	if choppa == null:
		return
	var a := choppa.ammo
	var caption := UiKit.spaced("condensed", 2)
	var display := UiKit.font("display")
	# The gun.
	var full := maxf(1.0, choppa.full_ammo("gun"))
	var low: bool = a.gun < full * 0.2
	draw_string(caption, Vector2(16, 24), "GUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.MUTED)
	draw_string(display, Vector2(14, 64), str(a.gun) if a.gun > 0 else "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 38,
		UiKit.DANGER if low else UiKit.TEXT)
	var bar := Rect2(16, 76, 112, 4)
	draw_rect(bar, UiKit.TRACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * a.gun / full, bar.size.y)), UiKit.DANGER if low else UiKit.TEXT)
	var heat_color := UiKit.DANGER if choppa.overheated else Color(UiKit.TEXT, 0.5).lerp(UiKit.ACCENT, smoothstep(0.4, 0.8, choppa.heat))
	draw_rect(Rect2(16, 85, 112, 2), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(16, 85, 112 * choppa.heat, 2), heat_color)
	draw_string(caption, Vector2(16, 98), "OVERHEAT" if choppa.overheated else "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		heat_color if choppa.overheated else UiKit.FAINT)
	draw_line(Vector2(146, 14), Vector2(146, SIZE.y - 14), UiKit.LINE, 1.0)
	# Missiles, one icon each.
	var x0 := 160.0
	draw_string(caption, Vector2(x0, 24), "MSL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.MUTED)
	var locked: bool = a.missiles > 0 and choppa.missile_target() != null
	var missiles := choppa.full_ammo("missiles")
	if missiles == 0:
		draw_string(caption, Vector2(x0 + 40, 24), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.FAINT)
	for k in missiles:
		var at := Vector2(x0 + 40 + (k % 2) * 70, 19 + (k / 2) * 16)
		var color := (UiKit.ACCENT if locked else UiKit.TEXT) if k < a.missiles else UiKit.FAINT
		_missile(at, 60.0, color, k < a.missiles)
	# Rockets: the count and a rocket.
	var rockets := choppa.full_ammo("rockets")
	var row := 62.0 if missiles <= 2 else 72.0
	draw_string(caption, Vector2(x0, row), "RKT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.MUTED)
	if rockets == 0:
		draw_string(caption, Vector2(x0 + 40, row), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.FAINT)
	else:
		draw_string(display, Vector2(x0 + 40, row + 2), str(a.rockets), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			UiKit.TEXT if a.rockets > 0 else UiKit.FAINT)
		for k in mini(rockets, 10):  # Tubes in the pod, filled as far as the count goes.
			var on := k < ceili(a.rockets * 10.0 / rockets)
			var tube := Vector2(x0 + 76 + k * 9, row - 8)
			if on:
				draw_circle(tube, 3.0, UiKit.TEXT)
			else:
				draw_arc(tube, 3.0, 0.0, TAU, 12, UiKit.FAINT, 1.0, true)
	# Flares, mines, smoke: pips.
	var spot := x0
	for entry: Array in [["FLR", "flares"], ["MINE", "mines"], ["SMK", "smoke"]]:
		var left: int = a[entry[1]]
		var total := maxi(choppa.full_ammo(entry[1]), left)
		draw_string(caption, Vector2(spot, 94), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.MUTED)
		var width := caption.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		for k in total:
			var pip := Rect2(spot + width + 6 + k * 7, 86, 4, 8)
			if k < left:
				draw_rect(pip, UiKit.TEXT)
			else:
				draw_rect(pip, UiKit.FAINT, false, 1.0)
		spot += width + 14 + total * 7


## A missile seen from the side, nose right, `length` long.
func _missile(at: Vector2, length: float, color: Color, filled: bool) -> void:
	var tail := at.x
	var nose := at.x + length
	var body := PackedVector2Array([Vector2(tail + 4, at.y - 2), Vector2(nose - 8, at.y - 2), Vector2(nose, at.y),
		Vector2(nose - 8, at.y + 2), Vector2(tail + 4, at.y + 2)])
	var fins := [PackedVector2Array([Vector2(tail, at.y - 6), Vector2(tail + 9, at.y - 2), Vector2(tail + 4, at.y - 2)]),
		PackedVector2Array([Vector2(tail, at.y + 6), Vector2(tail + 9, at.y + 2), Vector2(tail + 4, at.y + 2)]),
		PackedVector2Array([Vector2(nose - 22, at.y - 4), Vector2(nose - 16, at.y - 2), Vector2(nose - 24, at.y - 2)]),
		PackedVector2Array([Vector2(nose - 22, at.y + 4), Vector2(nose - 16, at.y + 2), Vector2(nose - 24, at.y + 2)])]
	if filled:
		draw_colored_polygon(body, color)
		for fin: PackedVector2Array in fins:
			draw_colored_polygon(fin, color)
	else:
		body.append(body[0])
		draw_polyline(body, color, 1.0, true)
		for fin: PackedVector2Array in fins:
			fin.append(fin[0])
			draw_polyline(fin, color, 1.0, true)
