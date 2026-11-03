class_name ThumbCache
extends Node
## Renders a picture of each furniture model once, one at a time, in a small
## off-screen viewport, and keeps the pictures for the board and the orders.

signal rendered(model: String)

const SIZE := 160

var _cache := {}
var _queue: Array[String] = []
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _current := ""
var _frames := 0


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.0
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


## The picture of [param model], or null until it has been drawn.
func texture(model: String) -> Texture2D:
	if _cache.has(model):
		return _cache[model]
	if model != _current and not _queue.has(model):
		_queue.append(model)
	return null


func ready_count() -> int:
	return _cache.size()


func busy() -> bool:
	return _current != "" or not _queue.is_empty()


func _process(_delta: float) -> void:
	if _current != "":
		_frames -= 1
		if _frames <= 0:
			var img := _vp.get_texture().get_image()
			_cache[_current] = ImageTexture.create_from_image(img)
			var done := _current
			_current = ""
			rendered.emit(done)
		return
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	for c in _pivot.get_children():
		c.queue_free()
	var m := Models.furniture(_current)
	_pivot.add_child(m)
	var b := Models.bounds(m)
	var center := b.get_center()
	var ext := maxf(b.size.x, maxf(b.size.y, b.size.z))
	_cam.size = ext * 1.35
	var dir := Vector3(0.75, 0.6, 1.0).normalized()
	if b.size.z < 0.3:
		# Wall pictures face forwards: look at them straight on.
		dir = Vector3(0.25, 0.15, 1.0).normalized()
	_cam.position = center + dir * (ext * 4.0 + 2.0)
	_cam.look_at(center, Vector3.UP)
	_frames = 3
