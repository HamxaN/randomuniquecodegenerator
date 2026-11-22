class_name TouchButton
extends Control
## A round on-screen button for thumbs. Supports holding (fire), tapping, and
## dragging while held to keep turning the camera (like mobile shooters do).

signal pressed
signal released
signal dragged(rel: Vector2)

var text := ""
var icon_kind := ""
var color := Color(0, 0, 0, 0.35)
var ring := Color(1, 1, 1, 0.5)
var big := false
var held := false
var badge := ""
var progress := -1.0
var _touch := -1
var _tex_font: Font


func _init(label_text: String = "", diameter: float = 84.0, icon: String = "") -> void:
	text = label_text
	icon_kind = icon
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch < 0:
			if t.position.distance_to(size / 2) > size.x * 0.62:
				return
			_touch = t.index
			held = true
			pressed.emit()
			accept_event()
			queue_redraw()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			held = false
			released.emit()
			accept_event()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			dragged.emit(d.relative)
			accept_event()


func release() -> void:
	if held:
		held = false
		_touch = -1
		released.emit()
		queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 2
	var fill := color if not held else Color(color.r, color.g, color.b, minf(1.0, color.a + 0.25))
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 48, ring, 3.0 if big else 2.0, true)
	if progress >= 0.0:
		draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 48, UI.ACCENT, 5.0, true)
	if icon_kind != "":
		_icon(c, r)
	if text != "":
		var f := UI.bold()
		var fs := int(r * (0.5 if text.length() <= 4 else 0.36))
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var y := c.y + fs * 0.32 + (r * 0.42 if icon_kind != "" else 0.0)
		draw_string_outline(f, Vector2(c.x - w / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(c.x - w / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if badge != "":
		var f2 := UI.bold()
		var bp := c + Vector2(r * 0.55, -r * 0.6)
		draw_circle(bp, 13, Color(0.1, 0.1, 0.12, 0.9))
		var w2 := f2.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(f2, bp + Vector2(-w2 / 2, 6), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _icon(c: Vector2, r: float) -> void:
	var w := Color(1, 1, 1, 0.95)
	var s := r * 0.55
	var oc := c - Vector2(0, r * 0.12 if text != "" else 0.0)
	match icon_kind:
		"fire":
			# A bullet.
			draw_rect(Rect2(oc + Vector2(-s * 0.22, -s * 0.2), Vector2(s * 0.44, s * 0.85)), w)
			draw_colored_polygon(PackedVector2Array([oc + Vector2(-s * 0.22, -s * 0.2), oc + Vector2(0, -s * 0.75), oc + Vector2(s * 0.22, -s * 0.2)]), w)
			draw_rect(Rect2(oc + Vector2(-s * 0.28, s * 0.62), Vector2(s * 0.56, s * 0.14)), w)
		"scope":
			draw_arc(oc, s * 0.65, 0, TAU, 32, w, 3.0, true)
			draw_line(oc - Vector2(s, 0), oc + Vector2(s, 0), w, 2.0)
			draw_line(oc - Vector2(0, s), oc + Vector2(0, s), w, 2.0)
		"jump":
			draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -s * 0.8), oc + Vector2(s * 0.7, 0), oc + Vector2(s * 0.25, 0), oc + Vector2(s * 0.25, s * 0.7), oc + Vector2(-s * 0.25, s * 0.7), oc + Vector2(-s * 0.25, 0), oc + Vector2(-s * 0.7, 0)]), w)
		"reload":
			draw_arc(oc, s * 0.6, 0.4, TAU - 0.2, 28, w, 4.0, true)
			draw_colored_polygon(PackedVector2Array([oc + Vector2(s * 0.6, -s * 0.45), oc + Vector2(s * 0.95, s * 0.1), oc + Vector2(s * 0.25, s * 0.05)]), w)
		"grenade":
			draw_circle(oc + Vector2(0, s * 0.15), s * 0.55, w)
			draw_rect(Rect2(oc + Vector2(-s * 0.2, -s * 0.65), Vector2(s * 0.4, s * 0.3)), w)
			draw_arc(oc + Vector2(s * 0.35, -s * 0.55), s * 0.22, 0, TAU, 12, w, 2.0)
		"heal":
			draw_rect(Rect2(oc + Vector2(-s * 0.2, -s * 0.7), Vector2(s * 0.4, s * 1.4)), Color("ff5a5a"))
			draw_rect(Rect2(oc + Vector2(-s * 0.7, -s * 0.2), Vector2(s * 1.4, s * 0.4)), Color("ff5a5a"))
		"hand":
			draw_circle(oc, s * 0.5, w)
			for i in 4:
				draw_rect(Rect2(oc + Vector2(-s * 0.5 + i * s * 0.27, -s * 0.95), Vector2(s * 0.2, s * 0.6)), w)
		"car":
			draw_rect(Rect2(oc + Vector2(-s * 0.85, -s * 0.1), Vector2(s * 1.7, s * 0.5)), w)
			draw_colored_polygon(PackedVector2Array([oc + Vector2(-s * 0.5, -s * 0.1), oc + Vector2(-s * 0.3, -s * 0.55), oc + Vector2(s * 0.35, -s * 0.55), oc + Vector2(s * 0.55, -s * 0.1)]), w)
			draw_circle(oc + Vector2(-s * 0.5, s * 0.45), s * 0.2, Color(0.1, 0.1, 0.1))
			draw_circle(oc + Vector2(s * 0.5, s * 0.45), s * 0.2, Color(0.1, 0.1, 0.1))
		"chute":
			draw_arc(oc + Vector2(0, s * 0.1), s * 0.85, PI, TAU, 24, w, 5.0, true)
			draw_line(oc + Vector2(-s * 0.85, s * 0.1), oc + Vector2(0, s * 0.8), w, 2.0)
			draw_line(oc + Vector2(s * 0.85, s * 0.1), oc + Vector2(0, s * 0.8), w, 2.0)
			draw_circle(oc + Vector2(0, s * 0.8), s * 0.15, w)
		"exit":
			draw_rect(Rect2(oc + Vector2(-s * 0.7, -s * 0.7), Vector2(s * 0.8, s * 1.4)), Color(0, 0, 0, 0), false, 3.0)
			draw_line(oc + Vector2(-s * 0.1, 0), oc + Vector2(s * 0.8, 0), w, 4.0)
			draw_colored_polygon(PackedVector2Array([oc + Vector2(s * 0.9, 0), oc + Vector2(s * 0.5, -s * 0.35), oc + Vector2(s * 0.5, s * 0.35)]), w)


## The right side of the screen: drag to look around.
class LookPad:
	extends Control

	signal dragged(rel: Vector2)

	var _touch := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed and _touch < 0:
				_touch = t.index
				accept_event()
			elif not t.pressed and t.index == _touch:
				_touch = -1
				accept_event()
		elif event is InputEventScreenDrag:
			var d := event as InputEventScreenDrag
			if d.index == _touch:
				dragged.emit(d.relative)
				accept_event()
