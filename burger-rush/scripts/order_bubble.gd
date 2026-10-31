class_name OrderBubble
extends Control
## The speech bubble over a customer: the burger they want drawn layer by
## layer, any fries or drink, ticks for what they already have, and a
## patience bar that slides from green to red.

const EDGE := Color(0.12, 0.07, 0.03)
const COLORS := {"bun": Color("e8932e"), "patty": Color("6b3418"), "cheese": Color("ffd23a"),
	"lettuce": Color("6cc04a"), "tomato": Color("e6463a")}
const HEIGHTS := {"bun": 13.0, "patty": 12.0, "cheese": 6.0, "lettuce": 7.0, "tomato": 7.0}

var order: Dictionary
var got := {"burger": false, "fries": false, "drink": false}
var patience := 1.0:
	set(v):
		patience = v
		queue_redraw()
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()
var _sides: Array[Icon] = []
var _ticks := {}


func setup(o: Dictionary) -> void:
	order = o
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := 96.0
	for side in ["fries", "drink"]:
		if order[side]:
			var ic := UI.icon(side, 46)
			ic.position = Vector2(w - 4, 20)
			add_child(ic)
			_sides.append(ic)
			_ticks[side] = ic
			w += 50.0
	size = Vector2(w + 8, 104)
	pivot_offset = Vector2(size.x / 2, size.y)


func mark(part: String) -> void:
	got[part] = true
	var tick := UI.icon("check", 30)
	if part == "burger":
		tick.position = Vector2(56, 8)
	else:
		var ic: Icon = _ticks[part]
		ic.modulate = Color(1, 1, 1, 0.4)
		tick.position = ic.position + Vector2(20, -10)
	add_child(tick)
	UI.pop(tick, 0.3)
	queue_redraw()


func _draw() -> void:
	var body := Rect2(0, 0, size.x, 86)
	var bubble := UI.box(Color(1, 1, 1, 0.97), 18, EDGE, 3)
	if highlight:
		bubble.border_color = Color("ffd23a")
		bubble.set_border_width_all(5)
	draw_style_box(bubble, body)
	var tail := PackedVector2Array([Vector2(size.x / 2 - 12, 84), Vector2(size.x / 2 + 12, 84), Vector2(size.x / 2, 100)])
	draw_colored_polygon(tail, Color(1, 1, 1, 0.97))
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), EDGE, 3.0, true)
	_draw_burger(Rect2(12, 8, 74, 60), order.get("burger", []), got["burger"])
	# Patience bar.
	var bar := Rect2(10, 70, size.x - 20, 9)
	draw_rect(bar, Color(0.15, 0.1, 0.06))
	var col := Color("62c63c") if patience > 0.5 else (Color("ffb02e") if patience > 0.25 else Color("e6463a"))
	draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(patience, 0.0, 1.0), bar.size.y - 2)), col)


func _draw_burger(r: Rect2, items: Array, done: bool) -> void:
	var a := 0.45 if done else 1.0
	var y := r.end.y - 4.0
	var cx := r.get_center().x
	var w := r.size.x
	for item in GameData.stacked(items):
		var h: float = HEIGHTS[item]
		var c: Color = COLORS[item]
		c.a = a
		var e := Color(EDGE, a)
		match item:
			"bun":
				_round(Rect2(cx - w * 0.44, y - h, w * 0.88, h), c, e, 5.0)
			"patty":
				_round(Rect2(cx - w * 0.48, y - h, w * 0.96, h), c, e, 4.0)
			"cheese":
				var pts := PackedVector2Array([Vector2(cx - w * 0.5, y - h), Vector2(cx + w * 0.5, y - h),
					Vector2(cx + w * 0.36, y + 3), Vector2(cx + w * 0.22, y), Vector2(cx - w * 0.5, y)])
				draw_colored_polygon(pts, c)
				pts.append(pts[0])
				draw_polyline(pts, e, 2.0, true)
			"lettuce":
				var top: Array[Vector2] = []
				for k in 9:
					top.append(Vector2(cx - w * 0.52 + k * w * 0.13, y - h + (3.0 if k % 2 == 0 else 0.0)))
				var poly := PackedVector2Array(top)
				poly.append(Vector2(cx + w * 0.5, y))
				poly.append(Vector2(cx - w * 0.5, y))
				draw_colored_polygon(poly, c)
				poly.append(poly[0])
				draw_polyline(poly, e, 2.0, true)
			"tomato":
				_round(Rect2(cx - w * 0.42, y - h, w * 0.84, h), c, e, 3.0)
		y -= h - 1.0
	if items.has("bun") and items.has("patty"):
		# The top bun: a dome with sesame seeds.
		var dome := PackedVector2Array()
		for k in 17:
			var ang := PI + PI * k / 16.0
			dome.append(Vector2(cx + cos(ang) * w * 0.46, y + sin(ang) * 22.0))
		var bun_c: Color = COLORS["bun"]
		bun_c.a = a
		draw_colored_polygon(dome, bun_c)
		dome.append(dome[0])
		draw_polyline(dome, Color(EDGE, a), 2.5, true)
		for k in 3:
			draw_circle(Vector2(cx - 12 + k * 12, y - 12 + (k % 2) * 4), 2.2, Color(1, 0.95, 0.8, a))


func _round(r: Rect2, c: Color, e: Color, radius: float) -> void:
	var s := UI.box(c, int(radius), e, 2)
	draw_style_box(s, r)
