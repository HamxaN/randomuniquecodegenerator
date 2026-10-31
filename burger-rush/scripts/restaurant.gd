class_name Restaurant
extends Node3D
## One day at the restaurant. Customers walk in and order at the counter; you
## tap the crates, grill, fryer, drinks machine and plates, and the chef runs
## between them doing each job in turn. In menu mode it is just a cosy
## backdrop with the chef idling and a few diners.

signal finished(result: Dictionary)

const BACK_Z := -4.75
const BACK_SPOT_Z := -3.2
const FRONT_Z := -1.0
const FRONT_SPOT_Z := -2.25
const TOP := 1.0
const SPOTS_X := [-4.2, -1.4, 1.4, 4.2]
const SPOT_Z := 0.8
const DOOR := Vector3(9.5, 0, 4.0)
const DOOR_IN := Vector3(6.6, 0, 3.4)
const AISLE_Z := 2.2
const PLATE_X := [-3.0, -1.0, 1.0]
const CUP_X := [4.4, 5.4]
const GRILL_X := -3.0
const FRYER_X := -5.0
const MAX_TASKS := 6
const PATTY_LOOK := {"cooking": "food_ingredient_burger_uncooked", "ready": "food_ingredient_burger_cooked",
	"burnt": "food_ingredient_burger_trash"}

var day := 1
var menu_mode := false
var autopilot := false
var plan: Dictionary
var loc: Dictionary
var kitchen := KitchenState.new()
var camera: Camera3D
var chef: Person
var hud: ShiftHud
var state := "open"   # open, done
var clock := 0.0
var spawned := 0
var coins := 0
var served := 0
var lost := 0
var combo := 0
var tasks: Array[String] = []
var customers: Array[Dictionary] = []
var spots: Array = [null, null, null, null]
var seats: Array[Dictionary] = []
var tutorial_step := -1
var patience_scale := 1.0

var _stations := {}       # id -> {"pos": Vector3 (tap point), "spot": Vector3 (chef stands here)}
var _plate_nodes: Array[Node3D] = []
var _grill_nodes: Array[Node3D] = []
var _cup_nodes: Array[Node3D] = []
var _fries_node: Node3D
var _fry_oil: MeshInstance3D
var _busy := 0.0
var _cam_t := 0.0
var _end_t := -1.0
var _rng := RandomNumberGenerator.new()
var _sizzle_t := 0.0


func _ready() -> void:
	plan = GameData.day_plan(day)
	loc = GameData.location(day)
	_rng.seed = day * 31 + 7
	var grill_slots := 2 + Save.level("grill") if not menu_mode else 2
	kitchen.setup(2 + Save.level("plates"), grill_slots, 2)
	kitchen.cook_time = GameData.cook_time(Save.level("heat"))
	kitchen.batch = GameData.FRIES_PER_BATCH + Save.level("fryer")
	kitchen.changed.connect(_refresh)
	patience_scale = GameData.patience_mult(Save.level("decor"))
	_environment()
	_room()
	_kitchen()
	_dining()
	chef = Person.new()
	add_child(chef)
	chef.setup(GameData.chef(Save.chef)["model"], 1.0)
	chef.speed = GameData.chef_speed(Save.level("shoes"))
	chef.walk_anim = "Running_A" if not menu_mode else "Walking_A"
	chef.position = Vector3(0, 0, -2.8)
	chef.face(Vector3(0, 0, 1))
	camera = Camera3D.new()
	camera.fov = 44.0
	add_child(camera)
	camera.current = true
	_place_camera(0.0)
	_refresh()
	if menu_mode:
		_menu_diners()
		return
	hud = ShiftHud.new()
	hud.restaurant = self
	add_child(hud)
	if day == 1:
		tutorial_step = 0
	Sfx.play("ding")


func _place_camera(t: float) -> void:
	if menu_mode:
		camera.position = Vector3(sin(t * 0.12) * 3.0, 7.5, 9.0)
		camera.look_at(Vector3(0, 1.2, -1.5), Vector3.UP)
	else:
		camera.position = Vector3(0, 11.0, 8.6)
		camera.look_at(Vector3(0, 0.4, -1.1), Vector3.UP)


