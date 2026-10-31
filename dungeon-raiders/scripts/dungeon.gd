class_name Dungeon
extends Node3D
## One floor of the dungeon. Rooms lock when you walk in and the dead rise from
## the floor; clear them to open the gates. Gold and gear drop, treasure rooms
## hold chests, and the Bone King (or the Lich) waits in the last room.

signal exit_requested(next_floor: bool)

const CAM_OFFSET := Vector3(0, 13.0, 9.0)
const HALF := 10.0

var floor_n := 1
var autopilot := false
var hero: Actor
var monsters: Array[Actor] = []
var hud: Hud
var camera: Camera3D
var input_move := Vector3.ZERO

# Run state (carried between floors by Main).
var run := {"level": 1, "xp": 0, "gold": 0, "kills": 0, "boons": [], "potions": 2, "revived": false}
var speed_mult := 1.0
var rate_mult := 1.0
var attack_mult := 1.0
var crit := 0.05
var leech := 0.0
var cleave := 0
var gold_mult := 1.0
var skill_cd := 0.0
var skill_max := GameData.SKILL_COOLDOWN

var rooms: Array[Dictionary] = []
var current_room := -1
var state := "explore"
var boss: Actor
var _cleared := {}
var _gates := {}
var _queue: Array[String] = []
var _spawn_t := 0.0
var _bolts: Array[Dictionary] = []
var _coins: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _chests: Array[Dictionary] = []
var _portal: Node3D
var _torches: Array[OmniLight3D] = []
var _hero_light: OmniLight3D
var _cam_pos := Vector3.ZERO
var _shake := 0.0
var _numbers: Array[Label3D] = []
var _number_next := 0
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.seed = floor_n * 7717 + Save.runs * 31
	_environment()
	rooms = DungeonGen.generate(floor_n, _rng.seed)["rooms"] as Array[Dictionary]
	for i in rooms.size():
		_build_room(i)
	_build_corridors()
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	camera.current = true
	_make_numbers()
	_spawn_hero()
	_cam_pos = hero.global_position + CAM_OFFSET
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.dungeon = self
	layer.add_child(hud)
	hud.banner("FLOOR %d" % floor_n, "Find and slay the %s" % GameData.ENEMIES[GameData.boss_for(floor_n)]["name"])
	Ads.hide_banner()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.018, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.38, 0.52)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.04, 0.06)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.6, 0.85)
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-62, 25, 0)
	moon.shadow_enabled = true
	add_child(moon)


# ---------------------------------------------------------------- Building the floor

func _place(piece: String, pos: Vector3, rot: float, solid: bool, shrink: float = 0.85) -> Node3D:
	var node := Models.prop(Models.dungeon(piece))
	add_child(node)
	node.position = pos
	node.rotation.y = rot
	if solid:
		var b := Models.bounds(node)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		add_child(body)
		body.position = pos
		body.rotation.y = rot
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(b.size.x * shrink, 0.4), maxf(b.size.y, 1.0), maxf(b.size.z * shrink, 0.4))
		cs.shape = box
		cs.position = b.get_center()
		body.add_child(cs)
	return node


