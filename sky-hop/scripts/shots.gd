class_name Shots
extends Node
## Plays through the game by itself and saves screenshots (CI, software rendering).
## The hopper is moved along the course to show its different parts.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 12
	Save.coins = 820
	Save.stars = {"1": 3, "2": 2, "3": 3, "4": 1, "5": 2, "6": 3}
	Save.store()
	_run()


func _wait(seconds: float, frames: int = 12) -> void:
	var t := 0.0
	var f := 0
	while t < seconds or f < frames:
		t += get_process_delta_time()
		f += 1
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT %s (%d fps)" % [path, Engine.get_frames_per_second()])


func _goto(l: Level, piece: int) -> void:
	var pieces: Array = l.course["pieces"]
	var p: Dictionary = pieces[clampi(piece, 0, pieces.size() - 1)]
	l.player.global_position = (p["pos"] as Vector3) + Vector3(0, 1.2, 0.6)
	l.player.velocity = Vector3.ZERO


func _find(l: Level, kind: String) -> int:
	var pieces: Array = l.course["pieces"]
	for i in pieces.size():
		if pieces[i]["kind"] == kind:
			return i
	return 3


func _run() -> void:
	await _wait(1.5, 40)
	await _shot("skyhop-01-map")
	main.world_map().open_levels()
	await _wait(0.6)
	await _shot("skyhop-02-levels")
	main.world_map().open_skins()
	await _wait(0.6)
	await _shot("skyhop-03-skins")
	main.world_map().close_panel()
	main.start_level(2)
	var l: Level = main.level()
	await _wait(1.0, 30)
	await _shot("skyhop-04-start")
	l.player.input = Vector2(0, -1)
	l.player.jump()
	await _wait(0.35, 5)
	await _shot("skyhop-05-jump")
	l.player.input = Vector2.ZERO
	_goto(l, _find(l, "mover"))
	await _wait(1.2, 10)
	await _shot("skyhop-06-moving")
	_goto(l, _find(l, "falling"))
	await _wait(1.0, 10)
	await _shot("skyhop-07-falling")
	_goto(l, _find(l, "bounce"))
	await _wait(0.8, 10)
	await _shot("skyhop-08-bounce")
	main.start_level(9)
	l = main.level()
	await _wait(1.0, 30)
	_goto(l, 4)
	await _wait(1.0, 10)
	await _shot("skyhop-09-sunset")
	main.start_level(13)
	l = main.level()
	await _wait(1.0, 30)
	_goto(l, 6)
	await _wait(1.0, 10)
	await _shot("skyhop-10-frost")
	main.start_level(18)
	l = main.level()
	await _wait(1.0, 30)
	_goto(l, 5)
	await _wait(1.0, 10)
	await _shot("skyhop-11-night")
	l.player.global_position = l._goal + Vector3(0, 0.8, 0)
	await _wait(1.2, 12)
	await _shot("skyhop-12-complete")
	print("SHOTS DONE")
	get_tree().quit(0)
