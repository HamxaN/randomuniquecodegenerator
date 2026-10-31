class_name Hud
extends Control
## The dungeon HUD: hero health and XP, a minimap of the floor, gold, the
## thumbstick, skill and potion buttons, loot pop-ups, level-up boons, and the
## death, floor-cleared and results screens.

var dungeon: Dungeon

var _stick: Joystick
var _hp: ProgressBar
var _hp_text: Label
var _xp: ProgressBar
var _level: Label
var _gold: Label
var _kills: Label
var _skill: AbilityButton
var _potion: AbilityButton
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _boss_panel: Control
var _boss_bar: ProgressBar
var _boss_name: Label
var _vignette: TextureRect
var _hurt := 0.0
var _overlay: Control
var _map: Control
var _visited := {}
var _modal: Control
var _down_label: Label
var _down_time := 0.0
var _loot_box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette = _make_vignette()
	add_child(_vignette)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_world)
	add_child(_overlay)
	_stick = Joystick.new()
	_stick.anchor_right = 0.45
	_stick.anchor_top = 0.3
	_stick.anchor_bottom = 1.0
	add_child(_stick)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_actions()
	_build_banner()
	_visited[0] = true
	if not Save.tutorial_done:
		_tutorial()


func stick_active() -> bool:
	return _stick != null and _stick.active()


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
	var card := UI.panel(UI.PANEL, UI.ACCENT)
	card.custom_minimum_size = Vector2(340, 0)
	holder.add_child(card)
	var row := UI.hbox(12)
	card.add_child(row)
	var h := GameData.hero(Save.hero)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(60, 60)
	var col: Color = h["color"]
	badge.draw.connect(func() -> void:
		badge.draw_circle(Vector2(30, 30), 30, UI.ACCENT.darkened(0.4))
		badge.draw_circle(Vector2(30, 30), 26, col.darkened(0.3))
		var f := UI.head()
		var letter: String = (h["class"] as String).substr(0, 1)
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		badge.draw_string(f, Vector2(30 - w / 2, 41), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE))
	_level = UI.label("1", 22, UI.ACCENT)
	_level.position = Vector2(40, 40)
	badge.add_child(_level)
	row.add_child(badge)
	var info := UI.vbox(2)
	row.add_child(info)
	info.add_child(UI.label("%s  ·  %s" % [h["name"], h["class"]], 26, UI.TEXT))
	var hp_row := UI.hbox(6)
	info.add_child(hp_row)
	_hp = UI.bar(Color("d33b3b"), Vector2(200, 16))
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp)
	_hp_text = UI.label("100", 24)
	hp_row.add_child(_hp_text)
	_xp = UI.bar(Color("5a9cff"), Vector2(200, 6))
	info.add_child(_xp)


func _build_top_center() -> void:
	var holder := _corner(Control.PRESET_CENTER_TOP, Vector2(-120, 10))
	var col := UI.vbox(4)
	col.custom_minimum_size = Vector2(240, 0)
	holder.add_child(col)
	var t := UI.heading("FLOOR %d" % dungeon.floor_n, 28, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(240, 96)
	_map.draw.connect(_draw_map)
	col.add_child(_map)
	_boss_panel = UI.panel(Color(0.2, 0.04, 0.04, 0.85), UI.RED)
	_boss_panel.custom_minimum_size = Vector2(360, 0)
	_boss_panel.position = Vector2(-60, 140)
	holder.add_child(_boss_panel)
	var bc := UI.vbox(2)
	_boss_panel.add_child(bc)
	_boss_name = UI.heading("", 22, UI.RED)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(_boss_name)
	_boss_bar = UI.bar(UI.RED, Vector2(320, 14))
	bc.add_child(_boss_bar)
	_boss_panel.visible = false


func _build_top_right() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-380, 14))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.custom_minimum_size = Vector2(360, 0)
	holder.add_child(row)
	var kills := UI.chip("skull", "0", Color(0.92, 0.9, 0.85))
	_kills = kills.find_child("Amount", true, false) as Label
	row.add_child(kills)
	var gold := UI.chip("coin", "0", UI.ACCENT)
	_gold = gold.find_child("Amount", true, false) as Label
	row.add_child(gold)
	var pause := UI.ghost("", Vector2(56, 50))
	var ic := UI.icon("pause", 24)
	ic.position = Vector2(16, 13)
	pause.add_child(ic)
	pause.pressed.connect(_pause)
	row.add_child(pause)


