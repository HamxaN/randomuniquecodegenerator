class_name Camp
extends Node3D
## The camp between nights: your hero by a campfire at the graveyard gate,
## with buttons to start, pick a map, choose a hero and buy power-ups.

signal play_requested

var ui: CanvasLayer
var _modal: Control
var _gold: Label
var _map_btn: Button
var _camera: Camera3D
var _t := 0.0
var _hero: Node3D


func _ready() -> void:
	_scene()
	_ui()
	Ads.show_banner()


func _scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.85)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.17, 0.28)
	env.fog_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.6
	moon.rotation_degrees = Vector3(-40, 140, 0)
	moon.shadow_enabled = true
	add_child(moon)
	var ground := Models.cylinder(14.0, 0.2, Color(0.16, 0.18, 0.16))
	ground.position.y = -0.1
	add_child(ground)
	var gate := Models.yard("arch_gate")
	gate.position = Vector3(0, 0, -6)
	gate.scale = Vector3.ONE * 2.2
	add_child(gate)
	var spots := [["fence", Vector3(-4.5, 0, -6), 0.0], ["fence", Vector3(4.5, 0, -6), 0.0], ["tree_dead_large_decorated", Vector3(-6, 0, -3), 0.6],
		["gravestone", Vector3(4, 0, -3.5), 0.3], ["grave_A", Vector3(5.5, 0, -1), -0.4], ["pumpkin_orange_jackolantern", Vector3(-2.5, 0, 1.6), 0.5],
		["lantern_standing", Vector3(3, 0, 1), 0.0], ["coffin", Vector3(-4.5, 0, 0.5), 1.2], ["tree_dead_medium", Vector3(7, 0, -5), 0.0],
		["skull_candle", Vector3(1.6, 0, 2.2), 0.0], ["crypt", Vector3(-9, 0, -8), 0.5]]
	for s in spots:
		var n := Models.yard(s[0])
		n.position = s[1]
		n.rotation.y = s[2]
		n.scale = Vector3.ONE * (2.4 if (s[0] as String).begins_with("tree") or s[0] == "crypt" else 1.6)
		add_child(n)
	# Campfire.
	var fire := CPUParticles3D.new()
	fire.amount = 30
	fire.lifetime = 0.8
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 2.2
	fire.gravity = Vector3(0, 0.5, 0)
	fire.scale_amount_min = 0.2
	fire.scale_amount_max = 0.45
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	fm.radial_segments = 6
	fm.rings = 3
	fire.mesh = fm
	fire.material_override = Models.material(Color(1.0, 0.55, 0.15), 4.0)
	fire.position = Vector3(1.6, 0.2, 0.2)
	add_child(fire)
	for k in 5:
		var stick := Models.box(Vector3(0.9, 0.15, 0.15), Color(0.35, 0.2, 0.1))
		stick.position = Vector3(1.6, 0.08, 0.2)
		stick.rotation.y = k * TAU / 5.0
		add_child(stick)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	glow.position = Vector3(1.6, 1.2, 0.2)
	add_child(glow)
	_place_hero()
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true


func _place_hero() -> void:
	if _hero != null:
		_hero.queue_free()
	var h := GameData.hero(Save.hero)
	var model_name: String = h["model"]
	_hero = Models.character(model_name, Field.HEROES_KEEP.get(model_name, []))
	_hero.position = Vector3(-0.6, 0, 0.4)
	_hero.rotation.y = 0.5
	_hero.scale = Vector3.ONE * 1.3
	add_child(_hero)
	var ap := Models.animation_player(_hero)
	if ap != null:
		ap.play("Idle")


func _process(delta: float) -> void:
	_t += delta
	_camera.position = Vector3(sin(_t * 0.1) * 2.0 + 1.0, 3.2, 8.5)
	_camera.look_at(Vector3(0.6, 1.3, 0), Vector3.UP)


func _ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var t1 := UI.label("NIGHT", 88, Color("c9b8ff"))
	t1.position = Vector2(30, 4)
	root.add_child(t1)
	var t2 := UI.label("SURVIVORS", 88, Color("ff9a3a"))
	t2.position = Vector2(30, 86)
	root.add_child(t2)
	var info := UI.label("Best %d:%02d  ·  Dawns %d  ·  Most kills %s" % [int(Save.best_time) / 60, int(Save.best_time) % 60,
		Save.dawns, UI.fmt(Save.best_kills)], 24, Color("d8d0f0"))
	info.position = Vector2(36, 186)
	root.add_child(info)
	var gb := UI.resource_bar("gold", UI.GOLD, 220)
	gb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gb.offset_left = -270
	gb.offset_top = 14
	(gb.get_node("Bar") as ProgressBar).value = 100
	_gold = gb.get_node("Amount") as Label
	root.add_child(gb)
	var bottom := UI.hbox(14)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24
	bottom.offset_top = -150
	bottom.offset_bottom = -24
	root.add_child(bottom)
	var play := UI.button("Survive!", UI.GREEN, Vector2(270, 100), 44)
	play.pressed.connect(func() -> void: play_requested.emit())
	bottom.add_child(play)
	_map_btn = UI.button("", UI.PURPLE, Vector2(260, 100), 26)
	_map_btn.pressed.connect(_next_map)
	bottom.add_child(_map_btn)
	for b in [["helmet", "Heroes", UI.BLUE, open_heroes], ["up", "Power-ups", UI.ORANGE, open_powerups], ["sound", "Sound", UI.GREY, _toggle_sound]]:
		var rb := UI.round_button(b[0], b[1], b[2], 92)
		rb.pressed.connect(b[3])
		bottom.add_child(rb)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_modal)
	Save.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_gold.text = UI.fmt(Save.gold)
	var m: Dictionary = GameData.MAPS[0]
	for x in GameData.MAPS:
		if x["id"] == Save.map:
			m = x
	_map_btn.text = "Map: %s" % m["name"]


