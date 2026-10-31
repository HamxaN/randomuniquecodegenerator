extends Node
## The adventurer's profile: gold, heroes, equipped gear, talents and records.

signal changed

const PATH := "user://raider.json"

var gold := 0
var hero := "knight"
var owned: Array = ["knight"]
var gear: Dictionary = {}
var talents: Dictionary = {}
var deepest := 0
var kills := 0
var runs := 0
var sound := true
var vibrate := true
var tutorial_done := false


func _ready() -> void:
	load_profile()


func talent(id: String) -> int:
	return int(talents.get(id, 0))


func buy_talent(id: String) -> bool:
	var rank := talent(id)
	var max_rank := 10
	for t in GameData.TALENTS:
		if t["id"] == id:
			max_rank = int(t["max"])
	if rank >= max_rank or gold < GameData.talent_cost(rank):
		return false
	gold -= GameData.talent_cost(rank)
	talents[id] = rank + 1
	store()
	return true


func buy_hero(id: String) -> bool:
	if owned.has(id):
		hero = id
		store()
		return true
	var cost := int(GameData.hero(id)["cost"])
	if gold < cost:
		return false
	gold -= cost
	owned.append(id)
	hero = id
	store()
	return true


## Equips [param item] if it beats what's worn. Returns true if equipped; otherwise sells it.
func offer_item(item: Dictionary) -> bool:
	var slot: String = item["slot"]
	var current: Dictionary = gear.get(slot, {})
	if current.is_empty() or int(item["power"]) > int(current.get("power", 0)):
		if not current.is_empty():
			gold += GameData.sell_value(current)
		gear[slot] = item
		store()
		return true
	gold += GameData.sell_value(item)
	store()
	return false


func gear_power(slot: String) -> int:
	return int((gear.get(slot, {}) as Dictionary).get("power", 0))


## The hero's stats with gear and talents applied.
func hero_stats(id: String) -> Dictionary:
	var h := GameData.hero(id)
	var attack := (float(h["attack"]) + gear_power("weapon")) * (1.0 + 0.06 * talent("might"))
	var hp := (float(h["hp"]) + gear_power("armor") * 4.0) * (1.0 + 0.08 * talent("toughness"))
	var crit := 0.05 + gear_power("amulet") / 300.0
	var gold_mult := 1.0 + 0.08 * talent("fortune") + gear_power("amulet") / 200.0
	return {"attack": attack, "hp": hp, "crit": crit, "gold": gold_mult,
		"potions": GameData.BASE_POTIONS + talent("potions")}


func finish_run(floor_reached: int, run_kills: int, run_gold: int) -> bool:
	var record := floor_reached > deepest
	deepest = maxi(deepest, floor_reached)
	kills += run_kills
	gold += run_gold
	runs += 1
	store()
	return record


func to_dict() -> Dictionary:
	return {"gold": gold, "hero": hero, "owned": owned, "gear": gear, "talents": talents, "deepest": deepest,
		"kills": kills, "runs": runs, "sound": sound, "vibrate": vibrate, "tutorial_done": tutorial_done}


func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	hero = str(d.get("hero", "knight"))
	owned = d.get("owned", ["knight"])
	gear = d.get("gear", {})
	talents = d.get("talents", {})
	deepest = int(d.get("deepest", 0))
	kills = int(d.get("kills", 0))
	runs = int(d.get("runs", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	tutorial_done = bool(d.get("tutorial_done", false))
	if not owned.has("knight"):
		owned.append("knight")


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