func _build_room(i: int) -> void:
	var r: Dictionary = rooms[i]
	var c := DungeonGen.center(r["cell"])
	var kind: String = r["kind"]
	var tile := DungeonGen.TILE
	var n := DungeonGen.ROOM_TILES
	for x in n:
		for z in n:
			var p := c + Vector3((x - n / 2) * tile, 0, (z - n / 2) * tile)
			var piece := "floor_tile_large"
			var roll := _rng.randf()
			if kind == "boss" and (x + z) % 2 == 0:
				piece = "floor_tile_big_grate"
			elif roll < 0.18:
				piece = "floor_tile_large_rocks"
			elif roll < 0.26:
				piece = "floor_dirt_large"
			_place(piece, p, _rng.randi_range(0, 3) * PI / 2, false)
	var links: Array = r["links"]
	for side in 4:
		var dir := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][side] as Vector2i
		var has_door := links.has((r["cell"] as Vector2i) + dir)
		for k in n:
			var along := (k - n / 2) * tile
			var p: Vector3
			var rot := 0.0
			if dir.x != 0:
				p = c + Vector3(dir.x * HALF, 0, along)
				rot = PI / 2
			else:
				p = c + Vector3(along, 0, dir.y * HALF)
			if has_door and k == n / 2:
				var gate := _place("wall_gated", p, rot, false)
				gate.position.y = -4.2
				_gates[[i, side]] = gate
				continue
			var piece := "wall"
			var roll := _rng.randf()
			if roll < 0.15:
				piece = "wall_cracked"
			elif roll < 0.22 and kind != "boss":
				piece = "wall_shelves"
			_place(piece, p, rot, true, 1.0)
			if k == 1 or k == n - 2:
				if _rng.randf() < 0.7:
					_torch(p - Vector3(dir.x, 0, dir.y) * 0.55 + Vector3(0, 2.6, 0), atan2(-dir.x, -dir.y))
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		_place("pillar_decorated" if kind == "boss" else "pillar", c + corner * (HALF - 0.1), 0.0, true, 0.9)
	match kind:
		"start":
			_place("table_long_decorated_A", c + Vector3(-5, 0, -4), PI / 2, true)
			_place("barrel_large", c + Vector3(6, 0, -6), 0.0, true)
			_place("crates_stacked", c + Vector3(-6.5, 0, 5.5), 0.3, true)
			_place("banner_blue", c + Vector3(0, 0, -HALF + 0.6), 0.0, false)
		"treasure":
			var chest := _place("chest_gold", c + Vector3(0, 0, -2), 0.0, true)
			_chests.append({"node": chest, "open": false, "gold": 60 + floor_n * 25, "luck": 0.4})
			_place("coin_stack_large", c + Vector3(-2.5, 0, -2.5), 0.0, false)
			_place("coin_stack_small", c + Vector3(2.4, 0, -1.6), 0.0, false)
			_place("candle_triple", c + Vector3(-3.5, 0, -6), 0.0, false)
		"boss":
			_place("banner_triple_red", c + Vector3(-4, 0, -HALF + 0.6), 0.0, false)
			_place("banner_triple_red", c + Vector3(4, 0, -HALF + 0.6), 0.0, false)
			_place("rubble_half", c + Vector3(6, 0, 6), 0.4, true)
			var red := OmniLight3D.new()
			red.light_color = Color(1.0, 0.25, 0.2)
			red.light_energy = 1.4
			red.omni_range = 14.0
			red.position = c + Vector3(0, 4, 0)
			add_child(red)
		_:
			var layout := _rng.randi_range(0, 3)
			match layout:
				0:
					for p in [Vector3(-4, 0, -4), Vector3(4, 0, 4)]:
						_place("column", c + p, 0.0, true)
				1:
					_place("barrel_small_stack", c + Vector3(-6, 0, 6), 0.0, true)
					_place("box_large", c + Vector3(5, 0, -5.5), 0.4, true)
				2:
					_place("rubble_half", c + Vector3(-5, 0, 0), PI / 2, true)
				_:
					_place("keg", c + Vector3(6, 0, 5), 0.0, true)
					_place("box_small", c + Vector3(-6, 0, -6), 0.5, true)
			if _rng.randf() < 0.4:
				var chest := _place("chest", c + Vector3(_rng.randf_range(-5, 5), 0, -6.5), 0.0, true)
				_chests.append({"node": chest, "open": false, "gold": 20 + floor_n * 8, "luck": 0.0})


func _build_corridors() -> void:
	var done := {}
	for r in rooms:
		for other in r["links"]:
			var a: Vector2i = r["cell"]
			var b: Vector2i = other
			var key := [mini(a.x, b.x), mini(a.y, b.y), maxi(a.x, b.x), maxi(a.y, b.y)]
			if done.has(key):
				continue
			done[key] = true
			var ca := DungeonGen.center(a)
			var dir := Vector3(b.x - a.x, 0, b.y - a.y)
			var gap := DungeonGen.SPACING - HALF * 2.0
			var steps := int(gap / DungeonGen.TILE)
			for s in steps:
				var p := ca + dir * (HALF + DungeonGen.TILE * (s + 0.5))
				_place("floor_tile_large", p, 0.0, false)
				var side := Vector3(dir.z, 0, dir.x)
				var rot := 0.0 if dir.x != 0 else PI / 2
				_place("wall", p + side * 2.0, rot, true, 1.0)
				_place("wall", p - side * 2.0, rot, true, 1.0)
				if s == 1:
					_torch(p + side * 1.45 + Vector3(0, 2.6, 0), atan2(side.x, side.z))


