class_name UiKit
extends RefCounted
## The look of every 2D control: dark translucent panels, thin lines, one amber accent
## (the cockpit's), condensed numerals. One Theme shared by every layer, plus helpers
## for the handful of controls the game uses.

const TEXT := Color(0.94, 0.95, 0.97)
const MUTED := Color(0.94, 0.95, 0.97, 0.55)
const FAINT := Color(0.94, 0.95, 0.97, 0.28)
const ACCENT := Color(1.0, 0.62, 0.2)
const DANGER := Color(1.0, 0.33, 0.3)
const GOOD := Color(0.45, 0.9, 0.5)
const INK := Color(0.07, 0.08, 0.1)  ## Text on an accent fill.
const PANEL := Color(0.05, 0.06, 0.08, 0.72)
const PANEL_SOLID := Color(0.06, 0.07, 0.09, 0.96)
const LINE := Color(1, 1, 1, 0.1)
const HOVER := Color(1, 1, 1, 0.06)
const TRACK := Color(1, 1, 1, 0.14)  ## Empty part of a bar.

static var _theme: Theme
static var _fonts := {}


## "display": condensed semibold for titles and readouts; "condensed": condensed medium
## for labels; "text" / "text_medium": regular widths for sentences and key names.
static func font(kind: String) -> Font:
	if not _fonts.has(kind):
		var path := {
			"display": "res://assets/fonts/BarlowCondensed-SemiBold.ttf",
			"condensed": "res://assets/fonts/BarlowCondensed-Medium.ttf",
			"text": "res://assets/fonts/Barlow-Regular.ttf",
			"text_medium": "res://assets/fonts/Barlow-Medium.ttf",
		}[kind] as String
		_fonts[kind] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[kind]


## A font with letter spacing, for small capitals.
static func spaced(kind: String, spacing := 1) -> Font:
	var key := "%s+%d" % [kind, spacing]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = font(kind)
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("text")
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", style(PANEL, LINE))

	t.set_font("font", "Button", spaced("condensed", 1))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", style(Color(1, 1, 1, 0.03), LINE))
	t.set_stylebox("hover", "Button", style(HOVER, Color(1, 1, 1, 0.2)))
	t.set_stylebox("pressed", "Button", style(ACCENT, ACCENT))
	t.set_stylebox("hover_pressed", "Button", style(ACCENT, ACCENT))
	var focus := style(Color(0, 0, 0, 0), ACCENT, 4, 0)
	focus.border_width_left = 3
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", style(Color(1, 1, 1, 0.02), LINE))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", FAINT)

	t.set_font("font", "LineEdit", font("condensed"))
	t.set_font_size("font_size", "LineEdit", 22)
	t.set_stylebox("normal", "LineEdit", style(Color(1, 1, 1, 0.03), LINE))
	t.set_stylebox("focus", "LineEdit", style(Color(0, 0, 0, 0), ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	_theme = t
	return t


static func style(bg: Color, border := Color(0, 0, 0, 0), radius := 4, border_width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_width if border.a > 0.0 else 0)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


static func label(text: String, size := 18, color := TEXT, kind := "text") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Small spaced capitals: the caption above a value or a section.
static func caption(text: String, size := 14, color := MUTED) -> Label:
	var l := label(text.to_upper(), size, color, "condensed")
	l.add_theme_font_override("font", spaced("condensed", 2))
	return l


## A big readout number or title.
static func display(text: String, size := 40, color := TEXT) -> Label:
	return label(text, size, color, "display")


## The CHOPPA wordmark (assets/brand, made by tools/brand/make_brand.py), `width` px wide.
static func logo(width: float) -> TextureRect:
	var texture: Texture2D = load("res://assets/brand/logo_wordmark.png")
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.custom_minimum_size = Vector2(width, width * texture.get_height() / texture.get_width())
	rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Text drawn straight over the 3D view gets a soft dark outline to stay readable.
static func outlined(l: Label, strength := 0.75) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, strength))
	l.add_theme_constant_override("outline_size", maxi(3, l.get_theme_font_size("font_size") / 7))
	return l


static func button(text: String, min_width := 320.0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(min_width, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


static func panel(solid := false, margin := 24.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(PANEL_SOLID if solid else PANEL, LINE, 6)
	s.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", s)
	return p


## A key name in a small box, as in a manual.
static func keycap(text: String) -> Label:
	var l := label(text, 14, TEXT, "text_medium")
	var s := style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.22), 3)
	s.content_margin_left = 7.0
	s.content_margin_right = 7.0
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	l.add_theme_stylebox_override("normal", s)
	l.custom_minimum_size.x = 26.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A thin horizontal line, the divider between sections.
static func rule(color := LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A thin meter: a rounded track with a coloured fill, no chrome.
class Bar extends Control:
	var value := 1.0
	var color := UiKit.ACCENT
	var track := UiKit.TRACK

	func _init(width := 240.0, height := 5.0) -> void:
		custom_minimum_size = Vector2(width, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := int(size.y * 0.5)
		draw_style_box(UiKit.style(track, Color(0, 0, 0, 0), radius), Rect2(Vector2.ZERO, size))
		var w := size.x * clampf(value, 0.0, 1.0)
		if w > 0.0:
			draw_style_box(UiKit.style(color, Color(0, 0, 0, 0), radius),
				Rect2(Vector2.ZERO, Vector2(maxf(w, size.y), size.y)))

	func set_value(v: float, c := color) -> void:
		if v != value or c != color:
			value = v
			color = c
			queue_redraw()
