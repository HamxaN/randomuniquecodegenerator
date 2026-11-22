class_name Fighter
extends CharacterBody3D
## One player on the island: you, a bot or someone online. The same body handles
## the plane ride, freefall, parachute, running and gunning, vehicles, being
## knocked down and eliminated. Whoever controls it (this device or the server's
## bot brain) simulates it; everyone else smoothly follows network updates.

enum Ctl { LOCAL, BOT, REMOTE }

const STATES := ["plane", "fall", "chute", "ground", "vehicle", "knocked", "dead"]
const GRAVITY := 22.0
const RUN := 6.0
const AIM_WALK := 3.3
const CRAWL := 1.3
const SWIM := 3.0
const JUMP_V := 7.4
const FALL_H := 20.0
const CHUTE_H := 10.0
const CHUTE_DOWN := 5.5
const AUTO_CHUTE := 85.0
const MODEL_SCALE := 0.85
const INTERP_DELAY := 0.12

signal died(f: Fighter)

var game  # Match (untyped: the match and its fighters reference each other)
var id := 0
var display_name := ""
var team := 0
var skin_id := "rogue"
var human := false
var peer := 0
var ctl := Ctl.BOT

var state := "plane"
var hp := 100.0
var bleed := 100.0
var boost := 0.0
var inv := Inventory.new()
var yaw := 0.0
var pitch := 0.0
var move := Vector2.ZERO
var aiming := false
var want_jump := false
var swimming := false
var kills := 0
var knocks := 0
var damage_dealt := 0.0
var place := 0
var vehicle = null  # Vehicle
var seat := -1
var fire_cd := 0.0
var reload_t := 0.0
var heal_t := 0.0
var heal_kind := ""
var bloom := 0.0
var revive_t := 0.0
var revive_target: Fighter = null
var revived_by: Fighter = null
var last_attacker := 0
var fired_t := 0.0
var brain  # Bot brain, on the authority only
var invulnerable := false  # only for the screenshot tour
var flags_remote := 0
var weapon_remote := -1
var scope_remote := 0

var _buf: Array = []
var _model: Node3D
var _ap: AnimationPlayer
var _hand: Node3D
var _gun: GunModel
var _gun_key := ""
var _chute: Node3D
var _tag: Label3D
var _anim := ""
var _lock := 0.0
var _body_shape: CollisionShape3D
var _head_shape: CollisionShape3D
var _visual := true
var _prev_remote := Vector3.ZERO
var _remote_vel := Vector3.ZERO
var _step_t := 0.0
var _was_floor := true
var _flash: OmniLight3D


func setup(g, info: Dictionary, control: int, visuals: bool) -> void:
	game = g
	id = int(info["id"])
	display_name = String(info["name"])
	team = int(info["team"])
	skin_id = String(info.get("skin", "rogue"))
	human = bool(info.get("human", false))
	peer = int(info.get("peer", 0))
	ctl = control
	_visual = visuals
	name = "F%d" % id
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	_body_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.45
	_body_shape.shape = cap
	_body_shape.position.y = 0.73
	add_child(_body_shape)
	_head_shape = CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.19
	_head_shape.shape = sph
	_head_shape.position.y = 1.62
	add_child(_head_shape)
	if visuals:
		_build_visuals()


func _build_visuals() -> void:
	var sk := GameData.skin(skin_id)
	_model = Models.character(String(sk["model"]))
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_ap = Models.animation_player(_model)
	_hand = Models.hand_slot(_model)
	for a in ["Death_A", "Jump_Land", "2H_Ranged_Reload", "1H_Ranged_Reload", "Use_Item", "PickUp", "Throw", "Hit_A", "Lie_StandUp"]:
		if _ap != null and _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_NONE
	_chute = _make_chute(GameData.TEAM_COLORS[team % GameData.TEAM_COLORS.size()])
	_chute.visible = false
	add_child(_chute)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0011
	_tag.font_size = 30
	_tag.outline_size = 8
	_tag.position.y = 2.25
	_tag.text = display_name
	_tag.modulate = GameData.TEAM_COLORS[team % GameData.TEAM_COLORS.size()]
	_tag.visible = false
	add_child(_tag)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.45)
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	add_child(_flash)
	_play("Idle")


