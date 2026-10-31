class_name Colony
extends Node3D
## The Mars base in 3D: the red plain and cliffs, ore and crystal deposits,
## every building (with scaffolding while it goes up and smoke when it's
## hit), rockets landing with colonists, rovers, meteor showers to blast out
## of the sky and dust storms. Drag to look around, pinch to zoom, tap to build.

const BOUNDS := 12.0

var state: ColonyState
var rig: CameraRig
var hud: ColonyHud
var selected := -1
var placing := ""
var place_cell := Vector2i(-1, -1)
var meteors: Array[Dictionary] = []
var storm_left := 0.0

var _nodes := {}       # building id -> {"root", "model", "scaffold", "smoke", "fan", "drill"}
var _ghost: Node3D
var _marks: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _rovers: Array[Dictionary] = []
var _meteor_t := 40.0
var _storm_t := 150.0
var _shower_left := 0
var _shower_gap := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var events := true


func _ready() -> void:
	state = Save.colony
	_rng.randomize()
	_environment()
	_terrain()
	for b in state.buildings:
		_spawn_building(b)
	state.built.connect(_on_built)
	state.lander.connect(_on_lander)
	rig = CameraRig.new()
	add_child(rig)
	rig.focus = Vector3(0, 0, 1.0)
	rig.distance = 17.0
	rig.tapped.connect(_on_tap)
	_marks = Node3D.new()
	add_child(_marks)
	hud = ColonyHud.new()
	hud.colony = self
	add_child(hud)
	_sync_rovers()


# ---------------------------------------------------------------- world

func _environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.16, 0.1, 0.24)
	sm.sky_horizon_color = Color(0.95, 0.6, 0.45)
	sm.ground_horizon_color = Color(0.85, 0.5, 0.35)
	sm.ground_bottom_color = Color(0.45, 0.22, 0.14)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.85, 0.7, 0.65)
	_env.ambient_light_energy = 0.32
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.82
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.9, 0.55, 0.4)
	_env.fog_density = 0.004
	_env.glow_enabled = true
	_env.glow_intensity = 0.25
	_env.glow_hdr_threshold = 1.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.88, 0.75)
	_sun.light_energy = 0.85
	_sun.rotation_degrees = Vector3(-48, -35, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)


