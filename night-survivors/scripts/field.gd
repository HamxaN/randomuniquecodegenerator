class_name Field
extends Node3D
## One night in the graveyard. The hero walks with the thumbstick while every
## weapon fires by itself; the horde (animated skeletons plus a cheap swarm of
## glowing wisps drawn in one MultiMesh) closes in from all sides. Gems level
## you up, bosses come at 3, 6 and 9 minutes, and dawn breaks at 10.

signal finished(result: Dictionary)

const ARENA := 58.0
const MAX_SKELETONS := 42
const MAX_WISPS := 260
const MAX_GEMS := 400
const HEROES_KEEP := {"Knight": ["1H_Sword", "Round_Shield"], "Mage": ["2H_Staff"], "Rogue_Hooded": ["Knife", "Knife_Offhand"],
	"Barbarian": ["2H_Axe"]}

var run: RunState
var map: Dictionary
var autopilot := false
var hud: FieldHud
var camera: Camera3D
var hero: Node3D
var hero_ap: AnimationPlayer
var hp := 100.0
var clock := 0.0
var state := "play"     # play, levelup, dead, dawn
var input_move := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var boss: Dictionary = {}
var revived := false
var pending_levels := 0
## The play-test keeps the hero alive.
var god := false

var enemies: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var _cool := {}
var _axes: Array[Node3D] = []
var _axe_angle := 0.0
var _aura: MeshInstance3D
var _wisp_mm: MultiMesh
var _gem_mm: MultiMesh
var _hurt_t := 0.0
var _spawn_t := 0.0
var _swarm_t := 55.0
var _boss_index := 0
var _anim := ""
var _rng := RandomNumberGenerator.new()
var _skeleton_count := 0
var _shake := 0.0
var _popups := 0
var _next_id := 0


func _ready() -> void:
	_rng.randomize()
	run = RunState.new(Save.hero, Save.meta)
	map = GameData.MAPS[0]
	for m in GameData.MAPS:
		if m["id"] == Save.map:
			map = m
	hp = run.max_hp()
	_environment()
	_ground()
	_props()
	_hero()
	_multimeshes()
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 120.0
	add_child(camera)
	camera.current = true
	_update_camera(1.0)
	hud = FieldHud.new()
	hud.field = self
	add_child(hud)


# ---------------------------------------------------------------- world

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = (map["fog"] as Color).darkened(0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = map["fog"]
	env.fog_density = 0.022
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = map["moon"]
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)


func _ground() -> void:
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	var base: Color = map["ground"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 64:
		for x in 64:
			var n := sin(x * 0.31) * cos(y * 0.27) * 0.06 + rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, base.lightened(maxf(n, 0.0)).darkened(maxf(-n, 0.0)))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(40, 40, 1)
	mat.roughness = 1.0
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA * 2.6, ARENA * 2.6)
	plane.mesh = pm
	plane.material_override = mat
	add_child(plane)
	# Dirt patches and paths.
	for i in 40:
		var d := Models.yard("floor_dirt" if i % 3 else "floor_dirt_grave")
		add_child(d)
		d.position = Vector3(rng.randf_range(-ARENA, ARENA), 0.01, rng.randf_range(-ARENA, ARENA))
		d.rotation.y = rng.randf() * TAU
		d.scale = Vector3.ONE * rng.randf_range(1.5, 3.0)


