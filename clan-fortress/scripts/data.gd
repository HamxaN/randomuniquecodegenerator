class_name GameData
## Every rule of the game: what each building costs and does, troop stats, how
## the enemy villages are laid out, and how stars and loot are worked out.
## Pure data and maths, so it is unit tested.

const MAX_LEVEL := 5
const BUILDERS := 2

## Per-level arrays are indexed by level - 1. "limit" is indexed by Town Hall level - 1.
const BUILDINGS := {
	"townhall": {"name": "Town Hall", "model": "castle", "desc": "The heart of your village. Upgrade it to unlock more buildings.",
		"hp": [1400, 2000, 2700, 3500, 4400], "cost": [0, 1200, 4000, 10000, 24000], "res": "gold",
		"time": [0, 40, 150, 360, 720], "limit": [1, 1, 1, 1, 1], "xp": 60},
	"goldmine": {"name": "Gold Mine", "model": "mine", "desc": "Digs up gold over time. Tap it to collect.",
		"hp": [400, 500, 620, 760, 920], "cost": [150, 450, 1200, 3000, 7000], "res": "wood",
		"time": [5, 30, 90, 240, 540], "limit": [1, 2, 3, 4, 5], "xp": 15,
		"produces": "gold", "rate": [24, 40, 64, 96, 140], "capacity": [400, 900, 1800, 3200, 5000]},
	"lumbermill": {"name": "Lumber Mill", "model": "lumbermill", "desc": "Cuts wood over time. Wood trains troops.",
		"hp": [400, 500, 620, 760, 920], "cost": [150, 450, 1200, 3000, 7000], "res": "gold",
		"time": [5, 30, 90, 240, 540], "limit": [1, 2, 3, 4, 5], "xp": 15,
		"produces": "wood", "rate": [24, 40, 64, 96, 140], "capacity": [400, 900, 1800, 3200, 5000]},
	"barracks": {"name": "Barracks", "model": "barracks", "desc": "Trains your army. Upgrade it to unlock new troops.",
		"hp": [500, 650, 800, 1000, 1200], "cost": [200, 900, 2600, 6500, 14000], "res": "wood",
		"time": [5, 40, 120, 300, 600], "limit": [1, 1, 2, 2, 3], "xp": 20},
	"house": {"name": "Army Camp", "model": "home_A", "desc": "Houses your troops. Each level adds room for 6 more.",
		"hp": [300, 380, 460, 560, 680], "cost": [100, 400, 1100, 2800, 6500], "res": "gold",
		"time": [5, 25, 80, 200, 480], "limit": [2, 3, 4, 5, 6], "xp": 10, "housing": 6},
	"archertower": {"name": "Archer Tower", "model": "tower_A", "desc": "Shoots arrows at attackers in range.",
		"hp": [450, 560, 700, 860, 1050], "cost": [300, 900, 2400, 5800, 12500], "res": "gold",
		"time": [10, 45, 140, 330, 660], "limit": [1, 2, 3, 4, 4], "xp": 25,
		"defense": true, "range": 6.5, "damage": [12, 16, 21, 27, 34], "rate": 1.0, "splash": 0.0},
	"catapult": {"name": "Catapult", "model": "tower_catapult", "desc": "Hurls boulders that hit everything they land on.",
		"hp": [600, 740, 900, 1080, 1300], "cost": [900, 2400, 5600, 11000, 22000], "res": "gold",
		"time": [30, 90, 240, 480, 900], "limit": [0, 1, 2, 2, 3], "xp": 35,
		"defense": true, "range": 8.5, "min_range": 2.2, "damage": [30, 40, 52, 66, 82], "rate": 0.32, "splash": 1.6},
	"blacksmith": {"name": "Blacksmith", "model": "blacksmith", "desc": "Upgrades your troops. Each level raises their max level.",
		"hp": [500, 620, 760, 920, 1100], "cost": [800, 2500, 6000, 12000, 24000], "res": "wood",
		"time": [20, 80, 220, 450, 800], "limit": [0, 1, 1, 1, 1], "xp": 30},
	"market": {"name": "Market", "model": "market", "desc": "Traders pay you a little gold and wood every minute.",
		"hp": [400, 500, 620, 760, 920], "cost": [600, 1800, 4500, 9000, 18000], "res": "wood",
		"time": [15, 60, 180, 400, 720], "limit": [0, 0, 1, 1, 2], "xp": 25,
		"produces": "both", "rate": [12, 20, 32, 48, 70], "capacity": [300, 600, 1200, 2000, 3200]},
	"well": {"name": "Well", "model": "well", "desc": "A pretty well. Decoration.",
		"hp": [150, 150, 150, 150, 150], "cost": [80, 80, 80, 80, 80], "res": "gold",
		"time": [2, 2, 2, 2, 2], "limit": [2, 3, 4, 5, 6], "xp": 3, "max_level": 1},
	"windmill": {"name": "Windmill", "model": "windmill", "desc": "A windmill to watch turn. Decoration.",
		"hp": [250, 250, 250, 250, 250], "cost": [250, 250, 250, 250, 250], "res": "wood",
		"time": [3, 3, 3, 3, 3], "limit": [0, 1, 2, 2, 3], "xp": 5, "max_level": 1},
}

