class_name GameData
## The rules of the dungeon: heroes, monsters, loot and its rarities, the
## level-up boons offered during a run, permanent talents, and how floors grow.

const HEROES := [
	{"id": "knight", "name": "Sir Aldric", "class": "Knight", "model": "Knight", "keep": ["1H_Sword", "Round_Shield"],
		"hp": 150, "attack": 14, "speed": 5.0, "range": 2.2, "rate": 1.4, "ranged": false, "armor": 0.15,
		"skill": "whirl", "skill_name": "Whirlwind", "skill_desc": "Spin and hit everything around you", "cost": 0, "color": Color("4d9be8")},
	{"id": "barbarian", "name": "Grunhild", "class": "Barbarian", "model": "Barbarian", "keep": ["2H_Axe"],
		"hp": 180, "attack": 20, "speed": 4.8, "range": 2.4, "rate": 1.1, "ranged": false, "armor": 0.05,
		"skill": "slam", "skill_name": "Ground Slam", "skill_desc": "Leap and smash the ground", "cost": 2500, "color": Color("e05a3a")},
	{"id": "rogue", "name": "Vex", "class": "Ranger", "model": "Rogue_Hooded", "keep": ["2H_Crossbow"],
		"hp": 110, "attack": 11, "speed": 5.6, "range": 9.0, "rate": 1.8, "ranged": true, "armor": 0.0,
		"skill": "volley", "skill_name": "Volley", "skill_desc": "Fire a fan of seven bolts", "cost": 4000, "color": Color("5cc46a")},
	{"id": "mage", "name": "Ilyra", "class": "Sorceress", "model": "Mage", "keep": ["2H_Staff"],
		"hp": 100, "attack": 16, "speed": 5.2, "range": 8.0, "rate": 1.2, "ranged": true, "armor": 0.0,
		"skill": "nova", "skill_name": "Frost Nova", "skill_desc": "Blast and freeze nearby foes", "cost": 6000, "color": Color("a86bff")},
]

const ENEMIES := {
	"minion": {"name": "Skeleton", "model": "Skeleton_Minion", "gear": "Skeleton_Blade", "hp": 40.0, "speed": 3.6,
		"damage": 9.0, "reach": 1.7, "cooldown": 1.2, "ranged": false, "gold": 3, "xp": 8, "scale": 1.0},
	"archer": {"name": "Bone Archer", "model": "Skeleton_Rogue", "gear": "Skeleton_Crossbow", "hp": 34.0, "speed": 3.0,
		"damage": 10.0, "reach": 9.0, "cooldown": 2.2, "ranged": true, "gold": 4, "xp": 10, "scale": 1.0},
	"warrior": {"name": "Bone Knight", "model": "Skeleton_Warrior", "gear": "Skeleton_Axe", "hp": 110.0, "speed": 2.8,
		"damage": 17.0, "reach": 2.0, "cooldown": 1.5, "ranged": false, "gold": 7, "xp": 18, "scale": 1.15},
	"mage": {"name": "Necromancer", "model": "Skeleton_Mage", "gear": "Skeleton_Staff", "hp": 55.0, "speed": 2.8,
		"damage": 14.0, "reach": 8.5, "cooldown": 2.6, "ranged": true, "gold": 6, "xp": 15, "scale": 1.0},
	"boss": {"name": "The Bone King", "model": "Skeleton_Warrior", "gear": "Skeleton_Axe", "hp": 900.0, "speed": 2.6,
		"damage": 30.0, "reach": 3.4, "cooldown": 2.2, "ranged": false, "gold": 80, "xp": 150, "scale": 2.1},
	"lich": {"name": "The Lich", "model": "Skeleton_Mage", "gear": "Skeleton_Staff", "hp": 700.0, "speed": 2.4,
		"damage": 22.0, "reach": 9.0, "cooldown": 1.6, "ranged": true, "gold": 80, "xp": 150, "scale": 2.0},
}

const SLOTS := ["weapon", "armor", "amulet"]
const RARITIES := [
	{"id": "common", "name": "Common", "color": Color("c9ced6"), "mult": 1.0, "weight": 60},
	{"id": "rare", "name": "Rare", "color": Color("4fa3ff"), "mult": 1.5, "weight": 28},
	{"id": "epic", "name": "Epic", "color": Color("b86bff"), "mult": 2.2, "weight": 10},
	{"id": "legendary", "name": "Legendary", "color": Color("ffb02e"), "mult": 3.2, "weight": 2},
]
const PREFIXES := ["Rusty", "Grim", "Iron", "Blessed", "Cursed", "Ancient", "Storm", "Ember", "Frost", "Shadow", "Royal", "Dragon"]
const BASES := {
	"weapon": ["Blade", "Cleaver", "Edge", "Fang", "Reaver", "Brand"],
	"armor": ["Mail", "Plate", "Cuirass", "Hauberk", "Aegis", "Vestments"],
	"amulet": ["Charm", "Talisman", "Pendant", "Sigil", "Relic", "Locket"],
}