func _next_map() -> void:
	var ids: Array = []
	for m in GameData.MAPS:
		ids.append(m["id"])
	var i := ids.find(Save.map)
	var nxt: String = ids[(i + 1) % ids.size()]
	if nxt == "patch" and Save.best_time < 300.0 and Save.dawns == 0:
		_toast("Survive 5 minutes to unlock the Pumpkin Patch")
		Sfx.play("error")
		return
	Save.map = nxt
	Save.store()


func _toggle_sound() -> void:
	Save.sound = not Save.sound
	Save.store()
	_toast("Sound on" if Save.sound else "Sound off")


func _toast(text: String) -> void:
	var l := UI.label(text, 32)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func close_panel() -> void:
	for c in _modal.get_children():
		c.queue_free()


func _panel(title: String, width: float) -> VBoxContainer:
	close_panel()
	_modal.add_child(UI.dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	var head := UI.hbox(10)
	v.add_child(head)
	var t := UI.label(title, 40, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(52, 52)
	close.focus_mode = Control.FOCUS_NONE
	close.add_child(UI.icon("close", 48))
	close.pressed.connect(close_panel)
	head.add_child(close)
	return v


func open_heroes() -> void:
	var v := _panel("Heroes", 960)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for h in GameData.HEROES:
		var id: String = h["id"]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style(Color("5a4a8a") if Save.hero == id else UI.PARCHMENT_DARK))
		row.add_child(card)
		var col := UI.vbox(4)
		card.add_child(col)
		var tex := TextureRect.new()
		tex.texture = Thumbs.hero(self, h["model"], 180)
		tex.custom_minimum_size = Vector2(170, 150)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(tex)
		var n := UI.label(h["name"], 26)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var wrow := UI.hbox(4)
		wrow.alignment = BoxContainer.ALIGNMENT_CENTER
		wrow.add_child(UI.icon(GameData.WEAPONS[h["weapon"]]["icon"], 28))
		wrow.add_child(UI.ink("HP %d" % int(h["hp"]), 18))
		col.add_child(wrow)
		var perk := UI.ink(h["perk"], 15)
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD
		perk.custom_minimum_size = Vector2(170, 44)
		perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(perk)
		var label := "Chosen" if Save.hero == id else ("Choose" if Save.heroes.has(id) else UI.fmt(int(h["cost"])))
		var color := UI.GREY if Save.hero == id else (UI.BLUE if Save.heroes.has(id) else UI.GREEN)
		var b := UI.button(label, color, Vector2(170, 52), 24)
		b.pressed.connect(func() -> void:
			if Save.pick_hero(id):
				Sfx.play("buy")
				_place_hero()
				open_heroes()
			else:
				Sfx.play("error")
				_toast("Not enough gold"))
		col.add_child(b)


func open_powerups() -> void:
	var v := _panel("Power-ups", 860)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for m in GameData.META:
		var id: String = m["id"]
		var lv := Save.meta_level(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style())
		card.custom_minimum_size = Vector2(400, 0)
		grid.add_child(card)
		var h := UI.hbox(10)
		card.add_child(h)
		h.add_child(UI.icon(m["icon"], 52))
		var info := UI.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.ink("%s  (%d/%d)" % [m["name"], lv, int(m["max"])], 22))
		var d := UI.ink(m["desc"], 17)
		d.modulate = Color(1, 1, 1, 0.75)
		info.add_child(d)
		if lv >= int(m["max"]):
			h.add_child(UI.button("Max", UI.GREY, Vector2(110, 54), 24))
			continue
		var cost := GameData.meta_cost(id, lv)
		var buy := UI.button(UI.fmt(cost), UI.GREEN if Save.gold >= cost else UI.GREY, Vector2(120, 54), 24)
		buy.pressed.connect(func() -> void:
			if Save.buy_meta(id):
				Sfx.play("buy")
				open_powerups()
			else:
				Sfx.play("error")
				_toast("Not enough gold"))
		h.add_child(buy)
