extends Node
## The hopper's progress: coins, skins, stars and best times per level.

signal changed

const PATH := "user://skyhop.json"

var coins := 0
var skin := "classic"
var owned: Array = ["classic"]
var stars: Dictionary = {}
var times: Dictionary = {}
var sound := true
var vibrate := true


func _ready() -> void:
	load_profile()


func level_stars(n: int) -> int:
	return int(stars.get(str(n), 0))


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


func unlocked() -> int:
	var n := 1
	while n < GameData.level_count() and stars.has(str(n)):
		n += 1
	return n


func finish_level(n: int, earned_stars: int, reward: int, time: float) -> void:
	if not stars.has(str(n)) or earned_stars > level_stars(n):
		stars[str(n)] = earned_stars
	if not times.has(str(n)) or time < float(times[str(n)]):
		times[str(n)] = time
	coins += reward
	store()


func buy_skin(id: String) -> bool:
	if owned.has(id):
		skin = id
		store()
		return true
	var cost := int(GameData.skin(id)["cost"])
	if coins < cost:
		return false
	coins -= cost
	owned.append(id)
	skin = id
	store()
	return true


func to_dict() -> Dictionary:
	return {"coins": coins, "skin": skin, "owned": owned, "stars": stars, "times": times, "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	skin = str(d.get("skin", "classic"))
	owned = d.get("owned", ["classic"])
	stars = d.get("stars", {})
	times = d.get("times", {})
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))


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