func _props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map["id"])
	var graves := ["gravestone", "grave_A", "grave_B", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
	var bits := ["pumpkin_orange", "pumpkin_orange_jackolantern", "pumpkin_yellow", "bone_A", "skull", "ribcage", "coffin",
		"candle_triple", "skull_candle"]
	var trees: Array = map["trees"]
	var lights := 0
	for i in 170:
		var p := Vector3(rng.randf_range(-ARENA, ARENA), 0, rng.randf_range(-ARENA, ARENA))
		if p.length() < 7.0:
			continue
		var roll := rng.randf()
		var piece: String
		if roll < 0.42:
			piece = graves[rng.randi() % graves.size()]
		elif roll < 0.62:
			piece = trees[rng.randi() % trees.size()]
		elif roll < 0.9:
			piece = bits[rng.randi() % bits.size()]
		else:
			piece = ["crypt", "shrine_candles", "lantern_standing", "post_lantern", "arch_gate", "bench_decorated"][rng.randi() % 6]
		if map["id"] == "patch" and roll >= 0.62 and roll < 0.9:
			piece = ["pumpkin_orange", "pumpkin_orange_jackolantern", "pumpkin_yellow_jackolantern", "pumpkin_yellow"][rng.randi() % 4]
		var n := Models.yard(piece)
		add_child(n)
		n.position = p
		n.rotation.y = rng.randf() * TAU
		var sc := 1.4
		if piece.begins_with("tree"):
			sc = rng.randf_range(2.0, 3.2)
		elif piece == "crypt":
			sc = 1.6
		n.scale = Vector3.ONE * sc
		if lights < 10 and (piece.contains("lantern") or piece.contains("candle") or piece.contains("jackolantern")):
			lights += 1
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.25)
			l.light_energy = 1.2
			l.omni_range = 5.0
			l.position = p + Vector3(0, 1.2, 0)
			add_child(l)
	# A broken fence ring marks the edge of the night.
	for i in 72:
		var a := TAU * i / 72.0
		var f := Models.yard("fence_broken" if i % 5 == 0 else ("fence_pillar" if i % 2 == 0 else "fence"))
		add_child(f)
		f.position = Vector3(cos(a), 0, sin(a)) * (ARENA + 1.5)
		f.rotation.y = -a + PI / 2
		f.scale = Vector3.ONE * 1.6


func _hero() -> void:
	hero = Node3D.new()
	add_child(hero)
	var model_name: String = run.hero["model"]
	var model := Models.character(model_name, HEROES_KEEP.get(model_name, []))
	hero.add_child(model)
	hero_ap = Models.animation_player(model)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 2.0
	lamp.omni_range = 11.0
	lamp.position = Vector3(0, 2.6, 0)
	hero.add_child(lamp)
	_aura = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	disc.radial_segments = 40
	_aura.mesh = disc
	_aura.material_override = Models.material(Color(1.0, 0.85, 0.4, 0.22), 1.5, true)
	_aura.position.y = 0.05
	_aura.visible = false
	hero.add_child(_aura)
	_play("Idle")


func _multimeshes() -> void:
	var wisp := SphereMesh.new()
	wisp.radius = 0.35
	wisp.height = 0.7
	wisp.radial_segments = 8
	wisp.rings = 4
	wisp.material = Models.material(Color(0.45, 0.95, 0.75), 2.2)
	_wisp_mm = MultiMesh.new()
	_wisp_mm.transform_format = MultiMesh.TRANSFORM_3D
	_wisp_mm.mesh = wisp
	_wisp_mm.instance_count = MAX_WISPS
	_wisp_mm.visible_instance_count = 0
	var wmi := MultiMeshInstance3D.new()
	wmi.multimesh = _wisp_mm
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)
	var gem := CylinderMesh.new()
	gem.top_radius = 0.0
	gem.bottom_radius = 0.18
	gem.height = 0.42
	gem.radial_segments = 4
	gem.material = Models.material(Color(0.35, 0.8, 1.0), 2.5)
	_gem_mm = MultiMesh.new()
	_gem_mm.transform_format = MultiMesh.TRANSFORM_3D
	_gem_mm.mesh = gem
	_gem_mm.instance_count = MAX_GEMS
	_gem_mm.visible_instance_count = 0
	var gmi := MultiMeshInstance3D.new()
	gmi.multimesh = _gem_mm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)


func _play(anim: String, spd: float = 1.0) -> void:
	if hero_ap == null or _anim == anim or not hero_ap.has_animation(anim):
		return
	_anim = anim
	hero_ap.play(anim, 0.15)
	hero_ap.speed_scale = spd


# ---------------------------------------------------------------- the loop

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if state != "play":
		_update_camera(delta)
		_draw_swarm()
		return
	clock += delta
	_move_hero(delta)
	_director(delta)
	_move_enemies(delta)
	_weapons(delta)
	_move_shots(delta)
	_pickups(delta)
	_draw_swarm()
	_update_camera(delta)
	hp = minf(run.max_hp(), hp + run.regen() * delta)
	_hurt_t = maxf(0.0, _hurt_t - delta)
	if clock >= GameData.NIGHT_LENGTH:
		_dawn()


