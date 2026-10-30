class_name Troop
extends Node3D
## An attacking troop in a raid: walks to its chosen target, steering around
## other buildings, and attacks when in range. Archers and wizards fire
## projectiles through the battle; melee troops hit directly.

const HEIGHT := 0.78
const SPEED_SCALE := 1.0

var battle: Battle
var kind := ""
var info: Dictionary
var level := 1
var max_hp := 50.0
var hp := 50.0
var damage := 10.0
var dead := false
var target: Building
var _cd := 0.3
var _model: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _lock := 0.0
var _retarget := 0.0
var _hit_pending := -1.0
var _flash := 0.0
var _meshes: Array[MeshInstance3D] = []

static var _flash_mat: StandardMaterial3D


func setup(p_kind: String, p_level: int) -> void:
	kind = p_kind
	info = GameData.troop(kind)
	level = p_level
	max_hp = float(GameData.at_level(info["hp"], level))
	hp = max_hp
	damage = float(GameData.at_level(info["damage"], level))
	_model = Models.character(info["model"], info["keep"])
	add_child(_model)
	_model.rotation.y = PI
	var b := Models.bounds(_model)
	_model.scale = Vector3.ONE * (HEIGHT / maxf(b.end.y, 0.3))
	_ap = Models.animation_player(_model)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).visible:
			_meshes.append(m)
	if _flash_mat == null:
		_flash_mat = Models.material(Color(1, 0.3, 0.2, 0.55), 0.0, true)
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# A little coloured disc so troops read clearly from far away.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.02
	disc.mesh = cyl
	disc.material_override = Models.material(Color(info["color"], 0.7), 0.6, true)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.02
	add_child(disc)
	_play("Idle")


func head() -> Vector3:
	return global_position + Vector3(0, HEIGHT + 0.25, 0)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for m in _meshes:
				m.material_overlay = null
	if dead or battle == null:
		return
	_lock = maxf(0.0, _lock - delta)
	_cd -= delta
	_retarget -= delta
	if _hit_pending >= 0.0:
		_hit_pending -= delta
		if _hit_pending < 0.0:
			_strike()
	if target == null or target.destroyed or _retarget <= 0.0:
		target = battle.pick_target(self)
		_retarget = 1.0 if target != null else 0.3
	if target == null:
		_play("Cheer")
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var reach := float(info["range"]) + 0.75
	if dist > reach:
		var dir := to / dist
		dir += battle.avoid(self, target) * 0.9
		dir.y = 0
		dir = dir.normalized()
		var step := float(info["speed"]) * SPEED_SCALE * delta
		global_position += dir * step
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0, 1))
		if _lock <= 0.0:
			_play("Running_A")
	else:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 10.0, 0, 1))
		if _cd <= 0.0 and _lock <= 0.0:
			_cd = 1.0 / float(info["rate"])
			_attack_anim()
			_hit_pending = 0.28
		elif _lock <= 0.0:
			_play("Idle_Combat" if _ap != null and _ap.has_animation("Idle_Combat") else "Idle")


func _attack_anim() -> void:
	match kind:
		"archer":
			_one_shot("2H_Ranged_Shoot", 1.4)
		"mage":
			_one_shot("Spellcast_Shoot", 1.5)
		"knight":
			_one_shot("1H_Melee_Attack_Slice_Horizontal", 1.4)
		_:
			_one_shot("2H_Melee_Attack_Chop", 1.5)


func _strike() -> void:
	if dead or target == null or target.destroyed:
		return
	if float(info["range"]) > 1.5:
		battle.troop_projectile(self, target)
	else:
		battle.hit_building(target, damage, self)
		Sfx.play("swing", randf_range(0.9, 1.2))


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.1
	for m in _meshes:
		m.material_overlay = _flash_mat
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_one_shot("Death_A", 1.2)
		battle.troop_died(self)


func _play(anim: String) -> void:
	if _ap == null or _anim == anim or not _ap.has_animation(anim):
		return
	_anim = anim
	_ap.play(anim, 0.15)


func _one_shot(anim: String, speed: float) -> void:
	if _ap == null or not _ap.has_animation(anim):
		return
	_anim = anim
	_ap.play(anim, 0.08, speed)
	_ap.seek(0.0, true)
	_lock = _ap.get_animation(anim).length / speed
