class_name Race
extends Node3D
## One race: six karts on the grid, a countdown, laps and positions, item boxes,
## rockets, oil slicks and shields, bumping, and a swooping chase camera.

signal exit_requested(next: bool)

var track_index := 0
var autopilot := false
var track: Track
var karts: Array[Kart] = []
var player: Kart
var hud: RaceHud
var camera: Camera3D
var state := "countdown"
var countdown := 3.6
var race_time := 0.0
var finish_order: Array[Kart] = []
var steer_input := 0.0
var drift_input := false

var _boxes: Array[Dictionary] = []
var _rockets: Array[Dictionary] = []
var _slicks: Array[Dictionary] = []
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _engine: AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()
	track = Track.new()
	add_child(track)
	track.build(GameData.track(track_index))
	_place_boxes()
	_spawn_karts()
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	_cam_pos = player.position - player.forward() * 9.0 + Vector3(0, 4.5, 0)
	_cam_look = player.position
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = RaceHud.new()
	hud.race = self
	layer.add_child(hud)
	_engine = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/sfx/engine.ogg"):
		var s: AudioStream = load("res://assets/sfx/engine.ogg")
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_engine.stream = s
		_engine.volume_db = -14.0
	add_child(_engine)
	if Save.sound:
		_engine.play()
	Ads.hide_banner()


func _spawn_karts() -> void:
	var names := GameData.RIVALS.duplicate()
	names.shuffle()
	var others: Array = []
	for k in GameData.KARTS:
		if k["id"] != Save.kart:
			others.append(k)
	var n := track.samples.size()
	for i in GameData.RACERS:
		var is_player := i == GameData.RACERS - 1
		var info: Dictionary = GameData.kart(Save.kart) if is_player else others[i % others.size()]
		var k := Kart.new()
		k.race = self
		k.setup(info, is_player, "YOU" if is_player else str(names[i]), Color.WHITE)
		add_child(k)
		var row := i / 2
		var si := (n - 4 - row * 4) % n
		var t := track.tangents[si]
		k.heading = atan2(-t.x, -t.z)
		k.position = track.samples[si] + track.side(si) * (3.0 if i % 2 == 0 else -3.0)
		k.index = si
		k.lap = -1
		k.rotation.y = k.heading
		if is_player:
			player = k
			k.nitro = 1.0 + 0.15 * Save.upgrade("nitro")
		karts.append(k)


func speed_bonus(k: Kart) -> float:
	if k.is_player:
		return 1.0 + 0.03 * Save.upgrade("engine")
	# Rivals keep the race close: a little faster behind the player, slower ahead.
	var gap := (player.progress() - k.progress()) / float(track.samples.size())
	return k.skill * clampf(1.0 + gap * 0.18, 0.9, 1.1) * (1.0 + 0.012 * track_index)


func _physics_process(delta: float) -> void:
	match state:
		"countdown":
			countdown -= delta
			hud.countdown(countdown)
			if countdown <= 0.0:
				state = "race"
				Sfx.play("go")
		"race", "done":
			race_time += delta
	if not autopilot:
		player.steer = steer_input
		player.drift_held = drift_input
	for k in karts:
		k.step(delta)
	_collide()
	_update_boxes(delta)
	_update_rockets(delta)
	_update_slicks()
	_update_camera(delta)
	if _engine.playing:
		_engine.pitch_scale = 0.7 + player.speed / player.top_speed * 0.9 + (0.25 if player.boost_time > 0.0 else 0.0)


func _process(delta: float) -> void:
	if autopilot and player != null and state == "race":
		# The player's kart drives itself for the screenshot run.
		player._ai(delta)
		if player.item != "":
			use_item(player)


func places() -> Array[Kart]:
	var list: Array[Kart] = karts.duplicate()
	list.sort_custom(func(a: Kart, b: Kart) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.progress() > b.progress())
	return list


func place_of(k: Kart) -> int:
	return places().find(k) + 1


func on_lap(k: Kart) -> void:
	var laps := int(track.info["laps"])
	if k.lap >= laps and not k.finished:
		k.finished = true
		k.finish_time = race_time
		finish_order.append(k)
		if k == player:
			state = "done"
			Sfx.play("win" if finish_order.size() <= 3 else "lap")
			hud.finished(finish_order.size())
	elif k == player and k.lap > 0:
		hud.lap_banner(k.lap + 1, laps)
		Sfx.play("lap")


