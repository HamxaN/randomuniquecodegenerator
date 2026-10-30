class_name Hud
extends Control
## The in-match HUD, laid out like a modern mobile shooter: health and squad top
## left, wave tracker top centre, score top right, thumbstick bottom left and the
## action buttons bottom right. Also the perk cards, the "down" screen, pause and
## the match summary.

var arena: Arena

var _stick: Joystick
var _hp_bar: ProgressBar
var _hp_text: Label
var _armor_text: Label
var _mates: Array = []
var _wave_title: Label
var _wave_sub: Label
var _wave_bar: ProgressBar
var _coins: Label
var _kills: Label
var _ammo: Label
var _ammo_max: Label
var _weapon_name: Label
var _reload_bar: ProgressBar
var _grenade: AbilityButton
var _dash: AbilityButton
var _strike: AbilityButton
var _reload: AbilityButton
var _feed: VBoxContainer
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _announce: Label
var _boss_panel: Control
var _boss_bar: ProgressBar
var _vignette: TextureRect
var _hurt := 0.0
var _hit := 0.0
var _hit_kill := false
var _overlay: Control
var _modal: Control
var _down_time := 0.0
var _down_label: Label


func _ready() -> void:
	# Already in the tree here, so set the offsets too or the HUD keeps a zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_vignette()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_world)
	add_child(_overlay)
	_stick = Joystick.new()
	_stick.anchor_right = 0.45
	_stick.anchor_bottom = 1.0
	_stick.anchor_top = 0.3
	add_child(_stick)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_actions()
	_build_feed()
	_build_banner()
	if not Save.tutorial_done:
		_tutorial()


func stick_active() -> bool:
	return _stick != null and _stick.active()


func _process(delta: float) -> void:
	if arena == null or arena.player == null:
		return
	if _stick.active() or _stick.value != Vector2.ZERO:
		arena.input_move = Vector3(_stick.value.x, 0, _stick.value.y)
	elif not arena.autopilot and not _keyboard_moving():
		arena.input_move = Vector3.ZERO
	var p := arena.player
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = lerpf(_hp_bar.value, p.hp, clampf(delta * 10.0, 0, 1))
	_hp_text.text = "%d" % int(ceil(p.hp))
	var low := p.hp / p.max_hp < 0.3
	(_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UI.RED if low else UI.GREEN
	for i in _mates.size():
		var row: Dictionary = _mates[i]
		var u: Unit = row["unit"]
		var bar: ProgressBar = row["bar"]
		bar.max_value = u.max_hp
		bar.value = u.hp
		(row["label"] as Label).modulate = Color(1, 1, 1, 0.45) if u.dead else Color.WHITE
	_coins.text = UI.fmt(arena.coins)
	_kills.text = str(arena.kills)
	var total := maxi(1, GameData.wave(maxi(arena.wave, 1)).size())
	_wave_title.text = "WAVE %d" % maxi(arena.wave, 1)
	match arena.state:
		"fight":
			_wave_sub.text = "%d HOSTILES LEFT" % arena.remaining()
			_wave_bar.value = 1.0 - float(arena.remaining()) / total
		"break", "perk":
			_wave_sub.text = "NEXT WAVE IN %d" % int(ceil(arena.state_time)) if arena.state == "break" else "CHOOSE A PERK"
			_wave_bar.value = 1.0
		_:
			_wave_sub.text = "GET READY"
			_wave_bar.value = 0.0
	_ammo.text = str(p.ammo) if p.reload_left <= 0.0 else "--"
	_ammo_max.text = "/ %d" % p.mag
	_ammo.add_theme_color_override("font_color", UI.RED if p.ammo <= p.mag / 5 else UI.TEXT)
	_reload_bar.visible = p.reload_left > 0.0
	if p.reload_left > 0.0:
		_reload_bar.value = 1.0 - p.reload_left / (float(p.weapon["reload"]) * p.reload_mult)
	_grenade.cooldown = arena.grenade_cd / arena.grenade_max
	_dash.cooldown = arena.dash_cd / arena.dash_max
	_strike.charge = arena.streak
	_reload.cooldown = 0.0 if p.reload_left <= 0.0 else 1.0
	_boss_panel.visible = arena.boss != null and not arena.boss.dead
	if _boss_panel.visible:
		_boss_bar.max_value = arena.boss.max_hp
		_boss_bar.value = arena.boss.hp
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	var hp_frac := p.hp / p.max_hp
	_vignette.modulate.a = clampf(_hurt + (0.35 - hp_frac) * 1.6 if hp_frac < 0.35 else _hurt, 0.0, 0.85)
	_hit = maxf(0.0, _hit - delta)
	if _down_label != null and arena.state == "over":
		_down_time = maxf(0.0, _down_time - delta)
		_down_label.text = "%d" % int(ceil(_down_time))
		if _down_time <= 0.0:
			_down_label = null
			show_results()
	_overlay.queue_redraw()


func _keyboard_moving() -> bool:
	return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) \
		or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)


