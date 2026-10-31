class_name GameData
## Buildings, costs, the map and the mission chain for the Mars colony.
## Pure data and maths so the unit tests can check it.

const COLS := 12
const ROWS := 9
const CELL := 2.0
const HQ_CELL := Vector2i(5, 4)
const HQ_MAX := 5

## power: + makes, - uses. Outputs are per second at level 1.
const BUILDINGS := {
	"hq": {"name": "Command Hub", "desc": "The heart of the colony. Upgrade it to unlock more.",
		"model": "basemodule_D", "power": 2, "housing": 4, "oxygen": 4, "credits": 0, "ore": 0, "time": 0, "hq": 1},
	"solar": {"name": "Solar Array", "desc": "Clean power. Weak in dust storms.", "model": "solar",
		"power": 4, "credits": 60, "ore": 0, "time": 4, "hq": 1, "icon": "bolt"},
	"hab": {"name": "Habitat", "desc": "Homes for 5 colonists.", "model": "basemodule_A",
		"power": -1, "housing": 5, "credits": 80, "ore": 20, "time": 6, "hq": 1, "icon": "colonist"},
	"drill": {"name": "Ore Drill", "desc": "Mines ore. Build it on an ore deposit.", "model": "drill_structure",
		"power": -2, "mine": 0.6, "credits": 100, "ore": 0, "time": 6, "hq": 1, "on": "ore", "icon": "ore"},
	"dome": {"name": "Greenhouse", "desc": "Makes oxygen for 8 colonists.", "model": "basemodule_E",
		"power": -1, "oxygen": 8, "credits": 120, "ore": 40, "time": 8, "hq": 1, "icon": "oxygen"},
	"wind": {"name": "Wind Turbine", "desc": "Steady power, even in storms.", "model": "windturbine_tall",
		"power": 3, "credits": 150, "ore": 60, "time": 8, "hq": 2, "icon": "bolt"},
	"pad": {"name": "Landing Pad", "desc": "Rockets bring new colonists twice as fast.", "model": "landingpad_large",
		"power": -1, "credits": 220, "ore": 80, "time": 10, "hq": 2, "icon": "rocket"},
	"depot": {"name": "Cargo Depot", "desc": "Stores 300 more ore.", "model": "cargodepot_A",
		"power": 0, "storage": 300, "credits": 180, "ore": 60, "time": 8, "hq": 2, "icon": "box"},
	"garage": {"name": "Rover Bay", "desc": "Rovers haul ore: drills work 20% faster.", "model": "basemodule_garage",
		"power": -1, "boost_ore": 0.2, "credits": 260, "ore": 120, "time": 10, "hq": 3, "icon": "rover"},
	"lab": {"name": "Research Lab", "desc": "Colonists earn 15% more credits.", "model": "basemodule_C",
		"power": -2, "boost_credits": 0.15, "credits": 350, "ore": 150, "time": 12, "hq": 3, "icon": "lab"},
	"crystal": {"name": "Crystal Extractor", "desc": "Slowly mines rare crystals. Build it on a crystal vein.",
		"model": "structure_tall", "power": -3, "crystal": 0.02, "credits": 400, "ore": 200, "time": 14, "hq": 3,
		"on": "crystal", "icon": "crystal"},
}
const BUILD_ORDER := ["solar", "hab", "drill", "dome", "wind", "pad", "depot", "garage", "lab", "crystal"]
## How many of each building every Command Hub level allows.
const LIMITS := {"solar": [2, 4, 6, 8, 10], "hab": [2, 3, 5, 7, 9], "drill": [2, 3, 4, 5, 6], "dome": [1, 2, 3, 5, 7],
	"wind": [0, 2, 3, 4, 6], "pad": [0, 1, 1, 1, 2], "depot": [0, 1, 2, 2, 3], "garage": [0, 0, 1, 1, 2],
	"lab": [0, 0, 1, 2, 2], "crystal": [0, 0, 1, 2, 2]}
const MAX_LEVEL := 5
const CREDITS_PER_COLONIST := 0.35
const BASE_STORAGE := 250
const OFFLINE_CAP := 7200.0
const LANDER_EVERY := 24.0
const LANDER_COLONISTS := 2

const ORE_CELLS := [Vector2i(1, 1), Vector2i(2, 6), Vector2i(9, 1), Vector2i(10, 7), Vector2i(7, 7), Vector2i(4, 1)]
const CRYSTAL_CELLS := [Vector2i(0, 4), Vector2i(11, 3)]

