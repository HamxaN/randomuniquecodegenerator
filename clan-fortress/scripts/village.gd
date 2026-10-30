class_name Village
extends Node3D
## Your home island: buildings from the save, tap to select or collect, place
## new buildings from the shop, and watch your troops wander around camp.

signal attack_requested(level_n: int)

var rig: CameraRig
var hud: VillageHud
var nodes := {}
var selected: Building
var placing := ""
var ghost: Building
var ghost_cell := Vector2i.ZERO
var _tick := 0.0
var _wanderers: Array[Dictionary] = []
var _ghost_ring: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Island.build(self, 42, false)
	for data in Save.buildings:
		_spawn_node(data)
	rig = CameraRig.new()
	add_child(rig)
	rig.focus = Vector3(0, 0, 1.0)
	rig.distance = 20.0
	rig.tapped.connect(_on_tap)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = VillageHud.new()
	hud.village = self
	layer.add_child(hud)
	_spawn_wanderers()
	_refresh_states()
	Ads.show_banner()


func _spawn_node(data: Dictionary) -> Building:
	var b := Building.new()
	b.setup(data, "blue")
	add_child(b)
	nodes[int(data["id"])] = b
	return b


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		for data in Save.tick():
			var b: Building = nodes.get(int(data["id"]))
			if b != null:
				b.level = int(data["level"])
				b.set_building(0.0)
				_sparkle(b.global_position)
				Sfx.play("upgrade")
				hud.toast("%s reached level %d!" % [GameData.building(b.kind)["name"], b.level], UI.GREEN)
		_refresh_states()
	_update_wanderers(delta)


## Scaffolding timers and "collect" bubbles.
func _refresh_states() -> void:
	for data in Save.buildings:
		var b: Building = nodes.get(int(data["id"]))
		if b == null:
			continue
		var left := float(data["done_at"]) - Save.now()
		b.set_building(left if Save.building_busy(data) else 0.0)
		var info := GameData.building(b.kind)
		var bubble := ""
		if info.has("produces") and not Save.building_busy(data):
			var cap := int(GameData.at_level(info["capacity"], b.level))
			if Save.ready_to_collect(data) >= maxi(10, cap / 10):
				bubble = "wood" if info["produces"] == "wood" else "gold"
		b.set_bubble(bubble)


func _on_tap(_screen: Vector2, ground: Vector3) -> void:
	var cell := Hex.from_world(ground)
	if placing != "":
		if Hex.buildable(cell):
			_move_ghost(cell)
		return
	var data: Variant = Save.building_at(cell)
	if data == null:
		select(null)
		return
	var b: Building = nodes.get(int(data["id"]))
	if Save.ready_to_collect(data) > 0 and GameData.building(b.kind).has("produces"):
		var got := Save.collect(int(data["id"]))
		if int(got["gold"]) + int(got["wood"]) > 0:
			_collect_fx(b, got)
			_refresh_states()
			if Save.tutorial_step == 0:
				Save.tutorial_step = 1
				Save.store()
			if selected != b:
				return
	select(b)


func select(b: Building) -> void:
	if selected != null and is_instance_valid(selected):
		selected.select(false)
	selected = b
	if b != null:
		b.select(true)
		Sfx.play("click")
	hud.show_selection(b)


func _collect_fx(b: Building, got: Dictionary) -> void:
	Sfx.play("coin")
	b.pop()
	var screen := rig.camera.unproject_position(b.top())
	if int(got["gold"]) > 0:
		hud.fly_resource("gold", screen, int(got["gold"]))
	if int(got["wood"]) > 0:
		hud.fly_resource("wood", screen, int(got["wood"]))


# ---------------------------------------------------------------- Placing

func start_placing(kind: String) -> void:
	cancel_placing()
	select(null)
	placing = kind
	ghost = Building.new()
	ghost.setup({"id": 0, "type": kind, "level": 1, "q": 0, "r": 0}, "blue")
	add_child(ghost)
	_ghost_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.12
	cyl.bottom_radius = 1.12
	cyl.height = 0.03
	cyl.radial_segments = 6
	_ghost_ring.mesh = cyl
	_ghost_ring.rotation.y = PI / 6.0
	_ghost_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(_ghost_ring)
	_ghost_ring.position.y = 0.04
	_move_ghost(_free_cell_near(Hex.from_world(rig.focus)))
	hud.show_placing(kind)


