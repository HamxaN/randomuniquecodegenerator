class_name GameData
## Every number that shapes a match: operators, weapons, the undead, arenas,
## perks, how waves grow and what they pay. Pure data, so it is unit tested.

const OPERATORS := [
	{"id": "rogue", "name": "GHOST", "model": "Rogue", "role": "Recon", "hp": 100, "speed": 5.8, "damage": 1.0,
		"armor": 0.0, "dash_cd": 0.7, "grenade_cd": 1.0, "cost": 0,
		"perk": "Dash recharges 30% faster", "color": Color("3fd16f")},
	{"id": "knight", "name": "BULWARK", "model": "Knight", "role": "Tank", "hp": 170, "speed": 4.8, "damage": 1.0,
		"armor": 0.2, "dash_cd": 1.0, "grenade_cd": 1.0, "cost": 1500,
		"perk": "Takes 20% less damage", "color": Color("3aa4ff")},
	{"id": "barbarian", "name": "BRUTE", "model": "Barbarian", "role": "Assault", "hp": 140, "speed": 5.2, "damage": 1.25,
		"armor": 0.0, "dash_cd": 1.0, "grenade_cd": 1.0, "cost": 3000,
		"perk": "Deals 25% more damage", "color": Color("ec4a3c")},
	{"id": "mage", "name": "ARCANE", "model": "Mage", "role": "Demolition", "hp": 95, "speed": 5.4, "damage": 1.0,
		"armor": 0.0, "dash_cd": 1.0, "grenade_cd": 0.55, "cost": 5000,
		"perk": "Grenades recharge 45% faster", "color": Color("a56bff")},
]

## rate: shots per second. spread: degrees. pellets: bullets per shot.
const WEAPONS := [
	{"id": "ar", "name": "M4 RAIDER", "kind": "Assault Rifle", "model": "blaster-repeater", "tint": Color("3b4350"),
		"damage": 11.0, "rate": 7.5, "mag": 30, "reload": 1.6, "range": 11.0, "spread": 3.0, "pellets": 1, "pierce": 0,
		"move": 1.0, "cost": 0, "sound": "rifle"},
	{"id": "smg", "name": "VIPER SMG", "kind": "Submachine Gun", "model": "blaster", "tint": Color("2f6f4a"),
		"damage": 7.0, "rate": 12.5, "mag": 40, "reload": 1.3, "range": 8.5, "spread": 7.0, "pellets": 1, "pierce": 0,
		"move": 1.1, "cost": 1200, "sound": "smg"},
	{"id": "shotgun", "name": "THUNDER 12", "kind": "Shotgun", "model": "blaster", "tint": Color("7a3a24"),
		"damage": 11.0, "rate": 1.5, "mag": 6, "reload": 2.0, "range": 7.0, "spread": 20.0, "pellets": 7, "pierce": 0,
		"move": 1.0, "cost": 2500, "sound": "shotgun"},
	{"id": "dmr", "name": "LONGSHOT DMR", "kind": "Marksman Rifle", "model": "blaster-repeater", "tint": Color("6b5a2e"),
		"damage": 52.0, "rate": 2.0, "mag": 10, "reload": 2.0, "range": 15.0, "spread": 0.5, "pellets": 1, "pierce": 2,
		"move": 0.95, "cost": 4000, "sound": "dmr"},
	{"id": "lmg", "name": "HAILSTORM LMG", "kind": "Light Machine Gun", "model": "blaster-repeater", "tint": Color("23272d"),
		"damage": 13.0, "rate": 10.0, "mag": 90, "reload": 3.4, "range": 12.0, "spread": 5.0, "pellets": 1, "pierce": 1,
		"move": 0.85, "cost": 6500, "sound": "rifle"},
]

## The undead. ranged ones keep their distance and shoot; the rest charge.
const ENEMIES := {
	"minion": {"name": "Skeleton", "model": "Skeleton_Minion", "gear": "Skeleton_Blade", "hp": 70.0, "speed": 4.3,
		"damage": 8.0, "reach": 1.6, "cooldown": 1.1, "ranged": false, "coins": 2, "xp": 10, "scale": 1.0},
	"rogue": {"name": "Bone Archer", "model": "Skeleton_Rogue", "gear": "Skeleton_Crossbow", "hp": 70.0, "speed": 3.4,
		"damage": 9.0, "reach": 9.0, "cooldown": 2.0, "ranged": true, "coins": 3, "xp": 14, "scale": 1.0},
	"warrior": {"name": "Bone Knight", "model": "Skeleton_Warrior", "gear": "Skeleton_Axe", "hp": 230.0, "speed": 3.1,
		"damage": 18.0, "reach": 1.9, "cooldown": 1.4, "ranged": false, "coins": 6, "xp": 24, "scale": 1.12},
	"mage": {"name": "Necromancer", "model": "Skeleton_Mage", "gear": "Skeleton_Staff", "hp": 110.0, "speed": 3.1,
		"damage": 15.0, "reach": 8.5, "cooldown": 2.6, "ranged": true, "coins": 5, "xp": 20, "scale": 1.0},
	"boss": {"name": "BONE COLOSSUS", "model": "Skeleton_Warrior", "gear": "Skeleton_Axe", "hp": 2400.0, "speed": 2.8,
		"damage": 34.0, "reach": 3.2, "cooldown": 2.0, "ranged": false, "coins": 60, "xp": 200, "scale": 2.0},
}

