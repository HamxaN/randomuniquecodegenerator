class_name Lobby
extends Node3D
## The main menu: your squad posing on a lit stage, a profile bar with level and
## coins, side menus for operators and the armory, and the deploy panel with the
## map picker and the big START button.

signal play_requested(arena_index: int)

var _stage_units: Array[Node3D] = []
var _hero_pivot: Node3D
var _turn := 0.0
var _dragging := false
var _ui: Control
var _panel: Control
var _coins: Label
var _level: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _op_name: Label
var _op_role: Label
var _op_perk: Label
var _weapon_label: Label
var _map_name: Label
var _map_desc: Label
var _map_best: Label
var _start: Button
var _lock_note: Label
var _camera: Camera3D
var _time := 0.0
var _guns: Array[Dictionary] = []


func _ready() -> void:
	_build_stage()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(_ui)
	_ui.gui_input.connect(_on_ui_input)
	_build_top_bar()
	_build_side_menu()
	_build_operator_plate()
	_build_deploy()
	Save.changed.connect(_refresh)
	_refresh()
	Ads.show_banner()


func _process(delta: float) -> void:
	_time += delta
	if not _dragging:
		_turn = lerpf(_turn, sin(_time * 0.35) * 0.35, delta * 1.5)
	if _hero_pivot != null:
		_hero_pivot.rotation.y = _turn
	_camera.position = Vector3(0.6 + sin(_time * 0.2) * 0.08, 1.75, 6.4)
	_camera.look_at(Vector3(0.6, 1.25, 0))
	# Hold each gun level, pointing a little off to the side of the camera.
	for g in _guns:
		var gun: Node3D = g["gun"]
		var holder: Node3D = g["holder"]
		if is_instance_valid(gun) and is_instance_valid(holder):
			gun.global_basis = holder.global_basis.rotated(Vector3.UP, 0.55).scaled(Vector3.ONE * float(g["scale"]))


func _on_ui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = (event as InputEventScreenTouch).pressed
	elif event is InputEventScreenDrag:
		_turn += (event as InputEventScreenDrag).relative.x * 0.01


# ---------------------------------------------------------------- 3D stage

func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.1)
	env.fog_density = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true
	# Floor and a glowing ring under the hero.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Models.material(Color(0.07, 0.08, 0.1))
	(floor_mesh.material_override as StandardMaterial3D).roughness = 0.35
	(floor_mesh.material_override as StandardMaterial3D).metallic = 0.4
	add_child(floor_mesh)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.7
	cyl.height = 0.12
	disc.mesh = cyl
	disc.material_override = Models.material(Color(0.12, 0.14, 0.17))
	disc.position = Vector3(0, 0.06, 0)
	add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.62
	torus.outer_radius = 1.7
	ring.mesh = torus
	ring.material_override = Models.material(UI.ACCENT, 4.0, true)
	ring.position = Vector3(0, 0.13, 0)
	ring.scale = Vector3(1, 0.4, 1)
	add_child(ring)
	# Backdrop: crates, barrels and a weapon rack, softly lit.
	for spec in [
		["crate_A_big", Vector3(-3.6, 0, -3.2), 20.0, 7.0], ["crate_A_big", Vector3(-3.0, 1.45, -3.4), 50.0, 7.0],
		["barrel", Vector3(-2.2, 0, -3.8), 0.0, 7.5], ["crate_long_A", Vector3(3.6, 0, -3.0), -30.0, 7.0],
		["weaponrack", Vector3(4.2, 0, -4.2), -15.0, 9.0], ["barrel", Vector3(2.6, 0, -4.2), 0.0, 7.5],
		["tent", Vector3(0.5, 0, -8.0), 10.0, 9.0],
	]:
		MapBuilder.place(self, MapBuilder.HEX % spec[0], spec[1], spec[2], spec[3], false)
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.76)
	key.light_energy = 6.0
	key.spot_range = 16.0
	key.spot_angle = 28.0
	key.shadow_enabled = true
	key.position = Vector3(2.5, 6.0, 4.0)
	add_child(key)
	key.look_at(Vector3(0, 1, 0))
	var rim := SpotLight3D.new()
	rim.light_color = Color(0.35, 0.6, 1.0)
	rim.light_energy = 7.0
	rim.spot_range = 14.0
	rim.spot_angle = 35.0
	rim.position = Vector3(-3.5, 4.0, -3.5)
	add_child(rim)
	rim.look_at(Vector3(0, 1.2, 0))
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.55, 0.2)
	warm.light_energy = 1.4
	warm.omni_range = 7.0
	warm.position = Vector3(3.5, 1.5, -2.5)
	add_child(warm)
	_rebuild_squad()


