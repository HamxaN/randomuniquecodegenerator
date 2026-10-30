class_name Battle
extends Node3D
## A raid on an enemy village: deploy troops around the edge, watch them smash
## buildings while archer towers and catapults fight back, and earn stars and loot.

signal exit_requested

const DEPLOY_EVERY := 0.16

var level_n := 1
var autopilot := false
var rig: CameraRig
var hud: BattleHud
var buildings: Array[Building] = []
var troops: Array[Troop] = []
var available := {}
var used := {}
var selected := ""
var time_left := GameData.BATTLE_SECONDS
var started := false
var finished := false
var loot_total := {}
var loot_taken := {"gold": 0, "wood": 0}
var town_hall_down := false
var stars := 0

var _holding := false
var _hold_ground := Vector3.ZERO
var _hold_t := 0.0
var _projectiles: Array[Dictionary] = []
var _end_delay := -1.0
var _forbidden: Dictionary = {}


func _ready() -> void:
	Island.build(self, 500 + level_n * 17, true)
	for data in GameData.enemy_base(level_n):
		var b := Building.new()
		b.setup(data, "red")
		b.rotation.y = randi_range(0, 5) * PI / 3.0
		add_child(b)
		buildings.append(b)
		for d in Hex.disc(1):
			_forbidden[b.cell + d] = true
	for t in GameData.TROOP_ORDER:
		if int(Save.army.get(t, 0)) > 0:
			available[t] = int(Save.army[t])
	if available.size() > 0:
		selected = available.keys()[0]
	loot_total = GameData.enemy_loot(level_n)
	rig = CameraRig.new()
	add_child(rig)
	rig.focus = Vector3(0, 0, 1.2)
	rig.distance = 17.5
	rig.tapped.connect(_on_tap)
	rig.pressed.connect(func(_s: Vector2, g: Vector3) -> void:
		_holding = true
		_hold_ground = g
		_hold_t = 0.45)
	rig.released.connect(func() -> void: _holding = false)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = BattleHud.new()
	hud.battle = self
	layer.add_child(hud)
	Sfx.play("horn")
	Ads.hide_banner()


func _process(delta: float) -> void:
	if finished:
		return
	if started:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			finish()
			return
	if _holding and selected != "":
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = DEPLOY_EVERY
			deploy(_hold_ground + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), false)
	_defenses(delta)
	_update_projectiles(delta)
	if _end_delay >= 0.0:
		_end_delay -= delta
		if _end_delay < 0.0:
			finish()
	elif started and _alive_troops() == 0 and _left_to_deploy() == 0:
		_end_delay = 1.2


func _on_tap(_screen: Vector2, ground: Vector3) -> void:
	deploy(ground, true)


func _alive_troops() -> int:
	var n := 0
	for t in troops:
		if not t.dead:
			n += 1
	return n


func _left_to_deploy() -> int:
	var n := 0
	for k in available:
		n += int(available[k])
	return n


func can_deploy_at(ground: Vector3) -> bool:
	var cell := Hex.from_world(ground)
	return Hex.distance(cell, Vector2i.ZERO) <= Hex.LAND_RADIUS and not _forbidden.has(cell)


## Puts one of the selected troop down at [param ground].
func deploy(ground: Vector3, tapped: bool) -> bool:
	if finished or selected == "" or int(available.get(selected, 0)) <= 0:
		if tapped and selected != "":
			hud.toast("No %ss left!" % GameData.troop(selected)["name"])
		return false
	if not can_deploy_at(ground):
		if tapped:
			hud.toast("Deploy troops outside the red zone")
			_flash_forbidden()
			Sfx.play("deny")
		return false
	var t := Troop.new()
	t.battle = self
	t.setup(selected, Save.troop_level(selected))
	add_child(t)
	t.global_position = Vector3(ground.x, 0, ground.z)
	t.rotation.y = atan2(t.global_position.x, t.global_position.z)
	troops.append(t)
	available[selected] = int(available[selected]) - 1
	used[selected] = int(used.get(selected, 0)) + 1
	if int(available[selected]) <= 0:
		for k in GameData.TROOP_ORDER:
			if int(available.get(k, 0)) > 0:
				selected = k
				break
	_puff(t.global_position, Color(0.9, 0.85, 0.7), 8)
	Sfx.play("place", randf_range(1.1, 1.4), -6.0)
	if not started:
		started = true
	hud.refresh_troops()
	return true


