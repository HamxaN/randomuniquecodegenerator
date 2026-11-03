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


## Merges every pair it can find on the board, once.
func _merge_all(view: BoardView, b: BoardState) -> int:
	var n := 0
	for i in b.cells.size():
		for j in range(i + 1, b.cells.size()):
			if b.at(i) != "" and GameData.can_merge(b.at(i), b.at(j)):
				view.drop(i, j)
				n += 1
				break
	return n


func _run() -> void:
	var m: Manor = main.manor
	var b := Save.board
	await _until(func() -> bool: return not m.thumbs.busy(), 60.0)
	await _wait(0.5, 8)
	await _shot("mergemanor-01-dusty-room")
	# Unpack a few boxes.
	for k in 14:
		m.hud._on_generator([0, GameData.COLS - 1, b.idx(3, GameData.ROWS - 1)][k % 3])
	await _wait(0.4, 6)
	await _shot("mergemanor-02-unpacked")
	var view := m.hud.view
	for k in 4:
		_merge_all(view, b)
	view.selection = -1
	for i in b.cells.size():
		if GameData.is_item(b.at(i)) and GameData.level_of(b.at(i)) >= 2:
			view.selection = i
			m.hud._on_selected(i)
			break
	await _wait(0.3, 6)
	await _shot("mergemanor-03-merged")
	# Fill and deliver the orders.
	for o in GameData.ORDER_SLOTS:
		var spot := b.nearest_empty(b.idx(3, 2))
		if spot >= 0:
			b.cells[spot] = b.orders[o]
	b.changed.emit()
	await _wait(0.5, 8)
	await _shot("mergemanor-04-orders-ready")
	for o in GameData.ORDER_SLOTS:
		m.hud.deliver(o)
	# Restore the living room step by step.
	b.stars += 40
	b.changed.emit()
	for k in 4:
		m.hud.renovate()
		await _wait(0.2, 3)
	await _wait(0.8, 10)
	await _shot("mergemanor-05-renovating")
	while b.room == 0:
		m.hud.renovate()
		await _wait(0.1, 2)
	await _wait(0.6, 8)
	await _shot("mergemanor-06-living-room-done")
	await _wait(3.5, 30)
	b.stars += 60
	for k in 5:
		m.hud.renovate()
		await _wait(0.2, 3)
	await _wait(0.8, 10)
	await _shot("mergemanor-07-bedroom")
	m.hud.open_energy()
	await _wait(0.4, 6)
	await _shot("mergemanor-08-energy")
	m.hud.close_panel()
	while b.room == 1:
		m.hud.renovate()
		await _wait(0.1, 2)
	await _wait(3.5, 30)
	b.stars += 60
	while not b.finished():
		m.hud.renovate()
		await _wait(0.1, 2)
	await _wait(1.0, 12)
	await _shot("mergemanor-09-study-done")
	print("SHOTS DONE")
	get_tree().quit(0)
