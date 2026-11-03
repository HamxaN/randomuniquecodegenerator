class_name Manor
extends Node3D
## The game: the room being restored in 3D on the left, and the merge board
## and orders on the right.

var room: RoomView
var hud: ManorHud
var thumbs: ThumbCache


func _ready() -> void:
	thumbs = ThumbCache.new()
	add_child(thumbs)
	room = RoomView.new()
	add_child(room)
	var b := Save.board
	room.build(mini(b.room, GameData.ROOMS.size() - 1), b.step if not b.finished() else 99)
	hud = ManorHud.new()
	hud.board = b
	hud.thumbs = thumbs
	add_child(hud)
	hud.renovated.connect(_on_renovated)
	# Draw every model the board can show, ready for later.
	for c in GameData.CHAINS:
		for m in GameData.CHAINS[c]["models"]:
			thumbs.texture(m)


func _on_renovated(step: Dictionary) -> void:
	var b := Save.board
	Save.store()
	if b.step == 0 and not b.finished() or b.finished():
		# That step finished a room.
		var done_room := b.room - 1
		var steps: Array = GameData.ROOMS[done_room]["steps"]
		room.place(step, steps.size(), steps.size())
		hud.celebrate("%s restored!" % GameData.ROOMS[done_room]["name"])
		if not b.finished():
			get_tree().create_timer(3.0).timeout.connect(func() -> void: room.build(b.room, 0))
	else:
		var total := (GameData.ROOMS[b.room]["steps"] as Array).size()
		room.place(step, b.step, total)
