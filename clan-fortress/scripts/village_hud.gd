class_name VillageHud
extends Control
## The home-village HUD, laid out like the big base-builders: level and XP top
## left, builders top centre, resources top right, ATTACK! bottom left, SHOP and
## ARMY bottom right, and the info bar for the selected building.

var village: Village

var _level: Label
var _xp_bar: ProgressBar
var _stars: Label
var _builders: Label
var _res := {}
var _selection: Control
var _placing_bar: Control
var _toast: Label
var _panel: Control
var _coach: Control
var _coach_label: Label
var _last_values := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom_buttons()
	_selection = _corner(Control.PRESET_CENTER_BOTTOM, Vector2(0, -24))
	_placing_bar = _corner(Control.PRESET_CENTER_BOTTOM, Vector2(0, -24))
	_toast = UI.label("", 34)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -450
	_toast.offset_right = 450
	_toast.offset_top = 130
	_toast.modulate.a = 0.0
	add_child(_toast)
	_build_coach()
	Save.changed.connect(refresh)
	refresh()


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
	var holder := _corner(Control.PRESET_TOP_LEFT, Vector2(20, 14))
	var row := UI.hbox(8)
	holder.add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(70, 70)
	badge.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(35, 2), Vector2(66, 14), Vector2(62, 46), Vector2(35, 68), Vector2(8, 46), Vector2(4, 14)])
		var edge := pts.duplicate()
		edge.append(pts[0])
		badge.draw_polyline(edge, Color(0.1, 0.06, 0.02), 7.0, true)
		badge.draw_colored_polygon(pts, Color("2f7fd0"))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(35, 35) + (p - Vector2(35, 35)) * 0.78)
		badge.draw_colored_polygon(inner, Color("4fa6f0")))
	_level = UI.label("1", 32)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.size = Vector2(70, 66)
	badge.add_child(_level)
	row.add_child(badge)
	var col := UI.vbox(2)
	row.add_child(col)
	col.add_child(UI.label("Chief", 30))
	_xp_bar = UI.bar(UI.BLUE, Vector2(170, 16))
	col.add_child(_xp_bar)
	var stars := UI.hbox(4)
	stars.add_child(UI.icon("star", 30))
	_stars = UI.label("0", 26)
	stars.add_child(_stars)
	col.add_child(stars)


func _build_top_center() -> void:
	var holder := _corner(Control.PRESET_CENTER_TOP, Vector2(-90, 14))
	var p := PanelContainer.new()
	var st := UI.box(Color(0.1, 0.08, 0.06, 0.65), 14, Color(0, 0, 0, 0.8), 2)
	st.content_margin_left = 10
	st.content_margin_right = 14
	p.add_theme_stylebox_override("panel", st)
	holder.add_child(p)
	var row := UI.hbox(6)
	p.add_child(row)
	row.add_child(UI.icon("builder", 40))
	var col := UI.vbox(-6)
	row.add_child(col)
	col.add_child(UI.label("Builders", 20, Color(0.95, 0.9, 0.8)))
	_builders = UI.label("0/2", 28)
	col.add_child(_builders)


func _build_top_right() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-290, 12))
	var col := UI.vbox(2)
	holder.add_child(col)
	for spec in [["gold", UI.GOLD], ["wood", UI.WOOD_RES], ["gem", UI.GEM]]:
		var r := UI.resource_bar(spec[0], spec[1], 230.0)
		col.add_child(r)
		_res[spec[0]] = r
	var gear := UI.button("", Color(0.5, 0.52, 0.56), Vector2(58, 52), 20)
	var gi := UI.icon("info", 34)
	gi.position = Vector2(12, 6)
	gear.add_child(gi)
	gear.pressed.connect(open_settings)
	var gh := _corner(Control.PRESET_TOP_RIGHT, Vector2(-80, 180))
	gh.add_child(gear)