func _rebuild_squad() -> void:
	for n in _stage_units:
		n.queue_free()
	_stage_units.clear()
	_guns.clear()
	var hero_op := GameData.operator(Save.operator)
	var others: Array = []
	for o in GameData.OPERATORS:
		if o["id"] != hero_op["id"]:
			others.append(o)
	_hero_pivot = Node3D.new()
	add_child(_hero_pivot)
	_stage_units.append(_hero_pivot)
	_hero_pivot.add_child(_stage_model(hero_op, Save.weapon, Vector3.ZERO, 0.0, "2H_Ranged_Aiming"))
	var spots := [[Vector3(-2.4, 0, -1.6), 0.35, "Idle"], [Vector3(2.5, 0, -1.8), -0.4, "Idle"]]
	for i in 2:
		var s: Array = spots[i]
		var node := _stage_model(others[i], ["smg", "ar"][i], s[0], s[1], s[2])
		add_child(node)
		_stage_units.append(node)


func _stage_model(op: Dictionary, weapon_id: String, pos: Vector3, yaw: float, anim: String) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	var model := Models.character(op["model"])
	holder.add_child(model)
	var b := Models.bounds(model)
	model.scale = Vector3.ONE * (Unit.HEIGHT / maxf(b.end.y, 0.5))
	var hand := Models.hand_slot(model)
	if hand != null:
		var w := GameData.weapon(weapon_id)
		var g := Models.gun(w["model"], w["tint"])
		hand.add_child(g)
		var gb := Models.bounds(g)
		_guns.append({"gun": g, "holder": holder, "scale": 0.9 / maxf(gb.size.z, 0.01)})
	var ap := Models.animation_player(model)
	if ap != null and ap.has_animation(anim):
		ap.play(anim)
		ap.seek(randf() * 2.0, true)
	return holder


# ---------------------------------------------------------------- UI

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var st := UI.box(Color(0.03, 0.04, 0.05, 0.82), 0)
	st.border_color = Color(1, 1, 1, 0.08)
	st.border_width_bottom = 1
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", st)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(bar)
	var row := UI.hbox(16)
	bar.add_child(row)
	var badge := _level_badge()
	row.add_child(badge)
	var who := UI.vbox(0)
	row.add_child(who)
	var name_row := UI.hbox(10)
	who.add_child(name_row)
	name_row.add_child(UI.heading("COMMANDER", 26, UI.TEXT))
	_xp_text = UI.label("", 22, UI.MUTED)
	name_row.add_child(_xp_text)
	_xp_bar = UI.bar(UI.BLUE, Vector2(260, 8))
	who.add_child(_xp_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var title := UI.heading("SQUAD STRIKE", 34, UI.ACCENT)
	row.add_child(title)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	var kills := UI.chip("skull", UI.fmt(Save.total_kills), Color(0.9, 0.9, 0.86))
	kills.name = "Kills"
	row.add_child(kills)
	var coins := UI.chip("coin", "0", UI.ACCENT)
	_coins = coins.find_child("Amount", true, false) as Label
	row.add_child(coins)
	var gear := UI.ghost("", Vector2(54, 48))
	gear.add_child(_icon_in(gear, "gear", 26))
	gear.pressed.connect(open_settings)
	row.add_child(gear)


func _level_badge() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(56, 56)
	_level = UI.heading("1", 26, UI.TEXT)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.size = Vector2(56, 56)
	c.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(Vector2(28, 28) + Vector2.from_angle(-PI / 2 + i * TAU / 6) * 27)
		c.draw_colored_polygon(pts, Color("1d4f8a"))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(28, 28) + (p - Vector2(28, 28)) * 0.82)
		c.draw_colored_polygon(inner, Color("2d74c4"))
		pts.append(pts[0])
		c.draw_polyline(pts, UI.ACCENT, 2.5, true))
	c.add_child(_level)
	return c


func _icon_in(parent: Control, kind: String, s: float) -> Icon:
	var i := UI.icon(kind, s)
	i.position = (parent.custom_minimum_size - Vector2(s, s)) / 2
	return i


