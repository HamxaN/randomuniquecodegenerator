class_name GameData
## Zones, prices, growth rules, the budget and the city's milestones. Plain
## data and maths for the city simulation and the unit tests.

const COLS := 16
const ROWS := 12
const CELL := 2.0
const DAY := 10.0           # seconds per in-game day (when the budget is paid)
const START_MONEY := 2500

## cost, upkeep per day, and per-level residents / jobs.
const ZONES := {
	"road": {"name": "Road", "cost": 10, "upkeep": 0.4, "icon": "road"},
	"res": {"name": "Homes", "cost": 60, "upkeep": 0.0, "residents": [10, 26, 60], "icon": "house",
		"models": ["building_A", "building_B", "building_E"], "color": Color("62c63c")},
	"com": {"name": "Shops", "cost": 90, "upkeep": 0.0, "jobs": [8, 20, 44], "icon": "shop",
		"models": ["building_F", "building_D", "building_G"], "color": Color("3f9de0")},
	"ind": {"name": "Factory", "cost": 80, "upkeep": 0.0, "jobs": [16, 30, 52], "icon": "factory",
		"models": ["garage", "garage", "garage"], "color": Color("ffb02e")},
	"office": {"name": "Offices", "cost": 320, "upkeep": 0.0, "jobs": [40, 90, 180], "icon": "office", "unlock": 1,
		"models": ["building_C", "building_H", "building_H"], "color": Color("9b5ce0")},
	"park": {"name": "Park", "cost": 70, "upkeep": 1.5, "icon": "tree", "color": Color("4fa83a")},
	"plaza": {"name": "Plaza", "cost": 240, "upkeep": 3.0, "icon": "fountain", "unlock": 1, "color": Color("bfe8ff")},
}
const TOOL_ORDER := ["road", "res", "com", "ind", "office", "park", "plaza"]
const BULLDOZE_COST := 5

const MILESTONES := [
	{"name": "Village", "pop": 0, "reward": 0},
	{"name": "Town", "pop": 100, "reward": 800},
	{"name": "City", "pop": 300, "reward": 2000},
	{"name": "Metropolis", "pop": 800, "reward": 5000},
	{"name": "Megacity", "pop": 1600, "reward": 12000},
]

const TAX_PER_RESIDENT := 0.6
const PAY_PER_JOB := {"com": 0.45, "ind": 0.35, "office": 0.6}


static func zone(type: String) -> Dictionary:
	return ZONES.get(type, {})


static func is_lot(type: String) -> bool:
	return type == "res" or type == "com" or type == "ind" or type == "office"


static func milestone_index(pop: int) -> int:
	var idx := 0
	for i in MILESTONES.size():
		if pop >= int(MILESTONES[i]["pop"]):
			idx = i
	return idx


## Can [param type] be built at milestone [param stage]?
static func unlocked(type: String, stage: int) -> bool:
	return stage >= int(zone(type).get("unlock", 0))


static func residents(level: int) -> int:
	return int(ZONES["res"]["residents"][clampi(level, 1, 3) - 1])


static func jobs(type: String, level: int) -> int:
	var z := zone(type)
	if not z.has("jobs"):
		return 0
	return int(z["jobs"][clampi(level, 1, 3) - 1])


## Road auto-tiling. Neighbour bits: N=1, E=2, S=4, W=8. The KayKit pieces
## face: straight N+S, corner S+E, T-split N+S+E, junction all four.
## Returns [model, quarter turns].
static func road_piece(mask: int) -> Array:
	var bases := [["road_straight", 5], ["road_corner", 6], ["road_tsplit", 7], ["road_junction", 15]]
	for b in bases:
		var m := int(b[1])
		for k in 4:
			if m == mask:
				return [b[0], k]
			m = rotate_mask(m)
	# Dead ends and lone tiles: a straight piece the right way round.
	if mask == 2 or mask == 8:
		return ["road_straight", 1]
	return ["road_straight", 0]


## One quarter turn (as rotation.y += PI/2): E->N, N->W, W->S, S->E.
static func rotate_mask(m: int) -> int:
	var out := 0
	if m & 2:
		out |= 1
	if m & 1:
		out |= 8
	if m & 8:
		out |= 4
	if m & 4:
		out |= 2
	return out