# ---------------------------------------------------------------- Layout

func _corner(preset: int, offset: Vector2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(preset)
	c.position = offset
	add_child(c)
	return c


func _build_top_left() -> void:
	var holder := _corner(Control.PRESET_TOP_LEFT, Vector2(22, 16))
	var col := UI.vbox(6)
	holder.add_child(col)
	var card := UI.panel(UI.PANEL, arena.player.color)
	card.custom_minimum_size = Vector2(330, 0)
	col.add_child(card)
	var row := UI.hbox(12)
	card.add_child(row)
	var badge := _rank_badge(arena.player.color, arena.player.display_name.substr(0, 1))
	row.add_child(badge)
	var info := UI.vbox(0)
	row.add_child(info)
	var name_row := UI.hbox(8)
	info.add_child(name_row)
	name_row.add_child(UI.label(arena.player.display_name, 30, arena.player.color))
	_armor_text = UI.label(GameData.operator(arena.player.kind)["role"].to_upper(), 22, UI.MUTED)
	name_row.add_child(_armor_text)
	var hp_row := UI.hbox(8)
	info.add_child(hp_row)
	hp_row.add_child(UI.icon("heart", 22, UI.RED))
	_hp_bar = UI.bar(UI.GREEN, Vector2(200, 16))
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_text = UI.label("100", 28)
	hp_row.add_child(_hp_text)
	for u in arena.squad:
		if u.is_player:
			continue
		var mrow := UI.hbox(8)
		var mc := PanelContainer.new()
		var st := UI.box(Color(0, 0, 0, 0.45), 3)
		st.content_margin_left = 10
		st.content_margin_right = 10
		st.content_margin_top = 2
		st.content_margin_bottom = 2
		mc.add_theme_stylebox_override("panel", st)
		mc.add_child(mrow)
		col.add_child(mc)
		var dot := ColorRect.new()
		dot.color = u.color
		dot.custom_minimum_size = Vector2(6, 22)
		mrow.add_child(dot)
		var l := UI.label(u.display_name, 22)
		l.custom_minimum_size = Vector2(86, 0)
		mrow.add_child(l)
		var b := UI.bar(u.color, Vector2(130, 9))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mrow.add_child(b)
		_mates.append({"unit": u, "bar": b, "label": l})


func _rank_badge(color: Color, letter: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(58, 58)
	c.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(29, 0), Vector2(58, 14), Vector2(58, 42), Vector2(29, 58), Vector2(0, 42), Vector2(0, 14)])
		c.draw_colored_polygon(pts, color.darkened(0.55))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(29, 29) + (p - Vector2(29, 29)) * 0.8)
		c.draw_colored_polygon(inner, color.darkened(0.15))
		pts.append(pts[0])
		c.draw_polyline(pts, color.lightened(0.3), 2.0, true)
		var f := UI.head()
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		c.draw_string_outline(f, Vector2(29 - w / 2, 40), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 4, Color(0, 0, 0, 0.8))
		c.draw_string(f, Vector2(29 - w / 2, 40), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE))
	return c


