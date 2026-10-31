class_name Walker
extends Node3D
## Someone on the battlefield who walks: a skeleton marching down the road
## (blocked and attacked by the hero when it gets in the way), or the hero.

const HEIGHT := 0.82

var defense: Defense
var kind := ""
var info: Dictionary
var is_hero := false
var max_hp := 50.0
var hp := 50.0
var speed := 1.5
var armor := 0.0
var damage := 8.0
var dead := false
var slow_time := 0.0
var slow_amount := 0.0
var distance := 0.0
var waypoint := 1
var path: Array[Vector3] = []
var goal := Vector3.ZERO
var fighting: Walker
var respawn := 0.0
var _cd := 0.5
var _model: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _lock := 0.0
var _meshes: Array[MeshInstance3D] = []
var _flash := 0.0
var _scale := 1.0

static var _flash_mat: StandardMaterial3D
static var _ice_mat: StandardMaterial3D


func setup_enemy(enemy_kind: String, health_scale: float, road: Array[Vector3]) -> void:
	kind = enemy_kind
	info = GameData.ENEMIES[kind]
	max_hp = float(info["hp"]) * health_scale
	hp = max_hp
	speed = float(info["speed"]) * randf_range(0.94, 1.06)
	armor = float(info["armor"])
	damage = float(info["damage"])
	path = road
	_build(Models.character(info["model"], []), float(info["scale"]))
	position = path[0] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))


func setup_hero(at: Vector3) -> void:
	is_hero = true
	kind = "hero"
	max_hp = float(GameData.HERO["hp"])
	hp = max_hp
	speed = float(GameData.HERO["speed"])
	damage = float(GameData.HERO["damage"])
	armor = 0.2
	_build(Models.character("Knight", ["1H_Sword", "Round_Shield"]), 1.15)
	position = at
	goal = at
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.38
	t.outer_radius = 0.48
	ring.mesh = t
	ring.material_override = Models.material(Color(1.0, 0.85, 0.3), 2.0, true)
	ring.scale = Vector3(1, 0.3, 1)
	ring.position.y = 0.04
	add_child(ring)


func _build(model: Node3D, s: float) -> void:
	_scale = s
	_model = model
	add_child(_model)
	_model.rotation.y = PI
	var b := Models.bounds(_model)
	_model.scale = Vector3.ONE * (HEIGHT * s / maxf(b.end.y, 0.3))
	_ap = Models.animation_player(_model)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).visible:
			_meshes.append(m)
	if _flash_mat == null:
		_flash_mat = Models.material(Color(1, 0.3, 0.2, 0.55), 0.0, true)
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ice_mat = Models.material(Color(0.6, 0.4, 1.0, 0.4), 0.0, true)
		_ice_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_play("Idle")


func head() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale + 0.2, 0)


func center() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale * 0.5, 0)


func step(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if _meshes.size() > 0:
		var overlay: Material = _flash_mat if _flash > 0.0 else (_ice_mat if slow_time > 0.0 else null)
		if _meshes[0].material_overlay != overlay:
			for m in _meshes:
				m.material_overlay = overlay
	if dead:
		if is_hero:
			respawn -= delta
			if respawn <= 0.0:
				_revive()
		return
	_lock = maxf(0.0, _lock - delta)
	_cd -= delta
	if is_hero:
		_hero_step(delta)
	else:
		_enemy_step(delta)


func _enemy_step(delta: float) -> void:
	if fighting != null and (fighting.dead or fighting.global_position.distance_to(global_position) > 1.3):
		fighting = null
	if fighting != null:
		_face(fighting.global_position)
		if _cd <= 0.0 and _lock <= 0.0:
			_cd = 1.2
			_one_shot("1H_Melee_Attack_Chop", 1.3)
			fighting.hurt(damage * 0.6, false)
		elif _lock <= 0.0:
			_play("Idle_Combat" if _ap != null and _ap.has_animation("Idle_Combat") else "Idle")
		return
	var spd := speed * (1.0 - slow_amount if slow_time > 0.0 else 1.0)
	if waypoint >= path.size():
		defense.enemy_escaped(self)
		return
	var target := path[waypoint]
	var to := target - global_position
	to.y = 0
	var step_len := spd * delta
	if to.length() <= step_len:
		global_position = Vector3(target.x, 0, target.z)
		waypoint += 1
	else:
		global_position += to.normalized() * step_len
		_face(target)
	distance += step_len
	_play("Walking_D_Skeletons" if kind == "boss" else ("Running_C" if kind == "runner" and _ap != null and _ap.has_animation("Running_C") else "Walking_A"), 0.2, 1.0 + spd * 0.15)


func _hero_step(delta: float) -> void:
	var foe := defense.enemy_near(global_position, float(GameData.HERO["reach"]) + 0.3)
	if foe != null:
		foe.fighting = self
		_face(foe.global_position)
		if _cd <= 0.0 and _lock <= 0.0:
			_cd = 1.0 / float(GameData.HERO["rate"])
			_one_shot("1H_Melee_Attack_Slice_Horizontal", 1.5)
			defense.hit_enemy(foe, damage, false, 0.0)
		elif _lock <= 0.0:
			_play("Idle")
		return
	var to := goal - global_position
	to.y = 0
	if to.length() > 0.15:
		global_position += to.normalized() * minf(speed * delta, to.length())
		_face(goal)
		_play("Running_A", 0.15, 1.1)
	elif _lock <= 0.0:
		_play("Idle")
	hp = minf(max_hp, hp + delta * 6.0)


func _face(p: Vector3) -> void:
	var to := p - global_position
	if to.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.25)


## Returns true when fatal.
func hurt(amount: float, magic: bool) -> bool:
	if dead:
		return false
	var real := amount * (1.0 if magic else 1.0 - armor)
	hp -= real
	_flash = 0.08
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_one_shot("Death_A" if randf() < 0.5 else "Death_B", 1.0)
		if is_hero:
			respawn = float(GameData.HERO["respawn"])
			defense.hero_died()
		else:
			defense.enemy_killed(self)
		return true
	return false


func _revive() -> void:
	dead = false
	hp = max_hp
	_anim = ""
	global_position = defense.castle_spot
	goal = global_position
	_one_shot("Lie_StandUp", 1.4)


func cheer() -> void:
	if not dead:
		_one_shot("Cheer", 1.0)


func _play(anim: String, blend: float = 0.15, spd: float = 1.0) -> void:
	if _ap == null or _anim == anim or not _ap.has_animation(anim) or _lock > 0.0:
		return
	_anim = anim
	_ap.play(anim, blend, spd)


func _one_shot(anim: String, spd: float) -> void:
	if _ap == null or not _ap.has_animation(anim):
		return
	_anim = anim
	_ap.play(anim, 0.08, spd)
	_ap.seek(0.0, true)
	_lock = _ap.get_animation(anim).length / spd
