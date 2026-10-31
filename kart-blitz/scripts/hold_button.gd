class_name HoldButton
extends Control
## A round touch button that reports whether it is being held. Works with
## several fingers at once (steer with one thumb, drift with the other).

signal pressed

var icon_kind := "left"
var caption := ""
var color := Color("3f9de0")
var held := false
var _touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch < 0:
			_touch = t.index
			held = true
			pressed.emit()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			held = false
		accept_event()
		queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 4
	var col := color.lightened(0.15) if held else color
	draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color(0.1, 0.07, 0.04, 0.85))
	draw_circle(c, r - 5, Color(col, 0.92 if held else 0.75))
	draw_arc(c, r - 5, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.35), 4.0, true)
	var s := r * 0.9
	var white := Color.WHITE
	match icon_kind:
		"left":
			_arrow(c, s, -1.0, white)
		"right":
			_arrow(c, s, 1.0, white)
		"drift":
			for i in 3:
				draw_arc(c + Vector2(0, s * 0.1), s * (0.2 + i * 0.13), PI * 1.15, PI * 1.85, 16, white, s * 0.07)
		_:
			draw_circle(c, s * 0.3, white)
	if caption != "":
		var f := UI.font()
		var fs := int(r * 0.36)
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(c.x - w / 2, c.y + r * 0.72), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.08, 0.05, 0.02))
		draw_string(f, Vector2(c.x - w / 2, c.y + r * 0.72), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _arrow(c: Vector2, s: float, dir: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(dir * s * 0.45, 0), c + Vector2(-dir * s * 0.15, -s * 0.42), c + Vector2(-dir * s * 0.15, -s * 0.15),
		c + Vector2(-dir * s * 0.45, -s * 0.15), c + Vector2(-dir * s * 0.45, s * 0.15), c + Vector2(-dir * s * 0.15, s * 0.15), c + Vector2(-dir * s * 0.15, s * 0.42)])
	draw_colored_polygon(pts, col)