func _build_bottom_buttons() -> void:
	var left := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(26, -190))
	var attack := UI.round_button("attack", "Attack!", UI.ORANGE, 140.0)
	attack.pressed.connect(open_campaign)
	left.add_child(attack)
	var right := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-290, -170))
	var shop := UI.round_button("shop", "Shop", UI.GREEN, 118.0)
	shop.pressed.connect(open_shop)
	right.add_child(shop)
	var army := UI.round_button("army", "Army", UI.BLUE, 118.0)
	army.position = Vector2(140, 0)
	army.pressed.connect(open_army)
	right.add_child(army)


func _build_coach() -> void:
	_coach = _corner(Control.PRESET_CENTER_TOP, Vector2(-330, 112))
	var p := PanelContainer.new()
	var st := UI.parchment_style()
	st.content_margin_top = 10
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(660, 0)
	_coach.add_child(p)
	var row := UI.hbox(12)
	p.add_child(row)
	row.add_child(UI.icon("info", 44))
	_coach_label = UI.ink("", 26)
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.custom_minimum_size = Vector2(560, 0)
	row.add_child(_coach_label)


func refresh() -> void:
	var lv := Save.level()
	_level.text = str(lv)
	var lo := GameData.xp_to_reach(lv)
	var hi := GameData.xp_to_reach(lv + 1)
	_xp_bar.max_value = hi - lo
	_xp_bar.value = Save.xp - lo
	_stars.text = str(Save.total_stars())
	_builders.text = "%d/%d" % [GameData.BUILDERS - Save.builders_busy(), GameData.BUILDERS]
	_set_res("gold", Save.gold, 5000)
	_set_res("wood", Save.wood, 5000)
	_set_res("gem", Save.gems, 500)
	var tips := ["Tap your Gold Mine to collect the gold it has dug up.",
		"Tap SHOP and build something new, like another Gold Mine.",
		"Tap ATTACK! and raid the Goblin Outpost with your army.",
		""]
	var step := clampi(Save.tutorial_step, 0, tips.size() - 1)
	if step == 2 and Save.total_stars() > 0:
		step = 3
	_coach.visible = tips[step] != "" and _panel == null
	_coach_label.text = tips[step]


func _set_res(kind: String, value: int, scale_to: int) -> void:
	var holder: Control = _res[kind]
	var b := holder.get_node("Bar") as ProgressBar
	b.max_value = maxi(scale_to, value)
	b.value = value
	var l := holder.get_node("Amount") as Label
	l.text = UI.fmt(value)
	if _last_values.has(kind) and int(_last_values[kind]) != value:
		l.pivot_offset = l.size / 2
		var tw := l.create_tween()
		tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.06)
		tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	_last_values[kind] = value


func _process(_delta: float) -> void:
	if village != null and village.selected != null and _selection.get_child_count() > 0:
		var data: Variant = Save.by_id(village.selected.id)
		if data != null and Save.building_busy(data):
			var t := _selection.find_child("Timer", true, false) as Label
			if t != null:
				t.text = UI.time_text(float(data["done_at"]) - Save.now())


func toast(text: String, color: Color = UI.TEXT) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


