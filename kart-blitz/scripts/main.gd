extends Node
## Switches between the garage and races. With `-- --shots=<dir>` it plays
## itself and saves screenshots (used by CI).

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
	_fade.color = Color(0.05, 0.05, 0.08)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	show_garage()
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
	tw.tween_property(_fade, "modulate:a", 0.0, 0.35)


func show_garage() -> void:
	var g := Garage.new()
	g.race_requested.connect(start_race)
	_swap(g)


func start_race(track: int) -> void:
	var r := Race.new()
	r.track_index = track
	r.autopilot = _shots_dir != ""
	r.exit_requested.connect(func(again: bool) -> void:
		if again:
			start_race(track)
		else:
			show_garage())
	_swap(r)


func garage() -> Garage:
	return current as Garage


func race() -> Race:
	return current as Race
