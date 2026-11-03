class_name FieldHud
extends CanvasLayer
## The screens over the graveyard: XP bar and level, the night clock, kills and
## gold, health, the weapon and relic slots, the boss bar, level-up cards,
## pause and the results at dawn (or death).

signal retry_pressed
signal menu_pressed

var field: Field
var _root: Control
var _xp: ProgressBar
var _level: Label
var _clock: Label
var _kills: Label
var _gold: Label
var _hp: ProgressBar
var _slots: HBoxContainer
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _banner: Label
var _hurt: ColorRect
var _modal: Control
var _stick: Joystick
var _slot_sig := ""


static func choice_name(c: Dictionary) -> String:
	match c["kind"]:
		"weapon":
			return GameData.WEAPONS[c["id"]]["name"]
		"relic":
			return GameData.RELICS[c["id"]]["name"]
	return "25 gold"


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.color = Color(0.8, 0.05, 0.05, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt)
	_stick = Joystick.new()
	_stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_stick)
	# XP across the top.
	_xp = UI.bar(Color("4fc8ff"), Vector2(100, 22))
	_xp.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_xp.offset_left = 70
	_xp.offset_right = -10
	_xp.offset_top = 8
	_xp.offset_bottom = 30
	_root.add_child(_xp)
	var badge := PanelContainer.new()
	var bs := UI.box(Color("2a6bb0"), 24, Color(0.05, 0.05, 0.1), 3)
	badge.add_theme_stylebox_override("panel", bs)
	badge.position = Vector2(8, 2)
	badge.custom_minimum_size = Vector2(56, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(badge)
	_level = UI.label("1", 28)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(_level)
	_clock = UI.label("10:00", 44, Color("ffe7a8"))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_left = -120
	_clock.offset_right = 120
	_clock.offset_top = 32
	_clock.offset_bottom = 84
	_root.add_child(_clock)
	var right := UI.vbox(2)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -96
	right.offset_top = 36
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var kr := UI.hbox(6)
	kr.add_child(UI.icon("skull", 30))
	_kills = UI.label("0", 26)
	kr.add_child(_kills)
	right.add_child(kr)
	var gr := UI.hbox(6)
	gr.add_child(UI.icon("gold", 30))
	_gold = UI.label("0", 26, UI.GOLD)
	gr.add_child(_gold)
	right.add_child(gr)
	var pause := UI.round_button("pause", "", UI.BLUE, 60)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -76
	pause.offset_right = -16
	pause.offset_top = 38
	pause.offset_bottom = 98
	pause.pressed.connect(show_pause)
	_root.add_child(pause)
	var left := UI.vbox(6)
	left.position = Vector2(12, 40)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	var hr := UI.hbox(6)
	hr.add_child(UI.icon("heart", 30))
	_hp = UI.bar(Color("e6463a"), Vector2(200, 18))
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(_hp)
	left.add_child(hr)
	_slots = UI.hbox(4)
	left.add_child(_slots)
	_boss_box = UI.vbox(2)
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = 88
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	var bl := UI.label("BONE COLOSSUS", 24, Color("ff8a7a"))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bl)
	_boss_bar = UI.bar(Color("c0392b"), Vector2(520, 20))
	_boss_box.add_child(_boss_bar)
	_banner = UI.label("", 46, UI.GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -640
	_banner.offset_right = 640
	_banner.offset_top = -200
	_banner.offset_bottom = -140
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	Ads.hide_banner()


func _process(_delta: float) -> void:
	var f := field
	if f == null:
		return
	f.input_move = Vector3(_stick.value.x, 0, _stick.value.y)
	_xp.max_value = GameData.xp_to_next(f.run.level)
	_xp.value = f.run.xp
	_level.text = str(f.run.level)
	var left := maxf(0.0, GameData.NIGHT_LENGTH - f.clock)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_kills.text = UI.fmt(f.run.kills)
	_gold.text = UI.fmt(f.run.gold)
	_hp.max_value = f.run.max_hp()
	_hp.value = f.hp
	_boss_box.visible = not f.boss.is_empty()
	if not f.boss.is_empty():
		_boss_bar.max_value = float(f.boss["max"])
		_boss_bar.value = float(f.boss["hp"])
	_hurt.color.a = maxf(0.0, _hurt.color.a - get_process_delta_time() * 1.5)
	var sig := str(f.run.weapons) + str(f.run.relics)
	if sig != _slot_sig:
		_slot_sig = sig
		_rebuild_slots()


func _rebuild_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	for id in field.run.weapons:
		_slots.add_child(_slot(GameData.WEAPONS[id]["icon"], int(field.run.weapons[id]), Color(0.25, 0.2, 0.4, 0.85)))
	for id in field.run.relics:
		_slots.add_child(_slot(GameData.RELICS[id]["icon"], int(field.run.relics[id]), Color(0.15, 0.3, 0.3, 0.85)))


func _slot(icon: String, level: int, bg: Color) -> Control:
	var p := PanelContainer.new()
	var s := UI.box(bg, 8, Color(1, 1, 1, 0.25), 2)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(38, 38)
	p.add_child(holder)
	holder.add_child(UI.icon(icon, 38))
	var l := UI.label(str(level), 16)
	l.position = Vector2(26, 20)
	holder.add_child(l)
	return p


func hurt_flash() -> void:
	_hurt.color.a = 0.28


func banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _clear() -> void:
	for c in _modal.get_children():
		c.queue_free()


func _panel(title: String, color: Color = UI.GOLD) -> VBoxContainer:
	_clear()
	_modal.add_child(UI.dim(0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var v := UI.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var t := UI.label(title, 58, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func show_choices(choices: Array[Dictionary]) -> void:
	get_tree().paused = true
	var v := _panel("LEVEL UP!")
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for c in choices:
		var info: Dictionary = {}
		if c["kind"] == "weapon":
			info = GameData.WEAPONS[c["id"]]
		elif c["kind"] == "relic":
			info = GameData.RELICS[c["id"]]
		else:
			info = {"name": "Gold", "desc": "+25 gold", "icon": "gold"}
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(250, 300)
		var col := Color("3d3558") if c["kind"] != "weapon" else Color("4a3a6e")
		card.add_theme_stylebox_override("normal", UI.card_style(col))
		card.add_theme_stylebox_override("hover", UI.card_style(col.lightened(0.12)))
		card.add_theme_stylebox_override("pressed", UI.card_style(col.darkened(0.1)))
		row.add_child(card)
		var cv := UI.vbox(6)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 12
		cv.offset_right = -12
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var tag := "NEW!" if int(c["level"]) == 1 else "Level %d" % int(c["level"])
		if c["kind"] == "gold":
			tag = ""
		var tl := UI.label(tag, 22, Color("8ff2a2") if int(c["level"]) == 1 else Color("ffd23a"))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tl)
		var ic := CenterContainer.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(UI.icon(info["icon"], 96))
		cv.add_child(ic)
		var nl := UI.label(info["name"], 28)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var dl := UI.label(info["desc"], 20, Color(0.85, 0.82, 0.95))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size = Vector2(220, 0)
		cv.add_child(dl)
		var choice: Dictionary = c
		card.pressed.connect(func() -> void:
			_clear()
			get_tree().paused = false
			Sfx.play("buy")
			field.choose(choice))
		UI.pop(card, 0.5)


func show_pause() -> void:
	if field.state != "play":
		return
	get_tree().paused = true
	var v := _panel("Paused")
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var resume := UI.button("Resume", UI.GREEN, Vector2(200, 70))
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_clear())
	row.add_child(resume)
	var quit := UI.button("Give up", UI.RED, Vector2(180, 70))
	quit.pressed.connect(func() -> void:
		_clear()
		get_tree().paused = false
		field.state = "dead"
		show_results(field._result(false)))
	row.add_child(quit)


func show_results(result: Dictionary) -> void:
	var survived: bool = result["survived"]
	var v := _panel("YOU SURVIVED!" if survived else "THE NIGHT TOOK YOU", UI.GOLD if survived else Color("ff8a7a"))
	var t := float(result["time"])
	var stats := UI.label("Time %d:%02d   ·   Kills %s   ·   Level %d" % [int(t) / 60, int(t) % 60, UI.fmt(int(result["kills"])),
		int(result["level"])], 30)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var best := Save.finish_run(t, int(result["kills"]), int(result["gold"]), survived)
	Ads.match_finished()
	var gr := UI.hbox(8)
	gr.alignment = BoxContainer.ALIGNMENT_CENTER
	gr.add_child(UI.icon("gold", 48))
	var amount := UI.label("+%s gold" % UI.fmt(int(result["gold"])), 44, UI.GOLD)
	gr.add_child(amount)
	v.add_child(gr)
	if best:
		var nb := UI.label("New best time!", 28, Color("8ff2a2"))
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nb)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	if not survived and not field.revived:
		var rev := UI.button("Revive", UI.PURPLE, Vector2(200, 70), 30)
		rev.add_child(_at(UI.icon("ad", 30), Vector2(12, 18)))
		var back := func() -> void:
			# The gold was already banked; carry on into the night.
			Save.gold -= int(result["gold"])
			Save.store()
			_clear()
			field.revive()
		rev.pressed.connect(func() -> void: Ads.show_rewarded(back))
		row.add_child(rev)
	if int(result["gold"]) > 0:
		var dbl := UI.button("x2 Gold", UI.ORANGE, Vector2(190, 70), 30)
		dbl.add_child(_at(UI.icon("ad", 30), Vector2(12, 18)))
		var reward := func() -> void:
			Save.gold += int(result["gold"])
			Save.store()
			amount.text = "+%s gold" % UI.fmt(int(result["gold"]) * 2)
			UI.pop(amount, 0.6)
			Sfx.play("levelup")
		dbl.pressed.connect(func() -> void:
			dbl.disabled = true
			Ads.show_rewarded(reward))
		row.add_child(dbl)
	var again := UI.button("Play again", UI.GREEN, Vector2(210, 70), 30)
	again.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(again)
	var menu := UI.button("Camp", UI.BLUE, Vector2(150, 70), 30)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu)


func _at(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c