## An icon flying from a building to its resource bar.
func fly_resource(kind: String, from: Vector2, amount: int) -> void:
	var target: Control = _res[kind]
	var to := target.global_position + Vector2(target.size.x - 30, 24)
	for i in mini(6, 2 + amount / 50):
		var ic := UI.icon(kind, 42)
		ic.position = from + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		add_child(ic)
		var tw := ic.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(ic, "position", to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(ic.queue_free)
	var pop := UI.label("+%s" % UI.fmt(amount), 34, UI.GOLD if kind == "gold" else Color("f0c58a"))
	pop.position = from - Vector2(40, 60)
	add_child(pop)
	var tw2 := pop.create_tween().set_parallel()
	tw2.tween_property(pop, "position:y", pop.position.y - 50, 0.8)
	tw2.tween_property(pop, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw2.chain().tween_callback(pop.queue_free)


# ---------------------------------------------------------------- Selected building

func show_selection(b: Building) -> void:
	for c in _selection.get_children():
		c.queue_free()
	if b == null:
		return
	var data: Variant = Save.by_id(b.id)
	if data == null:
		return
	var info := GameData.building(b.kind)
	var col := UI.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(700, 0)
	col.position = Vector2(-350, -170)
	_selection.add_child(col)
	var title := UI.label("%s (Level %d)" % [info["name"], int(data["level"])], 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var busy := Save.building_busy(data)
	if busy:
		var t := UI.label("", 30, UI.GOLD)
		t.name = "Timer"
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		var gems := GameData.gems_to_finish(float(data["done_at"]) - Save.now())
		row.add_child(_action("gem", "Finish %d" % gems, UI.GEM.darkened(0.15), func() -> void: village.finish_selected(false)))
		row.add_child(_action("ad", "Free", UI.PURPLE, func() -> void:
			Ads.show_rewarded(func() -> void: village.finish_selected(true))))
	else:
		var next := int(data["level"]) + 1
		if next <= GameData.max_level(b.kind):
			var cost := GameData.cost(b.kind, next)
			row.add_child(_action("up", "%s %s" % [UI.fmt(cost), "gold" if info["res"] == "gold" else "wood"], UI.GREEN, village.upgrade_selected))
		if info.has("produces"):
			var amount_ready := Save.ready_to_collect(data)
			row.add_child(_action("gold" if info["produces"] != "wood" else "wood", "Collect %d" % amount_ready, UI.ORANGE, func() -> void:
				var got := Save.collect(b.id)
				village._collect_fx(b, got)
				village._refresh_states()
				show_selection(b)))
		if b.kind == "barracks" or b.kind == "house":
			row.add_child(_action("army", "Train", UI.BLUE, open_army))
		if b.kind == "blacksmith":
			row.add_child(_action("sword", "Troops", UI.PURPLE, open_blacksmith))
		if b.kind == "townhall":
			row.add_child(_action("attack", "Attack", UI.ORANGE, open_campaign))
	var desc := UI.label(info["desc"], 22, Color(1, 0.97, 0.9))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(desc)
	UI.pop(col, 0.85)


func _action(icon_kind: String, caption: String, color: Color, cb: Callable) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(110, 120)
	var b := UI.round_button(icon_kind, "", color, 86.0)
	b.position = Vector2(12, 0)
	b.pressed.connect(cb)
	holder.add_child(b)
	var l := UI.label(caption, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(150, 30)
	l.position = Vector2(-20, 88)
	holder.add_child(l)
	return holder


func show_placing(kind: String) -> void:
	for c in _placing_bar.get_children():
		c.queue_free()
	if kind == "":
		return
	var col := UI.vbox(8)
	col.custom_minimum_size = Vector2(600, 0)
	col.position = Vector2(-300, -150)
	_placing_bar.add_child(col)
	var t := UI.label("Tap a spot for your %s" % GameData.building(kind)["name"], 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var row := UI.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var cancel := UI.button("Cancel", UI.RED, Vector2(180, 70), 30)
	cancel.pressed.connect(village.cancel_placing)
	row.add_child(cancel)
	var ok := UI.button("Build here", UI.GREEN, Vector2(220, 70), 30)
	ok.pressed.connect(village.confirm_placing)
	row.add_child(ok)


# ---------------------------------------------------------------- Panels

func _open_panel(title: String, width: float) -> VBoxContainer:
	close_panel()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_panel.add_child(UI.dim(0.5))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var frame := UI.panel()
	frame.custom_minimum_size = Vector2(width, 0)
	center.add_child(frame)
	var col := UI.vbox(12)
	frame.add_child(col)
	var head := UI.hbox(10)
	col.add_child(head)
	var t := UI.label(title, 44)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(60, 60)
	close.focus_mode = Control.FOCUS_NONE
	close.add_child(UI.icon("close", 56))
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		close_panel())
	head.add_child(close)
	UI.pop(frame, 0.85)
	_coach.visible = false
	return col


func close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	refresh()


func open_shop() -> void:
	var col := _open_panel("Shop", 1120)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var th := Save.town_hall_level()
	for kind in GameData.SHOP_ORDER:
		grid.add_child(_shop_card(kind, th))


func _shop_card(kind: String, th: int) -> Control:
	var info := GameData.building(kind)
	var have := Save.count(kind)
	var allowed := GameData.limit(kind, th)
	var cost := GameData.cost(kind, 1)
	var card := Button.new()
	card.custom_minimum_size = Vector2(205, 250)
	card.focus_mode = Control.FOCUS_NONE
	var open := have < allowed
	var st := UI.card_style(UI.PARCHMENT_DARK if open else Color(0.72, 0.68, 0.6))
	card.add_theme_stylebox_override("normal", st)
	card.add_theme_stylebox_override("hover", UI.card_style(Color("ecdcae")))
	card.add_theme_stylebox_override("pressed", st)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := UI.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var name_label := UI.label(info["name"], 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var tex := TextureRect.new()
	tex.texture = Thumbs.get_texture(self, kind, 160)
	tex.custom_minimum_size = Vector2(150, 130)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.modulate = Color.WHITE if open else Color(0.6, 0.6, 0.6)
	col.add_child(tex)
	var count := UI.ink("Built: %d/%d" % [have, allowed], 20)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(count)
	var price := UI.hbox(4)
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_child(UI.icon(info["res"], 30))
	var affordable := Save.can_afford(info["res"], cost)
	price.add_child(UI.label(UI.fmt(cost), 26, Color.WHITE if affordable else Color("ff8a80")))
	col.add_child(price)
	if not open:
		var lock := UI.ink("Town Hall %d" % _town_hall_needed(kind, have), 18)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lock)
	card.pressed.connect(func() -> void:
		if not open:
			toast("Upgrade your Town Hall to build more", UI.RED)
			Sfx.play("deny")
			return
		close_panel()
		village.start_placing(kind))
	return card


func _town_hall_needed(kind: String, have: int) -> int:
	for th in range(1, GameData.MAX_LEVEL + 1):
		if GameData.limit(kind, th) > have:
			return th
	return GameData.MAX_LEVEL


func open_army() -> void:
	var col := _open_panel("Army", 1000)
	var cap := Save.housing_capacity()
	var used := Save.housing_used()
	var top := UI.hbox(10)
	col.add_child(top)
	top.add_child(UI.ink("Army camps: %d / %d" % [used, cap], 28))
	var bar := UI.bar(UI.BLUE, Vector2(360, 24))
	bar.max_value = cap
	bar.value = used
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	var row := UI.hbox(12)
	col.add_child(row)
	var barracks := Save.best_level("barracks")
	for t in GameData.TROOP_ORDER:
		row.add_child(_troop_card(t, barracks))
	if Save.training.size() > 0:
		var q := UI.hbox(8)
		col.add_child(q)
		var last := float(Save.training[-1]["done_at"]) - Save.now()
		q.add_child(UI.ink("Training %d troops, done in %s" % [Save.training.size(), UI.time_text(maxf(last, 0.0))], 24))
		var fast := UI.button("  Train now", UI.PURPLE, Vector2(220, 56), 24)
		var ad := UI.icon("ad", 30)
		ad.position = Vector2(12, 12)
		fast.add_child(ad)
		fast.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void:
				for e in Save.training:
					e["done_at"] = Save.now()
				Save.tick()
				open_army()))
		q.add_child(fast)


func _troop_card(t: String, barracks: int) -> Control:
	var info := GameData.troop(t)
	var unlocked := int(info["barracks"]) <= barracks
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style(UI.PARCHMENT_DARK if unlocked else Color(0.72, 0.68, 0.6)))
	var v := UI.vbox(2)
	p.add_child(v)
	var head := UI.hbox(4)
	v.add_child(head)
	head.add_child(UI.label(info["name"], 26))
	var tex := TextureRect.new()
	tex.texture = Thumbs.get_texture(self, "troop:" + t, 180)
	tex.custom_minimum_size = Vector2(200, 170)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35)
	v.add_child(tex)
	v.add_child(UI.ink("In army: %d   Lv %d" % [int(Save.army.get(t, 0)), Save.troop_level(t)], 22))
	var stats := UI.ink("HP %d  ·  DMG %d  ·  Space %d" % [int(GameData.at_level(info["hp"], Save.troop_level(t))),
		int(GameData.at_level(info["damage"], Save.troop_level(t))), int(info["housing"])], 18)
	v.add_child(stats)
	if unlocked:
		var b := UI.button("  Train %d" % int(info["cost"]), UI.GREEN, Vector2(200, 58), 26)
		var ic := UI.icon("wood", 30)
		ic.position = Vector2(10, 12)
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			var err := Save.train(t)
			if err != "":
				toast(err, UI.RED)
				Sfx.play("deny")
			else:
				Sfx.play("place")
				open_army())
		v.add_child(b)
	else:
		v.add_child(UI.ink("Barracks level %d" % int(info["barracks"]), 22))
	return p


