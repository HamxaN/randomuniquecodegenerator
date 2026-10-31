class_name GameData
## The rules: towers and their upgrades, the skeleton horde, the road each
## level winds along, how waves grow, and stars. Pure data, unit tested.

## Per-level arrays are indexed by tower level - 1 (levels 1 to 3).
const TOWERS := {
	"archer": {"name": "Archer Tower", "model": "tower_A", "desc": "Fast arrows at one target.",
		"cost": [70, 110, 170], "damage": [10, 17, 28], "rate": [1.3, 1.5, 1.8], "range": [6.5, 7.0, 7.6], "splash": 0.0, "slow": 0.0},
	"catapult": {"name": "Catapult", "model": "tower_catapult", "desc": "Boulders that crush groups.",
		"cost": [120, 170, 250], "damage": [30, 50, 80], "rate": [0.36, 0.42, 0.5], "range": [8.0, 8.5, 9.0], "splash": 1.8, "slow": 0.0, "min_range": 2.0},
	"mage": {"name": "Mage Tower", "model": "tower_B", "desc": "Magic bolts pierce armour and slow foes.",
		"cost": [100, 150, 230], "damage": [13, 21, 34], "rate": [1.0, 1.1, 1.3], "range": [6.0, 6.5, 7.0], "splash": 0.0, "slow": 0.4},
	"mine": {"name": "Gold Mine", "model": "mine", "desc": "Digs up gold every few seconds.",
		"cost": [90, 140, 210], "income": [6, 11, 18], "rate": [0.1, 0.1, 0.1]},
}
const TOWER_ORDER := ["archer", "catapult", "mage", "mine"]

const ENEMIES := {
	"minion": {"name": "Skeleton", "model": "Skeleton_Minion", "hp": 42.0, "speed": 1.7, "armor": 0.0, "gold": 4, "damage": 8.0, "scale": 1.0},
	"runner": {"name": "Bone Runner", "model": "Skeleton_Rogue", "hp": 30.0, "speed": 2.8, "armor": 0.0, "gold": 5, "damage": 6.0, "scale": 0.95},
	"knight": {"name": "Bone Knight", "model": "Skeleton_Warrior", "hp": 130.0, "speed": 1.15, "armor": 0.45, "gold": 9, "damage": 16.0, "scale": 1.12},
	"mage": {"name": "Necromancer", "model": "Skeleton_Mage", "hp": 70.0, "speed": 1.4, "armor": 0.1, "gold": 8, "damage": 10.0, "scale": 1.0},
	"boss": {"name": "Bone Colossus", "model": "Skeleton_Warrior", "hp": 1300.0, "speed": 0.85, "armor": 0.3, "gold": 80, "damage": 40.0, "scale": 1.9},
}

const LEVELS := 12
const LIVES := 20
const START_GOLD := 230
const SELL_BACK := 0.6
const HERO := {"hp": 320.0, "damage": 26.0, "rate": 1.2, "reach": 1.5, "speed": 3.2, "respawn": 10.0}
const NAMES := ["Green Valley", "Old Mill", "Crossroads", "River Bend", "Sandy Ford", "Dune Pass", "Red Cliffs",
	"Frost Gate", "Snowfall", "Ashen Fields", "Ember Road", "The Last Keep"]
const THEMES := ["grass", "grass", "grass", "grass", "sand", "sand", "sand", "snow", "snow", "ash", "ash", "ash"]


static func tower(kind: String) -> Dictionary:
	return TOWERS[kind]


static func at(values: Array, level: int) -> Variant:
	return values[clampi(level, 1, values.size()) - 1]


## Gold back when selling a tower (a share of everything spent on it).
static func sell_value(kind: String, level: int) -> int:
	var spent := 0
	for lv in range(1, level + 1):
		spent += int(at(TOWERS[kind]["cost"], lv))
	return int(spent * SELL_BACK)


static func wave_count(level_n: int) -> int:
	return 8 + level_n


## The enemies of wave [param w] (1-based) on level [param level_n], in order.
static func wave(level_n: int, w: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_n * 1000 + w
	var out: Array[String] = []
	var count := 6 + w * 2 + level_n
	for i in count:
		var r := rng.randf()
		var kind := "minion"
		if w >= 3 and r > 0.8:
			kind = "knight"
		elif w >= 2 and r > 0.6:
			kind = "runner"
		elif w >= 5 and r > 0.5:
			kind = "mage"
		out.append(kind)
	if w == wave_count(level_n) or (w % 5 == 0 and level_n >= 4):
		out.append("boss")
	return out


static func health_scale(level_n: int, w: int) -> float:
	return 1.0 + 0.09 * float(w - 1) + 0.14 * float(level_n - 1)


static func stars(lives_left: int) -> int:
	if lives_left <= 0:
		return 0
	if lives_left >= 18:
		return 3
	if lives_left >= 10:
		return 2
	return 1


## The road for a level: a chain of neighbouring hex cells from the enemy gate on
## one edge of the island to your castle on the other.
static func path(level_n: int) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_n * 7331 + 11
	var r := Hex.BUILD_RADIUS
	var start_dir: Vector2i = Hex.DIRS[level_n % 6]
	var start: Vector2i = start_dir * r
	var goal: Vector2i = -start_dir * (r - 1)
	for attempt in 300:
		var cells: Array[Vector2i] = [start]
		var used := {start: true}
		var cur := start
		var ok := true
		while cur != goal:
			var options: Array[Vector2i] = []
			for d in Hex.DIRS:
				var n: Vector2i = cur + d
				if used.has(n) or Hex.distance(n, Vector2i.ZERO) > r:
					continue
				# Keep the road one cell wide: don't touch older parts of it.
				var touches := 0
				for d2 in Hex.DIRS:
					if used.has(n + d2):
						touches += 1
				if touches > 1:
					continue
				options.append(n)
			if options.is_empty():
				ok = false
				break
			options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Hex.distance(a, goal) < Hex.distance(b, goal))
			# Mostly head for the castle, sometimes wander for a longer, twistier road.
			var pick: Vector2i = options[0]
			if options.size() > 1 and rng.randf() < 0.45:
				pick = options[rng.randi_range(0, mini(options.size() - 1, 2))]
			cells.append(pick)
			used[pick] = true
			cur = pick
			if cells.size() > 60:
				ok = false
				break
		if ok and cells.size() >= 12:
			return cells
	# Fallback: a straight line.
	var line: Array[Vector2i] = []
	var c := start
	while c != goal:
		line.append(c)
		c -= start_dir
	line.append(goal)
	return line
