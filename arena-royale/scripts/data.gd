class_name GameData
## Cards, towers, arenas, levels and rewards. Plain data and maths for the
## battle simulation and the unit tests.

const FIELD_W := 18.0     # x from -9 to 9
const FIELD_L := 32.0     # y from -16 (enemy back) to 16 (your back)
const RIVER := 1.2        # half-width of the river
const BRIDGES := [-6.0, 0.0, 6.0]
const BRIDGE_HALF := 1.3
const BATTLE_TIME := 180.0
const OVERTIME := 60.0
const MAX_MANA := 10.0
const MANA_EVERY := 2.8
const DECK_SIZE := 8
const HAND_SIZE := 4
const MAX_LEVEL := 10

## Towers: y is for your side; the enemy mirrors it.
const TOWERS := [
	{"kind": "guard", "x": -5.5, "y": 10.5, "hp": 1400, "damage": 45, "range": 7.5, "rate": 0.9},
	{"kind": "guard", "x": 5.5, "y": 10.5, "hp": 1400, "damage": 45, "range": 7.5, "rate": 0.9},
	{"kind": "keep", "x": 0.0, "y": 13.8, "hp": 2600, "damage": 60, "range": 7.0, "rate": 1.0},
]

## Units: hp, damage, range, rate (s between hits), speed, count, splash,
## targets ("any" or "buildings"), radius, and the hero (yours) and skeleton
## (Bone Army) models. Spells have "spell".
const CARDS := {
	"knight": {"name": "Knight", "cost": 3, "hp": 900, "damage": 105, "range": 1.2, "rate": 1.1, "speed": 1.6, "count": 1,
		"splash": 0.0, "targets": "any", "radius": 0.6, "blue": "Knight", "red": "Skeleton_Warrior", "scale": 1.0,
		"desc": "Sturdy sword fighter", "rarity": "common"},
	"archers": {"name": "Archers", "cost": 3, "hp": 280, "damage": 70, "range": 5.5, "rate": 1.0, "speed": 1.8, "count": 2,
		"splash": 0.0, "targets": "any", "radius": 0.5, "blue": "Rogue_Hooded", "red": "Skeleton_Rogue", "scale": 0.9,
		"desc": "A pair of ranged shooters", "rarity": "common"},
	"minions": {"name": "Bone Swarm", "cost": 2, "hp": 110, "damage": 55, "range": 1.0, "rate": 1.0, "speed": 2.3, "count": 5,
		"splash": 0.0, "targets": "any", "radius": 0.45, "blue": "Skeleton_Minion", "red": "Skeleton_Minion", "scale": 0.75,
		"desc": "Five quick little fighters", "rarity": "common"},
	"barbarian": {"name": "Barbarian", "cost": 5, "hp": 1500, "damage": 170, "range": 1.3, "rate": 1.5, "speed": 1.3, "count": 1,
		"splash": 1.3, "targets": "any", "radius": 0.75, "blue": "Barbarian", "red": "Skeleton_Warrior", "scale": 1.25,
		"desc": "Huge axe swings hit a crowd", "rarity": "rare"},
	"mage": {"name": "Mage", "cost": 4, "hp": 520, "damage": 140, "range": 5.5, "rate": 1.6, "speed": 1.6, "count": 1,
		"splash": 1.5, "targets": "any", "radius": 0.55, "blue": "Mage", "red": "Skeleton_Mage", "scale": 1.0,
		"desc": "Fire blasts hit everything nearby", "rarity": "rare"},
	"golem": {"name": "Bone Golem", "cost": 7, "hp": 3400, "damage": 220, "range": 1.4, "rate": 1.8, "speed": 0.95, "count": 1,
		"splash": 0.0, "targets": "buildings", "radius": 1.1, "blue": "Skeleton_Warrior", "red": "Skeleton_Warrior", "scale": 2.0,
		"desc": "Ignores troops and walks to the towers", "rarity": "epic"},
	"rogue": {"name": "Rogue", "cost": 2, "hp": 380, "damage": 90, "range": 1.0, "rate": 0.7, "speed": 2.4, "count": 1,
		"splash": 0.0, "targets": "any", "radius": 0.5, "blue": "Rogue", "red": "Skeleton_Rogue", "scale": 0.95,
		"desc": "Fast, cheap and stabby", "rarity": "common"},
	"catapult": {"name": "Catapult", "cost": 5, "hp": 900, "damage": 130, "range": 10.0, "rate": 2.5, "speed": 0.0, "count": 1,
		"splash": 1.6, "targets": "any", "radius": 1.0, "building": true, "lifetime": 35.0, "blue": "", "red": "",
		"scale": 1.0, "desc": "A building that lobs boulders, then crumbles", "rarity": "rare"},
	"fireball": {"name": "Fireball", "cost": 4, "spell": true, "damage": 380, "radius": 2.6, "tower_share": 0.35,
		"desc": "Burns everything in a circle", "rarity": "rare"},
	"freeze": {"name": "Frost Nova", "cost": 3, "spell": true, "damage": 60, "radius": 3.0, "stun": 3.0, "tower_share": 1.0,
		"desc": "Freezes troops and towers for 3 seconds", "rarity": "epic"},
	"heal": {"name": "Healing Rune", "cost": 3, "spell": true, "heal": 450, "radius": 3.2, "tower_share": 0.0,
		"desc": "Heals your troops in a circle", "rarity": "rare"},
}
const CARD_ORDER := ["knight", "archers", "minions", "rogue", "mage", "barbarian", "catapult", "golem", "fireball", "freeze", "heal"]
const STARTER_DECK := ["knight", "archers", "minions", "rogue", "mage", "barbarian", "fireball", "catapult"]
const RARITY_COLOR := {"common": Color("8fb0d0"), "rare": Color("ff9a1f"), "epic": Color("b06bff")}

