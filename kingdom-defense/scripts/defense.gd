class_name Defense
extends Node3D
## One level: the road from the enemy gate to your castle, the towers you build
## beside it, your knight hero, and wave after wave of skeletons.

signal exit_requested(next: bool)

var level_n := 1
var autopilot := false
var rig: CameraRig
var hud: DefenseHud
var road: Array[Vector2i] = []
var road_points: Array[Vector3] = []
var road_set := {}
var towers := {}
var enemies: Array[Walker] = []
var hero: Walker
var castle_spot := Vector3.ZERO
var gold := GameData.START_GOLD
var lives := GameData.LIVES
var wave := 0
var waves := 10
var state := "build"
var speed := 1.0
var _queue: Array[String] = []
var _spawn_t := 0.0
var _next_wave_t := 0.0
var _projectiles: Array[Dictionary] = []
var _castle: Node3D
var _auto_t := 0.0


func _ready() -> void:
	waves = GameData.wave_count(level_n)
	road = GameData.path(level_n)
	for c in road:
		road_set[c] = true
	Island.build(self, 300 + level_n * 11, GameData.THEMES[level_n - 1], road_set)
	# Enemies come in from just outside the island edge.
	var first := Hex.to_world(road[0])
	var outward := first.normalized() * 3.0
	road_points.append(first + outward)
	for c in road:
		road_points.append(Hex.to_world(c))
	castle_spot = road_points[-1]
	_castle = Models.building("castle", "blue")
	add_child(_castle)
	_castle.position = castle_spot
	_castle.scale = Vector3.ONE * 1.1
	var gate := Models.prop(Models.hex("building_tower_B_red"))
	add_child(gate)
	gate.position = first + outward * 0.4 + first.normalized().cross(Vector3.UP) * 1.4
	var flag := Models.prop(Models.hex("flag_red"))
	add_child(flag)
	flag.position = first + outward * 0.4 - first.normalized().cross(Vector3.UP) * 1.4
	hero = Walker.new()
	hero.defense = self
	hero.setup_hero(castle_spot + (road_points[-2] - castle_spot) * 0.6)
	add_child(hero)
	rig = CameraRig.new()
	add_child(rig)
	rig.focus = Vector3(0, 0, 1.0)
	rig.distance = 19.0
	rig.tapped.connect(_on_tap)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DefenseHud.new()
	hud.defense = self
	layer.add_child(hud)
	_next_wave_t = 12.0
	Ads.hide_banner()


func _process(delta: float) -> void:
	var dt := delta * speed
	if state == "build" or state == "wave":
		if state == "build" or _queue.is_empty():
			_next_wave_t -= dt
			if _next_wave_t <= 0.0 and wave < waves:
				start_wave()
		if _queue.size() > 0:
			_spawn_t -= dt
			if _spawn_t <= 0.0:
				_spawn_t = 0.9 if _queue[0] != "boss" else 2.0
				_spawn(_queue.pop_front())
		if state == "wave" and _queue.is_empty() and _alive() == 0:
			if wave >= waves:
				_win()
			else:
				state = "build"
				_next_wave_t = 8.0
				hud.toast("Wave %d cleared!" % wave)
	for e in enemies.duplicate():
		(e as Walker).step(dt)
	hero.step(dt)
	for t in towers.values():
		(t as Tower).step(dt)
	_update_projectiles(dt)
	if autopilot:
		_autopilot(delta)


func _alive() -> int:
	var n := 0
	for e in enemies:
		if not e.dead:
			n += 1
	return n


## Calls the next wave; calling it early pays a bonus.
func start_wave() -> void:
	if wave >= waves or state == "done":
		return
	var bonus := int(_next_wave_t * 2.0) if state == "build" and wave > 0 else 0
	if bonus > 0:
		gold += bonus
		hud.toast("+%d gold for calling early" % bonus)
	wave += 1
	_queue.append_array(GameData.wave(level_n, wave))
	_spawn_t = 0.3
	state = "wave"
	_next_wave_t = 22.0
	Sfx.play("horn")
	hud.banner("WAVE %d" % wave, "BOSS INCOMING!" if _queue.has("boss") else "%d enemies" % _queue.size())


func _spawn(kind: String) -> void:
	var e := Walker.new()
	e.defense = self
	e.setup_enemy(kind, GameData.health_scale(level_n, wave), road_points)
	add_child(e)
	enemies.append(e)


