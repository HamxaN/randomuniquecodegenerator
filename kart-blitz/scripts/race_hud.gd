class_name RaceHud
extends Control
## Race HUD: place, lap and time top left, the item slot top centre, a minimap
## top right, the speedo, steering and drift/item buttons, the countdown and the
## results podium.

const ORDINALS := ["1st", "2nd", "3rd", "4th", "5th", "6th"]

var race: Race
var _place: Label
var _place_of: Label
var _lap: Label
var _time: Label
var _speed: Label
var _item_slot: Control
var _item_kind := ""
var _roll_t := 0.0
var _map: Control
var _left: HoldButton
var _right: HoldButton
var _drift: HoldButton
var _big: Label
var _flash: Label
var _modal: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_item_slot()
	_build_map()
	_build_controls()
	_big = UI.label("", 150, UI.GOLD)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.offset_left = -400
	_big.offset_right = 400
	_big.offset_top = -170
	_big.offset_bottom = 30
	add_child(_big)
	_flash = UI.label("", 52, UI.GOLD)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_left = -400
	_flash.offset_right = 400
	_flash.offset_top = 170
	_flash.modulate.a = 0.0
	add_child(_flash)


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
	var holder := _corner(Control.PRESET_TOP_LEFT, Vector2(24, 10))
	var row := UI.hbox(6)
	holder.add_child(row)
	_place = UI.label("6th", 92, UI.GOLD)
	row.add_child(_place)
	_place_of = UI.label("/6", 40)
	_place_of.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_place_of)
	var col := UI.vbox(0)
	col.position = Vector2(4, 112)
	holder.add_child(col)
	_lap = UI.label("LAP 1/3", 36)
	col.add_child(_lap)
	_time = UI.label("0:00.0", 28, Color(0.95, 0.95, 0.9))
	col.add_child(_time)


func _build_item_slot() -> void:
	var holder := _corner(Control.PRESET_CENTER_TOP, Vector2(-60, 14))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 120)
	b.size = b.custom_minimum_size
	holder.add_child(b)
	_item_slot = Control.new()
	_item_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_slot.draw.connect(_draw_item)
	b.add_child(_item_slot)
	b.pressed.connect(func() -> void: race.use_item(race.player))


func _build_map() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-250, 14))
	_map = Control.new()
	_map.custom_minimum_size = Vector2(230, 200)
	_map.size = _map.custom_minimum_size
	_map.draw.connect(_draw_map)
	holder.add_child(_map)


func _build_controls() -> void:
	var left := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(30, -190))
	_left = _hold("left", "", Color("3f9de0"), 150)
	left.add_child(_left)
	_right = _hold("right", "", Color("3f9de0"), 150)
	_right.position = Vector2(175, 0)
	left.add_child(_right)
	var right := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-350, -200))
	_drift = _hold("drift", "DRIFT", Color("ff9a1f"), 170)
	_drift.position = Vector2(160, 10)
	right.add_child(_drift)
	var item := _hold("item", "ITEM", Color("9b5ce0"), 120)
	item.position = Vector2(20, 40)
	item.pressed.connect(func() -> void: race.use_item(race.player))
	right.add_child(item)
	var sp := _corner(Control.PRESET_CENTER_BOTTOM, Vector2(-90, -96))
	_speed = UI.label("0", 64)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.size = Vector2(180, 70)
	sp.add_child(_speed)
	var kmh := UI.label("km/h", 22, Color(0.9, 0.9, 0.85))
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kmh.size = Vector2(180, 30)
	kmh.position = Vector2(0, 66)
	sp.add_child(kmh)


func _hold(kind: String, caption: String, color: Color, d: float) -> HoldButton:
	var b := HoldButton.new()
	b.icon_kind = kind
	b.caption = caption
	b.color = color
	b.size = Vector2(d, d)
	b.custom_minimum_size = b.size
	return b


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	var steer := 0.0
	if _left.held or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		steer -= 1.0
	if _right.held or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		steer += 1.0
	race.steer_input = steer
	race.drift_input = _drift.held or Input.is_key_pressed(KEY_SPACE)
	if Input.is_key_pressed(KEY_E):
		race.use_item(p)
	var place := race.place_of(p)
	_place.text = ORDINALS[place - 1]
	_place.add_theme_color_override("font_color", UI.GOLD if place == 1 else (Color("cfd6de") if place == 2 else (Color("e09a5a") if place == 3 else UI.TEXT)))
	var laps := int(race.track.info["laps"])
	_lap.text = "LAP %d/%d" % [clampi(p.lap + 1, 1, laps), laps]
	var t := race.race_time
	_time.text = "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
	_speed.text = str(int(p.speed * 3.6))
	_speed.add_theme_color_override("font_color", Color("ffb347") if p.boost_time > 0.0 else UI.TEXT)
	_roll_t = maxf(0.0, _roll_t - delta)
	_item_slot.queue_redraw()
	_map.queue_redraw()


