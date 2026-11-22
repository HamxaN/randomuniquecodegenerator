class_name Lobby
extends Node3D
## The main menu: your character on a helipad, play offline against bots, join a
## server, host a game on this phone for friends on the same Wi-Fi, the locker,
## settings and career stats. Also shows the online waiting room.

signal play_offline(match_mode: String)
signal join_server(address: String)
signal host_game(match_mode: String)
signal leave_online

var ui: Control
var _model: Node3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _coins: Label
var _level: Label
var _name_btn: Button
var _mode_btns: Array = []
var _panel: Control
var _room: Control
var _room_list: VBoxContainer
var _room_title: Label
var _room_status: Label
var _room_start: Button
var _status_label: Label
var _t := 0.0
var _hand: Node3D
var _gun: GunModel
var _gun_id := "ar"


func _ready() -> void:
	_build_scene()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_build_ui()
	Net.lobby_changed.connect(_on_lobby)
	Net.status.connect(func(t: String) -> void: set_status(t))
	Save.changed.connect(_refresh)
	_refresh()
	if Net.online():
		show_room()
		_on_lobby(Net.info if not Net.info.is_empty() else Net.lobby_info())


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1d3a5c")
	sm.sky_horizon_color = Color("e98b4f")
	sm.ground_horizon_color = Color("e98b4f")
	sm.ground_bottom_color = Color("1a2330")
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -50, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.6
	cyl.height = 0.3
	pad.mesh = cyl
	pad.material_override = Models.material(Color("2b3440"))
	pad.position.y = -0.15
	add_child(pad)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.9
	tm.outer_radius = 2.05
	ring.mesh = tm
	ring.material_override = Models.material(UI.ACCENT, 1.5)
	ring.position.y = 0.02
	add_child(ring)
	# A few crates and a car behind for atmosphere.
	for p in [Vector3(-3.2, 0, -2.0), Vector3(-3.0, 0, -0.6), Vector3(-2.6, 0.9, -1.3)]:
		var c := Models.prop("res://assets/city/box_A.gltf")
		c.scale = Vector3.ONE * 5.0
		c.position = p
		c.rotation.y = p.x
		add_child(c)
	var car := Models.prop("res://assets/city/car_police.gltf")
	car.scale = Vector3.ONE * 4.0
	car.position = Vector3(3.6, 0.25, -2.6)
	car.rotation.y = -0.7
	add_child(car)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	add_child(_cam)
	_cam.position = Vector3(1.6, 1.9, 6.2)
	_cam.look_at(Vector3(1.0, 1.0, 0), Vector3.UP)
	_cam.current = true
	_show_skin(Save.skin)


func _show_skin(skin_id: String) -> void:
	if _model != null:
		_model.queue_free()
	_model = Models.character(String(GameData.skin(skin_id)["model"]))
	_model.scale = Vector3.ONE * 0.85
	add_child(_model)
	_ap = Models.animation_player(_model)
	if _ap != null:
		_ap.play("Idle")
	_hand = Models.hand_slot(_model)
	_show_gun(_gun_id)
	_model.rotation.y = 0.35


func _show_gun(id: String) -> void:
	_gun_id = id
	if _gun != null and is_instance_valid(_gun):
		_gun.queue_free()
	_gun = GunModel.make({"id": id, "att": {"scope": "scope2", "grip": "grip"} if GameData.fits(id, "scope2") else {},
		"camo": Save.camo, "rar": 2})
	if _hand != null:
		_hand.add_child(_gun)
		_gun.rotation = Vector3(0, PI, 0)


func _process(delta: float) -> void:
	_t += delta
	if _model != null:
		_model.rotation.y = 0.35 + sin(_t * 0.4) * 0.25


