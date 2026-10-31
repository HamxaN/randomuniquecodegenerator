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
	Save.coins = 2400
	Save.stars = {"1": 3, "2": 3, "3": 2, "4": 3, "5": 2, "6": 1}
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
	await _shot("burgerrush-01-menu")
	main.menu.open_days()
	await _wait(0.5)
	await _shot("burgerrush-02-days")
	main.menu.open_upgrades()
	await _wait(0.5)
	await _shot("burgerrush-03-kitchen")
	main.menu.open_chefs()
	await _wait(1.0, 20)
	await _shot("burgerrush-04-chefs")
	main.menu.close_panel()
	# Day 1 with the tutorial pointer.
	main.start_day(1)
	var r: Restaurant = main.restaurant()
	await _wait(0.6, 10)
	await _shot("burgerrush-05-day-intro")
	await _until(func() -> bool: return r.customers.size() > 0 and r.customers[0]["state"] == "wait", 30.0)
	await _wait(0.5, 6)
	await _shot("burgerrush-06-first-order")
	await _until(func() -> bool: return r.kitchen.ready_patty() >= 0 or r.served > 0, 30.0)
	await _shot("burgerrush-07-tutorial")
	await _until(func() -> bool: return r.state == "done", 240.0)
	await _until(func() -> bool: return r.hud._modal.get_child_count() > 0, 10.0)
	await _wait(1.6, 12)
	await _shot("burgerrush-08-day1-results")
	# A busier day with the full menu, mid-rush.
	Save.upgrades = {"grill": 2, "plates": 1, "heat": 2}
	main.start_day(9)
	r = main.restaurant()
	await _until(func() -> bool: return r.served >= 2 and r._waiting_count() >= 3, 120.0)
	await _wait(0.4, 4)
	await _shot("burgerrush-09-rush")
	await _until(func() -> bool: return r.served >= 5, 80.0)
	await _shot("burgerrush-10-busy")
	# The beach shack and the spooky night grill.
	main.start_day(14)
	r = main.restaurant()
	await _until(func() -> bool: return r.served >= 2, 90.0)
	await _shot("burgerrush-11-beach")
	main.start_day(25)
	r = main.restaurant()
	await _until(func() -> bool: return r.served >= 2, 90.0)
	await _shot("burgerrush-12-night")
	r.hud.show_results({"day": 25, "coins": 214, "served": 14, "lost": 1, "stars": 3, "goals": [100, 150, 200]}, true)
	await _wait(1.6, 12)
	await _shot("burgerrush-13-results")
	print("SHOTS DONE")
	get_tree().quit(0)