func _draw_item() -> void:
	var c := _item_slot.size / 2
	var r := minf(_item_slot.size.x, _item_slot.size.y) / 2 - 4
	_item_slot.draw_circle(c, r + 4, Color(0.08, 0.05, 0.03, 0.9))
	_item_slot.draw_circle(c, r, Color(1, 1, 1, 0.92))
	_item_slot.draw_arc(c, r, 0, TAU, 40, UI.GOLD, 5.0, true)
	var kind := _item_kind
	if _roll_t > 0.0:
		kind = GameData.ITEMS[int(_roll_t * 20.0) % GameData.ITEMS.size()]
	if kind == "":
		return
	var s := r * 1.2
	_item_slot.draw_set_transform(c - Vector2(s, s) / 2)
	match kind:
		"boost", "triple":
			var count := 3 if kind == "triple" and race.player.item_uses >= 3 else (race.player.item_uses if kind == "triple" else 1)
			for i in count:
				var off := Vector2((i - (count - 1) / 2.0) * s * 0.22, 0)
				_item_slot.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.55, s * 0.12) + off, Vector2(s * 0.3, s * 0.55) + off, Vector2(s * 0.48, s * 0.55) + off, Vector2(s * 0.42, s * 0.9) + off, Vector2(s * 0.7, s * 0.42) + off, Vector2(s * 0.52, s * 0.42) + off]), Color("ff9a1f"))
		"rocket":
			_item_slot.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.5, s * 0.08), Vector2(s * 0.66, s * 0.4), Vector2(s * 0.66, s * 0.75), Vector2(s * 0.34, s * 0.75), Vector2(s * 0.34, s * 0.4)]), Color("e6463a"))
			_item_slot.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.34, s * 0.6), Vector2(s * 0.2, s * 0.88), Vector2(s * 0.34, s * 0.8)]), Color("b8302a"))
			_item_slot.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.66, s * 0.6), Vector2(s * 0.8, s * 0.88), Vector2(s * 0.66, s * 0.8)]), Color("b8302a"))
			_item_slot.draw_circle(Vector2(s * 0.5, s * 0.42), s * 0.08, Color("bfe8ff"))
		"shield":
			_item_slot.draw_circle(Vector2(s * 0.5, s * 0.5), s * 0.38, Color(0.35, 0.75, 1.0, 0.85))
			_item_slot.draw_arc(Vector2(s * 0.5, s * 0.5), s * 0.38, 0, TAU, 32, Color("1f6fb8"), s * 0.05)
			_item_slot.draw_arc(Vector2(s * 0.42, s * 0.42), s * 0.18, PI, PI * 1.5, 12, Color(1, 1, 1, 0.8), s * 0.05)
		"oil":
			_item_slot.draw_circle(Vector2(s * 0.5, s * 0.58), s * 0.3, Color(0.1, 0.1, 0.14))
			_item_slot.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.5, s * 0.1), Vector2(s * 0.72, s * 0.5), Vector2(s * 0.28, s * 0.5)]), Color(0.1, 0.1, 0.14))
			_item_slot.draw_circle(Vector2(s * 0.42, s * 0.5), s * 0.06, Color(0.6, 0.6, 0.8))
	_item_slot.draw_set_transform(Vector2.ZERO)


func _draw_map() -> void:
	var pts := race.track.samples
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	var area := _map.size - Vector2(24, 24)
	var k := minf(area.x / (mx.x - mn.x), area.y / (mx.y - mn.y))
	var origin := Vector2(12, 12) + (area - (mx - mn) * k) / 2
	var line := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		line.append(origin + (Vector2(pts[i].x, pts[i].z) - mn) * k)
	line.append(line[0])
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0, 0, 0, 0.35))
	_map.draw_polyline(line, Color(0.1, 0.08, 0.05, 0.9), 9.0, true)
	_map.draw_polyline(line, Color(0.92, 0.92, 0.9), 5.0, true)
	for kart in race.karts:
		var q := origin + (Vector2(kart.position.x, kart.position.z) - mn) * k
		var col := UI.GOLD if kart.is_player else Color("e6463a")
		_map.draw_circle(q, 8.0 if kart.is_player else 6.0, Color(0.1, 0.06, 0.03))
		_map.draw_circle(q, 6.0 if kart.is_player else 4.5, col)


