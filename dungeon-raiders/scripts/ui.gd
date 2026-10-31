class_name UI
## The look of every menu and HUD: dark stone and bronze panels, gold trim,
## carved serif headings, built from code so it scales to any screen.

const BG := Color("0c0907")
const PANEL := Color(0.075, 0.06, 0.045, 0.9)
const PANEL_LIGHT := Color(0.14, 0.11, 0.08, 0.94)
const EDGE := Color("7a5a2e")
const TEXT := Color("f4ead6")
const MUTED := Color("a8987c")
const ACCENT := Color("e8b54a")
const ORANGE := Color("ff7a1a")
const RED := Color("ec4a3c")
const GREEN := Color("3fd16f")
const BLUE := Color("3aa4ff")
const PURPLE := Color("a56bff")

static var _body: Font
static var _bold: Font
static var _head: Font


static func body() -> Font:
	if _body == null:
		_body = _teko(500)
	return _body


static func bold() -> Font:
	if _bold == null:
		_bold = _teko(650)
	return _bold


static func head() -> Font:
	if _head == null:
		var v := FontVariation.new()
		v.base_font = load("res://assets/fonts/Cinzel.ttf")
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_head = v
	return _head


static func _teko(weight: int) -> Font:
	var v := FontVariation.new()
	v.base_font = load("res://assets/fonts/Teko.ttf")
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	v.variation_opentype = {tag: weight}
	return v


static func label(text: String, size: int = 28, color: Color = TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(2, size / 9))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 14))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func heading(text: String, size: int = 40, color: Color = TEXT) -> Label:
	return label(text, size, color, head())


static func box(color: Color, radius: int = 6, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s


## A glassy panel with a thin bright edge along the top, like a HUD card.
static func panel_style(color: Color = PANEL, accent: Color = EDGE) -> StyleBoxFlat:
	var s := box(color, 4, accent, 1)
	s.border_width_top = 2
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	return s


static func panel(color: Color = PANEL, accent: Color = EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, accent))
	return p


## A slanted button with a darker lip underneath so it looks pressable.
static func button(text: String, color: Color = ACCENT, size: Vector2 = Vector2(220, 64), font_size: int = 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	var dark := color.darkened(0.45)
	var text_color := Color("111418") if color.get_luminance() > 0.55 else TEXT
	b.add_theme_stylebox_override("normal", _button_box(color, dark, 5))
	b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.08), dark, 5))
	b.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.1), dark, 1))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.25, 0.28, 0.32), Color(0.12, 0.13, 0.15), 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.pivot_offset = size / 2
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2)
	b.button_down.connect(func() -> void:
		Sfx.play("click")
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
	b.button_up.connect(func() -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


static func _button_box(color: Color, lip: Color, lip_px: int) -> StyleBoxFlat:
	var s := box(color, 6, lip, 0)
	s.border_width_bottom = lip_px
	s.border_color = lip
	s.border_width_top = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 4
	s.content_margin_bottom = 2 + lip_px
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


## A dark ghost button used for secondary actions and tabs.
static func ghost(text: String, size: Vector2 = Vector2(180, 52), font_size: int = 28) -> Button:
	var b := button(text, Color(0.16, 0.2, 0.25), size, font_size)
	var edge := _button_box(Color(0.12, 0.15, 0.19, 0.92), Color(0.05, 0.06, 0.08), 4)
	edge.border_color = EDGE
	edge.border_width_left = 1
	edge.border_width_right = 1
	edge.border_width_top = 1
	b.add_theme_stylebox_override("normal", edge)
	return b


static func bar(color: Color, size: Vector2 = Vector2(200, 14)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = size
	p.show_percentage = false
	p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.55), 2, Color(1, 1, 1, 0.08), 1))
	p.add_theme_stylebox_override("fill", box(color, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func icon(kind: String, size: float = 28.0, color: Color = Color.WHITE) -> Icon:
	var i := Icon.new()
	i.kind = kind
	i.tint = color
	i.custom_minimum_size = Vector2(size, size)
	return i


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


## A currency chip: icon, amount and an optional "+".
static func chip(kind: String, amount: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(0, 0, 0, 0.55), 18, Color(1, 1, 1, 0.12), 1)
	s.content_margin_left = 8
	s.content_margin_right = 16
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var h := hbox(8)
	h.add_child(icon(kind, 30, color))
	var l := label(amount, 30)
	l.name = "Amount"
	h.add_child(l)
	p.add_child(h)
	return p


static func pop(c: Control, from: float = 0.6) -> void:
	c.pivot_offset = c.size / 2
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.18)


## A full-screen dim layer that blocks touches, for modal panels.
static func dim(alpha: float = 0.6) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.02, 0.03, 0.05, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
