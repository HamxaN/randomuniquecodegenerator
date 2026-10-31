class_name ShiftHud
extends CanvasLayer
## Everything drawn over a day at the restaurant: the coin goal bar with its
## three stars, customers left, order bubbles, cooking timers, the chef's job
## queue, tips, the tutorial pointer and the end-of-day results.

signal next_pressed
signal retry_pressed
signal menu_pressed

var restaurant: Restaurant
var bubbles: Control
var _overlay: Overlay
var _coin_bar: ProgressBar
var _coin_label: Label
var _star_icons: Array[Icon] = []
var _guests: Label
var _toast: Label
var _toast_t := 0.0
var _hint: PanelContainer
var _hint_label: Label
var _modal: Control
var _coin_target: Control


class Overlay:
	extends Control
	var hud: ShiftHud
	var ripples: Array = []
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		for r in ripples:
			r["t"] = float(r["t"]) + delta
		ripples = ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < 0.4)
		queue_redraw()

	func _draw() -> void:
		var rest := hud.restaurant
		if rest == null:
			return
		var font := UI.font()
		for r in rest.rings():
			var p: Vector2 = r["pos"] + Vector2(0, -6)
			var col: Color = r["color"]
			draw_circle(p, 25, Color(0.1, 0.06, 0.03, 0.85))
			draw_arc(p, 19, -PI / 2, -PI / 2 + TAU * clampf(float(r["frac"]), 0.0, 1.0), 32, col, 9.0, true)
			draw_arc(p, 25, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.5, true)
		for m in rest.queue_marks():
			var p: Vector2 = m["pos"]
			draw_circle(p, 17, Color(0.1, 0.06, 0.03))
			draw_circle(p, 14, Color("3f9de0"))
			var txt := str(m["n"])
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
			draw_string(font, p + Vector2(-sz.x / 2, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		for r in ripples:
			var k := float(r["t"]) / 0.4
			draw_arc(r["pos"], 20 + k * 40, 0, TAU, 32, Color(1, 1, 1, 1.0 - k), 5.0, true)
		if rest.tutorial_step >= 0:
			var target := rest.tutorial_target()
			if target.x > 0:
				var bob := sin(_t * 6.0) * 8.0
				var tip := target + Vector2(0, -50 + bob)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-22, -34), tip + Vector2(22, -34)]), Color("ffd23a"))
				draw_polyline(PackedVector2Array([tip, tip + Vector2(-22, -34), tip + Vector2(22, -34), tip]), Color(0.15, 0.08, 0.02), 4.0, true)
				draw_rect(Rect2(tip + Vector2(-9, -70), Vector2(18, 38)), Color("ffd23a"))
				draw_arc(target, 44 + sin(_t * 6.0) * 4.0, 0, TAU, 40, Color("ffd23a"), 5.0, true)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bubbles = Control.new()
	bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubbles)
	_overlay = Overlay.new()
	_overlay.hud = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)
	_build_top(root)
	_toast = UI.label("", 34)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 96
	_toast.offset_bottom = 140
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	_hint = PanelContainer.new()
	var hs := UI.box(Color(0.1, 0.06, 0.03, 0.82), 18, Color("ffd23a"), 3)
	hs.content_margin_left = 22
	hs.content_margin_right = 22
	hs.content_margin_top = 8
	hs.content_margin_bottom = 10
	_hint.add_theme_stylebox_override("panel", hs)
	_hint_label = UI.label("", 28)
	_hint.add_child(_hint_label)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -18
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	root.add_child(_hint)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_modal)
	_intro()


func _build_top(root: Control) -> void:
	# Day and goal, top-left.
	var card := PanelContainer.new()
	var cs := UI.box(Color(0.1, 0.06, 0.03, 0.72), 18, Color(1, 1, 1, 0.15), 2)
	cs.content_margin_left = 16
	cs.content_margin_right = 16
	cs.content_margin_top = 6
	cs.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", cs)
	card.position = Vector2(14, 10)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var v := UI.vbox(2)
	card.add_child(v)
	var loc: Dictionary = restaurant.loc
	v.add_child(UI.label("Day %d  ·  %s" % [restaurant.day, loc["name"]], 24, Color("ffe7a8")))
	var row := Control.new()
	row.custom_minimum_size = Vector2(330, 46)
	v.add_child(row)
	_coin_bar = UI.bar(UI.GOLD, Vector2(270, 26))
	_coin_bar.position = Vector2(30, 12)
	var goals: Array = restaurant.plan["goals"]
	_coin_bar.max_value = float(goals[2])
	row.add_child(_coin_bar)
	var ci := UI.icon("gold", 44)
	ci.position = Vector2(-6, 4)
	row.add_child(ci)
	_coin_target = ci
	_coin_label = UI.label("0", 24)
	_coin_label.position = Vector2(40, 10)
	row.add_child(_coin_label)
	for i in 3:
		var star := UI.icon("star_empty", 30)
		star.position = Vector2(30 + 270.0 * float(goals[i]) / float(goals[2]) - 15, 10)
		row.add_child(star)
		_star_icons.append(star)
	# Customers left, top-centre.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", cs.duplicate() as StyleBoxFlat)
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = 12
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)
	var ph := UI.hbox(8)
	pill.add_child(ph)
	ph.add_child(UI.icon("chef", 36))
	_guests = UI.label("0 / 0", 28)
	ph.add_child(_guests)
	# Pause, top-right.
	var pause := UI.round_button("pause", "", Color("3f9de0"), 64)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -80
	pause.offset_right = -16
	pause.offset_top = 12
	pause.offset_bottom = 76
	pause.pressed.connect(show_pause)
	root.add_child(pause)


