class_name ColonyState
extends RefCounted
## The colony's economy: stockpiles, buildings, power and oxygen, colonists
## arriving by rocket, construction timers and the mission chain. The 3D base
## only draws this, so every rule here is unit tested.

signal built(b: Dictionary)
signal lander
signal mission_done

var credits := 250.0
var ore := 40.0
var crystals := 5
var colonists := 4
var buildings: Array[Dictionary] = []
var mission := 0
var meteors := 0
var storm := false
var boost := 0.0       # seconds of double production left (rewarded ad)
var next_id := 1
var lander_t := 0.0
var _mission_ready := false


func _init() -> void:
	buildings.append({"id": 0, "type": "hq", "cell": GameData.HQ_CELL, "level": 1, "build": 0.0, "damaged": false})


func hq_level() -> int:
	return int(hq()["level"])


func hq() -> Dictionary:
	for b in buildings:
		if b["type"] == "hq":
			return b
	return {}


func count(type: String) -> int:
	var n := 0
	for b in buildings:
		if b["type"] == type:
			n += 1
	return n


func at(cell: Vector2i) -> Dictionary:
	for b in buildings:
		if b["cell"] == cell:
			return b
	return {}


func by_id(id: int) -> Dictionary:
	for b in buildings:
		if int(b["id"]) == id:
			return b
	return {}


func working(b: Dictionary) -> bool:
	return float(b["build"]) <= 0.0 and not b["damaged"]


func afford(c: Array) -> bool:
	return credits >= int(c[0]) and ore >= int(c[1])


## Why [param type] can't go on [param cell], or "" if it can.
func place_error(type: String, cell: Vector2i) -> String:
	if not GameData.in_bounds(cell):
		return "Outside the colony"
	if not at(cell).is_empty():
		return "Something is already there"
	var need: String = GameData.info(type).get("on", "")
	var dep := GameData.deposit(cell)
	if need != "" and dep != need:
		return "Build it on an %s deposit" % need if need == "ore" else "Build it on a crystal vein"
	if need == "" and dep != "":
		return "Keep deposits free for drills"
	return ""


## Why [param type] can't be built at all right now, or "".
func build_error(type: String) -> String:
	if GameData.unlock_level(type) > hq_level():
		return "Needs Command Hub level %d" % GameData.unlock_level(type)
	if count(type) >= GameData.limit(type, hq_level()):
		return "Upgrade the Command Hub to build more"
	if not afford(GameData.cost(type, 0)):
		return "Not enough resources"
	return ""


func build(type: String, cell: Vector2i) -> Dictionary:
	if build_error(type) != "" or place_error(type, cell) != "":
		return {}
	var c := GameData.cost(type, 0)
	credits -= int(c[0])
	ore -= int(c[1])
	var b := {"id": next_id, "type": type, "cell": cell, "level": 1, "build": GameData.build_time(type, 0),
		"damaged": false}
	next_id += 1
	buildings.append(b)
	return b


func upgrade_error(b: Dictionary) -> String:
	if float(b["build"]) > 0.0:
		return "Still under construction"
	if b["damaged"]:
		return "Repair it first"
	var max_level := GameData.HQ_MAX if b["type"] == "hq" else GameData.MAX_LEVEL
	if int(b["level"]) >= max_level:
		return "Fully upgraded"
	if b["type"] != "hq" and int(b["level"]) >= hq_level() + 1:
		return "Upgrade the Command Hub first"
	if not afford(GameData.cost(b["type"], int(b["level"]))):
		return "Not enough resources"
	return ""


func upgrade(b: Dictionary) -> bool:
	if upgrade_error(b) != "":
		return false
	var c := GameData.cost(b["type"], int(b["level"]))
	credits -= int(c[0])
	ore -= int(c[1])
	b["build"] = GameData.build_time(b["type"], int(b["level"]))
	b["level"] = int(b["level"]) + 1
	return true


## Finishes a build at once for crystals.
func rush(b: Dictionary) -> bool:
	var price := GameData.rush_cost(float(b["build"]))
	if float(b["build"]) <= 0.0 or crystals < price:
		return false
	crystals -= price
	b["build"] = 0.0
	built.emit(b)
	return true


func repair(b: Dictionary) -> bool:
	var price := GameData.repair_cost(b["type"], int(b["level"]))
	if not b["damaged"] or credits < price:
		return false
	credits -= price
	b["damaged"] = false
	return true


func damage(b: Dictionary) -> void:
	if not b.is_empty() and b["type"] != "hq" and float(b["build"]) <= 0.0:
		b["damaged"] = true


func _sum(key: String, only_working: bool = true) -> float:
	var total := 0.0
	for b in buildings:
		if only_working and not working(b):
			continue
		var v := float(GameData.info(b["type"]).get(key, 0.0))
		total += v * GameData.level_mult(int(b["level"]))
	return total


func power_supply() -> float:
	var total := 0.0
	for b in buildings:
		if not working(b):
			continue
		var p := float(GameData.info(b["type"])["power"])
		if p > 0.0:
			var made := p * GameData.level_mult(int(b["level"]))
			if storm and b["type"] == "solar":
				made *= 0.5
			total += made
	return total


func power_demand() -> float:
	var total := 0.0
	for b in buildings:
		if not working(b):
			continue
		var p := float(GameData.info(b["type"])["power"])
		if p < 0.0:
			total -= p
	return total


## 0..1: how well everything runs with the power available.
func efficiency() -> float:
	var d := power_demand()
	if d <= 0.0:
		return 1.0
	return clampf(power_supply() / d, 0.0, 1.0)


