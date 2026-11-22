class_name Bot
extends RefCounted
## The brain of an AI player, run on the authority (this phone offline, or the
## server online). It picks a landing spot, loots, fights with a skill-based aim,
## heals, keeps ahead of the zone, follows and revives its squad leader, and rides
## along when the leader drives.

var f: Fighter
var game
var skill := 0.5
var drop_target := Vector3.ZERO
var jump_at := 0.0
var goal := Vector3.ZERO
var goal_kind := ""
var enemy: Fighter = null
var loot_id := -1
var think_t := 0.0
var react := 0.0
var strafe := 1.0
var strafe_t := 0.0
var last_seen := -100.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var detour_t := 0.0
var detour := Vector3.ZERO
var aim_error := Vector3.ZERO
var heal_wait := 0.0
var roam_t := 0.0


func _init(fighter: Fighter, g, bot_skill: float) -> void:
	f = fighter
	game = g
	skill = bot_skill
	strafe = 1.0 if randf() < 0.5 else -1.0


func leader() -> Fighter:
	for m in game.squad(f.team):
		if m != f and m.human and m.alive():
			return m
	return null


## Called by the match once the plane path is known.
func plan_drop(target: Vector3, along: float) -> void:
	drop_target = target
	jump_at = along


func update(delta: float) -> void:
	if not f.alive():
		return
	think_t -= delta
	match f.state:
		"plane":
			_plane()
			return
		"fall", "chute":
			_steer_to(drop_target, 1.0)
			f.want_jump = f.state == "fall" and f.global_position.y - game.island.height(f.global_position.x, f.global_position.z) < 140.0
			return
		"vehicle":
			f.move = Vector2.ZERO
			var l := leader()
			if l == null or l.state != "vehicle" or l.vehicle != f.vehicle:
				game.request(f, "exit", null)
			return
	if think_t <= 0.0:
		think_t = randf_range(0.22, 0.38)
		_think()
	_act(delta)


func _plane() -> void:
	var l := leader()
	if l != null:
		# Jump with the squad leader.
		if l.state != "plane":
			drop_target = l.global_position + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
			if l.state == "ground":
				drop_target = l.global_position
			game.request(f, "jump", null)
		return
	if game.plane_progress() >= jump_at:
		game.request(f, "jump", null)


func _think() -> void:
	# Look for someone to shoot.
	var best: Fighter = null
	var best_d := 1e9
	var sight := 75.0 + skill * 40.0
	var held := f.inv.current()
	if not held.is_empty():
		sight = maxf(sight, minf(float(GameData.stats(held)["range"]) * 1.4, 200.0))
	for o in game.fighters:
		if o == f or o.team == f.team or not o.alive() or o.state in ["plane", "fall"]:
			continue
		var d: float = f.global_position.distance_to(o.global_position)
		if d > sight or d >= best_d:
			continue
		if game.line_of_sight(f.eye(), o.chest_pos(), f, o):
			best = o
			best_d = d
	if best != null:
		if best != enemy:
			react = lerpf(0.9, 0.25, skill)
			aim_error = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * lerpf(2.5, 0.8, skill)
		enemy = best
		last_seen = game.clock
	elif enemy != null and (not enemy.alive() or game.clock - last_seen > 4.0):
		enemy = null
	# Pick what to do when not fighting.
	var zs: Dictionary = game.zone_state()
	var zc := Vector3(zs["next_center"].x, 0, zs["next_center"].y)
	var flat := Vector2(f.global_position.x, f.global_position.z)
	var outside_now := flat.distance_to(zs["center"]) > float(zs["radius"]) - 4.0
	var outside_next := flat.distance_to(zs["next_center"]) > float(zs["next_radius"]) * 0.85
	if f.state == "knocked":
		var mate := _nearest_mate()
		goal = mate.global_position if mate != null else f.global_position - _away_from_enemy() * 5.0
		goal_kind = "crawl"
		return
	var down := _knocked_mate()
	if down != null and (enemy == null or game.clock - last_seen > 2.0):
		goal = down.global_position
		goal_kind = "revive"
		return
	if outside_now or (outside_next and (bool(zs["shrinking"]) or float(zs["timer"]) < 25.0)):
		goal = zc + (Vector3(f.global_position.x, 0, f.global_position.z) - zc).normalized() * float(zs["next_radius"]) * 0.4
		goal_kind = "zone"
		loot_id = -1
		return
	if enemy == null and f.hp < 65.0 and _heal_choice() != "" and f.heal_t <= 0.0 and game.clock - last_seen > 3.0:
		goal_kind = "heal"
		return
	var l := leader()
	if l != null and l.alive() and f.global_position.distance_to(l.global_position) > 16.0:
		goal = l.global_position
		goal_kind = "follow"
		return
	if loot_id >= 0 and not game.loot.has(loot_id):
		loot_id = -1
	if loot_id < 0 and _needs_loot():
		loot_id = _find_loot(32.0 if l == null else 14.0)
	if loot_id >= 0:
		goal = game.loot[loot_id]["pos"]
		goal_kind = "loot"
		return
	if l != null:
		goal = l.global_position + Vector3(sin(f.id * 1.7), 0, cos(f.id * 1.7)) * 5.0
		goal_kind = "follow"
		return
	roam_t -= 0.3
	if goal_kind != "roam" or roam_t <= 0.0 or f.global_position.distance_to(goal) < 4.0:
		var ang := randf() * TAU
		var r := randf() * float(zs["next_radius"]) * 0.7
		goal = zc + Vector3(cos(ang), 0, sin(ang)) * r
		goal_kind = "roam"
		roam_t = randf_range(8.0, 20.0)