## Boons offered on level-up during a run.
const BOONS := [
	{"id": "atk", "name": "Sharpened", "desc": "+20% attack", "icon": "sword"},
	{"id": "speed", "name": "Swift Strikes", "desc": "+18% attack speed", "icon": "bolt"},
	{"id": "hp", "name": "Vigor", "desc": "+40 max health, heal fully", "icon": "heart"},
	{"id": "crit", "name": "Precision", "desc": "+12% critical chance", "icon": "star"},
	{"id": "move", "name": "Fleet Foot", "desc": "+12% move speed", "icon": "boot"},
	{"id": "leech", "name": "Vampirism", "desc": "Heal 3% of damage dealt", "icon": "drop"},
	{"id": "skill", "name": "Arcane Focus", "desc": "Skill recharges 25% faster", "icon": "skill"},
	{"id": "multishot", "name": "Cleave", "desc": "Attacks hit an extra foe", "icon": "axe"},
	{"id": "gold", "name": "Greed", "desc": "+30% gold from foes", "icon": "coin"},
]

## Permanent talents bought with gold at camp.
const TALENTS := [
	{"id": "might", "name": "Might", "desc": "+6% attack per rank", "max": 10, "icon": "sword"},
	{"id": "toughness", "name": "Toughness", "desc": "+8% health per rank", "max": 10, "icon": "heart"},
	{"id": "fortune", "name": "Fortune", "desc": "+8% gold per rank", "max": 10, "icon": "coin"},
	{"id": "potions", "name": "Alchemy", "desc": "+1 potion per run per rank", "max": 3, "icon": "potion"},
]

const POTION_HEAL := 0.4
const BASE_POTIONS := 2
const SKILL_COOLDOWN := 8.0


static func hero(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return HEROES[0]


static func talent_cost(rank: int) -> int:
	return 200 + rank * rank * 120


## How many rooms a floor has (start and boss included).
static func room_count(floor_n: int) -> int:
	return clampi(5 + floor_n / 2, 5, 11)


static func monster_scale(floor_n: int) -> float:
	return 1.0 + 0.22 * float(floor_n - 1)


## The monsters of one fight room, in spawn order.
static func room_monsters(floor_n: int, room_index: int, seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[String] = []
	var count := 3 + floor_n / 2 + room_index / 2 + rng.randi_range(0, 2)
	for i in mini(count, 12):
		var r := rng.randf()
		var kind := "minion"
		if floor_n >= 3 and r > 0.85:
			kind = "mage"
		elif floor_n >= 2 and r > 0.68:
			kind = "warrior"
		elif r > 0.5:
			kind = "archer"
		out.append(kind)
	return out


static func boss_for(floor_n: int) -> String:
	return "boss" if floor_n % 2 == 1 else "lich"


## A random piece of gear for [param floor_n]. [param luck] tilts rarity upward.
static func roll_item(floor_n: int, rng: RandomNumberGenerator, luck: float = 0.0) -> Dictionary:
	var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var total := 0.0
	for r in RARITIES:
		total += float(r["weight"])
	var pick := rng.randf() * total * (1.0 - clampf(luck, 0.0, 0.8))
	var rarity: Dictionary = RARITIES[0]
	var acc := 0.0
	for r in RARITIES:
		acc += float(r["weight"])
		if pick <= acc:
			rarity = r
			break
	if luck > 0.0:
		var i := RARITIES.find(rarity)
		if rng.randf() < luck:
			rarity = RARITIES[mini(i + 1, RARITIES.size() - 1)]
	var power := int(round((6.0 + floor_n * 3.0) * float(rarity["mult"]) * rng.randf_range(0.85, 1.15)))
	var bases: Array = BASES[slot]
	var item_name := "%s %s" % [PREFIXES[rng.randi_range(0, PREFIXES.size() - 1)], bases[rng.randi_range(0, bases.size() - 1)]]
	return {"slot": slot, "rarity": rarity["id"], "name": item_name, "power": power}


static func rarity(id: String) -> Dictionary:
	for r in RARITIES:
		if r["id"] == id:
			return r
	return RARITIES[0]


## What an item's power means for its slot.
static func item_stat(item: Dictionary) -> String:
	match item.get("slot", ""):
		"weapon":
			return "+%d Attack" % int(item["power"])
		"armor":
			return "+%d Health" % (int(item["power"]) * 4)
		_:
			return "+%d%% Crit, +%d%% Gold" % [int(item["power"]) / 3, int(item["power"]) / 2]


static func sell_value(item: Dictionary) -> int:
	return int(item.get("power", 0)) * 4


static func xp_for_level(level: int) -> int:
	return 30 + level * 25


## Picks three different boons.
static func boon_choices(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool := BOONS.duplicate()
	var out: Array[Dictionary] = []
	for i in 3:
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	return out
