extends Node
## The village: buildings, resources, army and campaign progress, saved as JSON.
## Builds and training run on real time, so they carry on while the game is closed.

signal changed

const PATH := "user://village.json"

var gold := 600
var wood := 600
var gems := 60
var xp := 0
var buildings: Array = []
var army: Dictionary = {}
var training: Array = []
var troop_levels: Dictionary = {}
var campaign: Dictionary = {}
var next_id := 1
var sound := true
var vibrate := true
var tutorial_step := 0


func _ready() -> void:
	load_village()
	if buildings.is_empty():
		new_village()


static func now() -> float:
	return Time.get_unix_time_from_system()


func new_village() -> void:
	gold = 600
	wood = 600
	gems = 60
	xp = 0
	buildings = []
	next_id = 1
	army = {"barbarian": 8, "archer": 4}
	training = []
	troop_levels = {}
	campaign = {}
	_add("townhall", Vector2i(0, 0), 1)
	_add("goldmine", Vector2i(2, -1), 1)
	_add("lumbermill", Vector2i(-2, 1), 1)
	_add("barracks", Vector2i(1, 1), 1)
	_add("house", Vector2i(-1, -1), 1)
	_add("archertower", Vector2i(0, -2), 1)
	store()


func _add(kind: String, cell: Vector2i, level: int) -> Dictionary:
	var b := {"id": next_id, "type": kind, "q": cell.x, "r": cell.y, "level": level, "done_at": 0.0, "collected_at": now()}
	next_id += 1
	buildings.append(b)
	return b


func level() -> int:
	return GameData.level_for_xp(xp)


func town_hall_level() -> int:
	for b in buildings:
		if b["type"] == "townhall":
			return int(b["level"])
	return 1


func count(kind: String) -> int:
	var n := 0
	for b in buildings:
		if b["type"] == kind:
			n += 1
	return n


func best_level(kind: String) -> int:
	var best := 0
	for b in buildings:
		if b["type"] == kind and not building_busy(b):
			best = maxi(best, int(b["level"]))
		elif b["type"] == kind:
			best = maxi(best, int(b["level"]) - 1)
	return best


func building_at(cell: Vector2i) -> Variant:
	for b in buildings:
		if int(b["q"]) == cell.x and int(b["r"]) == cell.y:
			return b
	return null


func by_id(id: int) -> Variant:
	for b in buildings:
		if int(b["id"]) == id:
			return b
	return null


func building_busy(b: Dictionary) -> bool:
	return float(b["done_at"]) > now()


func builders_busy() -> int:
	var n := 0
	for b in buildings:
		if building_busy(b):
			n += 1
	return n


func can_afford(res: String, amount: int) -> bool:
	return (gold if res == "gold" else wood) >= amount


func pay(res: String, amount: int) -> bool:
	if not can_afford(res, amount):
		return false
	if res == "gold":
		gold -= amount
	else:
		wood -= amount
	return true


func housing_capacity() -> int:
	var cap := GameData.BASE_HOUSING
	for b in buildings:
		if b["type"] == "house":
			var lv := int(b["level"]) - (1 if building_busy(b) else 0)
			cap += GameData.BUILDINGS["house"]["housing"] * maxi(lv, 0)
	return cap


func housing_used() -> int:
	var n := 0
	for t in army:
		n += int(army[t]) * int(GameData.TROOPS[t]["housing"])
	for q in training:
		n += int(GameData.TROOPS[q["type"]]["housing"])
	return n


func troop_level(kind: String) -> int:
	return int(troop_levels.get(kind, 1))


func campaign_stars(n: int) -> int:
	return int(campaign.get(str(n), 0))


func total_stars() -> int:
	var s := 0
	for k in campaign:
		s += int(campaign[k])
	return s


## The next campaign level that can be played (the first without any stars).
func next_campaign_level() -> int:
	for n in range(1, GameData.CAMPAIGN_SIZE + 1):
		if campaign_stars(n) == 0:
			return n
	return GameData.CAMPAIGN_SIZE


# ---------------------------------------------------------------- Actions

## Starts building [param kind] on [param cell]. Returns "" or why not.
func place(kind: String, cell: Vector2i) -> String:
	if not Hex.buildable(cell) or building_at(cell) != null:
		return "Can't build there"
	if count(kind) >= GameData.limit(kind, town_hall_level()):
		return "Upgrade your Town Hall to build more"
	if builders_busy() >= GameData.BUILDERS:
		return "All builders are busy"
	var b: Dictionary = GameData.building(kind)
	if not pay(b["res"], GameData.cost(kind, 1)):
		return "Not enough %s" % b["res"]
	var nb := _add(kind, cell, 1)
	nb["done_at"] = now() + GameData.build_time(kind, 1)
	store()
	return ""


