class_name AbilityButton
extends Control
## A round action button with an icon, a cooldown sweep and a "ready" glow.

signal pressed

var icon_kind := "grenade"
var caption := ""
var color := Color("ffc21a")
## 0 = ready, 1 = just used. Set every frame by the HUD.
var cooldown := 0.0
## For charge-up abilities (the airstrike): 0..1 filled.
var charge := -1.0
var count_text := ""
var _down := false
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func ready_to_use() -> bool:
	return cooldown <= 0.0 and (charge < 0.0 or charge >= 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_down = true
			pressed.emit()
		else:
			_down = false
		accept_event()


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 4
	var ok := ready_to_use()
	var press := 0.92 if _down else 1.0
	r *= press
	if ok and (charge >= 0.0 or cooldown <= 0.0):
		var glow := 0.25 + 0.15 * sin(_pulse * 5.0)
		draw_circle(c, r + 8, Color(color, glow if charge >= 0.0 else 0.12))
	draw_circle(c, r, Color(0.05, 0.07, 0.09, 0.78))
	draw_circle(c, r - 5, Color(color.darkened(0.55), 0.85) if ok else Color(0.12, 0.14, 0.17, 0.85))
	draw_arc(c, r, 0, TAU, 64, Color(color, 0.95) if ok else Color(1, 1, 1, 0.25), 3.0, true)
	if charge >= 0.0 and charge < 1.0:
		draw_arc(c, r - 2, -PI / 2, -PI / 2 + TAU * charge, 64, color, 6.0, true)
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 40
		for i in steps + 1:
			var a := -PI / 2 + TAU * cooldown * float(i) / steps
			pts.append(c + Vector2.from_angle(a) * (r - 5))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var icon_size := r * 1.0
	_icon(c - Vector2(0, 4 if caption != "" else 0), icon_size, Color.WHITE if ok else Color(1, 1, 1, 0.45))
	if caption != "":
		var f := UI.bold()
		var fs := int(r * 0.42)
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(c.x - w / 2, c.y + r * 0.78), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(c.x - w / 2, c.y + r * 0.78), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if count_text != "":
		var f2 := UI.bold()
		draw_string_outline(f2, c + Vector2(-8, 8), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.7), 5, Color(0, 0, 0, 0.9))
		draw_string(f2, c + Vector2(-8, 8), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.7), Color.WHITE)


func _icon(at: Vector2, s: float, tint: Color) -> void:
	# Reuse the Icon drawing by drawing into this canvas with a transform.
	draw_set_transform(at - Vector2(s, s) / 2, 0.0, Vector2.ONE)
	_draw_icon_shape(Vector2(s, s), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_icon_shape(sz: Vector2, tint: Color) -> void:
	var s := minf(sz.x, sz.y)
	var c := sz / 2
	match icon_kind:
		"grenade":
			draw_circle(c + Vector2(0, s * 0.08), s * 0.3, tint)
			draw_rect(Rect2(c.x - s * 0.09, c.y - s * 0.34, s * 0.18, s * 0.14), tint)
			draw_arc(c + Vector2(s * 0.15, -s * 0.3), s * 0.1, 0, TAU, 16, tint, s * 0.05)
		"dash":
			for i in 3:
				var x := -s * 0.32 + i * s * 0.22
				draw_polyline(PackedVector2Array([c + Vector2(x, -s * 0.26), c + Vector2(x + s * 0.2, 0), c + Vector2(x, s * 0.26)]), Color(tint, tint.a * (0.4 + i * 0.3)), s * 0.09)
		"strike":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.1, -s * 0.08), c + Vector2(s * 0.42, s * 0.12), c + Vector2(s * 0.1, s * 0.1), c + Vector2(s * 0.07, s * 0.3), c + Vector2(s * 0.18, s * 0.4), c + Vector2(-s * 0.18, s * 0.4), c + Vector2(-s * 0.07, s * 0.3), c + Vector2(-s * 0.1, s * 0.1), c + Vector2(-s * 0.42, s * 0.12), c + Vector2(-s * 0.1, -s * 0.08)]), tint)
		"reload":
			draw_arc(c, s * 0.28, 0.4, TAU - 0.6, 24, tint, s * 0.08)
			var tip := c + Vector2.from_angle(0.4) * s * 0.28
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.14, -s * 0.02), tip + Vector2(s * 0.1, -s * 0.06), tip + Vector2(0, s * 0.14)]), tint)
		"whirl":
			for i in 3:
				draw_arc(c, s * (0.14 + i * 0.11), i * 2.1, i * 2.1 + 4.2, 20, tint, s * 0.06)
		"slam":
			draw_line(c + Vector2(-s * 0.36, s * 0.3), c + Vector2(s * 0.36, s * 0.3), tint, s * 0.08)
			for i in 3:
				var x := -s * 0.24 + i * s * 0.24
				draw_line(c + Vector2(x, s * 0.2), c + Vector2(x * 1.4, -s * 0.2), tint, s * 0.07)
			draw_circle(c + Vector2(0, -s * 0.28), s * 0.1, tint)
		"volley":
			for i in 5:
				var a := -PI / 2 + (i - 2) * 0.32
				draw_line(c + Vector2(0, s * 0.3), c + Vector2(0, s * 0.3) + Vector2.from_angle(a) * s * 0.6, tint, s * 0.05)
		"nova":
			for i in 8:
				var a := i * TAU / 8
				draw_line(c + Vector2.from_angle(a) * s * 0.12, c + Vector2.from_angle(a) * s * 0.42, tint, s * 0.07)
			draw_circle(c, s * 0.1, tint)
		"potion":
			draw_rect(Rect2(c.x - s * 0.07, c.y - s * 0.38, s * 0.14, s * 0.14), tint.darkened(0.3))
			draw_circle(c + Vector2(0, s * 0.08), s * 0.26, tint)
		_:
			draw_circle(c, s * 0.3, tint)