func open_blacksmith() -> void:
	var col := _open_panel("Blacksmith", 1000)
	col.add_child(UI.ink("Stronger troops hit harder and survive longer. Max troop level = Blacksmith level + 1.", 22))
	var row := UI.hbox(12)
	col.add_child(row)
	for t in GameData.TROOP_ORDER:
		var info := GameData.troop(t)
		var lv := Save.troop_level(t)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.card_style())
		var v := UI.vbox(4)
		p.add_child(v)
		v.add_child(UI.label("%s  Lv %d" % [info["name"], lv], 26))
		var tex := TextureRect.new()
		tex.texture = Thumbs.get_texture(self, "troop:" + t, 180)
		tex.custom_minimum_size = Vector2(200, 160)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tex)
		if lv < GameData.MAX_LEVEL:
			var b := UI.button("  %s" % UI.fmt(GameData.troop_upgrade_cost(lv)), UI.GREEN, Vector2(200, 58), 26)
			var ic := UI.icon("gold", 30)
			ic.position = Vector2(14, 12)
			b.add_child(ic)
			b.pressed.connect(func() -> void:
				var err := Save.upgrade_troop(t)
				if err != "":
					toast(err, UI.RED)
					Sfx.play("deny")
				else:
					Sfx.play("upgrade")
					open_blacksmith())
			v.add_child(b)
		else:
			v.add_child(UI.label("MAX", 30, UI.GOLD))
		row.add_child(p)


