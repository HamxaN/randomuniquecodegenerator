class_name GameData
## Every number that defines the game: weapons, attachments, gear, loot odds,
## the island and match rules. Pure data and helpers, shared by client and server.

const VERSION := "1.0"
const ISLAND_RADIUS := 270.0
const MAX_PLAYERS := 20
const SQUAD_SIZE := 4
const PORT := 7777

## Ammo types and how much one pickup gives.
const AMMO := {
	"light": {"name": "Light ammo", "pack": 30, "max": 240, "color": Color("f2c14e")},
	"rifle": {"name": "Rifle ammo", "pack": 30, "max": 240, "color": Color("7bd06b")},
	"shells": {"name": "Shells", "pack": 10, "max": 60, "color": Color("ec6a4c")},
	"heavy": {"name": "Heavy ammo", "pack": 10, "max": 40, "color": Color("4ca9ec")},
}

## dmg per bullet, rpm, mag size, spread (degrees, hip / aimed), recoil (degrees of
## kick per shot), range (full damage up to here), reload seconds, zoom when aimed,
## move (speed multiplier while holding it), burst (rounds per trigger pull, 0 = none).
const WEAPONS := {
	"pistol": {"name": "P9 Pistol", "class": "pistol", "ammo": "light", "dmg": 24.0, "rpm": 380.0, "mag": 12, "hip": 2.6, "ads": 1.1,
		"recoil": 1.1, "range": 45.0, "reload": 1.4, "auto": false, "pellets": 1, "head": 1.8, "zoom": 1.15, "move": 1.08,
		"slots": ["mag", "muzzle"], "sound": "pistol", "len": 0.32, "color": Color("3b4048"),
		"desc": "Quick, accurate sidearm. Better than nothing."},
	"revolver": {"name": "Magnum .44", "class": "pistol", "ammo": "light", "dmg": 54.0, "rpm": 140.0, "mag": 6, "hip": 2.8, "ads": 0.7,
		"recoil": 3.0, "range": 55.0, "reload": 2.4, "auto": false, "pellets": 1, "head": 1.9, "zoom": 1.2, "move": 1.06,
		"slots": ["scope", "muzzle"], "sound": "dmr", "len": 0.38, "color": Color("8a8f96"),
		"desc": "Six huge rounds. Two to the head ends most fights."},
	"smg": {"name": "Vex SMG", "class": "smg", "ammo": "light", "dmg": 17.0, "rpm": 820.0, "mag": 30, "hip": 3.2, "ads": 1.6,
		"recoil": 0.7, "range": 55.0, "reload": 1.9, "auto": true, "pellets": 1, "head": 1.6, "zoom": 1.2, "move": 1.05,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "smg", "len": 0.55, "color": Color("2f3a46"),
		"desc": "Fast and steady up close. Great for clearing towns."},
	"stinger": {"name": "Stinger", "class": "smg", "ammo": "light", "dmg": 13.0, "rpm": 1060.0, "mag": 25, "hip": 3.6, "ads": 2.0,
		"recoil": 0.55, "range": 38.0, "reload": 1.6, "auto": true, "pellets": 1, "head": 1.5, "zoom": 1.15, "move": 1.08,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "smg", "len": 0.45, "color": Color("6a3a7a"),
		"desc": "Absurd fire rate, tiny range. Shreds in a doorway."},
	"ar": {"name": "KR-7 Rifle", "class": "ar", "ammo": "rifle", "dmg": 25.0, "rpm": 610.0, "mag": 30, "hip": 2.8, "ads": 0.9,
		"recoil": 1.0, "range": 110.0, "reload": 2.2, "auto": true, "pellets": 1, "head": 1.8, "zoom": 1.3, "move": 1.0,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "rifle", "len": 0.8, "color": Color("4a4436"),
		"desc": "The all-rounder. Good at every range with a scope."},
	"talon": {"name": "M-Talon", "class": "ar", "ammo": "rifle", "dmg": 31.0, "rpm": 500.0, "mag": 30, "hip": 3.0, "ads": 0.8,
		"recoil": 1.45, "range": 125.0, "reload": 2.4, "auto": true, "pellets": 1, "head": 1.8, "zoom": 1.3, "move": 0.98,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "rifle", "len": 0.88, "color": Color("2e3b2c"),
		"desc": "Hits harder, kicks harder. Fit a grip and win long fights."},
	"burst": {"name": "Tri-Burst", "class": "ar", "ammo": "rifle", "dmg": 27.0, "rpm": 330.0, "mag": 30, "hip": 2.6, "ads": 0.55,
		"recoil": 0.85, "range": 120.0, "reload": 2.3, "auto": true, "pellets": 1, "head": 1.9, "zoom": 1.3, "move": 1.0, "burst": 3,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "rifle", "len": 0.82, "color": Color("394a5e"),
		"desc": "Three-round bursts with pinpoint accuracy."},
	"lmg": {"name": "Havoc LMG", "class": "lmg", "ammo": "rifle", "dmg": 23.0, "rpm": 700.0, "mag": 75, "hip": 3.8, "ads": 1.3,
		"recoil": 0.95, "range": 100.0, "reload": 4.2, "auto": true, "pellets": 1, "head": 1.6, "zoom": 1.25, "move": 0.88,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "rifle", "len": 0.95, "color": Color("3d3a33"),
		"desc": "A huge belt of ammo. Slow to move with, slower to reload."},
	"shotgun": {"name": "Breaker 12", "class": "shotgun", "ammo": "shells", "dmg": 13.0, "rpm": 72.0, "mag": 5, "hip": 5.5, "ads": 4.2,
		"recoil": 4.0, "range": 18.0, "reload": 3.0, "auto": false, "pellets": 9, "head": 1.4, "zoom": 1.1, "move": 1.0,
		"slots": ["scope", "muzzle"], "sound": "shotgun", "len": 0.75, "color": Color("5a3b2a"),
		"desc": "Pump-action. One clean shot up close is all it takes."},
	"riot": {"name": "Riot Auto", "class": "shotgun", "ammo": "shells", "dmg": 9.0, "rpm": 220.0, "mag": 8, "hip": 5.0, "ads": 4.0,
		"recoil": 2.6, "range": 14.0, "reload": 3.2, "auto": true, "pellets": 8, "head": 1.3, "zoom": 1.1, "move": 0.98,
		"slots": ["scope", "mag", "muzzle"], "sound": "shotgun", "len": 0.7, "color": Color("2a2a2e"),
		"desc": "Semi-auto shotgun. Keep pulling the trigger."},
	"dmr": {"name": "Ranger DMR", "class": "dmr", "ammo": "rifle", "dmg": 46.0, "rpm": 210.0, "mag": 10, "hip": 3.5, "ads": 0.35,
		"recoil": 2.2, "range": 190.0, "reload": 2.6, "auto": false, "pellets": 1, "head": 2.0, "zoom": 1.5, "move": 0.96,
		"slots": ["scope", "mag", "muzzle"], "sound": "dmr", "len": 0.95, "color": Color("394a3a"),
		"desc": "Hard-hitting semi-auto for picking people off."},
	"hunter": {"name": "Hunter SR", "class": "dmr", "ammo": "rifle", "dmg": 38.0, "rpm": 300.0, "mag": 15, "hip": 3.2, "ads": 0.45,
		"recoil": 1.6, "range": 160.0, "reload": 2.4, "auto": false, "pellets": 1, "head": 2.0, "zoom": 1.5, "move": 0.97,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "dmr", "len": 0.9, "color": Color("6b4a2e"),
		"desc": "Lighter marksman rifle. Fast follow-up shots."},
	"kestrel": {"name": "Kestrel Bolt", "class": "sniper", "ammo": "heavy", "dmg": 78.0, "rpm": 50.0, "mag": 5, "hip": 6.0, "ads": 0.12,
		"recoil": 4.4, "range": 280.0, "reload": 3.0, "auto": false, "pellets": 1, "head": 2.4, "zoom": 1.6, "move": 0.93,
		"slots": ["scope", "mag", "muzzle"], "sound": "sniper", "len": 1.08, "color": Color("40352a"),
		"desc": "Bolt-action sniper. A headshot through a level 2 helmet knocks."},
	"sniper": {"name": "Longbow", "class": "sniper", "ammo": "heavy", "dmg": 92.0, "rpm": 42.0, "mag": 5, "hip": 6.0, "ads": 0.1,
		"recoil": 5.0, "range": 320.0, "reload": 3.2, "auto": false, "pellets": 1, "head": 2.6, "zoom": 1.6, "move": 0.92,
		"slots": ["scope", "mag", "muzzle"], "sound": "sniper", "len": 1.15, "color": Color("2a2f35"),
		"desc": "Airdrop only. One headshot, one elimination."},
}
const CLASS_NAMES := {"pistol": "Pistols", "smg": "SMGs", "ar": "Assault rifles", "lmg": "Machine guns",
	"shotgun": "Shotguns", "dmr": "Marksman rifles", "sniper": "Sniper rifles"}

