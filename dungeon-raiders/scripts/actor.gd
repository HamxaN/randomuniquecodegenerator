class_name Actor
extends CharacterBody3D
## The hero or a monster: moving, facing, animations, health and the simple
## monster brains. The dungeon handles projectiles, loot and effects.

signal died(actor: Actor)

const HEIGHT := 2.1

var dungeon: Dungeon
var is_hero := false
var kind := ""
var info: Dictionary = {}
var display_name := ""
var max_hp := 100.0
var hp := 100.0
var attack := 10.0
var speed := 5.0
var armor := 0.0
var reach := 2.0
var rate := 1.0
var ranged := false
var dead := false
var frozen := 0.0
var spawn_lock := 0.0

var move_dir := Vector3.ZERO
var facing := Vector3.FORWARD
var target: Actor
var knock := Vector3.ZERO
var _cd := 0.4
var _pending := -1.0
var _retarget := 0.0
var _strafe := 1.0
var _model: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _lock := 0.0
var _scale := 1.0
var _meshes: Array[MeshInstance3D] = []
var _flash := 0.0

static var _flash_mat: StandardMaterial3D
static var _ice_mat: StandardMaterial3D


func _init() -> void:
	floor_snap_length = 0.3


func setup_hero(h: Dictionary, stats: Dictionary) -> void:
	is_hero = true
	kind = h["id"]
	display_name = h["name"]
	max_hp = float(stats["hp"])
	hp = max_hp
	attack = float(stats["attack"])
	speed = float(h["speed"])
	armor = float(h["armor"])
	reach = float(h["range"])
	rate = float(h["rate"])
	ranged = bool(h["ranged"])
	collision_layer = 2
	collision_mask = 1 | 4
	_build(Models.character(h["model"], h["keep"]), 1.0, 0.45)


func setup_monster(monster_kind: String, floor_n: int) -> void:
	kind = monster_kind
	info = GameData.ENEMIES[monster_kind]
	display_name = info["name"]
	var k := GameData.monster_scale(floor_n)
	max_hp = float(info["hp"]) * k
	hp = max_hp
	attack = float(info["damage"]) * (1.0 + 0.12 * float(floor_n - 1))
	speed = float(info["speed"]) * randf_range(0.92, 1.08)
	reach = float(info["reach"])
	rate = 1.0 / float(info["cooldown"])
	ranged = bool(info["ranged"])
	_cd = randf_range(0.6, 1.4)
	collision_layer = 4
	collision_mask = 1 | 2
	_build(Models.character(info["model"], []), float(info["scale"]), 0.45)
	var hand := Models.hand_slot(_model)
	if hand != null:
		hand.add_child(Models.gear(info["gear"]))
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _build(model: Node3D, unit_scale: float, radius: float) -> void:
	_scale = unit_scale
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius * unit_scale
	capsule.height = maxf(HEIGHT * unit_scale * 0.85, capsule.radius * 2.0 + 0.1)
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	_model = model
	add_child(_model)
	_model.rotation.y = PI
	var b := Models.bounds(_model)
	_model.scale = Vector3.ONE * (HEIGHT * unit_scale / maxf(b.end.y, 0.5))
	_ap = Models.animation_player(_model)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.visible:
			_meshes.append(mi)
	if _flash_mat == null:
		_flash_mat = Models.material(Color(1, 0.3, 0.25, 0.55), 0.0, true)
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ice_mat = Models.material(Color(0.5, 0.8, 1.0, 0.45), 0.0, true)
		_ice_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	play("Idle")


func center() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale * 0.55, 0)


func head() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale + 0.3, 0)


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _meshes.size() > 0:
		var overlay: Material = _flash_mat if _flash > 0.0 else (_ice_mat if frozen > 0.0 else null)
		if _meshes[0].material_overlay != overlay:
			for m in _meshes:
				m.material_overlay = overlay
	if dead:
		return
	_lock = maxf(0.0, _lock - delta)
	if spawn_lock > 0.0:
		spawn_lock -= delta
		return
	if frozen > 0.0:
		frozen -= delta
		velocity = Vector3.ZERO
		if _ap != null:
			_ap.speed_scale = 0.0
		return
	if _ap != null:
		_ap.speed_scale = 1.0
	if is_hero:
		_hero_think(delta)
	else:
		_monster_think(delta)
	var move_speed := speed * (dungeon.speed_mult if is_hero else 1.0)
	if _lock > 0.0 and not is_hero:
		move_speed *= 0.2
	var h := move_dir * move_speed + knock
	velocity.x = h.x
	velocity.z = h.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 30.0 * delta
	move_and_slide()
	knock = knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if global_position.y < -0.05 or global_position.y > 0.4:
		global_position.y = 0.0
	var look := facing
	if target != null and not target.dead and (move_dir.length() < 0.1 or _lock > 0.0 or not is_hero):
		var to := target.global_position - global_position
		to.y = 0
		if to.length() > 0.05:
			look = to.normalized()
	elif move_dir.length() > 0.1:
		look = move_dir.normalized()
	facing = facing.slerp(look, clampf(14.0 * delta, 0.0, 1.0)).normalized()
	if facing.length() < 0.5:
		facing = look
	rotation.y = atan2(-facing.x, -facing.z)
	_animate()


