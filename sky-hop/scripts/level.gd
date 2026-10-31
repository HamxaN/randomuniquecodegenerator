class_name Level
extends Node3D
## One sky course: floating platforms (some slide, lift or crumble), bounce pads,
## coin blocks to bump, coins and three hidden stars, checkpoints and the goal.

signal exit_requested(next: bool)

var level_n := 1
var autopilot := false
var player: Player
var hud: HopHud
var camera: Camera3D
var course: Dictionary
var coins := 0
var stars_got: Array[int] = []
var falls := 0
var time := 0.0
var state := "play"
var _movers: Array[Dictionary] = []
var _fallers: Array[Dictionary] = []
var _coins: Array[Node3D] = []
var _stars: Array[Node3D] = []
var _blocks := {}
var _bouncers := {}
var _checkpoint := Vector3.ZERO
var _flags: Array[Dictionary] = []
var _goal: Vector3
var _min_y := 0.0
var _cam_pos := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	course = GameData.course(level_n)
	_environment()
	for p in course["pieces"]:
		_build_piece(p)
	for c in course["coins"]:
		var coin := Models.kit("coin")
		coin.scale = Vector3.ONE * 1.6
		add_child(coin)
		coin.position = c
		_coins.append(coin)
	for i in (course["stars"] as Array).size():
		_stars.append(_make_star(course["stars"][i]))
	for b in course["blocks"]:
		_make_block(b)
	for i in (course["checkpoints"] as Array).size():
		if i == 0:
			continue
		var cp: Vector3 = course["checkpoints"][i]
		var flag := Models.kit("flag")
		flag.scale = Vector3.ONE * 1.6
		add_child(flag)
		flag.position = cp + Vector3(1.6, -0.1, 0)
		_flags.append({"node": flag, "pos": cp, "on": false})
	_goal = course["goal"]
	var goal_flag := Models.kit("flag")
	goal_flag.scale = Vector3.ONE * 3.2
	add_child(goal_flag)
	goal_flag.position = _goal + Vector3(0, 0.5, 0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.3)
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	glow.position = _goal + Vector3(0, 2.5, 0)
	add_child(glow)
	_checkpoint = course["checkpoints"][0]
	for p in course["pieces"]:
		_min_y = minf(_min_y, (p["pos"] as Vector3).y)
	player = Player.new()
	player.level = self
	add_child(player)
	player.global_position = _checkpoint
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 300.0
	add_child(camera)
	camera.current = true
	_cam_pos = player.global_position + Vector3(0, 3.3, 5.6)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HopHud.new()
	hud.level = self
	layer.add_child(hud)
	Ads.hide_banner()


