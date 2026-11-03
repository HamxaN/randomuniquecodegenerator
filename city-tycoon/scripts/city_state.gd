class_name CityState
extends RefCounted
## The city as numbers: what is on every tile, how each lot grows, residents,
## jobs, happiness, demand, money and milestones. The 3D city only draws it,
## so the rules are unit tested.

signal tile_changed(cell: Vector2i)
signal milestone(index: int)
signal day_passed(net: int)

var tiles: Array = []      # COLS*ROWS dictionaries: {"type", "level", "growth"}
var money := GameData.START_MONEY
var day := 1
var stage := 0
var clock := 0.0
var last_net := 0


func _init() -> void:
	tiles.resize(GameData.COLS * GameData.ROWS)
	for i in tiles.size():
		tiles[i] = {"type": "", "level": 0, "growth": 0.0}
	# A main street to start from.
	for x in range(3, GameData.COLS - 3):
		tiles[idx(Vector2i(x, GameData.ROWS / 2))] = {"type": "road", "level": 0, "growth": 0.0}


func idx(c: Vector2i) -> int:
	return c.y * GameData.COLS + c.x


func cell(i: int) -> Vector2i:
	return Vector2i(i % GameData.COLS, i / GameData.COLS)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GameData.COLS and c.y < GameData.ROWS


func at(c: Vector2i) -> Dictionary:
	return tiles[idx(c)] if in_bounds(c) else {"type": "", "level": 0, "growth": 0.0}


func type_at(c: Vector2i) -> String:
	return str(at(c)["type"])


const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Which neighbours are roads, as N=1, E=2, S=4, W=8.
func road_mask(c: Vector2i) -> int:
	var m := 0
	for k in 4:
		if type_at(c + DIRS[k]) == "road":
			m |= 1 << k
	return m


func connected(c: Vector2i) -> bool:
	return road_mask(c) != 0


func build_error(type: String, c: Vector2i) -> String:
	if not in_bounds(c):
		return "Outside the city limits"
	if not GameData.ZONES.has(type):
		return "Unknown building"
	if not GameData.unlocked(type, stage):
		return "Unlocks when you reach %s" % GameData.MILESTONES[int(GameData.zone(type).get("unlock", 0))]["name"]
	if type_at(c) != "":
		return "Bulldoze it first"
	if money < int(GameData.zone(type)["cost"]):
		return "Not enough money"
	return ""


func build(type: String, c: Vector2i) -> bool:
	if build_error(type, c) != "":
		return false
	money -= int(GameData.zone(type)["cost"])
	tiles[idx(c)] = {"type": type, "level": 1 if GameData.is_lot(type) else 0, "growth": 0.0}
	tile_changed.emit(c)
	for d in DIRS:
		if in_bounds(c + d) and type_at(c + d) == "road":
			tile_changed.emit(c + d)
	return true


func bulldoze(c: Vector2i) -> bool:
	if not in_bounds(c) or type_at(c) == "" or money < GameData.BULLDOZE_COST:
		return false
	var was := type_at(c)
	money -= GameData.BULLDOZE_COST
	tiles[idx(c)] = {"type": "", "level": 0, "growth": 0.0}
	tile_changed.emit(c)
	if was == "road":
		for d in DIRS:
			if in_bounds(c + d) and type_at(c + d) == "road":
				tile_changed.emit(c + d)
	return true


func _count_near(c: Vector2i, type: String, radius: int) -> int:
	var n := 0
	for y in range(c.y - radius, c.y + radius + 1):
		for x in range(c.x - radius, c.x + radius + 1):
			var o := Vector2i(x, y)
			if o != c and in_bounds(o) and type_at(o) == type and absi(o.x - c.x) + absi(o.y - c.y) <= radius:
				n += 1
	return n


## 0..100 for a home: parks, plazas and shops nearby help; factories hurt.
func happiness_at(c: Vector2i) -> int:
	var h := 50
	h += mini(_count_near(c, "park", 3) * 10, 30)
	h += 15 if _count_near(c, "plaza", 4) > 0 else 0
	h += 8 if _count_near(c, "com", 4) > 0 else 0
	h -= _count_near(c, "ind", 3) * 12
	if employment() < 0.7:
		h -= 10
	return clampi(h, 0, 100)


func population() -> int:
	var p := 0
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		if t["type"] == "res":
			p += _occupied(t, GameData.residents(int(t["level"])))
	return p


