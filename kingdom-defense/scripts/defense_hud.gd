class_name DefenseHud
extends Control
## The battle HUD: lives, gold and wave top left, speed and "call wave" top
## right, the build menu and tower menu, enemy health bars, and the end screen.

var defense: Defense
var _lives: Label
var _gold: Label
var _wave: Label
var _speed_button: Button
var _call: Button
var _menu: Control
var _toast: Label
var _banner: Label
var _banner_sub: Label
var _overlay: Control
var _hurt: ColorRect
var _modal: Control
var _menu_tower: Tower


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_bars)
	add_child(_overlay)
	_hurt = ColorRect.new()
	_hurt.color = Color(0.9, 0.1, 0.05, 0.0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)
	_build_top_left()
	_build_top_right()
	_toast = UI.label("", 34)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -450
	_toast.offset_right = 450
	_toast.offset_top = 120
	_toast.modulate.a = 0.0
	add_child(_toast)
	_banner = UI.label("", 76, UI.GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -170
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_sub = UI.label("", 34)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	_banner_sub.offset_left = -500
	_banner_sub.offset_right = 500
	_banner_sub.offset_top = -80
	_banner_sub.modulate.a = 0.0
	add_child(_banner_sub)
	if not Save.tutorial_done:
		_tutorial()


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
	var holder := _corner(Control.PRESET_TOP_LEFT, Vector2(20, 12))
	var col := UI.vbox(2)
	holder.add_child(col)
	col.add_child(UI.label("%d. %s" % [defense.level_n, GameData.NAMES[defense.level_n - 1]], 30))
	var row := UI.hbox(18)
	col.add_child(row)
	var l := UI.hbox(6)
	l.add_child(UI.icon("heart", 40, UI.RED))
	_lives = UI.label("20", 38)
	l.add_child(_lives)
	row.add_child(l)
	var g := UI.hbox(6)
	g.add_child(UI.icon("gold", 40))
	_gold = UI.label("0", 38, UI.GOLD)
	g.add_child(_gold)
	row.add_child(g)
	_wave = UI.label("", 30)
	col.add_child(_wave)


func _build_top_right() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-380, 14))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.custom_minimum_size = Vector2(360, 0)
	holder.add_child(row)
	_call = UI.button("Call wave", UI.ORANGE, Vector2(180, 62), 26)
	_call.pressed.connect(func() -> void: defense.start_wave())
	row.add_child(_call)
	_speed_button = UI.button("1x", UI.BLUE, Vector2(80, 62), 28)
	_speed_button.pressed.connect(func() -> void:
		defense.speed = 2.0 if defense.speed < 1.5 else 1.0
		_speed_button.text = "%dx" % int(defense.speed))
	row.add_child(_speed_button)
	var pause := UI.button("II", Color(0.5, 0.52, 0.56), Vector2(64, 62), 28)
	pause.pressed.connect(_pause)
	row.add_child(pause)


func _tutorial() -> void:
	var holder := _corner(Control.PRESET_CENTER_BOTTOM, Vector2(-340, -170))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.parchment_style())
	p.custom_minimum_size = Vector2(680, 0)
	holder.add_child(p)
	var col := UI.vbox(4)
	p.add_child(col)
	for line in ["Tap the grass beside the road to build a tower.",
			"Tap a tower to upgrade it. Tap anywhere else to send your knight there.",
			"Stop the skeletons before they reach your castle!"]:
		col.add_child(UI.ink(line, 24))
	var tw := p.create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(holder.queue_free)
	Save.tutorial_done = true
	Save.store()


func _process(delta: float) -> void:
	if defense == null:
		return
	_lives.text = str(defense.lives)
	_gold.text = UI.fmt(defense.gold)
	_wave.text = "Wave %d/%d" % [defense.wave, defense.waves]
	_call.visible = defense.state == "build" and defense.wave < defense.waves
	if _call.visible:
		_call.text = "Wave in %d" % int(ceil(defense._next_wave_t)) if defense.wave == 0 else "Call wave +%d" % int(defense._next_wave_t * 2.0)
	_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 0.8)
	if _menu_tower != null and _menu != null:
		_refresh_tower_buttons()
	_overlay.queue_redraw()


