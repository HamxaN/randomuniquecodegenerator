class_name Shots
extends Node
## Plays the game by itself and saves screenshots. CI runs it under a virtual
## display with software rendering (a few frames a second), so waits are in game
## time and frames rather than wall-clock seconds.

var main
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 10
	Save.coins = 3200
	Save.xp = 2400
	Save.player_name = "You"
	Save.store()
	_run()


func _wait(seconds: float, frames: int = 10) -> void:
	var t := 0.0
	var f := 0
	while t < seconds or f < frames:
		t += get_process_delta_time()
		f += 1
		await get_tree().process_frame


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		t += get_process_delta_time()
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT %s (%d fps)" % [path, Engine.get_frames_per_second()])


func _run() -> void:
	await _wait(1.5, 30)
	await _shot("lastdrop-01-lobby")
	main.lobby().open("locker")
	await _wait(0.5)
	await _shot("lastdrop-02-locker")
	main.lobby().open("online")
	await _wait(0.5)
	await _shot("lastdrop-03-online")
	main.lobby().open("")
	var m: Match = main.start_offline("squad", true)
	m.local.invulnerable = true
	await _wait(1.5, 20)
	m.local.yaw = 2.2
	await _shot("lastdrop-04-plane")
	await _until(func() -> bool: return m.clock > 5.0, 20.0)
	m.request(m.local, "jump", null)
	await _wait(1.0, 12)
	await _shot("lastdrop-05-freefall")
	await _until(func() -> bool: return m.local.state == "chute", 60.0)
	await _wait(1.0, 10)
	await _shot("lastdrop-06-parachute")
	await _until(func() -> bool: return m.local.state == "ground", 90.0)
	await _wait(1.5, 15)
	await _shot("lastdrop-07-landed")
	# Gear up and meet an enemy squad.
	var f := m.local
	f.brain = null
	f.inv.take(GameData.item("weapon", "ar"))
	f.inv.take({"kind": "attach", "id": "red_dot", "n": 1})
	f.inv.take({"kind": "attach", "id": "grip", "n": 1})
	f.inv.take(GameData.item("weapon", "dmr"))
	f.inv.take({"kind": "ammo", "id": "rifle", "n": 120})
	f.inv.take(GameData.item("vest", "2"))
	f.inv.take(GameData.item("helmet", "2"))
	f.inv.take({"kind": "heal", "id": "bandage", "n": 4})
	f.inv.take({"kind": "grenade", "id": "frag", "n": 2})
	m.hud.refresh_inventory()
	var enemies: Array = []
	for o in m.fighters:
		if o.team != f.team and o.alive() and enemies.size() < 3:
			enemies.append(o)
	var i := 0
	for o in enemies:
		o.state = "ground"
		o.global_position = m.island.ground(f.global_position.x + sin(f.yaw) * 14.0 + i * 2.5 - 2.5, f.global_position.z + cos(f.yaw) * 14.0) + Vector3(0, 0.5, 0)
		o.inv.take(GameData.item("weapon", "smg"))
		o.inv.take({"kind": "ammo", "id": "light", "n": 90})
		o.brain.enemy = f
		i += 1
	await _wait(0.6, 8)
	var target: Fighter = enemies[0] if not enemies.is_empty() else null
	for k in 14:
		if target != null and target.alive():
			var to := target.chest_pos() - f.eye()
			f.yaw = atan2(to.x, to.z)
			f.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			f.try_fire(target.chest_pos())
		await _wait(0.12, 2)
	await _shot("lastdrop-08-firefight")
	f.aiming = true
	m.hud._ads_toggle = true
	await _wait(0.6, 8)
	await _shot("lastdrop-09-aim")
	f.aiming = false
	m.hud._ads_toggle = false
	# Grenade.
	m.throw_local_grenade()
	await _wait(2.9, 14)
	await _shot("lastdrop-10-grenade")
	# Find a car and drive it.
	var v: Vehicle = m.vehicles[0]
	var best := 1e9
	for c in m.vehicles:
		var d: float = c.global_position.distance_to(f.global_position)
		if d < best and not c.wrecked:
			best = d
			v = c
	for o in enemies:
		if o.alive():
			m.eliminate(o, f.id, "ar")
	f.global_position = v.global_position + Vector3(2.5, 0.5, 0)
	await _wait(0.3, 4)
	m.handle(f, "enter", v.id)
	for mate in m.squad(f.team):
		if mate != f and mate.alive():
			mate.global_position = v.global_position + Vector3(-2.5, 0.5, 0)
			m.handle(mate, "enter", v.id)
	v.local_driver = true
	f.yaw = v.heading
	for k in 30:
		v.throttle = 1.0
		v.steer = 0.15
		await _wait(0.1, 2)
	await _shot("lastdrop-11-vehicle")
	v.throttle = 0.0
	m.handle(f, "exit", null)
	await _wait(0.5, 6)
	# The map and a closing zone.
	m.clock = float(Zone.PHASES[0][0]) + float(Zone.PHASES[0][1]) * 0.5
	m.hud._toggle_map()
	await _wait(0.4, 6)
	await _shot("lastdrop-12-map")
	m.hud._toggle_map()
	var zs := m.zone_state()
	var zc: Vector2 = zs["center"]
	var edge: Vector2 = zc + (Vector2(f.global_position.x, f.global_position.z) - zc).normalized() * (float(zs["radius"]) + 25.0)
	f.global_position = m.island.ground(edge.x, edge.y) + Vector3(0, 0.5, 0)
	f.yaw = atan2(zc.x - edge.x, zc.y - edge.y)
	await _wait(1.2, 12)
	await _shot("lastdrop-13-zone")
	# Airdrop.
	m.clock = Match.AIRDROP_TIME + 13.5
	var ad: Vector3 = m.airdrop["pos"]
	var spot := m.island.ground(ad.x + 16.0, ad.z + 16.0)
	for k in 12:
		var a := TAU * k / 12.0
		var p := m.island.ground(ad.x + cos(a) * 34.0, ad.z + sin(a) * 34.0)
		if p.y > 0.5 and m.line_of_sight(p + Vector3(0, 1.7, 0), ad + Vector3(0, 2.0, 0), f, null):
			spot = p
			break
	f.global_position = spot + Vector3(0, 0.5, 0)
	var to_drop := ad - f.global_position
	f.yaw = atan2(to_drop.x, to_drop.z)
	f.pitch = 0.55
	await _wait(1.0, 10)
	await _shot("lastdrop-14-airdrop")
	# Knocked down.
	f.pitch = 0.0
	f.invulnerable = false
	m.apply_damage(f, 500.0, enemies[0].id if not enemies.is_empty() else -1, false, "ar", Vector3.FORWARD)
	await _wait(1.0, 10)
	await _shot("lastdrop-15-knocked")
	# Results.
	for o in m.fighters:
		if o.team != f.team and o.alive():
			m.eliminate(o, f.id, "ar")
	await _until(func() -> bool: return m.phase == "over", 10.0)
	await _wait(1.0, 10)
	await _shot("lastdrop-16-results")
	print("SHOTS DONE")
	get_tree().quit(0)
