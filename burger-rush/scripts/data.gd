class_name GameData
## The menu, prices, days, upgrades and chefs. Everything here is plain maths
## so the unit tests can check it.

const PRICES := {"bun": 2, "patty": 5, "cheese": 2, "lettuce": 1, "tomato": 1, "fries": 4, "drink": 3}
## The day each ingredient or side first appears on the menu.
const UNLOCKS := {"bun": 1, "patty": 1, "cheese": 2, "drink": 3, "lettuce": 4, "fries": 5, "tomato": 7}
const TOPPINGS := ["cheese", "lettuce", "tomato"]
## Bottom to top, for drawing a burger.
const STACK := ["bun", "patty", "cheese", "lettuce", "tomato"]

const COOK_TIME := 6.5
const BURN_TIME := 9.0
const FRY_TIME := 5.5
const POUR_TIME := 2.6
const FRIES_PER_BATCH := 3
const TIP_SHARE := 0.35

const LOCATIONS := [
	{"name": "Main Street Diner", "floor_a": Color(0.96, 0.94, 0.88), "floor_b": Color(0.82, 0.22, 0.2),
		"outside": Color(0.55, 0.78, 0.98), "sun": Color(1.0, 0.95, 0.86), "energy": 0.95, "ambient": 0.42,
		"lamp": Color(1.0, 0.85, 0.6), "skeletons": 0.08},
	{"name": "Sunny Beach Shack", "floor_a": Color(0.98, 0.9, 0.7), "floor_b": Color(0.18, 0.62, 0.72),
		"outside": Color(0.45, 0.82, 0.95), "sun": Color(1.0, 0.92, 0.75), "energy": 1.0, "ambient": 0.45,
		"lamp": Color(1.0, 0.8, 0.55), "skeletons": 0.15},
	{"name": "Spooky Night Grill", "floor_a": Color(0.36, 0.32, 0.46), "floor_b": Color(0.16, 0.13, 0.22),
		"outside": Color(0.08, 0.07, 0.18), "sun": Color(0.6, 0.65, 1.0), "energy": 0.5, "ambient": 0.4,
		"lamp": Color(1.0, 0.6, 0.3), "skeletons": 0.7},
]
const DAYS_PER_LOCATION := 10

const ADVENTURERS := ["Knight", "Mage", "Rogue", "Rogue_Hooded", "Barbarian"]
const SKELETONS := ["Skeleton_Minion", "Skeleton_Rogue", "Skeleton_Mage", "Skeleton_Warrior"]

const UPGRADES := [
	{"id": "grill", "name": "Bigger Grill", "desc": "+1 patty on the grill", "max": 2, "base": 120, "icon": "patty"},
	{"id": "heat", "name": "Hotter Flames", "desc": "Patties cook 12% faster", "max": 4, "base": 90, "icon": "flame"},
	{"id": "plates", "name": "Extra Plate", "desc": "+1 plate on the counter", "max": 1, "base": 220, "icon": "plate"},
	{"id": "shoes", "name": "Running Shoes", "desc": "Chef moves 12% faster", "max": 4, "base": 80, "icon": "shoe"},
	{"id": "decor", "name": "Cosy Decor", "desc": "Customers wait 10% longer", "max": 4, "base": 110, "icon": "heart"},
	{"id": "tips", "name": "Tip Jar", "desc": "+15% tips", "max": 4, "base": 100, "icon": "gold"},
	{"id": "fryer", "name": "Big Fryer", "desc": "+1 portion per batch", "max": 2, "base": 150, "icon": "fries"},
]

const CHEFS := [
	{"id": "bruno", "name": "Big Bruno", "model": "Barbarian", "cost": 0},
	{"id": "lance", "name": "Sir Lance", "model": "Knight", "cost": 400},
	{"id": "mira", "name": "Mira the Wise", "model": "Mage", "cost": 900},
	{"id": "quinn", "name": "Quick Quinn", "model": "Rogue", "cost": 1500},
	{"id": "robin", "name": "Hooded Robin", "model": "Rogue_Hooded", "cost": 2200},
]