func _draw_bars() -> void:
	var cam := defense.rig.camera
	for e in defense.enemies:
		if e.dead or e.hp >= e.max_hp:
			continue
		var p := cam.unproject_position(e.head())
		var w := 34.0 * (1.6 if e.kind == "boss" else 1.0)
		_overlay.draw_rect(Rect2(p.x - w / 2 - 1, p.y - 1, w + 2, 7), Color(0, 0, 0, 0.75))
		_overlay.draw_rect(Rect2(p.x - w / 2, p.y, w * e.hp / e.max_hp, 5), UI.RED)
	var h := defense.hero
	if h != null:
		var p := cam.unproject_position(h.head())
		if h.dead:
			_overlay.draw_string(UI.font(), p + Vector2(-20, 0), "%d" % int(ceil(h.respawn)), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		else:
			_overlay.draw_rect(Rect2(p.x - 23, p.y - 1, 46, 8), Color(0, 0, 0, 0.75))
			_overlay.draw_rect(Rect2(p.x - 22, p.y, 44 * h.hp / h.max_hp, 6), UI.GREEN)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func banner(title: String, sub: String) -> void:
	_banner.text = title
	_banner_sub.text = sub
	for l in [_banner, _banner_sub]:
		(l as Label).modulate.a = 1.0
		var tw := (l as Label).create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(l, "modulate:a", 0.0, 0.4)


func hurt() -> void:
	_hurt.color.a = 0.35


func float_text(at: Vector2, text: String, color: Color) -> void:
	var l := UI.label(text, 28, color)
	l.position = at - Vector2(20, 30)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 40, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- Menus

func close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	if _menu_tower != null and is_instance_valid(_menu_tower):
		_menu_tower.select(false)
	_menu_tower = null


func _menu_panel(title: String) -> HBoxContainer:
	close_menu()
	_menu = _corner(Control.PRESET_CENTER_BOTTOM, Vector2(0, -20))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.parchment_style())
	_menu.add_child(p)
	var col := UI.vbox(6)
	p.add_child(col)
	var head := UI.hbox(8)
	col.add_child(head)
	var t := UI.ink(title, 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(44, 44)
	close.add_child(UI.icon("close", 42))
	close.pressed.connect(close_menu)
	head.add_child(close)
	var row := UI.hbox(10)
	col.add_child(row)
	p.resized.connect(func() -> void: p.position = Vector2(-p.size.x / 2, -p.size.y))
	UI.pop(p, 0.8)
	return row


func show_build_menu(cell: Vector2i) -> void:
	var row := _menu_panel("Build a tower")
	for kind in GameData.TOWER_ORDER:
		var info := GameData.tower(kind)
		var cost := int(GameData.at(info["cost"], 1))
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 190)
		card.focus_mode = Control.FOCUS_NONE
		var afford := defense.gold >= cost
		card.add_theme_stylebox_override("normal", UI.card_style(UI.PARCHMENT_DARK if afford else Color(0.72, 0.68, 0.6)))
		card.add_theme_stylebox_override("hover", UI.card_style(Color("ecdcae")))
		card.add_theme_stylebox_override("pressed", UI.card_style(Color("ecdcae")))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := UI.vbox(0)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var name_label := UI.label(info["name"], 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_label)
		var tex := TextureRect.new()
		tex.texture = Thumbs.get_texture(self, kind, 140)
		tex.custom_minimum_size = Vector2(130, 110)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tex)
		var price := UI.hbox(4)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.add_child(UI.icon("gold", 28))
		price.add_child(UI.label(str(cost), 26, Color.WHITE if afford else Color("ff8a80")))
		v.add_child(price)
		var k: String = kind
		card.pressed.connect(func() -> void:
			if defense.build(cell, k):
				close_menu())
		row.add_child(card)


func show_tower_menu(t: Tower) -> void:
	var row := _menu_panel("%s  (Level %d)" % [t.info()["name"], t.level])
	_menu_tower = t
	t.select(true)
	var desc := UI.ink(t.info()["desc"], 22)
	desc.custom_minimum_size = Vector2(260, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc)
	var up := UI.button("", UI.GREEN, Vector2(200, 70), 26)
	up.name = "Upgrade"
	up.pressed.connect(func() -> void:
		if defense.upgrade(t):
			show_tower_menu(t))
	row.add_child(up)
	var sell := UI.button("Sell %d" % GameData.sell_value(t.kind, t.level), UI.RED, Vector2(160, 70), 26)
	sell.pressed.connect(func() -> void:
		defense.sell(t)
		close_menu())
	row.add_child(sell)
	_refresh_tower_buttons()


func _refresh_tower_buttons() -> void:
	var up := _menu.find_child("Upgrade", true, false) as Button
	if up == null or not is_instance_valid(_menu_tower):
		return
	if _menu_tower.level >= 3:
		up.text = "Max level"
		up.disabled = true
	else:
		var cost := int(GameData.at(_menu_tower.info()["cost"], _menu_tower.level + 1))
		up.text = "Upgrade %d" % cost
		up.disabled = defense.gold < cost


func _modal_box() -> VBoxContainer:
	if _modal != null:
		_modal.queue_free()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_modal.add_child(UI.dim(0.5))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col


func show_end(won: bool, stars: int) -> void:
	close_menu()
	var col := _modal_box()
	var title := UI.label("VICTORY!" if won else "THE CASTLE FELL", 84, UI.GOLD if won else UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if won:
		var row := UI.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for i in 3:
			var s := UI.icon("star" if i < stars else "star_empty", 110 if i == 1 else 88)
			s.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(s)
	var info := UI.label("Lives left: %d   ·   Waves: %d/%d" % [defense.lives, defense.wave, defense.waves], 32)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(info)
	var buttons := UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	if not won:
		var again := UI.button("  Keep fighting", UI.PURPLE, Vector2(300, 76), 30)
		var ad := UI.icon("ad", 34)
		ad.position = Vector2(16, 20)
		again.add_child(ad)
		again.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void:
				_modal.queue_free()
				_modal = null
				defense.continue_with_ad()))
		buttons.add_child(again)
	if won and defense.level_n < GameData.LEVELS:
		var next := UI.button("Next level", UI.GREEN, Vector2(260, 76), 32)
		next.pressed.connect(func() -> void: defense.exit_requested.emit(true))
		buttons.add_child(next)
	var map := UI.button("Kingdom map", UI.BLUE, Vector2(260, 76), 30)
	map.pressed.connect(func() -> void: defense.exit_requested.emit(false))
	buttons.add_child(map)
	UI.pop(col, 0.8)


func _pause() -> void:
	get_tree().paused = true
	var col := _modal_box()
	col.add_child(UI.label("Paused", 70))
	var resume := UI.button("Resume", UI.GREEN, Vector2(300, 76), 32)
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_modal.queue_free()
		_modal = null)
	col.add_child(resume)
	var quit := UI.button("Quit level", UI.RED, Vector2(300, 70), 28)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		defense.exit_requested.emit(false))
	col.add_child(quit)