func _build_actions() -> void:
	var holder := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -280))
	var h := GameData.hero(Save.hero)
	_skill = AbilityButton.new()
	_skill.icon_kind = h["skill"]
	_skill.caption = (h["skill_name"] as String).to_upper()
	_skill.color = h["color"]
	_skill.size = Vector2(150, 150)
	_skill.custom_minimum_size = _skill.size
	_skill.position = Vector2(150, 90)
	_skill.pressed.connect(func() -> void: dungeon.use_skill())
	holder.add_child(_skill)
	_potion = AbilityButton.new()
	_potion.icon_kind = "potion"
	_potion.color = Color("e0404e")
	_potion.size = Vector2(100, 100)
	_potion.custom_minimum_size = _potion.size
	_potion.position = Vector2(30, 150)
	_potion.pressed.connect(func() -> void: dungeon.drink_potion())
	holder.add_child(_potion)


func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.55)
	strip.size = Vector2(900, 120)
	strip.position = Vector2(-450, -190)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(strip)
	for y in [-190, -73]:
		var e := ColorRect.new()
		e.color = UI.ACCENT
		e.size = Vector2(900, 2)
		e.position = Vector2(-450, y)
		_banner.add_child(e)
	_banner_title = UI.heading("", 56)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.size = Vector2(900, 70)
	_banner_title.position = Vector2(-450, -188)
	_banner.add_child(_banner_title)
	_banner_sub = UI.label("", 30, UI.ACCENT)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.size = Vector2(900, 40)
	_banner_sub.position = Vector2(-450, -118)
	_banner.add_child(_banner_sub)
	_banner.modulate.a = 0.0
	_toast = UI.label("", 34, UI.ACCENT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(800, 50)
	_toast.position = Vector2(-400, 40)
	_banner.add_child(_toast)
	_toast.modulate.a = 0.0


func _make_vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.7, 0.02, 0.02, 0.85))
	g.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	var v := TextureRect.new()
	v.texture = tex
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.modulate.a = 0.0
	return v


func _tutorial() -> void:
	var holder := _corner(Control.PRESET_CENTER_BOTTOM, Vector2(-330, -240))
	var card := UI.panel(Color(0.06, 0.05, 0.04, 0.92), UI.ACCENT)
	card.custom_minimum_size = Vector2(660, 0)
	holder.add_child(card)
	var col := UI.vbox(4)
	card.add_child(col)
	col.add_child(UI.heading("HOW TO PLAY", 26, UI.ACCENT))
	for line in ["Move with the left stick: you attack the nearest foe by yourself.",
			"Rooms lock until every monster is slain. Grab gold and gear.",
			"Tap your SKILL for big damage and the POTION to heal."]:
		col.add_child(UI.label(line, 26))
	var tw := card.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(holder.queue_free)
	Save.tutorial_done = true
	Save.store()