func _build_top_center() -> void:
	var holder := _corner(Control.PRESET_CENTER_TOP, Vector2(-160, 12))
	var col := UI.vbox(4)
	col.custom_minimum_size = Vector2(320, 0)
	holder.add_child(col)
	var card := UI.panel(UI.PANEL, UI.ACCENT)
	col.add_child(card)
	var inner := UI.vbox(0)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(inner)
	_wave_title = UI.heading("WAVE 1", 34, UI.ACCENT)
	_wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_wave_title)
	_wave_sub = UI.label("GET READY", 22, UI.MUTED)
	_wave_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_wave_sub)
	_wave_bar = UI.bar(UI.ACCENT, Vector2(280, 6))
	_wave_bar.max_value = 1.0
	inner.add_child(_wave_bar)
	_boss_panel = UI.panel(Color(0.2, 0.04, 0.04, 0.85), UI.RED)
	col.add_child(_boss_panel)
	var bcol := UI.vbox(2)
	_boss_panel.add_child(bcol)
	var bl := UI.heading("BONE COLOSSUS", 24, UI.RED)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bcol.add_child(bl)
	_boss_bar = UI.bar(UI.RED, Vector2(280, 14))
	bcol.add_child(_boss_bar)
	_boss_panel.visible = false


func _build_top_right() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-410, 16))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.custom_minimum_size = Vector2(390, 0)
	holder.add_child(row)
	var kills := UI.chip("skull", "0", Color(0.92, 0.92, 0.88))
	_kills = kills.find_child("Amount", true, false) as Label
	row.add_child(kills)
	var coins := UI.chip("coin", "0", UI.ACCENT)
	_coins = coins.find_child("Amount", true, false) as Label
	row.add_child(coins)
	var pause := UI.ghost("", Vector2(58, 52))
	pause.add_child(_centered_icon("pause", 26))
	pause.pressed.connect(_pause)
	row.add_child(pause)


func _centered_icon(kind: String, s: float) -> Icon:
	var i := UI.icon(kind, s)
	i.set_anchors_preset(Control.PRESET_CENTER)
	i.position = -Vector2(s, s) / 2
	return i


func _build_actions() -> void:
	var holder := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-430, -330))
	holder.custom_minimum_size = Vector2(420, 320)
	_grenade = _ability("grenade", "", UI.ACCENT, Vector2(256, 168), 132)
	_grenade.pressed.connect(func() -> void: arena.throw_grenade())
	holder.add_child(_grenade)
	_dash = _ability("dash", "", UI.BLUE, Vector2(130, 196), 104)
	_dash.pressed.connect(func() -> void: arena.dash())
	holder.add_child(_dash)
	_strike = _ability("strike", "STRIKE", UI.ORANGE, Vector2(296, 36), 110)
	_strike.pressed.connect(func() -> void: arena.airstrike())
	holder.add_child(_strike)
	_reload = _ability("reload", "", UI.GREEN, Vector2(176, 92), 76)
	_reload.pressed.connect(func() -> void: arena.player.reload())
	holder.add_child(_reload)
	var ammo_panel := PanelContainer.new()
	var st := UI.box(Color(0, 0, 0, 0.5), 4)
	st.content_margin_left = 14
	st.content_margin_right = 14
	ammo_panel.add_theme_stylebox_override("panel", st)
	ammo_panel.position = Vector2(-10, 12)
	holder.add_child(ammo_panel)
	var acol := UI.vbox(0)
	ammo_panel.add_child(acol)
	_weapon_name = UI.label(arena.player.weapon["name"], 22, UI.MUTED)
	acol.add_child(_weapon_name)
	var arow := UI.hbox(6)
	acol.add_child(arow)
	_ammo = UI.label("30", 46)
	arow.add_child(_ammo)
	_ammo_max = UI.label("/ 30", 26, UI.MUTED)
	_ammo_max.size_flags_vertical = Control.SIZE_SHRINK_END
	arow.add_child(_ammo_max)
	_reload_bar = UI.bar(UI.ACCENT, Vector2(120, 5))
	_reload_bar.max_value = 1.0
	acol.add_child(_reload_bar)


func _ability(kind: String, caption: String, color: Color, center: Vector2, diameter: float) -> AbilityButton:
	var b := AbilityButton.new()
	b.icon_kind = kind
	b.caption = caption
	b.color = color
	b.size = Vector2(diameter, diameter)
	b.custom_minimum_size = b.size
	b.position = center - b.size / 2
	return b


func _build_feed() -> void:
	var holder := _corner(Control.PRESET_TOP_RIGHT, Vector2(-330, 96))
	_feed = UI.vbox(4)
	_feed.custom_minimum_size = Vector2(310, 0)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.add_child(_feed)