func _make_chute(color: Color) -> Node3D:
	var root := Node3D.new()
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.4
	sm.height = 2.2
	sm.is_hemisphere = true
	sm.radial_segments = 16
	sm.rings = 6
	canopy.mesh = sm
	var m := Models.material(color)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = m
	canopy.position.y = 4.6
	canopy.scale = Vector3(1.0, 0.55, 0.75)
	root.add_child(canopy)
	var stripe := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 2.42
	sm2.height = 2.22
	sm2.is_hemisphere = true
	sm2.radial_segments = 16
	sm2.rings = 6
	stripe.mesh = sm2
	var m2 := Models.material(Color.WHITE)
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	stripe.material_override = m2
	stripe.position.y = 4.6
	stripe.scale = Vector3(0.35, 0.56, 0.76)
	root.add_child(stripe)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var line := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.01
			cm.bottom_radius = 0.01
			cm.height = 3.6
			cm.radial_segments = 4
			line.mesh = cm
			line.material_override = Models.material(Color(0.9, 0.9, 0.9))
			var top := Vector3(sx * 1.9, 4.6, sz * 1.3)
			var bottom := Vector3(sx * 0.2, 1.5, sz * 0.1)
			line.position = (top + bottom) * 0.5
			line.look_at_from_position(line.position, top, Vector3.FORWARD if absf(sx) < 0.01 else Vector3.UP)
			line.rotate_object_local(Vector3.RIGHT, PI / 2)
			root.add_child(line)
	return root


# --- Queries -----------------------------------------------------------------

func alive() -> bool:
	return state != "dead"


func standing() -> bool:
	return state == "ground" or state == "vehicle"


func can_shoot() -> bool:
	return state == "ground" and not swimming and inv.has_weapon() and reload_t <= 0.0


func facing() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func aim_dir() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Where shots start: eye height, slightly over the right shoulder.
func eye() -> Vector3:
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	var h := 1.5 if state != "knocked" else 0.5
	return global_position + Vector3(0, h, 0) + right * 0.25


func head_pos() -> Vector3:
	return global_position + Vector3(0, 1.62 if state != "knocked" else 0.45, 0)


func chest_pos() -> Vector3:
	return global_position + Vector3(0, 1.1 if state != "knocked" else 0.35, 0)


func visuals_ok() -> bool:
	return _visual


func state_code() -> int:
	return STATES.find(state)


func flags() -> int:
	return int(aiming) | (int(fired_t > 0.0) << 1) | (int(reload_t > 0.0) << 2) | (int(heal_t > 0.0) << 3) | (int(swimming) << 4)


func weapon_code() -> int:
	var w := inv.current()
	if w.is_empty():
		return -1
	return GameData.WEAPONS.keys().find(String(w["id"]))


func scope_code() -> int:
	var w := inv.current()
	if w.is_empty():
		return 0
	return ["", "red_dot", "scope2", "scope4", "scope8"].find(String((w["att"] as Dictionary).get("scope", "")))


# --- Simulation ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if ctl == Ctl.REMOTE:
		return
	fire_cd = maxf(0.0, fire_cd - delta)
	fired_t = maxf(0.0, fired_t - delta)
	bloom = maxf(0.0, bloom - delta * 2.2)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			game.request(self, "reload_done", null)
	match state:
		"plane":
			velocity = Vector3.ZERO
			global_position = game.plane_pos()
		"fall":
			_sim_fall(delta)
		"chute":
			_sim_chute(delta)
		"ground":
			_sim_ground(delta, AIM_WALK if aiming else RUN)
		"knocked":
			_sim_ground(delta, CRAWL)
		"vehicle":
			if vehicle != null:
				global_position = vehicle.seat_position(seat)
				velocity = vehicle.velocity
		"dead":
			velocity = Vector3.ZERO


func _move_dir() -> Vector3:
	var f := facing()
	var right := Vector3(-f.z, 0, f.x)
	return (f * move.y + right * move.x).limit_length(1.0)


func _sim_fall(delta: float) -> void:
	var dir := _move_dir()
	var dive := clampf(move.y, 0.0, 1.0)
	velocity.x = move_toward(velocity.x, dir.x * FALL_H, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * FALL_H, 30.0 * delta)
	velocity.y = move_toward(velocity.y, -(32.0 + dive * 18.0), 40.0 * delta)
	move_and_slide()
	var above: float = global_position.y - game.island.height(global_position.x, global_position.z)
	if above < AUTO_CHUTE or want_jump:
		want_jump = false
		state = "chute"
		if ctl == Ctl.LOCAL:
			Sfx.play("jump")
	if is_on_floor():
		_land()


