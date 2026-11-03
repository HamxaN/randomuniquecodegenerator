extends Node
## Switches between the camp and a night in the graveyard. With
## `-- --shots=<dir>` it plays itself and saves screenshots (CI).

var current: Node
var _fade: ColorRect
var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.06)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	show_camp()
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
	tw.tween_property(_fade, "modulate:a", 0.0, 0.5)


func show_camp() -> void:
	var c := Camp.new()
	c.play_requested.connect(start_run)
	_swap(c)


func start_run() -> void:
	var f := Field.new()
	f.autopilot = _shots_dir != ""
	_swap(f)
	f.hud.retry_pressed.connect(start_run)
	f.hud.menu_pressed.connect(show_camp)


func camp() -> Camp:
	return current as Camp


func field() -> Field:
	return current as Field
