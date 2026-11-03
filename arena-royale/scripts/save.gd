extends Node
## The commander's profile: trophies, gold, the card collection with levels
## and shards, the battle deck and the record.

signal changed

const PATH := "user://arena.json"

var trophies := 0
var best_trophies := 0
var gold := 100
var cards: Dictionary = {}    # id -> {"level": int, "shards": int}
var deck: Array = GameData.STARTER_DECK.duplicate()
var wins := 0
var losses := 0
var sound := true
var vibrate := true


func _ready() -> void:
	_ensure_cards()
	load_profile()


func _ensure_cards() -> void:
	for id in GameData.unlocked_cards(trophies):
		if not cards.has(id):
			cards[id] = {"level": 1, "shards": 0}


func level(id: String) -> int:
	return int((cards.get(id, {"level": 1}) as Dictionary).get("level", 1))


func shards(id: String) -> int:
	return int((cards.get(id, {}) as Dictionary).get("shards", 0))


func levels() -> Dictionary:
	var out := {}
	for id in cards:
		out[id] = level(id)
	return out


func owns(id: String) -> bool:
	return cards.has(id)


func can_upgrade(id: String) -> bool:
	var lv := level(id)
	return owns(id) and lv < GameData.MAX_LEVEL and shards(id) >= GameData.shards_needed(lv) and gold >= GameData.upgrade_cost(lv)


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var lv := level(id)
	gold -= GameData.upgrade_cost(lv)
	cards[id] = {"level": lv + 1, "shards": shards(id) - GameData.shards_needed(lv)}
	store()
	return true


## Swaps [param out_id] in the deck for [param in_id] (which must be owned and not in the deck).
func swap(out_id: String, in_id: String) -> bool:
	if not deck.has(out_id) or deck.has(in_id) or not owns(in_id):
		return false
	deck[deck.find(out_id)] = in_id
	store()
	return true


## Records a battle and opens its chest. Returns the chest's contents
## {gold, shards: {id: n}, new: [ids]}.
func finish_battle(won: bool, trophy_delta: int, gold_won: int, rng: RandomNumberGenerator) -> Dictionary:
	var before := GameData.arena_index(trophies)
	trophies = maxi(0, trophies + trophy_delta)
	best_trophies = maxi(best_trophies, trophies)
	gold += gold_won
	if won:
		wins += 1
	else:
		losses += 1
	var fresh: Array = []
	for id in GameData.unlocked_cards(trophies):
		if not cards.has(id):
			cards[id] = {"level": 1, "shards": 0}
			fresh.append(id)
	var chest := {"gold": 0, "shards": {}, "new": fresh, "arena_up": GameData.arena_index(trophies) > before}
	if won:
		var owned: Array = cards.keys()
		for i in 3:
			var id: String = owned[rng.randi() % owned.size()]
			var n := rng.randi_range(1, 4)
			cards[id]["shards"] = shards(id) + n
			chest["shards"][id] = int(chest["shards"].get(id, 0)) + n
		chest["gold"] = rng.randi_range(10, 30)
		gold += int(chest["gold"])
	store()
	return chest


func to_dict() -> Dictionary:
	return {"trophies": trophies, "best_trophies": best_trophies, "gold": gold, "cards": cards, "deck": deck,
		"wins": wins, "losses": losses, "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	trophies = int(d.get("trophies", 0))
	best_trophies = int(d.get("best_trophies", 0))
	gold = int(d.get("gold", 100))
	cards = {}
	var raw: Dictionary = d.get("cards", {})
	for id in raw:
		cards[id] = {"level": int(raw[id].get("level", 1)), "shards": int(raw[id].get("shards", 0))}
	deck = d.get("deck", GameData.STARTER_DECK.duplicate())
	wins = int(d.get("wins", 0))
	losses = int(d.get("losses", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	_ensure_cards()
	if deck.size() != GameData.DECK_SIZE:
		deck = GameData.STARTER_DECK.duplicate()


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
