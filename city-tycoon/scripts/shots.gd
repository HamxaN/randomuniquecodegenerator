class_name Shots
extends Node
## Builds a city by itself and saves screenshots. CI runs this under a virtual
## display with software rendering, so waits are in frames and game time.

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


func _use(c: City, tool: String, cells: Array) -> void:
	c.hud.pick_tool(tool)
	for p in cells:
		c.apply_tool(p)


## Lets the city grow quickly by running its simulation ahead.
func _grow(c: City, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		c.state.tick(0.5)
		t += 0.5


func _run() -> void:
	var c: City = main.city
	var s := c.state
	s.money = 60000
	c.set_time(0.35)
	await _wait(1.0, 20)
	await _shot("citytycoon-01-empty-land")
	var mid := GameData.ROWS / 2
	# Two cross streets and a ring.
	var roads: Array = []
	for y in range(2, GameData.ROWS - 2):
		roads.append(Vector2i(6, y))
		roads.append(Vector2i(10, y))
	for x in range(3, GameData.COLS - 3):
		roads.append(Vector2i(x, 2))
		roads.append(Vector2i(x, GameData.ROWS - 3))
	_use(c, "road", roads)
	var homes: Array = []
	for y in [3, 5, 7, 8]:
		for x in [4, 5, 7, 8]:
			homes.append(Vector2i(x, y))
	_use(c, "res", homes)
	_use(c, "com", [Vector2i(9, 3), Vector2i(9, 4), Vector2i(11, 3), Vector2i(11, 4), Vector2i(9, 5)])
	_use(c, "ind", [Vector2i(12, 7), Vector2i(12, 8), Vector2i(11, 8)])
	_use(c, "park", [Vector2i(4, 4), Vector2i(5, 4), Vector2i(8, 4)])
	c.hud.pick_tool("res")
	await _wait(1.0, 16)
	await _shot("citytycoon-02-zoned")
	_grow(c, 120.0)
	await _wait(1.0, 16)
	await _shot("citytycoon-03-growing")
	s.stage = 1
	_use(c, "plaza", [Vector2i(7, 4)])
	_use(c, "office", [Vector2i(11, 5), Vector2i(9, 7)])
	_use(c, "res", [Vector2i(3, 3), Vector2i(3, 5), Vector2i(3, 7), Vector2i(3, 8)])
	_use(c, "park", [Vector2i(9, 8)])
	_grow(c, 240.0)
	c.hud.pick_tool("")
	c.apply_tool(Vector2i(5, 4))
	c.rig.distance = 20.0
	await _wait(1.5, 24)
	await _shot("citytycoon-04-busy-city")
	c.rig.distance = 13.0
	c.rig.focus = c.to_world(Vector2i(9, 5))
	await _wait(1.2, 20)
	await _shot("citytycoon-05-street-level")
	c.set_time(0.88)
	c.rig.distance = 24.0
	c.rig.focus = Vector3(0, 0, 1)
	await _wait(1.5, 24)
	await _shot("citytycoon-06-night")
	c.set_time(0.4)
	s.milestone.emit(2)
	await _wait(0.6, 8)
	await _shot("citytycoon-07-milestone")
	print("SHOTS DONE")
	get_tree().quit(0)
