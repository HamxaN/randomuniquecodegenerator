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
## kick per shot), range (full damage up to here), reload seconds, zoom when aimed.
const WEAPONS := {
	"pistol": {"name": "P9 Pistol", "ammo": "light", "dmg": 24.0, "rpm": 380.0, "mag": 12, "hip": 2.6, "ads": 1.1,
		"recoil": 1.1, "range": 45.0, "reload": 1.4, "auto": false, "pellets": 1, "head": 1.8, "zoom": 1.15,
		"slots": ["mag", "muzzle"], "sound": "pistol", "len": 0.32, "color": Color("3b4048")},
	"smg": {"name": "Vex SMG", "ammo": "light", "dmg": 17.0, "rpm": 820.0, "mag": 30, "hip": 3.2, "ads": 1.6,
		"recoil": 0.7, "range": 55.0, "reload": 1.9, "auto": true, "pellets": 1, "head": 1.6, "zoom": 1.2,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "smg", "len": 0.55, "color": Color("2f3a46")},
	"ar": {"name": "KR-7 Rifle", "ammo": "rifle", "dmg": 25.0, "rpm": 610.0, "mag": 30, "hip": 2.8, "ads": 0.9,
		"recoil": 1.0, "range": 110.0, "reload": 2.2, "auto": true, "pellets": 1, "head": 1.8, "zoom": 1.3,
		"slots": ["scope", "mag", "grip", "muzzle"], "sound": "rifle", "len": 0.8, "color": Color("4a4436")},
	"shotgun": {"name": "Breaker 12", "ammo": "shells", "dmg": 13.0, "rpm": 72.0, "mag": 5, "hip": 5.5, "ads": 4.2,
		"recoil": 4.0, "range": 18.0, "reload": 3.0, "auto": false, "pellets": 9, "head": 1.4, "zoom": 1.1,
		"slots": ["scope", "muzzle"], "sound": "shotgun", "len": 0.75, "color": Color("5a3b2a")},
	"dmr": {"name": "Ranger DMR", "ammo": "rifle", "dmg": 46.0, "rpm": 210.0, "mag": 10, "hip": 3.5, "ads": 0.35,
		"recoil": 2.2, "range": 190.0, "reload": 2.6, "auto": false, "pellets": 1, "head": 2.0, "zoom": 1.5,
		"slots": ["scope", "mag", "muzzle"], "sound": "dmr", "len": 0.95, "color": Color("394a3a")},
	"sniper": {"name": "Longbow", "ammo": "heavy", "dmg": 92.0, "rpm": 42.0, "mag": 5, "hip": 6.0, "ads": 0.1,
		"recoil": 5.0, "range": 320.0, "reload": 3.2, "auto": false, "pellets": 1, "head": 2.6, "zoom": 1.6,
		"slots": ["scope", "mag", "muzzle"], "sound": "sniper", "len": 1.15, "color": Color("2a2f35")},
}

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
const MAX_GRENADES := 3
const GRENADE_DAMAGE := 110.0
const GRENADE_RADIUS := 6.5

## Ground loot odds: kind, id, weight. Weapons come with some ammo nearby.
const LOOT_TABLE := [
	["weapon", "pistol", 7], ["weapon", "smg", 9], ["weapon", "ar", 10], ["weapon", "shotgun", 8], ["weapon", "dmr", 4],
	["ammo", "light", 12], ["ammo", "rifle", 12], ["ammo", "shells", 6], ["ammo", "heavy", 2],
	["attach", "red_dot", 4], ["attach", "scope2", 3], ["attach", "scope4", 1.5], ["attach", "ext_mag", 4], ["attach", "grip", 4],
	["attach", "comp", 3], ["attach", "silencer", 1.5],
	["vest", "1", 5], ["vest", "2", 2.5], ["vest", "3", 0.6], ["helmet", "1", 5], ["helmet", "2", 2.5], ["helmet", "3", 0.6],
	["heal", "bandage", 10], ["heal", "medkit", 3], ["heal", "drink", 4], ["grenade", "frag", 4],
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
			return item(String(e[0]), String(e[1]))
	return item("ammo", "light")


## Builds an item dictionary. Weapons come loaded, other stacks get a sensible count.
static func item(kind: String, id: String) -> Dictionary:
	match kind:
		"weapon":
			return {"kind": "weapon", "id": id, "n": 1, "mag": int(weapon(id)["mag"]), "att": {}}
		"ammo":
			return {"kind": "ammo", "id": id, "n": int(AMMO[id]["pack"])}
		"vest", "helmet":
			return {"kind": kind, "id": id, "n": 1, "lvl": int(id)}
		"heal":
			return {"kind": "heal", "id": id, "n": 2 if id == "bandage" else 1}
		"grenade":
			return {"kind": "grenade", "id": "frag", "n": 1}
		_:
			return {"kind": kind, "id": id, "n": 1}


static func item_name(it: Dictionary) -> String:
	var id := String(it.get("id", ""))
	match String(it.get("kind", "")):
		"weapon":
			return String(weapon(id)["name"])
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
			return "Frag Grenade"
	return id


static func item_color(it: Dictionary) -> Color:
	var id := String(it.get("id", ""))
	match String(it.get("kind", "")):
		"weapon":
			return Color("ffc21a")
		"ammo":
			return AMMO[id]["color"]
		"attach":
			return Color("a56bff")
		"vest", "helmet":
			return [Color.WHITE, Color("c0c8d0"), Color("3aa4ff"), Color("ffc21a")][clampi(int(id), 0, 3)]
		"heal":
			return Color("ec4a3c")
		"grenade":
			return Color("6b8f3a")
	return Color.WHITE


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
