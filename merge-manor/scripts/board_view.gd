class_name BoardView
extends Control
## The merge board: a grid of tiles showing each item as a picture of its 3D
## model. Drag an item onto its twin to merge it, onto an empty tile to move
## it, or onto anything else to swap. Tap a generator to make a new item.

signal tapped_generator(index: int)
signal selected(index: int)
signal merged(index: int, id: String)

const CELL := 84.0
const GAP := 4.0

var board: BoardState
var thumbs: ThumbCache
var selection := -1
var _drag_from := -1
var _drag_pos := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _dragging := false
var _pops := {}     # cell -> time left of a merge pop
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(GameData.COLS * (CELL + GAP) + GAP, GameData.ROWS * (CELL + GAP) + GAP)
	size = custom_minimum_size
	thumbs.rendered.connect(func(_m: String) -> void: queue_redraw())


func cell_rect(i: int) -> Rect2:
	var c := i % GameData.COLS
	var r := i / GameData.COLS
	return Rect2(Vector2(GAP + c * (CELL + GAP), GAP + r * (CELL + GAP)), Vector2(CELL, CELL))


func cell_at(p: Vector2) -> int:
	var c := int((p.x - GAP) / (CELL + GAP))
	var r := int((p.y - GAP) / (CELL + GAP))
	if p.x < 0 or p.y < 0 or c < 0 or r < 0 or c >= GameData.COLS or r >= GameData.ROWS:
		return -1
	return r * GameData.COLS + c


func _process(delta: float) -> void:
	_t += delta
	for k in _pops.keys():
		_pops[k] = float(_pops[k]) - delta
		if float(_pops[k]) <= 0.0:
			_pops.erase(k)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var i := cell_at(t.position)
			if i >= 0 and board.at(i) != "":
				_drag_from = i
				_press_pos = t.position
				_drag_pos = t.position
				_dragging = false
			accept_event()
		else:
			if _drag_from >= 0:
				var to := cell_at(t.position)
				if _dragging and to >= 0 and to != _drag_from:
					drop(_drag_from, to)
				elif not _dragging:
					_tap(_drag_from)
			_drag_from = -1
			_dragging = false
			accept_event()
	elif event is InputEventScreenDrag and _drag_from >= 0:
		var d := event as InputEventScreenDrag
		_drag_pos = d.position
		if not _dragging and _drag_pos.distance_to(_press_pos) > 10.0 and not GameData.is_generator(board.at(_drag_from)):
			_dragging = true
		accept_event()


func _tap(i: int) -> void:
	if GameData.is_generator(board.at(i)):
		tapped_generator.emit(i)
	selection = i
	selected.emit(i)


## Drops the item at [param from] on [param to] (also used by the play-test).
func drop(from: int, to: int) -> String:
	var result := board.move(from, to)
	match result:
		"merge":
			_pops[to] = 0.35
			selection = to
			merged.emit(to, board.at(to))
			Sfx.play("merge", 1.0 + GameData.level_of(board.at(to)) * 0.06)
		"move", "swap":
			selection = to
			Sfx.play("place", 1.1, -4.0)
	selected.emit(selection)
	return result


func _draw() -> void:
	var bg := UI.box(Color(0.98, 0.94, 0.86, 0.94), 18, Color(0.55, 0.38, 0.22), 4)
	draw_style_box(bg, Rect2(Vector2(-6, -6), size + Vector2(12, 12)))
	var dragging_id := board.at(_drag_from) if _dragging else ""
	for i in board.cells.size():
		var r := cell_rect(i)
		var shade := Color(0.93, 0.86, 0.74) if (i % GameData.COLS + i / GameData.COLS) % 2 == 0 else Color(0.9, 0.82, 0.69)
		draw_style_box(UI.box(shade, 10), r)
		var id := board.at(i)
		if dragging_id != "" and i != _drag_from and GameData.can_merge(dragging_id, id):
			draw_style_box(UI.box(Color(0.5, 1.0, 0.5, 0.0), 10, Color(0.35, 0.85, 0.35, 0.6 + 0.4 * sin(_t * 8.0)), 4), r)
		if i == selection and id != "":
			draw_style_box(UI.box(Color(0, 0, 0, 0), 10, Color("ff9a1f"), 4), r)
		if id == "" or (i == _drag_from and _dragging):
			continue
		var scale_k := 1.0 + (0.35 * float(_pops[i]) / 0.35 if _pops.has(i) else 0.0)
		_draw_item(id, r.grow((scale_k - 1.0) * CELL * 0.5))
	if _dragging and dragging_id != "":
		_draw_item(dragging_id, Rect2(_drag_pos - Vector2(CELL, CELL) * 0.6, Vector2(CELL, CELL) * 1.2))