func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.55)
	strip.size = Vector2(900, 120)
	strip.position = Vector2(-450, -170)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(strip)
	var edge := ColorRect.new()
	edge.color = UI.ACCENT
	edge.size = Vector2(900, 3)
	edge.position = Vector2(-450, -170)
	_banner.add_child(edge)
	var edge2 := edge.duplicate() as ColorRect
	edge2.position = Vector2(-450, -53)
	_banner.add_child(edge2)
	_banner_title = UI.heading("", 60, UI.TEXT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.size = Vector2(900, 70)
	_banner_title.position = Vector2(-450, -168)
	_banner.add_child(_banner_title)
	_banner_sub = UI.label("", 30, UI.ACCENT)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.size = Vector2(900, 40)
	_banner_sub.position = Vector2(-450, -98)
	_banner.add_child(_banner_sub)
	_banner.modulate.a = 0.0
	_announce = UI.heading("", 40, UI.ACCENT)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.size = Vector2(800, 50)
	_announce.position = Vector2(-400, 60)
	_banner.add_child(_announce)
	_announce.modulate.a = 0.0


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.75, 0.02, 0.02, 0.85))
	g.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)


## First match only: a short "how to play" card that fades away.
func _tutorial() -> void:
	var holder := _corner(Control.PRESET_CENTER_BOTTOM, Vector2(-330, -250))
	var card := UI.panel(Color(0.05, 0.07, 0.09, 0.9), UI.ACCENT)
	card.custom_minimum_size = Vector2(660, 0)
	holder.add_child(card)
	var col := UI.vbox(4)
	card.add_child(col)
	col.add_child(UI.heading("HOW TO PLAY", 28, UI.ACCENT))
	for line in ["Move with the left stick: you aim and fire automatically.",
			"Tap GRENADE for crowds and DASH to escape.",
			"Kills charge your AIRSTRIKE. Survive as many waves as you can!"]:
		col.add_child(UI.label(line, 26))
	var tw := card.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(holder.queue_free)
	Save.tutorial_done = true
	Save.store()


# ---------------------------------------------------------------- World overlay

func _draw_world() -> void:
	if arena == null or arena.camera == null:
		return
	var cam := arena.camera
	var everyone: Array[Unit] = []
	everyone.append_array(arena.squad)
	everyone.append_array(arena.undead)
	for u in everyone:
		if u.dead or u.spawn_lock > 0.0 or u == arena.boss:
			continue
		var head := u.head_position()
		if cam.is_position_behind(head):
			continue
		var p := cam.unproject_position(head)
		var w := 54.0 if u.team == Unit.Team.SQUAD else 46.0
		var frac := u.hp / u.max_hp
		if u.team == Unit.Team.UNDEAD and frac >= 0.999:
			continue
		var col := u.color if u.team == Unit.Team.SQUAD else UI.RED
		_overlay.draw_rect(Rect2(p.x - w / 2 - 2, p.y - 2, w + 4, 9), Color(0, 0, 0, 0.6))
		_overlay.draw_rect(Rect2(p.x - w / 2, p.y, w * frac, 5), col)
		if u.team == Unit.Team.SQUAD and not u.is_player:
			var f := UI.bold()
			var tw := f.get_string_size(u.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_overlay.draw_string_outline(f, Vector2(p.x - tw / 2, p.y - 6), u.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 0.8))
			_overlay.draw_string(f, Vector2(p.x - tw / 2, p.y - 6), u.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, u.color)
	# Target lock and hit marker on the player's current target.
	var t := arena.player.target
	if t != null and not t.dead and not cam.is_position_behind(t.center()):
		var tp := cam.unproject_position(t.center())
		var s := 22.0
		var col2 := Color(1, 1, 1, 0.85)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var c: Vector2 = tp + corner * s
			_overlay.draw_line(c, c - Vector2(corner.x * 9, 0), col2, 3)
			_overlay.draw_line(c, c - Vector2(0, corner.y * 9), col2, 3)
		if _hit > 0.0:
			var hc := UI.RED if _hit_kill else Color.WHITE
			var a := _hit / 0.18
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_overlay.draw_line(tp + d * 7, tp + d * 17, Color(hc, a), 4)