func _flash_forbidden() -> void:
	for cell in _forbidden:
		if Hex.distance(cell, Vector2i.ZERO) > Hex.LAND_RADIUS:
			continue
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.12
		cyl.bottom_radius = 1.12
		cyl.height = 0.02
		cyl.radial_segments = 6
		m.mesh = cyl
		m.material_override = Models.material(Color(1, 0.15, 0.1, 0.35), 0.0, true)
		m.rotation.y = PI / 6.0
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.position = Hex.to_world(cell) + Vector3(0, 0.03, 0)
		var tw := m.create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(m, "transparency", 1.0, 0.4)
		tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- Troop AI support

func pick_target(t: Troop) -> Building:
	var prefer_defense: bool = t.info["target"] == "defense"
	var best: Building = null
	var best_d := INF
	for pass_index in 2:
		for b in buildings:
			if b.destroyed or not b.counts_for_destruction():
				continue
			if prefer_defense and pass_index == 0 and not b.is_defense():
				continue
			var d := b.global_position.distance_squared_to(t.global_position)
			if d < best_d:
				best_d = d
				best = b
		if best != null:
			break
	return best


## A push away from buildings that are in the way, so troops walk around them.
func avoid(t: Troop, target: Building) -> Vector3:
	var push := Vector3.ZERO
	for b in buildings:
		if b == target or b.destroyed:
			continue
		var d := t.global_position - b.global_position
		d.y = 0
		var l := d.length()
		if l < 1.15 and l > 0.001:
			push += d / l * (1.15 - l) * 2.0
	return push


func hit_building(b: Building, dmg: float, _from: Troop) -> void:
	if b.destroyed:
		return
	_puff(b.global_position + Vector3(randf_range(-0.4, 0.4), 0.6, randf_range(-0.4, 0.4)), Color(0.75, 0.65, 0.5), 3)
	if b.take_damage(dmg):
		_on_destroyed(b)


func _on_destroyed(b: Building) -> void:
	Sfx.play("break")
	rig.shake(0.5)
	_puff(b.global_position + Vector3(0, 0.5, 0), Color(0.62, 0.55, 0.48), 22)
	if b.kind == "townhall":
		town_hall_down = true
		hud.announce("TOWN HALL DESTROYED!")
	var frac := destruction()
	loot_taken["gold"] = int(float(loot_total["gold"]) * frac)
	loot_taken["wood"] = int(float(loot_total["wood"]) * frac)
	var s := GameData.stars(frac, town_hall_down)
	if s > stars:
		stars = s
		hud.star_earned(stars)
		Sfx.play("star")
	if frac >= 0.999 and _end_delay < 0.0:
		_end_delay = 1.6


func destruction() -> float:
	var total := 0
	var down := 0
	for b in buildings:
		if b.counts_for_destruction():
			total += 1
			if b.destroyed:
				down += 1
	return float(down) / maxf(1.0, float(total))


func troop_died(t: Troop) -> void:
	Sfx.play("die", randf_range(0.9, 1.2), -4.0)
	var tw := t.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(t, "position:y", -0.6, 0.8)
	tw.tween_callback(func() -> void:
		troops.erase(t)
		t.queue_free())


# ---------------------------------------------------------------- Projectiles

