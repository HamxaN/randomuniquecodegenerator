class_name Hud
extends CanvasLayer
## Everything on screen during a match: twin-stick touch controls, crosshair,
## minimap and full map, zone timer, alive and kill counts, health and armour,
## weapon slots, kill feed, squad status, hit and damage indicators, scopes,
## and the results screen.

var game
var root: Control
var stick: Joystick
var look: TouchButton.LookPad
var fire_r: TouchButton
var fire_l: TouchButton
var ads_btn: TouchButton
var jump_btn: TouchButton
var reload_btn: TouchButton
var nade_btn: TouchButton
var heal_btn: TouchButton
var act_btn: TouchButton
var slots: Array = []
var minimap: MapView
var bigmap: Control
var overlay: Control
var info_label: Label
var zone_label: Label
var alive_label: Label
var kills_label: Label
var toast_label: Label
var center_label: Label
var feed_box: VBoxContainer
var squad_box: VBoxContainer
var heal_menu: HBoxContainer
var spectate_bar: HBoxContainer
var results_panel: Control
var menu_btn: Button
var nade_cycle: TouchButton
var banner: Label
var _streak := 0
var _streak_t := 0.0

var _look_acc := Vector2.ZERO
var _ads_toggle := false
var _hits: Array = []
var _hurts: Array = []
var _marker_t := 0.0
var _marker_kill := false
var _shake := 0.0
var _revive := {}
var _recorded := false
var _last_ctx := ""
var _act_ctx := {}


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	look = TouchButton.LookPad.new()
	root.add_child(look)
	look.dragged.connect(func(r: Vector2) -> void: _look_acc += r)
	stick = Joystick.new()
	root.add_child(stick)
	fire_r = _btn("", 118, "fire", Color(0.9, 0.25, 0.2, 0.45))
	fire_r.big = true
	fire_l = _btn("", 82, "fire", Color(0.9, 0.25, 0.2, 0.4))
	for b in [fire_r, fire_l]:
		b.dragged.connect(func(r: Vector2) -> void: _look_acc += r)
	ads_btn = _btn("", 76, "scope")
	ads_btn.pressed.connect(func() -> void: _ads_toggle = not _ads_toggle)
	jump_btn = _btn("", 72, "jump")
	jump_btn.pressed.connect(_on_jump)
	reload_btn = _btn("", 64, "reload")
	reload_btn.pressed.connect(func() -> void:
		if game.local != null:
			game.local.start_reload())
	nade_btn = _btn("", 64, "grenade")
	nade_btn.pressed.connect(func() -> void: game.throw_local_grenade())
	nade_cycle = _btn("", 44, "", Color(0.1, 0.1, 0.12, 0.7))
	nade_cycle.pressed.connect(func() -> void:
		if game.local != null:
			game.local.inv.cycle_throwable()
			refresh_inventory())
	heal_btn = _btn("", 64, "heal")
	heal_btn.pressed.connect(_toggle_heal_menu)
	act_btn = _btn("", 92, "hand", Color(0.95, 0.75, 0.1, 0.55))
	act_btn.pressed.connect(func() -> void: game.interact())
	for i in 2:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 58)
		b.add_theme_font_override("font", UI.bold())
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void:
			if game.local != null:
				game.request(game.local, "switch", i))
		root.add_child(b)
		slots.append(b)
	minimap = MapView.new()
	minimap.game = game
	minimap.custom_minimum_size = Vector2(190, 190)
	minimap.size = Vector2(190, 190)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.clip_contents = true
	minimap.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			_toggle_map())
	root.add_child(minimap)
	alive_label = UI.label("", 30)
	root.add_child(alive_label)
	kills_label = UI.label("", 30, UI.ACCENT)
	root.add_child(kills_label)
	zone_label = UI.label("", 24)
	root.add_child(zone_label)
	info_label = UI.label("", 26, UI.TEXT)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)
	center_label = UI.heading("", 38)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	banner = UI.heading("", 46, UI.ACCENT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	root.add_child(banner)
	toast_label = UI.label("", 28)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)
	feed_box = UI.vbox(2)
	feed_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(feed_box)
	squad_box = UI.vbox(4)
	root.add_child(squad_box)
	heal_menu = UI.hbox(10)
	heal_menu.visible = false
	root.add_child(heal_menu)
	for kind in ["bandage", "medkit", "drink"]:
		var hb := _btn(String(GameData.HEALS[kind]["name"]).split(" ")[0], 70, "", Color(0.1, 0.1, 0.12, 0.7))
		root.remove_child(hb)
		hb.name = kind
		hb.pressed.connect(func() -> void:
			heal_menu.visible = false
			if game.local != null:
				game.request(game.local, "heal", kind))
		heal_menu.add_child(hb)
	spectate_bar = UI.hbox(14)
	spectate_bar.visible = false
	var next := UI.ghost("NEXT PLAYER", Vector2(200, 56), 26)
	next.pressed.connect(func() -> void: game.rig.next_spectate())
	spectate_bar.add_child(next)
	var leave := UI.button("LEAVE", UI.RED, Vector2(160, 56), 28)
	leave.pressed.connect(func() -> void: game.exit_requested.emit(false))
	spectate_bar.add_child(leave)
	root.add_child(spectate_bar)
	menu_btn = UI.ghost("II", Vector2(56, 52), 26)
	menu_btn.pressed.connect(_confirm_leave)
	root.add_child(menu_btn)
	bigmap = _make_bigmap()
	bigmap.visible = false
	root.add_child(bigmap)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh_inventory()