const SHOP_ORDER := ["goldmine", "lumbermill", "house", "archertower", "catapult", "barracks", "blacksmith", "market", "well", "windmill"]

## Per-level arrays indexed by troop level - 1.
const TROOPS := {
	"barbarian": {"name": "Barbarian", "model": "Barbarian", "keep": ["2H_Axe"], "barracks": 1,
		"hp": [85, 100, 118, 138, 160], "damage": [12, 14, 17, 20, 24], "rate": 1.0, "range": 0.9, "speed": 2.1,
		"housing": 1, "cost": 25, "train": 2.0, "target": "any", "splash": 0.0, "color": Color("e8a33a"),
		"desc": "Charges the nearest building."},
	"archer": {"name": "Archer", "model": "Rogue_Hooded", "keep": ["2H_Crossbow"], "barracks": 2,
		"hp": [36, 42, 50, 58, 68], "damage": [10, 12, 14, 17, 20], "rate": 1.0, "range": 4.6, "speed": 2.3,
		"housing": 1, "cost": 50, "train": 3.0, "target": "any", "splash": 0.0, "color": Color("5cc46a"),
		"desc": "Fires bolts from behind the front line."},
	"knight": {"name": "Knight", "model": "Knight", "keep": ["1H_Sword", "Round_Shield"], "barracks": 3,
		"hp": [420, 500, 590, 690, 800], "damage": [22, 26, 31, 36, 42], "rate": 0.9, "range": 0.9, "speed": 1.5,
		"housing": 5, "cost": 260, "train": 8.0, "target": "defense", "splash": 0.0, "color": Color("4d9be8"),
		"desc": "Armoured. Goes straight for towers."},
	"mage": {"name": "Wizard", "model": "Mage", "keep": ["2H_Staff"], "barracks": 4,
		"hp": [80, 92, 106, 122, 140], "damage": [42, 50, 60, 72, 86], "rate": 0.7, "range": 4.2, "speed": 1.8,
		"housing": 4, "cost": 360, "train": 10.0, "target": "any", "splash": 1.4, "color": Color("a86bff"),
		"desc": "Fireballs that hit everything nearby."},
}

const TROOP_ORDER := ["barbarian", "archer", "knight", "mage"]
const BASE_HOUSING := 10
const BATTLE_SECONDS := 150.0


static func building(kind: String) -> Dictionary:
	return BUILDINGS[kind]


static func troop(kind: String) -> Dictionary:
	return TROOPS[kind]


static func max_level(kind: String) -> int:
	return int(BUILDINGS[kind].get("max_level", MAX_LEVEL))


static func at_level(values: Array, level: int) -> Variant:
	return values[clampi(level, 1, values.size()) - 1]


## How many of a building the Town Hall level allows.
static func limit(kind: String, th_level: int) -> int:
	return int(at_level(BUILDINGS[kind]["limit"], th_level))


## Cost to build (level 1) or to upgrade to [param level].
static func cost(kind: String, level: int) -> int:
	return int(at_level(BUILDINGS[kind]["cost"], level))