func _build_ui() -> void:
	var title := UI.heading("LAST DROP", 72, UI.ACCENT)
	title.position = Vector2(48, 28)
	ui.add_child(title)
	var sub := UI.label("ISLAND BATTLE ROYALE", 26, UI.MUTED)
	sub.position = Vector2(52, 108)
	ui.add_child(sub)
	# Top right: name, level, coins.
	var top := UI.hbox(12)
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-560, 26)
	top.size = Vector2(530, 60)
	top.alignment = BoxContainer.ALIGNMENT_END
	_name_btn = UI.ghost(Save.player_name, Vector2(200, 52), 26)
	_name_btn.pressed.connect(_edit_name)
	top.add_child(_name_btn)
	var lv := UI.chip("xp", "1", UI.BLUE)
	_level = lv.find_child("Amount", true, false)
	top.add_child(lv)
	var coins := UI.chip("coin", "0", UI.ACCENT)
	_coins = coins.find_child("Amount", true, false)
	top.add_child(coins)
	ui.add_child(top)
	# Left column: mode and play.
	var col := UI.vbox(14)
	col.position = Vector2(48, 170)
	var modes := UI.hbox(10)
	for m in ["solo", "squad"]:
		var b := UI.ghost(m.to_upper(), Vector2(150, 52), 28)
		b.pressed.connect(func() -> void:
			Save.mode = m
			Save.store()
			_refresh())
		modes.add_child(b)
		_mode_btns.append(b)
	col.add_child(modes)
	var play := UI.button("PLAY", UI.ACCENT, Vector2(310, 84), 46)
	play.pressed.connect(func() -> void: play_offline.emit(Save.mode))
	col.add_child(play)
	var hint := UI.label("20 players · bots · works offline", 22, UI.MUTED)
	col.add_child(hint)
	var online := UI.button("PLAY ONLINE", UI.BLUE, Vector2(310, 66), 32)
	online.pressed.connect(_open_online)
	col.add_child(online)
	var row := UI.hbox(10)
	for pair in [["ARMORY", _open_armory], ["LOCKER", _open_locker], ["STATS", _open_stats], ["SETTINGS", _open_settings]]:
		var b := UI.ghost(pair[0], Vector2(116, 50), 22)
		b.pressed.connect(pair[1])
		row.add_child(b)
	col.add_child(row)
	ui.add_child(col)
	_status_label = UI.label("", 24, UI.ORANGE)
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status_label.position = Vector2(48, -60)
	ui.add_child(_status_label)


func _refresh() -> void:
	if _coins != null:
		_coins.text = UI.fmt(Save.coins)
	if _level != null:
		_level.text = "LV %d" % Save.level()
	if _name_btn != null:
		_name_btn.text = Save.player_name
	for i in _mode_btns.size():
		var b: Button = _mode_btns[i]
		var on: bool = ["solo", "squad"][i] == Save.mode
		b.modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.55)
		b.add_theme_color_override("font_color", UI.ACCENT if on else UI.TEXT)


func set_status(t: String) -> void:
	if _status_label != null:
		_status_label.text = t
	if _room_status != null and is_instance_valid(_room_status):
		_room_status.text = t


# --- Panels -------------------------------------------------------------------------

func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _modal(title: String, width: float = 640.0) -> VBoxContainer:
	_close_panel()
	var d := UI.dim(0.65)
	ui.add_child(d)
	_panel = d
	var p := UI.panel()
	p.custom_minimum_size = Vector2(width, 0)
	d.add_child(p)
	var v := UI.vbox(14)
	p.add_child(v)
	var head := UI.hbox(10)
	var t := UI.heading(title, 40)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UI.ghost("X", Vector2(56, 50), 26)
	x.pressed.connect(_close_panel)
	head.add_child(x)
	v.add_child(head)
	p.resized.connect(func() -> void: p.position = (ui.get_viewport_rect().size - p.size) / 2)
	return v


func _edit_name() -> void:
	var v := _modal("YOUR NAME", 520)
	var e := LineEdit.new()
	e.text = Save.player_name
	e.max_length = 16
	e.custom_minimum_size = Vector2(440, 56)
	e.add_theme_font_override("font", UI.bold())
	e.add_theme_font_size_override("font_size", 30)
	v.add_child(e)
	var ok := UI.button("SAVE", UI.ACCENT, Vector2(200, 60))
	ok.pressed.connect(func() -> void:
		var n := e.text.strip_edges()
		if n != "":
			Save.player_name = n
			Save.store()
		_close_panel())
	v.add_child(ok)