func upgrade(id: int) -> String:
	var b: Variant = by_id(id)
	if b == null:
		return "Missing"
	var kind: String = b["type"]
	var next := int(b["level"]) + 1
	if next > GameData.max_level(kind) or building_busy(b):
		return "Already at max level"
	if kind != "townhall" and next > town_hall_level():
		return "Upgrade your Town Hall first"
	if builders_busy() >= GameData.BUILDERS:
		return "All builders are busy"
	if not pay(GameData.building(kind)["res"], GameData.cost(kind, next)):
		return "Not enough %s" % GameData.building(kind)["res"]
	collect(id)
	b["level"] = next
	b["done_at"] = now() + GameData.build_time(kind, next)
	store()
	return ""


func finish_now(id: int, free: bool) -> bool:
	var b: Variant = by_id(id)
	if b == null or not building_busy(b):
		return false
	if not free:
		var g := GameData.gems_to_finish(float(b["done_at"]) - now())
		if gems < g:
			return false
		gems -= g
	b["done_at"] = now() - 0.01
	store()
	return true


## Called every frame or so: completes builds and training whose time is up.
## Returns the buildings that just finished, for effects.
func tick() -> Array:
	var finished: Array = []
	var t := now()
	for b in buildings:
		var done := float(b["done_at"])
		if done > 0.0 and done <= t:
			b["done_at"] = 0.0
			b["collected_at"] = t
			xp += int(GameData.building(b["type"])["xp"]) * int(b["level"])
			finished.append(b)
	var trained := false
	while training.size() > 0 and float(training[0]["done_at"]) <= t:
		var q: Dictionary = training.pop_front()
		army[q["type"]] = int(army.get(q["type"], 0)) + 1
		trained = true
	if finished.size() > 0 or trained:
		store()
	return finished


func ready_to_collect(b: Dictionary) -> int:
	if building_busy(b) or not GameData.building(b["type"]).has("produces"):
		return 0
	return GameData.produced(b["type"], int(b["level"]), now() - float(b["collected_at"]))


## Collects a producer's resources. Returns {gold, wood} collected.
func collect(id: int) -> Dictionary:
	var b: Variant = by_id(id)
	var got := {"gold": 0, "wood": 0}
	if b == null:
		return got
	var amount := ready_to_collect(b)
	b["collected_at"] = now()
	match GameData.building(b["type"]).get("produces", ""):
		"gold":
			got["gold"] = amount
		"wood":
			got["wood"] = amount
		"both":
			got["gold"] = amount
			got["wood"] = amount
	gold += got["gold"]
	wood += got["wood"]
	store()
	return got


func train(kind: String) -> String:
	var t: Dictionary = GameData.troop(kind)
	if int(t["barracks"]) > best_level("barracks"):
		return "Upgrade your Barracks to train this"
	if housing_used() + int(t["housing"]) > housing_capacity():
		return "Army camps are full"
	if not pay("wood", int(t["cost"])):
		return "Not enough wood"
	var start := now()
	if training.size() > 0:
		start = maxf(start, float(training[-1]["done_at"]))
	training.append({"type": kind, "done_at": start + float(t["train"])})
	store()
	return ""


func upgrade_troop(kind: String) -> String:
	var lv := troop_level(kind)
	if lv >= GameData.MAX_LEVEL:
		return "Max level"
	if lv >= best_level("blacksmith") + 1:
		return "Upgrade your Blacksmith first"
	if not pay("gold", GameData.troop_upgrade_cost(lv)):
		return "Not enough gold"
	troop_levels[kind] = lv + 1
	store()
	return ""


## Records a raid. [param used] is how many of each troop were deployed.
func finish_raid(n: int, stars: int, loot: Dictionary, used: Dictionary) -> void:
	if stars > campaign_stars(n):
		campaign[str(n)] = stars
	gold += int(loot.get("gold", 0))
	wood += int(loot.get("wood", 0))
	xp += 20 + stars * 15 + n * 3
	for t in used:
		army[t] = maxi(0, int(army.get(t, 0)) - int(used[t]))
	store()


# ---------------------------------------------------------------- Persistence

func to_dict() -> Dictionary:
	return {"gold": gold, "wood": wood, "gems": gems, "xp": xp, "buildings": buildings, "army": army,
		"training": training, "troop_levels": troop_levels, "campaign": campaign, "next_id": next_id,
		"sound": sound, "vibrate": vibrate, "tutorial_step": tutorial_step}


func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 600))
	wood = int(d.get("wood", 600))
	gems = int(d.get("gems", 60))
	xp = int(d.get("xp", 0))
	buildings = d.get("buildings", [])
	army = d.get("army", {})
	training = d.get("training", [])
	troop_levels = d.get("troop_levels", {})
	campaign = d.get("campaign", {})
	next_id = int(d.get("next_id", 1))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	tutorial_step = int(d.get("tutorial_step", 0))


func store() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_village() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		from_dict(parsed)