func open_campaign() -> void:
	var col := _open_panel("Goblin Lands", 1160)
	var map := Control.new()
	map.custom_minimum_size = Vector2(1100, 400)
	col.add_child(map)
	var points: Array[Vector2] = []
	for i in GameData.CAMPAIGN_SIZE:
		var row := i / 5
		var c := i % 5
		var x := 90.0 + (c if row % 2 == 0 else 4 - c) * 230.0
		var y := 50.0 + row * 98.0
		points.append(Vector2(x, y))
	map.draw.connect(func() -> void:
		map.draw_rect(Rect2(Vector2.ZERO, map.custom_minimum_size), Color("d9c48e"))
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var steps := int(a.distance_to(b) / 18.0)
			for s in steps:
				if s % 2 == 0:
					map.draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), Color("8b5a2b"), 5.0))
	var next := Save.next_campaign_level()
	for i in GameData.CAMPAIGN_SIZE:
		var n := i + 1
		var open := n <= next
		var stars := Save.campaign_stars(n)
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 84)
		b.size = b.custom_minimum_size
		b.position = points[i] - Vector2(42, 42)
		b.focus_mode = Control.FOCUS_NONE
		var color := UI.RED if open and stars == 0 else (UI.GREEN if stars > 0 else UI.GREY)
		var st := UI.box(color, 42, color.darkened(0.55), 4)
		st.border_width_bottom = 8
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var num := UI.label(str(n), 34)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.size = Vector2(84, 70)
		num.position = Vector2(0, 2)
		b.add_child(num)
		var srow := UI.hbox(0)
		srow.position = Vector2(4, 62)
		for k in 3:
			srow.add_child(UI.icon("star" if k < stars else "star_empty", 26))
		b.add_child(srow)
		if not open:
			var lock := UI.icon("lock", 34)
			lock.position = Vector2(50, -12)
			b.add_child(lock)
		b.pressed.connect(func() -> void:
			if not open:
				toast("Beat level %d first" % next, UI.RED)
				return
			_show_raid_card(n))
		map.add_child(b)
		if n == next:
			var tw := b.create_tween().set_loops()
			b.pivot_offset = Vector2(42, 42)
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.45)
			tw.tween_property(b, "scale", Vector2.ONE, 0.45)
	var army := 0
	for t in Save.army:
		army += int(Save.army[t])
	var bottom := UI.hbox(16)
	col.add_child(bottom)
	bottom.add_child(UI.ink("Your army: %d troops. Tap a village to see its loot." % army, 24))