func on_mini_turbo(k: Kart, big: bool) -> void:
	if k == player:
		Sfx.play("boost", 1.2 if big else 1.0)
		hud.flash_text("MINI-TURBO!" if not big else "SUPER TURBO!", Color("4fc3ff") if not big else Color("ff9a1f"))


func bump() -> void:
	_shake = maxf(_shake, 0.25)
	Sfx.play("impact", 1.0, -4.0)
	Sfx.vibrate(20)


func _collide() -> void:
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a := karts[i]
			var b := karts[j]
			var d := a.position - b.position
			d.y = 0
			var l := d.length()
			if l < 2.2 and l > 0.001:
				var push := d / l * (2.2 - l) * 0.5
				a.position += push
				b.position -= push
				var faster := a if a.speed > b.speed else b
				faster.speed *= 0.97
				if a == player or b == player:
					if l < 1.8:
						bump()


# ---------------------------------------------------------------- Items

func _place_boxes() -> void:
	for spot in track.box_spots:
		var i := track.nearest(spot, 0, track.samples.size())
		for lane in [-4.5, -1.5, 1.5, 4.5]:
			var p: Vector3 = track.samples[i] + track.side(i) * lane + Vector3(0, 1.0, 0)
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.1, 1.1, 1.1)
			box.mesh = bm
			box.material_override = Models.material(Color(0.4, 0.75, 1.0, 0.75), 1.6, true)
			var q := Label3D.new()
			q.text = "?"
			q.font = UI.font()
			q.font_size = 96
			q.outline_size = 18
			q.pixel_size = 0.009
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.no_depth_test = true
			box.add_child(q)
			add_child(box)
			box.position = p
			_boxes.append({"node": box, "respawn": 0.0})


func _update_boxes(delta: float) -> void:
	for b in _boxes:
		var node: MeshInstance3D = b["node"]
		node.rotate_y(delta * 1.5)
		node.rotate_x(delta * 0.8)
		if float(b["respawn"]) > 0.0:
			b["respawn"] = float(b["respawn"]) - delta
			if float(b["respawn"]) <= 0.0:
				node.visible = true
			continue
		for k in karts:
			if k.position.distance_to(node.position - Vector3(0, 1.0, 0)) < 2.0:
				node.visible = false
				b["respawn"] = 3.0
				if k.item == "":
					k.item = GameData.roll_item(place_of(k), _rng)
					k.item_uses = 3 if k.item == "triple" else 1
					if k == player:
						Sfx.play("item")
						hud.item_roll(k.item)
				break


func use_item(k: Kart) -> void:
	if k.item == "" or state != "race" or k.spin_time > 0.0:
		return
	match k.item:
		"boost", "triple":
			k.boost_time = maxf(k.boost_time, 1.5)
			if k == player:
				Sfx.play("boost", 0.9)
		"shield":
			k.shield_time = 7.0
		"rocket":
			_fire_rocket(k)
		"oil":
			_drop_oil(k)
	k.item_uses -= 1
	if k.item_uses <= 0:
		k.item = ""
	if k == player:
		hud.item_roll(k.item)


func ai_item(k: Kart) -> void:
	var place := place_of(k)
	match k.item:
		"rocket":
			if place > 1:
				use_item(k)
		"oil":
			var list := places()
			if place < list.size() and list[place].progress() > k.progress() - 25:
				use_item(k)
		"shield":
			if k.shield_time <= 0.0:
				use_item(k)
		_:
			var ahead := (k.index + 20) % track.samples.size()
			if track.tangents[k.index].dot(track.tangents[ahead]) > 0.9:
				use_item(k)