func _act(delta: float) -> void:
	var pos := f.global_position
	# Unstick: if barely moving while trying to, sidestep and hop.
	if f.move.length() > 0.5:
		if pos.distance_to(last_pos) < 0.04 * 60.0 * delta * 0.5:
			stuck_t += delta
		else:
			stuck_t = maxf(0.0, stuck_t - delta)
	last_pos = pos
	if stuck_t > 0.8:
		stuck_t = 0.0
		detour_t = 1.0
		detour = Vector3(-f.facing().z, 0, f.facing().x) * (1.0 if randf() < 0.5 else -1.0)
		f.want_jump = true
	if f.state == "knocked":
		_steer_to(goal, 1.0)
		return
	if enemy != null and enemy.alive() and game.clock - last_seen < 1.5 and f.inv.has_weapon():
		_fight(delta)
		return
	f.aiming = false
	if goal_kind == "heal":
		f.move = Vector2.ZERO
		if f.heal_t <= 0.0:
			var h := _heal_choice()
			if h != "":
				game.request(f, "heal", h)
			goal_kind = ""
		return
	if goal_kind == "revive":
		var down := _knocked_mate()
		if down != null and pos.distance_to(down.global_position) < 2.2:
			f.move = Vector2.ZERO
			if f.revive_target == null:
				game.request(f, "revive", down.id)
			return
	if goal_kind == "loot" and loot_id >= 0 and game.loot.has(loot_id):
		var lp: Vector3 = game.loot[loot_id]["pos"]
		if Vector2(pos.x - lp.x, pos.z - lp.z).length() < 1.8:
			game.request(f, "pickup", loot_id)
			loot_id = -1
			goal_kind = ""
			think_t = 0.0
			return
	if goal_kind == "follow" and pos.distance_to(goal) < 5.0:
		f.move = Vector2.ZERO
		var l := leader()
		if l != null:
			f.yaw = lerp_angle(f.yaw, l.yaw, 0.05)
		# Hop in if the leader is driving.
		if l != null and l.state == "vehicle" and l.vehicle != null and pos.distance_to(l.vehicle.global_position) < 12.0:
			game.request(f, "enter", l.vehicle.id)
		return
	if f.inv.has_weapon() and f.inv.current()["mag"] == 0:
		f.start_reload()
	_steer_to(goal, 1.0)
	var l2 := leader()
	if l2 != null and l2.state == "vehicle" and l2.vehicle != null and pos.distance_to(l2.vehicle.global_position) < 12.0:
		game.request(f, "enter", l2.vehicle.id)