func _move_hero(delta: float) -> void:
	var move := input_move
	if autopilot:
		move = _auto_move()
	if move.length() > 1.0:
		move = move.normalized()
	if move.length() > 0.05:
		facing = move.normalized()
		hero.position += move * run.speed() * delta
		var flat := Vector2(hero.position.x, hero.position.z)
		if flat.length() > ARENA:
			flat = flat.normalized() * ARENA
			hero.position = Vector3(flat.x, 0, flat.y)
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(facing.x, facing.z), clampf(delta * 14.0, 0, 1))
		_play("Running_A", clampf(run.speed() / 5.0, 0.8, 1.4))
	else:
		_play("Idle")


## The CI play-test's pilot: drift away from the crowd, circling, towards gems.
func _auto_move() -> Vector3:
	var push := Vector3.ZERO
	for e in enemies:
		var d: Vector3 = hero.position - (e["pos"] as Vector3)
		d.y = 0.0
		var l := d.length()
		if l < 7.0 and l > 0.01:
			push += d / l * (7.0 - l)
	var orbit := Vector3(-hero.position.z, 0, hero.position.x).normalized() * 0.6 if hero.position.length() > 1.0 else Vector3.RIGHT
	var home := -hero.position * 0.02
	var gem_pull := Vector3.ZERO
	var best := 9.0
	for g in gems:
		var d := (g["pos"] as Vector3).distance_to(hero.position)
		if d < best:
			best = d
			gem_pull = ((g["pos"] as Vector3) - hero.position).normalized() * 0.5
	return (push * 0.5 + orbit + home + gem_pull).normalized()


func _update_camera(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.5)
	var target := hero.position + Vector3(0, 15.5, 10.5)
	camera.position = camera.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0)) if camera.position.length() > 0.1 else target
	camera.look_at(hero.position + Vector3(0, 0.5, 0.5), Vector3.UP)
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake * 0.4


# ---------------------------------------------------------------- the horde

func _director(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.2
		var want := GameData.horde_size(clock)
		var n := 0
		while enemies.size() < want and n < 6:
			n += 1
			var kind := GameData.pick_weighted(GameData.spawn_table(clock), _rng.randf())
			spawn(kind, _ring_point(17.0, 22.0))
	_swarm_t -= delta
	if _swarm_t <= 0.0:
		_swarm_t = 60.0
		swarm(28 + int(clock / 30.0))
	if _boss_index < GameData.BOSS_TIMES.size() and clock >= float(GameData.BOSS_TIMES[_boss_index]):
		_boss_index += 1
		spawn_boss()


func _ring_point(r0: float, r1: float) -> Vector3:
	var a := _rng.randf() * TAU
	var p := hero.position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r0, r1)
	var flat := Vector2(p.x, p.z)
	if flat.length() > ARENA:
		flat = flat.normalized() * ARENA
	return Vector3(flat.x, 0, flat.y)


## A ring of wisps closing in from every side.
func swarm(count: int) -> void:
	hud.banner("A swarm closes in!", Color("8ff2c8"))
	for i in count:
		var a := TAU * i / count
		spawn("wisp", hero.position + Vector3(cos(a), 0, sin(a)) * 16.0)


