class_name Match
extends Node3D
## One battle royale match. The same code runs offline (this phone is the
## authority and runs the bots), as a host or dedicated server (authority plus
## network sync), and as an online client (follows the server, predicts its own
## player). The authority decides hits, damage, loot and who wins.

signal finished(results: Dictionary)
signal exit_requested(again: bool)

const PLANE_HEIGHT := 230.0
const PLANE_SPEED := 32.0
const SNAP_RATE := 15.0
const STATE_RATE := 20.0
const REVIVE_TIME := 4.0
const BLEED_RATE := 5.0
const AIRDROP_TIME := 170.0

var seed_value := 0
var mode := "squad"
var authority := true
var networked := false
var visuals := true
var local_id := -1
var island: Island
var zone: Zone
var clock := 0.0
var phase := "plane"  # plane, play, over
var fighters: Array = []
var by_id := {}
var vehicles: Array = []
var loot := {}          # id -> {item, pos, node}
var _loot_grid := {}
var _claims := {}
var _next_loot := 100000
var local: Fighter
var rig: PlayerRig
var hud: Hud
var plane_from := Vector3.ZERO
var plane_to := Vector3.ZERO
var plane_node: Node3D
var airdrop: Dictionary = {}
var results_sent := false
var team_places := {}
var teams_total := 0
var autopilot := false
var _snap_t := 0.0
var _state_t := 0.0
var _zone_tick := 0.0
var _grenades: Array = []
var _tracers: Array = []
var _tracer_i := 0
var _last_phase := 0
var _over_t := 0.0
var _feed_cb: Callable
var _plane_sound_t := 0.0
var snapshots_seen := 0
var _logged_client_shot := false
var inventory_updates := 0


## [param cfg]: seed, mode, authority, networked, visuals, local_id, roster (id,
## name, skin, team, human, peer), bot_skill.
func setup(cfg: Dictionary) -> void:
	seed_value = int(cfg["seed"])
	mode = String(cfg.get("mode", "squad"))
	authority = bool(cfg.get("authority", true))
	networked = bool(cfg.get("networked", false))
	visuals = bool(cfg.get("visuals", true))
	local_id = int(cfg.get("local_id", -1))
	autopilot = bool(cfg.get("autopilot", false))
	island = Island.new()
	island.generate(seed_value)
	add_child(island)
	island.build(visuals)
	zone = Zone.new(seed_value, GameData.ISLAND_RADIUS)
	_plan_plane()
	_spawn_loot()
	_spawn_vehicles()
	var teams := {}
	for info in cfg["roster"]:
		var ctl := Fighter.Ctl.REMOTE
		if int(info["id"]) == local_id:
			ctl = Fighter.Ctl.LOCAL
		elif authority and not bool(info.get("human", false)):
			ctl = Fighter.Ctl.BOT
		var f := Fighter.new()
		f.setup(self, info, ctl, visuals)
		add_child(f)
		f.global_position = plane_pos()
		fighters.append(f)
		by_id[f.id] = f
		teams[f.team] = true
		if ctl == Fighter.Ctl.LOCAL:
			local = f
	teams_total = teams.size()
	if authority:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 555
		var skill_base := float(cfg.get("bot_skill", 0.5))
		var team_targets := {}
		for f in fighters:
			if f.ctl == Fighter.Ctl.BOT:
				f.brain = Bot.new(f, self, clampf(skill_base + rng.randf_range(-0.25, 0.25), 0.15, 0.95))
				if not team_targets.has(f.team):
					team_targets[f.team] = _pick_drop(rng)
				var t: Vector3 = team_targets[f.team]
				var p := t + Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
				f.brain.plan_drop(p, clampf(_progress_of(p) - 0.06 + rng.randf_range(-0.03, 0.03), 0.03, 0.95))
	if autopilot and local != null:
		# The screenshot tour and network test let a bot brain play for us.
		var arng := RandomNumberGenerator.new()
		arng.seed = seed_value + 99
		local.brain = Bot.new(local, self, 0.8)
		var target := _pick_drop(arng)
		local.brain.plan_drop(target, clampf(_progress_of(target) - 0.05, 0.05, 0.9))
	if visuals:
		_build_world_visuals()
		_build_plane()
		if local != null:
			rig = PlayerRig.new()
			rig.game = self
			add_child(rig)
			hud = Hud.new()
			hud.game = self
			add_child(hud)
		else:
			# A dedicated view with no local player (only used for spectating tests).
			rig = PlayerRig.new()
			rig.game = self
			add_child(rig)
	for f in fighters:
		f.set_tag_visible(local != null and f.team == local.team and f != local)


# --- Layout ----------------------------------------------------------------------

func _plan_plane() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 3 + 1
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-90.0, 90.0)
	var half := GameData.ISLAND_RADIUS + 50.0
	plane_from = side - dir * half + Vector3(0, PLANE_HEIGHT, 0)
	plane_to = side + dir * half + Vector3(0, PLANE_HEIGHT, 0)
	# Airdrop: lands inside the third circle a few minutes in.
	var c: Vector2 = zone.centers[2]
	var r := zone.radii[2] * 0.55
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * r
	var p := c + off
	airdrop = {"pos": Vector3(p.x, island.height(p.x, p.y), p.y), "landed": false, "node": null}


func plane_duration() -> float:
	return plane_from.distance_to(plane_to) / PLANE_SPEED


func plane_progress() -> float:
	return clampf(clock / plane_duration(), 0.0, 1.0)


func plane_pos() -> Vector3:
	return plane_from.lerp(plane_to, plane_progress())


func _progress_of(p: Vector3) -> float:
	var a := Vector2(plane_from.x, plane_from.z)
	var b := Vector2(plane_to.x, plane_to.z)
	var ab := b - a
	return clampf((Vector2(p.x, p.z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


func _pick_drop(rng: RandomNumberGenerator) -> Vector3:
	if rng.randf() < 0.75:
		var t: Dictionary = island.towns[rng.randi() % island.towns.size()]
		var c: Vector2 = t["center"]
		return Vector3(c.x, 0, c.y) + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
	return island.loot_spots[rng.randi() % island.loot_spots.size()]


func _spawn_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 3
	var lid := 0
	for spot in island.loot_spots:
		var it := GameData.roll_loot(rng)
		_add_loot(lid, it, spot)
		lid += 1
		if it["kind"] == "weapon":
			var ammo_kind := String(GameData.weapon(String(it["id"]))["ammo"])
			_add_loot(lid, GameData.item("ammo", ammo_kind), spot + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(0.8, 1.4)))
			lid += 1


func _spawn_vehicles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 29 + 11
	var vid := 0
	for spot in island.vehicle_spots:
		var v := Vehicle.new()
		var k: String = Vehicle.KIND_LIST[rng.randi() % Vehicle.KIND_LIST.size()]
		var p: Vector3 = spot["pos"]
		p.y = island.height(p.x, p.z)
		v.setup(self, vid, k, p, float(spot["rot"]), visuals)
		add_child(v)
		vehicles.append(v)
		vid += 1


func vehicle_by_id(vid: int) -> Vehicle:
	for v in vehicles:
		if v.id == vid:
			return v
	return null


# --- Loot ------------------------------------------------------------------------

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 20.0), floori(p.z / 20.0))