func _on_tap(_screen: Vector2, ground: Vector3) -> void:
	if state == "done":
		return
	var cell := Hex.from_world(ground)
	if towers.has(cell):
		hud.show_tower_menu(towers[cell])
		return
	if Hex.buildable(cell) and not road_set.has(cell):
		hud.show_build_menu(cell)
		return
	hud.close_menu()
	# Anywhere else: send the hero there.
	if not hero.dead and Hex.distance(cell, Vector2i.ZERO) <= Hex.LAND_RADIUS:
		hero.goal = Vector3(ground.x, 0, ground.z)
		_marker(hero.goal)


func can_build(cell: Vector2i, kind: String) -> bool:
	return not towers.has(cell) and not road_set.has(cell) and Hex.buildable(cell) and gold >= int(GameData.at(GameData.tower(kind)["cost"], 1))


func build(cell: Vector2i, kind: String) -> bool:
	if not can_build(cell, kind):
		Sfx.play("deny")
		return false
	gold -= int(GameData.at(GameData.tower(kind)["cost"], 1))
	var t := Tower.new()
	t.defense = self
	t.setup(kind, cell)
	add_child(t)
	towers[cell] = t
	Sfx.play("build")
	_puff(t.global_position, Color(0.85, 0.78, 0.62), 16)
	return true


func upgrade(t: Tower) -> bool:
	if t.level >= 3:
		return false
	var cost := int(GameData.at(t.info()["cost"], t.level + 1))
	if gold < cost:
		Sfx.play("deny")
		return false
	gold -= cost
	t.upgrade()
	Sfx.play("upgrade")
	_sparkle(t.global_position)
	return true


func sell(t: Tower) -> void:
	gold += GameData.sell_value(t.kind, t.level)
	towers.erase(t.cell)
	_puff(t.global_position, Color(0.7, 0.62, 0.5), 14)
	t.queue_free()
	Sfx.play("remove")


# ---------------------------------------------------------------- Queries

## The enemy furthest along the road within range of [param from].
func first_enemy(from: Vector3, reach: float, min_reach: float) -> Walker:
	var best: Walker = null
	for e in enemies:
		if e.dead:
			continue
		var d := Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d <= reach and d >= min_reach and (best == null or e.distance > best.distance):
			best = e
	return best


func enemy_near(from: Vector3, reach: float) -> Walker:
	var best: Walker = null
	var best_d := reach
	for e in enemies:
		if e.dead:
			continue
		var d := e.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


# ---------------------------------------------------------------- Combat

func tower_fire(t: Tower, target: Walker) -> void:
	var d := t.info()
	var dmg := float(GameData.at(d["damage"], t.level))
	var from := t.top()
	match t.kind:
		"catapult":
			var land := target.global_position + target.global_transform.basis.z * -0.4
			var rock := Models.prop(Models.hex("projectile_catapult"))
			rock.scale = Vector3.ONE * 1.4
			add_child(rock)
			var splash := float(d["splash"])
			Sfx.play("thud", 0.7, -6.0)
			_launch(rock, from, land, 1.0, 3.2, func() -> void:
				_burst(land, Color(0.6, 0.5, 0.4), splash)
				Sfx.play("boom", 1.0, -8.0)
				rig.shake(0.18)
				for e in enemies:
					if not e.dead and e.global_position.distance_to(land) <= splash:
						hit_enemy(e, dmg, false, 0.0))
		"mage":
			var orb := _orb(Color(0.7, 0.4, 1.0), 0.15)
			add_child(orb)
			var slow := float(d["slow"])
			Sfx.play("bow", 1.6, -8.0)
			_launch(orb, from, target.center(), 0.35, 0.3, func() -> void:
				if is_instance_valid(target) and not target.dead:
					hit_enemy(target, dmg, true, slow))
		_:
			var arrow := Models.prop(Models.hex("Skeleton_Arrow"))
			arrow.scale = Vector3.ONE * 0.5
			add_child(arrow)
			Sfx.play("bow", 1.0, -8.0)
			_launch(arrow, from, target.center(), 0.3, 0.4, func() -> void:
				if is_instance_valid(target) and not target.dead:
					hit_enemy(target, dmg, false, 0.0))


func hit_enemy(e: Walker, dmg: float, magic: bool, slow: float) -> void:
	if slow > 0.0:
		e.slow_time = 1.6
		e.slow_amount = slow
	e.hurt(dmg, magic)


func mine_income(t: Tower, amount: int) -> void:
	if state != "wave" and wave == 0:
		return
	gold += amount
	hud.float_text(rig.camera.unproject_position(t.top()), "+%d" % amount, UI.GOLD)


func enemy_killed(e: Walker) -> void:
	gold += int(e.info["gold"])
	Sfx.play("die", randf_range(0.9, 1.2), -6.0)
	hud.float_text(rig.camera.unproject_position(e.head()), "+%d" % int(e.info["gold"]), UI.GOLD)
	var tw := e.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(e, "position:y", -0.6, 0.8)
	tw.tween_callback(func() -> void:
		enemies.erase(e)
		e.queue_free())


