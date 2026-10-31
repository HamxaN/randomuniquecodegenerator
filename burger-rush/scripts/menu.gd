class_name Menu
extends CanvasLayer
## The front of house: logo, coins and stars, the big PLAY button, and panels
## for picking a day, upgrading the kitchen and hiring chefs.

signal play_day(day: int)
signal chef_changed

var _coins: Label
var _stars: Label
var _modal: Control
var _play: Button


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var logo := UI.label("BURGER", 92, UI.GOLD)
	logo.position = Vector2(30, 4)
	root.add_child(logo)
	var logo2 := UI.label("RUSH!", 92, Color("ff6b3a"))
	logo2.position = Vector2(70, 88)
	logo2.rotation = -0.05
	root.add_child(logo2)
	var top := UI.vbox(6)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -300
	top.offset_right = -18
	top.offset_top = 14
	root.add_child(top)
	var cbar := UI.resource_bar("gold", UI.GOLD, 220)
	_coins = cbar.get_node("Amount") as Label
	(cbar.get_node("Bar") as ProgressBar).value = 100
	top.add_child(cbar)
	var sbar := UI.resource_bar("star", Color("ff9a1f"), 220)
	_stars = sbar.get_node("Amount") as Label
	(sbar.get_node("Bar") as ProgressBar).value = 100
	top.add_child(sbar)
	var bottom := UI.hbox(16)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24
	bottom.offset_top = -150
	bottom.offset_bottom = -24
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_play = UI.button("", UI.GREEN, Vector2(300, 100), 44)
	_play.pressed.connect(func() -> void: play_day.emit(Save.unlocked_day()))
	bottom.add_child(_play)
	for b in [["calendar", "Days", Color("3f9de0"), open_days], ["flame", "Kitchen", Color("ff9a1f"), open_upgrades],
			["chef", "Chefs", Color("9b5ce0"), open_chefs], ["sound", "Sound", Color("8a8f96"), _toggle_sound]]:
		var rb := UI.round_button(b[0], b[1], b[2], 92)
		rb.pressed.connect(b[3])
		bottom.add_child(rb)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_modal)
	Save.changed.connect(_update)
	_update()
	Ads.show_banner()


func _exit_tree() -> void:
	Ads.hide_banner()


func _update() -> void:
	_coins.text = UI.fmt(Save.coins)
	_stars.text = "%d / %d" % [Save.total_stars(), GameData.day_count() * 3]
	_play.text = "Play Day %d" % Save.unlocked_day()


func _toggle_sound() -> void:
	Save.sound = not Save.sound
	Save.store()
	_toast("Sound on" if Save.sound else "Sound off")


func _toast(text: String) -> void:
	var l := UI.label(text, 36)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_modal.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func close_panel() -> void:
	for c in _modal.get_children():
		c.queue_free()


func _panel(title: String, width: float = 760.0) -> VBoxContainer:
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
	var t := UI.label(title, 40, UI.GOLD)
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


func open_days() -> void:
	var v := _panel("Choose a day", 900)
	var unlocked := Save.unlocked_day()
	for li in GameData.LOCATIONS.size():
		var loc: Dictionary = GameData.LOCATIONS[li]
		var row := UI.hbox(8)
		v.add_child(row)
		var name_l := UI.ink(loc["name"], 22)
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(name_l)
		for k in GameData.DAYS_PER_LOCATION:
			var d := li * GameData.DAYS_PER_LOCATION + k + 1
			var open := d <= unlocked
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 70)
			b.focus_mode = Control.FOCUS_NONE
			var col: Color = (loc["floor_b"] as Color) if open else UI.GREY
			b.add_theme_stylebox_override("normal", UI.card_style(col.lightened(0.15)))
			b.add_theme_stylebox_override("hover", UI.card_style(col.lightened(0.25)))
			b.add_theme_stylebox_override("pressed", UI.card_style(col))
			b.add_theme_stylebox_override("disabled", UI.card_style(UI.GREY))
			b.disabled = not open
			var num := UI.label(str(d), 26)
			num.position = Vector2(8, 2)
			b.add_child(num)
			var stars := Save.day_stars(d)
			for s in 3:
				var si := UI.icon("star" if s < stars else "star_empty", 18)
				si.position = Vector2(6 + s * 18, 44)
				b.add_child(si)
			if not open:
				var lock := UI.icon("lock", 26)
				lock.position = Vector2(34, 4)
				b.add_child(lock)
			b.pressed.connect(func() -> void:
				close_panel()
				play_day.emit(d))
			row.add_child(b)


func open_upgrades() -> void:
	var v := _panel("Kitchen upgrades", 820)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for u in GameData.UPGRADES:
		var id: String = u["id"]
		var lv := Save.level(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style())
		card.custom_minimum_size = Vector2(380, 0)
		grid.add_child(card)
		var h := UI.hbox(10)
		card.add_child(h)
		h.add_child(UI.icon(u["icon"], 54))
		var info := UI.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.ink("%s  (%d/%d)" % [u["name"], lv, int(u["max"])], 22))
		var desc := UI.ink(u["desc"], 17)
		desc.modulate = Color(1, 1, 1, 0.75)
		info.add_child(desc)
		if lv >= int(u["max"]):
			h.add_child(UI.button("Max", UI.GREY, Vector2(110, 54), 24))
			continue
		var cost := GameData.upgrade_cost(id, lv)
		var buy := UI.button(UI.fmt(cost), UI.GREEN if Save.coins >= cost else UI.GREY, Vector2(120, 54), 24)
		buy.pressed.connect(func() -> void:
			if Save.buy_upgrade(id):
				Sfx.play("buy")
				open_upgrades()
			else:
				Sfx.play("error")
				_toast("Not enough coins"))
		h.add_child(buy)


func open_chefs() -> void:
	var v := _panel("Chefs", 900)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for c in GameData.CHEFS:
		var id: String = c["id"]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style(Color("ffe08a") if Save.chef == id else UI.PARCHMENT_DARK))
		row.add_child(card)
		var col := UI.vbox(4)
		card.add_child(col)
		var tex := TextureRect.new()
		tex.texture = Thumbs.chef(self, c["model"], 180)
		tex.custom_minimum_size = Vector2(140, 140)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(tex)
		var n := UI.ink(c["name"], 20)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var label := "Cooking" if Save.chef == id else ("Pick" if Save.chefs.has(id) else UI.fmt(int(c["cost"])))
		var color := UI.GREY if Save.chef == id else (UI.BLUE if Save.chefs.has(id) else UI.GREEN)
		var b := UI.button(label, color, Vector2(140, 50), 22)
		b.pressed.connect(func() -> void:
			if Save.pick_chef(id):
				Sfx.play("buy")
				chef_changed.emit()
				open_chefs()
			else:
				Sfx.play("error")
				_toast("Not enough coins"))
		col.add_child(b)
