class_name GameData
## Heroes, weapons, passive relics, the horde's growth over the night, XP and
## the permanent upgrades. Plain data and maths so the unit tests can check it.

const NIGHT_LENGTH := 600.0      # survive ten minutes until dawn
const BOSS_TIMES := [180.0, 360.0, 540.0]
const MAX_WEAPONS := 6
const MAX_RELICS := 6
const MAX_LEVEL := 5

const HEROES := [
	{"id": "knight", "name": "Sir Aldric", "model": "Knight", "weapon": "axes", "hp": 120, "speed": 5.0, "cost": 0,
		"perk": "Starts with Spinning Axes and extra armour", "armor": 1},
	{"id": "mage", "name": "Ilyra", "model": "Mage", "weapon": "bolt", "hp": 90, "speed": 5.2, "cost": 600,
		"perk": "Starts with Magic Bolt; weapons fire 10% faster", "haste": 0.1},
	{"id": "rogue", "name": "Vex", "model": "Rogue_Hooded", "weapon": "daggers", "hp": 95, "speed": 5.8, "cost": 900,
		"perk": "Starts with Throwing Daggers; moves faster", "armor": 0},
	{"id": "barbarian", "name": "Grunhild", "model": "Barbarian", "weapon": "aura", "hp": 150, "speed": 4.8, "cost": 1400,
		"perk": "Starts with Holy Ring and a lot of health", "armor": 1},
]

## Per-level stats. damage, cooldown (s), count, area, speed (for projectiles).
const WEAPONS := {
	"bolt": {"name": "Magic Bolt", "desc": "Homing bolts at the nearest foe", "icon": "bolt", "color": Color(0.55, 0.75, 1.0),
		"levels": [
			{"damage": 14, "cooldown": 1.0, "count": 1, "area": 1.0, "speed": 16.0},
			{"damage": 16, "cooldown": 0.9, "count": 2, "area": 1.0, "speed": 17.0},
			{"damage": 20, "cooldown": 0.85, "count": 2, "area": 1.1, "speed": 18.0},
			{"damage": 24, "cooldown": 0.75, "count": 3, "area": 1.2, "speed": 19.0},
			{"damage": 30, "cooldown": 0.65, "count": 4, "area": 1.3, "speed": 20.0}]},
	"axes": {"name": "Spinning Axes", "desc": "Axes circle around you", "icon": "axe", "color": Color(0.85, 0.85, 0.9),
		"levels": [
			{"damage": 12, "cooldown": 0.45, "count": 2, "area": 2.2, "speed": 3.2},
			{"damage": 14, "cooldown": 0.42, "count": 3, "area": 2.4, "speed": 3.4},
			{"damage": 18, "cooldown": 0.4, "count": 3, "area": 2.7, "speed": 3.6},
			{"damage": 22, "cooldown": 0.38, "count": 4, "area": 3.0, "speed": 3.8},
			{"damage": 28, "cooldown": 0.35, "count": 5, "area": 3.3, "speed": 4.2}]},
	"daggers": {"name": "Throwing Daggers", "desc": "Fast knives where you're heading", "icon": "dagger", "color": Color(0.9, 0.9, 1.0),
		"levels": [
			{"damage": 10, "cooldown": 0.5, "count": 1, "area": 1.0, "speed": 22.0},
			{"damage": 12, "cooldown": 0.45, "count": 2, "area": 1.0, "speed": 23.0},
			{"damage": 15, "cooldown": 0.4, "count": 2, "area": 1.0, "speed": 24.0},
			{"damage": 18, "cooldown": 0.38, "count": 3, "area": 1.1, "speed": 25.0},
			{"damage": 22, "cooldown": 0.32, "count": 4, "area": 1.2, "speed": 26.0}]},
	"aura": {"name": "Holy Ring", "desc": "Burns everything close to you", "icon": "ring", "color": Color(1.0, 0.85, 0.4),
		"levels": [
			{"damage": 6, "cooldown": 0.5, "count": 1, "area": 2.4, "speed": 0.0},
			{"damage": 8, "cooldown": 0.5, "count": 1, "area": 2.8, "speed": 0.0},
			{"damage": 10, "cooldown": 0.45, "count": 1, "area": 3.2, "speed": 0.0},
			{"damage": 13, "cooldown": 0.45, "count": 1, "area": 3.6, "speed": 0.0},
			{"damage": 16, "cooldown": 0.4, "count": 1, "area": 4.2, "speed": 0.0}]},
	"lightning": {"name": "Storm Call", "desc": "Lightning strikes random foes", "icon": "lightning", "color": Color(0.7, 0.85, 1.0),
		"levels": [
			{"damage": 30, "cooldown": 2.2, "count": 2, "area": 1.4, "speed": 0.0},
			{"damage": 34, "cooldown": 2.0, "count": 3, "area": 1.5, "speed": 0.0},
			{"damage": 40, "cooldown": 1.8, "count": 3, "area": 1.7, "speed": 0.0},
			{"damage": 48, "cooldown": 1.6, "count": 4, "area": 1.9, "speed": 0.0},
			{"damage": 60, "cooldown": 1.4, "count": 5, "area": 2.2, "speed": 0.0}]},
	"bomb": {"name": "Pumpkin Bomb", "desc": "Lobbed bombs that burst in fire", "icon": "bomb", "color": Color(1.0, 0.55, 0.15),
		"levels": [
			{"damage": 26, "cooldown": 2.6, "count": 1, "area": 2.4, "speed": 10.0},
			{"damage": 30, "cooldown": 2.4, "count": 1, "area": 2.7, "speed": 10.0},
			{"damage": 36, "cooldown": 2.2, "count": 2, "area": 3.0, "speed": 10.0},
			{"damage": 44, "cooldown": 2.0, "count": 2, "area": 3.3, "speed": 10.0},
			{"damage": 55, "cooldown": 1.8, "count": 3, "area": 3.8, "speed": 10.0}]},
}

