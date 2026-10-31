class_name ColonyHud
extends CanvasLayer
## The colony's screens: stockpiles, power and oxygen, colonists, the current
## mission, the build menu, placing a building, the panel for a selected
## building, event banners and the welcome-back screen.

var colony: Colony
var _credits: Label
var _ore: Label
var _crystals: Label
var _pop: Label
var _pop_bar: ProgressBar
var _power: Label
var _oxygen: Label
var _hub: Label
var _mission_text: Label
var _mission_bar: ProgressBar
var _mission_count: Label
var _mission_reward: Label
var _claim: Button
var _boost: Button
var _boost_label: Label
var _build_btn: Button
var _place_bar: PanelContainer
var _place_label: Label
var _place_ok: Button
var _info: PanelContainer
var _modal: Control
var _toast: Label
var _toast_t := 0.0
var _banner: Label
var _overlay: Overlay
var _root: Control


class Overlay:
	extends Control
	var hud: ColonyHud
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if hud.colony == null:
			return
		for o in hud.colony.overlays():
			var p: Vector2 = o["pos"]
			if o["kind"] == "build":
				draw_circle(p, 22, Color(0.05, 0.06, 0.1, 0.85))
				draw_arc(p, 16, -PI / 2, -PI / 2 + TAU * clampf(float(o["frac"]), 0.0, 1.0), 32, Color("ffb02e"), 8.0, true)
				draw_arc(p, 22, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0, true)
			else:
				var s := 1.0 + sin(_t * 8.0) * 0.12
				var pts := PackedVector2Array([p + Vector2(0, -24) * s, p + Vector2(22, 16) * s, p + Vector2(-22, 16) * s])
				draw_colored_polygon(pts, Color("e6463a"))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.1, 0.05, 0.05), 3.0, true)
				draw_rect(Rect2(p + Vector2(-3, -12), Vector2(6, 14)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(-3, 5), Vector2(6, 6)), Color.WHITE)


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_overlay = Overlay.new()
	_overlay.hud = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_build_top()
	_build_mission()
	_build_bottom()
	_toast = UI.label("", 32)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 90
	_toast.offset_bottom = 130
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_banner = UI.label("", 44, UI.GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -600
	_banner.offset_right = 600
	_banner.offset_top = 120
	_banner.offset_bottom = 180
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	colony.state.mission_done.connect(func() -> void:
		Sfx.play("reward")
		UI.pop(_claim, 0.5))
	if not Save.away.is_empty() and int(Save.away.get("credits", 0)) > 0:
		show_welcome(Save.away)
		Save.away = {}
	Ads.show_banner()


func _glass() -> StyleBoxFlat:
	var s := UI.box(Color(0.05, 0.06, 0.12, 0.74), 16, Color(0.6, 0.85, 1.0, 0.25), 2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s


func _pill(kind: String, color: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _glass())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(6)
	p.add_child(h)
	h.add_child(UI.icon(kind, 34))
	var l := UI.label("0", 26, color)
	l.custom_minimum_size = Vector2(96, 0)
	h.add_child(l)
	_top_right.add_child(p)
	return l


var _top_right: HBoxContainer


func _build_top() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _glass())
	card.position = Vector2(14, 10)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	var v := UI.vbox(2)
	card.add_child(v)
	_hub = UI.label("Mars Colony", 26, Color("ffd9a8"))
	v.add_child(_hub)
	var row := UI.hbox(8)
	v.add_child(row)
	row.add_child(UI.icon("colonist", 34))
	var pv := UI.vbox(0)
	row.add_child(pv)
	_pop = UI.label("4 / 8", 22)
	pv.add_child(_pop)
	_pop_bar = UI.bar(Color("62d0ff"), Vector2(180, 12))
	pv.add_child(_pop_bar)
	_top_right = UI.hbox(8)
	_top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -14
	_top_right.offset_top = 10
	_root.add_child(_top_right)
	_credits = _pill("gold", UI.GOLD)
	_ore = _pill("ore", Color("ffc77a"))
	_crystals = _pill("crystal", Color("8ff6ff"))
	var status := UI.hbox(16)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status.offset_right = -18
	status.offset_top = 66
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(status)
	var ph := UI.hbox(4)
	ph.add_child(UI.icon("bolt", 30))
	_power = UI.label("0 / 0", 24)
	ph.add_child(_power)
	status.add_child(ph)
	var oh := UI.hbox(4)
	oh.add_child(UI.icon("oxygen", 30))
	_oxygen = UI.label("0", 24)
	oh.add_child(_oxygen)
	status.add_child(oh)


func _build_mission() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _glass())
	card.position = Vector2(14, 104)
	card.custom_minimum_size = Vector2(300, 0)
	_root.add_child(card)
	var v := UI.vbox(4)
	card.add_child(v)
	var head := UI.hbox(6)
	head.add_child(UI.icon("star", 26))
	head.add_child(UI.label("Mission", 22, UI.GOLD))
	v.add_child(head)
	_mission_text = UI.label("", 21)
	_mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_mission_text.custom_minimum_size = Vector2(272, 0)
	v.add_child(_mission_text)
	var row := UI.hbox(8)
	v.add_child(row)
	_mission_bar = UI.bar(UI.GREEN, Vector2(170, 14))
	_mission_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mission_bar)
	_mission_count = UI.label("0/1", 20)
	row.add_child(_mission_count)
	_mission_reward = UI.label("", 19, Color("ffe7a8"))
	v.add_child(_mission_reward)
	_claim = UI.button("Claim", UI.GREEN, Vector2(272, 50), 26)
	_claim.pressed.connect(func() -> void:
		if colony.state.claim_mission():
			Sfx.play("level")
			toast("Mission complete!")
			Save.store()
			Ads.match_finished())
	v.add_child(_claim)