func _torch(pos: Vector3, rot: float) -> void:
	var t := Models.prop(Models.dungeon("torch_mounted"))
	add_child(t)
	t.position = pos
	t.rotation.y = rot
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.8
	light.omni_range = 9.0
	light.omni_attenuation = 1.3
	light.position = pos + Vector3(0, 0.6, 0)
	add_child(light)
	_torches.append(light)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.34
	flame.mesh = sm
	flame.material_override = Models.material(Color(1.0, 0.6, 0.2), 6.0, true)
	flame.position = pos + Vector3(0, 0.55, 0)
	add_child(flame)


func _spawn_hero() -> void:
	var h := GameData.hero(Save.hero)
	var stats := Save.hero_stats(Save.hero)
	hero = Actor.new()
	hero.dungeon = self
	hero.setup_hero(h, stats)
	add_child(hero)
	hero.global_position = DungeonGen.center(Vector2i.ZERO) + Vector3(0, 0, 3)
	hero.died.connect(_on_hero_died)
	crit = float(stats["crit"])
	gold_mult = float(stats["gold"])
	if floor_n == 1 or not run.has("potions"):
		run["potions"] = int(stats["potions"])
	for b in run["boons"]:
		_apply_boon(str(b), false)
	_hero_light = OmniLight3D.new()
	_hero_light.light_color = Color(1.0, 0.85, 0.65)
	_hero_light.light_energy = 1.1
	_hero_light.omni_range = 8.0
	add_child(_hero_light)


# ---------------------------------------------------------------- Main loop

func _process(delta: float) -> void:
	_t += delta
	skill_cd = maxf(0.0, skill_cd - delta)
	for i in _torches.size():
		_torches[i].light_energy = 1.7 + sin(_t * 9.0 + i * 1.7) * 0.15 + sin(_t * 23.0 + i) * 0.08
	if hero != null:
		_hero_light.global_position = hero.global_position + Vector3(0, 3.0, 0)
	_read_keyboard()
	if autopilot:
		_autopilot()
	_update_camera(delta)
	_update_bolts(delta)
	_update_loot(delta)
	_check_rooms()
	if state == "fight":
		_spawn_t -= delta
		if _spawn_t <= 0.0 and _queue.size() > 0 and _alive() < 8:
			_spawn_t = 0.35
			_spawn_monster(_queue.pop_front())
		if _queue.is_empty() and _alive() == 0:
			_room_cleared()


func _read_keyboard() -> void:
	if autopilot or hud == null or hud.stick_active():
		return
	var k := Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		k.x -= 1
	if Input.is_key_pressed(KEY_D):
		k.x += 1
	if Input.is_key_pressed(KEY_W):
		k.z -= 1
	if Input.is_key_pressed(KEY_S):
		k.z += 1
	input_move = k.normalized()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_SPACE:
			use_skill()
		elif k.keycode == KEY_Q:
			drink_potion()


## For the screenshot run: walk towards the nearest monster, or on to the next room.
func _autopilot() -> void:
	if hero == null or hero.dead:
		return
	var goal := Vector3.ZERO
	var m := nearest_monster(hero.global_position, 60.0, false)
	if m != null:
		var to := m.global_position - hero.global_position
		to.y = 0
		goal = to.normalized() if to.length() > hero.reach * 0.8 else Vector3.ZERO
	elif state == "explore":
		var next := _next_room_target()
		var to := next - hero.global_position
		to.y = 0
		goal = to.normalized() if to.length() > 0.6 else Vector3.ZERO
	input_move = goal
	if skill_cd <= 0.0 and _alive() >= 3:
		use_skill()
	if hero.hp < hero.max_hp * 0.35:
		drink_potion()


var _auto_goal := Vector3.ZERO


## The next room to walk to on the way to the nearest room not yet cleared.
func _next_room_target() -> Vector3:
	if _portal != null:
		return _portal.global_position
	var here := _room_at(hero.global_position)
	if here < 0:
		return _auto_goal
	var target := -1
	for i in rooms.size():
		if not _cleared.has(i) and rooms[i]["kind"] != "start" and i != here:
			if target < 0 or int(rooms[i]["depth"]) < int(rooms[target]["depth"]):
				target = i
	if target < 0:
		return hero.global_position
	# Breadth-first search over the room links for the first step.
	var start: Vector2i = rooms[here]["cell"]
	var goal: Vector2i = rooms[target]["cell"]
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for r in rooms:
			if r["cell"] == c:
				for l in r["links"]:
					if not prev.has(l):
						prev[l] = c
						queue.append(l)
	var step := goal
	while prev.has(step) and prev[step] != start:
		step = prev[step]
	_auto_goal = DungeonGen.center(step)
	return _auto_goal


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / DungeonGen.SPACING), roundi(p.z / DungeonGen.SPACING))