func _process(delta: float) -> void:
	if dungeon == null or dungeon.hero == null:
		return
	if _stick.active() or _stick.value != Vector2.ZERO:
		dungeon.input_move = Vector3(_stick.value.x, 0, _stick.value.y)
	elif not dungeon.autopilot and not (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)):
		dungeon.input_move = Vector3.ZERO
	var h := dungeon.hero
	_hp.max_value = h.max_hp
	_hp.value = lerpf(_hp.value, h.hp, clampf(delta * 10.0, 0, 1))
	_hp_text.text = str(int(ceil(h.hp)))
	var lv := int(dungeon.run["level"])
	_level.text = str(lv)
	_xp.max_value = GameData.xp_for_level(lv)
	_xp.value = int(dungeon.run["xp"])
	_gold.text = UI.fmt(int(dungeon.run["gold"]))
	_kills.text = str(int(dungeon.run["kills"]))
	_skill.cooldown = dungeon.skill_cd / dungeon.skill_max
	_potion.count_text = str(int(dungeon.run["potions"]))
	_potion.cooldown = 1.0 if int(dungeon.run["potions"]) <= 0 else 0.0
	_boss_panel.visible = dungeon.boss != null and not dungeon.boss.dead and dungeon.boss.spawn_lock <= 0.0
	if _boss_panel.visible:
		_boss_name.text = dungeon.boss.display_name.to_upper()
		_boss_bar.max_value = dungeon.boss.max_hp
		_boss_bar.value = dungeon.boss.hp
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	var frac := h.hp / h.max_hp
	_vignette.modulate.a = clampf(_hurt + (maxf(0.0, 0.35 - frac) * 1.6), 0.0, 0.85)
	if _down_label != null:
		_down_time = maxf(0.0, _down_time - delta)
		_down_label.text = str(int(ceil(_down_time)))
		if _down_time <= 0.0:
			_down_label = null
			show_results()
	_overlay.queue_redraw()
	_map.queue_redraw()


func _draw_world() -> void:
	var cam := dungeon.camera
	for m in dungeon.monsters:
		if m.dead or m.spawn_lock > 0.0 or m == dungeon.boss or m.hp >= m.max_hp:
			continue
		var p3 := m.head()
		if cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3)
		_overlay.draw_rect(Rect2(p.x - 26, p.y - 2, 52, 9), Color(0, 0, 0, 0.6))
		_overlay.draw_rect(Rect2(p.x - 24, p.y, 48 * m.hp / m.max_hp, 5), UI.RED)


func _draw_map() -> void:
	var cells: Array[Vector2i] = []
	for r in dungeon.rooms:
		cells.append(r["cell"])
	var minx := 0
	var maxx := 0
	var miny := 0
	var maxy := 0
	for c in cells:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		miny = mini(miny, c.y)
		maxy = maxi(maxy, c.y)
	var w := float(maxx - minx + 1)
	var hgt := float(maxy - miny + 1)
	var step := minf(_map.size.x / w, _map.size.y / hgt)
	step = minf(step, 26.0)
	var origin := (_map.size - Vector2(w, hgt) * step) / 2
	_map.draw_rect(Rect2(origin - Vector2(6, 6), Vector2(w, hgt) * step + Vector2(12, 12)), Color(0, 0, 0, 0.45))
	var cur := dungeon.current_room
	for i in dungeon.rooms.size():
		var r: Dictionary = dungeon.rooms[i]
		var c: Vector2i = r["cell"]
		var p := origin + Vector2(c.x - minx, c.y - miny) * step + Vector2(step, step) / 2
		for l in r["links"]:
			var q := origin + Vector2((l as Vector2i).x - minx, (l as Vector2i).y - miny) * step + Vector2(step, step) / 2
			_map.draw_line(p, q, Color(1, 1, 1, 0.25), 2.0)
	for i in dungeon.rooms.size():
		var r: Dictionary = dungeon.rooms[i]
		var c: Vector2i = r["cell"]
		var p := origin + Vector2(c.x - minx, c.y - miny) * step + Vector2(step, step) / 2
		var known := _visited.has(i)
		var col := Color(0.35, 0.32, 0.28, 0.9)
		if known:
			col = Color(0.75, 0.68, 0.55)
		if r["kind"] == "boss":
			col = Color(0.85, 0.2, 0.2) if known else Color(0.5, 0.15, 0.15)
		elif r["kind"] == "treasure" and known:
			col = UI.ACCENT
		if i == cur:
			col = Color.WHITE
		var s := step * 0.62
		_map.draw_rect(Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), col)