func _open_online() -> void:
	var v := _modal("PLAY ONLINE", 720)
	v.add_child(UI.label("Join a Last Drop server, or host a match on this phone for friends on the same Wi-Fi.", 22, UI.MUTED))
	var row := UI.hbox(10)
	var addr := LineEdit.new()
	addr.placeholder_text = "Server address (e.g. 203.0.113.5 or 192.168.1.20)"
	addr.text = Save.server
	addr.custom_minimum_size = Vector2(470, 56)
	addr.add_theme_font_override("font", UI.bold())
	addr.add_theme_font_size_override("font_size", 26)
	row.add_child(addr)
	var join := UI.button("JOIN", UI.BLUE, Vector2(170, 56), 30)
	join.pressed.connect(func() -> void:
		var a := addr.text.strip_edges()
		if a == "":
			set_status("Type the server's address first.")
			return
		Save.server = a
		Save.store()
		_close_panel()
		join_server.emit(a))
	row.add_child(join)
	v.add_child(row)
	var host_row := UI.hbox(10)
	for m in ["solo", "squad"]:
		var b := UI.ghost("HOST " + m.to_upper(), Vector2(220, 56), 26)
		b.pressed.connect(func() -> void:
			_close_panel()
			host_game.emit(m))
		host_row.add_child(b)
	v.add_child(host_row)
	v.add_child(UI.label("Port %d · Empty slots are filled with bots" % GameData.PORT, 20, UI.MUTED))


