extends Node
## The restaurant's profile: coins, stars per day, kitchen upgrades and chefs.

signal changed

const PATH := "user://burger.json"

var coins := 0
var stars: Dictionary = {}     # day (as string) -> best stars
var upgrades: Dictionary = {}  # upgrade id -> level
var chef := "bruno"
var chefs: Array = ["bruno"]
var served := 0
var sound := true
var vibrate := true


func _ready() -> void:
	load_profile()


func level(id: String) -> int:
	return int(upgrades.get(id, 0))


func day_stars(day: int) -> int:
	return int(stars.get(str(day), 0))


## The furthest day you can play: one past the last day with at least one star.
func unlocked_day() -> int:
	var d := 1
	while d < GameData.day_count() and day_stars(d) > 0:
		d += 1
	return d


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


func buy_upgrade(id: String) -> bool:
	var u := GameData.upgrade(id)
	var lv := level(id)
	if u.is_empty() or lv >= int(u["max"]):
		return false
	var cost := GameData.upgrade_cost(id, lv)
	if coins < cost:
		return false
	coins -= cost
	upgrades[id] = lv + 1
	store()
	return true


func pick_chef(id: String) -> bool:
	if chefs.has(id):
		chef = id
		store()
		return true
	var cost := int(GameData.chef(id)["cost"])
	if coins < cost:
		return false
	coins -= cost
	chefs.append(id)
	chef = id
	store()
	return true


## Records a finished day. Returns true if it beat the previous best.
func finish_day(day: int, earned: int, star_count: int, served_count: int) -> bool:
	coins += earned
	served += served_count
	var best := star_count > day_stars(day)
	if best:
		stars[str(day)] = star_count
	store()
	return best


func to_dict() -> Dictionary:
	return {"coins": coins, "stars": stars, "upgrades": upgrades, "chef": chef, "chefs": chefs,
		"served": served, "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	stars = d.get("stars", {})
	upgrades = d.get("upgrades", {})
	chef = str(d.get("chef", "bruno"))
	chefs = d.get("chefs", ["bruno"])
	served = int(d.get("served", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	if not chefs.has("bruno"):
		chefs.append("bruno")


func store() -> void:
	# Only the game's own profile is written to disk (not copies made by tests).
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
