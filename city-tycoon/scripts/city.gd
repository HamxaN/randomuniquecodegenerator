class_name City
extends Node3D
## The city in 3D: auto-joining roads, homes, shops, factories and offices
## that grow taller as they level up, parks and plazas, cars driving the
## streets, and a day-night cycle with lit-up buildings and streetlights.

var state: CityState
var rig: CameraRig
var hud: CityHud
var tool := ""           # "" (inspect), a zone type, or "bulldoze"
var selected := Vector2i(-1, -1)

var _tiles := {}         # cell index -> Node3D
var _cars: Array[Dictionary] = []
var _sun: DirectionalLight3D
var _env: Environment
var _cursor: MeshInstance3D
var _lamps: Array[OmniLight3D] = []
var _windows: StandardMaterial3D
var _time := 0.3         # time of day 0..1 (0.25 sunrise, 0.75 sunset)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	state = Save.city
	_rng.randomize()
	_environment()
	_ground()
	for i in state.tiles.size():
		_draw_tile(state.cell(i))
	state.tile_changed.connect(_on_tile_changed)
	rig = CameraRig.new()
	add_child(rig)
	rig.focus = Vector3(0, 0, 1.0)
	rig.distance = 24.0
	rig.tapped.connect(_on_tap)
	_cursor = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GameData.CELL * 0.96, GameData.CELL * 0.96)
	_cursor.mesh = pm
	_cursor.material_override = Models.material(Color(1, 1, 1, 0.35), 0.5, true)
	_cursor.visible = false
	add_child(_cursor)
	hud = CityHud.new()
	hud.city = self
	add_child(hud)


static func to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x - (GameData.COLS - 1) / 2.0) * GameData.CELL, 0.0, (c.y - (GameData.ROWS - 1) / 2.0) * GameData.CELL)


static func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x / GameData.CELL + (GameData.COLS - 1) / 2.0)), int(round(p.z / GameData.CELL + (GameData.ROWS - 1) / 2.0)))


# ---------------------------------------------------------------- world

func _environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.6, 0.95)
	sm.sky_horizon_color = Color(0.8, 0.9, 1.0)
	sky.sky_material = sm
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.8, 0.85, 0.95)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.8, 0.88, 1.0)
	_env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)
	_windows = Models.material(Color(1.0, 0.85, 0.5), 0.0)
	_apply_time()


func _ground() -> void:
	var grass := Models.box(Vector3(GameData.COLS * GameData.CELL + 40, 0.2, GameData.ROWS * GameData.CELL + 40), Color(0.42, 0.66, 0.32))
	grass.position.y = -0.11
	add_child(grass)
	# Countryside around the city limits.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 70:
		var p := Vector3(rng.randf_range(-36, 36), 0, rng.randf_range(-30, 30))
		if absf(p.x) < GameData.COLS + 1.5 and absf(p.z) < GameData.ROWS + 1.5:
			continue
		var t := Models.kenney("grass-trees-tall" if i % 3 else "grass-trees")
		t.position = p
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(2.0, 3.0)
		add_child(t)
	# The city limits: a faint border.
	var border := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(GameData.COLS * GameData.CELL + 0.6, GameData.ROWS * GameData.CELL + 0.6)
	border.mesh = bm
	border.material_override = Models.material(Color(0.5, 0.72, 0.4))
	border.position.y = 0.0
	add_child(border)


func _on_tile_changed(c: Vector2i) -> void:
	_draw_tile(c)
	if hud != null and c == selected:
		hud.show_tile(c)