## Weapon rarity: damage bonus and how many attachments come fitted.
const RARITY := [
	{"name": "Common", "color": Color("b8c0c8"), "dmg": 1.0},
	{"name": "Rare", "color": Color("3aa4ff"), "dmg": 1.05},
	{"name": "Epic", "color": Color("b06bff"), "dmg": 1.1},
	{"name": "Legendary", "color": Color("ffc21a"), "dmg": 1.15},
]
const RARITY_WEIGHTS := [62.0, 25.0, 9.5, 3.5]

## Throwables.
const THROWABLES := {
	"frag": {"name": "Frag Grenade", "short": "FRAG", "color": Color("6b8f3a")},
	"smoke": {"name": "Smoke Grenade", "short": "SMOKE", "color": Color("c8ccd0")},
	"molotov": {"name": "Molotov", "short": "MOLLY", "color": Color("ff7a1a")},
}
const SMOKE_RADIUS := 6.0
const SMOKE_TIME := 16.0
const FIRE_RADIUS := 4.2
const FIRE_TIME := 8.0
const FIRE_DPS := 14.0

## Weapon camos you can buy; applied to every gun you carry.
const CAMOS := [
	{"id": "none", "name": "Factory", "price": 0, "color": Color(0, 0, 0, 0)},
	{"id": "urban", "name": "Urban", "price": 600, "color": Color("6d7580")},
	{"id": "desert", "name": "Desert", "price": 600, "color": Color("c2a06a")},
	{"id": "jungle", "name": "Jungle", "price": 600, "color": Color("4f6b3a")},
	{"id": "arctic", "name": "Arctic", "price": 1000, "color": Color("dfe8ee")},
	{"id": "neon", "name": "Neon", "price": 2000, "color": Color("ff3fb4"), "glow": true},
	{"id": "gold", "name": "Gold", "price": 5000, "color": Color("e8b83a"), "metal": true},
]