func _room_at(p: Vector3) -> int:
	var cell := _cell_of(p)
	var c := DungeonGen.center(cell)
	if absf(p.x - c.x) > HALF - 1.2 or absf(p.z - c.z) > HALF - 1.2:
		return -1
	for i in rooms.size():
		if rooms[i]["cell"] == cell:
			return i
	return -1


func _check_rooms() -> void:
	if hero == null or hero.dead or state != "explore":
		return
	var i := _room_at(hero.global_position)
	if i < 0 or i == current_room:
		return
	current_room = i
	hud.minimap_visit(i)
	var kind: String = rooms[i]["kind"]
	if _cleared.has(i) or kind == "start" or kind == "treasure":
		_cleared[i] = true
		return
	state = "fight"
	_set_gates(i, true)
	Sfx.play("door")
	shake(0.25)
	if kind == "boss":
		var b := GameData.boss_for(floor_n)
		_queue = [b, "minion", "minion", "archer"]
		hud.banner(GameData.ENEMIES[b]["name"].to_upper(), "BOSS", true)
	else:
		_queue = GameData.room_monsters(floor_n, int(rooms[i]["depth"]), _rng.randi())
	_spawn_t = 0.5


func _set_gates(room: int, closed: bool) -> void:
	for side in 4:
		var key := [room, side]
		if not _gates.has(key):
			continue
		var gate: Node3D = _gates[key]
		var tw := gate.create_tween()
		tw.tween_property(gate, "position:y", 0.0 if closed else -4.2, 0.35)
		var body_name := "GateBody%d_%d" % [room, side]
		if closed:
			var body := StaticBody3D.new()
			body.name = body_name
			body.collision_layer = 1
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(4, 4, 1)
			cs.shape = box
			cs.position = Vector3(0, 2, 0)
			body.add_child(cs)
			add_child(body)
			body.global_position = Vector3(gate.global_position.x, 0, gate.global_position.z)
			body.rotation.y = gate.rotation.y
		elif has_node(body_name):
			get_node(body_name).queue_free()


func _spawn_monster(monster_kind: String) -> void:
	var c := DungeonGen.center(rooms[current_room]["cell"])
	var p := c + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
	for i in 6:
		if p.distance_to(hero.global_position) > 4.5:
			break
		p = c + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
	var m := Actor.new()
	m.dungeon = self
	m.setup_monster(monster_kind, floor_n)
	add_child(m)
	m.global_position = p
	m.rotation.y = _rng.randf() * TAU
	m.rise()
	monsters.append(m)
	m.died.connect(_on_monster_died)
	_dust(p, Color(0.4, 0.36, 0.3), 14)
	if monster_kind in ["boss", "lich"]:
		boss = m


func _alive() -> int:
	var n := 0
	for m in monsters:
		if not m.dead:
			n += 1
	return n


func _room_cleared() -> void:
	_cleared[current_room] = true
	state = "explore"
	_set_gates(current_room, false)
	hero.heal(hero.max_hp * 0.2)
	Sfx.play("door", 1.2)
	if rooms[current_room]["kind"] == "boss":
		_open_portal(DungeonGen.center(rooms[current_room]["cell"]))
		hud.banner("FLOOR CLEARED", "Step into the portal to go deeper")
	else:
		hud.toast("Room cleared")


func _open_portal(at: Vector3) -> void:
	_portal = Node3D.new()
	add_child(_portal)
	_portal.global_position = at
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.3
	tm.outer_radius = 1.6
	ring.mesh = tm
	ring.material_override = Models.material(Color(0.5, 0.75, 1.0), 5.0, true)
	ring.position.y = 0.1
	_portal.add_child(ring)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.3
	cm.bottom_radius = 1.3
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = Models.material(Color(0.3, 0.5, 1.0, 0.6), 3.0, true)
	_portal.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.7, 1.0)
	light.light_energy = 3.0
	light.omni_range = 7.0
	light.position.y = 1.5
	_portal.add_child(light)


# ---------------------------------------------------------------- Queries

func nearest_monster(from: Vector3, max_range: float, need_sight: bool) -> Actor:
	var best: Actor = null
	var best_d := INF
	for m in monsters:
		if m.dead or m.spawn_lock > 0.0:
			continue
		var d := from.distance_to(m.global_position)
		if d <= max_range and d < best_d:
			if need_sight and not line_of_sight(from + Vector3(0, 1.2, 0), m.center()):
				continue
			best_d = d
			best = m
	return best


