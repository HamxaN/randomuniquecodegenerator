class_name Battle
extends Node3D
## The arena in 3D. Your side is on the left, the Bone Army's on the right, the
## river runs down the middle with three bridges. Everything that happens is
## decided by [BattleSim]; this scene draws it: troops walking and swinging,
## arrows and boulders, spells, crumbling towers.

signal finished(result: Dictionary)

var sim := BattleSim.new()
var brain: BattleSim.Brain
var pilot: BattleSim.Brain    # plays your side in the CI play-test
var arena: Dictionary
var arena_index := 0
var camera: Camera3D
var hud: BattleHud
var selected := ""
var _nodes := {}     # entity id -> {"root", "ap", "card", "walk", "anim"}
var _zone: MeshInstance3D
var _ended := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	arena_index = GameData.arena_index(Save.trophies)
	arena = GameData.ARENAS[arena_index]
	sim.levels[BattleSim.YOU] = Save.levels()
	var ai_level := int(arena["ai_level"])
	var foe_cards: Array = GameData.unlocked_cards(int(arena["trophies"]))
	var foe_deck: Array = []
	foe_cards.shuffle()
	for c in foe_cards:
		if foe_deck.size() < GameData.DECK_SIZE:
			foe_deck.append(c)
	var foe_levels := {}
	for c in foe_deck:
		foe_levels[c] = ai_level
	sim.levels[BattleSim.FOE] = foe_levels
	sim.setup(Save.deck, foe_deck, _rng)
	brain = BattleSim.Brain.new(sim, BattleSim.FOE, ai_level)
	_environment()
	_field()
	for e in sim.entities:
		_spawn(e)
	camera = Camera3D.new()
	camera.fov = 44.0
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 23.5, 14.0)
	camera.look_at(Vector3(0, 0, 1.2), Vector3.UP)
	hud = BattleHud.new()
	hud.battle = self
	add_child(hud)


## Battle coordinates (x across, y along the field) to the 3D world: your
## side on the left of the screen.
static func to_world(p: Vector2) -> Vector3:
	return Vector3(-p.y, 0.0, p.x)


static func to_field(w: Vector3) -> Vector2:
	return Vector2(w.z, -w.x)


# ---------------------------------------------------------------- building the arena

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = arena["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _field() -> void:
	var w := GameData.FIELD_L
	var d := GameData.FIELD_W
	var ground: Color = arena["ground"]
	# The pitch with a mown-stripe pattern, on a wider meadow.
	var outer := Models.box(Vector3(80, 0.2, 60), ground.darkened(0.15))
	outer.position.y = -0.12
	add_child(outer)
	var img := Image.create(32, 2, false, Image.FORMAT_RGB8)
	for x in 32:
		for y in 2:
			img.set_pixel(x, y, ground if (x / 2) % 2 == 0 else ground.lightened(0.07))
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = ImageTexture.create_from_image(img)
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pm.roughness = 0.9
	var pitch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, d)
	pitch.mesh = plane
	pitch.material_override = pm
	pitch.position.y = 0.0
	add_child(pitch)
	# Stone border.
	for side in [-1.0, 1.0]:
		var wall := Models.box(Vector3(w + 1.0, 0.5, 0.5), Color(0.6, 0.6, 0.62))
		wall.position = Vector3(0, 0.2, side * (d / 2.0 + 0.25))
		add_child(wall)
		var end := Models.box(Vector3(0.5, 0.5, d + 1.0), Color(0.6, 0.6, 0.62))
		end.position = Vector3(side * (w / 2.0 + 0.25), 0.2, 0)
		add_child(end)
	# The river and its bridges.
	var water := Models.box(Vector3(GameData.RIVER * 2.0, 0.1, d), arena["water"])
	water.material_override = Models.material(arena["water"], 0.4)
	water.position.y = -0.02
	add_child(water)
	for bx in GameData.BRIDGES:
		var bridge := Models.box(Vector3(GameData.RIVER * 2.0 + 1.2, 0.18, GameData.BRIDGE_HALF * 2.0), Color(0.55, 0.38, 0.22))
		bridge.position = Vector3(0, 0.06, float(bx))
		add_child(bridge)
		for s in [-1.0, 1.0]:
			var rail := Models.box(Vector3(GameData.RIVER * 2.0 + 1.2, 0.3, 0.12), Color(0.4, 0.26, 0.14))
			rail.position = Vector3(0, 0.25, float(bx) + s * GameData.BRIDGE_HALF)
			add_child(rail)
	# Scenery around the walls.
	var rng := RandomNumberGenerator.new()
	rng.seed = arena_index * 17 + 3
	var trees := ["trees_A_large", "trees_B_large", "tree_single_A", "tree_single_B", "rock_single_A", "hill_single_A"]
	for i in 60:
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-22, 22))
		if absf(p.x) < w / 2.0 + 1.5 and absf(p.z) < d / 2.0 + 1.5:
			continue
		var t := Models.prop(Models.hex(trees[rng.randi() % trees.size()]))
		t.position = p
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(1.8, 2.6)
		if arena_index == 2:
			for m in t.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_overlay = Models.material(Color(1, 1, 1, 0.5))
		add_child(t)
	for team in ["blue", "red"]:
		for k in 3:
			var tent := Models.prop(Models.hex("tent"))
			var x := (-1.0 if team == "blue" else 1.0) * (w / 2.0 + 3.0)
			tent.position = Vector3(x, 0, -6.0 + k * 6.0)
			tent.scale = Vector3.ONE * 1.6
			add_child(tent)
			var flag := Models.prop(Models.hex("flag_%s" % team))
			flag.position = Vector3(x + (-1.5 if team == "blue" else 1.5), 0, -3.0 + k * 6.0)
			flag.scale = Vector3.ONE * 2.0
			add_child(flag)
	# Where you may deploy (shown while a troop card is selected).
	_zone = MeshInstance3D.new()
	var zp := PlaneMesh.new()
	zp.size = Vector2(w / 2.0 - GameData.RIVER - 0.4, d - 0.8)
	_zone.mesh = zp
	_zone.material_override = Models.material(Color(0.4, 0.75, 1.0, 0.2), 0.3, true)
	_zone.position = Vector3(-(w / 4.0 + (GameData.RIVER + 0.4) / 2.0), 0.03, 0)
	_zone.visible = false
	add_child(_zone)