## Attachments. "slot" is where they go; the rest change the weapon's numbers.
const ATTACH := {
	"red_dot": {"name": "Red Dot", "slot": "scope", "zoom": 1.45, "ads_mult": 0.8, "tier": 1},
	"scope2": {"name": "2x Scope", "slot": "scope", "zoom": 2.2, "ads_mult": 0.7, "tier": 2},
	"scope4": {"name": "4x Scope", "slot": "scope", "zoom": 4.0, "ads_mult": 0.55, "tier": 3, "only": ["ar", "dmr", "sniper"]},
	"scope8": {"name": "8x Scope", "slot": "scope", "zoom": 7.5, "ads_mult": 0.4, "tier": 4, "only": ["dmr", "sniper"]},
	"ext_mag": {"name": "Extended Mag", "slot": "mag", "mag_mult": 1.5, "reload_mult": 0.9, "tier": 1},
	"grip": {"name": "Vertical Grip", "slot": "grip", "recoil_mult": 0.65, "hip_mult": 0.85, "tier": 1},
	"comp": {"name": "Compensator", "slot": "muzzle", "recoil_mult": 0.75, "tier": 1},
	"silencer": {"name": "Suppressor", "slot": "muzzle", "quiet": true, "recoil_mult": 0.9, "tier": 2},
}