## Passive relics: each level adds "step" to a stat.
const RELICS := {
	"might": {"name": "Ember Heart", "desc": "+10% damage", "icon": "might", "stat": "might", "step": 0.1},
	"haste": {"name": "Hourglass", "desc": "Weapons fire 8% faster", "icon": "clock", "stat": "haste", "step": 0.08},
	"boots": {"name": "Wind Boots", "desc": "+8% move speed", "icon": "shoe", "stat": "speed", "step": 0.08},
	"vigor": {"name": "Troll Blood", "desc": "+20 max health", "icon": "heart", "stat": "hp", "step": 20.0},
	"magnet": {"name": "Lodestone", "desc": "Pick up gems from further away", "icon": "magnet", "stat": "magnet", "step": 0.35},
	"regen": {"name": "Moon Charm", "desc": "Heal 0.5 health a second", "icon": "moon", "stat": "regen", "step": 0.5},
	"area": {"name": "Giant's Ring", "desc": "+10% weapon area", "icon": "area", "stat": "area", "step": 0.1},
}

## Permanent upgrades bought with gold between runs.
const META := [
	{"id": "might", "name": "Might", "desc": "+5% damage", "max": 5, "base": 120, "icon": "might"},
	{"id": "armor", "name": "Armour", "desc": "-1 damage taken", "max": 3, "base": 200, "icon": "shield"},
	{"id": "hp", "name": "Max Health", "desc": "+10 health", "max": 5, "base": 100, "icon": "heart"},
	{"id": "speed", "name": "Swiftness", "desc": "+4% move speed", "max": 3, "base": 150, "icon": "shoe"},
	{"id": "magnet", "name": "Attraction", "desc": "+15% pickup range", "max": 3, "base": 100, "icon": "magnet"},
	{"id": "greed", "name": "Greed", "desc": "+10% gold", "max": 5, "base": 140, "icon": "gold"},
	{"id": "revival", "name": "Second Wind", "desc": "Revive once per run", "max": 1, "base": 900, "icon": "up"},
]

## Enemy kinds: hp, speed, damage per touch, xp, model (or "wisp" for the cheap glowing swarm).
const ENEMIES := {
	"wisp": {"hp": 8, "speed": 3.6, "damage": 4, "xp": 1, "model": "", "scale": 1.0},
	"minion": {"hp": 22, "speed": 2.8, "damage": 7, "xp": 2, "model": "Skeleton_Minion", "scale": 0.9},
	"rogue": {"hp": 18, "speed": 4.2, "damage": 6, "xp": 2, "model": "Skeleton_Rogue", "scale": 0.9},
	"warrior": {"hp": 60, "speed": 2.4, "damage": 12, "xp": 5, "model": "Skeleton_Warrior", "scale": 1.0},
	"mage": {"hp": 40, "speed": 2.6, "damage": 9, "xp": 4, "model": "Skeleton_Mage", "scale": 0.95},
	"boss": {"hp": 1600, "speed": 2.6, "damage": 25, "xp": 60, "model": "Skeleton_Warrior", "scale": 2.4},
}

const MAPS := [
	{"id": "graveyard", "name": "Haunted Graveyard", "ground": Color(0.2, 0.22, 0.2), "fog": Color(0.18, 0.22, 0.32),
		"moon": Color(0.6, 0.7, 1.0), "trees": ["tree_dead_large", "tree_dead_medium", "tree_dead_small", "tree_dead_large_decorated"]},
	{"id": "patch", "name": "Pumpkin Patch", "ground": Color(0.24, 0.2, 0.15), "fog": Color(0.3, 0.2, 0.22),
		"moon": Color(1.0, 0.75, 0.55), "trees": ["tree_pine_orange_large", "tree_pine_orange_medium", "tree_pine_yellow_large", "tree_dead_medium"]},
]


static func hero(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return HEROES[0]


static func weapon_stats(id: String, level: int) -> Dictionary:
	var levels: Array = WEAPONS[id]["levels"]
	return levels[clampi(level, 1, levels.size()) - 1]


## XP needed to go from [param level] to the next.
static func xp_to_next(level: int) -> int:
	return 5 + level * 6 + int(pow(level, 1.6))


## How many enemies the night tries to keep alive at time [param t] (seconds).
static func horde_size(t: float) -> int:
	return int(12 + t * 0.22 + pow(t / 60.0, 2.0) * 3.0)


## Which kinds may spawn at time [param t], with weights.
static func spawn_table(t: float) -> Dictionary:
	var m := t / 60.0
	var table := {"wisp": 6.0, "minion": 4.0}
	if m >= 1.0:
		table["rogue"] = 2.0 + m * 0.3
	if m >= 2.5:
		table["warrior"] = 1.0 + m * 0.25
	if m >= 4.0:
		table["mage"] = 1.0 + m * 0.2
	return table


## Enemy health grows through the night.
static func hp_scale(t: float) -> float:
	return 1.0 + t / 150.0


static func pick_weighted(table: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var x := roll * total
	for k in table:
		x -= float(table[k])
		if x <= 0.0:
			return str(k)
	return str(table.keys()[-1])


static func meta(id: String) -> Dictionary:
	for m in META:
		if m["id"] == id:
			return m
	return {}


static func meta_cost(id: String, level: int) -> int:
	return int(round(float(meta(id)["base"]) * pow(1.7, level)))


## Gold for surviving [param seconds] with [param kills] kills.
static func gold_reward(seconds: float, kills: int, greed: int) -> int:
	return int(round((seconds / 6.0 + kills * 0.25) * (1.0 + 0.1 * greed)))