# ---------------------------------------------------------------- building

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = loc["outside"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.86)
	env.ambient_light_energy = loc["ambient"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = loc["sun"]
	sun.light_energy = loc["energy"]
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# Pendant lamps over the counter.
	for x in [-4.0, 0.0, 4.0]:
		var cord := Models.cylinder(0.02, 1.4, Color(0.15, 0.15, 0.15))
		cord.position = Vector3(x, 4.3, -1.4)
		add_child(cord)
		var shade := Models.cylinder(0.42, 0.34, Color("e6463a"), 0.12)
		shade.position = Vector3(x, 3.45, -1.4)
		add_child(shade)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		bulb.mesh = sm
		bulb.material_override = Models.material(loc["lamp"], 3.0)
		bulb.position = Vector3(x, 3.25, -1.4)
		add_child(bulb)
		var lamp := OmniLight3D.new()
		lamp.light_color = loc["lamp"]
		lamp.light_energy = 0.7 if loc["energy"] > 0.8 else 1.4
		lamp.omni_range = 6.5
		lamp.position = Vector3(x, 3.0, -1.4)
		add_child(lamp)


func _room() -> void:
	# Kitchen tiles at the back, a checkered diner floor in front.
	for x in [-6.0, -2.0, 2.0, 6.0]:
		for z in [-4.0, 0.0]:
			var tile := Models.kitchen("floor_kitchen")
			add_child(tile)
			tile.position = Vector3(x, -0.5, z)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 6.2)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _checker(loc["floor_a"], loc["floor_b"])
	fm.uv1_scale = Vector3(8, 3.1, 1)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	fm.roughness = 0.6
	floor_mi.material_override = fm
	floor_mi.position = Vector3(0, 0.01, 3.1)
	add_child(floor_mi)
	var street := Models.box(Vector3(80, 0.1, 60), (loc["outside"] as Color).darkened(0.45))
	street.position = Vector3(0, -0.1, 10)
	add_child(street)
	# Walls: back, left and right (the camera looks in from the front).
	var back := ["wall", "wall_decorated", "wall", "wall_window_open"]
	for i in 4:
		var w := Models.kitchen(back[i])
		add_child(w)
		w.position = Vector3(-6.0 + i * 4.0, 0, -6.0)
	var left := ["wall", "wall_window_open", "wall"]
	var right := ["wall", "wall_window_open", "wall_doorway"]
	for i in 3:
		var l := Models.kitchen(left[i])
		add_child(l)
		l.position = Vector3(-8.0, 0, -4.0 + i * 4.0)
		l.rotation.y = PI / 2
		var r := Models.kitchen(right[i])
		add_child(r)
		r.position = Vector3(8.0, 0, -4.0 + i * 4.0)
		r.rotation.y = -PI / 2
	for p in [Vector3(-8, 0, 6), Vector3(8, 0, 6)]:
		var pillar := Models.kitchen("pillar_A")
		add_child(pillar)
		pillar.position = p
	# A striped awning sign over the back wall.
	var sign_board := Models.box(Vector3(4.6, 0.9, 0.12), Color("e6463a"))
	sign_board.position = Vector3(2.4, 3.35, -5.7)
	add_child(sign_board)
	var title := Label3D.new()
	title.text = "BURGER RUSH"
	title.font = UI.font()
	title.font_size = 96
	title.outline_size = 18
	title.outline_modulate = Color(0.25, 0.08, 0.02)
	title.modulate = Color("ffd23a")
	title.pixel_size = 0.0062
	title.position = Vector3(2.4, 3.36, -5.62)
	add_child(title)


