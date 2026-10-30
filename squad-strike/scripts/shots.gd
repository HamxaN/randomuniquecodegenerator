class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display; any script error along the way fails the build.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.coins = 4200
	Save.xp = 2600
	_run()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT ", path)


func _run() -> void:
	await _wait(3.0)
	await _shot("squadstrike-01-lobby")
	main.lobby().open_operators()
	await _wait(1.0)
	await _shot("squadstrike-02-operators")
	main.lobby().open_armory("dmr")
	await _wait(1.0)
	await _shot("squadstrike-03-armory")
	main.lobby().close_panel()
	main.start_match(0)
	await _wait(1.6)
	await _shot("squadstrike-04-deploy")
	await _wait(5.0)
	await _shot("squadstrike-05-wave1")
	await _wait(5.0)
	await _shot("squadstrike-06-firefight")
	var a: Arena = main.arena()
	a.grenade_cd = 0.0
	a.throw_grenade()
	await _wait(0.85)
	await _shot("squadstrike-07-grenade")
	a.streak = 1.0
	a.airstrike()
	await _wait(1.5)
	await _shot("squadstrike-08-airstrike")
	a.hud.show_perks(GameData.perk_choices(7))
	await _wait(0.8)
	await _shot("squadstrike-09-perks")
	a.hud._close_modal()
	a.wave = 5
	a.queue.append("boss")
	await _wait(6.0)
	await _shot("squadstrike-10-boss")
	a.squad_damage_taken = 1.0
	a.player.take_damage(99999.0, Vector3.FORWARD)
	await _wait(1.2)
	await _shot("squadstrike-11-down")
	a.hud._down_label = null
	a.hud.show_results()
	await _wait(1.0)
	await _shot("squadstrike-12-results")
	main.start_match(1)
	await _wait(9.0)
	await _shot("squadstrike-13-village")
	main.start_match(2)
	await _wait(9.0)
	await _shot("squadstrike-14-fortress")
	print("SHOTS DONE")
	get_tree().quit(0)
