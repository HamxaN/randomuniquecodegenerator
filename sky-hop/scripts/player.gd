class_name Player
extends CharacterBody3D
## The hopper: runs, jumps, double-jumps (with a little coyote time and jump
## buffering so it feels fair on a phone), rides moving platforms and bumps
## coin blocks from below.

var level: Level
var input := Vector2.ZERO
var jump_pressed := false
var _coyote := 0.0
var _buffer := 0.0
var _double := true
var _model: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _was_floor := true
var _squash := 1.0
var _facing := 0.0


func _ready() -> void:
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50)
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 0.78
	shape.shape = cap
	shape.position.y = 0.39
	add_child(shape)
	_model = Models.kit("character")
	add_child(_model)
	_model.rotation.y = PI
	_ap = Models.animation_player(_model)
	if _ap != null:
		for a in ["idle", "walk"]:
			if _ap.has_animation(a):
				_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var tint: Color = GameData.skin(Save.skin)["color"]
	if tint != Color(1, 1, 1):
		for m in _model.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = Models.material(Color(tint, 0.45), 0.0, false)
	_play("idle")


func jump() -> void:
	_buffer = 0.14


func bounce(power: float) -> void:
	velocity.y = power
	_double = true
	_squash = 0.6
	_play("jump")


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = 0.12
		_double = true
	else:
		_coyote -= delta
	_buffer -= delta
	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = GameData.JUMP
			_coyote = 0.0
			_buffer = 0.0
			_squash = 1.35
			Sfx.play("jump")
			_play("jump")
		elif _double:
			velocity.y = GameData.DOUBLE_JUMP
			_double = false
			_buffer = 0.0
			_squash = 1.3
			Sfx.play("jump", 1.25)
			_play("jump")
			level.puff(global_position, 6)
	velocity.y -= GameData.GRAVITY * delta
	velocity.y = maxf(velocity.y, -30.0)
	var move := Vector3(input.x, 0, input.y)
	if move.length() > 1.0:
		move = move.normalized()
	var accel := 40.0 if on_floor else 18.0
	velocity.x = move_toward(velocity.x, move.x * GameData.RUN_SPEED, accel * delta)
	velocity.z = move_toward(velocity.z, move.z * GameData.RUN_SPEED, accel * delta)
	move_and_slide()
	# Bump blocks from below.
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.6:
			level.bump(c.get_collider())
		elif c.get_normal().y > 0.6:
			level.landed_on(c.get_collider())
	if is_on_floor() and not _was_floor:
		_squash = 0.7
		Sfx.play("land", 1.0, -6.0)
		level.puff(global_position, 4)
	_was_floor = is_on_floor()
	if move.length() > 0.1:
		_facing = lerp_angle(_facing, atan2(-move.x, -move.z), clampf(delta * 14.0, 0, 1))
	rotation.y = _facing
	_squash = lerpf(_squash, 1.0, clampf(delta * 12.0, 0, 1))
	_model.scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0 / sqrt(_squash))
	if is_on_floor():
		var flat := Vector2(velocity.x, velocity.z).length()
		_play("walk" if flat > 0.5 else "idle", 0.1, clampf(flat / GameData.RUN_SPEED * 1.6, 0.6, 1.8) if flat > 0.5 else 1.0)


func _play(anim: String, blend: float = 0.1, spd: float = 1.0) -> void:
	if _ap == null or not _ap.has_animation(anim):
		return
	if _anim == anim:
		_ap.speed_scale = spd
		return
	_anim = anim
	_ap.play(anim, blend)
	_ap.speed_scale = spd