func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func separation(me: Actor) -> Vector3:
	var push := Vector3.ZERO
	for m in monsters:
		if m == me or m.dead:
			continue
		var d := me.global_position - m.global_position
		d.y = 0
		var l := d.length()
		var r := 1.1 * (2.0 if m.kind in ["boss", "lich"] or me.kind in ["boss", "lich"] else 1.0)
		if l < r and l > 0.001:
			push += d / l * (r - l) / r
	return push


# ---------------------------------------------------------------- Combat

func _roll_damage(base: float) -> Array:
	var is_crit := randf() < crit
	return [base * attack_mult * (2.0 if is_crit else 1.0) * randf_range(0.9, 1.1), is_crit]


func hero_strike(h: Actor) -> void:
	if h.ranged:
		var shots := 1 + cleave
		for s in shots:
			var dir := h.facing
			if h.target != null and not h.target.dead:
				dir = (h.target.center() - h.center())
				dir.y = 0
				dir = dir.normalized()
			dir = dir.rotated(Vector3.UP, (s - (shots - 1) / 2.0) * 0.18)
			_fire(h.center() + dir * 0.6, dir, 18.0 if h.kind == "rogue" else 13.0, h.attack, true, h.kind == "mage")
		Sfx.play("bow" if h.kind == "rogue" else "magic", 1.0, -4.0)
		return
	var hits := 0
	Sfx.play("swing", randf_range(0.9, 1.1))
	var hit_list: Array[Actor] = []
	for m in monsters:
		if m.dead or m.spawn_lock > 0.0:
			continue
		var to := m.global_position - h.global_position
		to.y = 0
		if to.length() <= h.reach + 0.7 * m._scale and h.facing.angle_to(to.normalized()) < deg_to_rad(75):
			hit_list.append(m)
	hit_list.sort_custom(func(a: Actor, b: Actor) -> bool: return a.global_position.distance_to(h.global_position) < b.global_position.distance_to(h.global_position))
	for m in hit_list:
		if hits >= 3 + cleave:
			break
		hits += 1
		_damage_monster(m, h.attack, m.global_position - h.global_position)
	if hits > 0:
		shake(0.08)


func _damage_monster(m: Actor, base: float, push: Vector3) -> void:
	var roll := _roll_damage(base)
	var amount: float = roll[0]
	m.take_damage(amount, push)
	number(m.head(), amount, bool(roll[1]))
	_sparks(m.center(), Color(0.95, 0.9, 0.8), 5)
	if leech > 0.0:
		hero.heal(amount * leech)


func use_skill() -> void:
	if skill_cd > 0.0 or hero == null or hero.dead:
		return
	skill_cd = skill_max
	var h := hero
	match GameData.hero(Save.hero)["skill"]:
		"whirl":
			h.one_shot("2H_Melee_Attack_Spin" if h._ap != null and h._ap.has_animation("2H_Melee_Attack_Spin") else "1H_Melee_Attack_Slice_Horizontal", 1.4)
			_area(h.global_position, 4.0, h.attack * 2.5, Color(0.6, 0.8, 1.0), false)
		"slam":
			h.one_shot("Jump_Full_Short", 1.6)
			h.knock = h.facing * 14.0
			var tw := create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(func() -> void: _area(h.global_position + h.facing * 1.2, 3.6, h.attack * 3.0, Color(1.0, 0.6, 0.3), false))
		"volley":
			h.one_shot("2H_Ranged_Shoot", 1.4)
			for i in 7:
				var dir := h.facing.rotated(Vector3.UP, (i - 3) * 0.17)
				_fire(h.center() + dir * 0.6, dir, 18.0, h.attack * 1.4, true, false)
			Sfx.play("bow", 0.8)
		_:
			h.one_shot("Spellcast_Long" if h._ap != null and h._ap.has_animation("Spellcast_Long") else "Spellcast_Shoot", 1.6)
			_area(h.global_position, 6.0, h.attack * 1.6, Color(0.55, 0.85, 1.0), true)
	Sfx.play("magic", 0.7)


func _area(at: Vector3, radius: float, dmg: float, color: Color, freeze: bool) -> void:
	_ring(at, radius, color)
	_sparks(at + Vector3(0, 0.5, 0), color, 24)
	shake(0.35)
	for m in monsters:
		if m.dead or m.spawn_lock > 0.0:
			continue
		if m.global_position.distance_to(at) <= radius + 0.5 * m._scale:
			_damage_monster(m, dmg, m.global_position - at)
			if freeze and not m.dead:
				m.frozen = 2.5 if not m.kind in ["boss", "lich"] else 1.0


