extends Node
## Switches between the camp and dungeon floors, carrying the run from floor to
## floor. With `-- --shots=<dir>` it plays itself and saves screenshots (CI).

var current: Node
var run: Dictionary = {}
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
	_fade.color = Color(0.02, 0.015, 0.01)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	tw.tween_property(_fade, "modulate:a", 0.0, 0.4)


func show_camp() -> void:
	var c := Camp.new()
	c.play_requested.connect(start_run)
	_swap(c)


func start_run() -> void:
	run = {"level": 1, "xp": 0, "gold": 0, "kills": 0, "boons": [], "revived": false}
	_enter_floor(1)


func _enter_floor(n: int) -> void:
	var d := Dungeon.new()
	d.floor_n = n
	d.run = run
	d.autopilot = _shots_dir != ""
	d.exit_requested.connect(func(next_floor: bool) -> void:
		if next_floor:
			_enter_floor(n + 1)
		else:
			show_camp())
	_swap(d)


func camp() -> Camp:
	return current as Camp


func dungeon() -> Dungeon:
	return current as Dungeon