func _build_bottom() -> void:
	var right := UI.hbox(14)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -20
	right.offset_bottom = -34
	_root.add_child(right)
	_boost = UI.round_button("rocket", "x2 Boost", UI.PURPLE, 92)
	_boost.pressed.connect(func() -> void:
		Ads.show_rewarded(func() -> void:
			colony.state.boost = 180.0
			Sfx.play("level")
			banner("Double production for 3 minutes!", Color("d8b4ff"))))
	right.add_child(_boost)
	_boost_label = UI.label("", 20)
	_boost_label.position = Vector2(10, -24)
	_boost.add_child(_boost_label)
	_build_btn = UI.round_button("build", "Build", Color("ff9a1f"), 116)
	_build_btn.pressed.connect(open_build)
	right.add_child(_build_btn)
	var snd := UI.round_button("sound", "", UI.GREY, 60)
	snd.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	snd.offset_left = 16
	snd.offset_top = -80
	snd.offset_right = 76
	snd.offset_bottom = -20
	snd.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		toast("Sound on" if Save.sound else "Sound off"))
	_root.add_child(snd)
	# The bar shown while placing a building.
	_place_bar = PanelContainer.new()
	_place_bar.add_theme_stylebox_override("panel", _glass())
	_place_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_place_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_place_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place_bar.offset_bottom = -24
	_place_bar.visible = false
	_root.add_child(_place_bar)
	var ph := UI.hbox(14)
	_place_bar.add_child(ph)
	_place_label = UI.label("", 26)
	_place_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_place_label)
	_place_ok = UI.button("Build here", UI.GREEN, Vector2(170, 62), 26)
	_place_ok.pressed.connect(func() -> void: colony.confirm_place())
	ph.add_child(_place_ok)
	var cancel := UI.button("Cancel", UI.RED, Vector2(130, 62), 26)
	cancel.pressed.connect(func() -> void: colony.cancel_place())
	ph.add_child(cancel)


func _process(delta: float) -> void:
	var s := colony.state
	_credits.text = UI.fmt(int(s.credits))
	_ore.text = "%s/%s" % [UI.fmt(int(s.ore)), UI.fmt(s.storage())]
	_crystals.text = str(s.crystals)
	_hub.text = "Mars Colony  ·  Hub Lv %d" % s.hq_level()
	var cap := s.capacity()
	_pop.text = "%d / %d colonists" % [s.colonists, cap]
	_pop_bar.max_value = maxf(cap, 1)
	_pop_bar.value = s.colonists
	var sup := s.power_supply()
	var dem := s.power_demand()
	_power.text = "%d / %d" % [int(sup), int(dem)]
	_power.add_theme_color_override("font_color", Color("8ff2a2") if sup >= dem else Color("ff6b5a"))
	_oxygen.text = "%d / %d" % [s.colonists, s.oxygen()]
	_oxygen.add_theme_color_override("font_color", Color("8fd8ff") if s.oxygen() >= s.colonists else Color("ff6b5a"))
	var m := s.mission_info()
	if m.is_empty():
		_mission_text.text = "Every mission done! Keep growing your colony."
		_mission_bar.value = 100
		_mission_count.text = ""
		_mission_reward.text = ""
		_claim.visible = false
	else:
		var p := s.mission_progress()
		_mission_text.text = m["text"]
		_mission_bar.max_value = maxf(float(p[1]), 1.0)
		_mission_bar.value = float(p[0])
		_mission_count.text = "%d/%d" % [int(p[0]), int(p[1])]
		_mission_reward.text = "Reward: %d credits, %d crystals" % [int(m["credits"]), int(m["crystals"])]
		_claim.visible = s.mission_complete()
	_boost_label.text = UI.time_text(s.boost) if s.boost > 0.0 else ""
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 3.0, 0.0, 1.0)


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.0


func banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE
	var tw := _banner.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------- panels

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


func open_build() -> void:
	colony.select(-1)
	var v := _panel("Build", 1060)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var s := colony.state
	for type in GameData.BUILD_ORDER:
		var info := GameData.info(type)
		var err := s.build_error(type)
		var locked := GameData.unlock_level(type) > s.hq_level()
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(196, 236)
		var col := UI.PARCHMENT_DARK if err == "" else Color(0.72, 0.75, 0.8)
		card.add_theme_stylebox_override("normal", UI.card_style(col))
		card.add_theme_stylebox_override("hover", UI.card_style(col.lightened(0.1)))
		card.add_theme_stylebox_override("pressed", UI.card_style(col.darkened(0.08)))
		grid.add_child(card)
		var tex := TextureRect.new()
		tex.texture = Thumbs.building(self, type, 150)
		tex.position = Vector2(23, 4)
		tex.size = Vector2(150, 120)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			tex.modulate = Color(0.3, 0.3, 0.35)
		card.add_child(tex)
		var name_l := UI.ink(info["name"], 21)
		name_l.position = Vector2(12, 122)
		card.add_child(name_l)
		var count_l := UI.ink("%d/%d" % [s.count(type), GameData.limit(type, s.hq_level())], 18)
		count_l.position = Vector2(150, 8)
		card.add_child(count_l)
		if locked:
			var lock := UI.label("Hub Lv %d" % GameData.unlock_level(type), 24, UI.GOLD)
			lock.position = Vector2(12, 168)
			card.add_child(lock)
			card.add_child(_at(UI.icon("lock", 40), Vector2(140, 60)))
		else:
			var c := GameData.cost(type, 0)
			var row := UI.hbox(4)
			row.position = Vector2(10, 152)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(UI.icon("gold", 26))
			row.add_child(UI.label(UI.fmt(int(c[0])), 22, UI.GOLD if s.credits >= int(c[0]) else Color("ff6b5a")))
			if int(c[1]) > 0:
				row.add_child(UI.icon("ore", 26))
				row.add_child(UI.label(UI.fmt(int(c[1])), 22, Color("ffc77a") if s.ore >= int(c[1]) else Color("ff6b5a")))
			card.add_child(row)
			var stat := UI.ink(_stat_line(type, 1), 16)
			stat.position = Vector2(12, 186)
			stat.modulate = Color(1, 1, 1, 0.75)
			card.add_child(stat)
		card.pressed.connect(func() -> void:
			var e := colony.state.build_error(type)
			if e != "":
				toast(e)
				Sfx.play("error")
				return
			close_panel()
			colony.start_place(type))