func enemy_escaped(e: Walker) -> void:
	e.dead = true
	enemies.erase(e)
	e.queue_free()
	lives -= 2 if e.kind == "boss" else 1
	rig.shake(0.35)
	Sfx.play("break")
	_castle.create_tween().tween_property(_castle, "scale", Vector3.ONE * 1.0, 0.08)
	_castle.create_tween().tween_property(_castle, "scale", Vector3.ONE * 1.1, 0.2).set_delay(0.08)
	hud.hurt()
	if lives <= 0:
		lives = 0
		_lose()


func hero_died() -> void:
	hud.toast("Your knight fell! Back in %d s" % int(GameData.HERO["respawn"]))


func _win() -> void:
	state = "done"
	hero.cheer()
	var stars := GameData.stars(lives)
	Save.finish_level(level_n, stars)
	Ads.match_finished()
	Sfx.play("levelup")
	hud.show_end(true, stars)


func _lose() -> void:
	state = "done"
	Ads.match_finished()
	Sfx.play("deny")
	hud.show_end(false, 0)


func continue_with_ad() -> void:
	lives = 5
	state = "wave" if _alive() > 0 or _queue.size() > 0 else "build"
	for e in enemies:
		if not e.dead:
			e.hurt(e.max_hp * 0.5, true)


## For the screenshot run: build towers along the road and call waves.
func _autopilot(delta: float) -> void:
	_auto_t -= delta
	if _auto_t > 0.0:
		return
	_auto_t = 0.4
	var kinds := ["archer", "archer", "catapult", "mage", "mine", "archer", "mage", "catapult"]
	var want: String = kinds[towers.size() % kinds.size()]
	if gold >= int(GameData.at(GameData.tower(want)["cost"], 1)):
		for i in range(2, road.size() - 1, 2):
			for d in Hex.DIRS:
				var cell: Vector2i = road[i] + d
				if can_build(cell, want):
					build(cell, want)
					return
	for t in towers.values():
		var tw: Tower = t
		if tw.level < 3 and gold > 260:
			upgrade(tw)
			return
	if state == "build" and wave < waves:
		start_wave()


# ---------------------------------------------------------------- Projectiles and effects

func _launch(node: Node3D, from: Vector3, to: Vector3, time: float, arc: float, on_hit: Callable) -> void:
	node.global_position = from
	_projectiles.append({"node": node, "from": from, "to": to, "t": 0.0, "time": time, "arc": arc, "hit": on_hit})


func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		p["t"] = float(p["t"]) + delta
		var k := clampf(float(p["t"]) / float(p["time"]), 0.0, 1.0)
		var from: Vector3 = p["from"]
		var to: Vector3 = p["to"]
		var pos := from.lerp(to, k)
		pos.y += sin(k * PI) * float(p["arc"])
		var node: Node3D = p["node"]
		var prev := node.global_position
		node.global_position = pos
		if pos.distance_to(prev) > 0.001:
			node.look_at(pos + (pos - prev), Vector3.UP)
			node.rotate_object_local(Vector3.RIGHT, -PI / 2)
		if k >= 1.0:
			node.queue_free()
			_projectiles.remove_at(i)
			(p["hit"] as Callable).call()


func _orb(color: Color, radius: float) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	m.mesh = s
	m.material_override = Models.material(color, 4.0, true)
	return m


func _marker(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.42
	ring.mesh = tm
	ring.material_override = Models.material(Color(1, 0.9, 0.3, 0.9), 2.0, true)
	ring.scale = Vector3(1, 0.2, 1)
	add_child(ring)
	ring.position = at + Vector3(0, 0.05, 0)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(2, 0.2, 2), 0.4)
	tw.tween_callback(ring.queue_free)
	Sfx.play("click")


func _puff(at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
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
	p.material_override = Models.material(color)
	add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(p.queue_free)


func _sparkle(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 24
	p.lifetime = 1.0
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	p.mesh = mesh
	p.material_override = Models.material(Color(1.0, 0.9, 0.35), 3.0, true)
	add_child(p)
	p.global_position = at + Vector3(0, 1.2, 0)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(p.queue_free)


func _burst(at: Vector3, color: Color, radius: float) -> void:
	_puff(at, color, 12)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	ring.mesh = tm
	var m := Models.material(Color(color, 0.8), 2.0, true)
	ring.material_override = m
	add_child(ring)
	ring.global_position = Vector3(at.x, 0.06, at.z)
	ring.scale = Vector3(0.2, 0.05, 0.2)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)