func _btn(label: String, d: float, icon: String, col: Color = Color(0, 0, 0, 0.35)) -> TouchButton:
	var b := TouchButton.new(label, d, icon)
	b.color = col
	root.add_child(b)
	return b


func _layout() -> void:
	var s := root.get_viewport_rect().size
	stick.position = Vector2(0, s.y * 0.38)
	stick.size = Vector2(s.x * 0.36, s.y * 0.62)
	look.position = Vector2(s.x * 0.36, s.y * 0.18)
	look.size = Vector2(s.x * 0.64, s.y * 0.82)
	fire_r.position = Vector2(s.x - 170, s.y - 200)
	fire_l.position = Vector2(s.x * 0.36 - 40, s.y * 0.42)
	ads_btn.position = Vector2(s.x - 290, s.y - 150)
	jump_btn.position = Vector2(s.x - 120, s.y - 330)
	reload_btn.position = Vector2(s.x - 240, s.y - 260)
	nade_btn.position = Vector2(s.x - 330, s.y - 250)
	nade_cycle.position = Vector2(s.x - 352, s.y - 280)
	banner.position = Vector2(s.x * 0.5 - 400, s.y * 0.36)
	banner.size = Vector2(800, 60)
	heal_btn.position = Vector2(s.x * 0.5 + 200, s.y - 76)
	act_btn.position = Vector2(s.x * 0.5 + 120, s.y * 0.5 - 20)
	heal_menu.position = Vector2(s.x * 0.5 - 40, s.y - 200)
	for i in 2:
		(slots[i] as Button).position = Vector2(s.x * 0.5 - 180 + i * 184, s.y - 70)
	minimap.position = Vector2(18, 16)
	alive_label.position = Vector2(s.x - 330, 14)
	kills_label.position = Vector2(s.x - 170, 14)
	menu_btn.position = Vector2(s.x - 72, 70)
	zone_label.position = Vector2(220, 18)
	feed_box.position = Vector2(s.x - 420, 120)
	feed_box.size = Vector2(400, 200)
	squad_box.position = Vector2(18, 220)
	info_label.position = Vector2(s.x * 0.5 - 300, s.y * 0.18)
	info_label.size = Vector2(600, 40)
	center_label.position = Vector2(s.x * 0.5 - 400, s.y * 0.3)
	center_label.size = Vector2(800, 60)
	toast_label.position = Vector2(s.x * 0.5 - 300, s.y * 0.24)
	toast_label.size = Vector2(600, 40)
	spectate_bar.position = Vector2(s.x * 0.5 - 190, s.y - 90)
	bigmap.size = s
	results_reposition()


func results_reposition() -> void:
	if results_panel != null:
		results_panel.size = root.get_viewport_rect().size


