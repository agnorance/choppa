class_name Hangar
extends Control
## The hangar on the title screen: your level and XP, a turntable of the helicopter in
## the camo you pick per class, the earned camos with what unlocks each, and the paid
## packs and the Apex skin (granted by the server once online play exists).

signal closed

var _airframe := Airframe.SCOUT
var _preview: ChoppaModel
var _card: ClassCard  ## The class's speed, armour and the rest over the turntable.
var _pivot: Node3D  ## Spins; the model sits on it centred on its length.
var _stage: Node3D
var _grid: GridContainer
var _detail: Label
var _first: Control


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_airframe = Airframe.ORDER[Settings.choice("airframe")]
	var profile := Progression.profile()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.anchor_left = 0.5
	columns.anchor_right = 0.5
	columns.anchor_top = 0.5
	columns.anchor_bottom = 0.5
	columns.grow_horizontal = Control.GROW_DIRECTION_BOTH
	columns.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(columns)

	# Left: pilot card and the camo list.
	var left := UiKit.panel(true, 24.0)
	left.custom_minimum_size = Vector2(520.0, 600.0)
	columns.add_child(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	left.add_child(box)
	box.add_child(UiKit.display("HANGAR", 36))
	var level_row := HBoxContainer.new()
	box.add_child(level_row)
	var level := UiKit.display("LEVEL %d" % profile.level(), 26, UiKit.ACCENT)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level)
	var stars := Progression.ace_stars(profile.xp)
	if stars > 0:
		level_row.add_child(UiKit.display("ACE x%d" % stars, 22, UiKit.ACCENT))
	var bar := UiKit.Bar.new(0.0, 5.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_value(Progression.level_progress(profile.xp))
	box.add_child(bar)
	var next := "Max level: Ace stars every %d XP" % Progression.ACE_STAR_XP if profile.level() >= Progression.MAX_LEVEL \
		else "%d / %d XP to level %d" % [profile.xp - Progression.total_xp_for(profile.level()),
			Progression.xp_for_level(profile.level()), profile.level() + 1]
	box.add_child(UiKit.label(next, 14, UiKit.MUTED))
	box.add_child(UiKit.label("%d matches  ·  %d wins  ·  %d kills  ·  %d parts wrecked" % [profile.stats.matches,
		profile.stats.wins, profile.stats.kills, profile.stats.parts], 14, UiKit.FAINT))
	box.add_child(_gap(8))
	var class_row := SettingRow.new("Helicopter", Airframe.names(), Airframe.ORDER.find(_airframe))
	class_row.changed.connect(func(i: int) -> void:
		_airframe = Airframe.ORDER[i]
		_rebuild_preview()
		_fill_grid())
	box.add_child(class_row)
	_first = class_row
	box.add_child(_gap(6))
	box.add_child(UiKit.caption("Camos", 13, UiKit.ACCENT))
	box.add_child(UiKit.rule())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 4)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_grid)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var back := UiKit.button("Back", 0.0)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)

	# Right: the turntable, then the packs and Apex.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	var view_panel := UiKit.panel(true, 6.0)
	right.add_child(view_panel)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(480.0, 300.0)
	container.stretch = true
	view_panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	_stage = Node3D.new()
	viewport.add_child(_stage)
	_build_stage(viewport)
	var overlay := Control.new()  # The class's bars over the bottom left of the turntable.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_panel.add_child(overlay)
	_card = ClassCard.new(true)
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 8.0
	_card.offset_bottom = -8.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(_card)
	_detail = UiKit.label("", 15, UiKit.MUTED)
	_detail.custom_minimum_size.x = 480.0
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_detail)
	right.add_child(_store_card())

	_rebuild_preview()
	_fill_grid()


func open() -> void:
	visible = true
	_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		closed.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pivot and visible:
		_pivot.rotate_y(delta * 0.4)


