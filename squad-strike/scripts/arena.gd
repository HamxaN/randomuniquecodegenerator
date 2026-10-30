class_name Arena
extends Node3D
## One match: builds the map, runs the waves, fires the bullets and paints the
## explosions. The HUD reads its state; units ask it about the battlefield.

signal exit_requested(play_again: bool)

const CAM_OFFSET := Vector3(0, 12.0, 8.6)
const HALF := Vector2(22.0, 15.0)
const GRENADE_RADIUS := 4.6
const GRENADE_DAMAGE := 120.0
const STRIKE_DAMAGE := 170.0
const STRIKE_RADIUS := 4.4

var arena_index := 0
var player: Unit
var squad: Array[Unit] = []
var undead: Array[Unit] = []
var hud: Hud
var camera: Camera3D
var input_move := Vector3.ZERO
var autopilot := false

# Perks and operator bonuses.
var speed_mult := 1.0
var squad_damage_taken := 1.0
var damage_bonus := 1.0
var grenade_power := 1.0
var streak_mult := 1.0
var perks_taken: Array[String] = []

var wave := 0
var state := "intro"
var state_time := 0.0
var queue: Array[String] = []
var spawn_timer := 0.0
var kills := 0
var coins := 0
var xp_gain := 0
var streak := 0.0
var grenade_cd := 0.0
var grenade_max := 8.0
var dash_cd := 0.0
var dash_max := 3.2
var dash_time := 0.0
var revived := false
var boss: Unit
var match_time := 0.0

var _shake := 0.0
var _cam_pos := Vector3.ZERO
var _spawn_points: Array[Vector3] = []
var _bolts: Array[Dictionary] = []
var _grenades: Array[Dictionary] = []
var _pickups: Array[Dictionary] = []
var _tracers: Array[MeshInstance3D] = []
var _tracer_next := 0
var _numbers: Array[Label3D] = []
var _number_next := 0
var _flash_tex: Texture2D
var _decor_rng := RandomNumberGenerator.new()
var _mats := {}


func _ready() -> void:
	_flash_tex = load("res://assets/fx/burst.png")
	_decor_rng.seed = 4242 + arena_index
	MapBuilder.build(self, arena_index)
	_spawn_points = MapBuilder.spawn_points()
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.far = 160.0
	add_child(camera)
	camera.current = true
	_make_pools()
	_spawn_squad()
	_cam_pos = player.global_position + CAM_OFFSET
	camera.global_position = _cam_pos + Vector3(0, 6, 6)
	camera.look_at(player.global_position + Vector3(0, 1, 0))
	hud = Hud.new()
	hud.arena = self
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	state = "intro"
	state_time = 2.2
	hud.banner(GameData.arena(arena_index)["name"], "SURVIVE THE UNDEAD")
	Ads.hide_banner()


func _spawn_squad() -> void:
	var op := GameData.operator(Save.operator)
	player = _make_squad(op, Save.weapon, Save.weapon_level(Save.weapon), true, Vector3(0, 0, 4))
	player.autopilot = autopilot
	grenade_max = 8.0 * float(op["grenade_cd"])
	dash_max = 3.2 * float(op["dash_cd"])
	var mates: Array = []
	for o in GameData.OPERATORS:
		if o["id"] != op["id"]:
			mates.append(o)
	var offsets := [Vector3(-2.6, 0, 1.8), Vector3(2.6, 0, 1.8)]
	var mate_weapons := ["smg", "ar"]
	for i in 2:
		var u := _make_squad(mates[i], mate_weapons[i], 1, false, Vector3(0, 0, 4) + offsets[i])
		u.set_formation(offsets[i])
		u.damage_mult *= 0.45


func _make_squad(op: Dictionary, weapon_id: String, level: int, is_player: bool, pos: Vector3) -> Unit:
	var u := Unit.new()
	u.arena = self
	u.setup_squad(op, weapon_id, level, is_player)
	add_child(u)
	u.global_position = pos
	squad.append(u)
	u.died.connect(_on_squad_died)
	return u