# --- Input -------------------------------------------------------------------------

func move_vec() -> Vector2:
	var v := stick.value
	if v == Vector2.ZERO:
		v = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	return Vector2(v.x, -v.y) if stick.value != Vector2.ZERO else Vector2(v.x, v.y)


func fire_held() -> bool:
	return fire_r.held or fire_l.held


## Feeds this frame's touches into the local fighter.
func apply_to(f: Fighter, delta: float) -> void:
	var z: float = game.rig.zoom()
	var sens := Save.sensitivity * (1.0 / sqrt(z))
	f.yaw -= _look_acc.x * 0.0055 * sens
	f.pitch = clampf(f.pitch - _look_acc.y * 0.0045 * sens, -1.25, 1.15)
	_look_acc = Vector2.ZERO
	f.move = move_vec() if f.state != "vehicle" else Vector2.ZERO
	f.aiming = _ads_toggle and f.state == "ground" and f.inv.has_weapon()
	game.rig.assist(delta, fire_held())


func _on_jump() -> void:
	var f: Fighter = game.local
	if f == null:
		return
	match f.state:
		"plane":
			game.request(f, "jump", null)
		"fall":
			f.want_jump = true
		_:
			f.want_jump = true


func _toggle_heal_menu() -> void:
	heal_menu.visible = not heal_menu.visible
	refresh_inventory()


func _toggle_map() -> void:
	bigmap.visible = not bigmap.visible


func _confirm_leave() -> void:
	var d := UI.dim(0.6)
	var p := UI.panel()
	var v := UI.vbox(16)
	v.add_child(UI.heading("LEAVE MATCH?", 36))
	v.add_child(UI.label("You'll lose your place in this match.", 24, UI.MUTED))
	var h := UI.hbox(14)
	var stay := UI.ghost("STAY", Vector2(160, 56))
	stay.pressed.connect(d.queue_free)
	var go := UI.button("LEAVE", UI.RED, Vector2(160, 56))
	go.pressed.connect(func() -> void: game.exit_requested.emit(false))
	h.add_child(stay)
	h.add_child(go)
	v.add_child(h)
	p.add_child(v)
	d.add_child(p)
	root.add_child(d)
	p.position = root.get_viewport_rect().size * 0.5 - Vector2(220, 110)


# --- Per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var f: Fighter = game.local
	if f == null:
		return
	var st := f.state
	var combat := st == "ground" and f.alive()
	for b in [fire_r, fire_l, ads_btn, reload_btn, nade_btn, nade_cycle]:
		(b as Control).visible = combat
	_streak_t = maxf(0.0, _streak_t - delta)
	if _streak_t <= 0.0:
		_streak = 0
	heal_btn.visible = combat
	if not combat:
		heal_menu.visible = false
		if fire_r.held:
			fire_r.release()
		if fire_l.held:
			fire_l.release()
	jump_btn.visible = st in ["plane", "fall", "ground"]
	jump_btn.icon_kind = "chute" if st == "fall" else "jump"
	jump_btn.text = "JUMP" if st == "plane" else ("OPEN" if st == "fall" else "")
	jump_btn.custom_minimum_size = Vector2(118, 118) if st in ["plane", "fall"] else Vector2(72, 72)
	jump_btn.size = jump_btn.custom_minimum_size
	stick.visible = f.alive() and st != "plane"
	if not _ads_toggle or not combat:
		ads_btn.held = false
	ads_btn.color = Color(0.25, 0.6, 1.0, 0.55) if _ads_toggle else Color(0, 0, 0, 0.35)
	ads_btn.queue_redraw()
	if not combat:
		_ads_toggle = false
	for s in slots:
		(s as Control).visible = f.alive() and st in ["ground", "vehicle", "chute"]
	# Context button.
	_act_ctx = game.local_context()
	act_btn.visible = not _act_ctx.is_empty()
	if not _act_ctx.is_empty():
		act_btn.text = String(_act_ctx["label"]).substr(0, 18)
		act_btn.icon_kind = {"exit": "exit", "enter": "car", "revive": "heal"}.get(_act_ctx["kind"], "hand")
		act_btn.custom_minimum_size = Vector2(112, 112)
		act_btn.size = act_btn.custom_minimum_size
		act_btn.queue_redraw()
	if f.state == "vehicle":
		act_btn.position = Vector2(root.get_viewport_rect().size.x - 170, root.get_viewport_rect().size.y - 200)
	else:
		act_btn.position = Vector2(root.get_viewport_rect().size.x * 0.5 + 120, root.get_viewport_rect().size.y * 0.5 - 20)
	_update_labels(f)
	_update_squad(f)
	_marker_t = maxf(0.0, _marker_t - delta)
	_shake = maxf(0.0, _shake - delta)
	for h in _hurts.duplicate():
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) <= 0.0:
			_hurts.erase(h)
	spectate_bar.visible = not f.alive() and game.phase != "over"
	overlay.queue_redraw()
	minimap.queue_redraw()
	if bigmap.visible:
		bigmap.get_child(0).queue_redraw()


