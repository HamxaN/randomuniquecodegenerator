extends Node
## The commander's progress: stars per level and settings.

signal changed

const PATH := "user://kingdom.json"

var stars: Dictionary = {}
var sound := true
var vibrate := true
var tutorial_done := false


func _ready() -> void:
	load_profile()


func level_stars(n: int) -> int:
	return int(stars.get(str(n), 0))


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


## The highest level that can be played: one past the last one won.
func unlocked() -> int:
	var n := 1
	while n < GameData.LEVELS and level_stars(n) > 0:
		n += 1
	return n


func finish_level(n: int, earned: int) -> void:
	if earned > level_stars(n):
		stars[str(n)] = earned
	store()


func to_dict() -> Dictionary:
	return {"stars": stars, "sound": sound, "vibrate": vibrate, "tutorial_done": tutorial_done}


func from_dict(d: Dictionary) -> void:
	stars = d.get("stars", {})
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	tutorial_done = bool(d.get("tutorial_done", false))


func store() -> void:
	if not is_inside_tree():
		changed.emit()
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		from_dict(parsed)