func _draw_tile(c: Vector2i) -> void:
	var i := state.idx(c)
	if _tiles.has(i):
		(_tiles[i] as Node3D).queue_free()
		_tiles.erase(i)
	var t := state.at(c)
	var type := str(t["type"])
	if type == "":
		return
	var root := Node3D.new()
	root.position = to_world(c)
	add_child(root)
	_tiles[i] = root
	var lv := int(t["level"])
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + lv
	match type:
		"road":
			var piece := GameData.road_piece(state.road_mask(c))
			var r := Models.city(piece[0])
			r.rotation.y = int(piece[1]) * PI / 2
			root.add_child(r)
		"park":
			root.add_child(Models.city("base"))
			var trees := Models.kenney("grass-trees-tall")
			trees.scale = Vector3.ONE * 2.0
			trees.position.y = 0.1
			root.add_child(trees)
			var bench := Models.city("bench")
			bench.position = Vector3(0.5, 0.1, 0.7)
			bench.scale = Vector3.ONE * 2.0
			root.add_child(bench)
		"plaza":
			var fountain := Models.kenney("pavement-fountain")
			fountain.scale = Vector3.ONE * 2.0
			root.add_child(fountain)
			var lamp := Models.city("streetlight")
			lamp.position = Vector3(-0.8, 0.1, -0.8)
			lamp.scale = Vector3.ONE * 1.6
			root.add_child(lamp)
			_add_lamp(root.position + Vector3(0, 2.0, 0))
		"ind":
			root.add_child(Models.city("base"))
			var shed := Models.kenney("building-garage")
			shed.scale = Vector3(2.0, 2.0 + lv * 0.4, 2.0) * 0.9
			shed.position.y = 0.1
			root.add_child(shed)
			for k in lv:
				var tower := Models.city("watertower")
				tower.position = Vector3(-0.6 + k * 0.6, 0.1 + shed.scale.y * 0.55, 0.55)
				tower.scale = Vector3.ONE * 1.3
				root.add_child(tower)
			if lv >= 2:
				var dump := Models.city("dumpster")
				dump.position = Vector3(0.6, 0.1, -0.75)
				dump.scale = Vector3.ONE * 1.4
				root.add_child(dump)
		_:
			var z := GameData.zone(type)
			var model: String = z["models"][clampi(lv, 1, 3) - 1]
			var b := Models.city(model)
			if type == "office":
				var heights := [1.0, 1.3, 2.0]
				var hs: float = heights[clampi(lv, 1, 3) - 1]
				b.scale = Vector3(1.0, hs, 1.0)
			root.add_child(b)
			# Little touches: a bush, a hydrant, the odd bin.
			if rng.randf() < 0.6:
				var bush := Models.city("bush")
				bush.position = Vector3(rng.randf_range(-0.8, 0.8), 0.1, 0.85)
				bush.scale = Vector3.ONE * 1.6
				root.add_child(bush)
			if type == "com" and rng.randf() < 0.5:
				var h := Models.city("firehydrant")
				h.position = Vector3(0.8, 0.1, 0.85)
				h.scale = Vector3.ONE * 1.6
				root.add_child(h)
			for m in b.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_overlay = _windows
	if GameData.is_lot(type):
		# Face the building towards a road if there is one.
		var mask := state.road_mask(c)
		var face := 0
		for k in 4:
			if mask & (1 << k):
				face = k
				break
		var turns := [PI, PI / 2, 0.0, -PI / 2]
		var turn: float = turns[face]
		for ch in root.get_children():
			(ch as Node3D).rotation.y = turn
		if not state.connected(c):
			var sign_m := Models.box(Vector3(0.6, 0.6, 0.06), Color("e6463a"))
			sign_m.material_override = Models.material(Color("e6463a"), 1.5)
			sign_m.position = Vector3(0, 3.6, 0)
			sign_m.name = "NoRoad"
			root.add_child(sign_m)
		# Pop when it appears or levels up.
		root.scale = Vector3(1, 0.3, 1)
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_lamp(at: Vector3) -> void:
	if _lamps.size() >= 10:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.omni_range = 6.0
	l.light_energy = 0.0
	l.position = at
	add_child(l)
	_lamps.append(l)


# ---------------------------------------------------------------- the loop

func _process(delta: float) -> void:
	state.tick(delta)
	_time = fmod(_time + delta / 150.0, 1.0)
	_apply_time()
	_drive(delta)
	# Unconnected lots get their red sign removed once a road arrives.
	for i in _tiles:
		var root: Node3D = _tiles[i]
		var sign_m := root.get_node_or_null("NoRoad")
		if sign_m != null and state.connected(state.cell(int(i))):
			_draw_tile(state.cell(int(i)))
			break


func set_time(t: float) -> void:
	_time = t
	_apply_time()


func night() -> float:
	# 0 by day, 1 in the middle of the night.
	var d := absf(_time - 0.5) * 2.0
	return clampf((d - 0.55) / 0.3, 0.0, 1.0)


