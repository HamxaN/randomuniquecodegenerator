class_name Home
extends Node3D
## The home screen: your castle with a few heroes standing guard, trophies,
## gold and arena progress, the big BATTLE button, the card collection and
## deck, and the path of arenas.

signal battle_requested

var _modal: Control
var _gold: Label
var _trophies: Label
var _arena_label: Label
var _arena_bar: ProgressBar
var _camera: Camera3D
var _t := 0.0
var _pick := ""


func _ready() -> void:
	_scene()
	_ui()
	Ads.show_banner()


func _scene() -> void:
	var arena: Dictionary = GameData.ARENAS[GameData.arena_index(Save.trophies)]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = arena["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := Models.box(Vector3(60, 0.2, 60), arena["ground"])
	ground.position.y = -0.1
	add_child(ground)
	var castle := Models.building("castle", "blue")
	castle.scale = Vector3.ONE * 3.0
	castle.position = Vector3(0, 0, -2)
	add_child(castle)
	for x in [-4.5, 4.5]:
		var t := Models.building("tower_A", "blue")
		t.scale = Vector3.ONE * 2.2
		t.position = Vector3(x, 0, -1)
		add_child(t)
	var guards := [["Knight", Vector3(-1.6, 0, 2.2), "knight"], ["Mage", Vector3(1.6, 0, 2.4), "mage"],
		["Barbarian", Vector3(0, 0, 3.4), "barbarian"], ["Rogue_Hooded", Vector3(-3.2, 0, 3.2), "archers"]]
	for g in guards:
		var m := Models.character(g[0], CardArt.keep(g[2]))
		m.position = g[1]
		m.rotation.y = randf_range(-0.3, 0.3)
		add_child(m)
		var ap := Models.animation_player(m)
		if ap != null:
			ap.play("Idle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(9.0, 20.0)
		var tree := Models.prop(Models.hex(["trees_A_large", "trees_B_large", "tree_single_A", "hill_single_A"][rng.randi() % 4]))
		tree.position = Vector3(cos(a) * d, 0, sin(a) * d - 4.0)
		tree.scale = Vector3.ONE * rng.randf_range(1.8, 2.8)
		add_child(tree)
	for team_x in [-7.0, 7.0]:
		var flag := Models.prop(Models.hex("flag_blue"))
		flag.position = Vector3(team_x, 0, 1)
		flag.scale = Vector3.ONE * 2.4
		add_child(flag)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	_t += delta
	_camera.position = Vector3(sin(_t * 0.12) * 3.0, 6.0, 13.0)
	_camera.look_at(Vector3(0, 1.8, 0), Vector3.UP)


func _ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var l1 := UI.label("ARENA", 84, UI.GOLD)
	l1.position = Vector2(30, 4)
	root.add_child(l1)
	var l2 := UI.label("ROYALE", 84, Color("6fb8ff"))
	l2.position = Vector2(60, 82)
	root.add_child(l2)
	var top := UI.vbox(6)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -290
	top.offset_right = -14
	top.offset_top = 12
	root.add_child(top)
	var tb := UI.resource_bar("trophy", Color("ff9a1f"), 220)
	(tb.get_node("Bar") as ProgressBar).value = 100
	_trophies = tb.get_node("Amount") as Label
	top.add_child(tb)
	var gb := UI.resource_bar("gold", UI.GOLD, 220)
	(gb.get_node("Bar") as ProgressBar).value = 100
	_gold = gb.get_node("Amount") as Label
	top.add_child(gb)
	# Arena card.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.parchment_style())
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -132
	root.add_child(card)
	var cv := UI.vbox(4)
	card.add_child(cv)
	_arena_label = UI.ink("", 28)
	_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_arena_label)
	_arena_bar = UI.bar(Color("ff9a1f"), Vector2(360, 16))
	cv.add_child(_arena_bar)
	var battle := UI.button("BATTLE!", Color("ffb02e"), Vector2(330, 100), 50)
	battle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	battle.offset_left = -165
	battle.offset_right = 165
	battle.offset_top = -122
	battle.offset_bottom = -22
	battle.pressed.connect(func() -> void: battle_requested.emit())
	root.add_child(battle)
	var left := UI.vbox(14)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 24
	left.offset_top = -230
	left.offset_bottom = -24
	root.add_child(left)
	var row := UI.hbox(14)
	left.add_child(row)
	for b in [["cards", "Cards", UI.BLUE, open_cards], ["trophy", "Arenas", UI.ORANGE, open_arenas], ["sound", "Sound", UI.GREY, _toggle_sound]]:
		var rb := UI.round_button(b[0], b[1], b[2], 92)
		rb.pressed.connect(b[3])
		row.add_child(rb)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_modal)
	Save.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_gold.text = UI.fmt(Save.gold)
	_trophies.text = UI.fmt(Save.trophies)
	var i := GameData.arena_index(Save.trophies)
	var a: Dictionary = GameData.ARENAS[i]
	if i + 1 < GameData.ARENAS.size():
		var nxt := int(GameData.ARENAS[i + 1]["trophies"])
		_arena_label.text = "Arena %d: %s   ·   %d / %d" % [i + 1, a["name"], Save.trophies, nxt]
		_arena_bar.max_value = nxt - int(a["trophies"])
		_arena_bar.value = Save.trophies - int(a["trophies"])
	else:
		_arena_label.text = "Arena %d: %s" % [i + 1, a["name"]]
		_arena_bar.max_value = 1
		_arena_bar.value = 1