func _sim_chute(delta: float) -> void:
	var dir := _move_dir()
	velocity.x = move_toward(velocity.x, dir.x * CHUTE_H, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * CHUTE_H, 12.0 * delta)
	velocity.y = move_toward(velocity.y, -CHUTE_DOWN - maxf(0.0, move.y) * 2.0, 25.0 * delta)
	move_and_slide()
	if is_on_floor() or global_position.y <= Island.SEA_LEVEL - 0.6:
		_land()


func _land() -> void:
	state = "ground"
	velocity = Vector3.ZERO
	if ctl == Ctl.LOCAL:
		Sfx.play("land")
	game.request(self, "landed", null)


func _sim_ground(delta: float, speed: float) -> void:
	var dir := _move_dir()
	if heal_t > 0.0:
		speed *= 0.6
	if swimming:
		speed = SWIM
	velocity.x = move_toward(velocity.x, dir.x * speed, 45.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 45.0 * delta)
	if is_on_floor():
		if want_jump and state == "ground" and not swimming:
			velocity.y = JUMP_V
			if ctl == Ctl.LOCAL:
				Sfx.play("jump", 1.0, -4.0)
		else:
			velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	want_jump = false
	move_and_slide()
	# The sea: float at the surface and swim slowly.
	var water := Island.SEA_LEVEL - 1.15
	swimming = global_position.y < water + 0.05 and game.island.height(global_position.x, global_position.z) < water
	if global_position.y < water:
		global_position.y = water
		velocity.y = maxf(velocity.y, 0.0)
	if ctl == Ctl.LOCAL and is_on_floor() and not _was_floor and velocity.y <= 0.0:
		Sfx.play("land", 1.1, -10.0)
	_was_floor = is_on_floor()
	# Don't walk off the edge of the world.
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > Island.EXTENT - 5.0:
		flat = flat.normalized() * (Island.EXTENT - 5.0)
		global_position.x = flat.x
		global_position.z = flat.y


## Fires the held weapon towards [param target] if it can. Used by the local
## player and bots; the match resolves hits on the authority.
func try_fire(target: Vector3) -> bool:
	if not can_shoot() or fire_cd > 0.0:
		return false
	var w := inv.current()
	var s := GameData.stats(w)
	if int(w["mag"]) <= 0:
		start_reload()
		return false
	inv.use_round()
	if heal_t > 0.0:
		game.request(self, "heal_cancel", null)
	fire_cd = 60.0 / float(s["rpm"])
	fired_t = 0.35
	var origin := eye()
	var base := (target - origin).normalized()
	var spread := float(s["ads"]) if aiming else float(s["hip"])
	spread *= 1.0 + bloom
	if Vector2(velocity.x, velocity.z).length() > 1.0 and not aiming:
		spread *= 1.3
	var dirs := PackedVector3Array()
	for i in int(s["pellets"]):
		dirs.append(_jitter(base, deg_to_rad(spread)))
	bloom = minf(bloom + float(s["recoil"]) * 0.12, 1.6)
	game.fire(self, origin, dirs)
	if int(w["mag"]) <= 0 and inv.reload_amount() > 0:
		start_reload()
	return true


func _jitter(dir: Vector3, angle: float) -> Vector3:
	if angle <= 0.0:
		return dir
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var a := dir.cross(up).normalized()
	var b := dir.cross(a).normalized()
	var r := sqrt(randf()) * tan(angle)
	var t := randf() * TAU
	return (dir + a * cos(t) * r + b * sin(t) * r).normalized()


func start_reload() -> void:
	if reload_t > 0.0 or state != "ground" or inv.reload_amount() <= 0:
		return
	var s := GameData.stats(inv.current())
	reload_t = float(s["reload"])
	if heal_t > 0.0:
		game.request(self, "heal_cancel", null)
	one_shot("1H_Ranged_Reload" if inv.current()["id"] == "pistol" else "2H_Ranged_Reload", 2.4 / maxf(reload_t, 0.5) * 0.9)
	if ctl == Ctl.LOCAL:
		Sfx.play("reload")


