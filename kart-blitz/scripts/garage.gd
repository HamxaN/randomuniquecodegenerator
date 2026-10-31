class_name Garage
extends Node3D
## The main menu: your kart spinning on a showroom stand, with kart and upgrade
## shops and a track picker with little maps, and the big RACE! button.

signal race_requested(track: int)

var _ui: Control
var _panel: Control
var _coins: Label
var _trophies: Label
var _kart_name: Label
var _kart_stats: Control
var _track_name: Label
var _track_best: Label
var _track_map: Control
var _race: Button
var _lock: Label
var _stand: Node3D
var _kart_node: Node3D
var _camera: Camera3D
var _t := 0.0


func _ready() -> void:
	_build_stage()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_build_top()
	_build_kart_panel()
	_build_track_panel()
	Save.changed.connect(_refresh)
	_refresh()
	Ads.show_banner()


func _process(delta: float) -> void:
	_t += delta
	_stand.rotation.y += delta * 0.5
	_camera.position = Vector3(sin(_t * 0.15) * 0.4, 3.0, 8.5)
	_camera.look_at(Vector3(0, 0.8, 0))


func _build_stage() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.55, 0.92)
	sm.sky_horizon_color = Color(0.85, 0.93, 1.0)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.material_override = Models.material(Color(0.45, 0.72, 0.36))
	add_child(ground)
	# A chequered showroom floor and a turntable.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-6, 6):
		for z in range(-6, 6):
			var a := Vector3(x * 1.5, 0.01, z * 1.5)
			st.set_color(Color(0.95, 0.95, 0.95) if (x + z) % 2 == 0 else Color(0.15, 0.15, 0.17))
			st.set_normal(Vector3.UP)
			for v in [a, a + Vector3(1.5, 0, 0), a + Vector3(0, 0, 1.5), a + Vector3(1.5, 0, 0), a + Vector3(1.5, 0, 1.5), a + Vector3(0, 0, 1.5)]:
				st.add_vertex(v)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = st.commit()
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.3
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	_stand = Node3D.new()
	add_child(_stand)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.4
	cyl.height = 0.3
	disc.mesh = cyl
	disc.material_override = Models.material(Color(0.95, 0.75, 0.2))
	disc.position.y = 0.15
	_stand.add_child(disc)
	var arch := Models.kit("track-finish")
	add_child(arch)
	arch.position = Vector3(0, 0, -5.5)
	arch.scale = Vector3.ONE * 0.9
	for i in 8:
		var tree := Models.prop("res://assets/decor/%s.gltf" % ["trees_A_large", "trees_B_large"][i % 2])
		add_child(tree)
		tree.position = Vector3(-24 + i * 7, 0, -18 - (i % 3) * 3)
		tree.scale = Vector3.ONE * 5.0
	_rebuild_kart()


func _rebuild_kart() -> void:
	if _kart_node != null:
		_kart_node.queue_free()
	_kart_node = Models.kit(GameData.kart(Save.kart)["model"])
	_kart_node.scale = Vector3.ONE * 2.0
	_kart_node.position.y = 0.3
	_stand.add_child(_kart_node)


# ---------------------------------------------------------------- UI

func _build_top() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var logo := UI.label("KART BLITZ", 64, UI.GOLD)
	logo.position = Vector2(24, 8)
	holder.add_child(logo)
	var right := Control.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -290
	right.offset_top = 12
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(right)
	var col := UI.vbox(4)
	right.add_child(col)
	var c := UI.resource_bar("gold", UI.GOLD, 230.0)
	_coins = c.get_node("Amount") as Label
	(c.get_node("Bar") as ProgressBar).value = 100
	col.add_child(c)
	var t := UI.resource_bar("trophy", UI.ORANGE, 230.0)
	_trophies = t.get_node("Amount") as Label
	(t.get_node("Bar") as ProgressBar).value = 100
	col.add_child(t)


