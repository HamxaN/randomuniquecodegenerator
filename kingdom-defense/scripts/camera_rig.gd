class_name CameraRig
extends Node3D
## The tilted strategy camera: drag to pan, pinch (or mouse wheel) to zoom, and
## a short touch counts as a tap on the ground.

signal tapped(screen: Vector2, ground: Vector3)
signal pressed(screen: Vector2, ground: Vector3)
signal released

const PITCH := -52.0
const MIN_DIST := 9.0
const MAX_DIST := 30.0
const LIMIT := 9.0

var camera: Camera3D
var focus := Vector3.ZERO
var distance := 19.0
var yaw := 0.0
var _touches := {}
var _down_at := {}
var _moved := false
var _pinch_start := 0.0
var _pinch_dist := 0.0
var _shake := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_apply()


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.0)
	_apply()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _apply() -> void:
	focus.x = clampf(focus.x, -LIMIT, LIMIT)
	focus.z = clampf(focus.z, -LIMIT, LIMIT * 0.8)
	distance = clampf(distance, MIN_DIST, MAX_DIST)
	var back := Vector3(0, sin(deg_to_rad(-PITCH)), cos(deg_to_rad(-PITCH))) * distance
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake * 0.5
	camera.global_position = focus + back.rotated(Vector3.UP, yaw) + jitter
	camera.look_at(focus, Vector3.UP)


func ground_at(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return focus
	var t := -from.y / dir.y
	return from + dir * t


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			_down_at[t.index] = Time.get_ticks_msec()
			if _touches.size() == 1:
				_moved = false
				pressed.emit(t.position, ground_at(t.position))
			elif _touches.size() == 2:
				_pinch_dist = _two_finger_distance()
				_pinch_start = distance
		else:
			var quick := Time.get_ticks_msec() - int(_down_at.get(t.index, 0)) < 400
			if _touches.size() == 1 and not _moved and quick:
				tapped.emit(t.position, ground_at(t.position))
			_touches.erase(t.index)
			_down_at.erase(t.index)
			if _touches.is_empty():
				released.emit()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			_moved = true
			var now := _two_finger_distance()
			if _pinch_dist > 1.0:
				distance = _pinch_start * _pinch_dist / maxf(now, 1.0)
		elif d.relative.length() > 2.0 or _moved:
			_moved = true
			var k := distance / 620.0
			var pan := Vector3(-d.relative.x, 0, -d.relative.y) * k * 1.3
			focus += pan.rotated(Vector3.UP, yaw)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= 1.2
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += 1.2


func _two_finger_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)