func _environment() -> void:
	var w := GameData.world_of(level_n)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = w["sky_top"]
	sm.sky_horizon_color = w["horizon"]
	sm.ground_horizon_color = w["horizon"]
	sm.ground_bottom_color = (w["sky_top"] as Color).darkened(0.2)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = w["horizon"]
	env.fog_density = 0.008
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0 if (w["name"] as String) != "Starry Night" else 0.45
	sun.light_color = Color(1, 0.95, 0.85) if (w["name"] as String) != "Starry Night" else Color(0.6, 0.65, 1.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# Clouds drifting below and around the course.
	var rng := RandomNumberGenerator.new()
	rng.seed = level_n * 13
	var length := absf((course["goal"] as Vector3).z) + 20.0
	for i in int(length / 3.0):
		var cloud := Models.kit("cloud")
		add_child(cloud)
		# Well off to the sides or far below, so they never block the view.
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var below := rng.randf() < 0.6
		cloud.position = Vector3(side * rng.randf_range(10, 26) if not below else rng.randf_range(-20, 20),
			rng.randf_range(-16, -9) if below else rng.randf_range(-4, 6), -rng.randf() * length + 4)
		cloud.scale = Vector3.ONE * rng.randf_range(2.0, 4.5)
		for m in cloud.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_piece(p: Dictionary) -> void:
	var kind: String = p["kind"]
	var pos: Vector3 = p["pos"]
	var body: PhysicsBody3D
	if kind == "mover" or kind == "falling":
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = true
		body = ab
	else:
		body = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.position = pos
	var model := Models.kit(p["model"])
	body.add_child(model)
	var b := Models.bounds(model)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(b.size.x * 0.95, maxf(b.size.y, 0.3), b.size.z * 0.95)
	cs.shape = box
	cs.position = b.get_center()
	body.add_child(cs)
	if kind == "bounce":
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.7
		cyl.bottom_radius = 0.8
		cyl.height = 0.2
		pad.mesh = cyl
		pad.material_override = Models.material(Color(1.0, 0.35, 0.55), 1.2)
		pad.position.y = b.end.y + 0.1
		body.add_child(pad)
		_bouncers[body.get_instance_id()] = pad
	elif kind == "mover":
		_movers.append({"body": body, "origin": pos, "move": p["move"], "period": float(p["period"])})
	elif kind == "falling":
		_fallers.append({"body": body, "origin": pos, "timer": -1.0, "down": false})
	if (p["model"] as String).begins_with("platform-grass") or (p["model"] == "platform-large" and randf() < 0.5):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(pos.x * 31 + pos.z * 17)
		for i in 4:
			var g := Models.kit("grass" if i % 2 == 0 else "grass-small")
			body.add_child(g)
			g.position = Vector3(rng.randf_range(-1.8, 1.8), b.end.y - 0.02, rng.randf_range(-1.8, 1.8))
		# Trees stand at the back corners so they never hide the hopper.
		if rng.randf() < 0.6 and pos != Vector3.ZERO:
			var tree := Models.prop("res://assets/decor/%s.gltf" % ["tree_single_A", "tree_single_B"][rng.randi() % 2])
			body.add_child(tree)
			tree.position = Vector3(rng.randf_range(1.5, 1.9) * (1.0 if rng.randf() < 0.5 else -1.0), b.end.y, rng.randf_range(-1.7, -1.1))
			tree.scale = Vector3.ONE * 1.8


func _make_star(at: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var mesh := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var r := 0.55 if i % 2 == 0 else 0.24
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0))
	for face in [0.12, -0.12]:
		for i in 10:
			st.set_normal(Vector3(0, 0, signf(face)))
			st.add_vertex(Vector3(0, 0, face))
			st.add_vertex(pts[i])
			st.add_vertex(pts[(i + 1) % 10])
	mesh.mesh = st.commit()
	var mat := Models.material(Color(1.0, 0.82, 0.2), 1.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	root.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.3)
	light.light_energy = 1.5
	light.omni_range = 3.0
	root.add_child(light)
	return root


func _make_block(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.position = at
	var model := Models.kit("block-coin")
	body.add_child(model)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = box
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	_blocks[body.get_instance_id()] = {"body": body, "model": model, "coins": 5}
	for x in [-1.1, 1.1]:
		var brick := Models.kit("brick")
		add_child(brick)
		brick.position = at + Vector3(x, 0, 0)


func _physics_process(delta: float) -> void:
	_t += delta
	for m in _movers:
		var body: AnimatableBody3D = m["body"]
		var move: Vector3 = m["move"]
		var phase := _t * TAU / float(m["period"])
		# Side-to-side platforms swing around their rest spot; lifts rise from it.
		var k := sin(phase) if move.y <= 0.0 else 0.5 - 0.5 * cos(phase)
		body.position = (m["origin"] as Vector3) + move * k
	for f in _fallers:
		var body: AnimatableBody3D = f["body"]
		if float(f["timer"]) >= 0.0:
			f["timer"] = float(f["timer"]) + delta
			var tt := float(f["timer"])
			if tt < 0.6:
				body.position = (f["origin"] as Vector3) + Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05))
			elif tt < 3.2:
				body.position.y -= delta * (tt - 0.5) * 14.0
			else:
				body.position = f["origin"]
				f["timer"] = -1.0


func _process(delta: float) -> void:
	if state == "play":
		time += delta
	if player == null:
		return
	if not autopilot:
		player.input = hud.move_input()
	# Coins, stars, checkpoints, goal.
	var pp := player.global_position + Vector3(0, 0.4, 0)
	for i in range(_coins.size() - 1, -1, -1):
		var c := _coins[i]
		c.rotate_y(delta * 3.0)
		if c.global_position.distance_to(pp) < 0.75:
			coins += 1
			Sfx.play("coin", randf_range(0.95, 1.1))
			_pop(c)
			_coins.remove_at(i)
	for i in _stars.size():
		var s := _stars[i]
		if not s.visible:
			continue
		s.rotate_y(delta * 2.0)
		s.position.y += sin(_t * 3.0) * delta * 0.3
		if s.global_position.distance_to(pp) < 1.0:
			s.visible = false
			stars_got.append(i)
			Sfx.play("star")
			hud.star_collected(stars_got.size())
	for f in _flags:
		if not f["on"] and (f["pos"] as Vector3).distance_to(player.global_position) < 2.6:
			f["on"] = true
			_checkpoint = f["pos"]
			Sfx.play("checkpoint")
			hud.toast("Checkpoint!")
			var flag: Node3D = f["node"]
			flag.create_tween().tween_property(flag, "scale", Vector3.ONE * 2.2, 0.15)
			flag.create_tween().tween_property(flag, "scale", Vector3.ONE * 1.6, 0.25).set_delay(0.15)
	if state == "play" and player.global_position.distance_to(_goal + Vector3(0, 0.6, 0)) < 2.4:
		_finish()
	if player.global_position.y < _min_y - 9.0:
		falls += 1
		Sfx.play("fall")
		player.global_position = _checkpoint
		player.velocity = Vector3.ZERO
		hud.toast("Oops! Back to the checkpoint")
	_update_camera(delta)


