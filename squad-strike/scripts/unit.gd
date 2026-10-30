class_name Unit
extends CharacterBody3D
## A fighter on the field: the player, a squad bot, or one of the undead.
## Movement, facing, animation, health and the simple brains all live here; the
## arena handles bullets, effects and score.

signal died(unit: Unit)

enum Team { SQUAD, UNDEAD }

const HEIGHT := 2.2
const GRAVITY := 30.0

var arena: Arena
var team := Team.SQUAD
var kind := ""
var display_name := ""
var color := Color.WHITE
var is_player := false
var autopilot := false
var max_hp := 100.0
var hp := 100.0
var speed := 5.0
var armor := 0.0
var damage_mult := 1.0
var dead := false
var downed_time := 0.0

# Squad weapon state.
var weapon: Dictionary = {}
var weapon_power := 1.0
var ammo := 0
var mag := 30
var reload_left := 0.0
var fire_cd := 0.0
var fire_rate_mult := 1.0
var reload_mult := 1.0
var shooting_time := 0.0

# Undead attack state.
var info: Dictionary = {}
var attack_cd := 1.0
var pending_hit := -1.0
var spawn_lock := 0.0

var move_dir := Vector3.ZERO
var facing := Vector3.FORWARD
var target: Unit
var _retarget := 0.0
var _strafe := 1.0
var _formation := Vector3.ZERO
var knock := Vector3.ZERO

var model: Node3D
var _pivot: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _lock := 0.0
var _gun: Node3D
var _hand: BoneAttachment3D
var _meshes: Array[MeshInstance3D] = []
var _flash := 0.0
var _scale := 1.0
var _gun_scale := 1.0

static var _flash_mat: StandardMaterial3D


func _init() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	floor_snap_length = 0.3
	wall_min_slide_angle = 0.05


## Builds a squad member with an operator's look and stats and a weapon.
func setup_squad(op: Dictionary, weapon_id: String, level: int, player: bool) -> void:
	team = Team.SQUAD
	kind = op["id"]
	display_name = op["name"]
	color = op["color"]
	is_player = player
	max_hp = float(op["hp"])
	hp = max_hp
	speed = float(op["speed"])
	armor = float(op["armor"])
	damage_mult = float(op["damage"])
	collision_layer = 2
	collision_mask = 1 | 4
	_build(op["model"], 1.0, 0.42)
	set_weapon(weapon_id, level)


func set_weapon(weapon_id: String, level: int) -> void:
	weapon = GameData.weapon(weapon_id)
	weapon_power = GameData.weapon_power(level)
	mag = int(weapon["mag"])
	ammo = mag
	reload_left = 0.0
	if _gun != null:
		_gun.queue_free()
	_gun = Models.gun(weapon["model"], weapon["tint"])
	var holder: Node3D = _hand if _hand != null else _pivot
	holder.add_child(_gun)
	var gb := Models.bounds(_gun)
	var length := maxf(gb.size.z, 0.01)
	var want := 1.15 if weapon["id"] in ["dmr", "lmg"] else (0.95 if weapon["id"] == "shotgun" else 0.85)
	_gun_scale = want / length
	_gun.scale = Vector3.ONE * _gun_scale
	if _hand == null:
		_gun.position = Vector3(0.3, 1.1, -0.3)
		_gun.rotation.y = PI


## Builds one of the undead, scaled for the wave it belongs to.
func setup_enemy(enemy_kind: String, wave: int) -> void:
	team = Team.UNDEAD
	kind = enemy_kind
	info = GameData.ENEMIES[enemy_kind]
	display_name = info["name"]
	color = Color("ec4a3c")
	max_hp = float(info["hp"]) * GameData.health_scale(wave)
	hp = max_hp
	speed = float(info["speed"]) * randf_range(0.92, 1.08)
	damage_mult = GameData.damage_scale(wave)
	attack_cd = randf_range(0.4, 1.2)
	collision_layer = 4
	collision_mask = 1 | 2
	_build(info["model"], float(info["scale"]), 0.45)
	var g := Models.gear(info["gear"])
	if _hand != null:
		_hand.add_child(g)
		g.scale = Vector3.ONE * 1.0
	else:
		g.queue_free()
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _build(model_name: String, unit_scale: float, radius: float) -> void:
	_scale = unit_scale
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius * unit_scale
	capsule.height = maxf(HEIGHT * unit_scale * 0.85, capsule.radius * 2.0 + 0.1)
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	_pivot = Node3D.new()
	add_child(_pivot)
	model = Models.character(model_name)
	_pivot.add_child(model)
	# KayKit characters face +Z; the unit's forward is -Z.
	model.rotation.y = PI
	var b := Models.bounds(model)
	var h := maxf(b.end.y, 0.5)
	model.scale = Vector3.ONE * (HEIGHT * unit_scale / h)
	_ap = Models.animation_player(model)
	_hand = Models.hand_slot(model)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).visible:
			_meshes.append(m)
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 0.25, 0.2, 0.55)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	play("Idle")


