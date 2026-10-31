class_name Icon
extends Control
## Chunky outlined cartoon icons drawn in code: gold, wood, gems, swords and more.

var kind := "gold":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

const EDGE := Color(0.12, 0.07, 0.03)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _poly(points: Array, color: Color, outline: float) -> void:
	var p := PackedVector2Array(points)
	if outline > 0.0:
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, EDGE, outline * 2.0, true)
	draw_colored_polygon(p, color)


func _disc(c: Vector2, r: float, color: Color, outline: float) -> void:
	if outline > 0.0:
		draw_circle(c, r + outline, EDGE)
	draw_circle(c, r, color)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var o := maxf(1.5, s * 0.05)
	var t := tint
	match kind:
		"gold":
			for i in 3:
				var cc := c + Vector2(-s * 0.12 + i * s * 0.12, s * 0.14 - i * s * 0.14)
				_disc(cc, s * 0.27, Color("e09a12"), o)
				_disc(cc, s * 0.21, Color("ffd23a"), 0)
				draw_rect(Rect2(cc.x - s * 0.04, cc.y - s * 0.12, s * 0.08, s * 0.24), Color("fff1a8"))
		"wood":
			for i in 2:
				var y := c.y - s * 0.12 + i * s * 0.26
				var x0 := c.x - s * 0.4 + i * s * 0.06
				draw_rect(Rect2(x0 - o, y - s * 0.13 - o, s * 0.74 + o * 2, s * 0.26 + o * 2), EDGE)
				draw_rect(Rect2(x0, y - s * 0.13, s * 0.74, s * 0.26), Color("a8642a"))
				draw_rect(Rect2(x0, y - s * 0.13, s * 0.74, s * 0.07), Color("c98a3d"))
				_disc(Vector2(x0 + s * 0.74, y), s * 0.13, Color("e9c27f"), o * 0.6)
				draw_arc(Vector2(x0 + s * 0.74, y), s * 0.06, 0, TAU, 12, Color("a8642a"), s * 0.03)
		"gem":
			_poly([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.36, -s * 0.12), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.36, -s * 0.12)], Color("2fbf4f"), o)
			_poly([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.36, -s * 0.12), c + Vector2(0, -s * 0.02), c + Vector2(-s * 0.36, -s * 0.12)], Color("8ff2a2"), 0)
		"sword", "attack":
			for side in [-1.0, 1.0]:
				var a := Vector2(c.x - s * 0.36 * side, c.y + s * 0.36)
				var b := Vector2(c.x + s * 0.34 * side, c.y - s * 0.36)
				draw_line(a, b, EDGE, s * 0.2)
				draw_line(a, b, Color("e8eef2"), s * 0.12)
				var hilt := a.lerp(b, 0.25)
				var perp := (b - a).normalized().orthogonal() * s * 0.16
				draw_line(hilt - perp, hilt + perp, EDGE, s * 0.14)
				draw_line(hilt - perp, hilt + perp, Color("ffc23a"), s * 0.08)
		"hammer", "shop":
			draw_line(c + Vector2(-s * 0.3, s * 0.36), c + Vector2(s * 0.12, -s * 0.08), EDGE, s * 0.2)
			draw_line(c + Vector2(-s * 0.3, s * 0.36), c + Vector2(s * 0.12, -s * 0.08), Color("b8793a"), s * 0.11)
			_poly([c + Vector2(-s * 0.04, -s * 0.36), c + Vector2(s * 0.22, -s * 0.42), c + Vector2(s * 0.42, -s * 0.12), c + Vector2(s * 0.24, s * 0.02)], Color("a9b4bd"), o)
		"army", "helmet":
			_poly([c + Vector2(-s * 0.36, s * 0.2), c + Vector2(-s * 0.32, -s * 0.12), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.32, -s * 0.12), c + Vector2(s * 0.36, s * 0.2)], Color("b9c4cc"), o)
			draw_rect(Rect2(c.x - s * 0.36, c.y + s * 0.08, s * 0.72, s * 0.14), Color("8e9aa4"))
			draw_rect(Rect2(c.x - s * 0.05, c.y - s * 0.4, s * 0.1, s * 0.5), Color("e6463a"))
		"star":
			var pts: Array = []
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2.from_angle(a) * (s * 0.46 if i % 2 == 0 else s * 0.2))
			_poly(pts, t if t != Color.WHITE else Color("ffd23a"), o)
		"star_empty":
			var pts2: Array = []
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts2.append(c + Vector2.from_angle(a) * (s * 0.46 if i % 2 == 0 else s * 0.2))
			_poly(pts2, Color(0.25, 0.22, 0.2, 0.85), o)
		"shield":
			_poly([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.38, -s * 0.28), c + Vector2(s * 0.3, s * 0.16), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.3, s * 0.16), c + Vector2(-s * 0.38, -s * 0.28)], t if t != Color.WHITE else Color("3f9de0"), o)
		"clock":
			_disc(c, s * 0.4, Color("f4e7c6"), o)
			draw_line(c, c + Vector2(0, -s * 0.26), EDGE, s * 0.08)
			draw_line(c, c + Vector2(s * 0.18, 0), EDGE, s * 0.08)
		"trophy":
			_poly([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.3, -s * 0.4), c + Vector2(s * 0.18, s * 0.06), c + Vector2(-s * 0.18, s * 0.06)], Color("ffc23a"), o)
			draw_rect(Rect2(c.x - s * 0.06, c.y + s * 0.04, s * 0.12, s * 0.18), Color("d99a1a"))
			draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.22, s * 0.48, s * 0.16), Color("8b5a2b"))
		"up":
			_poly([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.38, 0), c + Vector2(s * 0.14, 0), c + Vector2(s * 0.14, s * 0.4), c + Vector2(-s * 0.14, s * 0.4), c + Vector2(-s * 0.14, 0), c + Vector2(-s * 0.38, 0)], Color("62c63c"), o)
		"info":
			_disc(c, s * 0.4, Color("3f9de0"), o)
			draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.06, s * 0.12, s * 0.28), Color.WHITE)
			draw_circle(c + Vector2(0, -s * 0.2), s * 0.07, Color.WHITE)
		"close":
			_disc(c, s * 0.42, Color("e6463a"), o)
			draw_line(c + Vector2(-s * 0.18, -s * 0.18), c + Vector2(s * 0.18, s * 0.18), Color.WHITE, s * 0.12)
			draw_line(c + Vector2(s * 0.18, -s * 0.18), c + Vector2(-s * 0.18, s * 0.18), Color.WHITE, s * 0.12)
		"home":
			_poly([c + Vector2(-s * 0.4, 0), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0)], Color("e6463a"), o)
			_poly([c + Vector2(-s * 0.28, 0), c + Vector2(s * 0.28, 0), c + Vector2(s * 0.28, s * 0.38), c + Vector2(-s * 0.28, s * 0.38)], Color("f4e7c6"), o)
		"ad":
			_poly([c + Vector2(-s * 0.42, -s * 0.28), c + Vector2(s * 0.42, -s * 0.28), c + Vector2(s * 0.42, s * 0.28), c + Vector2(-s * 0.42, s * 0.28)], Color("ffd23a"), o)
			_poly([c + Vector2(-s * 0.1, -s * 0.15), c + Vector2(s * 0.16, 0), c + Vector2(-s * 0.1, s * 0.15)], EDGE, 0)
		"lock":
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 16, EDGE, s * 0.12)
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 16, Color("b9c4cc"), s * 0.07)
			_poly([c + Vector2(-s * 0.3, -s * 0.08), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.3, s * 0.38), c + Vector2(-s * 0.3, s * 0.38)], Color("ffc23a"), o)
		"builder":
			_disc(c + Vector2(0, s * 0.06), s * 0.3, Color("f2c79a"), o)
			_poly([c + Vector2(-s * 0.36, -s * 0.04), c + Vector2(-s * 0.26, -s * 0.36), c + Vector2(s * 0.26, -s * 0.36), c + Vector2(s * 0.36, -s * 0.04)], Color("ffd23a"), o)
		"collect":
			_disc(c, s * 0.42, Color(1, 1, 1, 0.95), o)
		_:
			_disc(c, s * 0.4, t, o)
