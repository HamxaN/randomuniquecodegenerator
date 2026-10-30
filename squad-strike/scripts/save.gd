extends Node
## The player's profile: coins, XP, operators, weapons and records. Saved as JSON.

signal changed

const PATH := "user://profile.json"

var coins := 0
var xp := 0
var operator := "rogue"
var weapon := "ar"
var arena := 0
var owned_operators: Array = ["rogue"]
var weapon_levels: Dictionary = {"ar": 1}
var best_wave: Dictionary = {}
var total_kills := 0
var matches := 0
var sound := true
var vibrate := true
var tutorial_done := false


func _ready() -> void:
	load_profile()


func level() -> int:
	return GameData.level_for_xp(xp)


func owns_weapon(id: String) -> bool:
	return weapon_levels.has(id)


func weapon_level(id: String) -> int:
	return int(weapon_levels.get(id, 0))


func best(arena_index: int) -> int:
	return int(best_wave.get(str(arena_index), 0))


func arena_unlocked(index: int) -> bool:
	return level() >= int(GameData.arena(index)["unlock"])


func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	store()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	store()


func buy_operator(id: String) -> bool:
	if owned_operators.has(id):
		return true
	if not spend(int(GameData.operator(id)["cost"])):
		return false
	owned_operators.append(id)
	operator = id
	store()
	return true


func buy_weapon(id: String) -> bool:
	if owns_weapon(id):
		return true
	if not spend(int(GameData.weapon(id)["cost"])):
		return false
	weapon_levels[id] = 1
	weapon = id
	store()
	return true


func upgrade_weapon(id: String) -> bool:
	var lv := weapon_level(id)
	if lv < 1 or lv >= GameData.MAX_WEAPON_LEVEL:
		return false
	if not spend(GameData.upgrade_cost(lv)):
		return false
	weapon_levels[id] = lv + 1
	store()
	return true


## Records a finished match. Returns true if it set a new best wave.
func finish_match(arena_index: int, wave: int, kills: int, earned_coins: int, earned_xp: int) -> bool:
	var record := wave > best(arena_index)
	if record:
		best_wave[str(arena_index)] = wave
	coins += earned_coins
	xp += earned_xp
	total_kills += kills
	matches += 1
	store()
	return record


func to_dict() -> Dictionary:
	return {
		"coins": coins, "xp": xp, "operator": operator, "weapon": weapon, "arena": arena,
		"owned_operators": owned_operators, "weapon_levels": weapon_levels, "best_wave": best_wave,
		"total_kills": total_kills, "matches": matches, "sound": sound, "vibrate": vibrate,
		"tutorial_done": tutorial_done,
	}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	xp = int(d.get("xp", 0))
	operator = str(d.get("operator", "rogue"))
	weapon = str(d.get("weapon", "ar"))
	arena = int(d.get("arena", 0))
	owned_operators = d.get("owned_operators", ["rogue"])
	weapon_levels = d.get("weapon_levels", {"ar": 1})
	best_wave = d.get("best_wave", {})
	total_kills = int(d.get("total_kills", 0))
	matches = int(d.get("matches", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	tutorial_done = bool(d.get("tutorial_done", false))
	if not owned_operators.has("rogue"):
		owned_operators.append("rogue")
	if not weapon_levels.has("ar"):
		weapon_levels["ar"] = 1


func store() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		from_dict(parsed)


func reset() -> void:
	from_dict({})
	store()