func spawn(kind: String, at: Vector3) -> Dictionary:
	var info: Dictionary = GameData.ENEMIES[kind]
	if kind != "wisp" and kind != "boss" and _skeleton_count >= MAX_SKELETONS:
		kind = "wisp"
		info = GameData.ENEMIES["wisp"]
	if kind == "wisp" and enemies.size() - _skeleton_count >= MAX_WISPS:
		return {}
	var mhp := float(info["hp"]) * GameData.hp_scale(clock)
	_next_id += 1
	var e := {"id": _next_id, "kind": kind, "pos": at, "hp": mhp, "max": mhp, "speed": float(info["speed"]) * _rng.randf_range(0.9, 1.1),
		"damage": float(info["damage"]), "xp": int(info["xp"]), "node": null, "ap": null, "hit_t": 0.0, "flash": 0.0,
		"knock": Vector3.ZERO}
	if kind != "wisp":
		var model := Models.character(info["model"])
		model.scale = Vector3.ONE * float(info["scale"])
		add_child(model)
		model.position = at
		var ap := Models.animation_player(model)
		if ap != null:
			var walk := "Walking_D_Skeletons" if ap.has_animation("Walking_D_Skeletons") else "Walking_A"
			if kind == "rogue" and ap.has_animation("Running_A"):
				walk = "Running_A"
			ap.play(walk)
			ap.speed_scale = randf_range(0.9, 1.1)
		e["node"] = model
		e["ap"] = ap
		_skeleton_count += 1
	enemies.append(e)
	return e


func spawn_boss() -> void:
	var e := spawn("boss", _ring_point(14.0, 16.0))
	e["hp"] = float(e["hp"]) * (1.0 + _boss_index * 0.6)
	e["max"] = e["hp"]
	boss = e
	hud.banner("The Bone Colossus rises!", Color("ff6b5a"))
	Sfx.play("boom")
	_shake = 1.0


func _move_enemies(delta: float) -> void:
	var hp0 := hero.position
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		var p: Vector3 = e["pos"]
		var to := hp0 - p
		to.y = 0.0
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		var vel := dir * float(e["speed"])
		# Skeletons shuffle apart so they don't stack into one blob.
		if e["node"] != null and i % 2 == int(clock * 10.0) % 2:
			for j in range(maxi(0, i - 8), mini(enemies.size(), i + 8)):
				if j == i:
					continue
				var o: Vector3 = enemies[j]["pos"]
				var d := p - o
				var l := d.length()
				if l < 1.0 and l > 0.001:
					vel += d / l * (1.0 - l) * 6.0
		var knock: Vector3 = e["knock"]
		p += (vel + knock) * delta
		e["knock"] = knock.lerp(Vector3.ZERO, clampf(delta * 8.0, 0, 1))
		e["pos"] = p
		e["hit_t"] = maxf(0.0, float(e["hit_t"]) - delta)
		var reach := 0.9 if e["kind"] != "boss" else 2.2
		if dist < reach and _hurt_t <= 0.0:
			_take_damage(float(e["damage"]))
		var node: Node3D = e["node"]
		if node != null:
			node.position = p
			node.rotation.y = atan2(dir.x, dir.z)
			if float(e["flash"]) > 0.0:
				e["flash"] = float(e["flash"]) - delta
				node.scale = node.scale.lerp(Vector3.ONE * float(GameData.ENEMIES[e["kind"]]["scale"]), 0.3)


func _draw_swarm() -> void:
	var n := 0
	var bob := clock * 4.0
	for e in enemies:
		if e["node"] == null and n < MAX_WISPS:
			var p: Vector3 = e["pos"]
			var s := 1.3 if float(e["flash"]) > 0.0 else 1.0
			_wisp_mm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 1.2, s)), p + Vector3(0, 0.8 + sin(bob + p.x) * 0.2, 0)))
			n += 1
			if float(e["flash"]) > 0.0:
				e["flash"] = float(e["flash"]) - get_process_delta_time()
	_wisp_mm.visible_instance_count = n
	var g := 0
	for gm in gems:
		if g >= MAX_GEMS:
			break
		var p: Vector3 = gm["pos"]
		var big := 1.0 + minf(int(gm["xp"]) / 10.0, 1.5)
		_gem_mm.set_instance_transform(g, Transform3D(Basis(Vector3.UP, clock * 2.0 + p.x).scaled(Vector3.ONE * big), p + Vector3(0, 0.35, 0)))
		g += 1
	_gem_mm.visible_instance_count = g