const ARENAS := [
	{"name": "Training Meadow", "trophies": 0, "ground": Color(0.42, 0.62, 0.3), "water": Color(0.35, 0.65, 0.9),
		"sky": Color(0.55, 0.78, 0.98), "ai_level": 1, "unlock": ["knight", "archers", "minions", "rogue", "fireball"]},
	{"name": "Bone Canyon", "trophies": 300, "ground": Color(0.62, 0.48, 0.32), "water": Color(0.85, 0.4, 0.18),
		"sky": Color(0.95, 0.7, 0.5), "ai_level": 3, "unlock": ["mage", "barbarian", "catapult", "heal"]},
	{"name": "Frost Keep", "trophies": 700, "ground": Color(0.85, 0.9, 0.98), "water": Color(0.45, 0.7, 0.95),
		"sky": Color(0.7, 0.82, 0.98), "ai_level": 6, "unlock": ["golem", "freeze"]},
]


static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})


static func is_spell(id: String) -> bool:
	return bool(card(id).get("spell", false))


## Health and damage grow 8% per card level.
static func level_mult(level: int) -> float:
	return pow(1.08, maxi(level, 1) - 1)


static func upgrade_cost(level: int) -> int:
	return int(round(40.0 * pow(1.9, level - 1)))


static func shards_needed(level: int) -> int:
	return 2 + level * 2


static func arena_index(trophies: int) -> int:
	var idx := 0
	for i in ARENAS.size():
		if trophies >= int(ARENAS[i]["trophies"]):
			idx = i
	return idx


static func unlocked_cards(trophies: int) -> Array:
	var out: Array = []
	for i in arena_index(trophies) + 1:
		out.append_array(ARENAS[i]["unlock"])
	# The starter deck is always yours.
	for id in STARTER_DECK:
		if not out.has(id):
			out.append(id)
	return out


## Trophies and gold for a result: crowns are towers knocked down (keep = 3).
static func trophy_change(won: bool, draw: bool, crowns: int) -> int:
	if draw:
		return 0
	return 28 + crowns * 2 if won else -16


static func gold_reward(won: bool, crowns: int, arena: int) -> int:
	return (40 + crowns * 15 + arena * 20) if won else 10 + crowns * 5


## The mana gained per second (double in the last minute).
static func mana_rate(time_left: float) -> float:
	return (2.0 if time_left <= 60.0 else 1.0) / MANA_EVERY


## Mirrors a point from your side to the enemy's.
static func mirror(p: Vector2) -> Vector2:
	return Vector2(p.x, -p.y)