func _build_stage(viewport: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	for spec: Array in [[Vector3(-35.0, 40.0, 0.0), 2.2, Color(1.0, 0.9, 0.8)], [Vector3(-20.0, -140.0, 0.0), 0.8, Color(0.7, 0.8, 1.0)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		viewport.add_child(light)
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 5.5
	disc.bottom_radius = 5.5
	disc.height = 0.1
	disc.radial_segments = 48
	floor.mesh = disc
	floor.material_override = MapKit.material(Color(0.16, 0.17, 0.19))
	floor.position.y = -1.25
	viewport.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.position = Vector3(0.0, 1.9, 12.0)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, -1.0, 0.0))  # The model high in the frame: the class bars sit on the floor.


func _rebuild_preview() -> void:
	if _card:
		_card.show_class(_airframe)
	if _pivot:
		_pivot.queue_free()
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	_preview = ChoppaModel.new()
	_preview.airframe = _airframe
	_preview.silent = true
	_preview.camo = Progression.profile().camo_for(_airframe)
	_preview.color = Color(0.95, 0.5, 0.1)
	var size: float = Airframe.spec(_airframe).size
	# Every class the same size on the turntable, spun about the middle of its length
	# (nose about 2.5 m ahead of the mast, the tail rotor 5 to 7 m behind).
	_pivot.scale = Vector3.ONE / size
	_preview.position = Vector3(0.0, 0.0, Airframe.spec(_airframe).get("turntable", -1.6) * size)
	_pivot.add_child(_preview)
	_show_detail(_preview.camo)


func _fill_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var profile := Progression.profile()
	for id: String in Progression.ORDER:
		var camo: Dictionary = Progression.CAMOS[id]
		var owned := Progression.unlocked(id, profile.xp, profile.entitlements)
		var b := Button.new()
		b.custom_minimum_size = Vector2(230.0, 44.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiKit.font("text_medium"))
		b.add_theme_font_size_override("font_size", 16)
		b.text = "      " + camo.name
		if not owned:
			b.add_theme_color_override("font_color", UiKit.FAINT)
		if id == profile.camo_for(_airframe):
			b.add_theme_stylebox_override("normal", UiKit.style(Color(1, 1, 1, 0.05), UiKit.ACCENT))
		var swatch := ColorRect.new()
		swatch.color = (camo.colors[0] as Color).lerp(camo.colors[mini(1, camo.colors.size() - 1)], 0.35)
		swatch.custom_minimum_size = Vector2(18.0, 18.0)
		swatch.position = Vector2(12.0, 13.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			swatch.modulate.a = 0.35
		b.add_child(swatch)
		b.focus_entered.connect(_show_detail.bind(id))
		b.mouse_entered.connect(_show_detail.bind(id))
		b.pressed.connect(func() -> void:
			if profile.choose(_airframe, id):
				profile.save()
				_preview.set_camo(id)
				_fill_grid()
			else:
				_preview.set_camo(id)  # Locked: try it on, but it is not kept.
			_show_detail(id))
		_grid.add_child(b)


func _show_detail(id: String) -> void:
	var profile := Progression.profile()
	var camo: Dictionary = Progression.CAMOS[id]
	var owned := Progression.unlocked(id, profile.xp, profile.entitlements)
	var kind: String = {"level": "Earned", "ace": "Earned", "hangar": "Hangar Pack", "collector": "Collector Pack",
		"apex": "Apex"}[camo.tier]
	var text := "%s  ·  %s" % [camo.name.to_upper(), kind]
	text += "\n" + ("Unlocked. Click to fly it on the %s." % Airframe.spec(_airframe).name if owned
		else "Locked: %s. Click to preview." % Progression.requirement(id))
	if camo.tier == "apex":
		text += "\nOnly one pilot in the world wears this: whoever is #1 on the ranked leaderboard."
	_detail.text = text


## The two packs and Apex, explained; buying comes with the online store.
func _store_card() -> Control:
	var card := UiKit.panel(true, 18.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(UiKit.caption("Store  ·  style only, never power", 13, UiKit.ACCENT))
	for id: String in ["hangar", "collector"]:
		var pack: Dictionary = Progression.PACKS[id]
		var names := PackedStringArray()
		for camo_id: String in Progression.ORDER:
			if Progression.CAMOS[camo_id].tier == id:
				names.append(Progression.CAMOS[camo_id].name)
		var row := HBoxContainer.new()
		var label := UiKit.label("%s  ·  %s" % [pack.name, ", ".join(names) + (" + all of the Hangar Pack" if id == "collector" else "")],
			15, UiKit.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size.x = 360.0
		row.add_child(label)
		row.add_child(UiKit.label(pack.price, 15, UiKit.ACCENT, "condensed"))
		box.add_child(row)
	box.add_child(UiKit.label("Apex  ·  not for sale. Worn by the world's #1 ranked pilot.", 15, UiKit.TEXT))
	box.add_child(UiKit.label("Purchases and Apex open with online play.", 13, UiKit.FAINT))
	return card


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c
