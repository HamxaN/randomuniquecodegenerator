class_name BattleHud
extends CanvasLayer
## The battle's screen: crowns and the clock on top, health bars over towers
## and troops, the mana bar and your four cards (plus the next one) along the
## bottom, toasts, and the results with the chest you won.

signal home_pressed
signal again_pressed

const SPELL_ICON := {"fireball": "flame", "freeze": "snow", "heal": "heal"}

var battle: Battle
var _root: Control
var _overlay: Bars
var _clock: Label
var _blue_crowns: Array[Icon] = []
var _red_crowns: Array[Icon] = []
var _mana_bar: ProgressBar
var _mana_label: Label
var _hand: HBoxContainer
var _next: TextureRect
var _hand_sig := ""
var _buttons := {}
var _toast: Label
var _toast_t := 0.0
var _modal: Control
var _x2: Label


class Bars:
	extends Control
	var hud: BattleHud

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if hud.battle == null:
			return
		var font := UI.font()
		for b in hud.battle.bars():
			var p: Vector2 = b["pos"]
			var w := 74.0 if b["tower"] else 40.0
			var h := 12.0 if b["tower"] else 7.0
			var col := Color("3f9de0") if int(b["side"]) == BattleSim.YOU else Color("e6463a")
			draw_rect(Rect2(p - Vector2(w / 2 + 2, h / 2 + 2), Vector2(w + 4, h + 4)), Color(0.05, 0.04, 0.08, 0.85))
			draw_rect(Rect2(p - Vector2(w / 2, h / 2), Vector2(w * float(b["frac"]), h)), col)
			if b["tower"]:
				var txt := str(b["hp"])
				var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
				draw_string(font, p + Vector2(-sz.x / 2, -h), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_overlay = Bars.new()
	_overlay.hud = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_build_top()
	_build_bottom()
	_toast = UI.label("", 32)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = -40
	_toast.offset_bottom = 0
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_x2 = UI.label("x2 MANA!", 40, Color("d8b4ff"))
	_x2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_x2.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_x2.offset_left = -200
	_x2.offset_right = 200
	_x2.offset_top = 70
	_x2.offset_bottom = 120
	_x2.visible = false
	_root.add_child(_x2)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	Ads.hide_banner()


func _glass(color: Color) -> StyleBoxFlat:
	var s := UI.box(color, 16, Color(1, 1, 1, 0.2), 2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	return s


func _build_top() -> void:
	var you := PanelContainer.new()
	you.add_theme_stylebox_override("panel", _glass(Color(0.1, 0.3, 0.6, 0.8)))
	you.position = Vector2(12, 10)
	you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(you)
	var yh := UI.hbox(6)
	you.add_child(yh)
	yh.add_child(UI.label("You", 26))
	for i in 3:
		var c := UI.icon("crown_empty", 34)
		yh.add_child(c)
		_blue_crowns.append(c)
	var foe := PanelContainer.new()
	foe.add_theme_stylebox_override("panel", _glass(Color(0.6, 0.12, 0.1, 0.8)))
	foe.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	foe.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foe.offset_right = -12
	foe.offset_top = 10
	foe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(foe)
	var fh := UI.hbox(6)
	foe.add_child(fh)
	for i in 3:
		var c := UI.icon("crown_empty", 34)
		fh.add_child(c)
		_red_crowns.append(c)
	fh.add_child(UI.label("Bone Army", 26))
	var clock := PanelContainer.new()
	clock.add_theme_stylebox_override("panel", _glass(Color(0.05, 0.05, 0.1, 0.75)))
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock.offset_top = 8
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clock)
	_clock = UI.label("3:00", 34, Color("ffe7a8"))
	clock.add_child(_clock)


func _build_bottom() -> void:
	var tray := PanelContainer.new()
	var ts := UI.box(Color(0.12, 0.1, 0.18, 0.88), 20, Color(1, 1, 1, 0.15), 2)
	ts.content_margin_left = 14
	ts.content_margin_right = 14
	ts.content_margin_top = 8
	ts.content_margin_bottom = 10
	tray.add_theme_stylebox_override("panel", ts)
	tray.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tray.offset_bottom = -6
	_root.add_child(tray)
	var v := UI.vbox(6)
	tray.add_child(v)
	var row := UI.hbox(10)
	v.add_child(row)
	var nv := UI.vbox(0)
	nv.add_child(UI.label("Next", 16, Color(0.8, 0.8, 0.9)))
	_next = TextureRect.new()
	_next.custom_minimum_size = Vector2(60, 70)
	_next.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nv.add_child(_next)
	row.add_child(nv)
	_hand = UI.hbox(8)
	row.add_child(_hand)
	var mrow := UI.hbox(8)
	v.add_child(mrow)
	mrow.add_child(UI.icon("mana", 30))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(560, 26)
	mrow.add_child(holder)
	_mana_bar = UI.bar(Color("c34dff"), Vector2(560, 24))
	_mana_bar.max_value = GameData.MAX_MANA
	holder.add_child(_mana_bar)
	for i in range(1, int(GameData.MAX_MANA)):
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.35)
		tick.size = Vector2(2, 24)
		tick.position = Vector2(560.0 * i / GameData.MAX_MANA, 0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tick)
	_mana_label = UI.label("5", 26)
	mrow.add_child(_mana_label)