## Effects for a shot this fighter fired (everyone sees these).
func shot_fx(to: Vector3, weapon_id: String, quiet: bool) -> void:
	if not _visual:
		return
	fired_t = 0.35
	var from := muzzle_pos()
	game.tracer(from, to)
	if _flash != null and not quiet:
		_flash.global_position = from
		_flash.light_energy = 2.5
		var tw := _flash.create_tween()
		tw.tween_property(_flash, "light_energy", 0.0, 0.08)
	var key := String(GameData.weapon(weapon_id)["sound"])
	if ctl == Ctl.LOCAL:
		Sfx.play(key, 1.0, -5.0 if quiet else 0.0)
	else:
		Sfx.play_at(key, global_position, 1.0)
	if _anim != "2H_Ranged_Shoot" and _lock <= 0.0 and Vector2(velocity.x, velocity.z).length() < 0.5:
		_play("2H_Ranged_Shooting" if weapon_id != "pistol" else "1H_Ranged_Shooting", 0.08)


func muzzle_pos() -> Vector3:
	if _gun != null and _gun.muzzle != null and _gun.is_inside_tree():
		return _gun.muzzle.global_position
	return eye() + aim_dir() * 0.6


# --- Network following -----------------------------------------------------------

## A state update for a fighter someone else controls.
func push_state(t: float, pos: Vector3, y: float, p: float, st: int, fl: int, health: float, wcode: int, scode: int) -> void:
	if st >= 0 and st < STATES.size():
		var new_state: String = STATES[st]
		if new_state != state:
			_enter_state_remote(new_state)
	hp = health
	flags_remote = fl
	aiming = bool(fl & 1)
	swimming = bool(fl & 16)
	weapon_remote = wcode
	scope_remote = scode
	_buf.append([t, pos, y, p])
	while _buf.size() > 12:
		_buf.pop_front()


func _enter_state_remote(new_state: String) -> void:
	var old := state
	state = new_state
	if new_state == "dead" and old != "dead":
		_on_dead_visual()
	if new_state == "knocked":
		_set_knocked_shapes(true)
	elif old == "knocked":
		_set_knocked_shapes(false)


func _remote_follow() -> void:
	if _buf.is_empty():
		return
	var rt: float = game.clock - INTERP_DELAY
	var a: Array = _buf[0]
	var b: Array = _buf[_buf.size() - 1]
	for i in _buf.size() - 1:
		if float(_buf[i][0]) <= rt and float(_buf[i + 1][0]) >= rt:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var span := float(b[0]) - float(a[0])
	var k := 1.0 if span <= 0.0001 else clampf((rt - float(a[0])) / span, 0.0, 1.2)
	var pos: Vector3 = (a[1] as Vector3).lerp(b[1], k)
	global_position = pos
	yaw = lerp_angle(float(a[2]), float(b[2]), clampf(k, 0.0, 1.0))
	pitch = lerpf(float(a[3]), float(b[3]), clampf(k, 0.0, 1.0))


# --- Visuals ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	if ctl == Ctl.REMOTE:
		_remote_follow()
		_remote_vel = (global_position - _prev_remote) / maxf(delta, 0.001)
		_prev_remote = global_position
	if not _visual:
		return
	_lock = maxf(0.0, _lock - delta)
	if ctl != Ctl.LOCAL and state != "dead":
		_model.visible = state != "plane" and (state != "vehicle" or (vehicle != null and vehicle.kind == "bike"))
	_chute.visible = state == "chute"
	if state == "dead":
		return
	_model.rotation.y = yaw
	_update_gun()
	_animate()
	if ctl == Ctl.LOCAL and state == "ground" and is_on_floor() and Vector2(velocity.x, velocity.z).length() > 2.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.36
			Sfx.play("step", randf_range(0.9, 1.1))


func set_tag_visible(on: bool) -> void:
	if _tag != null:
		_tag.visible = on and state != "dead" and state != "plane"


func _update_gun() -> void:
	var w := inv.current()
	var key := ""
	var data := {}
	if ctl == Ctl.REMOTE:
		if weapon_remote >= 0 and weapon_remote < GameData.WEAPONS.size():
			var wid: String = GameData.WEAPONS.keys()[weapon_remote]
			var scope: String = ["", "red_dot", "scope2", "scope4", "scope8"][clampi(scope_remote, 0, 4)]
			data = {"id": wid, "att": {"scope": scope} if scope != "" else {}}
			key = wid + scope
	elif not w.is_empty():
		data = w
		key = String(w["id"]) + str(w["att"])
	var show := key != "" and state == "ground" and not swimming
	if key != _gun_key:
		_gun_key = key
		if _gun != null:
			_gun.queue_free()
			_gun = null
		if key != "":
			_gun = GunModel.make(data)
			(_hand if _hand != null else self).add_child(_gun)
	if _gun != null:
		_gun.visible = show
		if show:
			var aim := aim_dir()
			_gun.global_basis = Basis.looking_at(aim, Vector3.UP)