func _at(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func _stat_line(type: String, level: int) -> String:
	var b := GameData.info(type)
	var k := GameData.level_mult(level)
	var parts: Array[String] = []
	var p := int(b.get("power", 0))
	if type == "solar" or type == "wind" or type == "hq":
		parts.append("+%d power" % int(round(p * k)))
	elif p < 0:
		parts.append("%d power" % p)
	if b.has("housing"):
		parts.append("%d homes" % int(float(b["housing"]) * k))
	if b.has("oxygen"):
		parts.append("%d O2" % int(float(b["oxygen"]) * k))
	if b.has("mine"):
		parts.append("%.1f ore/s" % (float(b["mine"]) * k))
	if b.has("storage"):
		parts.append("+%d storage" % int(float(b["storage"]) * k))
	if b.has("crystal"):
		parts.append("%.0f crystals/h" % (float(b["crystal"]) * k * 3600.0))
	if b.has("boost_ore"):
		parts.append("+%d%% ore" % int(float(b["boost_ore"]) * k * 100))
	if b.has("boost_credits"):
		parts.append("+%d%% credits" % int(float(b["boost_credits"]) * k * 100))
	return "  ".join(parts)


func placing_changed() -> void:
	_place_bar.visible = colony.placing != ""
	_build_btn.visible = colony.placing == ""
	if colony.placing == "":
		return
	var err := colony.state.place_error(colony.placing, colony.place_cell)
	var name_s: String = GameData.info(colony.placing)["name"]
	_place_label.text = ("Tap a tile for the %s" % name_s) if err == "" else err
	_place_ok.disabled = err != ""


func show_building(id: int) -> void:
	if _info != null:
		_info.queue_free()
		_info = null
	if id < 0:
		return
	var b := colony.state.by_id(id)
	if b.is_empty():
		return
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", UI.parchment_style())
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.offset_bottom = -20
	_info.custom_minimum_size = Vector2(560, 0)
	_root.add_child(_info)
	var v := UI.vbox(6)
	_info.add_child(v)
	var head := UI.hbox(10)
	v.add_child(head)
	var info := GameData.info(b["type"])
	var t := UI.ink("%s  ·  Level %d" % [info["name"], int(b["level"])], 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(44, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.add_child(UI.icon("close", 40))
	close.pressed.connect(func() -> void: colony.select(-1))
	head.add_child(close)
	var desc := UI.ink(info["desc"], 19)
	desc.modulate = Color(1, 1, 1, 0.8)
	v.add_child(desc)
	v.add_child(UI.ink(_stat_line(b["type"], int(b["level"])), 20))
	var row := UI.hbox(10)
	v.add_child(row)
	var s := colony.state
	if float(b["build"]) > 0.0:
		var price := GameData.rush_cost(float(b["build"]))
		var rush := UI.button("Finish now  %d" % price, UI.BLUE, Vector2(230, 56), 24)
		rush.add_child(_at(UI.icon("crystal", 30), Vector2(194, 12)))
		rush.pressed.connect(func() -> void:
			if s.rush(b):
				Sfx.play("buy")
				show_building(id)
			else:
				toast("Not enough crystals")
				Sfx.play("error"))
		row.add_child(rush)
		row.add_child(UI.ink("Building... %s left" % UI.time_text(float(b["build"])), 20))
	elif b["damaged"]:
		var cost := GameData.repair_cost(b["type"], int(b["level"]))
		var fix := UI.button("Repair  %s" % UI.fmt(cost), UI.ORANGE, Vector2(230, 56), 24)
		fix.pressed.connect(func() -> void:
			if s.repair(b):
				Sfx.play("buy")
				colony._refresh_building(b)
				show_building(id)
			else:
				toast("Not enough credits")
				Sfx.play("error"))
		row.add_child(fix)
	else:
		var err := s.upgrade_error(b)
		if err == "Fully upgraded":
			row.add_child(UI.ink("Fully upgraded", 22))
		else:
			var c := GameData.cost(b["type"], int(b["level"]))
			var label := "Upgrade  %s" % UI.fmt(int(c[0]))
			if int(c[1]) > 0:
				label += " + %s ore" % UI.fmt(int(c[1]))
			var up := UI.button(label, UI.GREEN if err == "" else UI.GREY, Vector2(320, 56), 24)
			up.pressed.connect(func() -> void:
				if s.upgrade(b):
					Sfx.play("buy")
					colony._refresh_building(b)
					show_building(id)
					Save.store()
				else:
					toast(s.upgrade_error(b))
					Sfx.play("error"))
			row.add_child(up)
			if err != "" and err != "Not enough resources":
				row.add_child(UI.ink(err, 18))


func refresh_panel() -> void:
	if colony.selected >= 0:
		show_building(colony.selected)


func show_welcome(away: Dictionary) -> void:
	var v := _panel("Welcome back, Commander!", 620)
	var mins := int(float(away["seconds"]) / 60.0)
	var l := UI.ink("Your colony kept working for %s." % UI.time_text(mins * 60.0), 24)
	v.add_child(l)
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.icon("gold", 44))
	var cl := UI.label("+%s" % UI.fmt(int(away["credits"])), 40, UI.GOLD)
	row.add_child(cl)
	row.add_child(UI.icon("ore", 44))
	var ol := UI.label("+%s" % UI.fmt(int(away["ore"])), 40, Color("ffc77a"))
	row.add_child(ol)
	var buttons := UI.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	var dbl := UI.button("x2 (watch ad)", UI.PURPLE, Vector2(240, 64), 26)
	var reward := func() -> void:
		colony.state.credits += int(away["credits"])
		colony.state.ore = minf(colony.state.ore + int(away["ore"]), float(colony.state.storage()))
		cl.text = "+%s" % UI.fmt(int(away["credits"]) * 2)
		Sfx.play("reward")
		close_panel()
	dbl.pressed.connect(func() -> void: Ads.show_rewarded(reward))
	buttons.add_child(dbl)
	var ok := UI.button("Collect", UI.GREEN, Vector2(180, 64), 26)
	ok.pressed.connect(func() -> void:
		Sfx.play("coin")
		close_panel())
	buttons.add_child(ok)