const VEST_REDUCTION := [0.0, 0.25, 0.4, 0.55]
const HELMET_REDUCTION := [0.0, 0.3, 0.45, 0.6]

const HEALS := {
	"bandage": {"name": "Bandage", "time": 3.0, "heal": 15.0, "cap": 75.0, "max": 10, "boost": 0.0},
	"medkit": {"name": "Medkit", "time": 6.0, "heal": 100.0, "cap": 100.0, "max": 3, "boost": 0.0},
	"drink": {"name": "Energy Drink", "time": 3.0, "heal": 0.0, "cap": 100.0, "max": 5, "boost": 40.0},
}
const MAX_GRENADES := 3  # of each kind
const GRENADE_DAMAGE := 110.0
const GRENADE_RADIUS := 6.5

## Ground loot odds: kind, id, weight. Weapons come with some ammo nearby.
const LOOT_TABLE := [
	["weapon", "pistol", 6], ["weapon", "revolver", 3], ["weapon", "smg", 7], ["weapon", "stinger", 5],
	["weapon", "ar", 8], ["weapon", "talon", 5], ["weapon", "burst", 4], ["weapon", "lmg", 2.5],
	["weapon", "shotgun", 6], ["weapon", "riot", 3], ["weapon", "dmr", 3.5], ["weapon", "hunter", 3], ["weapon", "kestrel", 1.2],
	["ammo", "light", 12], ["ammo", "rifle", 13], ["ammo", "shells", 6], ["ammo", "heavy", 3],
	["attach", "red_dot", 4], ["attach", "scope2", 3], ["attach", "scope4", 1.5], ["attach", "scope8", 0.4], ["attach", "ext_mag", 4],
	["attach", "grip", 4], ["attach", "comp", 3], ["attach", "silencer", 1.5],
	["vest", "1", 5], ["vest", "2", 2.5], ["vest", "3", 0.6], ["helmet", "1", 5], ["helmet", "2", 2.5], ["helmet", "3", 0.6],
	["heal", "bandage", 10], ["heal", "medkit", 3], ["heal", "drink", 4],
	["grenade", "frag", 3.5], ["grenade", "smoke", 2.5], ["grenade", "molotov", 2.5],
]

## Playable characters (KayKit adventurers) with their accent colours.
const SKINS := [
	{"id": "rogue", "model": "Rogue", "name": "Vex", "price": 0, "color": Color("3fd16f")},
	{"id": "knight", "model": "Knight", "name": "Bastion", "price": 0, "color": Color("3aa4ff")},
	{"id": "hooded", "model": "Rogue_Hooded", "name": "Shade", "price": 1500, "color": Color("a56bff")},
	{"id": "barbarian", "model": "Barbarian", "name": "Brute", "price": 2500, "color": Color("ff7a1a")},
	{"id": "mage", "model": "Mage", "name": "Arc", "price": 4000, "color": Color("ffc21a")},
]

const TEAM_COLORS := [Color("3fd16f"), Color("3aa4ff"), Color("ffc21a"), Color("ec4a3c"), Color("a56bff"),
	Color("ff7a1a"), Color("4ae0d2"), Color("ff6fb5"), Color("c0c8d0"), Color("9be04a"),
	Color("e0b04a"), Color("6a8cff"), Color("ff4a6a"), Color("4affa0"), Color("d07bff"),
	Color("ffd27b"), Color("7bc8ff"), Color("ff9a7b"), Color("b0ff7b"), Color("ffffff")]

