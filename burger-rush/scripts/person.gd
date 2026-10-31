class_name Person
extends Node3D
## A walking, animated KayKit character: the chef or a customer.

signal arrived

var model: Node3D
var ap: AnimationPlayer
var speed := 2.6
var walk_anim := "Walking_A"
var idle_anim := "Idle"
var moving := false
var _path: Array[Vector3] = []
var _anim := ""
var _bob := 0.0


func setup(model_name: String, scale_factor: float = 1.0) -> void:
	model = Models.character(model_name)
	model.scale = Vector3.ONE * scale_factor
	add_child(model)
	ap = Models.animation_player(model)
	if model_name.begins_with("Skeleton") and ap != null and ap.has_animation("Walking_D_Skeletons"):
		walk_anim = "Walking_D_Skeletons"
	play(idle_anim)


## Walks through the given points, then emits [signal arrived].
func walk(points: Array) -> void:
	_path.clear()
	for p in points:
		_path.append(p as Vector3)
	moving = not _path.is_empty()
	if moving:
		play(walk_anim, 0.15, speed / 2.6)


func face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(dir.x, dir.z)


func play(anim: String, blend: float = 0.15, spd: float = 1.0) -> void:
	if ap == null or not ap.has_animation(anim):
		return
	if _anim == anim:
		ap.speed_scale = spd
		return
	_anim = anim
	ap.play(anim, blend)
	ap.speed_scale = spd


## Plays a one-shot animation, then goes back to idle.
func act(anim: String, spd: float = 1.0) -> void:
	if ap == null or not ap.has_animation(anim):
		return
	_anim = anim
	ap.play(anim, 0.1)
	ap.speed_scale = spd
	if not ap.animation_finished.is_connected(_on_finished):
		ap.animation_finished.connect(_on_finished)


func _on_finished(_name: StringName) -> void:
	if not moving and not Models.LOOPS.has(String(_anim)):
		play(idle_anim)


func _process(delta: float) -> void:
	if not moving:
		return
	var target := _path[0]
	var d := target - position
	d.y = 0.0
	var dist := d.length()
	var step := speed * delta
	if dist <= step:
		position = Vector3(target.x, position.y, target.z)
		_path.remove_at(0)
		if _path.is_empty():
			moving = false
			play(idle_anim)
			arrived.emit()
		return
	position += d / dist * step
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * 14.0, 0.0, 1.0))
