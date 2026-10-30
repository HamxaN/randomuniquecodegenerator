class_name Icon
extends Control
## Small vector icons drawn in code, so they stay sharp at any size.

var kind := "coin":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var outline := Color(0, 0, 0, 0.6)
	match kind:
		"coin":
			draw_circle(c, s * 0.48, Color("7a4a06"))
			draw_circle(c, s * 0.42, tint)
			draw_circle(c, s * 0.3, tint.darkened(0.18))
			draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.2, s * 0.12, s * 0.4), tint.lightened(0.35))
		"xp":
			_star(c, s * 0.48, s * 0.22, tint, outline)
		"star":
			_star(c, s * 0.48, s * 0.21, tint, outline)
		"skull":
			draw_circle(c + Vector2(0, -s * 0.06), s * 0.36, tint)
			draw_rect(Rect2(c.x - s * 0.2, c.y + s * 0.1, s * 0.4, s * 0.26), tint)
			draw_circle(c + Vector2(-s * 0.14, -s * 0.06), s * 0.1, Color(0, 0, 0, 0.85))
			draw_circle(c + Vector2(s * 0.14, -s * 0.06), s * 0.1, Color(0, 0, 0, 0.85))
			for i in 3:
				draw_rect(Rect2(c.x - s * 0.13 + i * s * 0.1, c.y + s * 0.2, s * 0.05, s * 0.16), Color(0, 0, 0, 0.7))
		"heart":
			draw_circle(c + Vector2(-s * 0.18, -s * 0.1), s * 0.22, tint)
			draw_circle(c + Vector2(s * 0.18, -s * 0.1), s * 0.22, tint)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.39, -s * 0.02), c + Vector2(s * 0.39, -s * 0.02), c + Vector2(0, s * 0.42)]), tint)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.08, -s * 0.48), c + Vector2(-s * 0.3, s * 0.06), c + Vector2(-s * 0.02, s * 0.06),
				c + Vector2(-s * 0.1, s * 0.48), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)]), tint)
		"grenade":
			draw_circle(c + Vector2(0, s * 0.08), s * 0.34, tint)
			draw_rect(Rect2(c.x - s * 0.1, c.y - s * 0.4, s * 0.2, s * 0.16), tint.darkened(0.3))
			draw_arc(c + Vector2(s * 0.16, -s * 0.34), s * 0.12, 0, TAU, 16, tint.lightened(0.3), s * 0.05)
			for i in 3:
				draw_line(c + Vector2(-s * 0.3, s * (-0.04 + i * 0.13)), c + Vector2(s * 0.3, s * (-0.04 + i * 0.13)), Color(0, 0, 0, 0.35), s * 0.04)
		"dash":
			for i in 3:
				var x := -s * 0.36 + i * s * 0.26
				draw_polyline(PackedVector2Array([c + Vector2(x, -s * 0.3), c + Vector2(x + s * 0.24, 0), c + Vector2(x, s * 0.3)]), Color(tint, 0.45 + i * 0.27), s * 0.1)
		"strike":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.48), c + Vector2(s * 0.12, -s * 0.1), c + Vector2(s * 0.46, s * 0.12), c + Vector2(s * 0.12, s * 0.12), c + Vector2(s * 0.08, s * 0.36), c + Vector2(s * 0.2, s * 0.46), c + Vector2(-s * 0.2, s * 0.46), c + Vector2(-s * 0.08, s * 0.36), c + Vector2(-s * 0.12, s * 0.12), c + Vector2(-s * 0.46, s * 0.12), c + Vector2(-s * 0.12, -s * 0.1)]), tint)
		"pause":
			draw_rect(Rect2(c.x - s * 0.28, c.y - s * 0.32, s * 0.2, s * 0.64), tint)
			draw_rect(Rect2(c.x + s * 0.08, c.y - s * 0.32, s * 0.2, s * 0.64), tint)
		"lock":
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.2, PI, TAU, 16, tint, s * 0.09)
			draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.1, s * 0.6, s * 0.48), tint)
		"user":
			draw_circle(c + Vector2(0, -s * 0.16), s * 0.2, tint)
			draw_circle(c + Vector2(0, s * 0.42), s * 0.36, tint)
		"gun":
			draw_rect(Rect2(c.x - s * 0.46, c.y - s * 0.16, s * 0.9, s * 0.18), tint)
			draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.02, s * 0.16, s * 0.34), tint)
			draw_rect(Rect2(c.x - s * 0.04, c.y, s * 0.12, s * 0.24), tint.darkened(0.2))
			draw_rect(Rect2(c.x + s * 0.2, c.y - s * 0.26, s * 0.1, s * 0.1), tint)
		"map":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.44, -s * 0.3), c + Vector2(-s * 0.14, -s * 0.4), c + Vector2(s * 0.14, -s * 0.3), c + Vector2(s * 0.44, -s * 0.4), c + Vector2(s * 0.44, s * 0.3), c + Vector2(s * 0.14, s * 0.4), c + Vector2(-s * 0.14, s * 0.3), c + Vector2(-s * 0.44, s * 0.4)]), tint)
			draw_circle(c + Vector2(s * 0.05, -s * 0.02), s * 0.1, Color("ec4a3c"))
		"trophy":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.3, -s * 0.4), c + Vector2(s * 0.2, s * 0.05), c + Vector2(-s * 0.2, s * 0.05)]), tint)
			draw_rect(Rect2(c.x - s * 0.06, c.y + s * 0.05, s * 0.12, s * 0.2), tint.darkened(0.2))
			draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.25, s * 0.48, s * 0.14), tint)
			draw_arc(c + Vector2(-s * 0.3, -s * 0.2), s * 0.12, PI * 0.5, PI * 1.5, 10, tint, s * 0.06)
			draw_arc(c + Vector2(s * 0.3, -s * 0.2), s * 0.12, -PI * 0.5, PI * 0.5, 10, tint, s * 0.06)
		"gear":
			for i in 8:
				var a := i * TAU / 8
				draw_line(c + Vector2.from_angle(a) * s * 0.2, c + Vector2.from_angle(a) * s * 0.46, tint, s * 0.16)
			draw_circle(c, s * 0.32, tint)
			draw_circle(c, s * 0.13, Color(0.1, 0.12, 0.15))
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.42, 0), c + Vector2(-s * 0.3, s * 0.4)]), tint)
		"ad":
			draw_rect(Rect2(c.x - s * 0.46, c.y - s * 0.32, s * 0.92, s * 0.64), tint)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.12, -s * 0.18), c + Vector2(s * 0.2, 0), c + Vector2(-s * 0.12, s * 0.18)]), Color(0.08, 0.1, 0.12))
		"plus":
			draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.36, s * 0.16, s * 0.72), tint)
			draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.08, s * 0.72, s * 0.16), tint)
		"close":
			draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.3), tint, s * 0.14)
			draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(-s * 0.3, s * 0.3), tint, s * 0.14)
		"arrow_l":
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.16, -s * 0.36), c + Vector2(-s * 0.2, 0), c + Vector2(s * 0.16, s * 0.36)]), tint, s * 0.14)
		"arrow_r":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.16, -s * 0.36), c + Vector2(s * 0.2, 0), c + Vector2(-s * 0.16, s * 0.36)]), tint, s * 0.14)
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.38, -s * 0.3), c + Vector2(s * 0.3, s * 0.14), c + Vector2(0, s * 0.46), c + Vector2(-s * 0.3, s * 0.14), c + Vector2(-s * 0.38, -s * 0.3)]), tint)
		_:
			draw_circle(c, s * 0.4, tint)


func _star(c: Vector2, r1: float, r2: float, color: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r1 if i % 2 == 0 else r2))
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, edge, maxf(1.0, r1 * 0.08))
