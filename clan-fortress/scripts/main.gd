extends Node
## Switches between the village and raids with a quick fade. With
## `-- --shots=<dir>` it plays itself and saves screenshots (used by CI).

var current: Node
var _fade: ColorRect
var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	if _shots_dir != "":
		# A fresh village every run, so the screenshots are repeatable.
		Save.new_village()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.03)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	show_village()
	if _shots_dir != "":
		var s := Shots.new()
		s.main = self
		s.out_dir = _shots_dir
		add_child(s)


func _swap(next: Node) -> void:
	get_tree().paused = false
	Thumbs.clear()
	if current != null:
		current.queue_free()
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.modulate.a = 1.0
	var tw := _fade.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.35)


func show_village() -> void:
	var v := Village.new()
	v.attack_requested.connect(start_battle)
	_swap(v)


func start_battle(n: int) -> void:
	var b := Battle.new()
	b.level_n = n
	b.autopilot = _shots_dir != ""
	b.exit_requested.connect(show_village)
	_swap(b)


func village() -> Village:
	return current as Village


func battle() -> Battle:
	return current as Battle
