extends Node
## Starts the right mode and swaps between the menu and matches.
##   (no args)                 the game
##   -- --server [--port=7777] [--mode=squad|solo] [--countdown=30]
##                             a dedicated server (run with --headless)
##   -- --shots=<dir>          plays itself and saves screenshots (CI)
##   -- --nettest=<address>    joins a server, plays a little and checks sync (CI)

var current: Node
var _fade: ColorRect
var _shots_dir := ""
var _nettest := ""
var _dedicated := false


func _ready() -> void:
	var port := GameData.PORT
	var server_mode := "squad"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--server":
			_dedicated = true
		elif arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--mode="):
			server_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--countdown="):
			Net.countdown = float(arg.trim_prefix("--countdown="))
		elif arg.begins_with("--nettest="):
			_nettest = arg.trim_prefix("--nettest=")
	Net.match_started.connect(_on_net_match)
	Net.match_ended.connect(_on_net_ended)
	Net.left.connect(_on_left)
	if _dedicated:
		Engine.max_fps = 60
		if Net.host(port, true, server_mode) != OK:
			get_tree().quit(1)
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.025, 0.035)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	if _nettest != "":
		var t := NetTest.new()
		t.main = self
		t.address = _nettest
		add_child(t)
		return
	show_lobby()
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
	if _fade != null:
		_fade.modulate.a = 1.0
		var tw := _fade.create_tween()
		tw.tween_interval(0.05)
		tw.tween_property(_fade, "modulate:a", 0.0, 0.4)


func show_lobby(message: String = "") -> void:
	var l := Lobby.new()
	l.play_offline.connect(func(m: String) -> void: start_offline(m))
	l.join_server.connect(func(a: String) -> void:
		var addr := a
		var port := GameData.PORT
		if a.contains(":"):
			addr = a.get_slice(":", 0)
			port = int(a.get_slice(":", 1))
		if Net.join(addr, port) == OK:
			lobby().show_room())
	l.host_game.connect(func(m: String) -> void:
		if Net.host(GameData.PORT, false, m) == OK:
			lobby().show_room())
	l.leave_online.connect(func() -> void: Net.stop())
	_swap(l)
	if message != "":
		l.set_status(message)


## An offline match against bots.
func start_offline(match_mode: String, autopilot: bool = false) -> Match:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roster := Net.build_roster([{"peer": 0, "name": Save.player_name, "skin": Save.skin}], match_mode, rng)
	var m := Match.new()
	m.exit_requested.connect(func(again: bool) -> void:
		if again:
			start_offline(match_mode)
		else:
			show_lobby())
	_swap(m)
	m.setup({"seed": rng.randi() % 1000000, "mode": match_mode, "roster": roster, "authority": true,
		"networked": false, "visuals": true, "local_id": 1, "bot_skill": 0.45 + minf(Save.level(), 20) * 0.015,
		"autopilot": autopilot})
	return m


func _on_net_match(cfg: Dictionary) -> void:
	var m := Match.new()
	Net.match_node = m
	m.exit_requested.connect(func(_again: bool) -> void:
		Net.stop()
		show_lobby())
	if _dedicated:
		if current != null:
			current.queue_free()
		current = m
		add_child(m)
	else:
		_swap(m)
	if _nettest != "":
		cfg["autopilot"] = true
	m.setup(cfg)


func _on_net_ended() -> void:
	if _dedicated:
		if current != null:
			current.queue_free()
		current = null
		return
	if _nettest != "":
		return
	if Net.online():
		show_lobby()
		lobby().show_room()


func _on_left(reason: String) -> void:
	if _dedicated:
		return
	if _nettest != "":
		print("NET TEST: disconnected: ", reason)
		return
	show_lobby(reason)


func lobby() -> Lobby:
	return current as Lobby


func game() -> Match:
	return current as Match