func hurt(e: Dictionary, dmg: float, from: Vector3 = Vector3.ZERO) -> void:
	if float(e["hp"]) <= 0.0:
		return
	var amount := dmg * run.might() * _rng.randf_range(0.9, 1.1)
	e["hp"] = float(e["hp"]) - amount
	e["flash"] = 0.12
	if from != Vector3.ZERO and e["kind"] != "boss":
		var k: Vector3 = (e["pos"] as Vector3) - from
		k.y = 0.0
		e["knock"] = k.normalized() * 6.0
	var node: Node3D = e["node"]
	if node != null:
		node.scale = Vector3.ONE * float(GameData.ENEMIES[e["kind"]]["scale"]) * 1.15
		if _popups < 14:
			_popup(node.position + Vector3(0, 2.2 if e["kind"] != "boss" else 5.0, 0), str(int(amount)), Color("ffe08a"))
	if float(e["hp"]) <= 0.0:
		_kill(e)


func _kill(e: Dictionary) -> void:
	var idx := enemies.find(e)
	if idx < 0:
		return
	enemies.remove_at(idx)
	run.kills += 1
	var p: Vector3 = e["pos"]
	var node: Node3D = e["node"]
	if node != null:
		_skeleton_count -= 1
		_puff(p + Vector3(0, 1.0, 0), Color(0.9, 0.9, 0.85), 10)
		node.queue_free()
		Sfx.play("kill", randf_range(0.9, 1.1), -6.0)
	else:
		_puff(p + Vector3(0, 0.8, 0), Color(0.45, 0.95, 0.75), 5)
	if gems.size() < MAX_GEMS:
		gems.append({"pos": p, "xp": int(e["xp"])})
	else:
		gems[_rng.randi() % gems.size()]["xp"] = int(gems[0]["xp"]) + int(e["xp"])
	var roll := _rng.randf()
	if e["kind"] == "boss":
		boss = {}
		_drop("chest", p)
		_shake = 1.2
		Sfx.play("boom")
		hud.banner("Colossus destroyed!", Color("ffd23a"))
	elif (e["kind"] == "warrior" or e["kind"] == "mage") and roll < 0.05:
		_drop("chest", p)
	elif roll < 0.035:
		_drop("coin", p)
	elif roll < 0.042:
		_drop("food", p)


func _drop(kind: String, at: Vector3) -> void:
	var node: Node3D
	match kind:
		"chest":
			node = Models.yard("coffin_decorated")
			node.scale = Vector3.ONE * 1.2
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.8, 0.3)
			glow.light_energy = 2.0
			glow.omni_range = 4.0
			glow.position.y = 1.0
			node.add_child(glow)
		"coin":
			node = Models.cylinder(0.3, 0.08, Color(1.0, 0.8, 0.2))
			node.material_override = Models.material(Color(1.0, 0.8, 0.2), 1.5)
			node.rotation.x = PI / 2
		_:
			node = Models.yard("pumpkin_orange")
			node.scale = Vector3.ONE * 0.7
	add_child(node)
	node.position = at + Vector3(0, 0.3, 0)
	pickups.append({"kind": kind, "node": node, "pos": at})


func _take_damage(amount: float) -> void:
	if god:
		return
	var dmg := maxf(1.0, amount - run.armor())
	hp -= dmg
	_hurt_t = 0.45
	hud.hurt_flash()
	Sfx.play("hurt", 1.0, -4.0)
	Sfx.vibrate(30)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if Save.meta_level("revival") > 0 and not revived:
		revive()
		hud.banner("Second Wind!", Color("8ff2a2"))
		return
	state = "dead"
	_play("Death_A")
	Sfx.play("boom", 0.7)
	get_tree().create_timer(1.4).timeout.connect(func() -> void: hud.show_results(_result(false)))


## Back on your feet with full health, pushing the horde away.
func revive() -> void:
	revived = true
	hp = run.max_hp()
	state = "play"
	_anim = ""
	_play("Idle")
	for e in enemies.duplicate():
		var d := (e["pos"] as Vector3).distance_to(hero.position)
		if d < 8.0:
			hurt(e, 9999.0, hero.position)
	_ring_flash(hero.position, 8.0, Color(1, 1, 1))


