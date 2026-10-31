class_name Icon
extends Control
## Chunky outlined cartoon icons drawn in code: credits, power, ore, crystals and more.

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
		"burger":
			_poly([c + Vector2(-s * 0.4, -s * 0.02), c + Vector2(-s * 0.36, -s * 0.3), c + Vector2(0, -s * 0.42), c + Vector2(s * 0.36, -s * 0.3), c + Vector2(s * 0.4, -s * 0.02)], Color("f2a43a"), o)
			_poly([c + Vector2(-s * 0.44, s * 0.02), c + Vector2(s * 0.44, s * 0.02), c + Vector2(s * 0.36, s * 0.12), c + Vector2(-s * 0.36, s * 0.12)], Color("6cc04a"), o * 0.6)
			_poly([c + Vector2(-s * 0.42, s * 0.12), c + Vector2(s * 0.42, s * 0.12), c + Vector2(s * 0.42, s * 0.24), c + Vector2(-s * 0.42, s * 0.24)], Color("7a3d1e"), o * 0.6)
			_poly([c + Vector2(-s * 0.4, s * 0.26), c + Vector2(s * 0.4, s * 0.26), c + Vector2(s * 0.34, s * 0.4), c + Vector2(-s * 0.34, s * 0.4)], Color("e8932e"), o)
			for k in 3:
				draw_circle(c + Vector2(-s * 0.16 + k * s * 0.16, -s * 0.24 + (k % 2) * s * 0.05), s * 0.03, Color("fff3d0"))
		"patty":
			_poly([c + Vector2(-s * 0.42, -s * 0.12), c + Vector2(s * 0.42, -s * 0.12), c + Vector2(s * 0.42, s * 0.14), c + Vector2(-s * 0.42, s * 0.14)], Color("7a3d1e"), o)
			for k in 4:
				draw_line(c + Vector2(-s * 0.3 + k * s * 0.2, -s * 0.1), c + Vector2(-s * 0.36 + k * s * 0.2, s * 0.12), Color("4a2410"), s * 0.05)
		"fries":
			for k in 5:
				var x := c.x - s * 0.22 + k * s * 0.11
				draw_rect(Rect2(x - s * 0.04 - o * 0.5, c.y - s * 0.42 - o * 0.5 + (k % 2) * s * 0.08, s * 0.08 + o, s * 0.4 + o), EDGE)
				draw_rect(Rect2(x - s * 0.04, c.y - s * 0.42 + (k % 2) * s * 0.08, s * 0.08, s * 0.4), Color("ffd23a"))
			_poly([c + Vector2(-s * 0.32, -s * 0.06), c + Vector2(s * 0.32, -s * 0.06), c + Vector2(s * 0.24, s * 0.44), c + Vector2(-s * 0.24, s * 0.44)], Color("e6463a"), o)
			draw_circle(c + Vector2(0, s * 0.16), s * 0.1, Color("ffd23a"))
		"drink":
			draw_line(c + Vector2(s * 0.06, -s * 0.3), c + Vector2(s * 0.18, -s * 0.46), EDGE, s * 0.1)
			draw_line(c + Vector2(s * 0.06, -s * 0.3), c + Vector2(s * 0.18, -s * 0.46), Color("ffffff"), s * 0.05)
			_poly([c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, -s * 0.3), c + Vector2(s * 0.22, s * 0.44), c + Vector2(-s * 0.22, s * 0.44)], Color("3f9de0"), o)
			draw_rect(Rect2(c.x - s * 0.27, c.y - s * 0.08, s * 0.54, s * 0.14), Color("ffffff"))
			_poly([c + Vector2(-s * 0.34, -s * 0.38), c + Vector2(s * 0.34, -s * 0.38), c + Vector2(s * 0.34, -s * 0.28), c + Vector2(-s * 0.34, -s * 0.28)], Color("e6463a"), o * 0.6)
		"flame":
			_poly([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.3, -s * 0.02), c + Vector2(s * 0.26, s * 0.3), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.26, s * 0.3), c + Vector2(-s * 0.3, -s * 0.02), c + Vector2(-s * 0.1, -s * 0.1)], Color("ff7a1a"), o)
			_poly([c + Vector2(0, -s * 0.08), c + Vector2(s * 0.14, s * 0.18), c + Vector2(0, s * 0.34), c + Vector2(-s * 0.14, s * 0.18)], Color("ffd23a"), 0)
		"plate":
			draw_set_transform(c, 0, Vector2(1, 0.55))
			draw_circle(Vector2.ZERO, s * 0.44 + o, EDGE)
			draw_circle(Vector2.ZERO, s * 0.44, Color("f4f4f4"))
			draw_circle(Vector2.ZERO, s * 0.28, Color("dcdcdc"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"shoe":
			_poly([c + Vector2(-s * 0.4, -s * 0.2), c + Vector2(-s * 0.1, -s * 0.2), c + Vector2(s * 0.02, 0), c + Vector2(s * 0.4, s * 0.08), c + Vector2(s * 0.42, s * 0.26), c + Vector2(-s * 0.4, s * 0.26)], Color("e6463a"), o)
			draw_rect(Rect2(c.x - s * 0.4, c.y + s * 0.18, s * 0.82, s * 0.08), Color("ffffff"))
		"heart":
			var hp: Array = []
			for i in 24:
				var a := TAU * i / 24.0
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
				hp.append(c + Vector2(x, y) * s * 0.026)
			_poly(hp, t if t != Color.WHITE else Color("ff4f6d"), o)
		"trash":
			_poly([c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(s * 0.3, -s * 0.2), c + Vector2(s * 0.24, s * 0.42), c + Vector2(-s * 0.24, s * 0.42)], Color("8a8f96"), o)
			_poly([c + Vector2(-s * 0.38, -s * 0.34), c + Vector2(s * 0.38, -s * 0.34), c + Vector2(s * 0.38, -s * 0.22), c + Vector2(-s * 0.38, -s * 0.22)], Color("b9c4cc"), o)
		"pause":
			_disc(c, s * 0.44, Color("3f9de0"), o)
			draw_rect(Rect2(c.x - s * 0.17, c.y - s * 0.2, s * 0.12, s * 0.4), Color.WHITE)
			draw_rect(Rect2(c.x + s * 0.05, c.y - s * 0.2, s * 0.12, s * 0.4), Color.WHITE)
		"chef":
			_disc(c + Vector2(0, s * 0.14), s * 0.26, Color("f2c79a"), o)
			_disc(c + Vector2(-s * 0.16, -s * 0.24), s * 0.16, Color.WHITE, o)
			_disc(c + Vector2(s * 0.16, -s * 0.24), s * 0.16, Color.WHITE, o)
			_disc(c + Vector2(0, -s * 0.32), s * 0.18, Color.WHITE, o)
			draw_rect(Rect2(c.x - s * 0.24, c.y - s * 0.2, s * 0.48, s * 0.14), Color.WHITE)
		"check":
			_disc(c, s * 0.42, Color("62c63c"), o)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.2, 0), c + Vector2(-s * 0.04, s * 0.16), c + Vector2(s * 0.22, -s * 0.16)]), Color.WHITE, s * 0.1)
		"sound":
			_poly([c + Vector2(-s * 0.36, -s * 0.12), c + Vector2(-s * 0.16, -s * 0.12), c + Vector2(s * 0.08, -s * 0.34), c + Vector2(s * 0.08, s * 0.34), c + Vector2(-s * 0.16, s * 0.12), c + Vector2(-s * 0.36, s * 0.12)], Color.WHITE, o)
			draw_arc(c + Vector2(s * 0.1, 0), s * 0.22, -0.9, 0.9, 10, Color.WHITE if t == Color.WHITE else t, s * 0.07)
		"cheese":
			_poly([c + Vector2(-s * 0.4, s * 0.3), c + Vector2(s * 0.4, s * 0.3), c + Vector2(s * 0.4, -s * 0.05), c + Vector2(-s * 0.4, -s * 0.3)], Color("ffd23a"), o)
			draw_circle(c + Vector2(s * 0.1, s * 0.12), s * 0.07, Color("e0a812"))
		"lettuce":
			_disc(c, s * 0.36, Color("6cc04a"), o)
			draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), Color("a8e07a"), s * 0.05)
		"tomato":
			_disc(c, s * 0.36, Color("e6463a"), o)
			_disc(c, s * 0.2, Color("ff8a7a"), 0)
		"bun":
			_poly([c + Vector2(-s * 0.4, s * 0.16), c + Vector2(-s * 0.34, -s * 0.16), c + Vector2(0, -s * 0.32), c + Vector2(s * 0.34, -s * 0.16), c + Vector2(s * 0.4, s * 0.16)], Color("f2a43a"), o)
		"calendar":
			_poly([c + Vector2(-s * 0.38, -s * 0.3), c + Vector2(s * 0.38, -s * 0.3), c + Vector2(s * 0.38, s * 0.4), c + Vector2(-s * 0.38, s * 0.4)], Color.WHITE, o)
			_poly([c + Vector2(-s * 0.38, -s * 0.3), c + Vector2(s * 0.38, -s * 0.3), c + Vector2(s * 0.38, -s * 0.08), c + Vector2(-s * 0.38, -s * 0.08)], Color("e6463a"), 0)
			for k in 6:
				draw_rect(Rect2(c.x - s * 0.28 + (k % 3) * s * 0.21, c.y + s * 0.0 + (k / 3) * s * 0.18, s * 0.12, s * 0.1), Color("8a8f96"))
		"bolt":
			_poly([c + Vector2(s * 0.08, -s * 0.46), c + Vector2(-s * 0.3, s * 0.06), c + Vector2(-s * 0.02, s * 0.06), c + Vector2(-s * 0.1, s * 0.46), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)], Color("ffd23a"), o)
		"oxygen":
			_disc(c, s * 0.4, Color("62d0ff"), o)
			_disc(c + Vector2(-s * 0.12, -s * 0.12), s * 0.1, Color(1, 1, 1, 0.8), 0)
			var f := UI.font()
			draw_string(f, c + Vector2(-s * 0.26, s * 0.16), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.38), Color("0b3d5c"))
		"ore":
			_poly([c + Vector2(-s * 0.4, s * 0.3), c + Vector2(-s * 0.28, -s * 0.18), c + Vector2(0, -s * 0.38), c + Vector2(s * 0.34, -s * 0.16), c + Vector2(s * 0.42, s * 0.3)], Color("8a6d5a"), o)
			_poly([c + Vector2(-s * 0.12, -s * 0.08), c + Vector2(s * 0.04, -s * 0.2), c + Vector2(s * 0.16, -s * 0.02), c + Vector2(0, s * 0.1)], Color("ffb02e"), 0)
			_poly([c + Vector2(s * 0.16, s * 0.12), c + Vector2(s * 0.26, s * 0.04), c + Vector2(s * 0.3, s * 0.2)], Color("ffd23a"), 0)
		"crystal":
			_poly([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.22, -s * 0.1), c + Vector2(s * 0.12, s * 0.42), c + Vector2(-s * 0.12, s * 0.42), c + Vector2(-s * 0.22, -s * 0.1)], Color("4fe0ff"), o)
			_poly([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.22, -s * 0.1), c + Vector2(0, s * 0.0), c + Vector2(-s * 0.22, -s * 0.1)], Color("b8f6ff"), 0)
		"colonist":
			_disc(c + Vector2(0, -s * 0.16), s * 0.22, Color("f4f4f4"), o)
			_disc(c + Vector2(0, -s * 0.16), s * 0.14, Color("3a6db0"), 0)
			_poly([c + Vector2(-s * 0.3, s * 0.42), c + Vector2(-s * 0.24, s * 0.1), c + Vector2(s * 0.24, s * 0.1), c + Vector2(s * 0.3, s * 0.42)], Color("ff9a1f"), o)
		"rocket":
			_poly([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.16, -s * 0.18), c + Vector2(s * 0.16, s * 0.22), c + Vector2(-s * 0.16, s * 0.22), c + Vector2(-s * 0.16, -s * 0.18)], Color("f4f4f4"), o)
			_poly([c + Vector2(-s * 0.16, s * 0.02), c + Vector2(-s * 0.34, s * 0.32), c + Vector2(-s * 0.16, s * 0.22)], Color("e6463a"), o * 0.6)
			_poly([c + Vector2(s * 0.16, s * 0.02), c + Vector2(s * 0.34, s * 0.32), c + Vector2(s * 0.16, s * 0.22)], Color("e6463a"), o * 0.6)
			_poly([c + Vector2(-s * 0.1, s * 0.24), c + Vector2(s * 0.1, s * 0.24), c + Vector2(0, s * 0.46)], Color("ffb02e"), 0)
			_disc(c + Vector2(0, -s * 0.12), s * 0.07, Color("62d0ff"), 0)
		"box":
			_poly([c + Vector2(-s * 0.36, -s * 0.24), c + Vector2(s * 0.36, -s * 0.24), c + Vector2(s * 0.36, s * 0.36), c + Vector2(-s * 0.36, s * 0.36)], Color("e6463a"), o)
			draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.02, s * 0.72, s * 0.1), Color("f4f4f4"))
		"rover":
			_poly([c + Vector2(-s * 0.4, s * 0.12), c + Vector2(-s * 0.3, -s * 0.18), c + Vector2(s * 0.24, -s * 0.18), c + Vector2(s * 0.4, s * 0.12)], Color("f4f4f4"), o)
			_disc(c + Vector2(-s * 0.24, s * 0.22), s * 0.12, Color("3a3f48"), o)
			_disc(c + Vector2(s * 0.24, s * 0.22), s * 0.12, Color("3a3f48"), o)
		"lab":
			_poly([c + Vector2(-s * 0.1, -s * 0.42), c + Vector2(s * 0.1, -s * 0.42), c + Vector2(s * 0.1, -s * 0.08), c + Vector2(s * 0.34, s * 0.38), c + Vector2(-s * 0.34, s * 0.38), c + Vector2(-s * 0.1, -s * 0.08)], Color("e9eef5"), o)
			_poly([c + Vector2(-s * 0.2, s * 0.12), c + Vector2(s * 0.2, s * 0.12), c + Vector2(s * 0.3, s * 0.34), c + Vector2(-s * 0.3, s * 0.34)], Color("62e07a"), 0)
		"build":
			_disc(c, s * 0.44, Color("ff9a1f"), o)
			draw_line(c + Vector2(-s * 0.2, s * 0.22), c + Vector2(s * 0.12, -s * 0.1), Color.WHITE, s * 0.1)
			_poly([c + Vector2(s * 0.02, -s * 0.22), c + Vector2(s * 0.2, -s * 0.3), c + Vector2(s * 0.3, -s * 0.12), c + Vector2(s * 0.14, -s * 0.02)], Color.WHITE, 0)
		"meteor":
			_poly([c + Vector2(s * 0.42, -s * 0.42), c + Vector2(s * 0.06, -s * 0.06), c + Vector2(-s * 0.04, s * 0.06), c + Vector2(s * 0.1, -s * 0.18)], Color("ffb02e"), 0)
			_disc(c + Vector2(-s * 0.1, s * 0.1), s * 0.26, Color("8a5a4a"), o)
			_disc(c + Vector2(-s * 0.16, s * 0.06), s * 0.07, Color("5a3a30"), 0)
		"collect":
			_disc(c, s * 0.42, Color(1, 1, 1, 0.95), o)
		_:
			_disc(c, s * 0.4, t, o)