func _card_button(card_id: String) -> Button:
	var c := GameData.card(card_id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(108, 132)
	var col: Color = GameData.RARITY_COLOR[c.get("rarity", "common")]
	b.add_theme_stylebox_override("normal", _card_style(col, false))
	b.add_theme_stylebox_override("hover", _card_style(col, false))
	b.add_theme_stylebox_override("pressed", _card_style(col, true))
	b.add_theme_stylebox_override("disabled", _card_style(Color(0.4, 0.4, 0.45), false))
	var art: Control
	if GameData.is_spell(card_id):
		art = UI.icon(SPELL_ICON.get(card_id, "flame"), 72)
		art.position = Vector2(18, 16)
	else:
		var tex := TextureRect.new()
		tex.texture = Thumbs.card(battle, card_id, 140)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(4, 6)
		tex.size = Vector2(100, 100)
		art = tex
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var cost := PanelContainer.new()
	cost.add_theme_stylebox_override("panel", UI.box(Color("c34dff"), 16, Color(0.1, 0.02, 0.15), 2))
	cost.position = Vector2(-8, -8)
	cost.custom_minimum_size = Vector2(32, 32)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := UI.label(str(int(c["cost"])), 22)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_child(cl)
	b.add_child(cost)
	var name_l := UI.label(c["name"], 15)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 106)
	name_l.size = Vector2(108, 22)
	b.add_child(name_l)
	b.pressed.connect(func() -> void:
		if battle.selected == card_id:
			battle.select("")
		else:
			battle.select(card_id)
			Sfx.play("click")
		_refresh_selection())
	return b


func _card_style(col: Color, pressed: bool) -> StyleBoxFlat:
	var s := UI.box(Color(0.92, 0.92, 0.96), 12, col, 4)
	s.border_width_bottom = 4 if pressed else 8
	return s


func _refresh_selection() -> void:
	for id in _buttons:
		var b: Button = _buttons[id]
		var sel: bool = battle.selected == id
		b.pivot_offset = b.size / 2
		b.scale = Vector2.ONE * (1.1 if sel else 1.0)
		b.modulate = Color(1.2, 1.2, 0.85) if sel else Color.WHITE


func _process(delta: float) -> void:
	var sim := battle.sim
	var left := sim.time_left()
	_clock.text = ("OT " if sim.overtime() else "") + "%d:%02d" % [int(ceil(left)) / 60, int(ceil(left)) % 60]
	_x2.visible = left <= 60.0 and not sim.over and int(_x2.get_meta("blink", 0)) == 0
	var m := float(sim.mana[BattleSim.YOU])
	_mana_bar.value = m
	_mana_label.text = str(int(m))
	var hand: Array = sim.hands[BattleSim.YOU]
	var sig := str(hand)
	if sig != _hand_sig:
		_hand_sig = sig
		for c in _hand.get_children():
			c.queue_free()
		_buttons.clear()
		for id in hand:
			var b := _card_button(id)
			_hand.add_child(b)
			_buttons[id] = b
		var nxt := sim.next_card(BattleSim.YOU)
		_next.texture = Thumbs.card(battle, nxt, 140) if nxt != "" and not GameData.is_spell(nxt) else null
		_refresh_selection()
	for id in _buttons:
		var b: Button = _buttons[id]
		var cost := float(GameData.card(id)["cost"])
		b.self_modulate = Color.WHITE if m >= cost else Color(0.55, 0.55, 0.6)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 3.0, 0.0, 1.0)


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.4