func _process(delta: float) -> void:
	match_time += delta
	_update_camera(delta)
	_update_bolts(delta)
	_update_grenades(delta)
	_update_pickups(delta)
	grenade_cd = maxf(0.0, grenade_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	if dash_time > 0.0:
		dash_time -= delta
		player.knock = player.facing * 15.0 if player.move_dir.length() < 0.1 else player.move_dir.normalized() * 15.0
	if autopilot and state == "fight":
		_autopilot(delta)
	_read_keyboard()
	match state:
		"intro":
			state_time -= delta
			if state_time <= 0.0:
				_start_wave(1)
		"fight":
			_run_wave(delta)
		"break":
			state_time -= delta
			if state_time <= 0.0:
				_start_wave(wave + 1)


func _read_keyboard() -> void:
	if autopilot or hud == null or hud.stick_active():
		return
	var k := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.z += 1
	input_move = k.normalized()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			dash()
		KEY_G:
			throw_grenade()
		KEY_F:
			airstrike()
		KEY_R:
			player.reload()


func _autopilot(_delta: float) -> void:
	if grenade_cd <= 0.0 and alive_undead() >= 4:
		throw_grenade()
	if streak_ready():
		airstrike()


func _start_wave(n: int) -> void:
	wave = n
	queue = GameData.wave(n)
	state = "fight"
	spawn_timer = 0.6
	var boss_wave := n % 5 == 0
	hud.banner("WAVE %d" % n, "BOSS INCOMING" if boss_wave else "%d UNDEAD" % queue.size(), boss_wave)
	Sfx.play("wave")


func _run_wave(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0 and queue.size() > 0 and alive_undead() < GameData.MAX_ALIVE:
		spawn_timer = maxf(0.25, 0.65 - wave * 0.025)
		_spawn_enemy(queue.pop_front())
	if queue.is_empty() and alive_undead() == 0:
		_wave_cleared()


func _spawn_enemy(kind: String, at: Variant = null) -> void:
	var best := Vector3.ZERO
	var best_score := -1.0
	for i in 4:
		var p: Vector3 = _spawn_points[randi() % _spawn_points.size()]
		p += Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		var d := p.distance_to(player.global_position)
		if d > best_score:
			best_score = d
			best = p
	if at is Vector3:
		best = at
	var u := Unit.new()
	u.arena = self
	u.setup_enemy(kind, wave)
	add_child(u)
	u.global_position = best
	u.rotation.y = randf() * TAU
	u.spawn_rise()
	undead.append(u)
	u.died.connect(_on_undead_died)
	_dust(best, Color(0.35, 0.3, 0.25), 18)
	if kind == "boss":
		boss = u
		shake(0.6)


func _wave_cleared() -> void:
	var bonus := GameData.wave_bonus(wave)
	coins += bonus
	xp_gain += 40 + wave * 10
	for u in squad:
		if u.dead:
			u.revive(0.5)
		else:
			u.heal(u.max_hp * 0.2)
		u.cheer()
	hud.wave_cleared(wave, bonus)
	Sfx.play("levelup")
	if wave % 2 == 0 and autopilot:
		choose_perk(GameData.perk_choices(wave * 31 + kills)[0])
	elif wave % 2 == 0:
		state = "perk"
		hud.show_perks(GameData.perk_choices(wave * 31 + kills))
	else:
		state = "break"
		state_time = 3.6


func choose_perk(perk: Dictionary) -> void:
	perks_taken.append(perk["id"])
	match perk["id"]:
		"damage":
			damage_bonus *= 1.2
		"rate":
			player.fire_rate_mult *= 1.15
		"hp":
			player.max_hp += 30.0
			player.hp = player.max_hp
		"reload":
			player.reload_mult *= 0.65
		"mag":
			player.mag = int(player.mag * 1.5)
			player.ammo = player.mag
		"speed":
			speed_mult *= 1.12
		"grenade":
			grenade_power *= 1.4
		"squad":
			for u in squad:
				u.revive(1.0)
				u.heal(u.max_hp)
		"streak":
			streak_mult *= 1.3
	state = "break"
	state_time = 2.4


## Raises a group of the undead in an arc in front of the squad (used by the screenshot run).
func spawn_group(kinds: Array, distance: float) -> void:
	for i in kinds.size():
		var a := -0.9 + 1.8 * float(i) / maxf(1.0, float(kinds.size() - 1))
		var p := player.global_position + Vector3(sin(a), 0, -cos(a)) * distance
		p.x = clampf(p.x, -HALF.x + 1.5, HALF.x - 1.5)
		p.z = clampf(p.z, -HALF.y + 1.5, HALF.y - 1.5)
		_spawn_enemy(kinds[i], p)


func alive_undead() -> int:
	var n := 0
	for u in undead:
		if not u.dead:
			n += 1
	return n


func remaining() -> int:
	return alive_undead() + queue.size()


# ---------------------------------------------------------------- Queries from units

func nearest_enemy(from: Vector3, max_range: float, need_sight: bool) -> Unit:
	var cands: Array = []
	for u in undead:
		if u.dead or u.spawn_lock > 0.0:
			continue
		var d := from.distance_to(u.global_position)
		if d <= max_range:
			cands.append([d, u])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(cands.size(), 3):
		var u: Unit = cands[i][1]
		if not need_sight or line_of_sight(from + Vector3(0, 1.2, 0), u.center()):
			return u
	return null


func nearest_squad(from: Vector3) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in squad:
		if u.dead:
			continue
		var d := from.distance_squared_to(u.global_position)
		# The player draws a little more attention than the bots.
		if u.is_player:
			d *= 0.6
		if d < best_d:
			best_d = d
			best = u
	return best


func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func separation(me: Unit) -> Vector3:
	var push := Vector3.ZERO
	for u in undead:
		if u == me or u.dead:
			continue
		var d := me.global_position - u.global_position
		d.y = 0
		var l := d.length()
		var r := 1.1 * (2.0 if u.kind == "boss" or me.kind == "boss" else 1.0)
		if l < r and l > 0.001:
			push += d / l * (r - l) / r
	return push


func keep_inside(p: Vector3) -> Vector3:
	var out := Vector3.ZERO
	var m := 4.0
	if p.x < -HALF.x + m:
		out.x += 1.0
	if p.x > HALF.x - m:
		out.x -= 1.0
	if p.z < -HALF.y + m:
		out.z += 1.0
	if p.z > HALF.y - m:
		out.z -= 1.0
	return out * 1.5


# ---------------------------------------------------------------- Shooting

func fire(u: Unit) -> void:
	var w := u.weapon
	var origin := u.muzzle()
	origin.y = u.global_position.y + 1.15
	var dir := u.facing
	if u.target != null:
		var to := u.target.center() - origin
		to.y = 0
		if to.length() > 0.1:
			dir = to.normalized()
	var base := float(w["damage"]) * u.weapon_power * u.damage_mult * (damage_bonus if u.is_player else 1.0)
	var spread := deg_to_rad(float(w["spread"]))
	for p in int(w["pellets"]):
		var d := dir.rotated(Vector3.UP, randf_range(-spread, spread) * 0.5)
		_hitscan(u, origin, d, float(w["range"]) + 1.5, base, int(w["pierce"]))
	_muzzle_flash(u.muzzle(), w["id"] == "shotgun")
	if u.is_player:
		Sfx.play(w["sound"])
		if w["id"] in ["shotgun", "dmr"]:
			shake(0.12)
	else:
		Sfx.play(w["sound"], 1.05, -9.0)


func _hitscan(shooter: Unit, origin: Vector3, dir: Vector3, length: float, dmg: float, pierce: int) -> void:
	var space := get_world_3d().direct_space_state
	var from := origin
	var end := origin + dir * length
	var exclude: Array[RID] = [shooter.get_rid()]
	var left := pierce + 1
	var stop := end
	while left > 0:
		var q := PhysicsRayQueryParameters3D.create(from, end, 1 | 4, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col: Object = hit["collider"]
		var pos: Vector3 = hit["position"]
		if col is Unit:
			var u := col as Unit
			var crit := randf() < 0.1
			var amount := dmg * (1.6 if crit else 1.0)
			u.take_damage(amount, dir, shooter)
			if shooter.is_player:
				damage_number(pos + Vector3(0, 0.6, 0), amount, crit)
				hud.hit_marker(u.dead)
			_sparks(pos, Color(0.95, 0.92, 0.85), 6)
			exclude.append(u.get_rid())
			left -= 1
			from = pos
			stop = pos
		else:
			stop = pos
			_sparks(pos, Color(1.0, 0.8, 0.4), 5)
			break
	_tracer(origin, stop, shooter.is_player)


func enemy_shoot(u: Unit, target: Unit) -> void:
	var from := u.global_position + Vector3(0, 1.3 * (2.0 if u.kind == "boss" else 1.0), 0) + u.facing * 0.6
	var aim := target.center() + target.velocity * 0.25
	var dir := aim - from
	dir.y = 0
	dir = dir.normalized()
	var node: Node3D
	if u.kind == "mage":
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.56
		orb.mesh = sm
		orb.material_override = _mat("orb", Color(0.7, 0.35, 1.0), 4.0)
		var light := OmniLight3D.new()
		light.light_color = Color(0.7, 0.4, 1.0)
		light.omni_range = 3.0
		light.light_energy = 1.5
		orb.add_child(light)
		node = orb
	else:
		node = Models.gear("Skeleton_Arrow")
		node.scale = Vector3.ONE * 1.4
	add_child(node)
	node.global_position = from
	node.look_at(from + dir, Vector3.UP)
	if u.kind != "mage":
		node.rotate_object_local(Vector3.RIGHT, -PI / 2)
	var spd := 9.0 if u.kind == "mage" else 15.0
	_bolts.append({"node": node, "pos": from, "dir": dir, "speed": spd,
		"damage": float(u.info["damage"]) * u.damage_mult, "life": 2.2, "magic": u.kind == "mage", "src": u})


func _update_bolts(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		var prev: Vector3 = b["pos"]
		var next: Vector3 = prev + b["dir"] * float(b["speed"]) * delta
		b["pos"] = next
		b["life"] = float(b["life"]) - delta
		var node: Node3D = b["node"]
		node.global_position = next
		var done := float(b["life"]) <= 0.0
		if not done:
			var q := PhysicsRayQueryParameters3D.create(prev, next, 1)
			if not space.intersect_ray(q).is_empty():
				done = true
				_sparks(next, Color(0.8, 0.5, 1.0) if b["magic"] else Color(0.9, 0.85, 0.7), 6)
		if not done:
			for u in squad:
				if u.dead:
					continue
				var c := u.center()
				if Vector2(c.x - next.x, c.z - next.z).length() < 0.75:
					u.take_damage(float(b["damage"]), b["dir"], b["src"] as Unit if is_instance_valid(b["src"]) else null)
					_sparks(next, Color(1, 0.3, 0.25), 8)
					if u.is_player:
						hud.hurt()
					done = true
					break
		if done:
			node.queue_free()
			_bolts.remove_at(i)


func slam(u: Unit, at: Vector3, radius: float, dmg: float) -> void:
	_ring(at, radius, Color(1.0, 0.5, 0.2))
	_dust(at, Color(0.45, 0.38, 0.3), 26)
	shake(0.5)
	Sfx.play("boom", 0.8, -3.0)
	for s in squad:
		if s.dead:
			continue
		var d := s.global_position.distance_to(at)
		if d <= radius:
			s.take_damage(dmg * (1.0 - d / radius * 0.4), s.global_position - u.global_position, u)
			s.knock += (s.global_position - at).normalized() * 9.0
			if s.is_player:
				hud.hurt()


# ---------------------------------------------------------------- Abilities

func dash() -> void:
	if dash_cd > 0.0 or player.dead or state == "over":
		return
	dash_cd = dash_max
	dash_time = 0.18
	Sfx.play("dash")
	_dust(player.global_position, Color(0.6, 0.6, 0.55), 10)


func throw_grenade() -> void:
	if grenade_cd > 0.0 or player.dead or state == "over":
		return
	grenade_cd = grenade_max
	var target := nearest_enemy(player.global_position, 11.0, false)
	var land := player.global_position + player.facing * 7.0
	if target != null:
		land = target.global_position
	land.y = 0.2
	var node := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	node.mesh = sm
	node.material_override = _mat("grenade", Color(0.25, 0.32, 0.2), 0.0)
	add_child(node)
	var from := player.global_position + Vector3(0, 1.6, 0)
	node.global_position = from
	_grenades.append({"node": node, "from": from, "to": land, "t": 0.0, "time": 0.75, "power": grenade_power})
	player.one_shot("Throw", 1.6)
	Sfx.play("dash", 0.7)


func _update_grenades(delta: float) -> void:
	for i in range(_grenades.size() - 1, -1, -1):
		var g: Dictionary = _grenades[i]
		g["t"] = float(g["t"]) + delta
		var k := clampf(float(g["t"]) / float(g["time"]), 0.0, 1.0)
		var from: Vector3 = g["from"]
		var to: Vector3 = g["to"]
		var p := from.lerp(to, k)
		p.y += sin(k * PI) * 4.0
		var node: Node3D = g["node"]
		node.global_position = p
		node.rotate_x(delta * 12.0)
		if k >= 1.0:
			node.queue_free()
			explode(to, GRENADE_RADIUS, GRENADE_DAMAGE * float(g["power"]), player)
			_grenades.remove_at(i)


func streak_ready() -> bool:
	return streak >= 1.0


func airstrike() -> void:
	if not streak_ready() or player.dead or state == "over":
		return
	streak = 0.0
	hud.announce("AIRSTRIKE INBOUND", UI.ORANGE)
	Sfx.play("wave", 1.4)
	var points: Array[Vector3] = []
	var alive: Array[Unit] = []
	for u in undead:
		if not u.dead:
			alive.append(u)
	alive.shuffle()
	for u in alive:
		if points.size() >= 7:
			break
		points.append(u.global_position)
	while points.size() < 5:
		points.append(player.global_position + Vector3(randf_range(-9, 9), 0, randf_range(-7, 7)))
	for i in points.size():
		var at := points[i]
		at.y = 0.05
		_ring(at, STRIKE_RADIUS, Color(1, 0.2, 0.15), 0.75 + i * 0.18)
		var tw := create_tween()
		tw.tween_interval(0.75 + i * 0.18)
		tw.tween_callback(_strike_hit.bind(at))


func _strike_hit(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var streak_line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 14.0, 0.25)
	streak_line.mesh = bm
	streak_line.material_override = _mat("strike", Color(1.0, 0.85, 0.5), 6.0)
	add_child(streak_line)
	streak_line.global_position = at + Vector3(2.0, 7.0, -1.0)
	streak_line.rotation.z = 0.25
	var tw := streak_line.create_tween()
	tw.tween_property(streak_line, "scale", Vector3(0.1, 1, 0.1), 0.15)
	tw.tween_callback(streak_line.queue_free)
	explode(at, STRIKE_RADIUS, STRIKE_DAMAGE, player)


func explode(at: Vector3, radius: float, dmg: float, source: Unit) -> void:
	shake(0.45)
	Sfx.play("boom")
	Sfx.vibrate(40)
	_fireball(at, radius)
	for u in undead:
		if u.dead:
			continue
		var d := u.global_position.distance_to(at)
		if d <= radius:
			var amount := dmg * (1.0 - d / radius * 0.5)
			var dir := u.global_position - at
			u.take_damage(amount, dir, source)
			u.knock += dir.normalized() * 7.0 if u.kind != "boss" else Vector3.ZERO
			damage_number(u.head_position(), amount, amount > 100.0)


# ---------------------------------------------------------------- Deaths and rewards

func on_unit_hurt(u: Unit, amount: float, _source: Unit) -> void:
	if u.team == Unit.Team.SQUAD and u.is_player:
		hud.hurt()
		Sfx.vibrate(20)
	elif u.team == Unit.Team.UNDEAD:
		Sfx.play("hurt", randf_range(0.9, 1.15), -6.0)
	if u == boss and amount > 0.0:
		hud.boss_hit()


func _on_undead_died(u: Unit) -> void:
	kills += 1
	var info := u.info
	coins += int(info["coins"])
	xp_gain += int(info["xp"])
	streak = minf(1.0, streak + streak_mult / float(GameData.STREAK_KILLS) * (8.0 if u.kind == "boss" else 1.0))
	Sfx.play("kill", randf_range(0.9, 1.1))
	_dust(u.global_position, Color(0.85, 0.82, 0.75), 14)
	hud.kill_feed(u.display_name, u.kind == "boss")
	hud.coin_pop(int(info["coins"]))
	if u == boss:
		boss = null
		hud.announce("COLOSSUS DOWN", UI.ACCENT)
		shake(0.7)
	if randf() < 0.09 or u.kind == "boss":
		_drop_medkit(u.global_position)
	var tw := u.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(u, "position:y", -1.6, 1.2)
	tw.tween_callback(func() -> void:
		undead.erase(u)
		u.queue_free())


func _on_squad_died(u: Unit) -> void:
	if u.is_player:
		state = "over"
		player.move_dir = Vector3.ZERO
		hud.player_down(not revived)
	else:
		hud.kill_feed("%s DOWN" % u.display_name, false, true)


func revive_player() -> void:
	revived = true
	player.revive(0.7)
	state = "fight"
	_ring(player.global_position, 7.0, Color(0.4, 0.9, 1.0))
	for u in undead:
		if not u.dead and u.global_position.distance_to(player.global_position) < 7.0:
			u.knock += (u.global_position - player.global_position).normalized() * 14.0
			u.take_damage(60.0, u.global_position - player.global_position, player)


## Ends the match and returns what the player earned.
func end_match() -> Dictionary:
	state = "done"
	var reached := maxi(0, wave - (0 if queue.is_empty() and alive_undead() == 0 else 1))
	var record := Save.finish_match(arena_index, reached, kills, coins, xp_gain)
	Ads.match_finished()
	return {"wave": reached, "kills": kills, "coins": coins, "xp": xp_gain, "record": record, "time": match_time}


func _drop_medkit(at: Vector3) -> void:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.45, 0.5)
	box.mesh = bm
	box.material_override = _mat("medkit", Color(0.92, 0.94, 0.95), 0.0)
	root.add_child(box)
	# A red cross on the lid.
	for size in [Vector3(0.42, 0.04, 0.12), Vector3(0.12, 0.04, 0.36)]:
		var cross := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = size
		cross.mesh = cm
		cross.material_override = _mat("cross", Color(0.9, 0.15, 0.15), 1.5)
		cross.position.y = 0.24
		root.add_child(cross)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.5)
	light.omni_range = 2.5
	light.light_energy = 1.2
	light.position.y = 0.8
	root.add_child(light)
	add_child(root)
	root.global_position = Vector3(at.x, 0.4, at.z)
	_pickups.append({"node": root, "life": 14.0})


func _update_pickups(delta: float) -> void:
	for i in range(_pickups.size() - 1, -1, -1):
		var p: Dictionary = _pickups[i]
		var node: Node3D = p["node"]
		p["life"] = float(p["life"]) - delta
		node.rotate_y(delta * 2.0)
		node.position.y = 0.45 + sin(match_time * 4.0) * 0.12
		var taken := not player.dead and node.global_position.distance_to(player.global_position + Vector3(0, 0.45, 0)) < 1.5
		if taken:
			player.heal(35.0)
			hud.announce("+35 HP", UI.GREEN, true)
			Sfx.play("coin", 0.8)
		if taken or float(p["life"]) <= 0.0:
			node.queue_free()
			_pickups.remove_at(i)


# ---------------------------------------------------------------- Camera and effects

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var look_ahead := player.facing * 1.6 + player.move_dir * 1.2
	var goal := player.global_position + look_ahead
	goal.x = clampf(goal.x, -HALF.x + 6.0, HALF.x - 6.0)
	goal.z = clampf(goal.z, -HALF.y + 2.0, HALF.y - 1.0)
	_cam_pos = _cam_pos.lerp(goal + CAM_OFFSET, clampf(5.0 * delta, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 1.6)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 1.4
	camera.global_position = _cam_pos + jitter
	camera.look_at(_cam_pos - CAM_OFFSET + Vector3(0, 0.8, 0), Vector3.UP)


func _mat(key: String, color: Color, emission: float) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = Models.material(color, emission)
	return _mats[key]


func _make_pools() -> void:
	var tm := BoxMesh.new()
	tm.size = Vector3(0.06, 0.06, 1.0)
	var tmat := Models.material(Color(1.0, 0.85, 0.45), 5.0, true)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 48:
		var t := MeshInstance3D.new()
		t.mesh = tm
		t.material_override = tmat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_tracers.append(t)
	for i in 24:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font = UI.head()
		l.font_size = 64
		l.outline_size = 14
		l.pixel_size = 0.008
		l.no_depth_test = true
		l.visible = false
		add_child(l)
		_numbers.append(l)


func _tracer(a: Vector3, b: Vector3, bright: bool) -> void:
	var t := _tracers[_tracer_next]
	_tracer_next = (_tracer_next + 1) % _tracers.size()
	var length := a.distance_to(b)
	if length < 0.2:
		return
	t.visible = true
	t.global_position = (a + b) / 2.0
	t.look_at(b, Vector3.UP)
	t.scale = Vector3(1.6 if bright else 1.0, 1.6 if bright else 1.0, length)
	t.transparency = 0.0
	var tw := t.create_tween()
	tw.tween_property(t, "transparency", 1.0, 0.09)
	tw.tween_callback(func() -> void: t.visible = false)


func damage_number(at: Vector3, amount: float, crit: bool) -> void:
	var l := _numbers[_number_next]
	_number_next = (_number_next + 1) % _numbers.size()
	l.text = str(int(round(amount)))
	l.modulate = Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	l.outline_modulate = Color(0.6, 0.1, 0.05) if crit else Color(0, 0, 0, 0.9)
	l.font_size = 84 if crit else 60
	l.visible = true
	l.global_position = at + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.2, 0.2))
	l.scale = Vector3.ONE * 0.6
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.3, 0), 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tw.chain().tween_callback(func() -> void: l.visible = false)


