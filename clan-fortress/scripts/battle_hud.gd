class_name BattleHud
extends Control
## Raid HUD: enemy name and loot top left, timer, destruction and stars top
## right, the troop bar along the bottom, and the victory/defeat screen.

var battle: Battle
var _timer: Label
var _timer_caption: Label
var _percent: Label
var _stars: Array[Icon] = []
var _gold: Label
var _wood: Label
var _troop_row: HBoxContainer
var _cards := {}
var _toast: Label
var _announce: Label
var _end_button: Button
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_bars)
	add_child(_overlay)
	_build_top_left()
	_build_top_right()
	_build_troop_bar()
	_toast = UI.label("", 34)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 150
	_toast.modulate.a = 0.0
	add_child(_toast)
	_announce = UI.label("", 52, UI.GOLD)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.set_anchors_preset(Control.PRESET_CENTER)
	_announce.offset_left = -500
	_announce.offset_right = 500
	_announce.offset_top = -120
	_announce.modulate.a = 0.0
	add_child(_announce)


func _corner(preset: int, offset: Vector2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x
	c.offset_bottom = offset.y
	add_child(c)
	return c


func _build_top_left() -> void:
	var holder := _corner(Control.PRESET_TOP_LEFT, Vector2(24, 18))
	var col := UI.vbox(2)
	holder.add_child(col)
	col.add_child(UI.label("%d. %s" % [battle.level_n, GameData.enemy_name(battle.level_n)], 34))
	col.add_child(UI.label("Available loot:", 22, Color(0.95, 0.92, 0.85)))
	var g := UI.hbox(8)
	g.add_child(UI.icon("gold", 36))
	_gold = UI.label(UI.fmt(int(battle.loot_total["gold"])), 30, UI.GOLD)
	g.add_child(_gold)
	col.add_child(g)
	var w := UI.hbox(8)
	w.add_child(UI.icon("wood", 36))
	_wood = UI.label(UI.fmt(int(battle.loot_total["wood"])), 30, Color("f0c58a"))
	w.add_child(_wood)
	col.add_child(w)


func _build_top_right() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-330, 14))
	var col := UI.vbox(0)
	col.custom_minimum_size = Vector2(310, 0)
	holder.add_child(col)
	_timer_caption = UI.label("Deploy troops to start", 22, Color(0.95, 0.92, 0.85))
	_timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_timer_caption)
	_timer = UI.label("2m 30s", 44)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_timer)
	var row := UI.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	for i in 3:
		var s := UI.icon("star_empty", 44)
		row.add_child(s)
		_stars.append(s)
	_percent = UI.label("0%", 40)
	row.add_child(_percent)


func _build_troop_bar() -> void:
	var bar := PanelContainer.new()
	var st := UI.box(Color(0.1, 0.08, 0.06, 0.78), 18, Color(0, 0, 0, 0.9), 3)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", st)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -170
	bar.offset_bottom = -12
	add_child(bar)
	_troop_row = UI.hbox(10)
	bar.add_child(_troop_row)
	_end_button = UI.button("End Battle", UI.RED, Vector2(200, 64), 28)
	_end_button.pressed.connect(func() -> void:
		if battle.started:
			battle.finish()
		else:
			battle.exit_requested.emit())
	var end_holder := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(24, -90))
	end_holder.add_child(_end_button)
	refresh_troops()


func refresh_troops() -> void:
	for t in GameData.TROOP_ORDER:
		if not battle.available.has(t):
			continue
		if not _cards.has(t):
			var card := Button.new()
			card.custom_minimum_size = Vector2(118, 140)
			card.focus_mode = Control.FOCUS_NONE
			var tex := TextureRect.new()
			tex.texture = Thumbs.get_texture(self, "troop:" + t, 160)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex.offset_top = 6
			tex.offset_bottom = -6
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(tex)
			var count := UI.label("x0", 30)
			count.name = "Count"
			count.position = Vector2(8, 2)
			card.add_child(count)
			var lv := UI.label("Lv%d" % Save.troop_level(t), 20)
			lv.position = Vector2(8, 108)
			card.add_child(lv)
			var kind: String = t
			card.pressed.connect(func() -> void:
				battle.selected = kind
				Sfx.play("click")
				refresh_troops())
			_troop_row.add_child(card)
			_cards[t] = card
		var c: Button = _cards[t]
		var left := int(battle.available.get(t, 0))
		(c.get_node("Count") as Label).text = "x%d" % left
		var sel: bool = battle.selected == t
		var color: Color = GameData.troop(t)["color"]
		var st := UI.card_style(color.lightened(0.25) if sel else Color(0.55, 0.5, 0.45))
		if sel:
			st.border_color = Color.WHITE
			st.set_border_width_all(4)
			st.border_width_bottom = 8
		c.add_theme_stylebox_override("normal", st)
		c.add_theme_stylebox_override("hover", st)
		c.add_theme_stylebox_override("pressed", st)
		c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		c.modulate = Color(1, 1, 1, 0.45) if left <= 0 else Color.WHITE