func _terrain() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := Models.material(Color(0.52, 0.25, 0.15))
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.03
	add_child(ground)
	# The buildable plain, one KayKit terrain tile per cell.
	var cells: Array[Vector2i] = []
	for y in GameData.ROWS:
		for x in GameData.COLS:
			cells.append(Vector2i(x, y))
	_tiles("terrain_low", cells, Vector3.ZERO)
	# Cliffs round the back and sides; the front stays open for the landing zone.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in range(-2, GameData.ROWS + 1):
		for x in range(-2, GameData.COLS + 2):
			var inside := x >= 0 and y >= 0 and x < GameData.COLS and y < GameData.ROWS
			if inside or y >= GameData.ROWS:
				continue
			var p := GameData.cell_to_world(Vector2i(x, y))
			var ring := 0 if (x == -1 or x == GameData.COLS or y == -1) else 1
			var piece := "terrain_slope" if ring == 0 and rng.randf() < 0.55 else "terrain_tall"
			var t := Models.base(piece)
			add_child(t)
			t.position = p + Vector3(0, 1.0 * ring, 0)
			t.scale = Vector3.ONE * GameData.CELL / 2.0
			if piece == "terrain_slope":
				# Slopes rise away from the plain.
				if y == -1:
					t.rotation.y = 0.0
				elif x == -1:
					t.rotation.y = PI / 2
				else:
					t.rotation.y = -PI / 2
			if rng.randf() < 0.25:
				var rock := Models.base("rocks_B" if rng.randf() < 0.5 else "rock_B")
				add_child(rock)
				rock.position = t.position + Vector3(rng.randf_range(-0.5, 0.5), 1.0, rng.randf_range(-0.5, 0.5))
	# Far mesas on the horizon.
	for i in 14:
		var a := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var d := rng.randf_range(45.0, 80.0)
		var m := Models.base("terrain_tall_curved" if i % 2 == 0 else "terrain_tall")
		add_child(m)
		m.position = Vector3(cos(a) * d, rng.randf_range(-1.0, 2.0), sin(a) * d)
		m.scale = Vector3(rng.randf_range(4, 9), rng.randf_range(3, 7), rng.randf_range(4, 9))
		m.rotation.y = rng.randf() * TAU
	# Scattered rocks on the plain's edges and in front.
	for i in 30:
		var p := Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(10, 20))
		var r := Models.base(["rock_A", "rock_B", "rocks_A"][rng.randi() % 3])
		add_child(r)
		r.position = p
		r.rotation.y = rng.randf() * TAU
		r.scale = Vector3.ONE * rng.randf_range(0.8, 2.0)
	# Deposits.
	for cell in GameData.ORE_CELLS:
		var p := GameData.cell_to_world(cell)
		var rocks := Models.base("rocks_A")
		rocks.name = "Deposit_%d_%d" % [cell.x, cell.y]
		add_child(rocks)
		rocks.position = p
		for k in 5:
			var nug := Models.box(Vector3(0.22, 0.22, 0.22), Color(1.0, 0.72, 0.2))
			nug.material_override = Models.material(Color(1.0, 0.72, 0.2), 0.8)
			nug.position = Vector3(rng.randf_range(-0.6, 0.6), 0.12, rng.randf_range(-0.6, 0.6))
			nug.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
			rocks.add_child(nug)
	for cell in GameData.CRYSTAL_CELLS:
		var c := Models.crystal_cluster(1.1)
		c.name = "Deposit_%d_%d" % [cell.x, cell.y]
		add_child(c)
		c.position = GameData.cell_to_world(cell)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.4, 0.95, 1.0)
		glow.light_energy = 0.8
		glow.omni_range = 3.0
		glow.position = Vector3(0, 0.8, 0)
		c.add_child(glow)


