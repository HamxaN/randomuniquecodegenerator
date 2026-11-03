extends Node
## Switches between home and battles. With `-- --shots=<dir>` it plays itself
## and saves screenshots (CI).

var current: Node
var _fade: ColorRect
var _shots_dir := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.08, 0.15)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	show_home()
	if _shots_dir != "":
		var s := Shots.new()
		s.main = self
		s.out_dir = _shots_dir
		add_child(s)


func _swap(next: Node) -> void:
	get_tree().paused = false
	if current != null:
		current.queue_free()
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.modulate.a = 1.0
	var tw := _fade.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.4)


func show_home() -> void:
	var h := Home.new()
	h.battle_requested.connect(start_battle)
	_swap(h)


func start_battle() -> void:
	var b := Battle.new()
	_swap(b)
	b.finished.connect(func(result: Dictionary) -> void:
		var chest := Save.finish_battle(bool(result["won"]), int(result["trophies"]), int(result["gold"]), _rng)
		Ads.match_finished()
		b.hud.show_results(result, chest))
	b.hud.home_pressed.connect(show_home)
	b.hud.again_pressed.connect(start_battle)


func home() -> Home:
	return current as Home


func battle() -> Battle:
	return current as Battle