func housing() -> int:
	return int(_sum("housing"))


func oxygen() -> int:
	var made := 0.0
	for b in buildings:
		if not working(b):
			continue
		var o := float(GameData.info(b["type"]).get("oxygen", 0.0)) * GameData.level_mult(int(b["level"]))
		if b["type"] != "hq":
			o *= efficiency()
		made += o
	return int(made)


func capacity() -> int:
	return mini(housing(), oxygen())


func storage() -> int:
	return GameData.BASE_STORAGE + int(_sum("storage"))


func credit_rate() -> float:
	var breathing := 1.0 if oxygen() >= colonists else float(oxygen()) / maxf(colonists, 1)
	var rate := colonists * GameData.CREDITS_PER_COLONIST * (1.0 + _sum("boost_credits")) * breathing
	return rate * (2.0 if boost > 0.0 else 1.0)


func ore_rate() -> float:
	var rate := _sum("mine") * efficiency() * (1.0 + _sum("boost_ore"))
	return rate * (2.0 if boost > 0.0 else 1.0)


func crystal_rate() -> float:
	return _sum("crystal") * efficiency()


var _crystal_acc := 0.0


func tick(delta: float) -> void:
	for b in buildings:
		if float(b["build"]) > 0.0:
			b["build"] = float(b["build"]) - delta
			if float(b["build"]) <= 0.0:
				b["build"] = 0.0
				built.emit(b)
	credits += credit_rate() * delta
	ore = minf(ore + ore_rate() * delta, float(storage()))
	_crystal_acc += crystal_rate() * delta
	while _crystal_acc >= 1.0:
		_crystal_acc -= 1.0
		crystals += 1
	boost = maxf(0.0, boost - delta)
	# Rockets bring colonists while there are homes and air for them.
	if colonists < capacity():
		lander_t += delta * (2.0 if count("pad") > 0 and working(_first("pad")) else 1.0)
		if lander_t >= GameData.LANDER_EVERY:
			lander_t = 0.0
			colonists = mini(colonists + GameData.LANDER_COLONISTS, capacity())
			lander.emit()
	else:
		lander_t = 0.0
	var ready := mission_complete()
	if ready and not _mission_ready:
		mission_done.emit()
	_mission_ready = ready


func _first(type: String) -> Dictionary:
	for b in buildings:
		if b["type"] == type:
			return b
	return {}


## Credits and ore earned while the game was closed (capped at two hours).
func offline(seconds: float) -> Dictionary:
	var t := clampf(seconds, 0.0, GameData.OFFLINE_CAP)
	var c := credit_rate() * t
	var o := minf(ore_rate() * t, maxf(float(storage()) - ore, 0.0))
	credits += c
	ore += o
	return {"credits": int(c), "ore": int(o), "seconds": t}


func mission_info() -> Dictionary:
	if mission >= GameData.MISSIONS.size():
		return {}
	return GameData.MISSIONS[mission]


## [current, goal] for the active mission.
func mission_progress() -> Array:
	var m := mission_info()
	if m.is_empty():
		return [0, 0]
	var cur := 0
	match m["kind"]:
		"count":
			for b in buildings:
				if b["type"] == m["what"] and float(b["build"]) <= 0.0:
					cur += 1
		"colonists":
			cur = colonists
		"hq":
			cur = hq_level() if float(hq()["build"]) <= 0.0 else hq_level() - 1
		"meteors":
			cur = meteors
		"max_level":
			for b in buildings:
				if b["type"] != "hq" and float(b["build"]) <= 0.0:
					cur = maxi(cur, int(b["level"]))
	return [mini(cur, int(m["goal"])), int(m["goal"])]


func mission_complete() -> bool:
	var p := mission_progress()
	return int(p[1]) > 0 and int(p[0]) >= int(p[1])


func claim_mission() -> bool:
	if not mission_complete():
		return false
	var m := mission_info()
	credits += int(m["credits"])
	crystals += int(m["crystals"])
	mission += 1
	_mission_ready = false
	return true


func to_dict() -> Dictionary:
	var list: Array = []
	for b in buildings:
		list.append({"id": b["id"], "type": b["type"], "x": (b["cell"] as Vector2i).x, "y": (b["cell"] as Vector2i).y,
			"level": b["level"], "build": b["build"], "damaged": b["damaged"]})
	return {"credits": credits, "ore": ore, "crystals": crystals, "colonists": colonists, "buildings": list,
		"mission": mission, "meteors": meteors, "next_id": next_id, "boost": boost}


func from_dict(d: Dictionary) -> void:
	credits = float(d.get("credits", 250.0))
	ore = float(d.get("ore", 40.0))
	crystals = int(d.get("crystals", 5))
	colonists = int(d.get("colonists", 4))
	mission = int(d.get("mission", 0))
	meteors = int(d.get("meteors", 0))
	next_id = int(d.get("next_id", 1))
	boost = float(d.get("boost", 0.0))
	var list: Array = d.get("buildings", [])
	if list.is_empty():
		return
	buildings.clear()
	for e in list:
		buildings.append({"id": int(e["id"]), "type": str(e["type"]), "cell": Vector2i(int(e["x"]), int(e["y"])),
			"level": int(e["level"]), "build": float(e["build"]), "damaged": bool(e["damaged"])})
	if hq().is_empty():
		buildings.append({"id": 0, "type": "hq", "cell": GameData.HQ_CELL, "level": 1, "build": 0.0, "damaged": false})