func _toggle_sound() -> void:
	Save.sound = not Save.sound
	Save.store()
	_toast("Sound on" if Save.sound else "Sound off")


func _toast(text: String) -> void:
	var l := UI.label(text, 32)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_top = 150
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func close_panel() -> void:
	_pick = ""
	for c in _modal.get_children():
		c.queue_free()


func _panel(title: String, width: float) -> VBoxContainer:
	for c in _modal.get_children():
		c.queue_free()
	_modal.add_child(UI.dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := UI.vbox(8)
	p.add_child(v)
	var head := UI.hbox(10)
	v.add_child(head)
	var t := UI.label(title, 38, UI.GOLD)
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


func _card_tile(id: String, in_deck: bool) -> Control:
	var c := GameData.card(id)
	var owned := Save.owns(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 150)
	var col: Color = GameData.RARITY_COLOR[c.get("rarity", "common")]
	var st := UI.box(Color(0.94, 0.94, 0.97) if owned else Color(0.5, 0.5, 0.55), 12, col, 4)
	st.border_width_bottom = 8
	if _pick == id:
		st.bg_color = Color(1.0, 0.95, 0.6)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	if GameData.is_spell(id):
		var ic := UI.icon(BattleHud.SPELL_ICON.get(id, "flame"), 70)
		ic.position = Vector2(21, 14)
		b.add_child(ic)
	else:
		var tex := TextureRect.new()
		tex.texture = Thumbs.card(self, id, 140)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(6, 4)
		tex.size = Vector2(100, 96)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tex)
	var cost := UI.label(str(int(c["cost"])), 22, Color("e8b8ff"))
	cost.position = Vector2(6, 0)
	b.add_child(cost)
	var nl := UI.label(c["name"], 15)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.position = Vector2(0, 98)
	nl.size = Vector2(112, 20)
	b.add_child(nl)
	if owned:
		var lv := Save.level(id)
		var sh := UI.bar(Color("62c63c"), Vector2(96, 12))
		sh.max_value = GameData.shards_needed(lv)
		sh.value = Save.shards(id)
		sh.position = Vector2(8, 124)
		b.add_child(sh)
		var ll := UI.label("Lv %d" % lv, 14)
		ll.position = Vector2(70, 2)
		b.add_child(ll)
		if Save.can_upgrade(id):
			var up := UI.icon("up", 30)
			up.position = Vector2(78, 82)
			b.add_child(up)
	else:
		var lock := UI.icon("lock", 40)
		lock.position = Vector2(36, 40)
		b.add_child(lock)
	b.pressed.connect(func() -> void: _tap_card(id, in_deck))
	return b


func _tap_card(id: String, in_deck: bool) -> void:
	if not Save.owns(id):
		_toast("Reach a higher arena to unlock this card")
		Sfx.play("error")
		return
	if _pick != "" and _pick != id:
		var a := _pick
		var ok := Save.swap(id, a) if in_deck else Save.swap(a, id)
		if ok:
			Sfx.play("place")
		_pick = ""
		open_cards()
		return
	if Save.can_upgrade(id):
		Save.upgrade(id)
		Sfx.play("buy")
		_toast("%s is now level %d!" % [GameData.card(id)["name"], Save.level(id)])
		open_cards()
		return
	_pick = "" if _pick == id else id
	open_cards()
	if _pick != "":
		_toast("Now tap a card to swap with")


func open_cards() -> void:
	var keep := _pick
	var v := _panel("Battle deck", 1020)
	_pick = keep
	var deck_row := GridContainer.new()
	deck_row.columns = 8
	deck_row.add_theme_constant_override("h_separation", 6)
	v.add_child(deck_row)
	for id in Save.deck:
		deck_row.add_child(_card_tile(id, true))
	var avg := 0.0
	for id in Save.deck:
		avg += float(GameData.card(id)["cost"])
	v.add_child(UI.ink("Average mana: %.1f   ·   Tap two cards to swap them, tap a card with a green arrow to upgrade it" % (avg / Save.deck.size()), 18))
	var others := GridContainer.new()
	others.columns = 8
	others.add_theme_constant_override("h_separation", 6)
	v.add_child(others)
	for id in GameData.CARD_ORDER:
		if not Save.deck.has(id):
			others.add_child(_card_tile(id, false))


func open_arenas() -> void:
	var v := _panel("Arenas", 820)
	for i in GameData.ARENAS.size():
		var a: Dictionary = GameData.ARENAS[i]
		var reached := Save.trophies >= int(a["trophies"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.card_style((a["ground"] as Color).lightened(0.2) if reached else Color(0.7, 0.7, 0.72)))
		v.add_child(row)
		var h := UI.hbox(12)
		row.add_child(h)
		h.add_child(UI.icon("trophy" if reached else "lock", 46))
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.ink("Arena %d: %s  (%d trophies)" % [i + 1, a["name"], int(a["trophies"])], 24))
		var names: Array = []
		for id in a["unlock"]:
			names.append(GameData.card(id)["name"])
		info.add_child(UI.ink("Unlocks: " + ", ".join(names), 18))
