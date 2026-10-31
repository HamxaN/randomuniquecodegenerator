class_name WorldMap
extends Node3D
## The main menu: your hopper on a floating island among the clouds, the level
## grid for the four worlds, and the skin shop.

signal play_requested(level_n: int)

var _ui: Control
var _panel: Control
var _coins: Label
var _camera: Camera3D
var _hero: Node3D
var _t := 0.0


func _ready() -> void:
	_build_scene()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_build_ui()
	Save.changed.connect(func() -> void: _coins.text = UI.fmt(Save.coins))
	Ads.show_banner()


func _process(delta: float) -> void:
	_t += delta
	_camera.position = Vector3(sin(_t * 0.15) * 9.0, 5.0, cos(_t * 0.15) * 9.0)
	_camera.look_at(Vector3(0, 0.6, 0))
	if _hero != null:
		_hero.position.y = 0.55 + absf(sin(_t * 3.0)) * 0.5


func _build_scene() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.6, 0.95)
	sm.sky_horizon_color = Color(0.85, 0.93, 1.0)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true
	var island := Models.kit("platform-grass-large-round")
	island.scale = Vector3.ONE * 1.4
	add_child(island)
	for i in 6:
		var g := Models.kit("grass")
		add_child(g)
		g.position = Vector3(cos(i * 1.1) * 2.4, 0.7, sin(i * 1.1) * 2.4)
	var tree := Models.prop("res://assets/decor/tree_single_A.gltf")
	tree.scale = Vector3.ONE * 2.2
	tree.position = Vector3(-2.2, 0.7, -1.2)
	add_child(tree)
	var flag := Models.kit("flag")
	flag.scale = Vector3.ONE * 2.0
	flag.position = Vector3(2.0, 0.7, -1.4)
	add_child(flag)
	var coin := Models.kit("coin")
	coin.scale = Vector3.ONE * 2.0
	coin.position = Vector3(0.8, 2.0, 1.4)
	add_child(coin)
	_hero = Models.kit("character")
	_hero.scale = Vector3.ONE * 1.8
	add_child(_hero)
	var ap := Models.animation_player(_hero)
	if ap != null and ap.has_animation("jump"):
		ap.play("jump")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var c := Models.kit("cloud")
		add_child(c)
		c.position = Vector3(rng.randf_range(-16, 16), rng.randf_range(-6, 6), rng.randf_range(-16, 16))
		if c.position.length() < 6.0:
			c.position = c.position.normalized() * 8.0
		c.scale = Vector3.ONE * rng.randf_range(2.0, 4.0)


func _build_ui() -> void:
	var logo := UI.label("SKY HOP", 76, UI.GOLD)
	logo.position = Vector2(28, 6)
	_ui.add_child(logo)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_left = -290
	holder.offset_top = 12
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var col := UI.vbox(4)
	holder.add_child(col)
	var cb := UI.resource_bar("gold", UI.GOLD, 230.0)
	_coins = cb.get_node("Amount") as Label
	_coins.text = UI.fmt(Save.coins)
	(cb.get_node("Bar") as ProgressBar).value = 100
	col.add_child(cb)
	var sb := UI.resource_bar("star", UI.ORANGE, 230.0)
	(sb.get_node("Amount") as Label).text = "%d / %d" % [Save.total_stars(), GameData.level_count() * 3]
	(sb.get_node("Bar") as ProgressBar).max_value = GameData.level_count() * 3
	(sb.get_node("Bar") as ProgressBar).value = Save.total_stars()
	col.add_child(sb)
	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24
	bottom.offset_top = -110
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bottom)
	var row := UI.hbox(14)
	bottom.add_child(row)
	var play := UI.button("Play level %d" % Save.unlocked(), UI.GREEN, Vector2(340, 90), 40)
	play.pressed.connect(func() -> void: play_requested.emit(Save.unlocked()))
	row.add_child(play)
	var levels := UI.button("Levels", UI.BLUE, Vector2(200, 90), 34)
	levels.pressed.connect(open_levels)
	row.add_child(levels)
	var skins := UI.button("Skins", UI.PURPLE, Vector2(180, 90), 34)
	skins.pressed.connect(open_skins)
	row.add_child(skins)


func _open_panel(title: String, width: float) -> VBoxContainer:
	close_panel()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)
	_panel.add_child(UI.dim(0.45))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var frame := UI.panel()
	frame.custom_minimum_size = Vector2(width, 0)
	center.add_child(frame)
	var col := UI.vbox(10)
	frame.add_child(col)
	var head := UI.hbox(10)
	col.add_child(head)
	var t := UI.label(title, 42)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.flat = true
	close.custom_minimum_size = Vector2(60, 60)
	close.add_child(UI.icon("close", 56))
	close.pressed.connect(close_panel)
	head.add_child(close)
	UI.pop(frame, 0.85)
	return col


func close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null


func open_levels() -> void:
	var col := _open_panel("Levels", 1080)
	var open_to := Save.unlocked()
	for w in GameData.WORLDS.size():
		var world: Dictionary = GameData.WORLDS[w]
		var row := UI.hbox(10)
		col.add_child(row)
		var name_label := UI.ink(world["name"], 26)
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)
		for i in GameData.LEVELS_PER_WORLD:
			var n := w * GameData.LEVELS_PER_WORLD + i + 1
			var open := n <= open_to
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 84)
			b.focus_mode = Control.FOCUS_NONE
			var color: Color = (world["sky_top"] as Color).lightened(0.15) if open else UI.GREY
			var st := UI.box(color, 16, color.darkened(0.5), 3)
			st.border_width_bottom = 7
			for s in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(s, st)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			var num := UI.label(str(n), 32)
			num.position = Vector2(12, 4)
			b.add_child(num)
			var srow := UI.hbox(0)
			srow.position = Vector2(56, 42)
			for k in 3:
				srow.add_child(UI.icon("star" if k < Save.level_stars(n) else "star_empty", 28))
			b.add_child(srow)
			if not open:
				var lock := UI.icon("lock", 34)
				lock.position = Vector2(100, 4)
				b.add_child(lock)
			b.pressed.connect(func() -> void:
				if open:
					close_panel()
					play_requested.emit(n)
				else:
					Sfx.play("deny"))
			row.add_child(b)


func open_skins() -> void:
	var col := _open_panel("Skins", 1040)
	var row := UI.hbox(10)
	col.add_child(row)
	for s in GameData.SKINS:
		var owned := Save.owned.has(s["id"])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card_style((s["color"] as Color).lerp(UI.PARCHMENT_DARK, 0.4)))
		var v := UI.vbox(6)
		card.add_child(v)
		var sw := ColorRect.new()
		sw.color = s["color"]
		sw.custom_minimum_size = Vector2(130, 80)
		v.add_child(sw)
		v.add_child(UI.label(s["name"], 26))
		var id: String = s["id"]
		var b: Button
		if Save.skin == id:
			b = UI.button("On", UI.GREY, Vector2(130, 56), 24)
			b.disabled = true
		elif owned:
			b = UI.button("Wear", UI.GREEN, Vector2(130, 56), 24)
		else:
			b = UI.button("%d" % int(s["cost"]), UI.ORANGE, Vector2(130, 56), 24)
		b.pressed.connect(func() -> void:
			if Save.buy_skin(id):
				Sfx.play("buy")
				open_skins()
			else:
				Sfx.play("deny"))
		v.add_child(b)
		row.add_child(card)