func landed_on(collider: Object) -> void:
	if collider == null:
		return
	var id := collider.get_instance_id()
	if _bouncers.has(id):
		player.bounce(GameData.BOUNCE)
		Sfx.play("bounce")
		var pad: Node3D = _bouncers[id]
		pad.scale = Vector3(1.3, 0.4, 1.3)
		pad.create_tween().tween_property(pad, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	for f in _fallers:
		if f["body"] == collider and float(f["timer"]) < 0.0:
			f["timer"] = 0.0
			Sfx.play("break", 1.3, -8.0)


func bump(collider: Object) -> void:
	if collider == null:
		return
	var id := collider.get_instance_id()
	if not _blocks.has(id):
		return
	var b: Dictionary = _blocks[id]
	if int(b["coins"]) <= 0:
		return
	b["coins"] = int(b["coins"]) - 1
	coins += 1
	Sfx.play("coin", 1.2)
	var body: StaticBody3D = b["body"]
	var tw := body.create_tween()
	tw.tween_property(body, "position:y", body.position.y + 0.3, 0.06)
	tw.tween_property(body, "position:y", body.position.y, 0.1)
	var coin := Models.kit("coin")
	coin.scale = Vector3.ONE * 1.6
	add_child(coin)
	coin.position = body.position + Vector3(0, 1.2, 0)
	var ct := coin.create_tween().set_parallel()
	ct.tween_property(coin, "position:y", coin.position.y + 1.4, 0.35)
	ct.tween_property(coin, "rotation:y", TAU * 2, 0.35)
	ct.chain().tween_callback(coin.queue_free)
	if int(b["coins"]) <= 0:
		(b["model"] as Node3D).queue_free()
		var brick := Models.kit("brick")
		body.add_child(brick)


func _pop(n: Node3D) -> void:
	var tw := n.create_tween().set_parallel()
	tw.tween_property(n, "scale", Vector3.ONE * 2.6, 0.12)
	tw.tween_property(n, "position:y", n.position.y + 0.5, 0.12)
	tw.chain().tween_callback(n.queue_free)


func puff(at: Vector3, amount: int) -> void:
	for i in amount:
		var d := Models.kit("dust")
		add_child(d)
		d.position = at + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
		var tw := d.create_tween().set_parallel()
		tw.tween_property(d, "position", d.position + Vector3(randf_range(-0.6, 0.6), 0.4, randf_range(-0.6, 0.6)), 0.4)
		tw.tween_property(d, "scale", Vector3.ONE * 0.1, 0.4)
		tw.chain().tween_callback(d.queue_free)


func _update_camera(delta: float) -> void:
	var goal := player.global_position + Vector3(0, 3.3, 5.6)
	_cam_pos = _cam_pos.lerp(goal, clampf(delta * 4.0, 0, 1))
	camera.position = _cam_pos
	camera.look_at(_cam_pos - Vector3(0, 2.7, 5.6) + Vector3(0, 0, -2.5), Vector3.UP)


func _finish() -> void:
	state = "done"
	player.input = Vector2.ZERO
	var stars := GameData.stars_for(stars_got.size())
	var reward := GameData.coins_reward(coins, stars)
	Save.finish_level(level_n, stars, reward, time)
	Ads.match_finished()
	Sfx.play("win")
	hud.show_end(stars, reward)


## Progress along the course, 0 to 1 (for the HUD bar).
func progress() -> float:
	var start: Vector3 = course["checkpoints"][0]
	return clampf((start.z - player.global_position.z) / maxf(1.0, start.z - _goal.z), 0.0, 1.0)
