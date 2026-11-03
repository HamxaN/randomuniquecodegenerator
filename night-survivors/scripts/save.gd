extends Node
## The survivor's profile: gold, heroes, permanent upgrades and records.

signal changed

const PATH := "user://night.json"

var gold := 0
var hero := "knight"
var heroes: Array = ["knight"]
var meta: Dictionary = {}
var map := "graveyard"
var best_time := 0.0
var best_kills := 0
var dawns := 0
var sound := true
var vibrate := true


func _ready() -> void:
	load_profile()


func meta_level(id: String) -> int:
	return int(meta.get(id, 0))


func buy_meta(id: String) -> bool:
	var m := GameData.meta(id)
	var lv := meta_level(id)
	if m.is_empty() or lv >= int(m["max"]):
		return false
	var cost := GameData.meta_cost(id, lv)
	if gold < cost:
		return false
	gold -= cost
	meta[id] = lv + 1
	store()
	return true


func pick_hero(id: String) -> bool:
	if heroes.has(id):
		hero = id
		store()
		return true
	var cost := int(GameData.hero(id)["cost"])
	if gold < cost:
		return false
	gold -= cost
	heroes.append(id)
	hero = id
	store()
	return true


## Records a finished night. Returns true for a new best time.
func finish_run(seconds: float, kills: int, earned: int, survived: bool) -> bool:
	var best := seconds > best_time
	best_time = maxf(best_time, seconds)
	best_kills = maxi(best_kills, kills)
	gold += earned
	if survived:
		dawns += 1
	store()
	return best


func to_dict() -> Dictionary:
	return {"gold": gold, "hero": hero, "heroes": heroes, "meta": meta, "map": map, "best_time": best_time,
		"best_kills": best_kills, "dawns": dawns, "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	hero = str(d.get("hero", "knight"))
	heroes = d.get("heroes", ["knight"])
	meta = d.get("meta", {})
	map = str(d.get("map", "graveyard"))
	best_time = float(d.get("best_time", 0.0))
	best_kills = int(d.get("best_kills", 0))
	dawns = int(d.get("dawns", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	if not heroes.has("knight"):
		heroes.append("knight")


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
