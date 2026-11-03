class_name ManorHud
extends CanvasLayer
## The screens over the manor: energy, coins and stars along the top, the
## orders on the left, the merge board on the right with an info bar under
## it, and the renovate button that spends stars on the next step.

signal renovated(step: Dictionary)

var board: BoardState
var thumbs: ThumbCache
var view: BoardView
var _root: Control
var _energy: Label
var _energy_timer: Label
var _coins: Label
var _stars: Label
var _orders: VBoxContainer
var _order_sig := ""
var _info_name: Label
var _info_text: Label
var _sell: Button
var _renovate: Button
var _room_label: Label
var _room_bar: ProgressBar
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
	_build_board()
	_build_orders()
	_build_renovate()
	_toast = UI.label("", 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 70
	_toast.offset_bottom = 110
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	board.changed.connect(_refresh)
	thumbs.rendered.connect(func(_m: String) -> void: _order_sig = "")
	_refresh()
	Ads.show_banner()


func _pill(icon: String, color: Color) -> Label:
	var p := PanelContainer.new()
	var s := UI.box(Color(1.0, 0.97, 0.9, 0.92), 20, Color(0.55, 0.38, 0.22), 3)
	s.content_margin_left = 10
	s.content_margin_right = 14
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var h := UI.hbox(6)
	p.add_child(h)
	h.add_child(UI.icon(icon, 34))
	var l := UI.label("0", 26, color)
	l.custom_minimum_size = Vector2(60, 0)
	h.add_child(l)
	_top.add_child(p)
	return l


var _top: HBoxContainer


func _build_top() -> void:
	var logo := UI.label("Merge Manor", 44, Color("ffe7b0"))
	logo.position = Vector2(20, 6)
	_root.add_child(logo)
	_top = UI.hbox(10)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top.offset_right = -14
	_top.offset_top = 10
	_root.add_child(_top)
	_energy = _pill("bolt", Color("ff9a1f"))
	_energy_timer = UI.label("", 16, Color(0.4, 0.3, 0.2), false)
	(_energy.get_parent() as HBoxContainer).add_child(_energy_timer)
	var plus := UI.round_button("plus", "", UI.GREEN, 38)
	plus.pressed.connect(open_energy)
	(_energy.get_parent() as HBoxContainer).add_child(plus)
	_coins = _pill("gold", Color("b07a10"))
	_stars = _pill("star", Color("e08a00"))


func _build_board() -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	holder.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.offset_left = -(GameData.COLS * (BoardView.CELL + BoardView.GAP) + BoardView.GAP + 26)
	holder.offset_right = -20
	holder.offset_top = 70
	holder.offset_bottom = -10
	_root.add_child(holder)
	view = BoardView.new()
	view.board = board
	view.thumbs = thumbs
	holder.add_child(view)
	view.tapped_generator.connect(_on_generator)
	view.selected.connect(_on_selected)
	view.merged.connect(func(i: int, id: String) -> void:
		if GameData.level_of(id) == GameData.max_level(GameData.chain_of(id)):
			toast("Top of the line: %s!" % GameData.display_name(id)))
	var info := PanelContainer.new()
	var s := UI.box(Color(1.0, 0.97, 0.9, 0.94), 14, Color(0.55, 0.38, 0.22), 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	info.add_theme_stylebox_override("panel", s)
	holder.add_child(info)
	var ih := UI.hbox(10)
	info.add_child(ih)
	var iv := UI.vbox(0)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(iv)
	_info_name = UI.label("Tap a box to unpack it", 22, Color(0.35, 0.2, 0.1), false)
	iv.add_child(_info_name)
	_info_text = UI.label("Drag two matching items together to merge them", 16, Color(0.45, 0.32, 0.22), false)
	iv.add_child(_info_text)
	_sell = UI.button("Sell", UI.ORANGE, Vector2(110, 48), 22)
	_sell.visible = false
	_sell.pressed.connect(func() -> void:
		var v := board.sell(view.selection)
		if v > 0:
			Sfx.play("coin")
			toast("+%d coins" % v)
			_on_selected(-1))
	ih.add_child(_sell)


func _build_orders() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.parchment_style())
	p.position = Vector2(16, 70)
	_root.add_child(p)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.ink("Orders", 26))
	_orders = UI.vbox(8)
	v.add_child(_orders)


func _build_renovate() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.parchment_style())
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = 16
	card.offset_bottom = -16
	_root.add_child(card)
	var v := UI.vbox(6)
	card.add_child(v)
	_room_label = UI.ink("", 22)
	v.add_child(_room_label)
	_room_bar = UI.bar(Color("ff9a1f"), Vector2(300, 14))
	v.add_child(_room_bar)
	_renovate = UI.button("", UI.GREEN, Vector2(300, 64), 22)
	_renovate.pressed.connect(renovate)
	v.add_child(_renovate)


func renovate() -> void:
	var s := board.renovate()
	if s.is_empty():
		var need := board.current_step()
		if need.is_empty():
			toast("The manor is fully restored!")
		else:
			toast("You need %d stars: fill orders to earn them" % int(need["stars"]))
		Sfx.play("error")
		return
	Sfx.play("renovate")
	renovated.emit(s)
	Ads.match_finished()


func _on_generator(i: int) -> void:
	var r := board.tap_generator(i)
	if r == -1:
		toast("Out of energy! It refills over time")
		Sfx.play("error")
		open_energy()
	elif r == -2:
		toast("The board is full: merge or sell something")
		Sfx.play("error")
	else:
		Sfx.play("pop", 1.0 + randf() * 0.2)


