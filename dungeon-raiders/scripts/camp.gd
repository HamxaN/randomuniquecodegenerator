class_name Camp
extends Node3D
## The main menu: your hero resting in a torchlit hall by the fire, with menus
## for heroes, gear and talents and the big ENTER DUNGEON button.

signal play_requested

var _ui: Control
var _panel: Control
var _gold: Label
var _hero_holder: Node3D
var _hero_name: Label
var _hero_class: Label
var _hero_stats: Label
var _deepest: Label
var _camera: Camera3D
var _fire: OmniLight3D
var _t := 0.0
var _turn := 0.0


func _ready() -> void:
	_build_hall()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(_ui)
	_ui.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenDrag:
			_turn += (e as InputEventScreenDrag).relative.x * 0.01)
	_build_top()
	_build_menu()
	_build_plate()
	_build_play()
	Save.changed.connect(_refresh)
	_refresh()
	Ads.show_banner()


func _process(delta: float) -> void:
	_t += delta
	_fire.light_energy = 3.2 + sin(_t * 8.0) * 0.4 + sin(_t * 19.0) * 0.2
	if _hero_holder != null:
		_hero_holder.rotation.y = lerp_angle(_hero_holder.rotation.y, _turn + sin(_t * 0.4) * 0.25, delta * 3.0)
	_camera.position = Vector3(0.9 + sin(_t * 0.2) * 0.1, 2.4, 7.0)
	_camera.look_at(Vector3(0.9, 1.3, 0))


func _place(piece: String, pos: Vector3, rot: float = 0.0, s: float = 1.0) -> Node3D:
	var n := Models.prop(Models.dungeon(piece))
	add_child(n)
	n.position = pos
	n.rotation.y = rot
	n.scale = Vector3.ONE * s
	return n