func _animate() -> void:
	if _ap == null or _lock > 0.0:
		return
	var v := _remote_vel if ctl == Ctl.REMOTE else velocity
	var flat := Vector3(v.x, 0, v.z)
	var speed := flat.length()
	var armed := (weapon_remote >= 0) if ctl == Ctl.REMOTE else inv.has_weapon()
	var pistol := armed and ((ctl != Ctl.REMOTE and String(inv.current().get("id", "")) == "pistol") or (ctl == Ctl.REMOTE and weapon_remote == 0))
	match state:
		"fall":
			_play("Jump_Idle", 0.3)
			_model.rotation.x = lerpf(_model.rotation.x, 0.9, 0.08)
			return
		"chute":
			_play("Jump_Idle", 0.3)
			_model.rotation.x = lerpf(_model.rotation.x, 0.0, 0.1)
			return
		"vehicle":
			_play("Sit_Chair_Idle", 0.25)
			_model.rotation.x = 0.0
			return
		"knocked":
			_play("Lie_Idle", 0.3)
			_model.rotation.x = 0.0
			return
	_model.rotation.x = 0.0
	if swimming:
		_play("Walking_A", 0.25, 0.7)
		return
	var on_floor := is_on_floor() if ctl != Ctl.REMOTE else absf(v.y) < 3.0
	if not on_floor:
		_play("Jump_Idle", 0.2)
		return
	var aim_now := aiming or fired_t > 0.0 or bool(flags_remote & 2)
	if speed > 0.6:
		var f := facing()
		var fwd := flat.normalized().dot(f)
		var side := flat.normalized().dot(Vector3(-f.z, 0, f.x))
		if fwd > 0.5:
			_play("Walking_B" if aiming else "Running_A", 0.15, 1.15 if not aiming else 1.3)
		elif fwd < -0.5:
			_play("Walking_Backwards", 0.15, 1.5)
		elif side < 0:
			_play("Running_Strafe_Right", 0.15)
		else:
			_play("Running_Strafe_Left", 0.15)
	elif armed:
		if aim_now:
			_play(("1H" if pistol else "2H") + "_Ranged_Aiming", 0.15)
		else:
			_play(("1H" if pistol else "2H") + "_Ranged_Aiming", 0.3)
	else:
		_play("Idle", 0.3)


func _play(anim_name: String, blend: float = 0.2, speed: float = 1.0) -> void:
	if _ap == null or _anim == anim_name or not _ap.has_animation(anim_name):
		return
	_anim = anim_name
	_ap.play(anim_name, blend, speed)


func one_shot(anim_name: String, speed: float = 1.0) -> void:
	if _ap == null or not _ap.has_animation(anim_name):
		return
	_anim = anim_name
	_ap.play(anim_name, 0.1, speed)
	_lock = _ap.get_animation(anim_name).length / speed * 0.95


# --- Health (applied on the authority, mirrored to clients) ----------------------

func set_knocked() -> void:
	state = "knocked"
	bleed = 100.0
	aiming = false
	reload_t = 0.0
	heal_t = 0.0
	_set_knocked_shapes(true)


func set_revived() -> void:
	state = "ground"
	hp = 25.0
	_set_knocked_shapes(false)
	one_shot("Lie_StandUp", 1.4)


func _set_knocked_shapes(on: bool) -> void:
	if _body_shape == null:
		return
	(_body_shape.shape as CapsuleShape3D).height = 0.8 if on else 1.45
	_body_shape.position.y = 0.4 if on else 0.73
	_head_shape.position.y = 0.45 if on else 1.62
	_head_shape.position.z = 0.6 if on else 0.0


func set_dead() -> void:
	if state == "dead":
		return
	state = "dead"
	hp = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if vehicle != null:
		vehicle.leave(self)
	_on_dead_visual()
	died.emit(self)


func _on_dead_visual() -> void:
	collision_layer = 0
	if not _visual:
		return
	if _tag != null:
		_tag.visible = false
	if _gun != null:
		_gun.visible = false
	_chute.visible = false
	_model.visible = true
	_model.rotation.x = 0.0
	if _ap != null:
		_ap.play("Death_A", 0.1)
		_anim = "Death_A"
		_lock = 999.0
	# Fade away after a while.
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_callback(func() -> void: _model.visible = false)