func _checker(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(16, 16, true, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, a if ((x / 8) + (y / 8)) % 2 == 0 else b)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _station(id: String, pos: Vector3, spot: Vector3) -> void:
	_stations[id] = {"pos": pos, "spot": spot}


func _kitchen() -> void:
	# Back counter, left to right: fridge, patties, grill, prep, buns, cheese, lettuce, tomatoes.
	var crates := {-5.0: ["crate_steak", "patty"], 1.0: ["crate_buns", "bun"], 3.0: ["crate_cheese", "cheese"],
		5.0: ["crate_lettuce", "lettuce"], 7.0: ["crate_tomatoes", "tomato"]}
	for x in [-7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0]:
		if x == -7.0:
			var fridge := Models.kitchen("fridge_A")
			add_child(fridge)
			fridge.position = Vector3(x, 0, BACK_Z)
			continue
		var counter := Models.kitchen("kitchencounter_straight_A" if x != -1.0 else "kitchencounter_sink_backsplash")
		add_child(counter)
		counter.position = Vector3(x, 0, BACK_Z)
		if crates.has(x):
			var c: Array = crates[x]
			var item: String = c[1]
			var crate := Models.kitchen(c[0])
			add_child(crate)
			crate.position = Vector3(x, TOP, BACK_Z + 0.2)
			crate.scale = Vector3.ONE * 0.62
			if menu_mode or GameData.unlocked(item, day):
				_station(item, Vector3(x, TOP + 0.6, BACK_Z + 0.2), Vector3(x, 0, BACK_SPOT_Z))
				_sign(Vector3(x, TOP + 0.05, BACK_Z + 0.95), item)
			else:
				crate.visible = false
				var lock := Label3D.new()
				lock.text = "Day %d" % int(GameData.UNLOCKS[item])
				lock.font = UI.font()
				lock.font_size = 48
				lock.outline_size = 10
				lock.pixel_size = 0.006
				lock.modulate = Color(1, 1, 1, 0.8)
				lock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lock.position = Vector3(x, TOP + 0.5, BACK_Z + 0.2)
				add_child(lock)
	# The grill.
	var stove := Models.kitchen("stove_multi_countertop")
	add_child(stove)
	stove.position = Vector3(GRILL_X, 0, BACK_Z)
	var hood := Models.kitchen("extractorhood")
	add_child(hood)
	hood.position = Vector3(GRILL_X, 0, -5.75)
	var burners := [Vector3(-0.42, 0, 0.38), Vector3(0.42, 0, 0.38), Vector3(-0.42, 0, -0.38), Vector3(0.42, 0, -0.38)]
	for i in kitchen.grill.size():
		var anchor := Node3D.new()
		add_child(anchor)
		anchor.position = Vector3(GRILL_X, 1.21, BACK_Z) + burners[i]
		_grill_nodes.append(anchor)
		_station("grill%d" % i, anchor.position + Vector3(0, 0.25, 0), Vector3(GRILL_X + burners[i].x * 0.6, 0, BACK_SPOT_Z))
	# Front counter (the pass) with plates, fryer and drinks.
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		var counter := Models.kitchen("kitchencounter_straight_B")
		add_child(counter)
		counter.position = Vector3(x, 0, FRONT_Z)
		counter.rotation.y = PI
	for i in kitchen.plates.size():
		var plate := Models.kitchen("plate")
		add_child(plate)
		plate.position = Vector3(PLATE_X[i], TOP, FRONT_Z)
		plate.scale = Vector3.ONE * 1.1
		var anchor := Node3D.new()
		add_child(anchor)
		anchor.position = plate.position + Vector3(0, 0.08, 0)
		_plate_nodes.append(anchor)
		_station("plate%d" % i, anchor.position + Vector3(0, 0.4, 0), Vector3(PLATE_X[i], 0, FRONT_SPOT_Z))
	if menu_mode or GameData.unlocked("fries", day):
		var fryer := Models.kitchen("stove_single_countertop")
		add_child(fryer)
		fryer.position = Vector3(FRYER_X, 0, FRONT_Z)
		var pot := Models.kitchen("pot_A")
		add_child(pot)
		pot.position = Vector3(FRYER_X - 0.25, 1.2, FRONT_Z - 0.2)
		_fry_oil = Models.cylinder(0.42, 0.04, Color(0.95, 0.75, 0.25))
		_fry_oil.position = pot.position + Vector3(0, 0.42, 0)
		add_child(_fry_oil)
		_fries_node = Models.kitchen("food_ingredient_potato_chopped")
		add_child(_fries_node)
		_fries_node.position = Vector3(FRYER_X + 0.45, TOP + 0.02, FRONT_Z + 0.3)
		_fries_node.scale = Vector3.ONE * 0.7
		_station("fryer", Vector3(FRYER_X, TOP + 0.6, FRONT_Z), Vector3(FRYER_X, 0, FRONT_SPOT_Z))
		_sign(Vector3(FRYER_X, TOP + 0.05, FRONT_Z + 0.95), "fries")
	if menu_mode or GameData.unlocked("drink", day):
		var tank := Models.cylinder(0.32, 0.9, Color(0.75, 0.88, 1.0, 0.75))
		tank.position = Vector3(4.9, TOP + 0.75, FRONT_Z - 0.55)
		add_child(tank)
		var machine := Models.box(Vector3(1.6, 0.3, 0.7), Color("e6463a"))
		machine.position = Vector3(4.9, TOP + 1.25, FRONT_Z - 0.4)
		add_child(machine)
		for i in kitchen.cups.size():
			var cup := Node3D.new()
			add_child(cup)
			cup.position = Vector3(CUP_X[i], TOP, FRONT_Z + 0.1)
			var glass := Models.cylinder(0.16, 0.45, Color(1, 1, 1), 0.2)
			glass.position.y = 0.225
			glass.name = "Glass"
			cup.add_child(glass)
			var soda := Models.cylinder(0.15, 0.4, Color(0.55, 0.22, 0.12), 0.19)
			soda.position.y = 0.21
			soda.name = "Soda"
			cup.add_child(soda)
			var lid := Models.cylinder(0.21, 0.05, Color("e6463a"))
			lid.position.y = 0.47
			lid.name = "Lid"
			cup.add_child(lid)
			_cup_nodes.append(cup)
			_station("cup%d" % i, cup.position + Vector3(0, 0.5, 0), Vector3(CUP_X[i], 0, FRONT_SPOT_Z))
		_sign(Vector3(4.9, TOP + 0.05, FRONT_Z + 0.95), "drink")
	for x in [3.0]:
		var menu_board := Models.kitchen("menu")
		add_child(menu_board)
		menu_board.position = Vector3(x - 0.3, TOP, FRONT_Z)
		var ketchup := Models.kitchen("ketchup")
		add_child(ketchup)
		ketchup.position = Vector3(x + 0.3, TOP, FRONT_Z + 0.1)
		var mustard := Models.kitchen("mustard")
		add_child(mustard)
		mustard.position = Vector3(x + 0.62, TOP, FRONT_Z - 0.05)
	# Bin.
	var bin := Models.cylinder(0.42, 1.0, Color(0.35, 0.4, 0.45), 0.46)
	bin.position = Vector3(-7.0, 0.5, -2.6)
	add_child(bin)
	var bin_lid := Models.cylinder(0.5, 0.08, Color(0.25, 0.3, 0.34))
	bin_lid.position = Vector3(-7.0, 1.04, -2.6)
	add_child(bin_lid)
	_station("trash", Vector3(-7.0, 1.3, -2.6), Vector3(-6.3, 0, -2.6))


## A little coloured tag on the counter front showing what a station gives.
func _sign(at: Vector3, kind: String) -> void:
	var colors := {"patty": Color("7a3d1e"), "bun": Color("e8932e"), "cheese": Color("f2c21a"),
		"lettuce": Color("4fa83a"), "tomato": Color("d83a2e"), "fries": Color("e6463a"), "drink": Color("3f9de0")}
	var board := Models.box(Vector3(1.2, 0.34, 0.05), colors.get(kind, Color.WHITE))
	board.position = at + Vector3(0, -0.28, 0)
	add_child(board)
	var l := Label3D.new()
	l.text = kind.to_upper() if kind != "patty" else "PATTIES"
	l.font = UI.font()
	l.font_size = 44
	l.outline_size = 8
	l.pixel_size = 0.0055
	l.position = at + Vector3(0, -0.28, 0.04)
	add_child(l)


func _dining() -> void:
	for x in [-5.0, -1.5, 2.0]:
		var table := Models.kitchen("table_round_A_small")
		add_child(table)
		table.position = Vector3(x, 0, 3.9)
		for side in [-1.0, 1.0]:
			var chair := Models.kitchen("chair_A")
			add_child(chair)
			chair.position = Vector3(x + side * 1.05, 0, 3.9)
			chair.rotation.y = -side * PI / 2
			seats.append({"pos": chair.position, "table": Vector3(x, 0, 3.9), "taken": false})
	var plant_pot := Models.cylinder(0.35, 0.6, Color(0.75, 0.4, 0.25), 0.4)
	plant_pot.position = Vector3(-7.2, 0.3, 1.2)
	add_child(plant_pot)


func _menu_diners() -> void:
	var models := GameData.ADVENTURERS.duplicate()
	for i in [0, 3, 4]:
		var s: Dictionary = seats[i]
		s["taken"] = true
		var p := Person.new()
		add_child(p)
		p.setup(models[i % models.size()])
		p.position = s["pos"] + Vector3(0, 0.12, 0)
		p.face(s["table"] - s["pos"])
		p.play("Sit_Chair_Idle")
		var food := Models.burger(["bun", "patty", "cheese", "lettuce"], 0.5)
		add_child(food)
		food.position = (s["table"] as Vector3).lerp(s["pos"], 0.3) + Vector3(0, 1.0, 0)
	kitchen.start_patty()
	kitchen.add_bun()
	kitchen.add_topping("cheese")


# ---------------------------------------------------------------- visuals

func _refresh() -> void:
	for i in _plate_nodes.size():
		var anchor := _plate_nodes[i]
		for c in anchor.get_children():
			c.queue_free()
		var items: Array = kitchen.plates[i]
		if not items.is_empty():
			anchor.add_child(Models.burger(items, 1.1))
	for i in _grill_nodes.size():
		var anchor := _grill_nodes[i]
		for c in anchor.get_children():
			c.queue_free()
		var st: String = kitchen.grill[i]["state"]
		if st != "empty":
			var p := Models.kitchen(PATTY_LOOK[st])
			p.scale = Vector3.ONE * 0.9
			anchor.add_child(p)
	if _fries_node != null:
		_fries_node.visible = kitchen.fryer_state == "ready"
		_fry_oil.material_override = Models.material(Color(0.95, 0.75, 0.25), 1.2 if kitchen.fryer_state == "frying" else 0.0)
	for i in _cup_nodes.size():
		var st: String = kitchen.cups[i]["state"]
		var cup := _cup_nodes[i]
		cup.visible = st != "empty"
		cup.get_node("Lid").visible = st == "ready"


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if menu_mode or state != "open" or get_tree().paused:
		return
	var pos := Vector2.ZERO
	# Mouse clicks arrive as touches too (pointing/emulate_touch_from_mouse).
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	else:
		return
	var id := pick(pos)
	if id != "":
		tap(id)
		get_viewport().set_input_as_handled()


func screen_pos(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


## The station or customer nearest a screen point, as a station id ("" if none).
func pick(pos: Vector2) -> String:
	var best := ""
	var best_d := 80.0 * get_viewport().get_visible_rect().size.y / 720.0
	for id in _stations:
		var d := screen_pos(_stations[id]["pos"]).distance_to(pos)
		if d < best_d:
			best_d = d
			best = id
	for c in customers:
		if c["state"] != "wait":
			continue
		var p: Person = c["person"]
		var d := screen_pos(p.position + Vector3(0, 1.2, 0)).distance_to(pos)
		if d < best_d:
			best_d = d
			best = _station_for_customer(c)
	return best


## What tapping a waiting customer means: hand over whatever is ready for them.
func _station_for_customer(c: Dictionary) -> String:
	var got: Dictionary = c["got"]
	var order: Dictionary = c["order"]
	if not got["burger"]:
		for i in kitchen.plates.size():
			if GameData.burger_matches(kitchen.plates[i], order["burger"]):
				return "plate%d" % i
	if order["fries"] and not got["fries"] and kitchen.fryer_state == "ready":
		return "fryer"
	if order["drink"] and not got["drink"]:
		for i in kitchen.cups.size():
			if kitchen.cups[i]["state"] == "ready":
				return "cup%d" % i
	return ""


func tap(id: String) -> void:
	if not _stations.has(id):
		return
	if tasks.size() >= MAX_TASKS:
		toast("The chef is busy!")
		Sfx.play("error")
		return
	tasks.append(id)
	Sfx.play("click", 1.2, -4.0)
	if hud != null:
		hud.tapped(screen_pos(_stations[id]["pos"]))


# ---------------------------------------------------------------- the day

func _process(delta: float) -> void:
	_cam_t += delta
	if menu_mode:
		_place_camera(_cam_t)
		kitchen.tick(delta * 0.3)
		if kitchen.grill[0]["state"] == "burnt" or kitchen.grill[0]["state"] == "ready":
			kitchen.grill[0] = {"state": "cooking", "t": 0.0}
		return
	kitchen.tick(delta)
	_sizzle_t -= delta
	var cooking := false
	for s in kitchen.grill:
		if s["state"] == "cooking":
			cooking = true
	if cooking and _sizzle_t <= 0.0:
		_sizzle_t = 0.65
		Sfx.play("sizzle", 1.0, -8.0)
	if state == "open":
		clock += delta
		_spawn()
		_update_customers(delta)
		if autopilot and tasks.is_empty() and _busy <= 0.0 and not chef.moving:
			var t := _auto_task()
			if t != "":
				tasks.append(t)
		_run_chef(delta)
		_tutorial()
		if spawned >= plan["orders"].size() and _waiting_count() == 0:
			state = "done"
			_end_t = 1.6
	else:
		_update_customers(delta)
		if _end_t > 0.0:
			_end_t -= delta
			if _end_t <= 0.0:
				_finish()
	_update_hud()


func _waiting_count() -> int:
	var n := 0
	for c in customers:
		if c["state"] == "enter" or c["state"] == "wait":
			n += 1
	return n


func _spawn() -> void:
	var times: Array = plan["times"]
	if spawned >= times.size() or clock < float(times[spawned]):
		return
	var spot := -1
	var free: Array[int] = []
	for i in spots.size():
		if spots[i] == null:
			free.append(i)
	if free.is_empty():
		return
	spot = free[_rng.randi() % free.size()]
	var order: Dictionary = plan["orders"][spawned]
	spawned += 1
	var skeleton := _rng.randf() < float(loc["skeletons"])
	var pool: Array = GameData.SKELETONS if skeleton else GameData.ADVENTURERS
	var model: String = pool[_rng.randi() % pool.size()]
	var p := Person.new()
	add_child(p)
	p.setup(model)
	p.speed = 3.0
	p.position = DOOR
	var target := Vector3(SPOTS_X[spot], 0, SPOT_Z)
	var c := {"person": p, "order": order, "got": {"burger": false, "fries": false, "drink": false},
		"patience": 1.0, "max": float(plan["patience"]) * patience_scale, "state": "enter", "spot": spot,
		"bubble": null, "seat": -1, "t": 0.0}
	spots[spot] = c
	customers.append(c)
	p.walk([DOOR_IN, Vector3(target.x, 0, AISLE_Z), target])
	p.arrived.connect(_on_arrived.bind(c), CONNECT_ONE_SHOT)


func _on_arrived(c: Dictionary) -> void:
	var p: Person = c["person"]
	p.face(Vector3(0, 0, -1))
	c["state"] = "wait"
	if hud != null:
		c["bubble"] = hud.add_bubble(c["order"])
	Sfx.play("ding", 1.0, -6.0)


func _update_customers(delta: float) -> void:
	for c in customers.duplicate():
		var p: Person = c["person"]
		match c["state"]:
			"wait":
				c["patience"] = float(c["patience"]) - delta / float(c["max"])
				var b: OrderBubble = c["bubble"]
				if b != null:
					b.patience = c["patience"]
				if c["patience"] <= 0.0:
					_storm_out(c)
			"eat":
				c["t"] = float(c["t"]) - delta
				if c["t"] <= 0.0:
					_leave(c)
			"gone":
				if not p.moving:
					customers.erase(c)
					p.queue_free()


func _storm_out(c: Dictionary) -> void:
	lost += 1
	combo = 0
	Sfx.play("angry")
	Sfx.vibrate(60)
	var p: Person = c["person"]
	float_text(p.position + Vector3(0, 2.6, 0), "Too slow!", Color("ff6b5a"))
	_free_spot(c)
	c["state"] = "gone"
	p.act("Hit_A")
	p.walk([Vector3(p.position.x, 0, AISLE_Z), DOOR_IN, DOOR])


func _free_spot(c: Dictionary) -> void:
	var b: OrderBubble = c["bubble"]
	if b != null:
		b.queue_free()
		c["bubble"] = null
	if int(c["spot"]) >= 0:
		spots[int(c["spot"])] = null
		c["spot"] = -1


## Hands [param part] to the most impatient customer who still needs it.
## For a burger, [param items] must match their order. Returns the customer or {}.
func _deliver(part: String, items: Array = []) -> Dictionary:
	var best: Dictionary = {}
	for c in customers:
		if c["state"] != "wait" or c["got"][part]:
			continue
		var order: Dictionary = c["order"]
		if part == "burger" and not GameData.burger_matches(items, order["burger"]):
			continue
		if part != "burger" and not order[part]:
			continue
		if best.is_empty() or float(c["patience"]) < float(best["patience"]):
			best = c
	return best


func _give(c: Dictionary, part: String, from: Vector3, items: Array = []) -> void:
	c["got"][part] = true
	var b: OrderBubble = c["bubble"]
	if b != null:
		b.mark(part)
	var p: Person = c["person"]
	# The food flies over the counter to them.
	var node: Node3D
	match part:
		"burger":
			node = Models.burger(items, 0.9)
		"fries":
			node = Models.kitchen("food_ingredient_potato_chopped")
			node.scale = Vector3.ONE * 0.6
		_:
			node = Models.cylinder(0.16, 0.45, Color(0.9, 0.25, 0.2), 0.2)
	add_child(node)
	node.position = from
	var to := p.position + Vector3(0, 1.3, -0.3)
	var tw := node.create_tween()
	tw.tween_property(node, "position", (from + to) / 2 + Vector3(0, 1.0, 0), 0.18)
	tw.tween_property(node, "position", to, 0.18)
	tw.tween_callback(node.queue_free)
	Sfx.play("plop")
	var order: Dictionary = c["order"]
	var done: bool = c["got"]["burger"] and (not order["fries"] or c["got"]["fries"]) and (not order["drink"] or c["got"]["drink"])
	if done:
		_pay(c)


func _pay(c: Dictionary) -> void:
	var price := GameData.order_price(c["order"])
	var tip := GameData.tip(price, c["patience"], Save.level("tips"))
	combo += 1
	var bonus := 0
	if combo >= 3:
		bonus = mini(combo, 8)
	var total := price + tip + bonus
	coins += total
	served += 1
	var p: Person = c["person"]
	var text := "+%d" % total
	if bonus > 0:
		text += "  Combo x%d!" % combo
	float_text(p.position + Vector3(0, 2.6, 0), text, Color("ffd23a"))
	Sfx.play("cash")
	Sfx.play("coin", 1.0, -6.0)
	p.act("Cheer")
	_free_spot(c)
	c["state"] = "leaving"
	if hud != null:
		hud.coin_burst(screen_pos(p.position + Vector3(0, 2.0, 0)))
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void: _go_sit(c))


func _go_sit(c: Dictionary) -> void:
	if not is_instance_valid(c["person"]):
		return
	var p: Person = c["person"]
	var free: Array[int] = []
	for i in seats.size():
		if not seats[i]["taken"]:
			free.append(i)
	if free.is_empty():
		c["state"] = "gone"
		p.walk([Vector3(p.position.x, 0, AISLE_Z), DOOR_IN, DOOR])
		return
	var si: int = free[_rng.randi() % free.size()]
	var seat: Dictionary = seats[si]
	seat["taken"] = true
	c["seat"] = si
	var sp: Vector3 = seat["pos"]
	p.walk([Vector3(p.position.x, 0, AISLE_Z), Vector3(sp.x, 0, AISLE_Z + 0.4), sp + Vector3(0, 0, -0.75), sp])
	p.arrived.connect(_sit_down.bind(c, seat), CONNECT_ONE_SHOT)


func _sit_down(c: Dictionary, seat: Dictionary) -> void:
	var p: Person = c["person"]
	var sp: Vector3 = seat["pos"]
	p.position.y = 0.12
	p.face((seat["table"] as Vector3) - sp)
	p.play("Sit_Chair_Idle")
	var food := Models.burger(c["order"]["burger"], 0.45)
	add_child(food)
	food.position = (seat["table"] as Vector3).lerp(sp, 0.3) + Vector3(0, 1.0, 0)
	c["food"] = food
	c["state"] = "eat"
	c["t"] = _rng.randf_range(5.0, 8.0)


func _leave(c: Dictionary) -> void:
	var p: Person = c["person"]
	if c.has("food") and is_instance_valid(c["food"]):
		(c["food"] as Node3D).queue_free()
	if int(c["seat"]) >= 0:
		seats[int(c["seat"])]["taken"] = false
	p.position.y = 0.0
	c["state"] = "gone"
	var sp: Vector3 = p.position
	p.walk([sp + Vector3(0, 0, -0.75), Vector3(sp.x, 0, AISLE_Z + 0.4), DOOR_IN, DOOR])


# ---------------------------------------------------------------- the chef

func _run_chef(delta: float) -> void:
	if _busy > 0.0:
		_busy -= delta
		return
	if chef.moving or tasks.is_empty():
		return
	var id: String = tasks[0]
	var spot: Vector3 = _stations[id]["spot"]
	if Vector2(chef.position.x - spot.x, chef.position.z - spot.z).length() > 0.08:
		chef.walk([spot])
		return
	tasks.pop_front()
	var look: Vector3 = _stations[id]["pos"] - chef.position
	look.y = 0.0
	chef.face(look)
	chef.act("Interact", 1.6)
	_busy = 0.22
	_do(id)


func _do(id: String) -> void:
	var at: Vector3 = _stations[id]["pos"]
	if id == "patty":
		if kitchen.start_patty() < 0:
			_nope("The grill is full!")
		else:
			Sfx.play("sizzle")
	elif id == "bun":
		if kitchen.add_bun() < 0:
			_nope("No free plate!")
		else:
			Sfx.play("place")
	elif GameData.TOPPINGS.has(id):
		if kitchen.add_topping(id) < 0:
			_nope("Put a bun on a plate first!")
		else:
			Sfx.play("place")
	elif id.begins_with("grill"):
		var slot := int(id.substr(5))
		var st: String = kitchen.grill[slot]["state"]
		var r := kitchen.take_patty(slot)
		if r == -2:
			Sfx.play("trash")
			float_text(at + Vector3(0, 0.6, 0), "Burnt!", Color("ff6b5a"))
		elif r < 0:
			_nope("Still cooking..." if st == "cooking" else ("Put a bun on a plate first!" if st == "ready" else "Nothing on the grill"))
		else:
			Sfx.play("place")
	elif id.begins_with("plate"):
		var i := int(id.substr(5))
		var items: Array = kitchen.plates[i]
		if items.is_empty():
			return
		var c := _deliver("burger", items)
		if c.is_empty():
			_nope("Nobody ordered that burger")
			return
		kitchen.take_plate(i)
		_give(c, "burger", at, items)
	elif id == "fryer":
		if kitchen.fryer_state == "empty":
			kitchen.start_fries()
			Sfx.play("sizzle", 0.8)
		elif kitchen.fryer_state == "ready":
			var c := _deliver("fries")
			if c.is_empty():
				_nope("Nobody wants fries right now")
				return
			kitchen.take_fries()
			_give(c, "fries", at)
	elif id.begins_with("cup"):
		var i := int(id.substr(3))
		var st: String = kitchen.cups[i]["state"]
		if st == "empty":
			kitchen.start_drink(i)
			Sfx.play("plop", 0.7)
		elif st == "ready":
			var c := _deliver("drink")
			if c.is_empty():
				_nope("Nobody wants a drink right now")
				return
			kitchen.take_drink(i)
			_give(c, "drink", at)
	elif id == "trash":
		if kitchen.trash() >= 0:
			Sfx.play("trash")
		else:
			_nope("The plates are empty")


func _nope(text: String) -> void:
	Sfx.play("error")
	toast(text)


func toast(text: String) -> void:
	if hud != null:
		hud.toast(text)


func float_text(at: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font()
	l.font_size = 72
	l.outline_size = 16
	l.outline_modulate = Color(0.15, 0.08, 0.02)
	l.modulate = color
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 1.2, 0), 1.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- helpers for the HUD

## Progress rings over the grill, fryer and drinks: [{pos, frac, color}].
func rings() -> Array:
	var out: Array = []
	for i in kitchen.grill.size():
		var s: Dictionary = kitchen.grill[i]
		if s["state"] == "cooking":
			out.append({"pos": screen_pos(_stations["grill%d" % i]["pos"]), "frac": kitchen.grill_progress(i), "color": Color("ffb02e")})
		elif s["state"] == "ready":
			out.append({"pos": screen_pos(_stations["grill%d" % i]["pos"]), "frac": 1.0 - kitchen.grill_progress(i),
				"color": Color("62c63c") if kitchen.grill_progress(i) < 0.6 else Color("e6463a")})
	if kitchen.fryer_state == "frying" and _stations.has("fryer"):
		out.append({"pos": screen_pos(_stations["fryer"]["pos"]), "frac": kitchen.fryer_t / kitchen.fry_time, "color": Color("ffb02e")})
	for i in kitchen.cups.size():
		if kitchen.cups[i]["state"] == "pouring" and _stations.has("cup%d" % i):
			out.append({"pos": screen_pos(_stations["cup%d" % i]["pos"]), "frac": float(kitchen.cups[i]["t"]) / kitchen.pour_time, "color": Color("3f9de0")})
	return out


## Numbers over the stations the chef is about to visit.
func queue_marks() -> Array:
	var out: Array = []
	for i in tasks.size():
		out.append({"pos": screen_pos(_stations[tasks[i]]["pos"]) + Vector2(0, -34), "n": i + 1})
	return out


func _update_hud() -> void:
	if hud == null:
		return
	for c in customers:
		var b: OrderBubble = c["bubble"]
		if b != null:
			var p: Person = c["person"]
			var sp := screen_pos(p.position + Vector3(0, 2.3, 0))
			b.position = sp - Vector2(b.size.x / 2, b.size.y)
	hud.refresh()


func tutorial_target() -> Vector2:
	var id := ""
	match tutorial_step:
		0:
			id = "patty"
		1:
			id = "bun"
		2:
			var r := kitchen.ready_patty()
			id = "grill%d" % (r if r >= 0 else 0)
		3:
			for i in kitchen.plates.size():
				if (kitchen.plates[i] as Array).has("patty"):
					id = "plate%d" % i
	if id == "" or not _stations.has(id):
		return Vector2(-100, -100)
	return screen_pos(_stations[id]["pos"])


func tutorial_text() -> String:
	match tutorial_step:
		0:
			return "Tap the PATTIES to put one on the grill"
		1:
			return "Tap the BUNS to put a bun on a plate"
		2:
			return "When the patty turns brown, tap it to add it to the burger"
		3:
			return "Tap the finished burger to serve it!"
	return ""


func _tutorial() -> void:
	if tutorial_step < 0:
		return
	var grill_used := false
	for s in kitchen.grill:
		if s["state"] != "empty":
			grill_used = true
	var bun := false
	var patty := false
	for p in kitchen.plates:
		bun = bun or (p as Array).has("bun")
		patty = patty or (p as Array).has("patty")
	match tutorial_step:
		0:
			if grill_used or patty:
				tutorial_step = 1
		1:
			if bun:
				tutorial_step = 2
		2:
			if patty:
				tutorial_step = 3
		3:
			if served > 0:
				tutorial_step = -1


# ---------------------------------------------------------------- autopilot (CI play-test)

func _auto_task() -> String:
	var waiting: Array[Dictionary] = []
	for c in customers:
		if c["state"] == "wait":
			waiting.append(c)
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["patience"]) < float(b["patience"]))
	for c in waiting:
		var s := _station_for_customer(c)
		if s != "":
			return s
	for i in kitchen.grill.size():
		if kitchen.grill[i]["state"] == "burnt":
			return "grill%d" % i
	var r := kitchen.ready_patty()
	if r >= 0 and kitchen.plate_for("patty") >= 0:
		return "grill%d" % r
	# Build the burger the most impatient customer still needs.
	var claimed: Array[int] = []
	for c in waiting:
		if c["got"]["burger"]:
			continue
		var spec: Array = c["order"]["burger"]
		var plate := -1
		for i in kitchen.plates.size():
			if claimed.has(i):
				continue
			var pitems: Array = kitchen.plates[i]
			if pitems.is_empty():
				continue
			var fits := true
			for it in pitems:
				if not spec.has(it):
					fits = false
			if fits:
				plate = i
				break
		if plate < 0:
			for i in kitchen.plates.size():
				if not claimed.has(i) and (kitchen.plates[i] as Array).is_empty():
					claimed.append(i)
					return "bun"
			continue
		claimed.append(plate)
		var items: Array = kitchen.plates[plate]
		for t in GameData.TOPPINGS:
			if spec.has(t) and not items.has(t):
				kitchen.last_plate = plate
				return t
		if not items.has("patty"):
			var on_grill := 0
			for s in kitchen.grill:
				if s["state"] == "cooking" or s["state"] == "ready":
					on_grill += 1
			if on_grill == 0:
				return "patty"
	for c in waiting:
		var order: Dictionary = c["order"]
		if order["fries"] and not c["got"]["fries"] and kitchen.fryer_state == "empty":
			return "fryer"
		if order["drink"] and not c["got"]["drink"]:
			var any_ready := false
			for i in kitchen.cups.size():
				if kitchen.cups[i]["state"] != "empty":
					any_ready = true
			if not any_ready:
				return "cup0"
	return ""


func _finish() -> void:
	var goals: Array = plan["goals"]
	var stars := GameData.stars(coins, goals)
	var result := {"day": day, "coins": coins, "served": served, "lost": lost, "stars": stars, "goals": goals}
	finished.emit(result)