func _fire_rocket(k: Kart) -> void:
	var list := places()
	var place := list.find(k)
	var target: Kart = list[place - 1] if place > 0 else null
	var node := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.28
	cm.height = 1.3
	node.mesh = cm
	node.material_override = Models.material(Color(1.0, 0.25, 0.2), 2.0)
	var trail := CPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.4
	trail.direction = Vector3(0, -1, 0)
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 2.0
	trail.scale_amount_min = 0.15
	trail.scale_amount_max = 0.3
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	trail.mesh = sm
	trail.material_override = Models.material(Color(1.0, 0.6, 0.2), 4.0, true)
	trail.position.y = -0.6
	node.add_child(trail)
	add_child(node)
	node.position = k.position + Vector3(0, 1.2, 0) + k.forward() * 2.0
	_rockets.append({"node": node, "index": k.index, "target": target, "life": 6.0, "owner": k})
	Sfx.play("rocket")


func _update_rockets(delta: float) -> void:
	var n := track.samples.size()
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		var node: MeshInstance3D = r["node"]
		r["life"] = float(r["life"]) - delta
		var target: Kart = r["target"]
		var goal: Vector3
		if target != null and node.position.distance_to(target.position) < 14.0:
			goal = target.position + Vector3(0, 0.8, 0)
		else:
			r["index"] = (int(r["index"]) + 2) % n
			goal = track.samples[int(r["index"])] + Vector3(0, 1.2, 0)
		var dir := (goal - node.position).normalized()
		node.position += dir * 55.0 * delta
		node.look_at(node.position + dir, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, -PI / 2)
		var done := float(r["life"]) <= 0.0
		for k in karts:
			if k == r["owner"]:
				continue
			if k.position.distance_to(node.position - Vector3(0, 0.8, 0)) < 1.8:
				_explode(node.position)
				if k.hit(1.4) and k == player:
					hud.flash_text("HIT!", UI.RED)
				done = true
				break
		if done:
			node.queue_free()
			_rockets.remove_at(i)


func _drop_oil(k: Kart) -> void:
	var slick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 0.04
	slick.mesh = cyl
	slick.material_override = Models.material(Color(0.05, 0.05, 0.08))
	(slick.material_override as StandardMaterial3D).metallic = 0.9
	(slick.material_override as StandardMaterial3D).roughness = 0.1
	add_child(slick)
	slick.position = k.position - k.forward() * 3.0 + Vector3(0, 0.06, 0)
	_slicks.append({"node": slick, "owner": k, "grace": 1.0})
	Sfx.play("oil")


func _update_slicks() -> void:
	for i in range(_slicks.size() - 1, -1, -1):
		var s: Dictionary = _slicks[i]
		var node: MeshInstance3D = s["node"]
		s["grace"] = float(s["grace"]) - get_physics_process_delta_time()
		for k in karts:
			if k == s["owner"] and float(s["grace"]) > 0.0:
				continue
			if k.spin_time <= 0.0 and k.position.distance_to(node.position) < 1.8:
				if k.hit(1.0) and k == player:
					hud.flash_text("OIL!", UI.RED)
				node.queue_free()
				_slicks.remove_at(i)
				break


func _explode(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.6
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	p.mesh = sm
	p.material_override = Models.material(Color(1.0, 0.55, 0.15), 4.0, true)
	add_child(p)
	p.position = at
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(p.queue_free)
	Sfx.play("boom")
	if at.distance_to(player.position) < 25.0:
		_shake = maxf(_shake, 0.4)


func _update_camera(delta: float) -> void:
	var f := player.forward()
	var back := 8.0 + player.speed * 0.05
	var goal := player.position - f * back + Vector3(0, 3.6, 0)
	_cam_pos = _cam_pos.lerp(goal, clampf(delta * 6.0, 0, 1))
	_cam_look = _cam_look.lerp(player.position + f * 5.0 + Vector3(0, 1.0, 0), clampf(delta * 10.0, 0, 1))
	_shake = maxf(0.0, _shake - delta * 1.5)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake * 0.6
	camera.position = _cam_pos + jitter
	camera.look_at(_cam_look, Vector3.UP)
	camera.fov = lerpf(camera.fov, 60.0 + player.speed * 0.25 + (8.0 if player.boost_time > 0.0 else 0.0), delta * 4.0)


## Ends the race and records the reward. Returns the summary.
func results() -> Dictionary:
	var order := places()
	var place := order.find(player) + 1
	var coins := GameData.coins_for(place)
	var unlocked := Save.finish_race(track_index, place, coins)
	Ads.match_finished()
	return {"place": place, "coins": coins, "order": order, "time": race_time, "unlocked": unlocked}