func countdown(t: float) -> void:
	var n := int(ceil(t))
	var text := "GO!" if t <= 0.6 else (str(n - 1) if n - 1 >= 1 else "GO!")
	if t > 3.0:
		text = ""
	if _big.text != text:
		_big.text = text
		if text != "":
			_big.pivot_offset = _big.size / 2
			_big.scale = Vector2(1.6, 1.6)
			_big.modulate.a = 1.0
			_big.create_tween().tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("go" if text == "GO!" else "beep")
	if t <= 0.0:
		var tw := _big.create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(_big, "modulate:a", 0.0, 0.3)


func flash_text(text: String, color: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.modulate.a = 1.0
	_flash.pivot_offset = _flash.size / 2
	_flash.scale = Vector2(1.3, 1.3)
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(0.7)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.3)


func lap_banner(lap: int, laps: int) -> void:
	flash_text("FINAL LAP!" if lap == laps else "LAP %d" % lap, UI.GOLD)


func item_roll(kind: String) -> void:
	_item_kind = kind
	if kind != "":
		_roll_t = 0.6


func finished(place: int) -> void:
	_big.text = ORDINALS[place - 1] + "!"
	_big.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(show_results)


func show_results() -> void:
	if _modal != null:
		return
	var r := race.results()
	_big.text = ""
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_modal.add_child(UI.dim(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var col := UI.vbox(10)
	panel.add_child(col)
	var place: int = r["place"]
	var title := UI.label("YOU FINISHED %s!" % ORDINALS[place - 1].to_upper(), 54, UI.GOLD if place <= 3 else UI.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var list := UI.vbox(4)
	col.add_child(list)
	var order: Array = r["order"]
	for i in order.size():
		var k: Kart = order[i]
		var row := PanelContainer.new()
		var st := UI.card_style(UI.GOLD.lightened(0.3) if k.is_player else UI.PARCHMENT_DARK)
		st.content_margin_top = 4
		st.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", st)
		var h := UI.hbox(14)
		row.add_child(h)
		var pl := UI.label(ORDINALS[i], 28, [UI.GOLD, Color("cfd6de"), Color("e09a5a")][i] if i < 3 else UI.TEXT)
		pl.custom_minimum_size = Vector2(70, 0)
		h.add_child(pl)
		var nm := UI.ink(k.display_name + "  ·  " + str(k.info["name"]), 26)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.ink("+%d pts" % GameData.points_for(i + 1), 24))
		list.add_child(row)
	var reward := UI.hbox(10)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_child(UI.icon("gold", 46))
	var coins_label := UI.label("+%d" % int(r["coins"]), 46, UI.GOLD)
	reward.add_child(coins_label)
	col.add_child(reward)
	if r["unlocked"] != "":
		var u := UI.label("NEW TRACK UNLOCKED: %s" % r["unlocked"], 30, UI.GREEN)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(u)
	var buttons := UI.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var dbl := UI.button("   x2 Coins", UI.PURPLE, Vector2(240, 72), 30)
	var ad := UI.icon("ad", 34)
	ad.position = Vector2(16, 18)
	dbl.add_child(ad)
	dbl.pressed.connect(func() -> void:
		Ads.show_rewarded(func() -> void:
			Save.coins += int(r["coins"])
			Save.store()
			coins_label.text = "+%d" % (int(r["coins"]) * 2)
			Sfx.play("coin")
			dbl.disabled = true))
	buttons.add_child(dbl)
	var again := UI.button("Race again", UI.GREEN, Vector2(230, 72), 30)
	again.pressed.connect(func() -> void: race.exit_requested.emit(true))
	buttons.add_child(again)
	var garage := UI.button("Garage", UI.BLUE, Vector2(190, 72), 30)
	garage.pressed.connect(func() -> void: race.exit_requested.emit(false))
	buttons.add_child(garage)
	UI.pop(panel, 0.8)