func alive() -> bool:
	return not dead


func center() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale * 0.55, 0)


func head_position() -> Vector3:
	return global_position + Vector3(0, HEIGHT * _scale + 0.35, 0)


func muzzle() -> Vector3:
	if _gun != null:
		return _gun.global_position + facing * 0.45 * _scale + Vector3(0, 0.05, 0)
	return global_position + Vector3(0, 1.2, 0) + facing * 0.6


func reach() -> float:
	return float(weapon["range"]) if team == Team.SQUAD else float(info["reach"])


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _flash <= 0.0 and _meshes.size() > 0 and _meshes[0].material_overlay != null:
		for m in _meshes:
			m.material_overlay = null
	if dead:
		return
	_lock = maxf(0.0, _lock - delta)
	if spawn_lock > 0.0:
		spawn_lock -= delta
		return
	if team == Team.SQUAD:
		if is_player and not autopilot:
			_player_think(delta)
		else:
			_bot_think(delta)
		_gun_think(delta)
	else:
		_undead_think(delta)
	var move_speed := speed * (float(weapon.get("move", 1.0)) if team == Team.SQUAD else 1.0)
	if team == Team.SQUAD and is_player and arena != null:
		move_speed *= arena.speed_mult
	var horizontal := move_dir * move_speed + knock
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	knock = knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if global_position.y < -0.05 or global_position.y > 0.4:
		global_position.y = 0.0
	# Face the target while shooting, otherwise the way we move.
	var look := facing
	if target != null and target.alive() and (team == Team.UNDEAD or shooting_time > 0.0 or move_dir.length() < 0.1):
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
	if _gun != null and _hand != null:
		# The hand bone wobbles with the animation; keep the barrel on target.
		_gun.global_basis = Basis.looking_at(facing, Vector3.UP).rotated(Vector3.UP, PI).scaled(Vector3.ONE * _gun_scale)
	_animate()


func _player_think(delta: float) -> void:
	move_dir = arena.input_move
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.15
		target = arena.nearest_enemy(global_position, reach(), true)


