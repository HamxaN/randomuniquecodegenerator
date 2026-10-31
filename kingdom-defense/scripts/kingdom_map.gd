class_name KingdomMap
extends Node3D
## The main menu: your castle on its island behind a parchment map of the
## twelve battles, with stars won on each.

signal play_requested(level_n: int)

var _ui: Control
var _rig: CameraRig
var _t := 0.0


func _ready() -> void:
	var road := GameData.path(1)
	var road_set := {}
	for c in road:
		road_set[c] = true
	Island.build(self, 7, "grass", road_set)
	var castle := Models.building("castle", "blue")
	add_child(castle)
	castle.position = Hex.to_world(road[-1])
	for i in range(2, road.size() - 2, 3):
		var t := Models.building(["archer", "mage", "catapult"][(i / 3) % 3], "blue")
		add_child(t)
		t.position = Hex.to_world(road[i] + Hex.DIRS[(i + 1) % 6])
	_rig = CameraRig.new()
	add_child(_rig)
	_rig.distance = 21.0
	_rig.set_process_unhandled_input(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_build()
	Ads.show_banner()


func _process(delta: float) -> void:
	_t += delta
	_rig.yaw = _t * 0.05


func _build() -> void:
	var logo := UI.label("KINGDOM DEFENSE", 64, UI.GOLD)
	logo.position = Vector2(28, 10)
	_ui.add_child(logo)
	var stars_holder := Control.new()
	stars_holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stars_holder.offset_left = -260
	stars_holder.offset_top = 16
	stars_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(stars_holder)
	var sr := UI.resource_bar("star", UI.GOLD, 200.0)
	(sr.get_node("Amount") as Label).text = "%d / %d" % [Save.total_stars(), GameData.LEVELS * 3]
	(sr.get_node("Bar") as ProgressBar).max_value = GameData.LEVELS * 3
	(sr.get_node("Bar") as ProgressBar).value = Save.total_stars()
	stars_holder.add_child(sr)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 70
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	var panel := UI.panel()
	center.add_child(panel)
	var col := UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.ink("Choose a battle", 30))
	var map := Control.new()
	map.custom_minimum_size = Vector2(1040, 360)
	col.add_child(map)
	var points: Array[Vector2] = []
	for i in GameData.LEVELS:
		var row := i / 4
		var c := i % 4
		points.append(Vector2(110.0 + (c if row % 2 == 0 else 3 - c) * 270.0, 60.0 + row * 120.0))
	map.draw.connect(func() -> void:
		map.draw_rect(Rect2(Vector2.ZERO, map.custom_minimum_size), Color("d9c48e"))
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var steps := int(a.distance_to(b) / 18.0)
			for s in steps:
				if s % 2 == 0:
					map.draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), Color("8b5a2b"), 5.0))
	var open_to := Save.unlocked()
	for i in GameData.LEVELS:
		var n := i + 1
		var open := n <= open_to
		var got := Save.level_stars(n)
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 90)
		b.size = b.custom_minimum_size
		b.position = points[i] - Vector2(45, 45)
		b.focus_mode = Control.FOCUS_NONE
		var theme_col: Color = {"grass": UI.GREEN, "sand": UI.ORANGE, "snow": UI.BLUE, "ash": UI.RED}[GameData.THEMES[i]]
		var color := theme_col if open else UI.GREY
		var st := UI.box(color, 45, color.darkened(0.55), 4)
		st.border_width_bottom = 8
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var num := UI.label(str(n), 36)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.size = Vector2(90, 70)
		b.add_child(num)
		var srow := UI.hbox(0)
		srow.position = Vector2(6, 66)
		for k in 3:
			srow.add_child(UI.icon("star" if k < got else "star_empty", 26))
		b.add_child(srow)
		var name_label := UI.ink(GameData.NAMES[i], 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(170, 24)
		name_label.position = Vector2(-40, 96)
		b.add_child(name_label)
		if not open:
			var lock := UI.icon("lock", 34)
			lock.position = Vector2(56, -12)
			b.add_child(lock)
		b.pressed.connect(func() -> void:
			if open:
				Sfx.play("horn")
				play_requested.emit(n)
			else:
				Sfx.play("deny"))
		map.add_child(b)
		if n == open_to and got == 0:
			b.pivot_offset = Vector2(45, 45)
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.45)
			tw.tween_property(b, "scale", Vector2.ONE, 0.45)
	var sound := UI.button("Sound: %s" % ("On" if Save.sound else "Off"), UI.BLUE, Vector2(220, 56), 24)
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "Sound: %s" % ("On" if Save.sound else "Off"))
	col.add_child(sound)
	UI.pop(panel, 0.9)