func crown(side: int, keep: bool) -> void:
	var list := _blue_crowns if side == BattleSim.YOU else _red_crowns
	var n := 0
	for c in list:
		if c.kind == "crown":
			n += 1
	n = 3 if keep else mini(n + 1, 3)
	for i in list.size():
		if i < n and list[i].kind != "crown":
			list[i].kind = "crown"
			list[i].tint = Color("3f9de0") if side == BattleSim.YOU else Color("e6463a")
			UI.pop(list[i], 0.2)
	Sfx.play("crown")


func _panel(title: String, color: Color) -> VBoxContainer:
	for c in _modal.get_children():
		c.queue_free()
	_modal.add_child(UI.dim(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var t := UI.label(title, 60, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func show_results(result: Dictionary, chest: Dictionary) -> void:
	var won: bool = result["won"]
	var title := "VICTORY!" if won else ("DRAW" if result["draw"] else "DEFEAT")
	var v := _panel(title, UI.GOLD if won else (UI.GREY if result["draw"] else Color("ff6b5a")))
	var crowns := UI.hbox(10)
	crowns.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var c := UI.icon("crown" if i < int(result["crowns"]) else "crown_empty", 70)
		c.tint = Color("3f9de0")
		crowns.add_child(c)
	v.add_child(crowns)
	var row := UI.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var tr := UI.hbox(6)
	tr.add_child(UI.icon("trophy", 40))
	var td := int(result["trophies"])
	tr.add_child(UI.ink(("+%d" % td) if td >= 0 else str(td), 34))
	row.add_child(tr)
	var gr := UI.hbox(6)
	gr.add_child(UI.icon("gold", 40))
	var gold_l := UI.ink("+%d" % (int(result["gold"]) + int(chest.get("gold", 0))), 34)
	gr.add_child(gold_l)
	row.add_child(gr)
	var shards: Dictionary = chest.get("shards", {})
	if not shards.is_empty():
		var ch := UI.ink("Chest:", 24)
		var srow := UI.hbox(8)
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		srow.add_child(ch)
		for id in shards:
			var cardrow := UI.hbox(2)
			if GameData.is_spell(id):
				cardrow.add_child(UI.icon(SPELL_ICON.get(id, "flame"), 44))
			else:
				var t := TextureRect.new()
				t.texture = Thumbs.card(battle, id, 120)
				t.custom_minimum_size = Vector2(52, 52)
				t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				cardrow.add_child(t)
			cardrow.add_child(UI.ink("x%d" % int(shards[id]), 22))
			srow.add_child(cardrow)
		v.add_child(srow)
	for id in chest.get("new", []):
		var nl := UI.label("New card unlocked: %s!" % GameData.card(id)["name"], 26, Color("8ff2a2"))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	if chest.get("arena_up", false):
		var al := UI.label("New arena: %s!" % GameData.ARENAS[GameData.arena_index(Save.trophies)]["name"], 28, UI.GOLD)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(al)
	var buttons := UI.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	var gold_won := int(result["gold"])
	if gold_won > 0:
		var dbl := UI.button("x2 Gold", UI.PURPLE, Vector2(180, 66), 28)
		var reward := func() -> void:
			Save.gold += gold_won
			Save.store()
			gold_l.text = "+%d" % (gold_won * 2 + int(chest.get("gold", 0)))
			Sfx.play("crown")
		dbl.pressed.connect(func() -> void:
			dbl.disabled = true
			Ads.show_rewarded(reward))
		buttons.add_child(dbl)
	var again := UI.button("Battle again", UI.ORANGE, Vector2(210, 66), 28)
	again.pressed.connect(func() -> void: again_pressed.emit())
	buttons.add_child(again)
	var home := UI.button("Home", UI.BLUE, Vector2(150, 66), 28)
	home.pressed.connect(func() -> void: home_pressed.emit())
	buttons.add_child(home)