func _apply_time() -> void:
	var n := night()
	var sun_angle := (_time - 0.25) * TAU
	_sun.rotation = Vector3(-maxf(sin(sun_angle), 0.15) * 1.0 - 0.25, 0.6, 0)
	_sun.light_energy = lerpf(1.05, 0.15, n)
	_sun.light_color = Color(1.0, 0.92, 0.8).lerp(Color(0.5, 0.6, 1.0), n)
	_env.ambient_light_energy = lerpf(0.55, 0.25, n)
	_env.ambient_light_color = Color(0.8, 0.85, 0.95).lerp(Color(0.35, 0.4, 0.7), n)
	var sm := _env.sky.sky_material as ProceduralSkyMaterial
	sm.sky_top_color = Color(0.35, 0.6, 0.95).lerp(Color(0.04, 0.05, 0.15), n)
	sm.sky_horizon_color = Color(0.8, 0.9, 1.0).lerp(Color(0.25, 0.2, 0.4), n)
	_env.fog_light_color = Color(0.8, 0.88, 1.0).lerp(Color(0.12, 0.12, 0.25), n)
	_windows.albedo_color = Color(1, 1, 1, 0.0)
	_windows.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_windows.emission_enabled = n > 0.01
	_windows.emission = Color(1.0, 0.8, 0.45)
	_windows.emission_energy_multiplier = n * 0.6
	for l in _lamps:
		l.light_energy = n * 2.0
	for car in _cars:
		(car["light"] as OmniLight3D).light_energy = n * 1.2


func _drive(delta: float) -> void:
	var roads: Array[Vector2i] = []
	for i in state.tiles.size():
		if state.tiles[i]["type"] == "road":
			roads.append(state.cell(i))
	var want := mini(roads.size() / 2, 4 + state.population() / 40)
	want = mini(want, 22)
	while _cars.size() < want and not roads.is_empty():
		_spawn_car(roads[_rng.randi() % roads.size()])
	while _cars.size() > want:
		var dead: Dictionary = _cars.pop_back()
		(dead["node"] as Node3D).queue_free()
	for car in _cars:
		var node: Node3D = car["node"]
		var to: Vector2i = car["to"]
		if state.type_at(to) != "road":
			car["to"] = car["from"]
			to = car["from"]
		var from: Vector2i = car["from"]
		var dir := Vector3(to.x - from.x, 0, to.y - from.y)
		var lane := Vector3(-dir.z, 0, dir.x) * -0.45
		var target := to_world(to) + lane + Vector3(0, 0.1, 0)
		var step := float(car["speed"]) * delta
		var d := target - node.position
		if d.length() <= step:
			node.position = target
			car["from"] = to
			car["to"] = _next_road(to, from)
		else:
			node.position += d.normalized() * step
			node.rotation.y = lerp_angle(node.rotation.y, atan2(d.x, d.z), clampf(delta * 10.0, 0, 1))


func _next_road(at: Vector2i, came: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for d in CityState.DIRS:
		var n: Vector2i = at + d
		if state.type_at(n) == "road" and n != came:
			options.append(n)
	if options.is_empty():
		return came if state.type_at(came) == "road" else at
	return options[_rng.randi() % options.size()]


func _spawn_car(c: Vector2i) -> void:
	var models := ["car_sedan", "car_hatchback", "car_taxi", "car_stationwagon", "car_sedan", "car_police"]
	var model: String = models[_rng.randi() % models.size()]
	var node := Models.city(model)
	node.scale = Vector3.ONE * 1.6
	node.position = to_world(c) + Vector3(0, 0.1, 0)
	add_child(node)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.omni_range = 2.5
	light.light_energy = 0.0
	light.position = Vector3(0, 0.6, 0.8)
	node.add_child(light)
	_cars.append({"node": node, "from": c, "to": _next_road(c, c), "speed": _rng.randf_range(2.6, 3.8), "light": light})


# ---------------------------------------------------------------- input

func _on_tap(_screen: Vector2, ground: Vector3) -> void:
	var c := to_cell(ground)
	if not state.in_bounds(c):
		return
	apply_tool(c)


## Uses the current tool on [param c] (also used by the play-test).
func apply_tool(c: Vector2i) -> bool:
	_cursor.visible = true
	_cursor.position = to_world(c) + Vector3(0, 0.14, 0)
	if tool == "":
		selected = c
		hud.show_tile(c)
		Sfx.play("click")
		return true
	if tool == "bulldoze":
		if state.bulldoze(c):
			Sfx.play("bulldoze")
			_dust(to_world(c))
			return true
		hud.toast("Nothing to bulldoze" if state.type_at(c) == "" else "Not enough money")
		Sfx.play("error")
		return false
	var err := state.build_error(tool, c)
	if err != "":
		hud.toast(err)
		Sfx.play("error")
		return false
	state.build(tool, c)
	Sfx.play("road" if tool == "road" else "build")
	_dust(to_world(c))
	return true


func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 80.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.4
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	bm.radial_segments = 6
	bm.rings = 3
	p.mesh = bm
	p.material_override = Models.material(Color(0.85, 0.8, 0.7, 0.8))
	p.position = at + Vector3(0, 0.3, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)