func _process(_delta: float) -> void:
	if battle == null:
		return
	var s := int(ceil(battle.time_left))
	_timer.text = "%dm %02ds" % [s / 60, s % 60]
	_timer_caption.text = "Battle ends in:" if battle.started else "Deploy troops to start"
	_timer.add_theme_color_override("font_color", UI.RED if s <= 20 and battle.started else UI.TEXT)
	_percent.text = "%d%%" % int(round(battle.destruction() * 100.0))
	_gold.text = UI.fmt(int(battle.loot_total["gold"]) - int(battle.loot_taken["gold"]))
	_wood.text = UI.fmt(int(battle.loot_total["wood"]) - int(battle.loot_taken["wood"]))
	_end_button.text = "End Battle" if battle.started else "Return Home"
	_overlay.queue_redraw()


func _draw_bars() -> void:
	var cam: Camera3D = battle.rig.camera if battle.rig != null else null
	if cam == null:
		return
	for b in battle.buildings:
		if b.destroyed or b.hp >= b.max_hp:
			continue
		var p := cam.unproject_position(b.top())
		var w := 58.0
		_overlay.draw_rect(Rect2(p.x - w / 2 - 2, p.y - 2, w + 4, 11), Color(0, 0, 0, 0.75))
		var frac := b.hp / b.max_hp
		_overlay.draw_rect(Rect2(p.x - w / 2, p.y, w * frac, 7), UI.GREEN if frac > 0.5 else (UI.ORANGE if frac > 0.25 else UI.RED))
	for t in battle.troops:
		if t.dead or t.hp >= t.max_hp:
			continue
		var p := cam.unproject_position(t.head())
		var w := 30.0
		_overlay.draw_rect(Rect2(p.x - w / 2 - 1, p.y - 1, w + 2, 7), Color(0, 0, 0, 0.75))
		_overlay.draw_rect(Rect2(p.x - w / 2, p.y, w * t.hp / t.max_hp, 5), Color("5be3ff"))


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func announce(text: String) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0
	_announce.pivot_offset = _announce.size / 2
	_announce.scale = Vector2(1.4, 1.4)
	var tw := _announce.create_tween()
	tw.tween_property(_announce, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(_announce, "modulate:a", 0.0, 0.4)


func star_earned(count: int) -> void:
	for i in _stars.size():
		_stars[i].kind = "star" if i < count else "star_empty"
	var s := _stars[count - 1]
	s.pivot_offset = s.size / 2
	s.scale = Vector2(2.2, 2.2)
	s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_results(stars: int, frac: float, loot: Dictionary) -> void:
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	m.add_child(UI.dim(0.5))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var title := UI.label("VICTORY!" if stars > 0 else "DEFEAT", 84, UI.GOLD if stars > 0 else UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var star_row := UI.hbox(10)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(star_row)
	for i in 3:
		var s := UI.icon("star" if i < stars else "star_empty", 110 if i == 1 else 88)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		star_row.add_child(s)
		if i < stars:
			s.pivot_offset = s.custom_minimum_size / 2
			s.scale = Vector2.ZERO
			var tw := s.create_tween()
			tw.tween_interval(0.25 + i * 0.3)
			tw.tween_callback(func() -> void: Sfx.play("star", 1.0 + i * 0.15))
			tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pct := UI.label("%d%% destroyed" % int(round(frac * 100.0)), 38)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pct)
	var card := UI.panel()
	col.add_child(card)
	var rows := UI.vbox(6)
	card.add_child(rows)
	rows.add_child(UI.ink("Loot", 30))
	var lr := UI.hbox(30)
	rows.add_child(lr)
	var gl := UI.hbox(8)
	gl.add_child(UI.icon("gold", 44))
	var gold_label := UI.label(UI.fmt(int(loot["gold"])), 40, UI.GOLD)
	gl.add_child(gold_label)
	lr.add_child(gl)
	var wl := UI.hbox(8)
	wl.add_child(UI.icon("wood", 44))
	var wood_label := UI.label(UI.fmt(int(loot["wood"])), 40, Color("f0c58a"))
	wl.add_child(wood_label)
	lr.add_child(wl)
	var buttons := UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	if int(loot["gold"]) + int(loot["wood"]) > 0:
		var dbl := UI.button("  Double loot", UI.PURPLE, Vector2(280, 76), 30)
		var ad := UI.icon("ad", 36)
		ad.position = Vector2(16, 18)
		dbl.add_child(ad)
		dbl.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void:
				Save.gold += int(loot["gold"])
				Save.wood += int(loot["wood"])
				Save.store()
				gold_label.text = UI.fmt(int(loot["gold"]) * 2)
				wood_label.text = UI.fmt(int(loot["wood"]) * 2)
				Sfx.play("coin")
				dbl.disabled = true))
		buttons.add_child(dbl)
	var home := UI.button("Return Home", UI.GREEN, Vector2(280, 76), 32)
	home.pressed.connect(func() -> void: battle.exit_requested.emit())
	buttons.add_child(home)
	UI.pop(col, 0.8)