func _update_labels(f: Fighter) -> void:
	alive_label.text = "%d ALIVE" % game.alive_count()
	kills_label.text = "%d KILLS" % f.kills
	var zs: Dictionary = game.zone_state()
	var tm := int(ceil(float(zs["timer"])))
	if game.phase == "over":
		zone_label.text = ""
	elif bool(zs["shrinking"]):
		zone_label.text = "ZONE CLOSING  %d:%02d" % [tm / 60, tm % 60]
		zone_label.add_theme_color_override("font_color", UI.ORANGE)
	elif float(zs["timer"]) > 0.0:
		zone_label.text = "ZONE SHRINKS IN  %d:%02d" % [tm / 60, tm % 60]
		zone_label.add_theme_color_override("font_color", UI.TEXT)
	else:
		zone_label.text = "FINAL ZONE"
	var msg := ""
	match f.state:
		"plane":
			msg = "Tap JUMP when you're over where you want to land"
			if game.clock > game.plane_duration() - 6.0:
				msg = "Last chance to jump!"
		"fall":
			msg = "Push forward to dive faster  ·  %dm" % int(f.global_position.y - game.island.height(f.global_position.x, f.global_position.z))
		"chute":
			msg = "Steer to your landing spot"
		"knocked":
			msg = "KNOCKED DOWN  ·  Crawl to cover, your squad can revive you"
		"dead":
			var sp: Fighter = game.rig.spectating
			msg = ("Spectating " + sp.display_name) if sp != null else "Eliminated"
		"vehicle":
			msg = "Driving" if f.seat == 0 else "Passenger"
	if f.alive() and f.state in ["ground", "vehicle", "knocked"] and game.zone.outside(f.global_position, game.clock):
		msg = "OUTSIDE THE ZONE  ·  Get to safety!"
	if f.heal_t > 0.0:
		msg = "Using %s..." % GameData.HEALS.get(f.heal_kind, {"name": "item"})["name"]
	if f.reload_t > 0.0:
		msg = "Reloading..."
	info_label.text = msg
	info_label.add_theme_color_override("font_color", UI.RED if msg.begins_with("OUTSIDE") or msg.begins_with("KNOCKED") else UI.TEXT)
	center_label.text = ""


func _update_squad(f: Fighter) -> void:
	var mates: Array = game.squad(f.team)
	if squad_box.get_child_count() != mates.size():
		for c in squad_box.get_children():
			c.queue_free()
		for m in mates:
			var row := UI.hbox(8)
			var l := UI.label(m.display_name, 20)
			l.custom_minimum_size.x = 100
			row.add_child(l)
			var bar := UI.bar(UI.GREEN, Vector2(90, 10))
			bar.max_value = 100
			row.add_child(bar)
			squad_box.add_child(row)
	for i in mates.size():
		var m: Fighter = mates[i]
		var row := squad_box.get_child(i)
		if row == null or row.get_child_count() < 2:
			continue
		var bar := row.get_child(1) as ProgressBar
		var lbl := row.get_child(0) as Label
		bar.value = m.hp if m.state != "knocked" else m.bleed
		var col := UI.GREEN
		if m.state == "knocked":
			col = UI.RED
		elif not m.alive():
			col = Color(0.3, 0.3, 0.3)
		bar.add_theme_stylebox_override("fill", UI.box(col, 2))
		lbl.modulate = Color(1, 1, 1, 0.45) if not m.alive() else Color.WHITE
	squad_box.visible = mates.size() > 1