func _free_cell_near(start: Vector2i) -> Vector2i:
	for r in range(0, Hex.BUILD_RADIUS * 2 + 1):
		for c in Hex.ring(r):
			var cell: Vector2i = start + c
			if Hex.buildable(cell) and Save.building_at(cell) == null:
				return cell
	return start


func _move_ghost(cell: Vector2i) -> void:
	ghost_cell = cell
	ghost.position = Hex.to_world(cell)
	ghost.pop()
	var ok: bool = Save.building_at(cell) == null and Hex.buildable(cell)
	_ghost_ring.material_override = Models.material(Color(0.3, 1.0, 0.3, 0.5) if ok else Color(1.0, 0.2, 0.15, 0.5), 0.5, true)
	Sfx.play("rotate", 1.2, -6.0)


func confirm_placing() -> void:
	if placing == "":
		return
	var err := Save.place(placing, ghost_cell)
	if err != "":
		hud.toast(err, UI.RED)
		Sfx.play("deny")
		return
	var data: Dictionary = Save.buildings[-1]
	cancel_placing()
	var b := _spawn_node(data)
	b.pop()
	_refresh_states()
	_dust(b.global_position)
	Sfx.play("build")
	if Save.tutorial_step == 1:
		Save.tutorial_step = 2
		Save.store()
	hud.refresh()


func cancel_placing() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	placing = ""
	hud.show_placing("")


# ---------------------------------------------------------------- Actions from the HUD

func upgrade_selected() -> void:
	if selected == null:
		return
	var err := Save.upgrade(selected.id)
	if err != "":
		hud.toast(err, UI.RED)
		Sfx.play("deny")
		return
	Sfx.play("build")
	_dust(selected.global_position)
	_refresh_states()
	hud.show_selection(selected)


func finish_selected(free: bool) -> void:
	if selected == null:
		return
	if Save.finish_now(selected.id, free):
		_tick = 0.0
	else:
		hud.toast("Not enough gems", UI.RED)
		Sfx.play("deny")


# ---------------------------------------------------------------- Life and effects

func _spawn_wanderers() -> void:
	var kinds: Array[String] = []
	for t in GameData.TROOP_ORDER:
		for i in mini(int(Save.army.get(t, 0)), 3):
			if kinds.size() < 8:
				kinds.append(t)
	for i in kinds.size():
		var t: Dictionary = GameData.troop(kinds[i])
		var holder := Node3D.new()
		var model := Models.character(t["model"], t["keep"])
		holder.add_child(model)
		model.rotation.y = PI
		var b := Models.bounds(model)
		model.scale = Vector3.ONE * (Troop.HEIGHT / maxf(b.end.y, 0.3))
		add_child(holder)
		holder.position = _random_walk_point()
		var ap := Models.animation_player(model)
		_wanderers.append({"node": holder, "ap": ap, "goal": _random_walk_point(), "wait": randf() * 2.0, "anim": ""})


func _random_walk_point() -> Vector3:
	for i in 20:
		var cell := Hex.random_on_ring(_rng, _rng.randi_range(1, Hex.BUILD_RADIUS))
		if Save.building_at(cell) == null:
			return Hex.to_world(cell) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	return Vector3.ZERO


func _update_wanderers(delta: float) -> void:
	for w in _wanderers:
		var node: Node3D = w["node"]
		var ap: AnimationPlayer = w["ap"]
		if float(w["wait"]) > 0.0:
			w["wait"] = float(w["wait"]) - delta
			_anim(w, ap, "Idle")
			continue
		var goal: Vector3 = w["goal"]
		var to := goal - node.position
		to.y = 0
		if to.length() < 0.15:
			w["goal"] = _random_walk_point()
			w["wait"] = randf_range(1.0, 4.0)
			continue
		var dir := to.normalized()
		node.position += dir * 0.7 * delta
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 6.0, 0, 1))
		_anim(w, ap, "Walking_A")


func _anim(w: Dictionary, ap: AnimationPlayer, anim_name: String) -> void:
	if ap == null or w["anim"] == anim_name or not ap.has_animation(anim_name):
		return
	w["anim"] = anim_name
	ap.play(anim_name, 0.2)


func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.42
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
	p.material_override = Models.material(Color(0.86, 0.8, 0.68))
	add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)


func _sparkle(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 24
	p.lifetime = 1.0
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = Models.material(Color(1.0, 0.9, 0.35), 3.0, true)
	add_child(p)
	p.global_position = at + Vector3(0, 1.0, 0)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(p.queue_free)