# ---------------------------------------------------------------- entities

func _spawn(e: Dictionary) -> void:
	var team := "blue" if int(e["side"]) == BattleSim.YOU else "red"
	var root := Node3D.new()
	add_child(root)
	root.position = to_world(e["pos"])
	var ap: AnimationPlayer = null
	var walk := "Walking_A"
	if e["tower"]:
		var model := Models.building("castle" if e["kind"] == "keep" else "tower_A", team)
		model.scale = Vector3.ONE * (2.3 if e["kind"] == "keep" else 1.8)
		root.add_child(model)
		root.rotation.y = PI / 2 if team == "blue" else -PI / 2
	elif e["card"] == "catapult":
		var cat := Models.building("tower_catapult", team)
		cat.scale = Vector3.ONE * 1.4
		root.add_child(cat)
	else:
		var c := GameData.card(e["card"])
		var model_name: String = c["blue"] if team == "blue" else c["red"]
		var model := Models.character(model_name, CardArt.keep(e["card"]))
		model.scale = Vector3.ONE * float(c["scale"])
		root.add_child(model)
		if team == "blue" and model_name.begins_with("Skeleton"):
			# Your skeletons wear blue.
			for m in model.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_overlay = Models.material(Color(0.3, 0.55, 1.0, 0.35))
		ap = Models.animation_player(model)
		if ap != null:
			if model_name.begins_with("Skeleton") and ap.has_animation("Walking_D_Skeletons"):
				walk = "Walking_D_Skeletons"
			ap.play(walk)
		# Drop in with a little puff.
		root.scale = Vector3.ONE * 0.2
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_puff(root.position + Vector3(0, 0.3, 0), Color(1, 1, 1, 0.8), 8)
	_nodes[int(e["id"])] = {"root": root, "ap": ap, "card": e["card"], "walk": walk, "anim": walk, "last": root.position}