const BOT_NAMES := ["Rook", "Viper", "Nomad", "Echo", "Blaze", "Specter", "Hawk", "Onyx", "Raptor", "Jinx", "Talon",
	"Ghost", "Bishop", "Comet", "Flint", "Mako", "Nova", "Ranger", "Sable", "Torch", "Wolf", "Zephyr", "Kestrel",
	"Pike", "Quill", "Rift", "Saber", "Tundra", "Vandal", "Wraith"]

const TOWN_NAMES := ["Harbor Row", "Old Mill", "Pine Ridge", "Sunset Docks", "Quarry Town", "Cinder Yard", "Lookout"]

## Coins and XP for a match.
const COINS_PER_KILL := 60
const COINS_FOR_PLACE := [400, 250, 180, 120, 90, 60]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["pistol"])


static func fits(weapon_id: String, attach_id: String) -> bool:
	if not WEAPONS.has(weapon_id) or not ATTACH.has(attach_id):
		return false
	var a: Dictionary = ATTACH[attach_id]
	if not (WEAPONS[weapon_id]["slots"] as Array).has(a["slot"]):
		return false
	if a.has("only") and not (a["only"] as Array).has(weapon_id):
		return false
	return true


## A weapon's numbers after its attachments. [param w] is an inventory weapon
## ({"id", "mag", "att": {slot: attach_id}}).
static func stats(w: Dictionary) -> Dictionary:
	var base: Dictionary = weapon(String(w.get("id", "pistol")))
	var s := base.duplicate()
	var att: Dictionary = w.get("att", {})
	s["quiet"] = false
	s["dmg"] = float(s["dmg"]) * float(RARITY[clampi(int(w.get("rar", 0)), 0, 3)]["dmg"])
	s["burst"] = int(base.get("burst", 0))
	for slot in att:
		var a: Dictionary = ATTACH.get(String(att[slot]), {})
		if a.is_empty():
			continue
		if a.has("zoom"):
			s["zoom"] = maxf(float(s["zoom"]), float(a["zoom"]))
		if a.has("ads_mult"):
			s["ads"] = float(s["ads"]) * float(a["ads_mult"])
		if a.has("mag_mult"):
			s["mag"] = int(round(int(s["mag"]) * float(a["mag_mult"])))
		if a.has("reload_mult"):
			s["reload"] = float(s["reload"]) * float(a["reload_mult"])
		if a.has("recoil_mult"):
			s["recoil"] = float(s["recoil"]) * float(a["recoil_mult"])
		if a.has("hip_mult"):
			s["hip"] = float(s["hip"]) * float(a["hip_mult"])
		if a.get("quiet", false):
			s["quiet"] = true
	return s


## Damage at [param dist] metres: full up to the weapon's range, then fading to 40%.
static func falloff(weapon_id: String, dist: float) -> float:
	var r := float(weapon(weapon_id)["range"])
	if dist <= r:
		return 1.0
	return clampf(1.0 - (dist - r) / (r * 1.5) * 0.6, 0.4, 1.0)


## Damage after armour. [param head] picks the helmet, otherwise the vest.
static func mitigate(dmg: float, head: bool, vest: int, helmet: int) -> float:
	if head:
		return dmg * (1.0 - HELMET_REDUCTION[clampi(helmet, 0, 3)])
	return dmg * (1.0 - VEST_REDUCTION[clampi(vest, 0, 3)])