func refresh_inventory() -> void:
	var f: Fighter = game.local
	if f == null:
		return
	for i in 2:
		var b: Button = slots[i]
		var w: Dictionary = f.inv.weapons[i]
		if w.is_empty():
			b.text = "EMPTY"
			b.modulate = Color(1, 1, 1, 0.5)
		else:
			var s := GameData.stats(w)
			var kind := String(s["ammo"])
			b.text = "%s  %d/%d" % [String(GameData.weapon(String(w["id"]))["name"]).to_upper(), int(w["mag"]), int(f.inv.ammo[kind])]
			b.modulate = Color.WHITE
		var active := i == f.inv.active
		var rcol: Color = GameData.rarity_of(w)["color"] if not w.is_empty() else Color(1, 1, 1, 0.3)
		var sb := UI.box(Color(0.95, 0.75, 0.1, 0.85) if active else Color(0, 0, 0, 0.5), 6, rcol, 2)
		sb.border_width_bottom = 5
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color("111418") if active else UI.TEXT)
	var sel := f.inv.throw_sel
	var n_sel := f.inv.throw_count(sel)
	nade_btn.badge = str(n_sel) if n_sel > 0 else ""
	nade_btn.modulate.a = 1.0 if n_sel > 0 else 0.4
	nade_btn.text = String(GameData.THROWABLES[sel]["short"])
	nade_btn.color = Color(GameData.THROWABLES[sel]["color"], 0.45)
	nade_cycle.text = "⇄"
	nade_cycle.visible = nade_cycle.visible and f.inv.throw_count() > n_sel
	nade_cycle.queue_redraw()
	var heals := int(f.inv.heals["bandage"]) + int(f.inv.heals["medkit"]) + int(f.inv.heals["drink"])
	heal_btn.badge = str(heals) if heals > 0 else ""
	heal_btn.modulate.a = 1.0 if heals > 0 else 0.4
	for c in heal_menu.get_children():
		var kind := String(c.name)
		var tb := c as TouchButton
		tb.badge = str(int(f.inv.heals[kind]))
		tb.modulate.a = 1.0 if int(f.inv.heals[kind]) > 0 else 0.35
		tb.queue_redraw()
	nade_btn.queue_redraw()
	heal_btn.queue_redraw()


# --- Feedback ------------------------------------------------------------------------

func toast(text: String, color: Color = Color.WHITE) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	var tw := toast_label.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func hit_marker(dmg: float, head: bool, outcome: String) -> void:
	_marker_t = 0.18 if outcome == "hit" else 0.45
	_marker_kill = outcome != "hit"
	Sfx.play("hit", 1.4 if head else 1.0)
	if outcome == "kill":
		Sfx.play("kill")
		toast("ELIMINATED", UI.RED)
		Sfx.vibrate(40)
		_streak = _streak + 1 if _streak_t > 0.0 else 1
		_streak_t = 6.0
		if _streak >= 2:
			show_banner(["", "", "DOUBLE KILL", "TRIPLE KILL", "QUAD KILL", "RAMPAGE"][mini(_streak, 5)])
	elif outcome == "knock":
		Sfx.play("knock")
		toast("KNOCKED DOWN", UI.ORANGE)
	_hits.append({"dmg": dmg, "head": head, "t": 0.6})


func hurt(dmg: float, dir, cause: String) -> void:
	if cause == "zone":
		_hurts.append({"dir": Vector3.ZERO, "t": 0.6, "zone": true})
	else:
		_hurts.append({"dir": dir as Vector3, "t": 1.2, "zone": false})
		Sfx.play("hurt", 1.0, -6.0)
		Sfx.vibrate(20)
	shake(minf(0.4, dmg / 60.0))


func shake(a: float) -> void:
	_shake = maxf(_shake, a)
	if game.rig != null:
		game.rig.shake(a)