func drink_potion() -> void:
	if int(run["potions"]) <= 0 or hero == null or hero.dead or hero.hp >= hero.max_hp:
		return
	run["potions"] = int(run["potions"]) - 1
	hero.heal(hero.max_hp * GameData.POTION_HEAL)
	_sparks(hero.center(), Color(1.0, 0.3, 0.35), 18)
	Sfx.play("loot", 0.7)


func monster_shoot(m: Actor, t: Actor) -> void:
	var from := m.center() + m.facing * 0.6
	var dir := t.center() + t.velocity * 0.2 - from
	dir.y = 0
	_fire(from, dir.normalized(), 10.0 if m.kind in ["mage", "lich"] else 14.0, m.attack, false, m.kind in ["mage", "lich"])
	if m.kind == "lich":
		for s in [-0.35, 0.35]:
			_fire(from, dir.normalized().rotated(Vector3.UP, s), 10.0, m.attack * 0.7, false, true)


func _fire(from: Vector3, dir: Vector3, spd: float, dmg: float, friendly: bool, magic: bool) -> void:
	var node: Node3D
	if magic:
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.48
		orb.mesh = sm
		var col := Color(0.6, 0.4, 1.0) if friendly else Color(0.4, 1.0, 0.5)
		orb.material_override = Models.material(col, 4.0, true)
		var light := OmniLight3D.new()
		light.light_color = col
		light.omni_range = 3.0
		light.light_energy = 1.4
		orb.add_child(light)
		node = orb
	else:
		node = Models.gear("Skeleton_Arrow")
		node.scale = Vector3.ONE * 1.3
	add_child(node)
	node.global_position = from
	node.look_at(from + dir, Vector3.UP)
	if not magic:
		node.rotate_object_local(Vector3.RIGHT, -PI / 2)
	_bolts.append({"node": node, "pos": from, "dir": dir, "speed": spd, "dmg": dmg, "life": 1.6, "friendly": friendly})