func _add_loot(lid: int, it: Dictionary, pos: Vector3) -> void:
	var p := pos
	p.y = island.height(p.x, p.z) + 0.05 if island != null else p.y
	if p.y < Island.SEA_LEVEL - 1.0:
		p.y = Island.SEA_LEVEL - 1.0
	var e := {"item": it, "pos": p, "node": null}
	loot[lid] = e
	var c := _cell(p)
	if not _loot_grid.has(c):
		_loot_grid[c] = []
	(_loot_grid[c] as Array).append(lid)
	if visuals and is_inside_tree():
		e["node"] = _loot_visual(it, p)


func _remove_loot(lid: int) -> void:
	if not loot.has(lid):
		return
	var e: Dictionary = loot[lid]
	var c := _cell(e["pos"])
	if _loot_grid.has(c):
		(_loot_grid[c] as Array).erase(lid)
	if e["node"] != null:
		(e["node"] as Node).queue_free()
	loot.erase(lid)
	_claims.erase(lid)


func loot_near(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var c := _cell(pos)
	var r := int(ceil(radius / 20.0))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if _loot_grid.has(key):
				for lid in _loot_grid[key]:
					if (loot[lid]["pos"] as Vector3).distance_to(pos) <= radius:
						out.append(lid)
	return out


func loot_claimed(lid: int, by: Fighter) -> bool:
	return _claims.has(lid) and _claims[lid] != by.id and by_id.has(_claims[lid]) and (by_id[_claims[lid]] as Fighter).alive()


func claim_loot(lid: int, by: Fighter) -> void:
	_claims[lid] = by.id


## Drops items around [param pos] (death boxes, swapped weapons). Authority only.
func drop_items(items: Array, pos: Vector3) -> void:
	var adds: Array = []
	var i := 0
	for it in items:
		var a := i * 2.399
		var r := 0.6 + 0.35 * sqrt(float(i))
		var p := pos + Vector3(cos(a) * r, 0, sin(a) * r)
		var lid := _next_loot
		_next_loot += 1
		_add_loot(lid, it, p)
		adds.append([lid, it, loot[lid]["pos"]])
		i += 1
	if networked and not adds.is_empty():
		Net.broadcast_event("loot_add", adds)


func _build_world_visuals() -> void:
	for lid in loot:
		var e: Dictionary = loot[lid]
		e["node"] = _loot_visual(e["item"], e["pos"])
	var env := WorldEnvironment.new()
	var e2 := Environment.new()
	e2.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f8fd6")
	sm.sky_horizon_color = Color("bcd9ee")
	sm.ground_horizon_color = Color("bcd9ee")
	sm.ground_bottom_color = Color("2c6f86")
	sky.sky_material = sm
	e2.sky = sky
	e2.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e2.ambient_light_energy = 0.55
	e2.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e2.tonemap_exposure = 0.9
	e2.fog_enabled = true
	e2.fog_light_color = Color("bcd9ee")
	e2.fog_density = 0.0006
	e2.fog_sky_affect = 0.0
	env.environment = e2
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = Save.quality >= 1
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	# Zone wall.
	var wall := MeshInstance3D.new()
	wall.name = "ZoneWall"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 64
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	wall.mesh = cyl
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float stripe = smoothstep(0.35, 0.5, abs(fract(UV.y * 60.0 - TIME * 0.6) - 0.5) * 2.0);
	float edge = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.7, UV.y);
	ALBEDO = mix(vec3(0.25, 0.45, 1.0), vec3(0.55, 0.75, 1.0), stripe);
	ALPHA = (0.22 + 0.18 * stripe) * edge;
}
"""
	var wm := ShaderMaterial.new()
	wm.shader = sh
	wall.material_override = wm
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	# Tracer pool.
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1.0, 0.85, 0.45)
	tm.emission_enabled = true
	tm.emission = Color(1.0, 0.8, 0.4)
	tm.emission_energy_multiplier = 3.0
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 24:
		var t := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.025, 1.0)
		t.mesh = b
		t.material_override = tm
		t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t)
		_tracers.append(t)


func _loot_visual(it: Dictionary, p: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = p
	var col := GameData.item_color(it)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.02
	cm.radial_segments = 16
	cm.rings = 1
	ring.mesh = cm
	ring.material_override = Models.material(Color(col, 0.45), 1.2, true)
	ring.position.y = 0.03
	root.add_child(ring)
	match String(it["kind"]):
		"weapon":
			var g := GunModel.make(it)
			g.rotation = Vector3(0, 0.6, PI / 2)
			g.position.y = 0.12
			g.scale = Vector3.ONE * 1.25
			root.add_child(g)
		_:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			match String(it["kind"]):
				"vest":
					bm.size = Vector3(0.42, 0.42, 0.16)
				"helmet":
					var sp := SphereMesh.new()
					sp.radius = 0.2
					sp.height = 0.24
					sp.is_hemisphere = true
					mi.mesh = sp
				"heal":
					bm.size = Vector3(0.28, 0.18, 0.2)
				"grenade":
					var sp2 := SphereMesh.new()
					sp2.radius = 0.09
					sp2.height = 0.2
					mi.mesh = sp2
				"attach":
					bm.size = Vector3(0.1, 0.1, 0.26)
				_:
					bm.size = Vector3(0.3, 0.2, 0.22)
			if mi.mesh == null:
				mi.mesh = bm
			mi.material_override = Models.material(col.darkened(0.15))
			mi.position.y = 0.16
			root.add_child(mi)
			if it["kind"] == "heal":
				var cross := MeshInstance3D.new()
				var cb := BoxMesh.new()
				cb.size = Vector3(0.2, 0.02, 0.06)
				cross.mesh = cb
				cross.material_override = Models.material(Color.WHITE)
				cross.position.y = 0.26
				root.add_child(cross)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visibility_range_end = 70.0
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(root)
	return root


func _build_plane() -> void:
	plane_node = Node3D.new()
	var body := Models.material(Color("c9ced6"))
	var dark := Models.material(Color("3b4450"))
	var accent := Models.material(Color("ff7a1a"))
	var parts := [
		[Vector3(2.6, 2.6, 16.0), Vector3(0, 0, 0), body],
		[Vector3(22.0, 0.35, 3.2), Vector3(0, 0.2, -0.5), body],
		[Vector3(7.0, 0.3, 2.0), Vector3(0, 0.6, 7.0), body],
		[Vector3(0.3, 3.0, 2.2), Vector3(0, 2.0, 7.0), accent],
		[Vector3(2.0, 1.0, 1.2), Vector3(0, 0.6, -8.2), dark],
		[Vector3(1.4, 1.4, 3.2), Vector3(-5.5, -0.6, -1.0), dark],
		[Vector3(1.4, 1.4, 3.2), Vector3(5.5, -0.6, -1.0), dark],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[0]
		mi.mesh = b
		mi.position = p[1]
		mi.material_override = p[2]
		plane_node.add_child(mi)
	add_child(plane_node)
	plane_node.look_at_from_position(plane_from, plane_to, Vector3.UP)


# --- Main loop ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if authority:
		clock += delta
		_authority_tick(delta)
	else:
		clock += delta
		if local != null and local.brain != null and phase != "over":
			local.brain.update(delta)
	_grenade_tick(delta)
	_airdrop_tick(delta)
	if networked:
		if authority:
			_snap_t -= delta
			if _snap_t <= 0.0:
				_snap_t = 1.0 / SNAP_RATE
				_send_snapshot()
		elif local != null:
			_state_t -= delta
			if _state_t <= 0.0:
				_state_t = 1.0 / STATE_RATE
				_send_state()


func _process(delta: float) -> void:
	if plane_node != null:
		plane_node.visible = clock < plane_duration() + 4.0
		if plane_node.visible:
			plane_node.global_position = plane_from.lerp(plane_to, clock / plane_duration())
	var wall := get_node_or_null("ZoneWall") as MeshInstance3D
	if wall != null:
		var zs := zone_state()
		var c: Vector2 = zs["center"]
		var r := maxf(float(zs["radius"]), 0.5)
		wall.position = Vector3(c.x, 60.0, c.y)
		wall.scale = Vector3(r, 160.0, r)
	if local != null and phase != "over":
		_drive_local(delta)
	if visuals and local != null and local.state == "plane" and clock < plane_duration():
		_plane_sound_t -= delta
		if _plane_sound_t <= 0.0:
			_plane_sound_t = 2.2
			Sfx.play("plane", 1.0, -10.0)


func zone_state() -> Dictionary:
	return zone.state(clock)


func squad(team: int) -> Array:
	var out: Array = []
	for f in fighters:
		if f.team == team:
			out.append(f)
	return out


func alive_count() -> int:
	var n := 0
	for f in fighters:
		if f.alive():
			n += 1
	return n


func alive_teams() -> Array:
	var t := {}
	for f in fighters:
		if f.alive():
			t[f.team] = true
	return t.keys()


func line_of_sight(from: Vector3, to: Vector3, a: Node, b: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4)
	var ex: Array[RID] = [a.get_rid()]
	if b != null:
		ex.append(b.get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- Authority ------------------------------------------------------------------------

func _authority_tick(delta: float) -> void:
	if phase == "over":
		_over_t += delta
		return
	if phase == "plane" and clock >= plane_duration():
		phase = "play"
		for f in fighters:
			if f.state == "plane":
				_do_jump(f)
	for f in fighters:
		if f.brain != null and phase != "over":
			f.brain.update(delta)
	_zone_tick -= delta
	var zs := zone_state()
	if int(zs["phase"]) != _last_phase:
		_last_phase = int(zs["phase"])
	for f in fighters:
		if not f.alive():
			continue
		# Healing, boosts and reviving.
		if f.heal_t > 0.0:
			f.heal_t -= delta
			if f.heal_t <= 0.0:
				_finish_heal(f)
		if f.boost > 0.0:
			f.boost = maxf(0.0, f.boost - delta * 1.6)
			if f.state == "ground" or f.state == "vehicle":
				f.hp = minf(100.0, f.hp + delta * 1.0)
		if f.revive_target != null:
			var t: Fighter = f.revive_target
			if t.state != "knocked" or f.state != "ground" or f.global_position.distance_to(t.global_position) > 3.0:
				_end_revive(f, false)
			else:
				f.revive_t += delta
				if f.revive_t >= REVIVE_TIME:
					_end_revive(f, true)
		if f.state == "knocked":
			f.bleed -= BLEED_RATE * delta
			if f.bleed <= 0.0:
				eliminate(f, f.last_attacker, "bled out")
				continue
	if _zone_tick <= 0.0:
		_zone_tick = 1.0
		for f in fighters:
			if f.alive() and f.state in ["ground", "knocked", "vehicle"] and zone.outside(f.global_position, clock):
				apply_damage(f, float(zs["dps"]), -1, false, "zone", Vector3.ZERO)
	_check_end()


func _check_end() -> void:
	if phase == "over" or clock < plane_duration() * 0.3:
		return
	var teams := alive_teams()
	if teams.size() <= 1:
		phase = "over"
		var winner: int = teams[0] if teams.size() == 1 else -1
		if winner >= 0:
			team_places[winner] = 1
			for f in squad(winner):
				f.place = 1
		var res := results()
		if networked:
			Net.broadcast_event("over", res)
		_on_over(res)


func results() -> Dictionary:
	var rows: Array = []
	for f in fighters:
		rows.append({"id": f.id, "name": f.display_name, "team": f.team, "kills": f.kills, "dmg": int(f.damage_dealt),
			"place": int(team_places.get(f.team, 1)), "human": f.human})
	rows.sort_custom(func(a, b) -> bool: return a["place"] < b["place"] or (a["place"] == b["place"] and a["kills"] > b["kills"]))
	return {"rows": rows, "teams": teams_total, "mode": mode}


func _on_over(res: Dictionary) -> void:
	phase = "over"
	finished.emit(res)
	if hud != null:
		hud.show_results(res)


## Handles something a fighter wants to do. On a client this goes to the server.
func request(f: Fighter, action: String, arg) -> void:
	if not authority:
		if f != local:
			return
		# Predict the simple ones so the game feels instant.
		match action:
			"reload_done":
				f.inv.reload()
			"switch":
				f.inv.switch_to(int(arg))
			"heal":
				f.heal_t = float(GameData.HEALS[String(arg)]["time"])
				f.heal_kind = String(arg)
			"heal_cancel":
				f.heal_t = 0.0
			"jump":
				_do_jump(f)
			"landed":
				return
		Net.send_action(action, arg)
		return
	handle(f, action, arg)


## The authority's side of [method request].
func handle(f: Fighter, action: String, arg) -> void:
	if not f.alive() and action != "spectate":
		return
	match action:
		"jump":
			if f.state == "plane" and clock > 2.0:
				_do_jump(f)
				_squad_jump(f)
		"landed":
			pass
		"pickup":
			_pickup(f, int(arg))
		"reload_done":
			f.inv.reload()
			_sync_inv(f)
		"reload":
			f.start_reload()
		"switch":
			if f.inv.switch_to(int(arg)):
				f.reload_t = 0.0
				_sync_inv(f)
		"heal":
			_start_heal(f, String(arg))
		"heal_cancel":
			f.heal_t = 0.0
			_event_to(f, "heal_stop", null)
		"enter":
			_enter_vehicle(f, int(arg))
		"exit":
			_exit_vehicle(f)
		"revive":
			var t: Fighter = by_id.get(int(arg), null)
			if t != null and t.team == f.team and t.state == "knocked" and f.state == "ground" and f.global_position.distance_to(t.global_position) < 3.0:
				f.revive_target = t
				f.revive_t = 0.0
				t.revived_by = f
				_event_all("revive", [f.id, t.id, REVIVE_TIME])
		"grenade":
			if f.inv.grenades > 0 and f.state == "ground":
				f.inv.grenades -= 1
				var a: Array = arg
				throw_grenade(f, a[0], a[1])
				_sync_inv(f)


func _do_jump(f: Fighter) -> void:
	if f.state != "plane":
		return
	f.state = "fall"
	f.global_position = plane_pos() + Vector3(randf_range(-2, 2), -4.0, randf_range(-2, 2))
	f.velocity = (plane_to - plane_from).normalized() * 12.0
	if f == local and visuals:
		Sfx.play("jump")


## When a human jumps, their AI squadmates follow.
func _squad_jump(f: Fighter) -> void:
	if not f.human:
		return
	for m in squad(f.team):
		if m != f and m.state == "plane" and m.brain != null:
			m.brain.drop_target = f.global_position
			_do_jump(m)
			m.global_position += Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))


func _pickup(f: Fighter, lid: int) -> void:
	if not loot.has(lid) or f.state != "ground":
		return
	var e: Dictionary = loot[lid]
	var reach := 3.2 if f.ctl == Fighter.Ctl.REMOTE else 2.6
	if Vector2(f.global_position.x - e["pos"].x, f.global_position.z - e["pos"].z).length() > reach:
		return
	var it: Dictionary = e["item"]
	if it["kind"] != "weapon" and not f.inv.wants(it):
		return
	var slot := -1
	if it["kind"] == "weapon" and f.inv.weapon_count() == 2:
		slot = f.inv.active
	var out := f.inv.take(it, slot)
	_remove_loot(lid)
	if networked:
		Net.broadcast_event("loot_del", [lid])
	if not out.is_empty():
		drop_items(out, f.global_position)
	if f.reload_t > 0.0 and it["kind"] == "weapon":
		f.reload_t = 0.0
	_sync_inv(f)
	if f == local and visuals:
		Sfx.play("pickup")
		hud.toast("+ " + GameData.item_name(it), GameData.item_color(it))


func _start_heal(f: Fighter, kind: String) -> void:
	if not GameData.HEALS.has(kind) or int(f.inv.heals.get(kind, 0)) <= 0 or f.state != "ground":
		return
	var h: Dictionary = GameData.HEALS[kind]
	if float(h["heal"]) > 0.0 and f.hp >= float(h["cap"]):
		return
	f.heal_t = float(h["time"])
	f.heal_kind = kind
	f.reload_t = 0.0
	_event_to(f, "heal_start", [kind, f.heal_t])
	if f.visuals_ok():
		f.one_shot("Use_Item", 1.0)


func _finish_heal(f: Fighter) -> void:
	var kind := f.heal_kind
	if not f.inv.use_heal(kind):
		return
	var h: Dictionary = GameData.HEALS[kind]
	if float(h["heal"]) > 0.0:
		f.hp = minf(float(h["cap"]), maxf(f.hp, minf(f.hp + float(h["heal"]), float(h["cap"]))))
	f.boost = minf(100.0, f.boost + float(h["boost"]))
	_sync_inv(f)
	_event_to(f, "heal_done", kind)


func _end_revive(f: Fighter, success: bool) -> void:
	var t: Fighter = f.revive_target
	f.revive_target = null
	f.revive_t = 0.0
	if t != null:
		t.revived_by = null
		if success:
			t.set_revived()
	_event_all("revive_end", [f.id, t.id if t != null else -1, success])


func _enter_vehicle(f: Fighter, vid: int) -> void:
	var v := vehicle_by_id(vid)
	if v == null or v.wrecked or f.state != "ground" or f.global_position.distance_to(v.global_position) > 6.5:
		return
	var s := v.free_seat(f.human)
	if s < 0:
		return
	v.seats[s] = f.id
	f.state = "vehicle"
	f.vehicle = v
	f.seat = s
	f.collision_layer = 0
	f.collision_mask = 0
	f.heal_t = 0.0
	f.reload_t = 0.0
	_apply_seat(f, v, s)
	_event_all("seat", [f.id, vid, s])


func _exit_vehicle(f: Fighter) -> void:
	if f.state != "vehicle" or f.vehicle == null:
		return
	var v: Vehicle = f.vehicle
	var s := f.seat
	v.leave(f)
	f.global_position = v.exit_position(s)
	f.velocity = Vector3.ZERO
	_apply_unseat(f, v)
	_event_all("seat", [f.id, -1, -1, f.global_position])


func _apply_seat(f: Fighter, v: Vehicle, s: int) -> void:
	f.state = "vehicle"
	f.vehicle = v
	f.seat = s
	f.collision_layer = 0
	f.collision_mask = 0
	if s < v.seats.size():
		v.seats[s] = f.id
	v.local_driver = s == 0 and f.ctl == Fighter.Ctl.LOCAL
	if visuals and f._model != null:
		f._model.visible = v.kind == "bike"


func _apply_unseat(f: Fighter, v: Vehicle) -> void:
	f.state = "ground"
	f.vehicle = null
	f.seat = -1
	f.collision_layer = 2
	f.collision_mask = 1 | 4
	if v != null:
		v.leave(f)
		if v.driver() < 0:
			v.local_driver = false
			v.throttle = 0.0


func run_over(v: Vehicle, f: Fighter, spd: float) -> void:
	if spd < 7.0 or not f.alive():
		return
	var driver: Fighter = by_id.get(v.driver(), null)
	if driver != null and driver.team == f.team:
		return
	apply_damage(f, spd * 3.5, driver.id if driver != null else -1, false, "vehicle", v.forward())
	v.speed *= 0.7


func damage_vehicle(v: Vehicle, dmg: float, attacker: int) -> void:
	if v.wrecked:
		return
	v.hp -= dmg
	if v.hp <= 0.0:
		v.set_wrecked()
		explode(v.global_position + Vector3(0, 1, 0), 130.0, 7.0, attacker, "explosion")
		for sid in v.seats.duplicate():
			var f: Fighter = by_id.get(int(sid), null)
			if f != null and f.state == "vehicle":
				_exit_vehicle(f)


# --- Combat ------------------------------------------------------------------------------

## A fighter fired. The authority resolves it; a client shows it and tells the server.
func fire(f: Fighter, origin: Vector3, dirs: PackedVector3Array) -> void:
	var w := f.inv.current()
	var wid := String(w.get("id", "pistol"))
	var quiet := bool(GameData.stats(w)["quiet"]) if not w.is_empty() else false
	if authority:
		var ends := resolve_shot(f, origin, dirs, wid)
		if visuals:
			for e in ends:
				f.shot_fx(e, wid, quiet)
		if networked:
			Net.broadcast_shot(f.id, ends, GameData.WEAPONS.keys().find(wid), quiet, f.peer)
	else:
		for d in dirs:
			var hit := _ray(origin, origin + d * 400.0, f)
			f.shot_fx(hit.get("position", origin + d * 400.0), wid, quiet)
		Net.send_fire(origin, dirs)
		if visuals and f == local:
			rig.kick(float(GameData.stats(w)["recoil"]))


## Called on the server when a client says it fired.
func client_fired(f: Fighter, origin: Vector3, dirs: PackedVector3Array) -> void:
	if not _logged_client_shot:
		_logged_client_shot = true
		print("first shot from a client (%s)" % f.display_name)
	if not f.can_shoot() and f.state != "ground":
		return
	if origin.distance_to(f.eye()) > 3.5:
		origin = f.eye()
	var w := f.inv.current()
	if w.is_empty():
		return
	f.inv.use_round()
	f.fired_t = 0.35
	var wid := String(w["id"])
	var ends := resolve_shot(f, origin, dirs, wid)
	if visuals:
		for e in ends:
			f.shot_fx(e, wid, bool(GameData.stats(w)["quiet"]))
	Net.broadcast_shot(f.id, ends, GameData.WEAPONS.keys().find(wid), bool(GameData.stats(w)["quiet"]), f.peer)


func _ray(from: Vector3, to: Vector3, f: Fighter) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4)
	var ex: Array[RID] = [f.get_rid()]
	if f.vehicle != null:
		ex.append(f.vehicle.get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q)


func resolve_shot(f: Fighter, origin: Vector3, dirs: PackedVector3Array, wid: String) -> Array:
	var ends: Array = []
	var s := GameData.stats(f.inv.current()) if not f.inv.current().is_empty() else GameData.weapon(wid)
	var dmg := float(s["dmg"])
	var total := {}
	var heads := {}
	for d in dirs:
		var to := origin + d.normalized() * 400.0
		var hit := _ray(origin, to, f)
		if hit.is_empty():
			ends.append(to)
			continue
		var p: Vector3 = hit["position"]
		ends.append(p)
		var c = hit["collider"]
		if c is Fighter:
			var v := c as Fighter
			if v.team == f.team:
				continue
			var head := int(hit.get("shape", 0)) == 1
			var amount := dmg * GameData.falloff(wid, origin.distance_to(p)) * (float(s["head"]) if head else 1.0)
			total[v] = float(total.get(v, 0.0)) + amount
			heads[v] = heads.get(v, false) or head
		elif c is Vehicle:
			damage_vehicle(c as Vehicle, dmg * 0.5, f.id)
	for v in total:
		apply_damage(v, total[v], f.id, heads[v], wid, (v.global_position - origin).normalized())
	return ends


func apply_damage(v: Fighter, raw: float, attacker_id: int, head: bool, cause: String, dir: Vector3) -> void:
	if not v.alive() or v.state in ["plane", "fall", "chute"] and cause != "zone":
		return
	var att: Fighter = by_id.get(attacker_id, null)
	if att != null and att.team == v.team and att != v:
		return
	if v.invulnerable:
		return
	var dmg := raw
	if cause != "zone" and cause != "explosion" and cause != "vehicle":
		dmg = GameData.mitigate(raw, head, v.inv.vest, v.inv.helmet)
	if v.state == "vehicle" and cause != "zone" and v.vehicle != null and v.vehicle.kind != "bike":
		dmg *= 0.6
	if att != null:
		v.last_attacker = att.id
		att.damage_dealt += minf(dmg, v.hp if v.state != "knocked" else v.bleed)
	var outcome := "hit"
	if v.state == "knocked":
		v.bleed -= dmg
		if v.bleed <= 0.0:
			eliminate(v, attacker_id, cause)
			outcome = "kill"
	else:
		v.hp -= dmg
		if v.hp <= 0.0:
			if mode == "squad" and _has_standing_mate(v):
				if v.state == "vehicle":
					_exit_vehicle(v)
				v.hp = 0.0
				v.set_knocked()
				if att != null:
					att.knocks += 1
				outcome = "knock"
				_event_all("feed", [att.display_name if att != null else "", v.display_name, cause, "knock",
					att.team if att != null else -1, v.team])
			else:
				eliminate(v, attacker_id, cause)
				outcome = "kill"
	# Feedback for the shooter and the victim.
	if att != null and att != v:
		_event_to(att, "hit", [dmg, head, outcome, v.id])
	_event_to(v, "hurt", [dmg, dir, cause])


func _has_standing_mate(v: Fighter) -> bool:
	for m in squad(v.team):
		if m != v and m.alive() and m.state != "knocked":
			return true
	return false


func eliminate(v: Fighter, killer_id: int, cause: String) -> void:
	if not v.alive():
		return
	var killer: Fighter = by_id.get(killer_id, null)
	if v.state == "vehicle":
		_exit_vehicle(v)
	if v.revive_target != null:
		_end_revive(v, false)
	var items := v.inv.drop_all()
	var pos := v.global_position
	v.inv = Inventory.new()
	v.set_dead()
	if killer != null and killer != v and killer.team != v.team:
		killer.kills += 1
	drop_items(items, pos)
	_event_all("feed", [killer.display_name if killer != null else "", v.display_name, cause, "kill",
		killer.team if killer != null else -1, v.team])
	# Team wiped?
	var standing := false
	for m in squad(v.team):
		if m.alive() and m.state != "knocked":
			standing = true
	if not standing:
		for m in squad(v.team):
			if m.alive():
				m.inv = Inventory.new()
				m.set_dead()
		var remaining := alive_teams().size()
		team_places[v.team] = remaining + 1
		for m in squad(v.team):
			m.place = remaining + 1
		_event_all("team_out", [v.team, remaining + 1])


func explode(pos: Vector3, dmg: float, radius: float, attacker_id: int, cause: String) -> void:
	if visuals:
		boom_fx(pos)
	if networked and authority:
		Net.broadcast_event("boom", pos)
	if not authority:
		return
	for f in fighters:
		if not f.alive() or f.state in ["plane", "fall", "chute"]:
			continue
		var d: float = f.chest_pos().distance_to(pos)
		if d < radius and line_of_sight(pos + Vector3(0, 0.3, 0), f.chest_pos(), f, null):
			apply_damage(f, dmg * (1.0 - d / radius * 0.75), attacker_id, false, cause, (f.global_position - pos).normalized())
	for v in vehicles:
		var d2: float = v.global_position.distance_to(pos)
		if d2 < radius:
			damage_vehicle(v, dmg * (1.0 - d2 / radius), attacker_id)


# --- Grenades ----------------------------------------------------------------------------

func throw_grenade(f: Fighter, origin: Vector3, vel: Vector3) -> void:
	_grenades.append({"pos": origin, "vel": vel, "t": 2.6, "owner": f.id, "node": null})
	if visuals:
		_grenades[_grenades.size() - 1]["node"] = _nade_visual()
	if networked and authority:
		Net.broadcast_event("nade", [f.id, origin, vel])


func _nade_visual() -> Node3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	mi.mesh = sm
	mi.material_override = Models.material(Color("4b5d2a"))
	add_child(mi)
	return mi


func _grenade_tick(delta: float) -> void:
	for g in _grenades.duplicate():
		g["t"] = float(g["t"]) - delta
		var vel: Vector3 = g["vel"]
		vel.y -= 18.0 * delta
		var p: Vector3 = g["pos"]
		var np := p + vel * delta
		var q := PhysicsRayQueryParameters3D.create(p, np, 1 | 4)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			vel = vel.bounce(n) * 0.45
			np = (hit["position"] as Vector3) + n * 0.05
		g["vel"] = vel
		g["pos"] = np
		if g["node"] != null:
			(g["node"] as Node3D).global_position = np
		if float(g["t"]) <= 0.0:
			_grenades.erase(g)
			if g["node"] != null:
				(g["node"] as Node).queue_free()
			if authority:
				explode(np, GameData.GRENADE_DAMAGE, GameData.GRENADE_RADIUS, int(g["owner"]), "grenade")


# --- Airdrop ---------------------------------------------------------------------------

func _airdrop_tick(_delta: float) -> void:
	if airdrop.is_empty() or bool(airdrop["landed"]):
		return
	var start := AIRDROP_TIME
	if clock < start:
		return
	var fall := 18.0
	var k := clampf((clock - start) / fall, 0.0, 1.0)
	var ground: Vector3 = airdrop["pos"]
	var pos := ground + Vector3(0, (1.0 - k) * 160.0, 0)
	if visuals:
		if airdrop["node"] == null:
			airdrop["node"] = _airdrop_visual()
			if hud != null:
				hud.toast("Airdrop incoming! Check the map", Color("ff4a4a"))
		(airdrop["node"] as Node3D).global_position = pos
		var chute := (airdrop["node"] as Node3D).get_node_or_null("Chute")
		if chute != null:
			chute.visible = k < 1.0
	if k >= 1.0:
		airdrop["landed"] = true
		if authority:
			var items := [GameData.item("weapon", "sniper"), {"kind": "ammo", "id": "heavy", "n": 20},
				GameData.item("vest", "3"), GameData.item("helmet", "3"), {"kind": "attach", "id": "scope8", "n": 1},
				{"kind": "heal", "id": "medkit", "n": 2}]
			items[0]["att"] = {"muzzle": "silencer"}
			drop_items(items, ground + Vector3(0, 0, 2.0))


func _airdrop_visual() -> Node3D:
	var root := Node3D.new()
	var crate := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.6, 1.2, 1.6)
	crate.mesh = b
	crate.material_override = Models.material(Color("c0392b"))
	crate.position.y = 0.6
	root.add_child(crate)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.65, 0.2, 1.65)
	band.mesh = bb
	band.material_override = Models.material(Color("f1c40f"), 0.8)
	band.position.y = 0.75
	root.add_child(band)
	var chute := MeshInstance3D.new()
	chute.name = "Chute"
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 2.4
	sm.is_hemisphere = true
	chute.mesh = sm
	var cm := Models.material(Color("ecf0f1"))
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	chute.material_override = cm
	chute.position.y = 6.0
	root.add_child(chute)
	var smoke := CPUParticles3D.new()
	smoke.amount = 30
	smoke.lifetime = 4.0
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 5.0
	smoke.gravity = Vector3(0.4, 0.5, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.8
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 6
	pm.rings = 3
	smoke.mesh = pm
	smoke.material_override = Models.material(Color(1.0, 0.25, 0.2, 0.55), 0.6)
	smoke.position.y = 1.4
	root.add_child(smoke)
	add_child(root)
	return root


# --- Effects -------------------------------------------------------------------------------

func tracer(from: Vector3, to: Vector3) -> void:
	if _tracers.is_empty():
		return
	var t: MeshInstance3D = _tracers[_tracer_i]
	_tracer_i = (_tracer_i + 1) % _tracers.size()
	var len := from.distance_to(to)
	if len < 0.5:
		return
	var mid := from.lerp(to, 0.5)
	t.visible = true
	t.global_position = mid
	t.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	t.scale = Vector3(1, 1, minf(len, 60.0))
	t.global_position = from.lerp(to, minf(30.0, len * 0.5) / len) if len > 60.0 else mid
	var tw := t.create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: t.visible = false)
	_impact_fx(to)


func _impact_fx(at: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(at) > 80.0:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	mi.mesh = sm
	mi.material_override = Models.material(Color(0.85, 0.8, 0.7, 0.8))
	add_child(mi)
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.5, 0.25)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.25)
	tw.tween_callback(mi.queue_free)


func boom_fx(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	mi.material_override = Models.material(Color(1.0, 0.55, 0.15, 0.9), 4.0, true)
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.4
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 5.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.45)
	tw.tween_callback(mi.queue_free)
	Sfx.play_at("crash", pos, 0.6)
	if hud != null and local != null and local.global_position.distance_to(pos) < 20.0:
		hud.shake(0.5)


# --- Events (authority -> one fighter / everyone) --------------------------------------------

func _event_to(f: Fighter, kind: String, data) -> void:
	if f == null:
		return
	if f == local:
		on_event(kind, data)
	elif networked and f.human and f.peer > 0:
		Net.send_event(f.peer, kind, data)


func _event_all(kind: String, data) -> void:
	if visuals:
		on_event(kind, data)
	if networked and authority:
		Net.broadcast_event(kind, data)


func _sync_inv(f: Fighter) -> void:
	if networked and f.human and f.peer > 0 and f != local:
		Net.send_inventory(f.peer, f.inv.to_dict(), f.hp, f.boost)
	if f == local and hud != null:
		hud.refresh_inventory()


## Applies an event from the authority (or locally when we are it).
func on_event(kind: String, data) -> void:
	match kind:
		"hit":
			if hud != null:
				hud.hit_marker(float(data[0]), bool(data[1]), String(data[2]))
		"hurt":
			if hud != null:
				hud.hurt(float(data[0]), data[1], String(data[2]))
		"feed":
			if hud != null:
				hud.feed(data)
		"team_out":
			if hud != null and local != null and int(data[0]) == local.team:
				hud.team_out(int(data[1]))
		"over":
			if not authority:
				_on_over(data)
		"loot_add":
			if not authority:
				for a in data:
					_add_loot(int(a[0]), a[1], a[2])
		"loot_del":
			if not authority:
				for lid in data:
					_remove_loot(int(lid))
		"seat":
			if not authority:
				var f: Fighter = by_id.get(int(data[0]), null)
				if f != null:
					if int(data[1]) >= 0:
						var v := vehicle_by_id(int(data[1]))
						if v != null:
							_apply_seat(f, v, int(data[2]))
					else:
						var old: Vehicle = f.vehicle
						_apply_unseat(f, old)
						if f == local and data.size() > 3:
							f.global_position = data[3]
						if visuals and f._model != null:
							f._model.visible = true
			else:
				var f2: Fighter = by_id.get(int(data[0]), null)
				if f2 != null and int(data[1]) < 0 and visuals and f2._model != null:
					f2._model.visible = true
		"revive":
			if hud != null:
				hud.revive_started(int(data[0]), int(data[1]), float(data[2]))
		"revive_end":
			if hud != null:
				hud.revive_ended(int(data[0]), int(data[1]), bool(data[2]))
		"heal_start":
			if local != null and not authority:
				local.heal_t = float(data[1])
				local.heal_kind = String(data[0])
		"heal_stop", "heal_done":
			if local != null and not authority:
				local.heal_t = 0.0
			if hud != null:
				hud.refresh_inventory()
		"nade":
			if not authority:
				var who: Fighter = by_id.get(int(data[0]), null)
				if who != local:
					throw_grenade(who if who != null else local, data[1], data[2])
		"boom":
			if not authority:
				boom_fx(data)
				for g in _grenades.duplicate():
					if (g["pos"] as Vector3).distance_to(data) < 4.0:
						_grenades.erase(g)
						if g["node"] != null:
							(g["node"] as Node).queue_free()


# --- Network sync -------------------------------------------------------------------------------

func _send_snapshot() -> void:
	var data := PackedFloat32Array()
	data.append(clock)
	data.append(float(alive_count()))
	data.append(float(fighters.size()))
	data.append(float(vehicles.size()))
	for f in fighters:
		var vs := -1.0
		if f.state == "vehicle" and f.vehicle != null:
			vs = f.vehicle.id * 10 + f.seat
		data.append_array(PackedFloat32Array([f.id, f.global_position.x, f.global_position.y, f.global_position.z,
			f.yaw, f.pitch, f.state_code(), f.flags(), f.hp if f.state != "knocked" else f.bleed, f.weapon_code(), f.scope_code(), vs]))
	for v in vehicles:
		data.append_array(PackedFloat32Array([v.id, v.global_position.x, v.global_position.y, v.global_position.z,
			v.heading, v.speed, v.hp]))
	Net.broadcast_snapshot(data)


func on_snapshot(data: PackedFloat32Array) -> void:
	if data.size() < 4:
		return
	snapshots_seen += 1
	var t := data[0]
	if absf(t - clock) > 1.0:
		clock = t
	else:
		clock = lerpf(clock, t, 0.15)
	var nf := int(data[2])
	var nv := int(data[3])
	var i := 4
	for k in nf:
		var fid := int(data[i])
		var f: Fighter = by_id.get(fid, null)
		if f != null:
			var pos := Vector3(data[i + 1], data[i + 2], data[i + 3])
			var st := int(data[i + 6])
			if f == local:
				_reconcile_local(f, pos, st, data[i + 8])
			else:
				f.push_state(t, pos, data[i + 4], data[i + 5], st, int(data[i + 7]), data[i + 8], int(data[i + 9]), int(data[i + 10]))
		i += 12
	for k in nv:
		var v := vehicle_by_id(int(data[i]))
		if v != null:
			var seat_ids: Array = []
			seat_ids.resize(v.seats.size())
			seat_ids.fill(-1)
			for f in fighters:
				if f.state == "vehicle" and f.vehicle == v and f.seat >= 0 and f.seat < seat_ids.size():
					seat_ids[f.seat] = f.id
			v.push_state(t, Vector3(data[i + 1], data[i + 2], data[i + 3]), data[i + 4], data[i + 5], data[i + 6], seat_ids)
		i += 7


## The server's view of our own player: take its health and life state; keep our position
## unless the server moved us (knocked, revived, eliminated, or far off).
func _reconcile_local(f: Fighter, pos: Vector3, st: int, health: float) -> void:
	var server_state: String = Fighter.STATES[clampi(st, 0, Fighter.STATES.size() - 1)]
	if server_state == "knocked":
		if f.state != "knocked":
			f.set_knocked()
		f.bleed = health
	else:
		f.hp = health
	if server_state == "dead" and f.state != "dead":
		f.set_dead()
	elif server_state == "ground" and f.state == "knocked":
		f.set_revived()
	elif server_state == "plane" and f.state != "plane":
		pass
	if f.state in ["ground", "knocked"] and pos.distance_to(f.global_position) > 12.0 and server_state != "plane":
		f.global_position = pos


func _send_state() -> void:
	var f := local
	if f == null:
		return
	var d := PackedFloat32Array([clock, f.global_position.x, f.global_position.y, f.global_position.z, f.yaw, f.pitch,
		f.state_code(), f.flags(), f.weapon_code(), f.scope_code()])
	if f.state == "vehicle" and f.vehicle != null and f.seat == 0:
		var v: Vehicle = f.vehicle
		d.append_array(PackedFloat32Array([v.id, v.global_position.x, v.global_position.y, v.global_position.z, v.heading, v.speed]))
	Net.send_state(d)


## The server applies a client's report about its own player.
func on_client_state(f: Fighter, d: PackedFloat32Array) -> void:
	if d.size() < 10 or not f.alive():
		return
	var pos := Vector3(d[1], d[2], d[3])
	var reported: String = Fighter.STATES[clampi(int(d[6]), 0, Fighter.STATES.size() - 1)]
	var movable := ["fall", "chute", "ground"]
	if f.state in movable and reported in movable:
		f.state = reported
	if f.state in ["fall", "chute", "ground", "knocked"]:
		f.global_position = pos
	f.yaw = d[4]
	f.pitch = d[5]
	f.flags_remote = int(d[7])
	f.aiming = bool(int(d[7]) & 1)
	f.swimming = bool(int(d[7]) & 16)
	if d.size() >= 16 and f.state == "vehicle" and f.seat == 0 and f.vehicle != null and int(d[10]) == f.vehicle.id:
		var v: Vehicle = f.vehicle
		v.global_position = Vector3(d[11], d[12], d[13])
		v.heading = d[14]
		v.rotation.y = v.heading
		v.speed = d[15]
		v.throttle = 0.0
		for sid in v.seats:
			var m: Fighter = by_id.get(int(sid), null)
			if m != null:
				m.global_position = v.seat_position(m.seat)


## Shot effects from the server for someone else's shot.
func on_shot(shooter_id: int, ends: Array, wcode: int, quiet: bool) -> void:
	var f: Fighter = by_id.get(shooter_id, null)
	if f == null or f == local:
		return
	var wid: String = GameData.WEAPONS.keys()[clampi(wcode, 0, GameData.WEAPONS.size() - 1)]
	for e in ends:
		f.shot_fx(e, wid, quiet)


func on_inventory(d: Dictionary, health: float, boost: float) -> void:
	if local == null:
		return
	inventory_updates += 1
	local.inv.from_dict(d)
	if local.state != "knocked":
		local.hp = health
	local.boost = boost
	if hud != null:
		hud.refresh_inventory()


# --- Local player control ---------------------------------------------------------------------

func _drive_local(delta: float) -> void:
	if hud == null or rig == null:
		return
	var f := local
	if autopilot and f.brain != null:
		return
	hud.apply_to(f, delta)
	if f.state == "vehicle" and f.vehicle != null and f.seat == 0:
		var v: Vehicle = f.vehicle
		v.local_driver = true
		v.throttle = hud.move_vec().y
		v.steer = hud.move_vec().x
	if f.alive() and hud.fire_held() and f.state == "ground":
		if f.try_fire(rig.aim_point()):
			rig.kick(float(GameData.stats(f.inv.current())["recoil"]))
	# Auto pick up ammo, heals and upgrades walked over.
	if f.state == "ground" and Engine.get_physics_frames() % 6 == 0:
		for lid in loot_near(f.global_position, 1.7):
			var it: Dictionary = loot[lid]["item"]
			if it["kind"] != "weapon" and f.inv.wants(it) and not _claims.has(lid):
				_claims[lid] = f.id
				request(f, "pickup", lid)
				break


## What the interact button would do right now: {kind, label, arg}.
func local_context() -> Dictionary:
	var f := local
	if f == null or not f.alive():
		return {}
	if f.state == "vehicle":
		return {"kind": "exit", "label": "Get out", "arg": null}
	if f.state != "ground":
		return {}
	for m in squad(f.team):
		if m != f and m.state == "knocked" and m.global_position.distance_to(f.global_position) < 2.6:
			return {"kind": "revive", "label": "Revive " + m.display_name, "arg": m.id}
	var best_v: Vehicle = null
	var bd := 5.5
	for v in vehicles:
		var d: float = v.global_position.distance_to(f.global_position)
		if d < bd and not v.wrecked and v.free_seat(true) >= 0:
			bd = d
			best_v = v
	var best_l := -1
	var bl := 2.4
	for lid in loot_near(f.global_position, 2.4):
		var it: Dictionary = loot[lid]["item"]
		var d2: float = Vector2(f.global_position.x - loot[lid]["pos"].x, f.global_position.z - loot[lid]["pos"].z).length()
		if it["kind"] == "weapon" and d2 < bl:
			bl = d2
			best_l = lid
	if best_l >= 0:
		var it2: Dictionary = loot[best_l]["item"]
		var label := ("Swap for " if f.inv.weapon_count() == 2 else "Pick up ") + GameData.item_name(it2)
		return {"kind": "pickup", "label": label, "arg": best_l}
	if best_v != null:
		return {"kind": "enter", "label": "Drive" if best_v.free_seat(true) == 0 else "Ride", "arg": best_v.id}
	return {}


func interact() -> void:
	var c := local_context()
	if c.is_empty():
		return
	match String(c["kind"]):
		"exit":
			request(local, "exit", null)
		"revive":
			request(local, "revive", c["arg"])
		"pickup":
			request(local, "pickup", c["arg"])
		"enter":
			request(local, "enter", c["arg"])
			var v := vehicle_by_id(int(c["arg"]))
			if authority and v != null:
				# AI squadmates nearby hop in too.
				for m in squad(local.team):
					if m != local and m.brain != null and m.state == "ground" and m.global_position.distance_to(v.global_position) < 15.0:
						handle(m, "enter", v.id)


func throw_local_grenade() -> void:
	var f := local
	if f == null or f.inv.grenades <= 0 or f.state != "ground":
		return
	var dir := rig.aim_dir()
	var origin := f.eye() + dir * 0.6
	var vel := dir * 17.0 + Vector3(0, 4.0, 0)
	f.one_shot("Throw", 1.6)
	if authority:
		handle(f, "grenade", [origin, vel])
	else:
		f.inv.grenades -= 1
		throw_grenade(f, origin, vel)
		Net.send_action("grenade", [origin, vel])
	if hud != null:
		hud.refresh_inventory()
