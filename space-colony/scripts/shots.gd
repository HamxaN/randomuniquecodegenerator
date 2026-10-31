class_name Shots
extends Node
## Builds up a colony by itself and saves screenshots. CI runs this under a
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


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT %s (%d fps)" % [path, Engine.get_frames_per_second()])


## Builds [param type] on [param cell] and finishes it at once.
func _build(type: String, cell: Vector2i) -> void:
	var c: Colony = main.colony
	c.state.credits += 5000
	c.state.ore += 2000
	c.state.crystals += 20
	c.start_place(type)
	c.move_ghost(cell)
	c.confirm_place()
	var b := c.state.at(cell)
	if not b.is_empty():
		c.state.rush(b)


func _run() -> void:
	var c: Colony = main.colony
	var s := c.state
	await _wait(1.5, 30)
	await _shot("spacecolony-01-landing")
	_build("solar", Vector2i(4, 3))
	_build("hab", Vector2i(6, 3))
	_build("drill", Vector2i(4, 1))
	await _wait(0.6, 8)
	await _shot("spacecolony-02-first-buildings")
	c.hud.open_build()
	await _wait(1.0, 20)
	await _shot("spacecolony-03-build-menu")
	c.hud.close_panel()
	c.start_place("dome")
	c.move_ghost(Vector2i(6, 5))
	await _wait(0.5, 8)
	await _shot("spacecolony-04-placing")
	c.confirm_place()
	await _wait(0.5, 6)
	await _shot("spacecolony-05-construction")
	s.rush(s.at(Vector2i(6, 5)))
	# Grow to Hub level 3 with a bigger base.
	s.credits += 20000
	s.ore += 250
	for lv in 2:
		s.upgrade(s.hq())
		s.rush(s.hq())
	s.storage()
	var plan := [["solar", Vector2i(3, 3)], ["solar", Vector2i(3, 4)], ["wind", Vector2i(8, 2)], ["wind", Vector2i(9, 4)],
		["hab", Vector2i(7, 3)], ["hab", Vector2i(6, 6)], ["dome", Vector2i(5, 6)], ["pad", Vector2i(3, 6)],
		["depot", Vector2i(8, 5)], ["drill", Vector2i(9, 1)], ["drill", Vector2i(2, 6)], ["garage", Vector2i(8, 6)],
		["lab", Vector2i(7, 5)], ["crystal", Vector2i(11, 3)], ["solar", Vector2i(2, 3)], ["hab", Vector2i(4, 5)]]
	for p in plan:
		_build(p[0], p[1])
	s.colonists = 20
	await _wait(1.0, 20)
	c.rig.distance = 20.0
	await _shot("spacecolony-06-colony")
	c.select(s.at(Vector2i(7, 3))["id"])
	await _wait(0.5, 8)
	await _shot("spacecolony-07-building-panel")
	c.select(-1)
	s.lander_t = GameData.LANDER_EVERY
	await _wait(1.2, 12)
	await _shot("spacecolony-08-rocket")
	c.start_shower(0)
	for i in 4:
		c.spawn_meteor(Vector2i(2 + i * 2, 2 + i % 3))
	await _wait(1.8, 16)
	await _shot("spacecolony-09-meteors")
	c.blast(0)
	await _wait(0.2, 3)
	await _shot("spacecolony-10-blast")
	await _wait(4.0, 40)
	c.start_storm(20.0)
	await _wait(2.0, 24)
	await _shot("spacecolony-11-storm")
	c.rig.distance = 12.0
	c.rig.focus = Vector3(4, 0, -1)
	await _wait(0.6, 8)
	await _shot("spacecolony-12-closeup")
	c.hud.show_welcome({"credits": 1840, "ore": 320, "seconds": 3600.0})
	await _wait(0.6, 8)
	await _shot("spacecolony-13-welcome")
	print("SHOTS DONE")
	get_tree().quit(0)