func _hero_think(delta: float) -> void:
	move_dir = dungeon.input_move
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.15
		target = dungeon.nearest_monster(global_position, reach + (0.0 if ranged else 0.8), ranged)
	_cd -= delta
	if _pending >= 0.0:
		_pending -= delta
		if _pending < 0.0:
			dungeon.hero_strike(self)
	if target != null and _cd <= 0.0 and _lock <= 0.0:
		_cd = 1.0 / (rate * dungeon.rate_mult)
		_pending = 0.22 if not ranged else 0.18
		match kind:
			"knight":
				one_shot("1H_Melee_Attack_Slice_Horizontal" if randf() < 0.5 else "1H_Melee_Attack_Chop", 1.8)
			"barbarian":
				one_shot("2H_Melee_Attack_Slice" if randf() < 0.5 else "2H_Melee_Attack_Chop", 1.6)
			"rogue":
				one_shot("2H_Ranged_Shoot", 1.8)
			_:
				one_shot("Spellcast_Shoot", 1.8)


func _monster_think(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5
		target = dungeon.hero if dungeon.hero != null and not dungeon.hero.dead else null
	_cd -= delta
	if _pending >= 0.0:
		_pending -= delta
		if _pending < 0.0:
			_land_hit()
	if target == null:
		move_dir = Vector3.ZERO
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var desired := Vector3.ZERO
	if ranged:
		var sees := dungeon.line_of_sight(center(), target.center())
		if dist > reach * 0.85 or not sees:
			desired = dir
		elif dist < reach * 0.45:
			desired = -dir
		else:
			desired = dir.cross(Vector3.UP) * _strafe * 0.5
		if dist <= reach and sees and _cd <= 0.0 and _lock <= 0.0:
			_cd = 1.0 / rate * randf_range(0.85, 1.2)
			one_shot("Spellcast_Shoot" if kind == "mage" or kind == "lich" else "1H_Ranged_Shoot", 1.2)
			dungeon.monster_shoot(self, target)
	else:
		if dist > reach * 0.8:
			desired = dir
		if dist <= reach and _cd <= 0.0 and _lock <= 0.0:
			_cd = 1.0 / rate * randf_range(0.9, 1.15)
			one_shot("2H_Melee_Attack_Chop" if kind == "boss" else "1H_Melee_Attack_Chop", 1.0 if kind == "boss" else 1.3)
			_pending = 0.55 if kind == "boss" else 0.32
			Sfx.play("swing", 0.7 if kind == "boss" else 1.0)
	desired += dungeon.separation(self) * 0.9
	desired.y = 0
	move_dir = desired.normalized() * minf(desired.length(), 1.0) if desired.length() > 0.05 else Vector3.ZERO


func _land_hit() -> void:
	if dead or target == null or target.dead:
		return
	if kind == "boss":
		dungeon.slam(self, global_position + facing * 1.6, reach + 0.6, attack)
	elif global_position.distance_to(target.global_position) <= reach + 0.6:
		target.take_damage(attack, target.global_position - global_position)


## Returns true when this hit was fatal.
func take_damage(amount: float, push: Vector3) -> bool:
	if dead or spawn_lock > 0.0:
		return false
	var real := amount * (1.0 - armor)
	hp -= real
	_flash = 0.09
	push.y = 0
	if push.length() > 0.01:
		knock += push.normalized() * (2.0 if not kind in ["boss", "lich"] else 0.2)
	dungeon.on_hurt(self, real)
	if hp <= 0.0:
		hp = 0.0
		die()
		return true
	if not is_hero and not kind in ["boss", "lich"] and randf() < 0.25 and _lock <= 0.0 and _pending < 0.0:
		one_shot("Hit_A", 1.6)
	return false


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func die() -> void:
	dead = true
	move_dir = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	_pending = -1.0
	_lock = 0.0
	frozen = 0.0
	if _ap != null:
		_ap.speed_scale = 1.0
	one_shot("Death_A" if randf() < 0.5 else "Death_B", 1.0)
	died.emit(self)


func revive(fraction: float) -> void:
	dead = false
	hp = max_hp * fraction
	collision_layer = 2
	collision_mask = 1 | 4
	_anim = ""
	one_shot("Lie_StandUp", 1.4)


func play(anim_name: String, blend: float = 0.18, anim_speed: float = 1.0) -> void:
	if _ap == null or _anim == anim_name or not _ap.has_animation(anim_name):
		return
	_anim = anim_name
	_ap.play(anim_name, blend, anim_speed)


func one_shot(anim_name: String, anim_speed: float = 1.0) -> void:
	if _ap == null or not _ap.has_animation(anim_name):
		return
	_anim = anim_name
	_ap.play(anim_name, 0.08, anim_speed)
	_ap.seek(0.0, true)
	_lock = _ap.get_animation(anim_name).length / anim_speed


func rise() -> void:
	spawn_lock = 1.0
	one_shot("Spawn_Ground_Skeletons" if _ap != null and _ap.has_animation("Spawn_Ground_Skeletons") else "Spawn_Ground", 1.3)


func _animate() -> void:
	if _lock > 0.0:
		return
	var moving := Vector3(velocity.x, 0, velocity.z).length() > 0.6
	if moving:
		if is_hero:
			play("Running_A", 0.15, 1.1)
		elif kind == "minion":
			play("Running_C" if _ap != null and _ap.has_animation("Running_C") else "Running_A", 0.2)
		elif kind == "boss":
			play("Walking_D_Skeletons", 0.2, 1.2)
		else:
			play("Walking_A", 0.2, 1.3)
	else:
		if is_hero:
			play("2H_Melee_Idle" if kind == "barbarian" else ("2H_Ranged_Aiming" if kind == "rogue" else "Idle"), 0.25)
		else:
			play("Idle_Combat" if _ap != null and _ap.has_animation("Idle_Combat") else "Idle", 0.25)