func _build_kart_panel() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = 24
	holder.offset_top = -300
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(380, 0)
	holder.add_child(p)
	var col := UI.vbox(8)
	p.add_child(col)
	var row := UI.hbox(8)
	col.add_child(row)
	var prev := UI.button("<", UI.BLUE, Vector2(56, 56), 30)
	prev.pressed.connect(func() -> void: _cycle_kart(-1))
	row.add_child(prev)
	_kart_name = UI.label("", 32)
	_kart_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kart_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_kart_name)
	var next := UI.button(">", UI.BLUE, Vector2(56, 56), 30)
	next.pressed.connect(func() -> void: _cycle_kart(1))
	row.add_child(next)
	_kart_stats = UI.vbox(4)
	col.add_child(_kart_stats)
	var buttons := UI.hbox(8)
	col.add_child(buttons)
	var up := UI.button("Upgrades", UI.ORANGE, Vector2(170, 60), 26)
	up.pressed.connect(open_upgrades)
	buttons.add_child(up)
	var settings_button := UI.button("Settings", Color(0.5, 0.52, 0.56), Vector2(170, 60), 26)
	settings_button.pressed.connect(open_settings)
	buttons.add_child(settings_button)


func _build_track_panel() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -420
	holder.offset_top = -360
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(400, 0)
	holder.add_child(p)
	var col := UI.vbox(6)
	p.add_child(col)
	var row := UI.hbox(8)
	col.add_child(row)
	var prev := UI.button("<", UI.BLUE, Vector2(56, 56), 30)
	prev.pressed.connect(func() -> void: _cycle_track(-1))
	row.add_child(prev)
	_track_name = UI.ink("", 30)
	_track_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_track_name)
	var next := UI.button(">", UI.BLUE, Vector2(56, 56), 30)
	next.pressed.connect(func() -> void: _cycle_track(1))
	row.add_child(next)
	_track_map = Control.new()
	_track_map.custom_minimum_size = Vector2(350, 120)
	_track_map.draw.connect(_draw_track_map)
	col.add_child(_track_map)
	_track_best = UI.ink("", 22)
	col.add_child(_track_best)
	_lock = UI.ink("", 22)
	col.add_child(_lock)
	_race = UI.button("RACE!", UI.GREEN, Vector2(400, 96), 52)
	_race.pressed.connect(func() -> void:
		Sfx.play("go")
		race_requested.emit(Save.track_index))
	var rh := Control.new()
	rh.custom_minimum_size = Vector2(400, 100)
	rh.add_child(_race)
	col.add_child(rh)


func _cycle_kart(step: int) -> void:
	var ids: Array = []
	for k in GameData.KARTS:
		ids.append(k["id"])
	var i := (ids.find(Save.kart) + step + ids.size()) % ids.size()
	var id: String = ids[i]
	if Save.owned.has(id):
		Save.kart = id
		Save.store()
	else:
		_show_buy(id)
	_preview(id)


func _preview(id: String) -> void:
	if _kart_node != null:
		_kart_node.queue_free()
	_kart_node = Models.kit(GameData.kart(id)["model"])
	_kart_node.scale = Vector3.ONE * 2.0
	_kart_node.position.y = 0.3
	_stand.add_child(_kart_node)
	_show_stats(id)


func _show_buy(id: String) -> void:
	var k := GameData.kart(id)
	_open_panel("%s" % k["name"], 520).add_child(_buy_body(id, k))


func _buy_body(id: String, k: Dictionary) -> Control:
	var col := UI.vbox(10)
	col.add_child(UI.ink("Top speed %d km/h  ·  Grip %.1f" % [int(float(k["speed"]) * 3.6), float(k["grip"])], 24))
	var b := UI.button("Buy for %s" % UI.fmt(int(k["cost"])), UI.GREEN, Vector2(400, 76), 32)
	b.pressed.connect(func() -> void:
		if Save.buy_kart(id):
			Sfx.play("buy")
			close_panel()
			_rebuild_kart()
		else:
			Sfx.play("error"))
	col.add_child(b)
	return col


func _cycle_track(step: int) -> void:
	Save.track_index = posmod(Save.track_index + step, GameData.TRACKS.size())
	Save.store()


