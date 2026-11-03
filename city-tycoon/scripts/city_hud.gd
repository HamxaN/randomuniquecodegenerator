class_name CityHud
extends CanvasLayer
## The mayor's screens: money, population, happiness and the day along the
## top, the demand meters, the build toolbar, a panel for the tapped tile,
## the daily budget and milestone celebrations.

var city: City
var _root: Control
var _money: Label
var _pop: Label
var _happy: Label
var _day: Label
var _title: Label
var _next: Label
var _meters := {}
var _tools := {}
var _info: PanelContainer
var _toast: Label
var _toast_t := 0.0
var _modal: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_build_meters()
	_build_toolbar()
	_toast = UI.label("", 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 80
	_toast.offset_bottom = 120
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	city.state.milestone.connect(_on_milestone)
	city.state.day_passed.connect(func(net: int) -> void:
		_float_money(net)
		Save.store())
	Ads.show_banner()


func _glass() -> StyleBoxFlat:
	var s := UI.box(Color(0.08, 0.12, 0.2, 0.78), 16, Color(1, 1, 1, 0.18), 2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	return s


func _stat(parent: Container, icon: String, color: Color) -> Label:
	var h := UI.hbox(4)
	h.add_child(UI.icon(icon, 30))
	var l := UI.label("0", 24, color)
	h.add_child(l)
	parent.add_child(h)
	return l


func _build_top() -> void:
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _glass())
	left.position = Vector2(12, 10)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	var lv := UI.vbox(0)
	left.add_child(lv)
	_title = UI.label("Village", 30, Color("ffe7a8"))
	lv.add_child(_title)
	_next = UI.label("", 17, Color(0.8, 0.85, 0.95))
	lv.add_child(_next)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _glass())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -12
	bar.offset_top = 10
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var h := UI.hbox(18)
	bar.add_child(h)
	_money = _stat(h, "gold", UI.GOLD)
	_pop = _stat(h, "people", Color("bfe8ff"))
	_happy = _stat(h, "smile", Color("8ff2a2"))
	_day = _stat(h, "clock", Color.WHITE)
	var grant := UI.round_button("ad", "Grant", UI.PURPLE, 64)
	grant.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grant.offset_left = -84
	grant.offset_right = -20
	grant.offset_top = 70
	grant.offset_bottom = 134
	grant.pressed.connect(func() -> void: Ads.show_rewarded(_grant))
	_root.add_child(grant)


func _grant() -> void:
	city.state.money += 1000
	_float_money(1000)
	Sfx.play("cash")


func _build_meters() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _glass())
	p.position = Vector2(12, 92)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	var v := UI.vbox(4)
	p.add_child(v)
	v.add_child(UI.label("Demand", 18, Color(0.8, 0.85, 0.95)))
	for k in [["res", "Homes"], ["com", "Shops"], ["ind", "Industry"]]:
		var row := UI.hbox(6)
		var name_l := UI.label(k[1], 16)
		name_l.custom_minimum_size = Vector2(66, 0)
		row.add_child(name_l)
		var b := UI.bar(GameData.zone(k[0])["color"], Vector2(110, 12))
		b.min_value = -1.0
		b.max_value = 1.0
		b.step = 0.01
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		v.add_child(row)
		_meters[k[0]] = b