func _build_side_menu() -> void:
	var col := UI.vbox(12)
	col.position = Vector2(24, 100)
	_ui.add_child(col)
	for item in [["OPERATORS", "user", open_operators], ["ARMORY", "gun", open_armory], ["SETTINGS", "gear", open_settings]]:
		var b := UI.ghost("", Vector2(230, 62), 30)
		var h := UI.hbox(12)
		h.position = Vector2(22, 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UI.icon(item[1], 34, UI.ACCENT))
		var l := UI.label(item[0], 32)
		h.add_child(l)
		b.add_child(h)
		b.pressed.connect(item[2])
		col.add_child(b)


func _build_operator_plate() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.position = Vector2(24, -250)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var col := UI.vbox(2)
	holder.add_child(col)
	_op_role = UI.label("", 26, UI.ACCENT)
	col.add_child(_op_role)
	_op_name = UI.heading("", 64, UI.TEXT)
	col.add_child(_op_name)
	_op_perk = UI.label("", 26, UI.MUTED)
	col.add_child(_op_perk)
	var wrow := UI.hbox(8)
	wrow.add_child(UI.icon("gun", 30, UI.TEXT))
	_weapon_label = UI.label("", 28, UI.TEXT)
	wrow.add_child(_weapon_label)
	col.add_child(wrow)


func _build_deploy() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.position = Vector2(-430, -330)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var col := UI.vbox(12)
	col.custom_minimum_size = Vector2(400, 0)
	holder.add_child(col)
	var card := UI.panel(UI.PANEL, UI.ACCENT)
	col.add_child(card)
	var inner := UI.vbox(4)
	card.add_child(inner)
	var mode_row := UI.hbox(8)
	mode_row.add_child(UI.icon("map", 26, UI.ACCENT))
	mode_row.add_child(UI.label("SURVIVAL  ·  SQUAD OF 3", 24, UI.ACCENT))
	inner.add_child(mode_row)
	var map_row := UI.hbox(6)
	inner.add_child(map_row)
	var prev := UI.ghost("", Vector2(46, 46))
	prev.add_child(_icon_in(prev, "arrow_l", 22))
	prev.pressed.connect(func() -> void: _change_map(-1))
	map_row.add_child(prev)
	_map_name = UI.heading("", 30, UI.TEXT)
	_map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_row.add_child(_map_name)
	var next := UI.ghost("", Vector2(46, 46))
	next.add_child(_icon_in(next, "arrow_r", 22))
	next.pressed.connect(func() -> void: _change_map(1))
	map_row.add_child(next)
	_map_desc = UI.label("", 22, UI.MUTED)
	_map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_desc.custom_minimum_size = Vector2(360, 0)
	inner.add_child(_map_desc)
	_map_best = UI.label("", 24, UI.TEXT)
	inner.add_child(_map_best)
	_lock_note = UI.label("", 24, UI.RED)
	inner.add_child(_lock_note)
	_start = UI.button("START", UI.ACCENT, Vector2(400, 92), 54)
	_start.add_theme_font_override("font", UI.head())
	_start.pressed.connect(func() -> void:
		Sfx.play("wave")
		play_requested.emit(Save.arena))
	col.add_child(_start)


func _change_map(step: int) -> void:
	Save.arena = posmod(Save.arena + step, GameData.ARENAS.size())
	Save.store()


func _refresh() -> void:
	_coins.text = UI.fmt(Save.coins)
	var lv := Save.level()
	_level.text = str(lv)
	var lo := GameData.xp_to_reach(lv)
	var hi := GameData.xp_to_reach(lv + 1)
	_xp_bar.max_value = hi - lo
	_xp_bar.value = Save.xp - lo
	_xp_text.text = "LV %d  ·  %d / %d XP" % [lv, Save.xp - lo, hi - lo]
	var op := GameData.operator(Save.operator)
	_op_name.text = op["name"]
	_op_name.add_theme_color_override("font_color", op["color"])
	_op_role.text = "%s  OPERATOR" % op["role"].to_upper()
	_op_perk.text = op["perk"]
	var w := GameData.weapon(Save.weapon)
	_weapon_label.text = "%s  ·  LV %d" % [w["name"], Save.weapon_level(Save.weapon)]
	var a := GameData.arena(Save.arena)
	_map_name.text = a["name"]
	_map_desc.text = a["desc"]
	var best := Save.best(Save.arena)
	_map_best.text = "Best: wave %d" % best if best > 0 else "Not played yet"
	var open := Save.arena_unlocked(Save.arena)
	_start.disabled = not open
	_lock_note.text = "" if open else "Reach level %d to unlock" % int(a["unlock"])
	_lock_note.visible = not open


