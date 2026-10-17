class_name HudRadar
extends Control
## The chase view's radar, bottom left: heading up, rings every 100 m out to RANGE, other
## choppas as red arrows pointing where they fly (pinned to the rim when out of range),
## ready service stations, missiles in the air. Settings "hud_radar" turns it off.

const RANGE := 300.0
const RADIUS := 92.0

var choppa: Choppa


func _init(target: Choppa) -> void:
	choppa = target
	custom_minimum_size = Vector2.ONE * RADIUS * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Where something at `world` shows on a radar of radius `r` centred at `c`, seen from
## `me` (heading up). Clamped to the rim when out of range; `inside` says whether it fit.
static func project(me: Choppa, world: Vector3, c: Vector2, r: float) -> Dictionary:
	var local := me.facing().inverse() * (world - me.global_position)
	var flat := Vector2(local.x, local.z) / RANGE
	var inside := flat.length() <= 1.0
	return {"at": c + flat.limit_length(1.0) * r, "inside": inside}


func _draw() -> void:
	var c := size * 0.5
	var r := RADIUS - 4.0
	draw_circle(c, RADIUS, UiKit.PANEL)
	draw_arc(c, RADIUS, 0.0, TAU, 72, UiKit.LINE, 1.0, true)
	for k in [1.0 / 3.0, 2.0 / 3.0]:
		draw_arc(c, r * k, 0.0, TAU, 56, Color(1, 1, 1, 0.07), 1.0, true)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.06), 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1, 1, 1, 0.06), 1.0)
	if choppa == null or not choppa.is_inside_tree():
		return
	var font := UiKit.font("condensed")
	# The compass on the rim turns as you do: north, east, south, west.
	for k in 4:
		var a := -choppa.heading + k * PI * 0.5
		var dir := Vector2(-sin(a), -cos(a))
		var letter: String = ["N", "W", "S", "E"][k]
		var spot := c + dir * (r - 9.0) - Vector2(4.0, -5.0)
		draw_string(font, spot, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.ACCENT if k == 0 else UiKit.FAINT)
	for node in get_tree().get_nodes_in_group("stations"):
		var station := node as ServiceStation
		var spot := project(choppa, station.global_position, c, r)
		if spot.inside and station.is_ready():
			draw_rect(Rect2(spot.at - Vector2(4, 4), Vector2(8, 8)), Color(UiKit.GOOD, 0.8), false, 1.5)
	for node in get_tree().get_nodes_in_group("missiles"):
		var spot := project(choppa, (node as Node3D).global_position, c, r)
		if spot.inside:
			draw_circle(spot.at, 2.5, UiKit.ACCENT)
	for node in get_tree().get_nodes_in_group("choppas"):
		var other := node as Choppa
		if other == choppa or not other.alive:
			continue
		var spot := project(choppa, other.global_position, c, r)
		var turn := other.heading - choppa.heading  # Their nose, relative to ours.
		var color := UiKit.DANGER if spot.inside else Color(UiKit.DANGER, 0.45)
		_arrow(spot.at, -turn, 6.0 if spot.inside else 4.0, color)
	_arrow(c, 0.0, 7.0, UiKit.TEXT)  # Us, always nose up.
	draw_string(font, c + Vector2(-RADIUS + 6.0, RADIUS - 4.0), "%d m" % roundi(RANGE), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		UiKit.FAINT)


func _arrow(at: Vector2, angle: float, s: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.75, s * 0.8), Vector2(0, s * 0.35), Vector2(-s * 0.75, s * 0.8)])
	for k in points.size():
		points[k] = at + points[k].rotated(angle)
	draw_colored_polygon(points, color)