func troop_projectile(t: Troop, b: Building) -> void:
	var from := t.global_position + Vector3(0, 0.55, 0) - t.global_transform.basis.z * 0.2
	var to := b.global_position + Vector3(0, 0.6, 0)
	var node: Node3D
	if t.kind == "mage":
		node = _orb(Color(1.0, 0.5, 0.15), 0.16)
		Sfx.play("boom", 1.8, -14.0)
	else:
		node = Models.prop(Models.hex("Skeleton_Arrow"))
		node.scale = Vector3.ONE * 0.5
		Sfx.play("bow", randf_range(1.0, 1.2))
	add_child(node)
	var dmg := t.damage
	var splash := float(t.info["splash"])
	_launch(node, from, to, 0.35 if t.kind == "archer" else 0.5, 0.4, func() -> void:
		if splash > 0.0:
			_burst(to, Color(1.0, 0.55, 0.2), splash)
			for other in buildings:
				if not other.destroyed and other.global_position.distance_to(b.global_position) <= splash + 0.2:
					hit_building(other, dmg if other == b else dmg * 0.5, null)
		else:
			hit_building(b, dmg, null))


func _defenses(delta: float) -> void:
	for b in buildings:
		if b.destroyed or not b.is_defense():
			continue
		b.cooldown -= delta
		if b.cooldown > 0.0:
			continue
		var d: Dictionary = GameData.building(b.kind)
		var reach := float(d["range"])
		var min_reach := float(d.get("min_range", 0.0))
		var best: Troop = null
		var best_d := INF
		for t in troops:
			if t.dead:
				continue
			var dist := t.global_position.distance_to(b.global_position)
			if dist <= reach and dist >= min_reach and dist < best_d:
				best_d = dist
				best = t
		if best == null:
			b.cooldown = 0.2
			continue
		b.cooldown = 1.0 / float(d["rate"])
		var dmg := float(GameData.at_level(d["damage"], b.level))
		var from := b.top()
		var victim := best
		if b.kind == "catapult":
			var land := best.global_position
			var rock := Models.prop(Models.hex("projectile_catapult"))
			rock.scale = Vector3.ONE * 1.4
			add_child(rock)
			var splash := float(d["splash"])
			Sfx.play("thud", 0.6, -6.0)
			_launch(rock, from, land, 1.1, 3.5, func() -> void:
				_burst(land, Color(0.6, 0.5, 0.4), splash)
				Sfx.play("boom", 1.0, -6.0)
				rig.shake(0.25)
				for t in troops:
					if not t.dead and t.global_position.distance_to(land) <= splash:
						t.take_damage(dmg))
		else:
			var arrow := Models.prop(Models.hex("Skeleton_Arrow"))
			arrow.scale = Vector3.ONE * 0.5
			add_child(arrow)
			Sfx.play("bow", 0.8, -4.0)
			_launch(arrow, from, victim.global_position + Vector3(0, 0.5, 0), 0.4, 0.5, func() -> void:
				if is_instance_valid(victim) and not victim.dead:
					victim.take_damage(dmg))


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


# ---------------------------------------------------------------- Effects

func _orb(color: Color, radius: float) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	m.mesh = s
	m.material_override = Models.material(color, 4.0)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 2.0
	light.light_energy = 1.5
	m.add_child(light)
	return m


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
	p.global_position = at
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(p.queue_free)


func _burst(at: Vector3, color: Color, radius: float) -> void:
	_puff(at + Vector3(0, 0.3, 0), color, 14)
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


# ---------------------------------------------------------------- End

func finish() -> void:
	if finished:
		return
	finished = true
	_holding = false
	var frac := destruction()
	stars = GameData.stars(frac, town_hall_down)
	Save.finish_raid(level_n, stars, loot_taken, used)
	Ads.match_finished()
	for t in troops:
		if not t.dead:
			t._one_shot("Cheer", 1.0)
	Sfx.play("levelup" if stars > 0 else "deny")
	hud.show_results(stars, frac, loot_taken)


## For the screenshot run: drop the whole army around the village, in waves.
func auto_deploy(count: int) -> void:
	var placed := 0
	var tries := 0
	var angle := randf() * TAU
	for k in GameData.TROOP_ORDER:
		selected = k
		while int(available.get(k, 0)) > 0 and placed < count and tries < 400:
			tries += 1
			angle += 0.55
			var p := Vector3(cos(angle) * 12.5, 0, sin(angle) * 10.8)
			if deploy(p, false):
				placed += 1
