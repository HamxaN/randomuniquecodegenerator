class_name Joystick
extends Control
## A floating thumbstick: touch anywhere in its area and drag.

var value := Vector2.ZERO
var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest := Vector2.ZERO
var radius := 74.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_place_rest)
	_place_rest()


func _place_rest() -> void:
	_rest = Vector2(radius + 70.0, size.y - radius - 70.0)
	if _touch < 0:
		_origin = _rest
		_knob = _rest
	queue_redraw()


func active() -> bool:
	return _touch >= 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch < 0:
			_touch = t.index
			_origin = t.position
			_knob = t.position
			accept_event()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			value = Vector2.ZERO
			_origin = _rest
			_knob = _rest
			accept_event()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _touch:
			return
		var off := d.position - _origin
		if off.length() > radius:
			# Drag the base along so the stick never "runs out".
			_origin += off.normalized() * (off.length() - radius)
			off = off.normalized() * radius
		_knob = _origin + off
		value = off / radius
		if value.length() < 0.12:
			value = Vector2.ZERO
		accept_event()
		queue_redraw()


func _draw() -> void:
	var a := 1.0 if _touch >= 0 else 0.55
	draw_circle(_origin, radius + 10, Color(0, 0, 0, 0.28 * a))
	draw_arc(_origin, radius + 10, 0, TAU, 64, Color(1, 1, 1, 0.35 * a), 3.0, true)
	draw_arc(_origin, radius * 0.55, 0, TAU, 48, Color(1, 1, 1, 0.12 * a), 2.0, true)
	for i in 4:
		var dir := Vector2.from_angle(i * PI / 2)
		var tip := _origin + dir * (radius + 2)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12 + dir.orthogonal() * 8, tip - dir * 12 - dir.orthogonal() * 8]), Color(1, 1, 1, 0.3 * a))
	draw_circle(_knob, 38, Color(0, 0, 0, 0.25))
	draw_circle(_knob, 34, Color(1, 1, 1, 0.82 * a))
	draw_circle(_knob, 26, Color(0.93, 0.95, 0.97, 0.9 * a))
	draw_arc(_knob, 34, 0, TAU, 40, Color("ffc21a", a), 3.0, true)