const MISSIONS := [
	{"text": "Build a Solar Array", "kind": "count", "what": "solar", "goal": 1, "credits": 60, "crystals": 1},
	{"text": "Build a Habitat", "kind": "count", "what": "hab", "goal": 1, "credits": 80, "crystals": 1},
	{"text": "Build an Ore Drill on a deposit", "kind": "count", "what": "drill", "goal": 1, "credits": 100, "crystals": 1},
	{"text": "Build a Greenhouse", "kind": "count", "what": "dome", "goal": 1, "credits": 120, "crystals": 2},
	{"text": "Reach 10 colonists", "kind": "colonists", "goal": 10, "credits": 150, "crystals": 2},
	{"text": "Upgrade the Command Hub to level 2", "kind": "hq", "goal": 2, "credits": 200, "crystals": 3},
	{"text": "Build a Landing Pad", "kind": "count", "what": "pad", "goal": 1, "credits": 200, "crystals": 2},
	{"text": "Build a Wind Turbine", "kind": "count", "what": "wind", "goal": 1, "credits": 150, "crystals": 2},
	{"text": "Build a Cargo Depot", "kind": "count", "what": "depot", "goal": 1, "credits": 150, "crystals": 2},
	{"text": "Reach 25 colonists", "kind": "colonists", "goal": 25, "credits": 300, "crystals": 3},
	{"text": "Blast 10 meteors", "kind": "meteors", "goal": 10, "credits": 250, "crystals": 4},
	{"text": "Upgrade the Command Hub to level 3", "kind": "hq", "goal": 3, "credits": 400, "crystals": 4},
	{"text": "Build a Rover Bay", "kind": "count", "what": "garage", "goal": 1, "credits": 300, "crystals": 3},
	{"text": "Build a Research Lab", "kind": "count", "what": "lab", "goal": 1, "credits": 350, "crystals": 3},
	{"text": "Build a Crystal Extractor", "kind": "count", "what": "crystal", "goal": 1, "credits": 400, "crystals": 5},
	{"text": "Reach 50 colonists", "kind": "colonists", "goal": 50, "credits": 600, "crystals": 5},
	{"text": "Upgrade any building to level 5", "kind": "max_level", "goal": 5, "credits": 600, "crystals": 5},
	{"text": "Upgrade the Command Hub to level 4", "kind": "hq", "goal": 4, "credits": 800, "crystals": 6},
	{"text": "Reach 80 colonists", "kind": "colonists", "goal": 80, "credits": 1000, "crystals": 8},
	{"text": "Upgrade the Command Hub to level 5", "kind": "hq", "goal": 5, "credits": 1500, "crystals": 10},
	{"text": "Reach 120 colonists", "kind": "colonists", "goal": 120, "credits": 2500, "crystals": 15},
]


static func info(type: String) -> Dictionary:
	return BUILDINGS.get(type, {})


static func limit(type: String, hq_level: int) -> int:
	if type == "hq":
		return 1
	var l: Array = LIMITS.get(type, [0])
	return int(l[clampi(hq_level - 1, 0, l.size() - 1)])


## The first Command Hub level that allows [param type].
static func unlock_level(type: String) -> int:
	for lv in range(1, HQ_MAX + 1):
		if limit(type, lv) > 0:
			return lv
	return HQ_MAX + 1


## Cost to build (level 0 -> 1) or upgrade (level n -> n+1): [credits, ore].
static func cost(type: String, level: int) -> Array:
	var b := info(type)
	if type == "hq":
		var k := pow(2.3, level - 1)
		return [int(round(300 * k)), int(round(120 * k))]
	var mult := pow(1.75, level)
	return [int(round(float(b["credits"]) * mult)), int(round(float(b["ore"]) * mult))]


static func build_time(type: String, level: int) -> float:
	var b := info(type)
	if type == "hq":
		return 10.0 * level
	return float(b["time"]) * (1.0 + 0.6 * level)


## Output multiplier for a building level.
static func level_mult(level: int) -> float:
	return 1.0 + 0.5 * (level - 1)


## Crystals to finish a build right now.
static func rush_cost(seconds_left: float) -> int:
	return maxi(1, int(ceil(seconds_left / 20.0)))


static func repair_cost(type: String, level: int) -> int:
	var c: Array = cost(type, maxi(level - 1, 0))
	return maxi(10, int(c[0]) / 4)


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (COLS - 1) / 2.0) * CELL, 0.0, (cell.y - (ROWS - 1) / 2.0) * CELL)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x / CELL + (COLS - 1) / 2.0)), int(round(p.z / CELL + (ROWS - 1) / 2.0)))


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


static func deposit(cell: Vector2i) -> String:
	if ORE_CELLS.has(cell):
		return "ore"
	if CRYSTAL_CELLS.has(cell):
		return "crystal"
	return ""
