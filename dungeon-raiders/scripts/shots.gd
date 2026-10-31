class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display with software rendering, so waits are in frames and game time.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 12
	Save.gold = 7200
	Save.store()
	_run()


func _wait(seconds: float, frames: int = 12) -> void:
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
	await _wait(1.5, 40)
	await _shot("dungeonraiders-01-camp")
	main.camp().open_heroes()
	await _wait(0.6)
	await _shot("dungeonraiders-02-heroes")
	main.camp().open_talents()
	await _wait(0.6)
	await _shot("dungeonraiders-03-talents")
	main.camp().close_panel()
	main.start_run()
	var d: Dungeon = main.dungeon()
	# A well-geared demo hero, so the run reaches the boss and beyond.
	d.attack_mult *= 2.2
	d.hero.max_hp *= 3.0
	d.hero.hp = d.hero.max_hp
	await _wait(1.0, 30)
	await _shot("dungeonraiders-04-start-room")
	await _until(func() -> bool: return d.state == "fight", 40.0)
	await _until(func() -> bool: return d._alive() >= 3, 10.0)
	await _wait(1.5, 10)
	await _shot("dungeonraiders-05-fight")
	await _wait(1.5, 10)
	d.skill_cd = 0.0
	d.use_skill()
	await _wait(0.4, 4)
	await _shot("dungeonraiders-06-skill")
	d.autopilot = false
	d.input_move = Vector3.ZERO
	d._drop_item(d.hero.global_position + Vector3(3.0, 0, 0), {"slot": "weapon", "rarity": "epic", "name": "Storm Reaver", "power": 30})
	await _wait(0.8, 6)
	await _shot("dungeonraiders-07-loot")
	d.hero.global_position += Vector3(3.0, 0, 0)
	await _wait(0.6, 6)
	await _shot("dungeonraiders-08-equipped")
	d.autopilot = true
	d.hud.show_boons(GameData.boon_choices(3))
	await _wait(0.5)
	await _shot("dungeonraiders-09-levelup")
	d.hud._close_modal()
	get_tree().paused = false
	await _until(func() -> bool: return d.boss != null or d._portal != null, 150.0)
	await _until(func() -> bool: return d.boss == null or d.boss.spawn_lock <= 0.0, 10.0)
	await _wait(2.0, 12)
	await _shot("dungeonraiders-10-boss")
	await _until(func() -> bool: return d._portal != null or d.state == "dead", 90.0)
	await _wait(1.5, 10)
	await _shot("dungeonraiders-11-portal")
	if d.state != "dead":
		d.hud.floor_cleared()
		await _wait(0.6)
		await _shot("dungeonraiders-12-cleared")
		d.exit_requested.emit(true)
		await _wait(1.2, 30)
		d = main.dungeon()
		d.attack_mult *= 2.2
		d.hero.max_hp *= 3.0
		d.hero.hp = d.hero.max_hp
		await _until(func() -> bool: return d.state == "fight", 40.0)
		await _wait(2.0, 12)
		await _shot("dungeonraiders-13-floor2")
	d.hud.show_results()
	await _wait(0.8)
	await _shot("dungeonraiders-14-results")
	print("SHOTS DONE")
	get_tree().quit(0)