func _dawn() -> void:
	state = "dawn"
	for e in enemies.duplicate():
		_kill(e)
	hud.banner("Dawn breaks! You survived the night!", Color("ffd9a8"))
	Sfx.play("levelup")
	var tw := create_tween()
	var we: WorldEnvironment = find_children("*", "WorldEnvironment", false, false)[0]
	tw.tween_property(we.environment, "background_color", Color(0.95, 0.65, 0.45), 2.0)
	tw.parallel().tween_property(we.environment, "fog_light_color", Color(1.0, 0.75, 0.55), 2.0)
	tw.parallel().tween_property(we.environment, "ambient_light_energy", 1.0, 2.0)
	tw.tween_callback(func() -> void: hud.show_results(_result(true)))


func _result(survived: bool) -> Dictionary:
	var earned := GameData.gold_reward(clock, run.kills, Save.meta_level("greed")) + run.gold
	return {"survived": survived, "time": clock, "kills": run.kills, "level": run.level, "gold": earned}


# ---------------------------------------------------------------- weapons

func _weapons(delta: float) -> void:
	for id in run.weapons:
		var lv := int(run.weapons[id])
		var st := GameData.weapon_stats(id, lv)
		var t := float(_cool.get(id, 0.0)) - delta
		var period := float(st["cooldown"]) * run.cooldown_mult()
		match id:
			"axes":
				_spin_axes(st, delta)
			"aura":
				_aura.visible = true
				var r := float(st["area"]) * run.area()
				_aura.scale = Vector3(r, 1, r)
				if t <= 0.0:
					for e in enemies.duplicate():
						if (e["pos"] as Vector3).distance_to(hero.position) < r:
							hurt(e, float(st["damage"]))
		if t <= 0.0:
			t = period
			if id != "axes" and id != "aura":
				_fire(id, st)
		_cool[id] = t


func _nearest(from: Vector3, skip: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var bd := 18.0
	for e in enemies:
		if skip.has(e):
			continue
		var d := (e["pos"] as Vector3).distance_to(from)
		if d < bd:
			bd = d
			best = e
	return best


func _fire(id: String, st: Dictionary) -> void:
	var count := int(st["count"])
	var color: Color = GameData.WEAPONS[id]["color"]
	match id:
		"bolt":
			var used: Array = []
			for i in count:
				var target := _nearest(hero.position, used)
				if target.is_empty():
					break
				used.append(target)
				var orb := Models.sphere(0.22 * run.area(), color, 3.0)
				add_child(orb)
				var from := hero.position + Vector3(0, 1.3, 0)
				orb.position = from
				shots.append({"kind": "bolt", "node": orb, "pos": from, "vel": ((target["pos"] as Vector3) + Vector3(0, 0.8, 0) - from).normalized() * float(st["speed"]),
					"target": target, "damage": float(st["damage"]), "radius": 0.7 * run.area(), "pierce": 1, "life": 2.0})
			if not used.is_empty():
				Sfx.play("bolt", 1.2, -10.0)
		"daggers":
			for i in count:
				var spread := (i - (count - 1) / 2.0) * 0.14
				var dir := facing.rotated(Vector3.UP, spread)
				var knife := Models.box(Vector3(0.08, 0.06, 0.7), color)
				knife.material_override = Models.material(color, 1.2)
				add_child(knife)
				var from := hero.position + Vector3(0, 1.0, 0) + dir * 0.6
				knife.position = from
				knife.look_at(from + dir, Vector3.UP)
				shots.append({"kind": "dagger", "node": knife, "pos": from, "vel": dir * float(st["speed"]), "target": {},
					"damage": float(st["damage"]), "radius": 0.75 * run.area(), "pierce": 2, "life": 0.9})
			Sfx.play("throw", 1.4, -12.0)
		"lightning":
			var near: Array = []
			for e in enemies:
				if (e["pos"] as Vector3).distance_to(hero.position) < 15.0:
					near.append(e)
			for i in mini(count, near.size()):
				var e: Dictionary = near[_rng.randi() % near.size()]
				_strike(e["pos"], float(st["damage"]), float(st["area"]) * run.area())
		"bomb":
			for i in count:
				var target := _nearest(hero.position)
				var to: Vector3 = target["pos"] if not target.is_empty() else hero.position + facing * 6.0
				to += Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
				var pumpkin := Models.yard("pumpkin_orange_jackolantern")
				pumpkin.scale = Vector3.ONE * 0.8
				add_child(pumpkin)
				var from := hero.position + Vector3(0, 1.5, 0)
				pumpkin.position = from
				shots.append({"kind": "bomb", "node": pumpkin, "pos": from, "from": from, "to": to, "t": 0.0, "time": 0.8,
					"damage": float(st["damage"]), "radius": float(st["area"]) * run.area(), "vel": Vector3.ZERO, "target": {},
					"pierce": 0, "life": 2.0})


func _spin_axes(st: Dictionary, delta: float) -> void:
	var count := int(st["count"])
	while _axes.size() < count:
		var axe := Node3D.new()
		var head := Models.box(Vector3(0.7, 0.12, 0.5), Color(0.8, 0.82, 0.9))
		head.material_override = Models.material(Color(0.85, 0.88, 0.95), 0.6)
		head.position = Vector3(0.25, 0, 0)
		axe.add_child(head)
		var handle := Models.box(Vector3(0.9, 0.08, 0.08), Color(0.45, 0.28, 0.15))
		axe.add_child(handle)
		add_child(axe)
		_axes.append(axe)
	_axe_angle += delta * float(st["speed"])
	var r := float(st["area"]) * run.area()
	for i in _axes.size():
		var a := _axe_angle + TAU * i / _axes.size()
		var p := hero.position + Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 1.0, 0)
		_axes[i].position = p
		_axes[i].rotation = Vector3(0, -a * 3.0, 0)
		for e in enemies.duplicate():
			if float(e["hit_t"]) > 0.0:
				continue
			var ep: Vector3 = e["pos"]
			var reach := 1.0 if e["kind"] != "boss" else 2.0
			if Vector2(ep.x - p.x, ep.z - p.z).length() < reach:
				e["hit_t"] = float(st["cooldown"])
				hurt(e, float(st["damage"]), hero.position)