static func build_time(kind: String, level: int) -> float:
	return float(at_level(BUILDINGS[kind]["time"], level))


## Gems to finish a build right now: one per 20 seconds left, at least one.
static func gems_to_finish(seconds_left: float) -> int:
	return maxi(1, int(ceil(seconds_left / 20.0)))


## Resources a producer has made in [param seconds], capped by its storage.
static func produced(kind: String, level: int, seconds: float) -> int:
	var b: Dictionary = BUILDINGS[kind]
	if not b.has("produces"):
		return 0
	var per_minute := float(at_level(b["rate"], level))
	return mini(int(per_minute * seconds / 60.0), int(at_level(b["capacity"], level)))


## Troops unlocked by the highest barracks level.
static func troops_for_barracks(level: int) -> Array[String]:
	var out: Array[String] = []
	for t in TROOP_ORDER:
		if int(TROOPS[t]["barracks"]) <= level:
			out.append(t)
	return out


static func troop_upgrade_cost(level: int) -> int:
	return 400 * level * level + 200 * level


## Player level from XP.
static func level_for_xp(xp: int) -> int:
	var level := 1
	while xp >= xp_to_reach(level + 1):
		level += 1
	return level


static func xp_to_reach(level: int) -> int:
	return 50 * (level - 1) * level


## Stars for a raid: one for half the village, one for the Town Hall, one for all of it.
static func stars(destroyed_fraction: float, town_hall_down: bool) -> int:
	var s := 0
	if destroyed_fraction >= 0.5:
		s += 1
	if town_hall_down:
		s += 1
	if destroyed_fraction >= 0.999:
		s += 1
	return s


## The enemy villages of the campaign, from easy to hard.
const CAMPAIGN_SIZE := 20
const ENEMY_NAMES := ["Goblin Outpost", "Muddy Hollow", "Rat Creek", "Crow's Nest", "Bramble Fort", "Rusty Gate",
	"Thorn Keep", "Wolf Den", "Ash Hill", "Iron Ford", "Stone Watch", "Grim Harbor", "Red Ridge", "Skull Pass",
	"Ember Hold", "Black Moor", "Storm Peak", "Dragon Rest", "King's Fall", "The Red Citadel"]


static func enemy_name(n: int) -> String:
	return ENEMY_NAMES[clampi(n, 1, CAMPAIGN_SIZE) - 1]


static func enemy_loot(n: int) -> Dictionary:
	return {"gold": 250 + n * 180 + n * n * 12, "wood": 250 + n * 180 + n * n * 12}


## Lays out enemy village [param n]: a list of {type, level, q, r}.
static func enemy_base(n: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 1013 + 7
	var th := clampi(1 + n / 4, 1, MAX_LEVEL)
	var lvl := clampi(1 + n / 5, 1, MAX_LEVEL)
	var out: Array[Dictionary] = []
	var used := {}
	out.append({"type": "townhall", "level": th, "q": 0, "r": 0})
	used[Vector2i(0, 0)] = true
	var plan: Array[String] = []
	for i in mini(1 + n / 3, 4):
		plan.append("archertower")
	for i in mini(n / 5, 3):
		plan.append("catapult")
	for i in mini(2 + n / 4, 5):
		plan.append("goldmine")
	for i in mini(2 + n / 4, 5):
		plan.append("lumbermill")
	for i in mini(2 + n / 3, 6):
		plan.append("house")
	plan.append("barracks")
	if n >= 6:
		plan.append("blacksmith")
	if n >= 9:
		plan.append("market")
	# Defences go in the inner rings, everything else spreads around them.
	for kind in plan:
		var defense: bool = BUILDINGS[kind].has("defense")
		var placed := false
		for attempt in 200:
			var radius := rng.randi_range(1, 2) if defense else rng.randi_range(1, 4)
			var cell := Hex.random_on_ring(rng, radius)
			if used.has(cell):
				continue
			used[cell] = true
			var level := clampi(lvl + (rng.randi_range(-1, 0) if not defense else 0), 1, max_level(kind))
			out.append({"type": kind, "level": level, "q": cell.x, "r": cell.y})
			placed = true
			break
		if not placed:
			break
	return out