func _muzzle_flash(at: Vector3, big: bool) -> void:
	var s := Sprite3D.new()
	s.texture = _flash_tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.modulate = Color(1.0, 0.85, 0.4)
	s.pixel_size = 0.0035 * (1.8 if big else 1.0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.no_depth_test = false
	add_child(s)
	s.global_position = at
	s.rotation.z = randf() * TAU
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.06)
	tw.tween_callback(s.queue_free)


func _particles(at: Vector3, color: Color, amount: int, speed: float, size: float, life: float, gravity: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = Models.material(color, 1.2 if color.v > 0.8 else 0.0)
	add_child(p)
	p.global_position = at
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)
	return p


func _sparks(at: Vector3, color: Color, amount: int) -> void:
	_particles(at, color, amount, 5.0, 0.12, 0.35, 12.0)


func _dust(at: Vector3, color: Color, amount: int) -> void:
	_particles(at + Vector3(0, 0.3, 0), color, amount, 3.5, 0.6, 0.8, 2.0)


func _fireball(at: Vector3, radius: float) -> void:
	_particles(at + Vector3(0, 0.5, 0), Color(1.0, 0.62, 0.15), 26, radius * 2.2, 1.4, 0.55, 3.0)
	_particles(at + Vector3(0, 0.5, 0), Color(0.42, 0.4, 0.38, 0.55), 14, radius * 1.1, 1.3, 1.0, -1.5)
	_particles(at, Color(1.0, 0.9, 0.6), 14, radius * 3.5, 0.18, 0.5, 14.0)
	_ring(at, radius, Color(1.0, 0.6, 0.2))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = radius * 2.6
	light.light_energy = 6.0
	add_child(light)
	light.global_position = at + Vector3(0, 1.5, 0)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.45)
	tw.tween_callback(light.queue_free)


## A flat ring on the ground: a warning when [param hold] > 0, or a shockwave.
func _ring(at: Vector3, radius: float, color: Color, hold: float = 0.0) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	var m := Models.material(Color(color, 0.85), 3.0, true)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(at.x, 0.08, at.z)
	ring.scale = Vector3(1, 0.05, 1) * (radius if hold > 0.0 else 0.3)
	var tw := ring.create_tween()
	if hold > 0.0:
		ring.scale = Vector3(radius, 0.05, radius)
		tw.tween_property(ring, "scale", Vector3(radius * 0.25, 0.05, radius * 0.25), hold)
	else:
		tw.set_parallel()
		tw.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
		tw.chain()
	tw.tween_callback(ring.queue_free)