# ---------------------------------------------------------------- Panels

func _open_panel(title: String) -> VBoxContainer:
	close_panel()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)
	_panel.add_child(UI.dim(0.72))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var frame := UI.panel(Color(0.06, 0.075, 0.095, 0.97), UI.ACCENT)
	center.add_child(frame)
	var col := UI.vbox(14)
	frame.add_child(col)
	var head := UI.hbox(12)
	col.add_child(head)
	head.add_child(UI.heading(title, 40, UI.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.chip("coin", UI.fmt(Save.coins), UI.ACCENT))
	var close := UI.ghost("", Vector2(52, 48))
	close.add_child(_icon_in(close, "close", 22))
	close.pressed.connect(close_panel)
	head.add_child(close)
	UI.pop(frame, 0.9)
	return col


func close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null


func open_operators() -> void:
	var col := _open_panel("OPERATORS")
	var row := UI.hbox(14)
	col.add_child(row)
	for op in GameData.OPERATORS:
		row.add_child(_operator_card(op))


func _operator_card(op: Dictionary) -> Control:
	var owned := Save.owned_operators.has(op["id"])
	var equipped: bool = Save.operator == op["id"]
	var card := UI.panel(UI.PANEL_LIGHT, op["color"])
	card.custom_minimum_size = Vector2(250, 0)
	var v := UI.vbox(6)
	card.add_child(v)
	var role := UI.label(op["role"].to_upper(), 22, op["color"])
	v.add_child(role)
	v.add_child(UI.heading(op["name"], 34, UI.TEXT))
	v.add_child(_stat_row("HEALTH", float(op["hp"]) / 170.0, op["color"]))
	v.add_child(_stat_row("SPEED", float(op["speed"]) / 6.0, op["color"]))
	v.add_child(_stat_row("POWER", float(op["damage"]) / 1.3, op["color"]))
	var perk := UI.label(op["perk"], 22, UI.MUTED)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.custom_minimum_size = Vector2(210, 52)
	v.add_child(perk)
	var b: Button
	if equipped:
		b = UI.ghost("EQUIPPED", Vector2(210, 54), 28)
		b.disabled = true
	elif owned:
		b = UI.button("SELECT", UI.ACCENT, Vector2(210, 54), 30)
		b.pressed.connect(func() -> void:
			Save.operator = op["id"]
			Save.store()
			_rebuild_squad()
			open_operators())
	else:
		b = UI.button("  %s" % UI.fmt(int(op["cost"])), UI.GREEN, Vector2(210, 54), 30)
		var ic := UI.icon("coin", 26, UI.ACCENT)
		ic.position = Vector2(30, 13)
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			if Save.buy_operator(op["id"]):
				Sfx.play("buy")
				_rebuild_squad()
				open_operators()
			else:
				Sfx.play("error")
				_flash_no_coins(b))
	v.add_child(b)
	return card


