class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display with software rendering, which is slow, so the waits are in
## game time and frames rather than wall-clock seconds.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Software rendering runs at a few frames a second; let physics keep up.
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 12
	Save.coins = 4200
	Save.xp = 2600
	Save.store()
	_run()


## Waits for [param frames] frames and at least [param seconds] of game time.
func _wait(seconds: float, frames: int = 12) -> void:
	var t := 0.0
	var f := 0
	while t < seconds or f < frames:
		t += get_process_delta_time()
		f += 1
		await get_tree().process_frame


## Waits until [param cond] is true (checked each frame), up to [param limit] seconds of game time.
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


func _close_enemies(a: Arena, n: int, dist: float) -> bool:
	var c := 0
	for u in a.undead:
		if not u.dead and u.spawn_lock <= 0.0 and u.global_position.distance_to(a.player.global_position) < dist:
			c += 1
	return c >= n


func _run() -> void:
	await _wait(1.5, 40)
	await _shot("squadstrike-01-lobby")
	main.lobby().open_operators()
	await _wait(0.6)
	await _shot("squadstrike-02-operators")
	main.lobby().open_armory("dmr")
	await _wait(0.6)
	await _shot("squadstrike-03-armory")
	main.lobby().close_panel()
	main.start_match(0)
	var a: Arena = main.arena()
	await _wait(0.8, 20)
	await _shot("squadstrike-04-deploy")
	await _until(func() -> bool: return _close_enemies(a, 3, 12.0), 40.0)
	await _wait(1.0)
	await _shot("squadstrike-05-contact")
	await _until(func() -> bool: return a.kills >= 4, 40.0)
	await _shot("squadstrike-06-firefight")
	a.grenade_cd = 0.0
	a.throw_grenade()
	await _wait(0.85, 6)
	await _shot("squadstrike-07-grenade")
	a.streak = 1.0
	a.airstrike()
	await _wait(1.4, 10)
	await _shot("squadstrike-08-airstrike")
	await _until(func() -> bool: return a.state == "perk" or a.wave >= 3, 90.0)
	if a.state != "perk":
		a.hud.show_perks(GameData.perk_choices(7))
	await _wait(0.6)
	await _shot("squadstrike-09-perks")
	a.hud._close_modal()
	a.choose_perk(GameData.PERKS[0])
	a.wave = 5
	a.queue.append("boss")
	await _until(func() -> bool: return a.boss != null and a.boss.spawn_lock <= 0.0 and a.boss.global_position.distance_to(a.player.global_position) < 11.0, 60.0)
	await _wait(0.5)
	await _shot("squadstrike-10-boss")
	a.squad_damage_taken = 1.0
	a.player.take_damage(99999.0, Vector3.FORWARD)
	await _wait(0.8)
	await _shot("squadstrike-11-down")
	a.hud._down_label = null
	a.hud.show_results()
	await _wait(0.8)
	await _shot("squadstrike-12-results")
	main.start_match(1)
	a = main.arena()
	await _until(func() -> bool: return _close_enemies(a, 3, 11.0), 40.0)
	await _shot("squadstrike-13-village")
	main.start_match(2)
	a = main.arena()
	await _until(func() -> bool: return _close_enemies(a, 3, 11.0), 40.0)
	await _shot("squadstrike-14-fortress")
	print("SHOTS DONE")
	get_tree().quit(0)
