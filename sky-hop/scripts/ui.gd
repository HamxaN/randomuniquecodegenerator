class_name UI
## The Clash-style look: chunky rounded buttons with a dark rim and a thick
## bottom lip, bold white lettering with black outlines, parchment panels with
## wooden borders, and pill-shaped resource bars.

const TEXT := Color("ffffff")
const INK := Color("2a1a0a")
const PARCHMENT := Color("f4e7c6")
const PARCHMENT_DARK := Color("e2cf9f")
const WOOD := Color("8b5a2b")
const WOOD_DARK := Color("4e2f12")
const GOLD := Color("ffd23a")
const WOOD_RES := Color("c98a3d")
const GEM := Color("4fe36b")
const GREEN := Color("62c63c")
const BLUE := Color("3f9de0")
const RED := Color("e6463a")
const ORANGE := Color("ff9a1f")
const PURPLE := Color("9b5ce0")
const GREY := Color("8a8f96")
const SKY := Color("bfe8ff")

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/LilitaOne.ttf")
	return _font


static func label(text: String, size: int = 28, color: Color = TEXT, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
		l.add_theme_constant_override("outline_size", maxi(4, size / 5))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 10))
		l.add_theme_constant_override("shadow_offset_x", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Dark text on parchment.
static func ink(text: String, size: int = 24) -> Label:
	var l := label(text, size, INK, false)
	return l


static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s


static func parchment_style() -> StyleBoxFlat:
	var s := box(PARCHMENT, 18, WOOD, 6)
	s.border_width_bottom = 10
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 20
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	return s


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", parchment_style())
	return p


## A card inside a parchment panel.
static func card_style(color: Color = PARCHMENT_DARK) -> StyleBoxFlat:
	var s := box(color, 14, color.darkened(0.25), 3)
	s.border_width_bottom = 6
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	return s


static func button(text: String, color: Color = GREEN, size: Vector2 = Vector2(220, 72), font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _button_box(color, 8))
	b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.07), 8))
	b.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.05), 3))
	b.add_theme_stylebox_override("disabled", _button_box(GREY, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, TEXT)
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	b.add_theme_constant_override("outline_size", maxi(5, font_size / 5))
	b.pivot_offset = size / 2
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2)
	b.button_down.connect(func() -> void:
		Sfx.play("click")
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.93, 0.93), 0.05))
	b.button_up.connect(func() -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


static func _button_box(color: Color, lip: int) -> StyleBoxFlat:
	var s := box(color, 16, Color(0.1, 0.07, 0.04), 3)
	s.border_width_bottom = lip
	s.border_color = color.darkened(0.5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 4
	s.content_margin_bottom = 2 + lip
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


## A big round button with an icon and a caption underneath, like ATTACK! and SHOP.
static func round_button(icon_kind: String, caption: String, color: Color, diameter: float = 120.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	var st := box(color, int(diameter / 2), color.darkened(0.55), 4)
	st.border_width_bottom = 9
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	var pressed := st.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 4
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := icon(icon_kind, diameter * 0.52)
	ic.position = Vector2(diameter * 0.24, diameter * 0.12)
	b.add_child(ic)
	if caption != "":
		var l := label(caption, int(diameter * 0.2))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(diameter + 40, 40)
		l.position = Vector2(-20, diameter * 0.64)
		b.add_child(l)
	b.pivot_offset = Vector2(diameter, diameter) / 2
	b.button_down.connect(func() -> void:
		Sfx.play("click")
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.05))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


static func icon(kind: String, size: float = 32.0, color: Color = Color.WHITE) -> Icon:
	var i := Icon.new()
	i.kind = kind
	i.tint = color
	i.custom_minimum_size = Vector2(size, size)
	i.size = Vector2(size, size)
	return i


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func bar(color: Color, size: Vector2 = Vector2(200, 18)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = size
	p.show_percentage = false
	p.add_theme_stylebox_override("background", box(Color(0.08, 0.06, 0.05, 0.8), int(size.y / 2), Color(0, 0, 0, 0.9), 2))
	var fill := box(color, int(size.y / 2))
	fill.border_color = color.lightened(0.35)
	fill.border_width_top = maxi(2, int(size.y / 5))
	p.add_theme_stylebox_override("fill", fill)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A pill-shaped resource counter with its icon on the right, as in the top-right HUD.
static func resource_bar(kind: String, color: Color, width: float = 230.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width + 30, 52)
	var b := bar(color, Vector2(width, 34))
	b.position = Vector2(0, 9)
	b.name = "Bar"
	holder.add_child(b)
	var l := label("0", 28)
	l.name = "Amount"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size = Vector2(width - 34, 40)
	l.position = Vector2(0, 5)
	holder.add_child(l)
	var ic := icon(kind, 52)
	ic.position = Vector2(width - 18, 0)
	holder.add_child(ic)
	return holder


static func pop(c: Control, from: float = 0.6) -> void:
	c.pivot_offset = c.size / 2
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.15)


static func dim(alpha: float = 0.55) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.03, 0.02, 0.01, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func time_text(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 3600:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %ds" % [s / 60, s % 60]
	return "%ds" % s


static func res_color(res: String) -> Color:
	return GOLD if res == "gold" else WOOD_RES