func minimap_visit(i: int) -> void:
	_visited[i] = true


# ---------------------------------------------------------------- Messages

func banner(title: String, sub: String, danger: bool = false) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", UI.RED if danger else UI.TEXT)
	_banner_sub.text = sub
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.8)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func hurt() -> void:
	_hurt = minf(0.7, _hurt + 0.3)


func loot_popup(item: Dictionary, equipped: bool) -> void:
	if _loot_box != null:
		_loot_box.queue_free()
	var r := GameData.rarity(item["rarity"])
	var col: Color = r["color"]
	_loot_box = _corner(Control.PRESET_CENTER_BOTTOM, Vector2(-220, -200))
	var card := UI.panel(Color(0.06, 0.05, 0.04, 0.94), col)
	card.custom_minimum_size = Vector2(440, 0)
	_loot_box.add_child(card)
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(UI.icon("sword" if item["slot"] == "weapon" else item["slot"], 56, col))
	var c := UI.vbox(0)
	row.add_child(c)
	c.add_child(UI.label("%s %s" % [r["name"].to_upper(), (item["slot"] as String).to_upper()], 20, col))
	c.add_child(UI.heading(item["name"], 26, UI.TEXT))
	c.add_child(UI.label(GameData.item_stat(item), 24, UI.GREEN))
	c.add_child(UI.label("EQUIPPED!" if equipped else "Weaker than yours: sold for %d gold" % GameData.sell_value(item), 22, UI.ACCENT if equipped else UI.MUTED))
	UI.pop(card, 0.6)
	var box := _loot_box
	var tw := card.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(box):
			box.queue_free())


# ---------------------------------------------------------------- Modals

