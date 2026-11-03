class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display with software rendering, so waits are in frames and game time.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.gold = 3200
	Save.best_time = 412.0
	Save.best_kills = 980
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
	await _wait(1.5, 30)
	await _shot("nightsurvivors-01-camp")
	main.camp().open_heroes()
	await _wait(1.0, 16)
	await _shot("nightsurvivors-02-heroes")
	main.camp().open_powerups()
	await _wait(0.5, 8)
	await _shot("nightsurvivors-03-powerups")
	main.camp().close_panel()
	main.start_run()
	var f: Field = main.field()
	await _wait(3.0, 24)
	await _shot("nightsurvivors-04-first-steps")
	# Later in the night the horde is much bigger.
	f.clock = 150.0
	f.god = true
	await _until(func() -> bool: return f.enemies.size() >= 60, 30.0)
	await _wait(2.0, 16)
	await _shot("nightsurvivors-05-horde")
	f.autopilot = false
	f.run.xp = GameData.xp_to_next(f.run.level) - 1
	f._gain_xp(5)
	await _wait(0.6, 8)
	await _shot("nightsurvivors-06-level-up")
	var cards: Array[Dictionary] = f.run.choices(RandomNumberGenerator.new())
	f.hud._clear()
	get_tree().paused = false
	f.choose(cards[0])
	f.autopilot = true
	# A full arsenal.
	f.run.weapons = {"axes": 4, "bolt": 4, "daggers": 3, "aura": 3, "lightning": 4, "bomb": 3}
	f.run.relics = {"might": 3, "area": 2, "magnet": 2}
	await _wait(2.5, 20)
	await _shot("nightsurvivors-07-arsenal")
	f.swarm(36)
	await _wait(1.2, 10)
	await _shot("nightsurvivors-08-swarm")
	f.clock = 179.0
	await _until(func() -> bool: return not f.boss.is_empty(), 10.0)
	await _wait(3.0, 20)
	await _shot("nightsurvivors-09-boss")
	# The Pumpkin Patch at dawn.
	Save.map = "patch"
	main.start_run()
	f = main.field()
	f.god = true
	f.run.weapons = {"bomb": 4, "lightning": 3, "axes": 3}
	f.clock = 420.0
	await _wait(3.0, 24)
	await _shot("nightsurvivors-10-pumpkin-patch")
	f.clock = GameData.NIGHT_LENGTH - 0.5
	await _until(func() -> bool: return f.hud._modal.get_child_count() > 0, 20.0)
	await _wait(1.0, 10)
	await _shot("nightsurvivors-11-dawn")
	print("SHOTS DONE")
	get_tree().quit(0)