func _fight(delta: float) -> void:
	var target := enemy.chest_pos()
	var d := f.global_position.distance_to(target)
	react -= delta
	aim_error = aim_error.lerp(Vector3.ZERO, delta * lerpf(0.4, 1.4, skill))
	var aim_at := target + aim_error * clampf(d / 30.0, 0.4, 2.0)
	if enemy.state == "knocked":
		aim_at = enemy.chest_pos()
	var to := aim_at - f.eye()
	var want_yaw := atan2(to.x, to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var turn := lerpf(3.0, 8.0, skill) * delta
	f.yaw = lerp_angle(f.yaw, want_yaw, clampf(turn, 0.0, 1.0))
	f.pitch = lerpf(f.pitch, want_pitch, clampf(turn, 0.0, 1.0))
	var held := f.inv.current()
	var s := GameData.stats(held)
	var ideal := clampf(float(s["range"]) * 0.45, 8.0, 60.0)
	f.aiming = d > 18.0
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.5, 1.4)
		strafe = -strafe
	var fwd := 0.0
	if d > ideal * 1.4:
		fwd = 1.0
	elif d < ideal * 0.5 and held["id"] != "shotgun":
		fwd = -0.6
	f.move = Vector2(strafe * (0.8 if not f.aiming else 0.5), fwd)
	if detour_t > 0.0:
		detour_t -= delta
		f.move.x = strafe
	if react <= 0.0 and absf(angle_difference(f.yaw, want_yaw)) < 0.25 and d < float(s["range"]) * 2.2:
		if int(held["mag"]) > 0:
			# Burst fire for autos, paced for single shots.
			if bool(s["auto"]) or randf() < 0.5 + skill * 0.3:
				f.try_fire(aim_at)
		else:
			f.start_reload()


func _steer_to(p: Vector3, spd: float) -> void:
	var to := p - f.global_position
	to.y = 0.0
	if detour_t > 0.0:
		detour_t -= game.get_physics_process_delta_time()
		to = detour * 10.0 + to.normalized() * 3.0
	if to.length() < 0.6:
		f.move = Vector2.ZERO
		return
	var want := atan2(to.x, to.z)
	f.yaw = lerp_angle(f.yaw, want, 0.18)
	f.pitch = lerpf(f.pitch, 0.0, 0.1)
	var off := angle_difference(f.yaw, want)
	f.move = Vector2(0, spd * clampf(1.0 - absf(off) / 1.2, 0.2, 1.0))


func _needs_loot() -> bool:
	if f.inv.weapon_count() < 2 or f.inv.vest == 0 or f.inv.helmet == 0:
		return true
	var w := f.inv.current()
	if not w.is_empty():
		var kind := String(GameData.weapon(String(w["id"]))["ammo"])
		if int(f.inv.ammo[kind]) < 60:
			return true
	return int(f.inv.heals["bandage"]) + int(f.inv.heals["medkit"]) < 3


func _find_loot(radius: float) -> int:
	var best := -1
	var best_d := radius
	for lid in game.loot_near(f.global_position, radius):
		var e: Dictionary = game.loot[lid]
		var it: Dictionary = e["item"]
		if not f.inv.wants(it):
			if not (it["kind"] == "weapon" and _better_gun(String(it["id"]))):
				continue
		var d: float = f.global_position.distance_to(e["pos"])
		if it["kind"] == "weapon" and not f.inv.has_weapon():
			d *= 0.3
		if d < best_d and not game.loot_claimed(lid, f):
			best_d = d
			best = lid
	if best >= 0:
		game.claim_loot(best, f)
	return best


func _better_gun(id: String) -> bool:
	var rank := ["pistol", "shotgun", "smg", "dmr", "ar", "sniper"]
	for w in f.inv.weapons:
		if (w as Dictionary).is_empty():
			return true
		if rank.find(String(w["id"])) < rank.find(id) and w["id"] == "pistol":
			return true
	return false


func _heal_choice() -> String:
	if f.hp < 50.0 and int(f.inv.heals["medkit"]) > 0:
		return "medkit"
	if f.hp < 75.0 and int(f.inv.heals["bandage"]) > 0:
		return "bandage"
	if int(f.inv.heals["drink"]) > 0 and f.boost < 20.0:
		return "drink"
	return ""


func _nearest_mate() -> Fighter:
	var best: Fighter = null
	var bd := 1e9
	for m in game.squad(f.team):
		if m != f and m.state == "ground":
			var d: float = f.global_position.distance_to(m.global_position)
			if d < bd:
				bd = d
				best = m
	return best


func _knocked_mate() -> Fighter:
	for m in game.squad(f.team):
		if m != f and m.state == "knocked" and f.global_position.distance_to(m.global_position) < 40.0:
			return m
	return null


func _away_from_enemy() -> Vector3:
	if enemy == null:
		return Vector3.ZERO
	return (enemy.global_position - f.global_position).normalized()