func _on_selected(i: int) -> void:
	var id := board.at(i)
	_sell.visible = GameData.is_item(id)
	if id == "":
		_info_name.text = "Tap a box to unpack it"
		_info_text.text = "Drag two matching items together to merge them"
	elif GameData.is_generator(id):
		_info_name.text = GameData.display_name(id)
		var names: Array = []
		for c in GameData.GENERATORS[id.trim_prefix("gen_")]["chains"]:
			names.append(GameData.CHAINS[c]["name"])
		_info_text.text = "Tap to unpack (1 energy): %s" % ", ".join(names)
	else:
		var lv := GameData.level_of(id)
		var top := GameData.max_level(GameData.chain_of(id))
		_info_name.text = "%s  ·  level %d of %d" % [GameData.display_name(id), lv, top]
		_info_text.text = ("Merge two to make a %s" % GameData.display_name(GameData.merged(id))) if lv < top else "The finest of its kind!"
		_sell.text = "Sell %d" % GameData.sell_value(id)


func _refresh() -> void:
	_energy.text = "%d/%d" % [board.energy, GameData.MAX_ENERGY]
	_coins.text = UI.fmt(board.coins)
	_stars.text = str(board.stars)
	if board.finished():
		_room_label.text = "The manor is fully restored!"
		_room_bar.value = 1
		_room_bar.max_value = 1
		_renovate.text = "All done!"
		_renovate.disabled = true
	else:
		var room: Dictionary = GameData.ROOMS[board.room]
		var total := (room["steps"] as Array).size()
		_room_label.text = "%s  ·  %d / %d" % [room["name"], board.step, total]
		_room_bar.max_value = total
		_room_bar.value = board.step
		var s := board.current_step()
		_renovate.text = "%s   %d★" % [s["name"], int(s["stars"])]
		_renovate.modulate = Color.WHITE if board.stars >= int(s["stars"]) else Color(0.75, 0.75, 0.75)
	var sig := str(board.orders) + str(board.cells)
	if sig != _order_sig:
		_order_sig = sig
		_rebuild_orders()


func _rebuild_orders() -> void:
	for c in _orders.get_children():
		c.queue_free()
	for o in board.orders.size():
		var id: String = board.orders[o]
		var have := board.find_for_order(o) >= 0
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style(Color("c8f0a8") if have else UI.PARCHMENT_DARK))
		_orders.add_child(card)
		var h := UI.hbox(8)
		card.add_child(h)
		var tex := TextureRect.new()
		tex.texture = thumbs.texture(GameData.model(id))
		tex.custom_minimum_size = Vector2(64, 64)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tex)
		var v := UI.vbox(0)
		v.custom_minimum_size = Vector2(150, 0)
		h.add_child(v)
		v.add_child(UI.ink(GameData.display_name(id), 20))
		var reward := GameData.order_reward(id)
		v.add_child(UI.ink("%d★  +%d coins" % [int(reward["stars"]), int(reward["coins"])], 16))
		var b := UI.button("Deliver", UI.GREEN if have else UI.GREY, Vector2(104, 48), 20)
		var which := o
		b.pressed.connect(func() -> void: deliver(which))
		h.add_child(b)


func deliver(o: int) -> bool:
	if board.deliver(o):
		Sfx.play("coin")
		Sfx.play("star")
		toast("Order delivered!")
		return true
	toast("Merge up a %s first" % GameData.display_name(board.orders[o]))
	Sfx.play("error")
	return false


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.8


func _process(delta: float) -> void:
	if board.energy < GameData.MAX_ENERGY:
		var left := GameData.ENERGY_EVERY - board.energy_t
		_energy_timer.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	else:
		_energy_timer.text = ""
	_energy.text = "%d/%d" % [board.energy, GameData.MAX_ENERGY]
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 3.0, 0.0, 1.0)


func close_panel() -> void:
	for c in _modal.get_children():
		c.queue_free()


func open_energy() -> void:
	close_panel()
	_modal.add_child(UI.dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := UI.panel()
	center.add_child(p)
	var v := UI.vbox(12)
	p.add_child(v)
	v.add_child(UI.label("More energy", 40, UI.GOLD))
	v.add_child(UI.ink("Energy refills one point every %d seconds." % int(GameData.ENERGY_EVERY), 22))
	var row := UI.hbox(12)
	v.add_child(row)
	var ad := UI.button("+30 free", UI.PURPLE, Vector2(200, 64), 26)
	ad.pressed.connect(func() -> void:
		Ads.show_rewarded(_free_energy)
		close_panel())
	row.add_child(ad)
	var buy := UI.button("Refill  %d" % board.refill_cost(), UI.GREEN, Vector2(220, 64), 26)
	buy.pressed.connect(func() -> void:
		if board.buy_refill():
			Sfx.play("coin")
			close_panel()
		else:
			toast("Not enough coins"))
	row.add_child(buy)
	var close := UI.button("Close", UI.GREY, Vector2(140, 64), 26)
	close.pressed.connect(close_panel)
	row.add_child(close)


func _free_energy() -> void:
	board.energy = mini(GameData.MAX_ENERGY + 30, board.energy + 30)
	board.changed.emit()
	Sfx.play("star")


func celebrate(text: String) -> void:
	var l := UI.label(text, 64, UI.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	l.offset_left = 40
	l.offset_right = 640
	l.offset_top = -40
	l.offset_bottom = 40
	_modal.add_child(l)
	UI.pop(l, 0.4)
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
