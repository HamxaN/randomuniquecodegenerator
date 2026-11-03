class_name Shots
extends Node
## Plays through the game by itself and saves screenshots. CI runs this under a
## virtual display with software rendering, so waits are in frames and game time.

var main  # the Main node (untyped so its helper methods resolve at runtime)
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.trophies = 340
	Save.gold = 1800
	Save._ensure_cards()
	Save.cards["knight"] = {"level": 3, "shards": 9}
	Save.cards["mage"] = {"level": 2, "shards": 2}
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


## Runs the battle simulation ahead quickly (with both brains) to reach later moments.
func _fast_forward(b: Battle, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not b.sim.over:
		b.brain.tick(0.1)
		b.pilot.tick(0.1)
		b.sim.tick(0.1)
		t += 0.1
	b._drain_events()


func _run() -> void:
	await _wait(1.5, 30)
	await _shot("arenaroyale-01-home")
	main.home().open_cards()
	await _wait(1.2, 24)
	await _shot("arenaroyale-02-cards")
	main.home().open_arenas()
	await _wait(0.4, 6)
	await _shot("arenaroyale-03-arenas")
	main.home().close_panel()
	main.start_battle()
	var b: Battle = main.battle()
	b.pilot = BattleSim.Brain.new(b.sim, BattleSim.YOU, 4)
	await _wait(1.2, 20)
	await _shot("arenaroyale-04-battle-start")
	# Select a card so the deploy zone shows, then play it by hand.
	b.sim.mana[BattleSim.YOU] = 10.0
	var hand: Array = b.sim.hands[BattleSim.YOU]
	var troop := ""
	for id in hand:
		if not GameData.is_spell(id) and troop == "":
			troop = id
	b.select(troop)
	await _wait(0.4, 6)
	await _shot("arenaroyale-05-select-card")
	b.deploy(troop, Vector2(-6.0, 7.0))
	b.sim.mana[BattleSim.FOE] = 10.0
	b.brain._t = 0.0
	await _wait(6.0, 40)
	await _shot("arenaroyale-06-clash")
	await _wait(6.0, 40)
	await _shot("arenaroyale-07-fight")
	b.sim.mana[BattleSim.YOU] = 10.0
	(b.sim.hands[BattleSim.YOU] as Array)[0] = "fireball"
	b.sim.play(BattleSim.YOU, "fireball", Vector2(5.0, -9.0))
	await _wait(0.8, 8)
	await _shot("arenaroyale-08-spell")
	_fast_forward(b, 120.0)
	await _wait(2.0, 20)
	await _shot("arenaroyale-09-late-game")
	await _until(func() -> bool: return b.sim.over, 1.0)
	if not b.sim.over:
		_fast_forward(b, 200.0)
	if not b.sim.over:
		b.sim._finish(BattleSim.YOU)
	await _until(func() -> bool: return b.hud._modal.get_child_count() > 0, 15.0)
	await _wait(1.5, 16)
	await _shot("arenaroyale-10-results")
	# The third arena.
	Save.trophies = 760
	main.start_battle()
	b = main.battle()
	b.pilot = BattleSim.Brain.new(b.sim, BattleSim.YOU, 5)
	b.sim.mana = [10.0, 10.0]
	await _wait(10.0, 60)
	await _shot("arenaroyale-11-frost-keep")
	print("SHOTS DONE")
	get_tree().quit(0)
