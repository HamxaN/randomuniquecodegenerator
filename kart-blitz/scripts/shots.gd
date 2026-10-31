class_name Shots
extends Node
## Plays through the game by itself and saves screenshots (CI, software rendering).

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 12
	Save.coins = 6400
	Save.unlocked = 6
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
	await _shot("kartblitz-01-garage")
	main.garage().open_upgrades()
	await _wait(0.6)
	await _shot("kartblitz-02-upgrades")
	main.garage().close_panel()
	main.start_race(0)
	var r: Race = main.race()
	await _wait(0.5, 20)
	await _shot("kartblitz-03-grid")
	await _until(func() -> bool: return r.state == "race", 10.0)
	await _wait(0.2, 4)
	await _shot("kartblitz-04-go")
	await _wait(4.0, 30)
	await _shot("kartblitz-05-racing")
	r.player.drift_held = true
	r.player.drifting = true
	r.player.drift_dir = 1.0
	r.player.drift_charge = 2.4
	await _wait(0.4, 6)
	await _shot("kartblitz-06-drift")
	r.player.item = "rocket"
	r.player.item_uses = 1
	r.hud.item_roll("rocket")
	await _wait(0.7, 6)
	await _shot("kartblitz-07-item")
	r.use_item(r.player)
	await _wait(0.6, 6)
	await _shot("kartblitz-08-rocket")
	await _wait(6.0, 30)
	await _shot("kartblitz-09-pack")
	r.hud.show_results()
	await _wait(0.8)
	await _shot("kartblitz-10-results")
	for t in [2, 5]:
		main.start_race(t)
		r = main.race()
		await _until(func() -> bool: return r.state == "race", 10.0)
		await _wait(5.0, 30)
		await _shot("kartblitz-%d-%s" % [11 + (0 if t == 2 else 1), GameData.track(t)["id"]])
	print("SHOTS DONE")
	get_tree().quit(0)