## Squad bots stay near the leader and shoot whatever is in range. The player's
## autopilot (used for screenshots) also lands here, kiting away from the undead.
func _bot_think(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.25
		target = arena.nearest_enemy(global_position, reach(), true)
	var desired := Vector3.ZERO
	if is_player:
		var threat := arena.nearest_enemy(global_position, 7.0, false)
		if threat != null:
			desired = (global_position - threat.global_position).normalized()
			desired = desired.rotated(Vector3.UP, 0.7 * _strafe)
		elif target == null:
			var far := arena.nearest_enemy(global_position, 60.0, false)
			if far != null and global_position.distance_to(far.global_position) > reach() * 0.8:
				desired = (far.global_position - global_position).normalized()
		desired += arena.keep_inside(global_position)
	else:
		var leader: Unit = arena.player
		var goal: Vector3 = leader.global_position + _formation if leader != null else global_position
		var to := goal - global_position
		to.y = 0
		if to.length() > 1.4:
			desired = to.normalized() * clampf(to.length() / 3.0, 0.4, 1.0)
	desired.y = 0
	move_dir = desired.normalized() * minf(desired.length(), 1.0) if desired.length() > 0.05 else Vector3.ZERO


func set_formation(offset: Vector3) -> void:
	_formation = offset


func _gun_think(delta: float) -> void:
	shooting_time = maxf(0.0, shooting_time - delta)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			ammo = mag
		return
	fire_cd -= delta
	if target == null or not target.alive() or fire_cd > 0.0:
		return
	if global_position.distance_to(target.global_position) > reach() + 0.5:
		return
	if ammo <= 0:
		reload()
		return
	fire_cd = 1.0 / (float(weapon["rate"]) * fire_rate_mult)
	ammo -= 1
	shooting_time = 0.35
	arena.fire(self)
	if ammo <= 0:
		reload()


func reload() -> void:
	if reload_left > 0.0 or ammo >= mag:
		return
	reload_left = float(weapon["reload"]) * reload_mult
	if is_player:
		Sfx.play("reload")


func _undead_think(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0 or target == null or not target.alive():
		_retarget = 0.6
		target = arena.nearest_squad(global_position)
	attack_cd -= delta
	if pending_hit >= 0.0:
		pending_hit -= delta
		if pending_hit < 0.0:
			_land_hit()
	if target == null:
		move_dir = Vector3.ZERO
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var r := reach()
	var desired := Vector3.ZERO
	if info["ranged"]:
		var sees: bool = arena.line_of_sight(center(), target.center())
		if dist > r * 0.85 or not sees:
			desired = dir
		elif dist < r * 0.45:
			desired = -dir
		else:
			desired = dir.cross(Vector3.UP) * _strafe * 0.5
		if dist <= r and sees and attack_cd <= 0.0 and _lock <= 0.0:
			attack_cd = float(info["cooldown"]) * randf_range(0.85, 1.2)
			one_shot("Spellcast_Shoot" if kind == "mage" else "1H_Ranged_Shoot", 1.2)
			arena.enemy_shoot(self, target)
	else:
		if dist > r * 0.8:
			desired = dir
		if dist <= r and attack_cd <= 0.0 and _lock <= 0.0:
			attack_cd = float(info["cooldown"]) * randf_range(0.9, 1.15)
			if kind == "boss":
				one_shot("2H_Melee_Attack_Chop", 1.0)
				pending_hit = 0.55
			else:
				one_shot("1H_Melee_Attack_Chop" if kind == "minion" else "2H_Melee_Attack_Slice", 1.3)
				pending_hit = 0.3
			Sfx.play("swing", 1.0 if kind != "boss" else 0.6)
	# Keep the horde from stacking into one blob.
	desired += arena.separation(self) * 0.9
	desired.y = 0
	if _lock > 0.0 and pending_hit >= 0.0:
		desired *= 0.15
	move_dir = desired.normalized() * minf(desired.length(), 1.0) if desired.length() > 0.05 else Vector3.ZERO


func _land_hit() -> void:
	if dead:
		return
	var dmg := float(info["damage"]) * damage_mult
	if kind == "boss":
		arena.slam(self, global_position + facing * 1.6, reach() + 0.8, dmg)
		return
	if target != null and target.alive() and global_position.distance_to(target.global_position) <= reach() + 0.6:
		target.take_damage(dmg, (target.global_position - global_position).normalized(), self)


## Returns true if this hit killed the unit.
func take_damage(amount: float, push: Vector3, source: Unit = null) -> bool:
	if dead or spawn_lock > 0.0:
		return false
	var real := amount * (1.0 - armor)
	if team == Team.SQUAD and arena != null:
		real *= arena.squad_damage_taken
	hp -= real
	_flash = 0.09
	for m in _meshes:
		m.material_overlay = _flash_mat
	push.y = 0
	knock += push.normalized() * (2.5 if kind != "boss" else 0.2)
	if arena != null:
		arena.on_unit_hurt(self, real, source)
	if hp <= 0.0:
		hp = 0.0
		die()
		return true
	if team == Team.UNDEAD and kind != "boss" and randf() < 0.25 and _lock <= 0.0 and pending_hit < 0.0:
		one_shot("Hit_A", 1.6)
	return false


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func die() -> void:
	dead = true
	move_dir = Vector3.ZERO
	velocity = Vector3.ZERO
	target = null
	collision_layer = 0
	collision_mask = 1
	pending_hit = -1.0
	_lock = 0.0
	one_shot("Death_A" if randf() < 0.5 else "Death_B", 1.0)
	died.emit(self)


## Brings a downed squad member back.
func revive(fraction: float) -> void:
	if not dead:
		heal(max_hp * fraction)
		return
	dead = false
	hp = max_hp * fraction
	collision_layer = 2
	collision_mask = 1 | 4
	_lock = 0.0
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


func spawn_rise() -> void:
	spawn_lock = 1.1
	one_shot("Spawn_Ground_Skeletons" if _ap != null and _ap.has_animation("Spawn_Ground_Skeletons") else "Spawn_Ground", 1.2)


func cheer() -> void:
	if not dead:
		one_shot("Cheer", 1.0)


func _animate() -> void:
	if _lock > 0.0:
		return
	var flat := Vector3(velocity.x, 0, velocity.z)
	var moving := flat.length() > 0.6
	if team == Team.SQUAD:
		if moving:
			var local := flat.normalized()
			var fwd := local.dot(facing)
			var side := local.dot(facing.cross(Vector3.UP))
			if fwd > 0.5:
				play("Running_A", 0.15, 1.1)
			elif fwd < -0.5:
				play("Walking_Backwards", 0.15, 1.5)
			elif side > 0:
				play("Running_Strafe_Right", 0.15)
			else:
				play("Running_Strafe_Left", 0.15)
		elif shooting_time > 0.0:
			play("2H_Ranged_Shooting", 0.12)
		else:
			play("2H_Ranged_Aiming", 0.25)
	else:
		if moving:
			if kind == "minion":
				play("Running_C" if _ap != null and _ap.has_animation("Running_C") else "Running_A", 0.2, 1.0)
			elif kind == "boss":
				play("Walking_D_Skeletons", 0.2, 1.2)
			else:
				play("Walking_A", 0.2, 1.3)
		else:
			play("Idle_Combat" if _ap != null and _ap.has_animation("Idle_Combat") else "Idle", 0.25)