func _strike(at: Vector3, damage: float, radius: float) -> void:
	var bolt := Models.box(Vector3(0.25, 14.0, 0.25), Color(0.75, 0.9, 1.0))
	bolt.material_override = Models.material(Color(0.75, 0.9, 1.0), 6.0, true)
	add_child(bolt)
	bolt.position = at + Vector3(0, 7.0, 0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.7, 0.85, 1.0)
	flash.light_energy = 4.0
	flash.omni_range = 7.0
	flash.position = at + Vector3(0, 2, 0)
	add_child(flash)
	var tw := bolt.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		bolt.queue_free()
		flash.queue_free())
	_ring_flash(at, radius, Color(0.7, 0.85, 1.0))
	for e in enemies.duplicate():
		if (e["pos"] as Vector3).distance_to(at) < radius:
			hurt(e, damage, at)
	Sfx.play("zap", randf_range(0.9, 1.2), -6.0)


func _move_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var node: Node3D = s["node"]
		s["life"] = float(s["life"]) - delta
		if s["kind"] == "bomb":
			s["t"] = float(s["t"]) + delta
			var k := clampf(float(s["t"]) / float(s["time"]), 0.0, 1.0)
			var p := (s["from"] as Vector3).lerp(s["to"], k) + Vector3(0, sin(PI * k) * 4.0, 0)
			node.position = p
			node.rotate_x(delta * 8.0)
			if k >= 1.0:
				_explode(s["to"], float(s["damage"]), float(s["radius"]))
				node.queue_free()
				shots.remove_at(i)
			continue
		var target: Dictionary = s["target"]
		if s["kind"] == "bolt" and not target.is_empty() and enemies.has(target):
			var want: Vector3 = ((target["pos"] as Vector3) + Vector3(0, 0.8, 0) - (s["pos"] as Vector3)).normalized() * (s["vel"] as Vector3).length()
			s["vel"] = (s["vel"] as Vector3).lerp(want, clampf(delta * 8.0, 0, 1))
		var p: Vector3 = (s["pos"] as Vector3) + (s["vel"] as Vector3) * delta
		s["pos"] = p
		node.position = p
		var hit := false
		for e in enemies.duplicate():
			var ep: Vector3 = e["pos"]
			var reach := float(s["radius"]) + (1.4 if e["kind"] == "boss" else 0.0)
			if Vector2(ep.x - p.x, ep.z - p.z).length() < reach:
				hurt(e, float(s["damage"]), p - (s["vel"] as Vector3).normalized())
				s["pierce"] = int(s["pierce"]) - 1
				if int(s["pierce"]) <= 0:
					hit = true
					break
		if hit or float(s["life"]) <= 0.0:
			if hit:
				_puff(p, GameData.WEAPONS["bolt" if s["kind"] == "bolt" else "daggers"]["color"], 4)
			node.queue_free()
			shots.remove_at(i)