func _open_modal() -> Control:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_modal.add_child(UI.dim(0.62))
	return _modal


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func _center_box(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var col := UI.vbox(16)
	col.custom_minimum_size = Vector2(width, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col


func show_boons(choices: Array[Dictionary]) -> void:
	get_tree().paused = true
	var m := _open_modal()
	var col := _center_box(m, 980)
	var t := UI.heading("LEVEL UP!", 52, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := UI.label("Choose a blessing for this run", 28, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for boon in choices:
		var card := Button.new()
		card.custom_minimum_size = Vector2(290, 290)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", UI.panel_style(UI.PANEL_LIGHT, UI.ACCENT))
		card.add_theme_stylebox_override("hover", UI.panel_style(Color(0.24, 0.18, 0.1, 0.95), UI.ACCENT))
		card.add_theme_stylebox_override("pressed", UI.panel_style(Color(0.24, 0.18, 0.1, 0.95), UI.ACCENT))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var inner := UI.vbox(10)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)
		var ic := UI.icon(boon["icon"], 80, UI.ACCENT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(ic)
		var n := UI.heading(boon["name"], 26)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(n)
		var d := UI.label(boon["desc"], 26, UI.MUTED)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		inner.add_child(d)
		var id: String = boon["id"]
		card.pressed.connect(func() -> void:
			get_tree().paused = false
			Sfx.play("buy")
			_close_modal()
			dungeon.choose_boon(id)
			toast(boon["name"]))
		row.add_child(card)
		UI.pop(card, 0.7)


func hero_down(can_revive: bool) -> void:
	var m := _open_modal()
	var col := _center_box(m, 560)
	var t := UI.heading("YOU HAVE FALLEN", 54, UI.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if can_revive:
		_down_label = UI.heading("8", 70)
		_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_down_label)
		_down_time = 8.0
		var rev := UI.button("   RISE AGAIN", UI.GREEN, Vector2(380, 76), 34)
		var ad := UI.icon("ad", 34, Color(0.1, 0.1, 0.1))
		ad.position = Vector2(22, 20)
		rev.add_child(ad)
		rev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rev.pressed.connect(func() -> void:
			_down_label = null
			Ads.show_rewarded(func() -> void:
				_close_modal()
				dungeon.revive_hero()))
		col.add_child(rev)
	var give := UI.ghost("RETURN TO CAMP", Vector2(300, 56))
	give.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	give.pressed.connect(func() -> void:
		_down_label = null
		show_results())
	col.add_child(give)


func floor_cleared() -> void:
	var m := _open_modal()
	var col := _center_box(m, 620)
	var t := UI.heading("FLOOR %d CLEARED" % dungeon.floor_n, 50, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var s := UI.label("Gold so far: %s   ·   Kills: %d" % [UI.fmt(int(dungeon.run["gold"])), int(dungeon.run["kills"])], 28)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	var deeper := UI.button("DESCEND TO FLOOR %d" % (dungeon.floor_n + 1), UI.ACCENT, Vector2(460, 80), 32)
	deeper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deeper.pressed.connect(func() -> void: dungeon.exit_requested.emit(true))
	col.add_child(deeper)
	var camp := UI.ghost("RETURN TO CAMP WITH THE LOOT", Vector2(460, 60))
	camp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	camp.pressed.connect(show_results)
	col.add_child(camp)


func show_results() -> void:
	get_tree().paused = false
	var r := dungeon.end_run()
	var m := _open_modal()
	var col := _center_box(m, 700)
	var t := UI.heading("RUN COMPLETE", 52, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if r["record"]:
		var nb := UI.label("NEW DEEPEST FLOOR!", 30, UI.GREEN)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nb)
	var stats := UI.hbox(14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stats)
	for spec in [["FLOORS", str(r["floor"]), "map"], ["KILLS", str(r["kills"]), "skull"], ["LEVEL", str(r["level"]), "star"]]:
		var p := UI.panel(UI.PANEL_LIGHT, UI.ACCENT)
		p.custom_minimum_size = Vector2(200, 0)
		var v := UI.vbox(0)
		p.add_child(v)
		var ic := UI.icon(spec[2], 34, UI.ACCENT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var val := UI.heading(spec[1], 44)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(val)
		var tl := UI.label(spec[0], 22, UI.MUTED)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
		stats.add_child(p)
	var gold_row := UI.hbox(10)
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_child(UI.icon("coin", 44, UI.ACCENT))
	var gl := UI.heading("+%s" % UI.fmt(int(r["gold"])), 44, UI.ACCENT)
	gold_row.add_child(gl)
	col.add_child(gold_row)
	var buttons := UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	if int(r["gold"]) > 0:
		var dbl := UI.button("   DOUBLE GOLD", UI.GREEN, Vector2(290, 70), 30)
		var ad := UI.icon("ad", 32, Color(0.1, 0.1, 0.1))
		ad.position = Vector2(20, 19)
		dbl.add_child(ad)
		dbl.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void:
				Save.gold += int(r["gold"])
				Save.store()
				gl.text = "+%s" % UI.fmt(int(r["gold"]) * 2)
				Sfx.play("coin")
				dbl.disabled = true))
		buttons.add_child(dbl)
	var camp := UI.button("BACK TO CAMP", UI.ACCENT, Vector2(280, 70), 30)
	camp.pressed.connect(func() -> void: dungeon.exit_requested.emit(false))
	buttons.add_child(camp)
	UI.pop(col, 0.85)


func _pause() -> void:
	if dungeon.state in ["dead", "done", "portal"]:
		return
	get_tree().paused = true
	var m := _open_modal()
	var col := _center_box(m, 420)
	var t := UI.heading("PAUSED", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var resume := UI.button("RESUME", UI.ACCENT, Vector2(320, 70), 34)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_close_modal())
	col.add_child(resume)
	var quit := UI.ghost("ABANDON RUN", Vector2(320, 58))
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(show_results)
	col.add_child(quit)