func _draw_item(id: String, r: Rect2) -> void:
	if GameData.is_generator(id):
		var g: Dictionary = GameData.GENERATORS[id.trim_prefix("gen_")]
		var pulse := 1.0 + sin(_t * 4.0) * 0.04
		var gr := Rect2(r.get_center() - r.size * 0.45 * pulse, r.size * 0.9 * pulse)
		draw_style_box(UI.box(Color(1.0, 0.85, 0.4, 0.35), 14), gr)
		_generator_icon(g["icon"], gr.grow(-8))
		return
	var tex := thumbs.texture(GameData.model(id))
	if tex != null:
		draw_texture_rect(tex, r.grow(-4), false)
	else:
		draw_circle(r.get_center(), r.size.x * 0.3, GameData.CHAINS[GameData.chain_of(id)]["color"])
	var lv := GameData.level_of(id)
	var top := GameData.max_level(GameData.chain_of(id))
	var badge := Rect2(r.position + Vector2(r.size.x - 26, r.size.y - 24), Vector2(24, 22))
	draw_style_box(UI.box(Color("ffd23a") if lv == top else Color(0.25, 0.18, 0.12, 0.85), 8), badge)
	var f := UI.font()
	draw_string(f, badge.position + Vector2(6 if lv < 10 else 2, 17), str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.2, 0.1, 0.05) if lv == top else Color.WHITE)


func _generator_icon(kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x
	var edge := Color(0.25, 0.14, 0.06)
	match kind:
		"box":
			draw_rect(Rect2(c - Vector2(s * 0.42, s * 0.22), Vector2(s * 0.84, s * 0.6)), edge)
			draw_rect(Rect2(c - Vector2(s * 0.38, s * 0.18), Vector2(s * 0.76, s * 0.52)), Color("c8955a"))
			draw_rect(Rect2(c - Vector2(s * 0.06, s * 0.18), Vector2(s * 0.12, s * 0.52)), Color("e8d0a0"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.22), c + Vector2(-s * 0.2, -s * 0.44), c + Vector2(0, -s * 0.22)]), Color("d8a868"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, -s * 0.22), c + Vector2(s * 0.2, -s * 0.44), c + Vector2(0, -s * 0.22)]), Color("d8a868"))
		"basket":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.06), c + Vector2(s * 0.42, -s * 0.06), c + Vector2(s * 0.32, s * 0.4), c + Vector2(-s * 0.32, s * 0.4)]), Color("b07840"))
			for k in 4:
				draw_line(c + Vector2(-s * 0.38 + k * s * 0.02, s * 0.04 + k * s * 0.09), c + Vector2(s * 0.38 - k * s * 0.02, s * 0.04 + k * s * 0.09), Color("8a5a2a"), 3.0)
			draw_circle(c + Vector2(-s * 0.14, -s * 0.12), s * 0.14, Color("e86a8a"))
			draw_circle(c + Vector2(s * 0.12, -s * 0.14), s * 0.12, Color("6ab0e8"))
			draw_arc(c + Vector2(0, -s * 0.06), s * 0.34, PI, TAU, 16, Color("8a5a2a"), 5.0)
		_:
			draw_rect(Rect2(c + Vector2(-s * 0.44, s * 0.02), Vector2(s * 0.88, s * 0.14)), Color("8a5a2a"))
			draw_rect(Rect2(c + Vector2(-s * 0.36, s * 0.16), Vector2(s * 0.1, s * 0.28)), Color("6a4020"))
			draw_rect(Rect2(c + Vector2(s * 0.26, s * 0.16), Vector2(s * 0.1, s * 0.28)), Color("6a4020"))
			draw_line(c + Vector2(-s * 0.3, -s * 0.36), c + Vector2(s * 0.06, -s * 0.02), Color("b9c4cc"), 7.0)
			draw_line(c + Vector2(s * 0.06, -s * 0.02), c + Vector2(s * 0.18, s * 0.0), Color("8b5a2b"), 9.0)
			draw_rect(Rect2(c + Vector2(s * 0.12, -s * 0.38), Vector2(s * 0.26, s * 0.12)), Color("9aa4ac"))
