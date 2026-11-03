class_name RunState
extends RefCounted
## One night's progress: level and XP, the weapons and relics picked so far
## and the stats they add up to. No nodes here, so it is unit tested.

var hero: Dictionary
var meta: Dictionary = {}     # permanent upgrade levels
var level := 1
var xp := 0
var weapons: Dictionary = {}  # id -> level
var relics: Dictionary = {}   # id -> level
var kills := 0
var gold := 0


func _init(hero_id: String = "knight", meta_levels: Dictionary = {}) -> void:
	hero = GameData.hero(hero_id)
	meta = meta_levels
	weapons[hero["weapon"]] = 1


func meta_level(id: String) -> int:
	return int(meta.get(id, 0))


func relic(id: String) -> int:
	return int(relics.get(id, 0))


func _relic_sum(stat: String) -> float:
	var total := 0.0
	for id in relics:
		var r: Dictionary = GameData.RELICS[id]
		if r["stat"] == stat:
			total += float(r["step"]) * int(relics[id])
	return total


func max_hp() -> float:
	return float(hero["hp"]) + _relic_sum("hp") + 10.0 * meta_level("hp")


func might() -> float:
	return 1.0 + _relic_sum("might") + 0.05 * meta_level("might")


## Multiplier on weapon cooldowns (smaller is faster).
func cooldown_mult() -> float:
	return 1.0 / (1.0 + _relic_sum("haste") + float(hero.get("haste", 0.0)))


func speed() -> float:
	return float(hero["speed"]) * (1.0 + _relic_sum("speed") + 0.04 * meta_level("speed"))


func magnet() -> float:
	return 2.2 * (1.0 + _relic_sum("magnet") + 0.15 * meta_level("magnet"))


func regen() -> float:
	return _relic_sum("regen")


func area() -> float:
	return 1.0 + _relic_sum("area")


func armor() -> float:
	return float(hero.get("armor", 0)) + meta_level("armor")


## Adds XP and returns how many levels were gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= GameData.xp_to_next(level):
		xp -= GameData.xp_to_next(level)
		level += 1
		gained += 1
	return gained


## Up to three different choices for a level-up: new or better weapons and
## relics, never past their max or the slot limits. Gold if nothing is left.
func choices(rng: RandomNumberGenerator, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id in GameData.WEAPONS:
		var lv := int(weapons.get(id, 0))
		if lv >= GameData.MAX_LEVEL:
			continue
		if lv == 0 and weapons.size() >= GameData.MAX_WEAPONS:
			continue
		# Upgrades to what you have come up a bit more often.
		pool.append({"kind": "weapon", "id": id, "level": lv + 1, "weight": 1.6 if lv > 0 else 1.0})
	for id in GameData.RELICS:
		var lv := relic(id)
		if lv >= GameData.MAX_LEVEL:
			continue
		if lv == 0 and relics.size() >= GameData.MAX_RELICS:
			continue
		pool.append({"kind": "relic", "id": id, "level": lv + 1, "weight": 1.0})
	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += float(p["weight"])
		var x := rng.randf() * total
		var pick := 0
		for i in pool.size():
			x -= float(pool[i]["weight"])
			if x <= 0.0:
				pick = i
				break
		out.append(pool[pick])
		pool.remove_at(pick)
	if out.is_empty():
		out.append({"kind": "gold", "id": "gold", "level": 0, "weight": 1.0})
	return out


func apply(choice: Dictionary) -> void:
	match choice["kind"]:
		"weapon":
			weapons[choice["id"]] = int(choice["level"])
		"relic":
			relics[choice["id"]] = int(choice["level"])
		"gold":
			gold += 25
