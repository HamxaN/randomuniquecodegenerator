class_name HopHud
extends Control
## In-level HUD: coins, the three star slots, time and course progress at the
## top, the thumbstick and JUMP button, and the level-complete screen.

var level: Level
var _stick: Joystick
var _jump: HoldButton
var _coins: Label
var _time: Label
var _stars: Array[Icon] = []
var _progress: ProgressBar
var _toast: Label
var _modal: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stick = Joystick.new()
	_stick.anchor_right = 0.5
	_stick.anchor_top = 0.3
	_stick.anchor_bottom = 1.0
	add_child(_stick)
	var top := UI.hbox(24)
	top.position = Vector2(24, 14)
	add_child(top)
	var c := UI.hbox(6)
	c.add_child(UI.icon("gold", 46))
	_coins = UI.label("0", 44, UI.GOLD)
	c.add_child(_coins)
	top.add_child(c)
	var s := UI.hbox(2)
	for i in 3:
		var icon := UI.icon("star_empty", 46)
		s.add_child(icon)
		_stars.append(icon)
	top.add_child(s)
	_time = UI.label("0:00", 40)
	top.add_child(_time)
	var bar_holder := Control.new()
	bar_holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar_holder.offset_left = -170
	bar_holder.offset_top = 90
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_holder)
	_progress = UI.bar(UI.GREEN, Vector2(340, 18))
	_progress.max_value = 1.0
	bar_holder.add_child(_progress)
	var flag := UI.icon("flag", 34)
	flag.position = Vector2(344, -8)
	bar_holder.add_child(flag)
	var jump_holder := Control.new()
	jump_holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_holder.offset_left = -250
	jump_holder.offset_top = -250
	jump_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(jump_holder)
	_jump = HoldButton.new()
	_jump.icon_kind = "jump"
	_jump.caption = "JUMP"
	_jump.color = UI.ORANGE
	_jump.size = Vector2(200, 200)
	_jump.custom_minimum_size = _jump.size
	_jump.pressed.connect(func() -> void: level.player.jump())
	jump_holder.add_child(_jump)
	var pause_holder := Control.new()
	pause_holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_holder.offset_left = -90
	pause_holder.offset_top = 14
	add_child(pause_holder)
	var pause := UI.button("II", Color(0.5, 0.52, 0.56), Vector2(70, 64), 30)
	pause.pressed.connect(_pause)
	pause_holder.add_child(pause)
	_toast = UI.label("", 40, UI.GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 130
	_toast.modulate.a = 0.0
	add_child(_toast)
	if level.level_n == 1:
		toast("Move with the stick, tap JUMP (twice for a double jump)!")


func move_input() -> Vector2:
	var v := _stick.value
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	return v.limit_length(1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_SPACE:
		level.player.jump()


func _process(_delta: float) -> void:
	if level == null:
		return
	_coins.text = str(level.coins)
	var t := int(level.time)
	_time.text = "%d:%02d" % [t / 60, t % 60]
	_progress.value = level.progress()


func star_collected(count: int) -> void:
	var s := _stars[count - 1]
	s.kind = "star"
	s.pivot_offset = s.size / 2
	s.scale = Vector2(2.4, 2.4)
	s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast("STAR %d/3!" % count)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _box() -> VBoxContainer:
	if _modal != null:
		_modal.queue_free()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_modal.add_child(UI.dim(0.45))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col


func show_end(stars: int, reward: int) -> void:
	var col := _box()
	var title := UI.label("LEVEL COMPLETE!", 80, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in 3:
		var s := UI.icon("star" if i < stars else "star_empty", 110 if i == 1 else 88)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(s)
	var t := int(level.time)
	var info := UI.label("Time %d:%02d   ·   Coins %d   ·   Falls %d" % [t / 60, t % 60, level.coins, level.falls], 32)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(info)
	var rr := UI.hbox(8)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_child(UI.icon("gold", 50))
	var reward_label := UI.label("+%d" % reward, 50, UI.GOLD)
	rr.add_child(reward_label)
	col.add_child(rr)
	var buttons := UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var dbl := UI.button("   x2 Coins", UI.PURPLE, Vector2(250, 76), 30)
	var ad := UI.icon("ad", 34)
	ad.position = Vector2(16, 20)
	dbl.add_child(ad)
	dbl.pressed.connect(func() -> void:
		Ads.show_rewarded(func() -> void:
			Save.coins += reward
			Save.store()
			reward_label.text = "+%d" % (reward * 2)
			Sfx.play("coin")
			dbl.disabled = true))
	buttons.add_child(dbl)
	if level.level_n < GameData.level_count():
		var next := UI.button("Next level", UI.GREEN, Vector2(250, 76), 32)
		next.pressed.connect(func() -> void: level.exit_requested.emit(true))
		buttons.add_child(next)
	var map := UI.button("Map", UI.BLUE, Vector2(160, 76), 32)
	map.pressed.connect(func() -> void: level.exit_requested.emit(false))
	buttons.add_child(map)
	UI.pop(col, 0.8)


func _pause() -> void:
	get_tree().paused = true
	var col := _box()
	col.add_child(UI.label("Paused", 70))
	var resume := UI.button("Resume", UI.GREEN, Vector2(300, 76), 32)
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		_modal.queue_free()
		_modal = null)
	col.add_child(resume)
	var restart := UI.button("Restart", UI.ORANGE, Vector2(300, 70), 28)
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		level.player.global_position = level.course["checkpoints"][0]
		level.player.velocity = Vector3.ZERO
		_modal.queue_free()
		_modal = null)
	col.add_child(restart)
	var quit := UI.button("Map", UI.BLUE, Vector2(300, 70), 28)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		level.exit_requested.emit(false))
	col.add_child(quit)