func feed(data: Array) -> void:
	var killer := String(data[0])
	var victim := String(data[1])
	var cause := String(data[2])
	var what := String(data[3])
	var my_team: int = game.local.team if game.local != null else -99
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_END
	var kc := UI.GREEN if int(data[4]) == my_team else UI.TEXT
	var vc := UI.GREEN if int(data[5]) == my_team else UI.TEXT
	if killer != "":
		row.add_child(UI.label(killer, 20, kc))
	var how := "knocked" if what == "knock" else "eliminated"
	var tool := String(GameData.WEAPONS[cause]["name"]) if GameData.WEAPONS.has(cause) else cause
	row.add_child(UI.label("[%s] %s" % [tool, how] if killer != "" else how + " by " + cause, 18, UI.MUTED))
	row.add_child(UI.label(victim, 20, vc))
	feed_box.add_child(row)
	while feed_box.get_child_count() > 5:
		feed_box.get_child(0).queue_free()
		feed_box.remove_child(feed_box.get_child(0))
	var tw := row.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.6)
	tw.tween_callback(row.queue_free)


func show_banner(text: String, color: Color = UI.ACCENT) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	banner.scale = Vector2(1.3, 1.3)
	banner.pivot_offset = banner.size / 2
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	Sfx.play("levelup", 1.2)


func team_out(place: int) -> void:
	show_banner("SQUAD ELIMINATED  ·  #%d" % place, UI.RED)


func revive_started(by_id: int, target_id: int, t: float) -> void:
	_revive = {"by": by_id, "target": target_id, "t0": game.clock, "len": t}


func revive_ended(_by_id: int, target_id: int, ok: bool) -> void:
	_revive = {}
	if ok and game.local != null and target_id == game.local.id:
		toast("REVIVED!", UI.GREEN)


# --- Results -----------------------------------------------------------------------------

func show_results(res: Dictionary) -> void:
	if results_panel != null:
		return
	var f: Fighter = game.local
	var place := 1
	var my_kills := 0
	var my_dmg := 0
	for r in res["rows"]:
		if f != null and int(r["id"]) == f.id:
			place = int(r["place"])
			my_kills = int(r["kills"])
			my_dmg = int(r["dmg"])
	var reward := {"coins": 0, "xp": 0}
	if not _recorded and not game.autopilot:
		_recorded = true
		reward = Save.record(place, my_kills, int(res["teams"]))
	results_panel = UI.dim(0.72)
	root.add_child(results_panel)
	results_reposition()
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_panel.add_child(v)
	var title := "LAST SQUAD STANDING" if place == 1 and res["mode"] == "squad" else ("LAST ONE STANDING" if place == 1 else "#%d  WELL FOUGHT" % place)
	var t := UI.heading(title, 56 if place == 1 else 46, UI.ACCENT if place == 1 else UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("PLACED #%d OF %d   ·   %d KILLS   ·   %d DAMAGE" % [place, int(res["teams"]), my_kills, my_dmg], 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if int(reward["coins"]) > 0:
		var rw := UI.label("+%d COINS   +%d XP" % [int(reward["coins"]), int(reward["xp"])], 30, UI.ACCENT)
		rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rw)
	# Top of the table.
	var table := UI.panel()
	table.custom_minimum_size = Vector2(560, 0)
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tv := UI.vbox(4)
	var shown := 0
	for r in res["rows"]:
		if shown >= 6:
			break
		var row := UI.hbox(12)
		var col := UI.GREEN if f != null and int(r["team"]) == f.team else UI.TEXT
		var a := UI.label("#%d" % int(r["place"]), 24, UI.ACCENT)
		a.custom_minimum_size.x = 50
		row.add_child(a)
		var n := UI.label(String(r["name"]), 24, col)
		n.custom_minimum_size.x = 250
		row.add_child(n)
		row.add_child(UI.label("%d kills" % int(r["kills"]), 22, UI.MUTED))
		tv.add_child(row)
		shown += 1
	table.add_child(tv)
	v.add_child(table)
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if not game.networked:
		var again := UI.button("PLAY AGAIN", UI.ACCENT, Vector2(240, 64))
		again.pressed.connect(func() -> void: game.exit_requested.emit(true))
		h.add_child(again)
	var lobby := UI.ghost("LOBBY" if not game.networked else "LEAVE SERVER", Vector2(220, 64))
	lobby.pressed.connect(func() -> void: game.exit_requested.emit(false))
	h.add_child(lobby)
	if game.networked:
		var wait := UI.label("Next match starts soon...", 24, UI.MUTED)
		h.add_child(wait)
	v.add_child(h)
	UI.pop(v, 0.85)
	if place == 1:
		Sfx.play("levelup")


func _make_bigmap() -> Control:
	var d := UI.dim(0.78)
	var m := MapView.new()
	m.game = game
	m.full = true
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(m)
	d.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			_toggle_map())
	return d