func _process(delta: float) -> void:
	if _ended:
		return
	var step := minf(delta, 0.1)
	brain.tick(step)
	if pilot != null:
		pilot.tick(step)
	sim.tick(step)
	_drain_events()
	for e in sim.entities:
		var n: Dictionary = _nodes.get(int(e["id"]), {})
		if n.is_empty():
			continue
		var root: Node3D = n["root"]
		if e["tower"] or e["building"]:
			continue
		var target := to_world(e["pos"])
		var moved := target.distance_to(root.position)
		if moved > 0.002:
			var dir := target - root.position
			root.rotation.y = lerp_angle(root.rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0, 1))
		root.position = target
		var ap: AnimationPlayer = n["ap"]
		if ap != null:
			var want: String = n["walk"] if moved > 0.002 else "Idle"
			if float(e["stun"]) > 0.0:
				want = "Idle"
				ap.speed_scale = 0.0
			elif n["anim"] != want and not (String(n["anim"]) != String(n["walk"]) and String(n["anim"]) != "Idle" and ap.is_playing()):
				ap.speed_scale = 1.0
				ap.play(want, 0.15)
				n["anim"] = want
	if sim.over and not _ended:
		_ended = true
		get_tree().create_timer(1.8).timeout.connect(func() -> void: finished.emit(result()))


func result() -> Dictionary:
	var won := sim.winner == BattleSim.YOU
	var draw := sim.winner == -1
	var crowns := int(sim.crowns[BattleSim.YOU])
	return {"won": won, "draw": draw, "crowns": crowns, "lost_crowns": int(sim.crowns[BattleSim.FOE]),
		"trophies": GameData.trophy_change(won, draw, crowns), "gold": GameData.gold_reward(won, crowns, arena_index)}


func _drain_events() -> void:
	for ev in sim.events:
		match ev["type"]:
			"spawn":
				var e := sim.by_id(int(ev["id"]))
				if not e.is_empty():
					_spawn(e)
			"attack":
				_on_attack(ev)
			"die":
				_on_die(ev)
			"spell":
				_on_spell(ev)
			"play":
				if int(ev["side"]) == BattleSim.YOU:
					Sfx.play("place")
	sim.events.clear()


func _on_attack(ev: Dictionary) -> void:
	var a: Dictionary = _nodes.get(int(ev["id"]), {})
	var t: Dictionary = _nodes.get(int(ev["target"]), {})
	if a.is_empty() or t.is_empty():
		return
	var from: Vector3 = (a["root"] as Node3D).position
	var to: Vector3 = (t["root"] as Node3D).position
	var ap: AnimationPlayer = a["ap"]
	if ap != null:
		var anim := CardArt.attack(a["card"])
		if ap.has_animation(anim):
			ap.speed_scale = 1.0
			ap.play(anim, 0.1)
			a["anim"] = anim
	if ev["ranged"]:
		var proj: Node3D
		var height := 1.6
		if a["card"] == "catapult":
			proj = Models.prop(Models.hex("projectile_catapult"))
			proj.scale = Vector3.ONE * 1.5
			height = 4.0
		elif a["card"] == "mage":
			proj = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.5
			(proj as MeshInstance3D).mesh = sm
			(proj as MeshInstance3D).material_override = Models.material(Color(1.0, 0.5, 0.15), 3.0)
		else:
			proj = Models.prop(Models.hex("Skeleton_Arrow"))
			proj.scale = Vector3.ONE * 1.2
		add_child(proj)
		var start := from + Vector3(0, 2.6 if ev["tower"] else 1.2, 0)
		var end := to + Vector3(0, 1.0, 0)
		proj.position = start
		var flight := clampf(start.distance_to(end) / 18.0, 0.15, 0.6)
		var tw := proj.create_tween()
		var fly := func(k: float) -> void:
			var p := start.lerp(end, k) + Vector3(0, sin(PI * k) * height * 0.5, 0)
			if p.distance_to(proj.position) > 0.01:
				proj.look_at(p, Vector3.UP)
			proj.position = p
		tw.tween_method(fly, 0.0, 1.0, flight)
		tw.tween_callback(func() -> void:
			if ev["splash"]:
				_puff(end, Color(1.0, 0.6, 0.2), 12)
			proj.queue_free())
		Sfx.play("shoot", randf_range(0.9, 1.2), -10.0)
	else:
		Sfx.play("hit", randf_range(0.9, 1.1), -8.0)


