class_name ClassCard
extends PanelContainer
## A helicopter class at a glance: its name, one line about it and five bars (speed,
## agility, armour, gun, ordnance) against the other classes. On the title screen and
## in the hangar, so the classes read apart before you fly them.

var _name: Label
var _blurb: Label
var _bars := {}  ## stat -> UiKit.Bar
var _values := {}  ## stat -> Label with the real number


func _init() -> void:
	add_theme_stylebox_override("panel", _style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(UiKit.caption("Helicopter", 13, UiKit.ACCENT))
	_name = UiKit.display("", 34)
	box.add_child(_name)
	_blurb = UiKit.label("", 14, UiKit.MUTED)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	_blurb.custom_minimum_size.x = 300.0
	box.add_child(_blurb)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 7)
	box.add_child(grid)
	for stat: String in Airframe.STATS:
		var label := UiKit.caption(stat, 13)
		label.custom_minimum_size.x = 84.0
		grid.add_child(label)
		var bar := UiKit.Bar.new(150.0, 6.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_bars[stat] = bar
		var value := UiKit.label("", 13, UiKit.MUTED)
		value.custom_minimum_size.x = 64.0
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		_values[stat] = value


func show_class(id: String) -> void:
	var spec := Airframe.spec(id)
	_name.text = (spec.name as String).to_upper()
	_blurb.text = spec.blurb
	var stats := Airframe.stats(id)
	for stat: String in Airframe.STATS:
		var bar: UiKit.Bar = _bars[stat]
		bar.value = stats[stat]
		bar.queue_redraw()
		(_values[stat] as Label).text = Airframe.stat_text(id, stat)


func _style() -> StyleBoxFlat:
	var s := UiKit.style(UiKit.PANEL, UiKit.LINE, 6)
	s.set_content_margin_all(18.0)
	return s