func _build_hall() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.42)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.03, 0.04)
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_camera = Camera3D.new()
	_camera.fov = 42.0
	add_child(_camera)
	_camera.current = true
	for x in range(-3, 4):
		for z in range(-3, 2):
			_place("floor_tile_large" if (x + z) % 3 != 0 else "floor_tile_large_rocks", Vector3(x * 4, 0, z * 4))
	for x in range(-3, 4):
		_place("wall" if x % 2 == 0 else "wall_shelves", Vector3(x * 4, 0, -10), 0.0)
	_place("banner_red", Vector3(-4, 0, -9.4))
	_place("banner_blue", Vector3(4, 0, -9.4))
	_place("table_long_decorated_A", Vector3(-4.5, 0, -5.5), PI / 2)
	_place("chair", Vector3(-4.5, 0, -3.8), PI)
	_place("barrel_large", Vector3(5.5, 0, -6.5))
	_place("barrel_small_stack", Vector3(6.8, 0, -4.5), 0.4)
	_place("crates_stacked", Vector3(-7, 0, -7), 0.3)
	_place("chest_gold", Vector3(3.2, 0, -2.2), -0.5)
	_place("coin_stack_large", Vector3(4.2, 0, -1.2))
	_place("sword_shield", Vector3(-2.6, 1.0, -8.9), 0.0, 1.0)
	for x in [-8.0, 8.0]:
		_place("pillar_decorated", Vector3(x, 0, -9))
		var t := _place("torch_mounted", Vector3(x * 0.6, 2.6, -9.45))
		t.rotation.y = 0.0
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = Vector3(x * 0.6, 3.2, -9.0)
		add_child(l)
	# Campfire: logs, flames and a flickering light.
	var fire_pos := Vector3(-1.8, 0, -1.0)
	for i in 4:
		var wood := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.12
		cyl.height = 1.2
		wood.mesh = cyl
		wood.material_override = Models.material(Color(0.32, 0.2, 0.12))
		wood.position = fire_pos + Vector3(0, 0.12, 0)
		wood.rotation = Vector3(PI / 2, i * PI / 4, 0)
		add_child(wood)
	var flames := CPUParticles3D.new()
	flames.amount = 30
	flames.lifetime = 0.8
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.initial_velocity_min = 0.8
	flames.initial_velocity_max = 1.8
	flames.gravity = Vector3(0, 0.6, 0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.25
	flames.scale_amount_min = 0.15
	flames.scale_amount_max = 0.35
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flames.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	flames.mesh = sm
	flames.material_override = Models.material(Color(1.0, 0.55, 0.15), 5.0, true)
	flames.position = fire_pos + Vector3(0, 0.25, 0)
	add_child(flames)
	_fire = OmniLight3D.new()
	_fire.light_color = Color(1.0, 0.55, 0.25)
	_fire.light_energy = 3.2
	_fire.omni_range = 9.0
	_fire.shadow_enabled = true
	_fire.position = fire_pos + Vector3(0, 1.0, 0)
	add_child(_fire)
	var key := SpotLight3D.new()
	key.light_color = Color(0.7, 0.75, 1.0)
	key.light_energy = 3.0
	key.spot_range = 14.0
	key.spot_angle = 30.0
	key.position = Vector3(3, 6, 5)
	add_child(key)
	key.look_at(Vector3(1, 1, 0))
	_rebuild_hero()


func _rebuild_hero() -> void:
	if _hero_holder != null:
		_hero_holder.queue_free()
	var h := GameData.hero(Save.hero)
	_hero_holder = Node3D.new()
	_hero_holder.position = Vector3(1.2, 0, 0.4)
	add_child(_hero_holder)
	var model := Models.character(h["model"], h["keep"])
	_hero_holder.add_child(model)
	var b := Models.bounds(model)
	model.scale = Vector3.ONE * (2.1 / maxf(b.end.y, 0.5))
	var ap := Models.animation_player(model)
	var anim := "2H_Melee_Idle" if h["id"] == "barbarian" else ("Spellcasting" if h["id"] == "mage" else ("2H_Ranged_Aiming" if h["id"] == "rogue" else "Idle"))
	if ap != null and ap.has_animation(anim):
		ap.play(anim)


# ---------------------------------------------------------------- UI

func _build_top() -> void:
	var bar := PanelContainer.new()
	var st := UI.box(Color(0.03, 0.025, 0.02, 0.82), 0)
	st.border_color = UI.EDGE
	st.border_width_bottom = 2
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", st)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(bar)
	var row := UI.hbox(16)
	bar.add_child(row)
	row.add_child(UI.heading("DUNGEON RAIDERS", 34, UI.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var deep := UI.chip("skull", "0", Color(0.9, 0.88, 0.82))
	_deepest = deep.find_child("Amount", true, false) as Label
	row.add_child(deep)
	var gold := UI.chip("coin", "0", UI.ACCENT)
	_gold = gold.find_child("Amount", true, false) as Label
	row.add_child(gold)


func _build_menu() -> void:
	var col := UI.vbox(12)
	col.position = Vector2(24, 96)
	_ui.add_child(col)
	for item in [["HEROES", "user", open_heroes], ["GEAR", "armor", open_gear], ["TALENTS", "star", open_talents], ["SETTINGS", "gear", open_settings]]:
		var b := UI.ghost("", Vector2(230, 60), 30)
		var h := UI.hbox(12)
		h.position = Vector2(20, 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UI.icon(item[1], 32, UI.ACCENT))
		h.add_child(UI.heading(item[0], 24))
		b.add_child(h)
		b.pressed.connect(item[2])
		col.add_child(b)


func _build_plate() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = 24
	holder.offset_top = -230
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var col := UI.vbox(2)
	holder.add_child(col)
	_hero_class = UI.label("", 26, UI.ACCENT)
	col.add_child(_hero_class)
	_hero_name = UI.heading("", 50)
	col.add_child(_hero_name)
	_hero_stats = UI.label("", 26, UI.MUTED)
	col.add_child(_hero_stats)


func _build_play() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -430
	holder.offset_top = -260
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var col := UI.vbox(10)
	col.custom_minimum_size = Vector2(400, 0)
	holder.add_child(col)
	var card := UI.panel(UI.PANEL, UI.ACCENT)
	col.add_child(card)
	var c := UI.vbox(2)
	card.add_child(c)
	c.add_child(UI.label("THE CATACOMBS", 24, UI.ACCENT))
	c.add_child(UI.label("Endless floors. Each one deeper, darker and richer.", 22, UI.MUTED))
	var go := UI.button("ENTER DUNGEON", UI.ACCENT, Vector2(400, 92), 40)
	go.add_theme_font_override("font", UI.head())
	go.pressed.connect(func() -> void:
		Sfx.play("door")
		play_requested.emit())
	col.add_child(go)


func _refresh() -> void:
	_gold.text = UI.fmt(Save.gold)
	_deepest.text = "Floor %d" % Save.deepest
	var h := GameData.hero(Save.hero)
	var s := Save.hero_stats(Save.hero)
	_hero_class.text = (h["class"] as String).to_upper()
	_hero_name.text = h["name"]
	_hero_stats.text = "Attack %d  ·  Health %d  ·  %s" % [int(s["attack"]), int(s["hp"]), h["skill_name"]]


func _open_panel(title: String) -> VBoxContainer:
	close_panel()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)
	_panel.add_child(UI.dim(0.7))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var frame := UI.panel(Color(0.07, 0.055, 0.04, 0.97), UI.ACCENT)
	center.add_child(frame)
	var col := UI.vbox(14)
	frame.add_child(col)
	var head := UI.hbox(12)
	col.add_child(head)
	head.add_child(UI.heading(title, 38, UI.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.chip("coin", UI.fmt(Save.gold), UI.ACCENT))
	var close := UI.ghost("", Vector2(52, 48))
	var ic := UI.icon("close", 22)
	ic.position = Vector2(15, 13)
	close.add_child(ic)
	close.pressed.connect(close_panel)
	head.add_child(close)
	UI.pop(frame, 0.9)
	return col


func close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null


func open_heroes() -> void:
	var col := _open_panel("HEROES")
	var row := UI.hbox(14)
	col.add_child(row)
	for h in GameData.HEROES:
		var owned := Save.owned.has(h["id"])
		var selected: bool = Save.hero == h["id"]
		var card := UI.panel(UI.PANEL_LIGHT, h["color"])
		card.custom_minimum_size = Vector2(250, 0)
		var v := UI.vbox(6)
		card.add_child(v)
		v.add_child(UI.label((h["class"] as String).to_upper(), 22, h["color"]))
		v.add_child(UI.heading(h["name"], 28))
		v.add_child(UI.label("Health %d  ·  Attack %d" % [int(h["hp"]), int(h["attack"])], 22))
		v.add_child(UI.label("Ranged" if h["ranged"] else "Melee", 22, UI.MUTED))
		var sk := UI.label("%s: %s" % [h["skill_name"], h["skill_desc"]], 20, UI.MUTED)
		sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sk.custom_minimum_size = Vector2(210, 60)
		v.add_child(sk)
		var b: Button
		var id: String = h["id"]
		if selected:
			b = UI.ghost("SELECTED", Vector2(210, 54), 26)
			b.disabled = true
		elif owned:
			b = UI.button("SELECT", UI.ACCENT, Vector2(210, 54), 28)
		else:
			b = UI.button("%s GOLD" % UI.fmt(int(h["cost"])), UI.GREEN, Vector2(210, 54), 26)
		b.pressed.connect(func() -> void:
			if Save.buy_hero(id):
				Sfx.play("buy")
				_rebuild_hero()
				open_heroes()
			else:
				Sfx.play("error"))
		v.add_child(b)
		row.add_child(card)


func open_gear() -> void:
	var col := _open_panel("GEAR")
	col.add_child(UI.label("Gear drops in the dungeon. Better pieces are equipped automatically.", 24, UI.MUTED))
	var row := UI.hbox(14)
	col.add_child(row)
	for slot in GameData.SLOTS:
		var item: Dictionary = Save.gear.get(slot, {})
		var col_c: Color = GameData.rarity(item.get("rarity", "common"))["color"] if not item.is_empty() else UI.MUTED
		var card := UI.panel(UI.PANEL_LIGHT, col_c)
		card.custom_minimum_size = Vector2(280, 220)
		var v := UI.vbox(6)
		card.add_child(v)
		v.add_child(UI.label((slot as String).to_upper(), 22, UI.ACCENT))
		var ic := UI.icon("sword" if slot == "weapon" else slot, 70, col_c)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		if item.is_empty():
			v.add_child(UI.label("Nothing yet", 26, UI.MUTED))
		else:
			v.add_child(UI.label(GameData.rarity(item["rarity"])["name"].to_upper(), 20, col_c))
			v.add_child(UI.heading(item["name"], 24))
			v.add_child(UI.label(GameData.item_stat(item), 24, UI.GREEN))
		row.add_child(card)


func open_talents() -> void:
	var col := _open_panel("TALENTS")
	col.add_child(UI.label("Permanent upgrades for every hero.", 24, UI.MUTED))
	for t in GameData.TALENTS:
		var rank := Save.talent(t["id"])
		var row := UI.hbox(14)
		col.add_child(row)
		row.add_child(UI.icon(t["icon"], 40, UI.ACCENT))
		var info := UI.vbox(0)
		info.custom_minimum_size = Vector2(380, 0)
		info.add_child(UI.heading("%s  %d/%d" % [t["name"], rank, int(t["max"])], 24))
		info.add_child(UI.label(t["desc"], 22, UI.MUTED))
		row.add_child(info)
		var pips := UI.hbox(3)
		for i in int(t["max"]):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(16, 12)
			pip.color = UI.ACCENT if i < rank else Color(1, 1, 1, 0.12)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pips.add_child(pip)
		pips.custom_minimum_size = Vector2(200, 0)
		row.add_child(pips)
		var id: String = t["id"]
		if rank < int(t["max"]):
			var b := UI.button("%s" % UI.fmt(GameData.talent_cost(rank)), UI.GREEN, Vector2(170, 52), 26)
			b.pressed.connect(func() -> void:
				if Save.buy_talent(id):
					Sfx.play("buy")
					open_talents()
				else:
					Sfx.play("error"))
			row.add_child(b)
		else:
			row.add_child(UI.label("MAX", 28, UI.ACCENT))


func open_settings() -> void:
	var col := _open_panel("SETTINGS")
	col.custom_minimum_size = Vector2(480, 0)
	var sound := UI.ghost("SOUND: %s" % ("ON" if Save.sound else "OFF"), Vector2(440, 60), 28)
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "SOUND: %s" % ("ON" if Save.sound else "OFF"))
	col.add_child(sound)
	col.add_child(UI.label("Runs %d  ·  Kills %s  ·  Deepest floor %d" % [Save.runs, UI.fmt(Save.kills), Save.deepest], 24, UI.MUTED))
	col.add_child(UI.label("3D art: KayKit by Kay Lousberg (CC0). Sounds: Kenney (CC0).\nFonts: Cinzel and Teko (SIL Open Font License).", 20, UI.MUTED))
