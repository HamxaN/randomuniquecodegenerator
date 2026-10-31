class_name Shots
extends Node
## Plays through the game by itself and saves screenshots (CI, software rendering).

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.stars = {"1": 3, "2": 2, "3": 3, "4": 1}
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
	await _shot("kingdomdefense-01-map")
	main.start_level(1)
	var d: Defense = main.defense()
	d.autopilot = false
	await _wait(1.0, 30)
	await _shot("kingdomdefense-02-battlefield")
	var cell: Vector2i = d.road[3] + Hex.DIRS[1]
	if not d.can_build(cell, "archer"):
		cell = d.road[3] + Hex.DIRS[4]
	d.hud.show_build_menu(cell)
	await _wait(0.8, 16)
	await _shot("kingdomdefense-03-build-menu")
	d.hud.close_menu()
	d.gold = 2000
	d.autopilot = true
	d.speed = 2.0
	await _until(func() -> bool: return d.towers.size() >= 6, 20.0)
	await _until(func() -> bool: return d._alive() >= 6, 40.0)
	await _wait(2.0, 12)
	await _shot("kingdomdefense-04-wave")
	var t: Tower = d.towers.values()[0]
	d.hud.show_tower_menu(t)
	await _wait(0.5, 8)
	await _shot("kingdomdefense-05-tower-menu")
	d.hud.close_menu()
	d.rig.distance = 12.0
	d.rig.focus = d.road_points[d.road_points.size() / 2]
	await _wait(3.0, 16)
	await _shot("kingdomdefense-06-closeup")
	d.rig.distance = 19.0
	d.rig.focus = Vector3(0, 0, 1)
	d.gold = 4000
	await _until(func() -> bool: return d.wave >= d.waves or d.state == "done", 220.0)
	await _until(func() -> bool: return d.state == "done", 120.0)
	if d.state != "done":
		d._win()
	await _wait(1.0, 12)
	await _shot("kingdomdefense-07-victory")
	main.start_level(8)
	d = main.defense()
	d.gold = 3000
	d.speed = 2.0
	await _until(func() -> bool: return d._alive() >= 6, 60.0)
	await _wait(2.0, 12)
	await _shot("kingdomdefense-08-snow")
	main.start_level(11)
	d = main.defense()
	d.gold = 3000
	d.speed = 2.0
	await _until(func() -> bool: return d._alive() >= 6, 60.0)
	await _wait(2.0, 12)
	await _shot("kingdomdefense-09-ash")
	print("SHOTS DONE")
	get_tree().quit(0)