## The online waiting room.
func show_room() -> void:
	_close_panel()
	if _room != null and is_instance_valid(_room):
		return
	var d := UI.dim(0.55)
	ui.add_child(d)
	_room = d
	var p := UI.panel()
	p.custom_minimum_size = Vector2(620, 420)
	d.add_child(p)
	p.resized.connect(func() -> void: p.position = (ui.get_viewport_rect().size - p.size) / 2)
	var v := UI.vbox(12)
	p.add_child(v)
	_room_title = UI.heading("WAITING ROOM", 40)
	v.add_child(_room_title)
	_room_status = UI.label("", 24, UI.MUTED)
	v.add_child(_room_status)
	if Net.role == Net.Role.HOST:
		var ips := Net.local_addresses()
		var ip_text := ", ".join(PackedStringArray(ips)) if not ips.is_empty() else "(connect to Wi-Fi)"
		v.add_child(UI.label("Friends join: %s" % ip_text, 26, UI.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 200)
	_room_list = UI.vbox(4)
	scroll.add_child(_room_list)
	v.add_child(scroll)
	var h := UI.hbox(12)
	if Net.role == Net.Role.HOST:
		_room_start = UI.button("START", UI.ACCENT, Vector2(200, 60))
		_room_start.pressed.connect(func() -> void: Net.host_start())
		h.add_child(_room_start)
	var leave := UI.ghost("LEAVE", Vector2(160, 60))
	leave.pressed.connect(func() -> void:
		hide_room()
		leave_online.emit())
	h.add_child(leave)
	v.add_child(h)


func hide_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.queue_free()
	_room = null


func _on_lobby(i: Dictionary) -> void:
	if _room == null or not is_instance_valid(_room):
		return
	var players: Array = i.get("players", [])
	_room_title.text = "WAITING ROOM  ·  %s" % String(i.get("mode", "squad")).to_upper()
	match String(i.get("state", "")):
		"countdown":
			_room_status.text = "Match starts in %d s · %d/%d players (bots fill the rest)" % [int(ceil(float(i["timer"]))), players.size(), int(i["max"])]
		"running":
			_room_status.text = "A match is in progress. You'll join the next one."
		"ended":
			_room_status.text = "Match ending. Next one soon..."
		_:
			_room_status.text = "%d/%d players · %s" % [players.size(), int(i.get("max", 20)),
				"waiting for players" if bool(i.get("dedicated", false)) else "tap START when everyone's in"]
	for c in _room_list.get_children():
		c.queue_free()
	for pl in players:
		var r := UI.hbox(10)
		r.add_child(UI.icon("user", 26, GameData.skin(String(pl["skin"]))["color"]))
		r.add_child(UI.label(String(pl["name"]), 26))
		_room_list.add_child(r)


func _open_locker() -> void:
	var v := _modal("LOCKER", 820)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	for s in GameData.SKINS:
		var card := UI.vbox(6)
		var owned := Save.owns(String(s["id"]))
		var name_l := UI.label(String(s["name"]).to_upper(), 26, s["color"])
		card.add_child(name_l)
		var b: Button
		if Save.skin == s["id"]:
			b = UI.ghost("EQUIPPED", Vector2(140, 50), 22)
			b.disabled = true
		elif owned:
			b = UI.button("EQUIP", UI.GREEN, Vector2(140, 50), 24)
			b.pressed.connect(func() -> void:
				Save.skin = s["id"]
				Save.store()
				_show_skin(Save.skin)
				_open_locker())
		else:
			b = UI.button("%s" % UI.fmt(int(s["price"])), UI.ACCENT, Vector2(140, 50), 24)
			b.disabled = Save.coins < int(s["price"])
			b.pressed.connect(func() -> void:
				if Save.buy(s["id"]):
					Save.skin = s["id"]
					Save.store()
					_show_skin(Save.skin)
				_open_locker())
		var preview := UI.ghost("VIEW", Vector2(140, 44), 20)
		preview.pressed.connect(func() -> void: _show_skin(s["id"]))
		card.add_child(preview)
		card.add_child(b)
		grid.add_child(card)
	v.add_child(grid)
	v.add_child(UI.label("Earn coins by placing high and getting eliminations.", 22, UI.MUTED))


func _open_stats() -> void:
	var v := _modal("CAREER", 560)
	var deaths := maxi(1, Save.matches - Save.wins)
	var rows := [["Matches", Save.matches], ["Wins", Save.wins], ["Top 5", Save.top5], ["Eliminations", Save.kills],
		["K/D", "%.2f" % (float(Save.kills) / deaths)], ["Best match kills", Save.best_kills], ["Level", Save.level()]]
	for r in rows:
		var h := UI.hbox(10)
		var a := UI.label(String(r[0]), 28, UI.MUTED)
		a.custom_minimum_size.x = 300
		h.add_child(a)
		h.add_child(UI.label(str(r[1]), 28))
		v.add_child(h)


func _open_settings() -> void:
	var v := _modal("SETTINGS", 620)
	v.add_child(_toggle("Sound", Save.sound, func(on: bool) -> void: Save.sound = on))
	v.add_child(_toggle("Vibration", Save.vibrate, func(on: bool) -> void: Save.vibrate = on))
	v.add_child(_toggle("Aim assist", Save.aim_assist, func(on: bool) -> void: Save.aim_assist = on))
	var sens := UI.hbox(12)
	var sl := UI.label("Look sensitivity", 28)
	sl.custom_minimum_size.x = 260
	sens.add_child(sl)
	var slider := HSlider.new()
	slider.min_value = 0.4
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = Save.sensitivity
	slider.custom_minimum_size = Vector2(260, 40)
	slider.value_changed.connect(func(x: float) -> void:
		Save.sensitivity = x
		Save.store())
	sens.add_child(slider)
	v.add_child(sens)
	var q := UI.hbox(10)
	var ql := UI.label("Graphics", 28)
	ql.custom_minimum_size.x = 260
	q.add_child(ql)
	for i in 3:
		var b := UI.ghost(["LOW", "MEDIUM", "HIGH"][i], Vector2(110, 46), 22)
		b.modulate = Color.WHITE if Save.quality == i else Color(1, 1, 1, 0.5)
		b.pressed.connect(func() -> void:
			Save.quality = i
			Save.store()
			_open_settings())
		q.add_child(b)
	v.add_child(q)
	var tips := UI.label("Left stick: move  ·  Drag right side: look  ·  Hold fire to shoot (drag to aim)\nScope button: aim  ·  Hand button: pick up, drive, revive", 20, UI.MUTED)
	v.add_child(tips)


func _toggle(text: String, on: bool, setter: Callable) -> Control:
	var h := UI.hbox(12)
	var l := UI.label(text, 28)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var b := UI.ghost("ON" if on else "OFF", Vector2(120, 46), 24)
	b.add_theme_color_override("font_color", UI.GREEN if on else UI.MUTED)
	var state := [on]
	b.pressed.connect(func() -> void:
		state[0] = not state[0]
		setter.call(state[0])
		Save.store()
		b.text = "ON" if state[0] else "OFF"
		b.add_theme_color_override("font_color", UI.GREEN if state[0] else UI.MUTED))
	h.add_child(b)
	return h


## Opens a panel by name (used by the screenshot tour).
func open(which: String) -> void:
	match which:
		"locker":
			_open_locker()
		"online":
			_open_online()
		"settings":
			_open_settings()
		"stats":
			_open_stats()
		"armory":
			_open_armory()
		_:
			_close_panel()

# --- Armory ---------------------------------------------------------------------------

func _open_armory(selected: String = "ar") -> void:
	var v := _modal("ARMORY", 980)
	var h := UI.hbox(18)
	v.add_child(h)
	# Weapon list by class.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 380)
	var list := UI.vbox(4)
	scroll.add_child(list)
	h.add_child(scroll)
	var by_class := {}
	for id in GameData.WEAPONS:
		var c := String(GameData.WEAPONS[id]["class"])
		if not by_class.has(c):
			by_class[c] = []
		(by_class[c] as Array).append(id)
	for c in ["ar", "smg", "lmg", "shotgun", "dmr", "sniper", "pistol"]:
		if not by_class.has(c):
			continue
		list.add_child(UI.label(String(GameData.CLASS_NAMES[c]).to_upper(), 20, UI.MUTED))
		for id in by_class[c]:
			var b := UI.ghost(String(GameData.WEAPONS[id]["name"]).to_upper(), Vector2(300, 42), 22)
			if id == selected:
				b.add_theme_color_override("font_color", UI.ACCENT)
			b.pressed.connect(func() -> void:
				_show_gun(id)
				_open_armory(id))
			list.add_child(b)
	# Details.
	var d: Dictionary = GameData.WEAPONS[selected]
	var info := UI.vbox(8)
	info.custom_minimum_size = Vector2(560, 0)
	info.add_child(UI.heading(String(d["name"]).to_upper(), 40, UI.ACCENT))
	var mode := "Burst" if d.has("burst") else ("Full auto" if d["auto"] else "Semi auto")
	info.add_child(UI.label("%s  ·  %s  ·  %s" % [String(GameData.CLASS_NAMES[d["class"]]).trim_suffix("s"),
		String(GameData.AMMO[d["ammo"]]["name"]), mode], 24, UI.MUTED))
	var desc := UI.label(String(d["desc"]), 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 540
	info.add_child(desc)
	var stats := [
		["Damage", float(d["dmg"]) * float(d["pellets"]) / 120.0, "%d" % int(float(d["dmg"]) * float(d["pellets"]))],
		["Fire rate", float(d["rpm"]) / 1100.0, "%d rpm" % int(d["rpm"])],
		["Range", float(d["range"]) / 320.0, "%d m" % int(d["range"])],
		["Accuracy", 1.0 - float(d["ads"]) / 4.5, ""],
		["Mobility", (float(d["move"]) - 0.85) / 0.25, ""],
		["Magazine", float(d["mag"]) / 75.0, "%d" % int(d["mag"])],
	]
	for st in stats:
		var row := UI.hbox(10)
		var l := UI.label(String(st[0]), 24, UI.MUTED)
		l.custom_minimum_size.x = 130
		row.add_child(l)
		var bar := UI.bar(UI.ACCENT, Vector2(300, 14))
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = clampf(float(st[1]), 0.04, 1.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UI.label(String(st[2]), 22))
		info.add_child(row)
	var slots: Array = []
	for sl in d["slots"]:
		slots.append(String(sl).to_upper())
	info.add_child(UI.label("Attachments: " + ", ".join(PackedStringArray(slots)), 22, UI.MUTED))
	# Camos.
	info.add_child(UI.label("CAMO  (applies to every gun you carry)", 22, UI.ACCENT))
	var camos := UI.hbox(8)
	for c in GameData.CAMOS:
		var owned: bool = Save.owned_camos.has(c["id"])
		var label := String(c["name"]).to_upper() if owned else UI.fmt(int(c["price"]))
		var col: Color = c["color"] if c["id"] != "none" else Color(0.3, 0.33, 0.38)
		var b := UI.button(label, col, Vector2(74, 44), 16)
		if Save.camo == c["id"]:
			b.add_theme_stylebox_override("normal", UI.box(col, 4, Color.WHITE, 3))
		b.disabled = not owned and Save.coins < int(c["price"])
		b.pressed.connect(func() -> void:
			if Save.owned_camos.has(c["id"]):
				Save.camo = c["id"]
				Save.store()
			else:
				Save.buy_camo(c["id"])
			_show_gun(selected)
			_open_armory(selected))
		camos.add_child(b)
	info.add_child(camos)
	h.add_child(info)
	var foot := UI.label("Guns are found on the island: grey Common, blue Rare, purple Epic and gold Legendary, with more damage and attachments fitted.", 20, UI.MUTED)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size.x = 900
	v.add_child(foot)