func _show_stats(id: String) -> void:
	for c in _kart_stats.get_children():
		c.queue_free()
	var k := GameData.kart(id)
	_kart_name.text = k["name"]
	for spec in [["Speed", float(k["speed"]) / 36.0, UI.RED], ["Accel", float(k["accel"]) / 21.0, UI.GOLD], ["Grip", float(k["grip"]) / 2.6, UI.BLUE]]:
		var row := UI.hbox(8)
		var l := UI.ink(spec[0], 22)
		l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		var bar := UI.bar(spec[2], Vector2(260, 16))
		bar.max_value = 1.0
		bar.value = spec[1]
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_kart_stats.add_child(row)
	if not Save.owned.has(id):
		_kart_stats.add_child(UI.ink("Locked: %s coins" % UI.fmt(int(k["cost"])), 22))


func _refresh() -> void:
	_coins.text = UI.fmt(Save.coins)
	_trophies.text = "%d wins" % Save.wins
	_show_stats(Save.kart)
	var t := GameData.track(Save.track_index)
	_track_name.text = t["name"]
	var bp := Save.best_place(Save.track_index)
	_track_best.text = "Best finish: %s" % (["1st", "2nd", "3rd", "4th", "5th", "6th"][bp - 1] if bp > 0 else "-")
	var open := Save.track_index < Save.unlocked
	_race.disabled = not open
	_lock.text = "" if open else "Finish top 3 on the previous track to unlock"
	_track_map.queue_redraw()


func _draw_track_map() -> void:
	var pts: Array = GameData.track(Save.track_index)["points"]
	var samples := GameData.sample_track(pts, 4.0)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in samples:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	var area := _track_map.size - Vector2(20, 20)
	var k := minf(area.x / (mx.x - mn.x), area.y / (mx.y - mn.y))
	var origin := Vector2(10, 10) + (area - (mx - mn) * k) / 2
	var line := PackedVector2Array()
	for p in samples:
		line.append(origin + (Vector2(p.x, p.z) - mn) * k)
	line.append(line[0])
	_track_map.draw_polyline(line, Color(0.25, 0.2, 0.15), 10.0, true)
	_track_map.draw_polyline(line, Color(0.95, 0.95, 0.92), 5.0, true)
	_track_map.draw_circle(line[0], 7.0, UI.RED)


func _open_panel(title: String, width: float) -> VBoxContainer:
	close_panel()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)
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
	var t := UI.label(title, 40)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(60, 60)
	close.add_child(UI.icon("close", 56))
	close.pressed.connect(func() -> void:
		close_panel()
		_rebuild_kart())
	head.add_child(close)
	UI.pop(frame, 0.85)
	return col


func close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_refresh()


func open_upgrades() -> void:
	var col := _open_panel("Upgrades", 760)
	for u in GameData.UPGRADES:
		var lv := Save.upgrade(u["id"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.card_style())
		var h := UI.hbox(14)
		row.add_child(h)
		h.add_child(UI.icon(u["icon"], 54))
		var info := UI.vbox(0)
		info.custom_minimum_size = Vector2(330, 0)
		info.add_child(UI.label("%s  Lv %d/%d" % [u["name"], lv, GameData.MAX_UPGRADE], 28))
		info.add_child(UI.ink(u["desc"], 22))
		h.add_child(info)
		var id: String = u["id"]
		if lv < GameData.MAX_UPGRADE:
			var b := UI.button("%s" % UI.fmt(GameData.upgrade_cost(lv)), UI.GREEN, Vector2(200, 62), 28)
			b.pressed.connect(func() -> void:
				if Save.buy_upgrade(id):
					Sfx.play("buy")
					open_upgrades()
				else:
					Sfx.play("error"))
			h.add_child(b)
		else:
			h.add_child(UI.label("MAX", 32, UI.GOLD))
		col.add_child(row)


func open_settings() -> void:
	var col := _open_panel("Settings", 520)
	var sound := UI.button("Sound: %s" % ("On" if Save.sound else "Off"), UI.BLUE, Vector2(440, 66), 28)
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "Sound: %s" % ("On" if Save.sound else "Off"))
	col.add_child(sound)
	col.add_child(UI.ink("Races %d  ·  Wins %d" % [Save.races, Save.wins], 24))
	col.add_child(UI.ink("Karts and scenery: Kenney and KayKit (CC0).\nFont: Lilita One (SIL Open Font License).", 20))