func _stat_row(title: String, frac: float, color: Color) -> Control:
	var h := UI.hbox(8)
	var l := UI.label(title, 20, UI.MUTED)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	var b := UI.bar(color, Vector2(140, 8))
	b.max_value = 1.0
	b.value = clampf(frac, 0.05, 1.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return h


func _flash_no_coins(c: Control) -> void:
	var tw := c.create_tween()
	for i in 3:
		tw.tween_property(c, "position:x", c.position.x + 8, 0.04)
		tw.tween_property(c, "position:x", c.position.x - 8, 0.04)
	tw.tween_property(c, "position:x", c.position.x, 0.04)


func open_armory(selected: String = "") -> void:
	var col := _open_panel("ARMORY")
	if selected == "":
		selected = Save.weapon
	var body := UI.hbox(20)
	col.add_child(body)
	var list := UI.vbox(8)
	body.add_child(list)
	for w in GameData.WEAPONS:
		var owned := Save.owns_weapon(w["id"])
		var row := UI.ghost("", Vector2(330, 62))
		if w["id"] == selected:
			row.add_theme_stylebox_override("normal", UI.panel_style(Color(0.2, 0.17, 0.08, 0.95), UI.ACCENT))
		var h := UI.hbox(10)
		h.position = Vector2(18, 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UI.icon("gun" if owned else "lock", 30, UI.TEXT if owned else UI.MUTED))
		var names := UI.vbox(-6)
		names.add_child(UI.label(w["name"], 28, UI.TEXT if owned else UI.MUTED))
		names.add_child(UI.label(w["kind"].to_upper(), 18, UI.MUTED))
		h.add_child(names)
		row.add_child(h)
		var wid: String = w["id"]
		row.pressed.connect(func() -> void: open_armory(wid))
		list.add_child(row)
	var detail := UI.panel(UI.PANEL_LIGHT, UI.ACCENT)
	detail.custom_minimum_size = Vector2(440, 0)
	body.add_child(detail)
	var d := UI.vbox(8)
	detail.add_child(d)
	var w := GameData.weapon(selected)
	var level := Save.weapon_level(selected)
	d.add_child(UI.label(w["kind"].to_upper(), 24, UI.ACCENT))
	d.add_child(UI.heading(w["name"], 40, UI.TEXT))
	var power := GameData.weapon_power(maxi(level, 1))
	var dps := float(w["damage"]) * float(w["pellets"]) * float(w["rate"]) * power
	d.add_child(_stat_row("DAMAGE", float(w["damage"]) * float(w["pellets"]) * power / 75.0, UI.ACCENT))
	d.add_child(_stat_row("FIRE RATE", float(w["rate"]) / 13.0, UI.ACCENT))
	d.add_child(_stat_row("RANGE", float(w["range"]) / 15.0, UI.ACCENT))
	d.add_child(_stat_row("MAGAZINE", float(w["mag"]) / 90.0, UI.ACCENT))
	d.add_child(UI.label("%d damage per second" % int(dps), 24, UI.TEXT))
	var pips := UI.hbox(4)
	for i in GameData.MAX_WEAPON_LEVEL:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(30, 10)
		pip.color = UI.ACCENT if i < level else Color(1, 1, 1, 0.12)
		pips.add_child(pip)
	d.add_child(UI.label("LEVEL %d / %d" % [maxi(level, 0), GameData.MAX_WEAPON_LEVEL], 22, UI.MUTED))
	d.add_child(pips)
	var buttons := UI.hbox(10)
	d.add_child(buttons)
	if level <= 0:
		var buy := UI.button("  BUY  %s" % UI.fmt(int(w["cost"])), UI.GREEN, Vector2(300, 60), 30)
		buy.pressed.connect(func() -> void:
			if Save.buy_weapon(selected):
				Sfx.play("buy")
				_rebuild_squad()
				open_armory(selected)
			else:
				Sfx.play("error")
				_flash_no_coins(buy))
		buttons.add_child(buy)
	else:
		if Save.weapon != selected:
			var equip := UI.button("EQUIP", UI.ACCENT, Vector2(160, 60), 30)
			equip.pressed.connect(func() -> void:
				Save.weapon = selected
				Save.store()
				_rebuild_squad()
				open_armory(selected))
			buttons.add_child(equip)
		if level < GameData.MAX_WEAPON_LEVEL:
			var cost := GameData.upgrade_cost(level)
			var up := UI.button("UPGRADE  %s" % UI.fmt(cost), UI.BLUE, Vector2(250, 60), 28)
			up.pressed.connect(func() -> void:
				if Save.upgrade_weapon(selected):
					Sfx.play("levelup")
					open_armory(selected)
				else:
					Sfx.play("error")
					_flash_no_coins(up))
			buttons.add_child(up)
		else:
			buttons.add_child(UI.label("MAX LEVEL", 30, UI.ACCENT))


func open_settings() -> void:
	var col := _open_panel("SETTINGS")
	col.custom_minimum_size = Vector2(480, 0)
	var sound := UI.ghost("SOUND: %s" % ("ON" if Save.sound else "OFF"), Vector2(440, 60), 30)
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "SOUND: %s" % ("ON" if Save.sound else "OFF"))
	col.add_child(sound)
	var vib := UI.ghost("VIBRATION: %s" % ("ON" if Save.vibrate else "OFF"), Vector2(440, 60), 30)
	vib.pressed.connect(func() -> void:
		Save.vibrate = not Save.vibrate
		Save.store()
		vib.text = "VIBRATION: %s" % ("ON" if Save.vibrate else "OFF"))
	col.add_child(vib)
	var stats := UI.label("Matches %d  ·  Kills %s  ·  Level %d" % [Save.matches, UI.fmt(Save.total_kills), Save.level()], 26, UI.MUTED)
	col.add_child(stats)
	var credits := UI.label("3D models: KayKit (Kay Lousberg) and Kenney, CC0.\nFonts: Teko and Black Ops One, SIL Open Font License.", 22, UI.MUTED)
	col.add_child(credits)