## Lots fill up as they grow.
func _occupied(t: Dictionary, capacity: int) -> int:
	return int(round(capacity * clampf(0.35 + float(t["growth"]) * 0.65, 0.0, 1.0)))


func jobs(type: String = "") -> int:
	var j := 0
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		if GameData.is_lot(t["type"]) and t["type"] != "res" and (type == "" or t["type"] == type):
			j += _occupied(t, GameData.jobs(t["type"], int(t["level"])))
	return j


func workers() -> int:
	return int(population() * 0.6)


func employment() -> float:
	var w := workers()
	if w == 0:
		return 1.0
	return clampf(float(jobs()) / w, 0.0, 1.0)


## Average happiness of the city's homes.
func happiness() -> int:
	var total := 0
	var n := 0
	for i in tiles.size():
		if tiles[i]["type"] == "res":
			total += happiness_at(cell(i))
			n += 1
	return int(round(float(total) / n)) if n > 0 else 50


## -1..1 demand for homes, shops and factories (the RCI meters).
func demand() -> Dictionary:
	var pop := population()
	var w := maxf(workers(), 8.0)
	var r := clampf(0.35 + (jobs() - workers()) / maxf(w, 20.0), -1.0, 1.0)
	var c := clampf((pop * 0.22 - jobs("com")) / maxf(pop * 0.22, 10.0), -1.0, 1.0)
	var i := clampf((pop * 0.3 - jobs("ind") - jobs("office") * 0.5) / maxf(pop * 0.3, 12.0), -1.0, 1.0)
	return {"res": r, "com": c, "ind": i, "office": c}


func upkeep() -> float:
	var u := 0.0
	for t in tiles:
		u += float(GameData.zone(t["type"]).get("upkeep", 0.0)) if t["type"] != "" else 0.0
	return u


func income() -> float:
	var inc := population() * GameData.TAX_PER_RESIDENT * (0.6 + happiness() / 250.0)
	for type in GameData.PAY_PER_JOB:
		inc += jobs(type) * float(GameData.PAY_PER_JOB[type])
	return inc


func tick(dt: float) -> void:
	clock += dt
	var dem := demand()
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		if not GameData.is_lot(t["type"]):
			continue
		var c := cell(i)
		if not connected(c):
			continue
		var want := float(dem.get(t["type"], 0.0))
		var rate := 0.06 * (0.4 + maxf(want, -0.3))
		if t["type"] == "res":
			rate *= 0.5 + happiness_at(c) / 100.0
		t["growth"] = clampf(float(t["growth"]) + rate * dt, 0.0, 1.0)
		if float(t["growth"]) >= 1.0 and int(t["level"]) < 3 and _can_level(t, c):
			t["level"] = int(t["level"]) + 1
			t["growth"] = 0.25
			tile_changed.emit(c)
	if clock >= GameData.DAY:
		clock -= GameData.DAY
		day += 1
		last_net = int(round(income() - upkeep()))
		money += last_net
		day_passed.emit(last_net)
	var s := GameData.milestone_index(population())
	if s > stage:
		stage = s
		money += int(GameData.MILESTONES[s]["reward"])
		milestone.emit(s)


## Homes need happy neighbourhoods to grow taller; businesses need customers.
func _can_level(t: Dictionary, c: Vector2i) -> bool:
	var next := int(t["level"]) + 1
	match t["type"]:
		"res":
			return happiness_at(c) >= (55 if next == 2 else 70)
		"com":
			return population() >= (60 if next == 2 else 200)
		"office":
			return population() >= (350 if next == 2 else 900)
		"ind":
			return population() >= (40 if next == 2 else 150)
	return false


func to_dict() -> Dictionary:
	return {"tiles": tiles, "money": money, "day": day, "stage": stage, "clock": clock}


func from_dict(d: Dictionary) -> void:
	var list: Array = d.get("tiles", [])
	if list.size() == GameData.COLS * GameData.ROWS:
		for i in list.size():
			var t: Dictionary = list[i]
			tiles[i] = {"type": str(t.get("type", "")), "level": int(t.get("level", 0)), "growth": float(t.get("growth", 0.0))}
	money = int(d.get("money", GameData.START_MONEY))
	day = int(d.get("day", 1))
	stage = int(d.get("stage", 0))
	clock = float(d.get("clock", 0.0))