func _intro() -> void:
	var item := GameData.new_item(restaurant.day)
	var text := "Day %d" % restaurant.day
	var sub := "Earn %d coins for a star" % int(restaurant.plan["goals"][0])
	if item != "":
		sub = "New on the menu: %s!" % ("Fries" if item == "fries" else item.capitalize())
	var box := UI.vbox(0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UI.label(text, 96, UI.GOLD)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var small := UI.label(sub, 36)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(small)
	if item != "":
		var ic := UI.icon(item if item != "patty" else "patty", 84)
		var holder := CenterContainer.new()
		holder.add_child(ic)
		box.add_child(holder)
	_modal.add_child(box)
	UI.pop(box)
	var tw := box.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


func add_bubble(order: Dictionary) -> OrderBubble:
	var b := OrderBubble.new()
	b.setup(order)
	bubbles.add_child(b)
	UI.pop(b, 0.3)
	return b


func refresh() -> void:
	var r := restaurant
	_coin_bar.value = r.coins
	_coin_label.text = UI.fmt(r.coins)
	var goals: Array = r.plan["goals"]
	for i in 3:
		var reached := r.coins >= int(goals[i])
		if reached and _star_icons[i].kind != "star":
			_star_icons[i].kind = "star"
			UI.pop(_star_icons[i], 0.2)
			Sfx.play("star")
	var total: int = r.plan["orders"].size()
	_guests.text = "%d / %d" % [r.served + r.lost, total]
	if _toast_t > 0.0:
		_toast_t -= get_process_delta_time()
		_toast.modulate.a = clampf(_toast_t * 3.0, 0.0, 1.0)
	var hint := r.tutorial_text() if r.tutorial_step >= 0 else ""
	_hint.visible = hint != ""
	_hint_label.text = hint


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.6


func tapped(at: Vector2) -> void:
	_overlay.ripples.append({"pos": at, "t": 0.0})


## Little coins flying from a happy customer to the coin bar.
func coin_burst(from: Vector2) -> void:
	var to := _coin_target.global_position + Vector2(22, 22)
	for i in 5:
		var c := UI.icon("gold", 34)
		c.position = from + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		_modal.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(c, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


func _panel(title: String) -> VBoxContainer:
	_clear_modal()
	var dim := UI.dim()
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(520, 0)
	center.add_child(p)
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var t := UI.label(title, 48, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _clear_modal() -> void:
	for c in _modal.get_children():
		c.queue_free()


func show_pause() -> void:
	if restaurant.state != "open":
		return
	get_tree().paused = true
	var v := _panel("Paused")
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var resume := UI.button("Resume", UI.GREEN, Vector2(190, 70))
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_clear_modal())
	row.add_child(resume)
	var quit := UI.button("Menu", UI.RED, Vector2(160, 70))
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		menu_pressed.emit())
	row.add_child(quit)


func show_results(result: Dictionary, best: bool) -> void:
	var stars := int(result["stars"])
	var title := "Day complete!" if stars > 0 else "Not enough coins..."
	var v := _panel(title)
	var star_row := UI.hbox(6)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(star_row)
	for i in 3:
		var s := UI.icon("star" if i < stars else "star_empty", 74)
		star_row.add_child(s)
		if i < stars:
			s.modulate.a = 0.0
			var tw := s.create_tween()
			tw.tween_interval(0.3 + i * 0.25)
			tw.tween_callback(func() -> void:
				s.modulate.a = 1.0
				UI.pop(s, 0.3)
				Sfx.play("star", 1.0 + i * 0.12))
	var earned := UI.hbox(8)
	earned.alignment = BoxContainer.ALIGNMENT_CENTER
	earned.add_child(UI.icon("gold", 44))
	var amount := UI.label("+%s" % UI.fmt(int(result["coins"])), 44, UI.GOLD)
	earned.add_child(amount)
	v.add_child(earned)
	var stats := UI.ink("Served %d  ·  Walked out %d%s" % [int(result["served"]), int(result["lost"]),
		"  ·  New best!" if best and stars > 0 else ""], 26)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	if stars == 0:
		var need := UI.ink("Earn %d coins to pass this day." % int((result["goals"] as Array)[0]), 24)
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(need)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	if int(result["coins"]) > 0:
		var dbl := UI.button("x2 Coins", UI.PURPLE, Vector2(170, 66), 28)
		var ad := UI.icon("ad", 30)
		ad.position = Vector2(10, 16)
		dbl.add_child(ad)
		var reward := func() -> void:
			Save.coins += int(result["coins"])
			Save.store()
			amount.text = "+%s" % UI.fmt(int(result["coins"]) * 2)
			UI.pop(amount, 0.6)
			Sfx.play("cash")
		dbl.pressed.connect(func() -> void:
			dbl.disabled = true
			Ads.show_rewarded(reward))
		row.add_child(dbl)
	if stars > 0 and restaurant.day < GameData.day_count():
		var nxt := UI.button("Next day", UI.GREEN, Vector2(180, 66), 30)
		nxt.pressed.connect(func() -> void: next_pressed.emit())
		row.add_child(nxt)
	else:
		var again := UI.button("Try again", UI.ORANGE, Vector2(180, 66), 30)
		again.pressed.connect(func() -> void: retry_pressed.emit())
		row.add_child(again)
	var menu := UI.button("Menu", UI.BLUE, Vector2(140, 66), 30)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu)