func _tiles(piece: String, cells: Array[Vector2i], offset: Vector3) -> void:
	var mesh := Models.first_mesh("res://assets/base/%s.gltf" % piece)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cells.size()
	var copy := mesh.duplicate() as Mesh
	for s in copy.get_surface_count():
		var mat := copy.surface_get_material(s)
		if mat is StandardMaterial3D:
			var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.vertex_color_use_as_albedo = true
			copy.surface_set_material(s, m)
	mm.mesh = copy
	for i in cells.size():
		var p := GameData.cell_to_world(cells[i]) + offset
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * GameData.CELL / 2.0), p))
		var v := 0.72 if (cells[i].x + cells[i].y) % 2 == 0 else 0.78
		mm.set_instance_color(i, Color(v, v, v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------- buildings

func _spawn_building(b: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = GameData.cell_to_world(b["cell"])
	var model := Models.building(b["type"])
	root.add_child(model)
	var scaffold := Models.base("structure_low")
	root.add_child(scaffold)
	var smoke := CPUParticles3D.new()
	smoke.amount = 16
	smoke.lifetime = 1.6
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 20.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.3, 0.4, 0)
	smoke.scale_amount_min = 0.3
	smoke.scale_amount_max = 0.7
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	smoke.mesh = sm
	smoke.material_override = Models.material(Color(0.2, 0.18, 0.18, 0.7))
	smoke.position.y = 1.2
	root.add_child(smoke)
	var fan := model.find_child("windturbine_tall_fan", true, false) as Node3D
	var drill := model.find_child("drill_module", true, false) as Node3D
	if b["type"] != "hq":
		var dep := get_node_or_null("Deposit_%d_%d" % [(b["cell"] as Vector2i).x, (b["cell"] as Vector2i).y])
		if dep != null and b["type"] == "drill":
			(dep as Node3D).scale = Vector3.ONE * 0.6
	_nodes[int(b["id"])] = {"root": root, "model": model, "scaffold": scaffold, "smoke": smoke, "fan": fan, "drill": drill}
	_refresh_building(b)


func _refresh_building(b: Dictionary) -> void:
	var n: Dictionary = _nodes.get(int(b["id"]), {})
	if n.is_empty():
		return
	var building := float(b["build"]) > 0.0
	(n["scaffold"] as Node3D).visible = building
	(n["model"] as Node3D).scale = Vector3(1, 0.35, 1) if building and int(b["level"]) == 1 else Vector3.ONE
	(n["smoke"] as CPUParticles3D).emitting = b["damaged"]


func _on_built(b: Dictionary) -> void:
	_refresh_building(b)
	var n: Dictionary = _nodes.get(int(b["id"]), {})
	if n.is_empty():
		return
	var model: Node3D = n["model"]
	model.scale = Vector3(1.2, 0.6, 1.2)
	var tw := model.create_tween()
	tw.tween_property(model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("done")
	float_text((n["root"] as Node3D).position + Vector3(0, 2.6, 0), "%s ready!" % GameData.info(b["type"])["name"], Color("8ff2a2"))
	_sync_rovers()
	if hud != null:
		hud.refresh_panel()


func node_of(id: int) -> Node3D:
	var n: Dictionary = _nodes.get(id, {})
	return n.get("root", null)


# ---------------------------------------------------------------- input

func _on_tap(screen: Vector2, ground: Vector3) -> void:
	# Meteors first: they're what you'd be aiming at.
	var best := -1
	var best_d := 80.0
	for i in meteors.size():
		var m: Node3D = meteors[i]["node"]
		var d := rig.camera.unproject_position(m.global_position).distance_to(screen)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		blast(best)
		return
	var cell := GameData.world_to_cell(ground)
	if placing != "":
		move_ghost(cell)
		return
	var b := state.at(cell)
	if b.is_empty():
		select(-1)
	else:
		select(int(b["id"]))


func select(id: int) -> void:
	selected = id
	_marks_clear()
	if id >= 0:
		var b := state.by_id(id)
		_mark(b["cell"], Color(1, 1, 1, 0.5))
		Sfx.play("click")
	hud.show_building(id)


# ---------------------------------------------------------------- placing

func start_place(type: String) -> void:
	select(-1)
	placing = type
	if _ghost != null:
		_ghost.queue_free()
	_ghost = Models.building(type)
	add_child(_ghost)
	for m in _ghost.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).transparency = 0.45
	_marks_clear()
	var cells := valid_cells(type)
	for c in cells:
		_mark(c, Color(0.4, 1.0, 0.5, 0.35))
	# Start on the free cell nearest the middle of the view.
	var start := Vector2i(-1, -1)
	var best := INF
	for c in cells:
		var d := GameData.cell_to_world(c).distance_to(rig.focus)
		if d < best:
			best = d
			start = c
	move_ghost(start if start.x >= 0 else GameData.HQ_CELL)


func valid_cells(type: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in GameData.ROWS:
		for x in GameData.COLS:
			if state.place_error(type, Vector2i(x, y)) == "":
				out.append(Vector2i(x, y))
	return out


func move_ghost(cell: Vector2i) -> void:
	if not GameData.in_bounds(cell):
		return
	place_cell = cell
	_ghost.position = GameData.cell_to_world(cell)
	var ok := state.place_error(placing, cell) == ""
	for m in _ghost.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = Models.material(Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.45), 0.4)
	hud.placing_changed()


func confirm_place() -> bool:
	var err := state.place_error(placing, place_cell)
	if err == "":
		err = state.build_error(placing)
	if err != "":
		hud.toast(err)
		Sfx.play("error")
		return false
	var b := state.build(placing, place_cell)
	_spawn_building(b)
	Sfx.play("place")
	cancel_place()
	Save.store()
	return true


func cancel_place() -> void:
	placing = ""
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_marks_clear()
	hud.placing_changed()


func _mark(cell: Vector2i, color: Color) -> void:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GameData.CELL * 0.92, GameData.CELL * 0.92)
	q.mesh = pm
	q.material_override = Models.material(color, 0.6, true)
	q.position = GameData.cell_to_world(cell) + Vector3(0, 0.04, 0)
	_marks.add_child(q)


func _marks_clear() -> void:
	if _marks == null:
		return
	for c in _marks.get_children():
		c.queue_free()


# ---------------------------------------------------------------- the loop

func _process(delta: float) -> void:
	_t += delta
	state.tick(delta)
	for id in _nodes:
		var n: Dictionary = _nodes[id]
		var b := state.by_id(int(id))
		if b.is_empty():
			continue
		var on := state.working(b)
		var speed := state.efficiency() if on else 0.0
		if n["fan"] != null:
			(n["fan"] as Node3D).rotate_object_local(Vector3(0, 0, 1), delta * 3.0 * speed)
		if n["drill"] != null:
			(n["drill"] as Node3D).position.y = absf(sin(_t * 3.0)) * 0.25 * speed
		if (n["scaffold"] as Node3D).visible and float(b["build"]) <= 0.0:
			_refresh_building(b)
	if events:
		_events(delta)
	_update_meteors(delta)
	_update_rovers(delta)


func _events(delta: float) -> void:
	_meteor_t -= delta
	if _meteor_t <= 0.0:
		_meteor_t = _rng.randf_range(70.0, 110.0)
		start_shower(_rng.randi_range(4, 7))
	if _shower_left > 0:
		_shower_gap -= delta
		if _shower_gap <= 0.0:
			_shower_gap = _rng.randf_range(0.7, 1.6)
			_shower_left -= 1
			spawn_meteor()
	_storm_t -= delta
	if _storm_t <= 0.0 and storm_left <= 0.0:
		_storm_t = _rng.randf_range(150.0, 220.0)
		start_storm(30.0)
	if storm_left > 0.0:
		storm_left -= delta
		if storm_left <= 0.0:
			state.storm = false
			hud.banner("The dust storm has passed", Color("8ff2a2"))
	var target_fog := 0.05 if state.storm else 0.004
	_env.fog_density = lerpf(_env.fog_density, target_fog, clampf(delta, 0.0, 1.0))
	_env.fog_light_color = _env.fog_light_color.lerp(Color(0.8, 0.45, 0.28) if state.storm else Color(0.9, 0.55, 0.4), clampf(delta, 0.0, 1.0))


func start_shower(count: int) -> void:
	_shower_left = count
	_shower_gap = 1.2
	hud.banner("Meteor shower! Tap the meteors!", Color("ff9a1f"))
	Sfx.play("alarm")


func start_storm(seconds: float) -> void:
	storm_left = seconds
	state.storm = true
	hud.banner("Dust storm! Solar power halved", Color("ffb02e"))
	Sfx.play("alarm", 0.8)


func spawn_meteor(target_cell: Vector2i = Vector2i(-1, -1)) -> void:
	var cell := target_cell
	if cell.x < 0:
		if _rng.randf() < 0.5 and state.buildings.size() > 1:
			cell = state.buildings[_rng.randi_range(1, state.buildings.size() - 1)]["cell"]
		else:
			cell = Vector2i(_rng.randi_range(0, GameData.COLS - 1), _rng.randi_range(0, GameData.ROWS - 1))
	var target := GameData.cell_to_world(cell)
	var start := target + Vector3(_rng.randf_range(4, 7), 14.0, _rng.randf_range(-6, -3))
	var root := Node3D.new()
	add_child(root)
	root.position = start
	var rock := Models.sphere(0.55, Color(0.45, 0.3, 0.25))
	root.add_child(rock)
	var core := Models.sphere(0.4, Color(1.0, 0.55, 0.15), 3.0)
	core.position = Vector3(0.12, 0.1, 0.12)
	root.add_child(core)
	var trail := CPUParticles3D.new()
	trail.amount = 30
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.spread = 10.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.6
	var tm := SphereMesh.new()
	tm.radius = 0.5
	tm.height = 1.0
	tm.radial_segments = 6
	tm.rings = 3
	trail.mesh = tm
	trail.material_override = Models.material(Color(1.0, 0.6, 0.2, 0.8), 2.5)
	root.add_child(trail)
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 0.85
	marker.mesh = ring
	marker.material_override = Models.material(Color(1.0, 0.3, 0.2, 0.7), 1.0, true)
	marker.position = target + Vector3(0, 0.08, 0)
	add_child(marker)
	meteors.append({"node": root, "from": start, "to": target, "t": 0.0, "time": _rng.randf_range(5.0, 6.5),
		"cell": cell, "marker": marker})


func _update_meteors(delta: float) -> void:
	for i in range(meteors.size() - 1, -1, -1):
		var m: Dictionary = meteors[i]
		m["t"] = float(m["t"]) + delta
		var k := clampf(float(m["t"]) / float(m["time"]), 0.0, 1.0)
		var node: Node3D = m["node"]
		node.position = (m["from"] as Vector3).lerp(m["to"], k * k * 0.6 + k * 0.4)
		node.rotate_y(delta * 3.0)
		(m["marker"] as Node3D).scale = Vector3.ONE * (1.2 - 0.5 * k)
		if k >= 1.0:
			_impact(i)


func _impact(i: int) -> void:
	var m: Dictionary = meteors[i]
	meteors.remove_at(i)
	var at: Vector3 = m["to"]
	_explode(at, Color(1.0, 0.5, 0.2))
	(m["node"] as Node3D).queue_free()
	(m["marker"] as Node3D).queue_free()
	var crater := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 0.8
	cm.height = 0.02
	crater.mesh = cm
	crater.material_override = Models.material(Color(0.3, 0.16, 0.1, 0.8))
	crater.position = at + Vector3(_rng.randf_range(-0.3, 0.3), 0.03, _rng.randf_range(-0.3, 0.3))
	add_child(crater)
	var tw := crater.create_tween()
	tw.tween_interval(20.0)
	tw.tween_property(crater, "scale", Vector3(0.01, 1, 0.01), 2.0)
	tw.tween_callback(crater.queue_free)
	var b := state.at(m["cell"])
	if not b.is_empty() and b["type"] != "hq" and float(b["build"]) <= 0.0:
		state.damage(b)
		_refresh_building(b)
		hud.toast("%s was hit! Tap it to repair." % GameData.info(b["type"])["name"])
		if selected == int(b["id"]):
			hud.refresh_panel()
	rig.shake(0.8)
	Sfx.play("boom")
	Sfx.vibrate(80)


func blast(i: int) -> void:
	var m: Dictionary = meteors[i]
	meteors.remove_at(i)
	var node: Node3D = m["node"]
	_explode(node.position, Color(0.4, 0.95, 1.0))
	node.queue_free()
	(m["marker"] as Node3D).queue_free()
	state.crystals += 1
	state.meteors += 1
	float_text(node.position + Vector3(0, 1.0, 0), "+1 crystal", Color("8ff6ff"))
	Sfx.play("zap")
	Sfx.play("blast")


func _explode(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.5
	p.mesh = bm
	p.material_override = Models.material(color, 2.5)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- rockets and rovers

func _on_lander() -> void:
	var pad := {}
	for b in state.buildings:
		if b["type"] == "pad" and state.working(b):
			pad = b
			break
	var target := GameData.cell_to_world(pad["cell"]) + Vector3(0, 0.5, 0) if not pad.is_empty() else Vector3(_rng.randf_range(-6, 6), 0, 11.5)
	var ship := Models.base("lander_A")
	add_child(ship)
	ship.position = target + Vector3(0, 14, 0)
	ship.scale = Vector3.ONE * 1.3
	var flame := CPUParticles3D.new()
	flame.amount = 24
	flame.lifetime = 0.4
	flame.direction = Vector3.DOWN
	flame.spread = 12.0
	flame.initial_velocity_min = 4.0
	flame.initial_velocity_max = 6.0
	flame.gravity = Vector3.ZERO
	flame.scale_amount_min = 0.2
	flame.scale_amount_max = 0.4
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	fm.radial_segments = 6
	fm.rings = 3
	flame.mesh = fm
	flame.material_override = Models.material(Color(1.0, 0.6, 0.2), 3.0)
	ship.add_child(flame)
	Sfx.play("rocket", 1.0, -4.0)
	var tw := ship.create_tween()
	tw.tween_property(ship, "position", target, 2.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		flame.emitting = false
		float_text(target + Vector3(0, 2.4, 0), "+%d colonists" % GameData.LANDER_COLONISTS, Color("8fd8ff"))
		Sfx.play("reward"))
	tw.tween_interval(1.8)
	tw.tween_callback(func() -> void:
		flame.emitting = true
		Sfx.play("rocket", 1.2, -6.0))
	tw.tween_property(ship, "position", target + Vector3(0, 30, 0), 2.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(ship.queue_free)


func _sync_rovers() -> void:
	var garages: Array[Dictionary] = []
	for b in state.buildings:
		if b["type"] == "garage" and float(b["build"]) <= 0.0:
			garages.append(b)
	while _rovers.size() < garages.size():
		var g: Dictionary = garages[_rovers.size()]
		var truck := Models.base("spacetruck_large")
		add_child(truck)
		truck.scale = Vector3.ONE * 1.4
		truck.position = GameData.cell_to_world(g["cell"]) + Vector3(0, 0, 1.4)
		_rovers.append({"node": truck, "home": truck.position, "target": truck.position, "wait": 1.0, "out": false})


func _update_rovers(delta: float) -> void:
	for r in _rovers:
		var truck: Node3D = r["node"]
		if float(r["wait"]) > 0.0:
			r["wait"] = float(r["wait"]) - delta
			if float(r["wait"]) <= 0.0:
				if r["out"]:
					r["target"] = r["home"]
				else:
					var drills: Array[Vector3] = []
					for b in state.buildings:
						if b["type"] == "drill" and state.working(b):
							drills.append(GameData.cell_to_world(b["cell"]) + Vector3(0, 0, 1.3))
					r["target"] = drills[_rng.randi() % drills.size()] if not drills.is_empty() else r["home"]
				r["out"] = not r["out"]
			continue
		var to: Vector3 = r["target"] - truck.position
		to.y = 0.0
		if to.length() < 0.1:
			r["wait"] = 1.5
			continue
		var step := minf(to.length(), 3.2 * delta)
		truck.position += to.normalized() * step
		truck.rotation.y = lerp_angle(truck.rotation.y, atan2(to.x, to.z), clampf(delta * 6.0, 0.0, 1.0))


func float_text(at: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font()
	l.font_size = 64
	l.outline_size = 14
	l.outline_modulate = Color(0.08, 0.05, 0.1)
	l.modulate = color
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 1.6, 0), 1.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.7)
	tw.tween_callback(l.queue_free)


## Screen points for the HUD: building progress rings and damage warnings.
func overlays() -> Array:
	var out: Array = []
	for b in state.buildings:
		var n := node_of(int(b["id"]))
		if n == null:
			continue
		var top := n.position + Vector3(0, 2.4, 0)
		if rig.camera.is_position_behind(top):
			continue
		var sp := rig.camera.unproject_position(top)
		if float(b["build"]) > 0.0:
			var total := GameData.build_time(b["type"], int(b["level"]) - 1)
			out.append({"pos": sp, "kind": "build", "frac": 1.0 - float(b["build"]) / maxf(total, 0.01)})
		elif b["damaged"]:
			out.append({"pos": sp, "kind": "damaged"})
	return out
