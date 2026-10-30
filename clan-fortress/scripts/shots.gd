class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display with software rendering, so waits are in frames and game time.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	# Pretend some time has passed so the mines have something to collect.
	for b in Save.buildings:
		b["collected_at"] = Save.now() - 600.0
	Save.gold = 5200
	Save.wood = 4800
	Save.army = {"barbarian": 14, "archer": 10, "knight": 2, "mage": 2}
	Save.store()
	main.show_village()
	await _wait(1.5, 40)
	var v: Village = main.village()
	v._refresh_states()
	await _wait(0.5, 10)
	await _shot("clanfortress-01-village")
	v.rig.distance = 13.0
	v.rig.focus = Vector3(1.0, 0, 0.5)
	await _wait(0.5, 10)
	await _shot("clanfortress-02-closeup")
	v.rig.distance = 17.0
	v.rig.focus = Vector3(0, 0, 1.0)
	var mine: Building = null
	for id in v.nodes:
		if (v.nodes[id] as Building).kind == "goldmine":
			mine = v.nodes[id]
	v.select(mine)
	await _wait(0.6, 10)
	await _shot("clanfortress-03-selected")
	v.select(null)
	v.hud.open_shop()
	await _wait(0.8, 16)
	await _shot("clanfortress-04-shop")
	v.hud.close_panel()
	v.start_placing("house")
	await _wait(0.5, 10)
	await _shot("clanfortress-05-placing")
	v.confirm_placing()
	await _wait(0.5, 10)
	await _shot("clanfortress-06-building")
	v.hud.open_army()
	await _wait(0.8, 16)
	await _shot("clanfortress-07-army")
	v.hud.open_campaign()
	await _wait(0.6, 10)
	await _shot("clanfortress-08-map")
	v.hud._show_raid_card(1)
	await _wait(0.4, 8)
	await _shot("clanfortress-09-raid-card")
	v.hud.close_panel()
	main.start_battle(3)
	await _wait(1.0, 30)
	var b: Battle = main.battle()
	await _shot("clanfortress-10-scout")
	b.auto_deploy(14)
	await _wait(3.0, 20)
	await _shot("clanfortress-11-deploy")
	b.auto_deploy(12)
	await _until(func() -> bool: return b.destruction() >= 0.3 or b.finished, 60.0)
	b.rig.distance = 14.0
	await _wait(0.5, 8)
	await _shot("clanfortress-12-battle")
	b.auto_deploy(20)
	await _until(func() -> bool: return b.finished, 90.0)
	if not b.finished:
		b.finish()
	await _wait(1.6, 16)
	await _shot("clanfortress-13-results")
	main.show_village()
	await _wait(1.0, 20)
	await _shot("clanfortress-14-home")
	print("SHOTS DONE")
	get_tree().quit(0)