func _show_raid_card(n: int) -> void:
	var col := _open_panel("%d. %s" % [n, GameData.enemy_name(n)], 640)
	var loot := GameData.enemy_loot(n)
	col.add_child(UI.ink("Loot to win:", 28))
	var row := UI.hbox(30)
	col.add_child(row)
	for k in ["gold", "wood"]:
		var h := UI.hbox(8)
		h.add_child(UI.icon(k, 46))
		h.add_child(UI.label(UI.fmt(int(loot[k])), 38, UI.GOLD if k == "gold" else Color("f0c58a")))
		row.add_child(h)
	var stars := Save.campaign_stars(n)
	col.add_child(UI.ink("Best: %d star%s" % [stars, "" if stars == 1 else "s"], 24))
	var defenses := 0
	for d in GameData.enemy_base(n):
		if GameData.building(d["type"]).has("defense"):
			defenses += 1
	col.add_child(UI.ink("Defenses: %d" % defenses, 24))
	var army := 0
	for t in Save.army:
		army += int(Save.army[t])
	var go := UI.button("Attack!", UI.ORANGE, Vector2(320, 86), 40)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void:
		if army <= 0:
			toast("Train some troops first!", UI.RED)
			return
		close_panel()
		if Save.tutorial_step < 3:
			Save.tutorial_step = 3
			Save.store()
		village.attack_requested.emit(n))
	col.add_child(go)


func open_settings() -> void:
	var col := _open_panel("Settings", 560)
	var sound := UI.button("Sound: %s" % ("On" if Save.sound else "Off"), UI.BLUE, Vector2(480, 66), 30)
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "Sound: %s" % ("On" if Save.sound else "Off"))
	col.add_child(sound)
	var vib := UI.button("Vibration: %s" % ("On" if Save.vibrate else "Off"), UI.BLUE, Vector2(480, 66), 30)
	vib.pressed.connect(func() -> void:
		Save.vibrate = not Save.vibrate
		Save.store()
		vib.text = "Vibration: %s" % ("On" if Save.vibrate else "Off"))
	col.add_child(vib)
	col.add_child(UI.ink("3D art: KayKit by Kay Lousberg (CC0). Sounds: Kenney (CC0).\nFont: Lilita One (SIL Open Font License).", 20))