## The crosshair, hit markers, damage arrows, scope and progress rings.
class Overlay:
	extends Control
	var hud

	func _draw() -> void:
		var game = hud.game
		var f: Fighter = game.local
		if f == null:
			return
		var s := size
		var c := s / 2
		var z: float = game.rig.zoom()
		# Scope view.
		if z >= 2.0:
			var r := s.y * 0.46
			draw_rect(Rect2(Vector2.ZERO, Vector2(c.x - r, s.y)), Color.BLACK)
			draw_rect(Rect2(Vector2(c.x + r, 0), Vector2(s.x - c.x - r, s.y)), Color.BLACK)
			for i in 48:
				var a0 := TAU * i / 48
				var a1 := TAU * (i + 1) / 48
				var pts := PackedVector2Array([c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r,
					c + Vector2.from_angle(a1) * r * 2.0, c + Vector2.from_angle(a0) * r * 2.0])
				draw_colored_polygon(pts, Color.BLACK)
			draw_arc(c, r, 0, TAU, 64, Color(0.05, 0.05, 0.05), 6.0, true)
			draw_line(c - Vector2(r, 0), c - Vector2(8, 0), Color(0, 0, 0, 0.9), 2.0)
			draw_line(c + Vector2(8, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 2.0)
			draw_line(c - Vector2(0, r), c - Vector2(0, 8), Color(0, 0, 0, 0.9), 2.0)
			draw_line(c + Vector2(0, 8), c + Vector2(0, r), Color(0, 0, 0, 0.9), 2.0)
			draw_circle(c, 2.5, Color(1, 0.15, 0.15))
		elif f.state == "ground" and f.inv.has_weapon() and f.alive():
			var w := f.inv.current()
			var st := GameData.stats(w)
			var spread := float(st["ads"]) if f.aiming else float(st["hip"])
			spread *= 1.0 + f.bloom
			var gap := 6.0 + spread * 9.0
			var col := Color(1, 1, 1, 0.9)
			if f.aiming and z > 1.0:
				draw_circle(c, 3.0, Color(1, 0.2, 0.2))
			else:
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_line(c + d * gap, c + d * (gap + 10), Color(0, 0, 0, 0.5), 4.0)
					draw_line(c + d * gap, c + d * (gap + 10), col, 2.0)
				draw_circle(c, 1.6, col)
		# Hit marker.
		if hud._marker_t > 0.0:
			var mc := Color(1, 0.25, 0.2) if hud._marker_kill else Color.WHITE
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 8, c + d * 18, mc, 3.0)
		# Damage numbers.
		for h in hud._hits.duplicate():
			h["t"] = float(h["t"]) - get_process_delta_time()
			if float(h["t"]) <= 0.0:
				hud._hits.erase(h)
				continue
			var k: float = 1.0 - float(h["t"]) / 0.6
			var txt := str(int(round(float(h["dmg"]))))
			var fc := UI.ACCENT if bool(h["head"]) else Color.WHITE
			draw_string_outline(UI.bold(), c + Vector2(26, -20 - k * 40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 5, Color(0, 0, 0, 0.7))
			draw_string(UI.bold(), c + Vector2(26, -20 - k * 40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, fc)
		# Where damage came from.
		var cam: Camera3D = game.rig.cam
		for h in hud._hurts:
			var a := float(h["t"])
			if bool(h["zone"]):
				draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.4, 1.0, 0.18 * a))
				continue
			var dir: Vector3 = -(h["dir"] as Vector3)
			var fwd := -cam.global_basis.z
			var ang := atan2(dir.x, dir.z) - atan2(fwd.x, fwd.z)
			var p := c + Vector2(-sin(ang), -cos(ang)) * minf(s.y * 0.32, 220.0)
			draw_arc(c, minf(s.y * 0.32, 220.0), -PI / 2 - ang - 0.25, -PI / 2 - ang + 0.25, 16, Color(1, 0.15, 0.1, 0.85 * minf(a, 1.0)), 8.0, true)
			draw_circle(p, 4.0, Color(1, 0.2, 0.1, 0.7 * minf(a, 1.0)))
		# Low health or knocked: red edges.
		if f.alive() and (f.hp < 30.0 or f.state == "knocked"):
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.8, 0.0, 0.0, 0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.008)))
		# Health, armour and boost at the bottom.
		if f.alive() and f.state != "plane":
			var bw := 340.0
			var bp := Vector2(c.x - bw / 2, s.y - 108)
			draw_rect(Rect2(bp, Vector2(bw, 14)), Color(0, 0, 0, 0.55))
			var hp := f.hp if f.state != "knocked" else f.bleed
			var hc := Color("e8edf2") if f.state != "knocked" else Color("ec4a3c")
			if hp < 30 and f.state != "knocked":
				hc = Color("ec4a3c")
			draw_rect(Rect2(bp, Vector2(bw * clampf(hp / 100.0, 0.0, 1.0), 14)), hc)
			if f.boost > 0.0:
				draw_rect(Rect2(bp + Vector2(0, -6), Vector2(bw * f.boost / 100.0, 4)), Color("ffc21a"))
			var ap := bp + Vector2(-70, -4)
			for i in 2:
				var lvl: int = f.inv.vest if i == 0 else f.inv.helmet
				var col2: Color = [Color(1, 1, 1, 0.25), Color("c0c8d0"), Color("3aa4ff"), Color("ffc21a")][clampi(lvl, 0, 3)]
				var r2 := Rect2(ap + Vector2(i * 32, 0), Vector2(28, 22))
				draw_rect(r2, Color(0, 0, 0, 0.5))
				draw_string(UI.bold(), r2.position + Vector2(4, 19), ("V" if i == 0 else "H") + str(lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col2)
		# Heal / revive progress.
		var prog := -1.0
		var label := ""
		if f.heal_t > 0.0 and GameData.HEALS.has(f.heal_kind):
			var total := float(GameData.HEALS[f.heal_kind]["time"])
			prog = 1.0 - f.heal_t / total
			label = String(GameData.HEALS[f.heal_kind]["name"])
		if not hud._revive.is_empty() and (int(hud._revive["by"]) == f.id or int(hud._revive["target"]) == f.id):
			prog = (game.clock - float(hud._revive["t0"])) / float(hud._revive["len"])
			label = "Reviving"
		if prog >= 0.0:
			draw_arc(c + Vector2(0, 90), 34, -PI / 2, -PI / 2 + TAU * clampf(prog, 0.0, 1.0), 40, UI.ACCENT, 7.0, true)
			var w2 := UI.bold().get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
			draw_string(UI.bold(), c + Vector2(-w2 / 2, 146), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		# Compass.
		var heading := fposmod(rad_to_deg(-f.yaw) + 180.0, 360.0)
		var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
		var cx := c.x
		for deg in range(-60, 61, 15):
			var hd := int(fposmod(round((heading + deg) / 15.0) * 15.0, 360.0))
			var off: float = (round((heading + deg) / 15.0) * 15.0 - heading) * 3.2
			var x: float = cx + off
			if names.has(hd):
				var t: String = names[hd]
				var tw := UI.bold().get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
				draw_string(UI.bold(), Vector2(x - tw / 2, 36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.ACCENT if hd == 0 else Color.WHITE)
			else:
				draw_line(Vector2(x, 18), Vector2(x, 28), Color(1, 1, 1, 0.6), 2.0)
		draw_line(Vector2(cx, 40), Vector2(cx, 48), UI.ACCENT, 3.0)