func _build_toolbar() -> void:
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _glass())
	tray.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tray.offset_bottom = -8
	_root.add_child(tray)
	var row := UI.hbox(8)
	tray.add_child(row)
	var tools: Array = [["", "Inspect", "info"]]
	for t in GameData.TOOL_ORDER:
		tools.append([t, GameData.zone(t)["name"], GameData.zone(t)["icon"]])
	tools.append(["bulldoze", "Bulldoze", "bulldozer"])
	for t in tools:
		var id: String = t[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(92, 92)
		b.add_theme_stylebox_override("normal", _tool_style(false))
		b.add_theme_stylebox_override("hover", _tool_style(false))
		b.add_theme_stylebox_override("pressed", _tool_style(true))
		var ic := UI.icon(t[2], 46)
		ic.position = Vector2(23, 6)
		b.add_child(ic)
		var nl := UI.label(t[1], 15)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.position = Vector2(0, 52)
		nl.size = Vector2(92, 20)
		b.add_child(nl)
		if id != "" and id != "bulldoze":
			var cl := UI.label("$%d" % int(GameData.zone(id)["cost"]), 14, UI.GOLD)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.position = Vector2(0, 70)
			cl.size = Vector2(92, 18)
			b.add_child(cl)
			var lock := UI.icon("lock", 28)
			lock.position = Vector2(60, 2)
			lock.name = "Lock"
			b.add_child(lock)
		b.pressed.connect(func() -> void: pick_tool(id))
		row.add_child(b)
		_tools[id] = b
	pick_tool("")


func _tool_style(on: bool) -> StyleBoxFlat:
	var s := UI.box(Color(0.25, 0.45, 0.8) if on else Color(0.14, 0.18, 0.26), 14, Color(1, 1, 1, 0.25), 2)
	s.border_width_bottom = 5
	return s


func pick_tool(id: String) -> void:
	city.tool = id
	for k in _tools:
		var b: Button = _tools[k]
		var on: bool = k == id
		b.add_theme_stylebox_override("normal", _tool_style(on))
		b.add_theme_stylebox_override("hover", _tool_style(on))
	if id != "":
		show_tile(Vector2i(-1, -1))
		if id != "bulldoze":
			toast("Tap a tile to build %s" % String(GameData.zone(id)["name"]).to_lower())


func _process(delta: float) -> void:
	var s := city.state
	_money.text = "$" + UI.fmt(s.money)
	_pop.text = UI.fmt(s.population())
	_happy.text = "%d%%" % s.happiness()
	_day.text = "Day %d" % s.day
	var m: Dictionary = GameData.MILESTONES[s.stage]
	_title.text = "%s of Brookvale" % m["name"]
	if s.stage + 1 < GameData.MILESTONES.size():
		_next.text = "Next: %s at %s people" % [GameData.MILESTONES[s.stage + 1]["name"], UI.fmt(int(GameData.MILESTONES[s.stage + 1]["pop"]))]
	else:
		_next.text = "The greatest city around!"
	var dem := s.demand()
	for k in _meters:
		(_meters[k] as ProgressBar).value = float(dem[k])
	for k in _tools:
		var b: Button = _tools[k]
		var lock := b.get_node_or_null("Lock")
		if lock != null:
			(lock as Control).visible = not GameData.unlocked(k, s.stage)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 3.0, 0.0, 1.0)


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.8


func _float_money(amount: int) -> void:
	var l := UI.label(("+$%s" if amount >= 0 else "-$%s") % UI.fmt(absi(amount)), 30, UI.GOLD if amount >= 0 else Color("ff6b5a"))
	l.position = _money.global_position + Vector2(0, 30)
	_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, 40), 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


func show_tile(c: Vector2i) -> void:
	if _info != null:
		_info.queue_free()
		_info = null
	if c.x < 0:
		return
	var s := city.state
	var t := s.at(c)
	var type := str(t["type"])
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", _glass())
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info.offset_right = -16
	_info.offset_top = -40
	_info.custom_minimum_size = Vector2(300, 0)
	_root.add_child(_info)
	var v := UI.vbox(4)
	_info.add_child(v)
	if type == "":
		v.add_child(UI.label("Empty land", 26))
		v.add_child(UI.label("Pick a tool below to build here", 17, Color(0.8, 0.85, 0.95)))
		return
	var z := GameData.zone(type)
	var title := str(z["name"])
	if GameData.is_lot(type):
		title += "  ·  level %d" % int(t["level"])
	v.add_child(UI.label(title, 26))
	match type:
		"res":
			v.add_child(UI.label("Home to %d people" % s._occupied(t, GameData.residents(int(t["level"]))), 19))
			v.add_child(UI.label("Happiness %d%%" % s.happiness_at(c), 19, Color("8ff2a2")))
			var need := 55 if int(t["level"]) == 1 else 70
			if int(t["level"]) < 3:
				v.add_child(UI.label("Grows taller at %d%% happiness: parks and plazas help" % need, 15, Color(0.8, 0.85, 0.95)))
		"com", "ind", "office":
			v.add_child(UI.label("%d jobs" % s._occupied(t, GameData.jobs(type, int(t["level"]))), 19))
			if type == "ind":
				v.add_child(UI.label("Noisy: neighbours are less happy", 15, Color("ffb02e")))
		"road":
			v.add_child(UI.label("Connects lots so they can grow", 17))
		"park", "plaza":
			v.add_child(UI.label("Makes nearby homes happier", 17))
	if GameData.is_lot(type):
		var bar := UI.bar(GameData.zone(type)["color"], Vector2(260, 12))
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = float(t["growth"])
		v.add_child(bar)
		if not s.connected(c):
			v.add_child(UI.label("Needs a road next to it!", 18, Color("ff6b5a")))


func _on_milestone(index: int) -> void:
	var m: Dictionary = GameData.MILESTONES[index]
	Sfx.play("milestone")
	Ads.match_finished()
	for c in _modal.get_children():
		c.queue_free()
	var box := UI.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(box)
	var t := UI.label("Brookvale is now a %s!" % m["name"], 54, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := "City hall sends $%s" % UI.fmt(int(m["reward"]))
	for z in GameData.TOOL_ORDER:
		if int(GameData.zone(z).get("unlock", -1)) == index:
			sub += "  ·  %s unlocked!" % GameData.zone(z)["name"]
	var l := UI.label(sub, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	UI.pop(box, 0.5)
	var tw := box.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)
