extends Node
## Switches between the menu (with the restaurant as a backdrop) and a day of
## service. With `-- --shots=<dir>` it plays itself and saves screenshots (CI).

var current: Node3D
var menu: Menu
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
	_fade.color = Color(0.98, 0.55, 0.15)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	show_menu()
	if _shots_dir != "":
		var s := Shots.new()
		s.main = self
		s.out_dir = _shots_dir
		add_child(s)


func _swap(next: Node3D) -> void:
	get_tree().paused = false
	if current != null:
		current.queue_free()
	if menu != null:
		menu.queue_free()
		menu = null
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.modulate.a = 1.0
	var tw := _fade.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.4)


func show_menu() -> void:
	var r := Restaurant.new()
	r.menu_mode = true
	r.day = Save.unlocked_day()
	_swap(r)
	menu = Menu.new()
	menu.play_day.connect(start_day)
	menu.chef_changed.connect(func() -> void:
		var m := menu
		menu = null
		show_menu()
		if m != null:
			m.queue_free())
	add_child(menu)


func start_day(day: int) -> void:
	var r := Restaurant.new()
	r.day = day
	r.autopilot = _shots_dir != ""
	_swap(r)
	r.finished.connect(func(result: Dictionary) -> void:
		var best := Save.finish_day(day, int(result["coins"]), int(result["stars"]), int(result["served"]))
		Ads.match_finished()
		r.hud.show_results(result, best))
	r.hud.next_pressed.connect(func() -> void: start_day(day + 1))
	r.hud.retry_pressed.connect(func() -> void: start_day(day))
	r.hud.menu_pressed.connect(show_menu)


func restaurant() -> Restaurant:
	return current as Restaurant