func _update_bolts(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		var prev: Vector3 = b["pos"]
		var next: Vector3 = prev + (b["dir"] as Vector3) * float(b["speed"]) * delta
		b["pos"] = next
		b["life"] = float(b["life"]) - delta
		(b["node"] as Node3D).global_position = next
		var done := float(b["life"]) <= 0.0
		if not done and not space.intersect_ray(PhysicsRayQueryParameters3D.create(prev, next, 1)).is_empty():
			done = true
			_sparks(next, Color(0.9, 0.8, 0.6), 5)
		if not done:
			if b["friendly"]:
				for m in monsters:
					if not m.dead and m.spawn_lock <= 0.0 and Vector2(m.global_position.x - next.x, m.global_position.z - next.z).length() < 0.8 * m._scale:
						_damage_monster(m, float(b["dmg"]), b["dir"])
						done = true
						break
			elif hero != null and not hero.dead and Vector2(hero.global_position.x - next.x, hero.global_position.z - next.z).length() < 0.75:
				hero.take_damage(float(b["dmg"]), b["dir"])
				done = true
		if done:
			(b["node"] as Node3D).queue_free()
			_bolts.remove_at(i)


func slam(m: Actor, at: Vector3, radius: float, dmg: float) -> void:
	_ring(at, radius, Color(1.0, 0.45, 0.2))
	_dust(at, Color(0.45, 0.38, 0.3), 22)
	shake(0.5)
	Sfx.play("door", 0.8)
	if hero != null and not hero.dead and hero.global_position.distance_to(at) <= radius:
		hero.take_damage(dmg, hero.global_position - m.global_position)
		hero.knock += (hero.global_position - at).normalized() * 9.0


func on_hurt(a: Actor, amount: float) -> void:
	if a == hero:
		hud.hurt()
		Sfx.vibrate(20)
		number(hero.head(), amount, false, true)
	else:
		Sfx.play("hurt", randf_range(0.9, 1.15), -6.0)


func _on_monster_died(m: Actor) -> void:
	run["kills"] = int(run["kills"]) + 1
	Sfx.play("kill", randf_range(0.9, 1.1))
	_dust(m.global_position, Color(0.85, 0.82, 0.75), 12)
	var coins := int(ceil(float(m.info["gold"]) * gold_mult))
	for i in mini(coins, 8):
		_drop_coin(m.global_position, maxi(1, coins / mini(coins, 8)))
	_gain_xp(int(m.info["xp"]))
	var is_boss: bool = m.kind in ["boss", "lich"]
	if is_boss or _rng.randf() < 0.07 + 0.02 * floor_n:
		_drop_item(m.global_position, GameData.roll_item(floor_n, _rng, 0.6 if is_boss else 0.0))
	if is_boss:
		boss = null
		shake(0.7)
	var tw := m.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(m, "position:y", -1.6, 1.0)
	tw.tween_callback(func() -> void:
		monsters.erase(m)
		m.queue_free())


func _gain_xp(amount: int) -> void:
	run["xp"] = int(run["xp"]) + amount
	var need := GameData.xp_for_level(int(run["level"]))
	if int(run["xp"]) >= need:
		run["xp"] = int(run["xp"]) - need
		run["level"] = int(run["level"]) + 1
		Sfx.play("levelup")
		_sparks(hero.center(), Color(1.0, 0.85, 0.3), 30)
		if autopilot:
			_apply_boon(GameData.boon_choices(int(run["level"]) * 13)[0]["id"], true)
		else:
			hud.show_boons(GameData.boon_choices(int(run["level"]) * 13 + Save.runs))


func choose_boon(id: String) -> void:
	_apply_boon(id, true)


func _apply_boon(id: String, record: bool) -> void:
	if record:
		(run["boons"] as Array).append(id)
	match id:
		"atk":
			attack_mult *= 1.2
		"speed":
			rate_mult *= 1.18
		"hp":
			hero.max_hp += 40.0
			if record:
				hero.hp = hero.max_hp
		"crit":
			crit += 0.12
		"move":
			speed_mult *= 1.12
		"leech":
			leech += 0.03
		"skill":
			skill_max *= 0.75
		"multishot":
			cleave += 1
		"gold":
			gold_mult *= 1.3


func _on_hero_died(_a: Actor) -> void:
	state = "dead"
	hud.hero_down(not bool(run["revived"]))


func revive_hero() -> void:
	run["revived"] = true
	hero.revive(0.6)
	state = "fight" if _alive() > 0 or _queue.size() > 0 else "explore"
	_area(hero.global_position, 6.0, 200.0, Color(1.0, 0.9, 0.5), false)


## Ends the run; returns the summary for the results screen.
func end_run() -> Dictionary:
	state = "done"
	var reached := floor_n - 1 + (1 if _portal != null else 0)
	var record := Save.finish_run(maxi(reached, 0), int(run["kills"]), int(run["gold"]))
	Ads.match_finished()
	return {"floor": reached, "kills": run["kills"], "gold": run["gold"], "level": run["level"], "record": record}


# ---------------------------------------------------------------- Loot

func _drop_coin(at: Vector3, value: int) -> void:
	var c := Models.prop(Models.dungeon("coin"))
	c.scale = Vector3.ONE * 1.6
	add_child(c)
	c.global_position = at + Vector3(0, 0.8, 0)
	var vel := Vector3(randf_range(-3, 3), randf_range(4, 6), randf_range(-3, 3))
	_coins.append({"node": c, "vel": vel, "value": value, "age": 0.0})


func _drop_item(at: Vector3, item: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(at.x, 0.0, at.z)
	var model := Models.prop(Models.dungeon("sword_shield_gold" if item["rarity"] in ["epic", "legendary"] else "sword_shield"))
	model.position.y = 1.0
	model.scale = Vector3.ONE * 0.8
	root.add_child(model)
	var col: Color = GameData.rarity(item["rarity"])["color"]
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.35
	cm.height = 5.0
	beam.mesh = cm
	beam.material_override = Models.material(Color(col, 0.35), 3.0, true)
	beam.position.y = 2.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position.y = 1.2
	root.add_child(light)
	_items.append({"node": root, "model": model, "item": item})
	Sfx.play("loot")


func _update_loot(delta: float) -> void:
	if hero == null:
		return
	var hp := hero.global_position
	for i in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[i]
		var node: Node3D = c["node"]
		c["age"] = float(c["age"]) + delta
		var v: Vector3 = c["vel"]
		var to := hp + Vector3(0, 1, 0) - node.global_position
		if float(c["age"]) > 0.6 and not hero.dead:
			v = v.lerp(to.normalized() * 16.0, clampf(delta * 6.0, 0, 1))
		else:
			v.y -= 18.0 * delta
		c["vel"] = v
		node.global_position += v * delta
		if node.global_position.y < 0.15:
			node.global_position.y = 0.15
			c["vel"] = Vector3(v.x * 0.6, absf(v.y) * 0.35, v.z * 0.6)
		node.rotate_y(delta * 8.0)
		if to.length() < 0.9 and float(c["age"]) > 0.6:
			run["gold"] = int(run["gold"]) + int(c["value"])
			Sfx.play("coin", randf_range(0.95, 1.2), -8.0)
			node.queue_free()
			_coins.remove_at(i)
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var node: Node3D = it["node"]
		var model: Node3D = it["model"]
		model.rotate_y(delta * 2.0)
		model.position.y = 1.0 + sin(_t * 3.0) * 0.15
		if not hero.dead and node.global_position.distance_to(hp) < 1.6:
			var item: Dictionary = it["item"]
			var equipped := Save.offer_item(item)
			hud.loot_popup(item, equipped)
			Sfx.play("equip" if equipped else "coin")
			if equipped:
				_refresh_hero_gear()
			node.queue_free()
			_items.remove_at(i)
	for ch in _chests:
		if ch["open"]:
			continue
		var node: Node3D = ch["node"]
		if not hero.dead and node.global_position.distance_to(hp) < 2.4 and state == "explore":
			ch["open"] = true
			var lid := node.find_child("chest_lid", true, false) as Node3D
			if lid != null:
				lid.create_tween().tween_property(lid, "rotation:x", -1.9, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("loot", 0.8)
			for k in 8:
				_drop_coin(node.global_position, maxi(1, int(ch["gold"]) / 8))
			if float(ch["luck"]) > 0.0 or _rng.randf() < 0.45:
				_drop_item(node.global_position + Vector3(0, 0, 1.6), GameData.roll_item(floor_n, _rng, float(ch["luck"])))
	if _portal != null:
		_portal.rotate_y(delta)
		if not hero.dead and _portal.global_position.distance_to(hp) < 1.6 and state == "explore":
			state = "portal"
			Sfx.play("levelup", 0.8)
			hud.floor_cleared()


## Equipped gear changes attack and health right away.
func _refresh_hero_gear() -> void:
	var stats := Save.hero_stats(Save.hero)
	var frac := hero.hp / hero.max_hp
	hero.attack = float(stats["attack"])
	hero.max_hp = float(stats["hp"]) + 40.0 * float((run["boons"] as Array).count("hp"))
	hero.hp = hero.max_hp * frac
	crit = float(stats["crit"]) + 0.12 * float((run["boons"] as Array).count("crit"))


# ---------------------------------------------------------------- Camera and effects

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_camera(delta: float) -> void:
	if hero == null:
		return
	var goal := hero.global_position + hero.facing * 1.2
	_cam_pos = _cam_pos.lerp(goal + CAM_OFFSET, clampf(5.0 * delta, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 1.6)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 1.2
	camera.global_position = _cam_pos + jitter
	camera.look_at(_cam_pos - CAM_OFFSET + Vector3(0, 0.8, 0), Vector3.UP)


func _make_numbers() -> void:
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


func number(at: Vector3, amount: float, is_crit: bool, on_hero: bool = false) -> void:
	var l := _numbers[_number_next]
	_number_next = (_number_next + 1) % _numbers.size()
	l.text = str(int(round(amount)))
	l.modulate = Color(1.0, 0.35, 0.3) if on_hero else (Color(1.0, 0.8, 0.2) if is_crit else Color.WHITE)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.font_size = 84 if is_crit else 58
	l.visible = true
	l.global_position = at + Vector3(randf_range(-0.4, 0.4), 0, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.2, 0), 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tw.chain().tween_callback(func() -> void: l.visible = false)


func _particles(at: Vector3, color: Color, amount: int, spd: float, size: float, life: float, gravity: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
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
	p.material_override = Models.material(color, 1.5 if color.v > 0.8 else 0.0)
	add_child(p)
	p.global_position = at
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)


func _sparks(at: Vector3, color: Color, amount: int) -> void:
	_particles(at, color, amount, 5.0, 0.12, 0.35, 12.0)


func _dust(at: Vector3, color: Color, amount: int) -> void:
	_particles(at + Vector3(0, 0.3, 0), color, amount, 3.0, 0.6, 0.8, 2.0)


func _ring(at: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	ring.mesh = tm
	var m := Models.material(Color(color, 0.85), 3.0, true)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(at.x, 0.1, at.z)
	ring.scale = Vector3(0.3, 0.05, 0.3)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