func _on_die(ev: Dictionary) -> void:
	var n: Dictionary = _nodes.get(int(ev["id"]), {})
	_nodes.erase(int(ev["id"]))
	if n.is_empty():
		return
	var root: Node3D = n["root"]
	if ev["tower"]:
		var ruin := Models.prop(Models.hex("building_destroyed"))
		ruin.position = root.position
		ruin.scale = Vector3.ONE * 2.0
		add_child(ruin)
		_puff(root.position + Vector3(0, 1.5, 0), Color(0.6, 0.55, 0.5), 30)
		Sfx.play("boom")
		var crown_for := 1 - int(ev["side"])
		hud.crown(crown_for, ev["kind"] == "keep")
		root.queue_free()
		return
	_puff(root.position + Vector3(0, 0.8, 0), Color(0.9, 0.9, 0.85), 10)
	Sfx.play("die", randf_range(0.9, 1.1), -6.0)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.2, 0.05, 1.2), 0.15)
	tw.tween_callback(root.queue_free)


func _on_spell(ev: Dictionary) -> void:
	var at := to_world(ev["pos"])
	var c := GameData.card(ev["card"])
	var r := float(c["radius"])
	match ev["card"]:
		"fireball":
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.8
			sm.height = 1.6
			ball.mesh = sm
			ball.material_override = Models.material(Color(1.0, 0.45, 0.1), 4.0)
			add_child(ball)
			ball.position = at + Vector3(-8 if int(ev["side"]) == BattleSim.YOU else 8, 14, 0)
			var tw := ball.create_tween()
			tw.tween_property(ball, "position", at, 0.4).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				_puff(at + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.15), 40)
				_ring(at, r, Color(1.0, 0.5, 0.15))
				Sfx.play("boom", 1.2)
				ball.queue_free())
		"freeze":
			_ring(at, r, Color(0.6, 0.9, 1.0))
			_puff(at + Vector3(0, 0.5, 0), Color(0.75, 0.95, 1.0), 30)
			Sfx.play("freeze")
		"heal":
			_ring(at, r, Color(0.4, 1.0, 0.5))
			_puff(at + Vector3(0, 0.5, 0), Color(0.5, 1.0, 0.6), 24)
			Sfx.play("heal")


# ---------------------------------------------------------------- input

func select(card_id: String) -> void:
	selected = card_id
	_zone.visible = card_id != "" and not GameData.is_spell(card_id)


func _unhandled_input(event: InputEvent) -> void:
	if selected == "" or sim.over:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var sp := (event as InputEventScreenTouch).position
		var from := camera.project_ray_origin(sp)
		var dir := camera.project_ray_normal(sp)
		if absf(dir.y) < 0.001:
			return
		var w := from + dir * (-from.y / dir.y)
		deploy(selected, to_field(w))
		get_viewport().set_input_as_handled()


func deploy(card_id: String, p: Vector2) -> bool:
	var c := GameData.card(card_id)
	if float(sim.mana[BattleSim.YOU]) < float(c["cost"]):
		hud.toast("Not enough mana")
		Sfx.play("error")
		return false
	if not sim.can_place(BattleSim.YOU, card_id, p):
		hud.toast("Deploy on your side of the river")
		Sfx.play("error")
		return false
	var ok := sim.play(BattleSim.YOU, card_id, p)
	if ok:
		select("")
	return ok


# ---------------------------------------------------------------- effects

func _puff(at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -5, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	bm.radial_segments = 6
	bm.rings = 3
	p.mesh = bm
	p.material_override = Models.material(color, 1.0)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _ring(at: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	ring.mesh = t
	ring.material_override = Models.material(Color(color, 0.85), 2.0, true)
	ring.position = at + Vector3(0, 0.12, 0)
	ring.scale = Vector3.ONE * 0.3
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, 1, radius), 0.3)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.45)
	tw.tween_callback(ring.queue_free)


## Screen-space health bars for the HUD.
func bars() -> Array:
	var out: Array = []
	for e in sim.entities:
		var n: Dictionary = _nodes.get(int(e["id"]), {})
		if n.is_empty():
			continue
		var full := float(e["hp"]) >= float(e["max"]) - 0.5
		if full and not e["tower"]:
			continue
		var h := 4.6 if e["kind"] == "keep" else (3.8 if e["tower"] else 2.4)
		if e["card"] == "golem":
			h = 4.2
		var top := (n["root"] as Node3D).position + Vector3(0, h, 0)
		out.append({"pos": camera.unproject_position(top), "frac": clampf(float(e["hp"]) / float(e["max"]), 0.0, 1.0),
			"side": int(e["side"]), "tower": e["tower"], "hp": int(ceil(float(e["hp"])))})
	return out
