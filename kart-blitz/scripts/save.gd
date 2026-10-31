extends Node
## The racer's profile: coins, karts, upgrades, track progress and trophies.

signal changed

const PATH := "user://racer.json"

var coins := 0
var kart := "red"
var owned: Array = ["red"]
var upgrades: Dictionary = {}
var best: Dictionary = {}
var unlocked := 1
var track_index := 0
var races := 0
var wins := 0
var sound := true
var vibrate := true


func _ready() -> void:
	load_profile()


func upgrade(id: String) -> int:
	return int(upgrades.get(id, 0))


func best_place(track: int) -> int:
	return int(best.get(str(track), 0))


func buy_kart(id: String) -> bool:
	if owned.has(id):
		kart = id
		store()
		return true
	var cost := int(GameData.kart(id)["cost"])
	if coins < cost:
		return false
	coins -= cost
	owned.append(id)
	kart = id
	store()
	return true


func buy_upgrade(id: String) -> bool:
	var lv := upgrade(id)
	if lv >= GameData.MAX_UPGRADE or coins < GameData.upgrade_cost(lv):
		return false
	coins -= GameData.upgrade_cost(lv)
	upgrades[id] = lv + 1
	store()
	return true


## Records a race. Top-three finishes unlock the next track; returns its name, or "".
func finish_race(track: int, place: int, earned: int) -> String:
	coins += earned
	races += 1
	if place == 1:
		wins += 1
	var prev := best_place(track)
	if prev == 0 or place < prev:
		best[str(track)] = place
	var opened := ""
	if place <= 3 and track + 1 >= unlocked and track + 1 < GameData.TRACKS.size():
		unlocked = track + 2
		opened = GameData.track(track + 1)["name"]
	store()
	return opened


func to_dict() -> Dictionary:
	return {"coins": coins, "kart": kart, "owned": owned, "upgrades": upgrades, "best": best, "unlocked": unlocked,
		"track_index": track_index, "races": races, "wins": wins, "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	kart = str(d.get("kart", "red"))
	owned = d.get("owned", ["red"])
	upgrades = d.get("upgrades", {})
	best = d.get("best", {})
	unlocked = int(d.get("unlocked", 1))
	track_index = int(d.get("track_index", 0))
	races = int(d.get("races", 0))
	wins = int(d.get("wins", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	if not owned.has("red"):
		owned.append("red")


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