# ---------------------------------------------------------------- Events from the arena

func banner(title: String, sub: String, danger: bool = false) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", UI.RED if danger else UI.TEXT)
	_banner_sub.text = sub
	_banner_sub.add_theme_color_override("font_color", UI.RED if danger else UI.ACCENT)
	var tw := _banner.create_tween()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1.3, 1.3)
	tw.set_parallel()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.5)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.35)


func announce(text: String, color: Color, small: bool = false) -> void:
	_announce.text = text
	_announce.add_theme_color_override("font_color", color)
	_announce.add_theme_font_size_override("font_size", 30 if small else 42)
	_announce.modulate.a = 1.0
	var tw := _announce.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_announce, "modulate:a", 0.0, 0.4)


func wave_cleared(n: int, bonus: int) -> void:
	banner("WAVE %d CLEARED" % n, "+%d BONUS" % bonus)


func hit_marker(kill: bool) -> void:
	_hit = 0.18
	_hit_kill = kill
	Sfx.play("hit", 1.3 if kill else 1.0, -8.0)


func hurt() -> void:
	_hurt = minf(0.7, _hurt + 0.35)


func boss_hit() -> void:
	pass


func coin_pop(_amount: int) -> void:
	var label := _coins
	label.pivot_offset = label.size / 2
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2(1.25, 1.25), 0.06)
	tw.tween_property(label, "scale", Vector2.ONE, 0.12)


func kill_feed(victim: String, big: bool, ally_down: bool = false) -> void:
	var row := PanelContainer.new()
	var st := UI.box(Color(0.4, 0.05, 0.05, 0.6) if ally_down else Color(0, 0, 0, 0.5), 3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	row.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(h)
	if not ally_down:
		h.add_child(UI.label(arena.player.display_name, 22, arena.player.color))
		h.add_child(UI.icon("gun", 22, Color(1, 1, 1, 0.8)))
	h.add_child(UI.label(victim.to_upper(), 22, UI.ACCENT if big else (UI.RED if ally_down else UI.TEXT)))
	_feed.add_child(row)
	_feed.move_child(row, 0)
	while _feed.get_child_count() > 5:
		_feed.get_child(_feed.get_child_count() - 1).queue_free()
		_feed.remove_child(_feed.get_child(_feed.get_child_count() - 1))
	var tw := row.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.5)
	tw.tween_callback(row.queue_free)


# ---------------------------------------------------------------- Modals