## One random ground item. [param rng] keeps every peer's loot identical for a seed.
static func roll_loot(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for e in LOOT_TABLE:
		total += float(e[2])
	var r := rng.randf() * total
	for e in LOOT_TABLE:
		r -= float(e[2])
		if r <= 0.0:
			var it := item(String(e[0]), String(e[1]))
			if it["kind"] == "weapon":
				_roll_rarity(it, rng)
			return it
	return item("ammo", "light")


## Gives a ground weapon a rarity, with one fitted attachment per tier.
static func _roll_rarity(it: Dictionary, rng: RandomNumberGenerator) -> void:
	var total := 0.0
	for w in RARITY_WEIGHTS:
		total += w
	var r := rng.randf() * total
	var rar := 0
	for i in RARITY_WEIGHTS.size():
		r -= RARITY_WEIGHTS[i]
		if r <= 0.0:
			rar = i
			break
	it["rar"] = rar
	var options: Array = []
	for aid in ATTACH:
		if fits(String(it["id"]), aid) and not (ATTACH[aid].has("only") and rar < 2):
			options.append(aid)
	var att := {}
	for k in rar:
		if options.is_empty():
			break
		var pick: String = options[rng.randi() % options.size()]
		att[ATTACH[pick]["slot"]] = pick
		var keep: Array = []
		for o in options:
			if ATTACH[o]["slot"] != ATTACH[pick]["slot"]:
				keep.append(o)
		options = keep
	it["att"] = att
	it["mag"] = int(stats(it)["mag"])


static func rarity_of(w: Dictionary) -> Dictionary:
	return RARITY[clampi(int(w.get("rar", 0)), 0, 3)]


## How good a weapon is overall (bots use it to choose what to carry).
static func weapon_score(w: Dictionary) -> float:
	if w.is_empty():
		return 0.0
	var s := stats(w)
	var dps := float(s["dmg"]) * float(s["pellets"]) * float(s["rpm"]) / 60.0
	return dps * (0.6 + minf(float(s["range"]), 200.0) / 120.0) * (1.0 if s["class"] != "pistol" else 0.6)


## Builds an item dictionary. Weapons come loaded, other stacks get a sensible count.
static func item(kind: String, id: String) -> Dictionary:
	match kind:
		"weapon":
			return {"kind": "weapon", "id": id, "n": 1, "mag": int(weapon(id)["mag"]), "att": {}, "rar": 0}
		"ammo":
			return {"kind": "ammo", "id": id, "n": int(AMMO[id]["pack"])}
		"vest", "helmet":
			return {"kind": kind, "id": id, "n": 1, "lvl": int(id)}
		"heal":
			return {"kind": "heal", "id": id, "n": 2 if id == "bandage" else 1}
		"grenade":
			return {"kind": "grenade", "id": id if THROWABLES.has(id) else "frag", "n": 1}
		_:
			return {"kind": kind, "id": id, "n": 1}


static func item_name(it: Dictionary) -> String:
	var id := String(it.get("id", ""))
	match String(it.get("kind", "")):
		"weapon":
			var rar := int(it.get("rar", 0))
			return (String(RARITY[rar]["name"]) + " " if rar > 0 else "") + String(weapon(id)["name"])
		"ammo":
			return "%s x%d" % [AMMO[id]["name"], int(it.get("n", 1))]
		"attach":
			return String(ATTACH[id]["name"])
		"vest":
			return "Vest Lv.%s" % id
		"helmet":
			return "Helmet Lv.%s" % id
		"heal":
			var n := int(it.get("n", 1))
			return String(HEALS[id]["name"]) + (" x%d" % n if n > 1 else "")
		"grenade":
			return String(THROWABLES.get(id, THROWABLES["frag"])["name"])
	return id


static func item_color(it: Dictionary) -> Color:
	var id := String(it.get("id", ""))
	match String(it.get("kind", "")):
		"weapon":
			return RARITY[clampi(int(it.get("rar", 0)), 0, 3)]["color"]
		"ammo":
			return AMMO[id]["color"]
		"attach":
			return Color("a56bff")
		"vest", "helmet":
			return [Color.WHITE, Color("c0c8d0"), Color("3aa4ff"), Color("ffc21a")][clampi(int(id), 0, 3)]
		"heal":
			return Color("ec4a3c")
		"grenade":
			return THROWABLES.get(id, THROWABLES["frag"])["color"]
	return Color.WHITE


static func camo(id: String) -> Dictionary:
	for c in CAMOS:
		if c["id"] == id:
			return c
	return CAMOS[0]


static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


static func level_for_xp(xp: int) -> int:
	var lvl := 1
	var need := 300
	var left := xp
	while left >= need and lvl < 99:
		left -= need
		lvl += 1
		need += 150
	return lvl