static func day_count() -> int:
	return LOCATIONS.size() * DAYS_PER_LOCATION


static func location_index(day: int) -> int:
	return clampi((day - 1) / DAYS_PER_LOCATION, 0, LOCATIONS.size() - 1)


static func location(day: int) -> Dictionary:
	return LOCATIONS[location_index(day)]


static func unlocked(item: String, day: int) -> bool:
	return day >= int(UNLOCKS.get(item, 1))


## What is new on the menu on [param day], or "".
static func new_item(day: int) -> String:
	for item in UNLOCKS:
		if int(UNLOCKS[item]) == day and day > 1:
			return str(item)
	return ""


static func make_order(day: int, rng: RandomNumberGenerator) -> Dictionary:
	var burger: Array = ["bun", "patty"]
	var chance := 0.35 + clampf(day / 30.0, 0.0, 1.0) * 0.25
	for t in TOPPINGS:
		if unlocked(t, day) and rng.randf() < chance:
			burger.append(t)
	var fries := unlocked("fries", day) and rng.randf() < 0.42
	var drink := unlocked("drink", day) and rng.randf() < 0.48
	return {"burger": burger, "fries": fries, "drink": drink}


static func order_price(order: Dictionary) -> int:
	var total := 0
	for item in order["burger"]:
		total += int(PRICES[item])
	if order["fries"]:
		total += int(PRICES["fries"])
	if order["drink"]:
		total += int(PRICES["drink"])
	return total


## How many things the cook has to hand over for this order.
static func order_parts(order: Dictionary) -> int:
	return 1 + (1 if order["fries"] else 0) + (1 if order["drink"] else 0)


## A day's customers: their orders, when they walk in, how long they wait and
## the coin goals for one, two and three stars.
static func day_plan(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var d := clampf((day - 1) / float(day_count() - 1), 0.0, 1.0)
	var count := 5 + int(round(day * 0.75))
	var gap := lerpf(9.5, 5.0, d)
	var orders: Array[Dictionary] = []
	var times: Array[float] = []
	var t := 1.5
	var total := 0
	for i in count:
		var o := make_order(day, rng)
		orders.append(o)
		times.append(t)
		total += order_price(o)
		# Customers trickle in, with the odd little rush.
		t += gap * (rng.randf_range(0.35, 0.6) if rng.randf() < 0.2 else rng.randf_range(0.8, 1.25))
	var goals: Array[int] = [int(total * 0.55), int(total * 0.85), int(total * 1.08)]
	return {"day": day, "orders": orders, "times": times, "patience": lerpf(44.0, 30.0, d), "goals": goals,
		"location": location_index(day)}


## True if the plate holds exactly the burger that was ordered (any stacking order).
static func burger_matches(items: Array, spec: Array) -> bool:
	if items.size() != spec.size():
		return false
	for item in spec:
		if not items.has(item):
			return false
	return true


static func tip(price: int, patience_left: float, tip_level: int) -> int:
	return int(round(price * TIP_SHARE * clampf(patience_left, 0.0, 1.0) * (1.0 + 0.15 * tip_level)))


static func stars(coins: int, goals: Array) -> int:
	var s := 0
	for g in goals:
		if coins >= int(g):
			s += 1
	return s


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func upgrade_cost(id: String, level: int) -> int:
	return int(round(float(upgrade(id)["base"]) * pow(1.85, level)))


static func chef(id: String) -> Dictionary:
	for c in CHEFS:
		if c["id"] == id:
			return c
	return CHEFS[0]


static func cook_time(heat: int) -> float:
	return COOK_TIME * pow(0.88, heat)


static func chef_speed(shoes: int) -> float:
	return 5.0 * (1.0 + 0.12 * shoes)


static func patience_mult(decor: int) -> float:
	return 1.0 + 0.1 * decor


## Items of a burger sorted bottom to top.
static func stacked(items: Array) -> Array:
	var out: Array = []
	for s in STACK:
		if items.has(s):
			out.append(s)
	return out