func _open_modal() -> Control:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_modal)
	_modal.add_child(UI.dim(0.62))
	return _modal


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func _center_box(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var col := UI.vbox(16)
	col.custom_minimum_size = Vector2(width, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col


func show_perks(choices: Array[Dictionary]) -> void:
	var m := _open_modal()
	var col := _center_box(m, 1000)
	var t := UI.heading("CHOOSE A PERK", 48, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := UI.label("Perks last for the rest of the match", 26, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var row := UI.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for perk in choices:
		var card := Button.new()
		card.custom_minimum_size = Vector2(290, 300)
		card.focus_mode = Control.FOCUS_NONE
		var normal := UI.panel_style(UI.PANEL_LIGHT, UI.ACCENT)
		var hover := UI.panel_style(Color(0.2, 0.18, 0.1, 0.95), UI.ACCENT)
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var inner := UI.vbox(10)
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)
		var ic := UI.icon(perk["icon"], 84, UI.ACCENT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(ic)
		var n := UI.heading(perk["name"], 28, UI.TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(n)
		var d := UI.label(perk["desc"], 26, UI.MUTED)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		inner.add_child(d)
		card.pressed.connect(func() -> void:
			Sfx.play("buy")
			_close_modal()
			arena.choose_perk(perk)
			announce(perk["name"], UI.ACCENT))
		row.add_child(card)
		UI.pop(card, 0.7)


func player_down(can_revive: bool) -> void:
	var m := _open_modal()
	var col := _center_box(m, 560)
	var t := UI.heading("YOU'RE DOWN", 64, UI.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := UI.label("Wave %d  ·  %d kills" % [arena.wave, arena.kills], 30, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	if can_revive:
		_down_label = UI.heading("8", 72, UI.TEXT)
		_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_down_label)
		_down_time = 8.0
		var revive := UI.button("  REVIVE", UI.GREEN, Vector2(380, 76), 38)
		revive.add_child(_ad_badge())
		revive.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		revive.pressed.connect(func() -> void:
			_down_label = null
			Ads.show_rewarded(func() -> void:
				_close_modal()
				arena.revive_player()
				announce("BACK IN THE FIGHT", UI.GREEN)))
		col.add_child(revive)
	var give := UI.ghost("END MATCH", Vector2(260, 56))
	give.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	give.pressed.connect(func() -> void:
		_down_label = null
		show_results())
	col.add_child(give)


func _ad_badge() -> Control:
	var c := UI.icon("ad", 34, Color(0.1, 0.12, 0.14))
	c.position = Vector2(22, 21)
	return c


func show_results() -> void:
	var r := arena.end_match()
	var m := _open_modal()
	var col := _center_box(m, 760)
	var t := UI.heading("MATCH SUMMARY", 52, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if r["record"]:
		var nb := UI.label("NEW BEST WAVE!", 32, UI.GREEN)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nb)
	var stats := UI.hbox(14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stats)
	stats.add_child(_stat_card("WAVES", str(r["wave"]), "trophy", UI.ACCENT))
	stats.add_child(_stat_card("KILLS", str(r["kills"]), "skull", UI.TEXT))
	stats.add_child(_stat_card("TIME", "%d:%02d" % [int(r["time"]) / 60, int(r["time"]) % 60], "bolt", UI.BLUE))
	var rewards := UI.panel(UI.PANEL_LIGHT, UI.ACCENT)
	col.add_child(rewards)
	var rr := UI.hbox(40)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_child(rr)
	var coin_row := UI.hbox(8)
	coin_row.add_child(UI.icon("coin", 40, UI.ACCENT))
	var coin_label := UI.label("+%s" % UI.fmt(r["coins"]), 44, UI.ACCENT)
	coin_row.add_child(coin_label)
	rr.add_child(coin_row)
	var xp_row := UI.hbox(8)
	xp_row.add_child(UI.icon("xp", 40, UI.BLUE))
	xp_row.add_child(UI.label("+%d XP" % r["xp"], 44, UI.BLUE))
	rr.add_child(xp_row)
	var buttons := UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	if int(r["coins"]) > 0:
		var dbl := UI.button("  x2 REWARDS", UI.GREEN, Vector2(270, 68), 32)
		dbl.add_child(_ad_badge())
		dbl.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void:
				Save.add_coins(int(r["coins"]))
				coin_label.text = "+%s" % UI.fmt(int(r["coins"]) * 2)
				Sfx.play("coin")
				dbl.disabled = true))
		buttons.add_child(dbl)
	var again := UI.button("PLAY AGAIN", UI.ACCENT, Vector2(240, 68), 32)
	again.pressed.connect(func() -> void: arena.exit_requested.emit(true))
	buttons.add_child(again)
	var lobby := UI.ghost("LOBBY", Vector2(170, 68), 30)
	lobby.pressed.connect(func() -> void: arena.exit_requested.emit(false))
	buttons.add_child(lobby)
	UI.pop(col, 0.85)


func _stat_card(title: String, value: String, icon_kind: String, color: Color) -> Control:
	var p := UI.panel(UI.PANEL_LIGHT, color)
	p.custom_minimum_size = Vector2(220, 0)
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var ic := UI.icon(icon_kind, 34, color)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var val := UI.heading(value, 46, UI.TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	var tl := UI.label(title, 24, UI.MUTED)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	return p


func _pause() -> void:
	if arena.state == "over" or arena.state == "done":
		return
	get_tree().paused = true
	var m := _open_modal()
	var col := _center_box(m, 420)
	var t := UI.heading("PAUSED", 60, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var resume := UI.button("RESUME", UI.ACCENT, Vector2(320, 70), 36)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_close_modal())
	col.add_child(resume)
	var sound := UI.ghost("SOUND: %s" % ("ON" if Save.sound else "OFF"), Vector2(320, 58))
	sound.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "SOUND: %s" % ("ON" if Save.sound else "OFF"))
	col.add_child(sound)
	var quit := UI.ghost("LEAVE MATCH", Vector2(320, 58))
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		show_results())
	col.add_child(quit)