func _explode(at: Vector3, damage: float, radius: float) -> void:
	_puff(at + Vector3(0, 0.5, 0), Color(1.0, 0.55, 0.15), 22)
	_ring_flash(at, radius, Color(1.0, 0.5, 0.15))
	for e in enemies.duplicate():
		if (e["pos"] as Vector3).distance_to(at) < radius:
			hurt(e, damage, at)
	Sfx.play("boom", randf_range(1.1, 1.3), -8.0)
	_shake = maxf(_shake, 0.35)


# ---------------------------------------------------------------- pickups

func _pickups(delta: float) -> void:
	var reach := run.magnet()
	for i in range(gems.size() - 1, -1, -1):
		var g: Dictionary = gems[i]
		var p: Vector3 = g["pos"]
		var d := p.distance_to(hero.position)
		if d < reach or g.has("pull"):
			g["pull"] = true
			p = p.move_toward(hero.position, delta * 16.0)
			g["pos"] = p
			if p.distance_to(hero.position) < 0.6:
				gems.remove_at(i)
				_gain_xp(int(g["xp"]))
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		var node: Node3D = pk["node"]
		node.rotate_y(delta * 2.0)
		if (pk["pos"] as Vector3).distance_to(hero.position) < 1.4:
			pickups.remove_at(i)
			node.queue_free()
			match pk["kind"]:
				"coin":
					run.gold += 10
					Sfx.play("coin")
					_popup(hero.position + Vector3(0, 2.6, 0), "+10 gold", Color("ffd23a"))
				"food":
					hp = minf(run.max_hp(), hp + 30.0)
					Sfx.play("heal")
					_popup(hero.position + Vector3(0, 2.6, 0), "+30", Color("8ff2a2"))
				"chest":
					var c := run.choices(_rng, 1)
					run.apply(c[0])
					Sfx.play("levelup")
					hud.banner("Treasure: %s!" % FieldHud.choice_name(c[0]), Color("ffd23a"))


func _gain_xp(amount: int) -> void:
	Sfx.play("gem", randf_range(1.0, 1.3), -12.0)
	var levels := run.add_xp(amount)
	if levels > 0:
		pending_levels += levels
		_level_up()


func _level_up() -> void:
	if pending_levels <= 0 or state != "play":
		return
	pending_levels -= 1
	state = "levelup"
	Sfx.play("levelup")
	_ring_flash(hero.position, 3.0, Color(1, 0.9, 0.5))
	if autopilot:
		var c := run.choices(_rng)
		choose(c[0])
		return
	hud.show_choices(run.choices(_rng))


func choose(choice: Dictionary) -> void:
	run.apply(choice)
	state = "play"
	if pending_levels > 0:
		_level_up()


# ---------------------------------------------------------------- effects

func _puff(at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.25
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.5
	p.mesh = bm
	p.material_override = Models.material(color, 1.5)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8, false).timeout.connect(p.queue_free)


func _ring_flash(at: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	ring.mesh = t
	ring.material_override = Models.material(Color(color, 0.8), 3.0, true)
	ring.position = at + Vector3(0, 0.15, 0)
	ring.scale = Vector3.ONE * 0.2
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, 1, radius), 0.25)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.3)
	tw.tween_callback(ring.queue_free)


func _popup(at: Vector3, text: String, color: Color) -> void:
	_popups += 1
	var l := Label3D.new()
	l.text = text
	l.font = UI.font()
	l.font_size = 56
	l.outline_size = 12
	l.outline_modulate = Color(0.1, 0.05, 0.02)
	l.modulate = color
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 1.0, 0), 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.tween_callback(func() -> void:
		_popups -= 1
		l.queue_free())