const ARENAS := [
	{"id": "graveyard", "name": "HOLLOW GRAVES", "desc": "Moonlit cemetery. The dead rise from the soil.", "unlock": 0},
	{"id": "village", "name": "RAVEN VILLAGE", "desc": "A burning hamlet. Fight between the houses.", "unlock": 5},
	{"id": "fortress", "name": "IRON KEEP", "desc": "Broken castle walls at sunset. Bosses lurk.", "unlock": 10},
]

const PERKS := [
	{"id": "damage", "name": "HOLLOW POINTS", "desc": "+20% weapon damage", "icon": "gun"},
	{"id": "rate", "name": "HAIR TRIGGER", "desc": "+15% fire rate", "icon": "bolt"},
	{"id": "hp", "name": "JUGGERNAUT", "desc": "+30 max health and full heal", "icon": "heart"},
	{"id": "reload", "name": "SLEIGHT OF HAND", "desc": "Reload 35% faster", "icon": "dash"},
	{"id": "mag", "name": "EXTENDED MAGS", "desc": "+50% magazine size", "icon": "gun"},
	{"id": "speed", "name": "LIGHTWEIGHT", "desc": "+12% move speed", "icon": "dash"},
	{"id": "grenade", "name": "DANGER CLOSE", "desc": "Grenades hit 40% harder", "icon": "grenade"},
	{"id": "squad", "name": "SQUAD MEDIC", "desc": "Revive and heal your squad", "icon": "shield"},
	{"id": "streak", "name": "HARDLINE", "desc": "Airstrike charges 30% faster", "icon": "strike"},
]

const MAX_WEAPON_LEVEL := 10
const STREAK_KILLS := 18
const MAX_ALIVE := 14


static func operator(id: String) -> Dictionary:
	for o in OPERATORS:
		if o["id"] == id:
			return o
	return OPERATORS[0]


static func weapon(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return WEAPONS[0]


static func arena(index: int) -> Dictionary:
	return ARENAS[clampi(index, 0, ARENAS.size() - 1)]


## Damage multiplier for a weapon's upgrade level (1 = base).
static func weapon_power(level: int) -> float:
	return 1.0 + 0.1 * float(clampi(level, 1, MAX_WEAPON_LEVEL) - 1)


static func upgrade_cost(level: int) -> int:
	return 150 * level * level + 100 * level


## Which enemies a wave sends, in spawn order. Every fifth wave ends with a boss.
static func wave(n: int) -> Array[String]:
	var out: Array[String] = []
	var count := 5 + n * 2 + int(n / 4) * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919 + 13
	for i in count:
		var roll := rng.randf()
		var kind := "minion"
		if n >= 4 and roll > 0.86:
			kind = "mage"
		elif n >= 3 and roll > 0.7:
			kind = "warrior"
		elif n >= 2 and roll > 0.5:
			kind = "rogue"
		out.append(kind)
	if n % 5 == 0:
		out.append("boss")
	return out


## How much tougher the undead get each wave.
static func health_scale(n: int) -> float:
	return 1.0 + 0.11 * float(n - 1) + 0.004 * float((n - 1) * (n - 1))


static func damage_scale(n: int) -> float:
	return 1.0 + 0.05 * float(n - 1)


static func wave_bonus(n: int) -> int:
	return 10 + n * 4


## Player level from total XP: each level needs a little more.
static func level_for_xp(xp: int) -> int:
	var level := 1
	while xp >= xp_to_reach(level + 1):
		level += 1
	return level


static func xp_to_reach(level: int) -> int:
	return 120 * (level - 1) * level / 2


## Perks offered after a wave: three different ones, chosen by seed.
static func perk_choices(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool := PERKS.duplicate()
	var out: Array[Dictionary] = []
	for i in 3:
		var pick := rng.randi_range(0, pool.size() - 1)
		out.append(pool[pick])
		pool.remove_at(pick)
	return out
