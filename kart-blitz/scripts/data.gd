class_name GameData
## Tracks, karts, upgrades, items and race rewards. Pure data, unit tested.

## Track centre lines as closed loops of points (x, z), in metres.
const TRACKS := [
	{"id": "meadow", "name": "Sunny Meadow", "theme": "meadow", "laps": 3, "unlock": 0,
		"points": [Vector2(0, 0), Vector2(60, 0), Vector2(95, 25), Vector2(95, 70), Vector2(55, 95), Vector2(10, 85), Vector2(-25, 55), Vector2(-30, 15)]},
	{"id": "canyon", "name": "Dusty Canyon", "theme": "desert", "laps": 3, "unlock": 1,
		"points": [Vector2(0, 0), Vector2(70, -10), Vector2(110, 20), Vector2(80, 50), Vector2(110, 85), Vector2(60, 110), Vector2(10, 80), Vector2(30, 45), Vector2(-20, 30)]},
	{"id": "pines", "name": "Frosty Pines", "theme": "snow", "laps": 3, "unlock": 2,
		"points": [Vector2(0, 0), Vector2(50, -20), Vector2(100, -5), Vector2(120, 40), Vector2(85, 60), Vector2(105, 100), Vector2(50, 115), Vector2(0, 90), Vector2(20, 50), Vector2(-20, 35)]},
	{"id": "dusk", "name": "Twilight Loop", "theme": "dusk", "laps": 3, "unlock": 3,
		"points": [Vector2(0, 0), Vector2(80, 0), Vector2(120, 40), Vector2(80, 80), Vector2(120, 120), Vector2(40, 130), Vector2(0, 100), Vector2(30, 60), Vector2(-30, 40)]},
	{"id": "island", "name": "Palm Island", "theme": "meadow", "laps": 3, "unlock": 4,
		"points": [Vector2(0, 0), Vector2(45, -25), Vector2(95, -20), Vector2(130, 15), Vector2(120, 65), Vector2(75, 75), Vector2(60, 115), Vector2(10, 120), Vector2(-25, 80), Vector2(-15, 35)]},
	{"id": "volcano", "name": "Lava Ridge", "theme": "lava", "laps": 3, "unlock": 5,
		"points": [Vector2(0, 0), Vector2(60, 10), Vector2(100, -15), Vector2(140, 20), Vector2(110, 60), Vector2(140, 100), Vector2(90, 130), Vector2(40, 100), Vector2(50, 60), Vector2(0, 70), Vector2(-25, 30)]},
]

const KARTS := [
	{"id": "red", "name": "Red Rocket", "model": "vehicle-truck-red", "speed": 30.0, "accel": 16.0, "grip": 2.1, "cost": 0},
	{"id": "green", "name": "Green Machine", "model": "vehicle-truck-green", "speed": 31.5, "accel": 15.0, "grip": 2.2, "cost": 1500},
	{"id": "yellow", "name": "Yellow Jacket", "model": "vehicle-truck-yellow", "speed": 31.0, "accel": 18.0, "grip": 2.0, "cost": 2500},
	{"id": "purple", "name": "Purple Haze", "model": "vehicle-truck-purple", "speed": 33.0, "accel": 16.0, "grip": 2.3, "cost": 4000},
	{"id": "moto", "name": "Lightning Bike", "model": "vehicle-motorcycle", "speed": 35.0, "accel": 20.0, "grip": 2.5, "cost": 7000},
]

const UPGRADES := [
	{"id": "engine", "name": "Engine", "desc": "+3% top speed per level", "icon": "bolt"},
	{"id": "tyres", "name": "Tyres", "desc": "+5% grip per level", "icon": "wheel"},
	{"id": "nitro", "name": "Nitro", "desc": "Longer drift boosts", "icon": "boost"},
]
const MAX_UPGRADE := 5

const RIVALS := ["Max", "Luna", "Rex", "Kiki", "Bolt", "Zara", "Duke", "Pip"]

## Items from the ? boxes. Racers further back get the stronger ones.
const ITEMS := ["boost", "rocket", "shield", "oil", "triple"]

const POINTS := [15, 12, 10, 8, 6, 4]
const COINS := [120, 90, 70, 50, 35, 25]
const RACERS := 6


static func track(index: int) -> Dictionary:
	return TRACKS[clampi(index, 0, TRACKS.size() - 1)]


static func kart(id: String) -> Dictionary:
	for k in KARTS:
		if k["id"] == id:
			return k
	return KARTS[0]


static func upgrade_cost(level: int) -> int:
	return 300 + level * level * 250


## Picks an item for a racer in [param place] (1 = leading).
static func roll_item(place: int, rng: RandomNumberGenerator) -> String:
	var back := float(place - 1) / float(RACERS - 1)
	var weights := {
		"boost": 2.0 + back * 4.0,
		"rocket": 1.0 + back * 4.0,
		"shield": 3.0 - back * 1.5,
		"oil": 3.5 - back * 2.5,
		"triple": back * 3.0,
	}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "boost"


static func coins_for(place: int) -> int:
	return COINS[clampi(place, 1, COINS.size()) - 1]


static func points_for(place: int) -> int:
	return POINTS[clampi(place, 1, POINTS.size()) - 1]


## A closed Catmull-Rom curve through the control points, sampled every ~[param step] metres.
static func sample_track(points: Array, step: float = 2.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	for i in n:
		var p0: Vector2 = points[(i - 1 + n) % n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % n]
		var p3: Vector2 = points[(i + 2) % n]
		var seg := int(ceil(p1.distance_to(p2) / step))
		for s in seg:
			var t := float(s) / seg
			var t2 := t * t
			var t3 := t2 * t
			var v := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			out.append(Vector3(v.x, 0, v.y))
	return out


static func track_length(samples: PackedVector3Array) -> float:
	var total := 0.0
	for i in samples.size():
		total += samples[i].distance_to(samples[(i + 1) % samples.size()])
	return total
