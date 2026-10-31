class_name GameData
## How the sky courses are put together, how high and far you can jump, skins
## and rewards. The level generator is pure maths, so it is unit tested.

const RUN_SPEED := 5.0
const JUMP := 7.6
const DOUBLE_JUMP := 6.8
const GRAVITY := 22.0
const BOUNCE := 14.0
## The farthest gap (edge to edge) and highest step the generator will ever ask for.
const MAX_GAP := 2.6
const MAX_STEP := 1.1

const WORLDS := [
	{"name": "Meadow Isles", "sky_top": Color(0.3, 0.6, 0.95), "horizon": Color(0.8, 0.92, 1.0), "ground": Color(0.5, 0.75, 0.4)},
	{"name": "Sunset Bay", "sky_top": Color(0.35, 0.3, 0.7), "horizon": Color(1.0, 0.7, 0.5), "ground": Color(0.85, 0.6, 0.4)},
	{"name": "Frost Peaks", "sky_top": Color(0.4, 0.6, 0.85), "horizon": Color(0.9, 0.95, 1.0), "ground": Color(0.9, 0.95, 1.0)},
	{"name": "Starry Night", "sky_top": Color(0.05, 0.06, 0.18), "horizon": Color(0.25, 0.22, 0.45), "ground": Color(0.4, 0.4, 0.6)},
]
const LEVELS_PER_WORLD := 5

const SKINS := [
	{"id": "classic", "name": "Classic", "color": Color(1, 1, 1), "cost": 0},
	{"id": "berry", "name": "Berry", "color": Color(1.0, 0.6, 0.7), "cost": 150},
	{"id": "mint", "name": "Mint", "color": Color(0.6, 1.0, 0.75), "cost": 250},
	{"id": "sky", "name": "Sky", "color": Color(0.6, 0.8, 1.0), "cost": 350},
	{"id": "gold", "name": "Golden", "color": Color(1.0, 0.85, 0.35), "cost": 600},
	{"id": "shadow", "name": "Shadow", "color": Color(0.45, 0.42, 0.55), "cost": 900},
]


static func level_count() -> int:
	return WORLDS.size() * LEVELS_PER_WORLD


static func world_of(level_n: int) -> Dictionary:
	return WORLDS[clampi((level_n - 1) / LEVELS_PER_WORLD, 0, WORLDS.size() - 1)]


static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


## Builds a course. Returns {pieces, coins, stars, checkpoints, goal, blocks}.
## A piece is {kind, model, pos, half, move, period}: kind is static, falling,
## mover or bounce; half is the half-width of its top; move is its swing.
static func course(level_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_n * 4241 + 9
	var pieces: Array[Dictionary] = []
	var coins: Array[Vector3] = []
	var stars: Array[Vector3] = []
	var checkpoints: Array[Vector3] = []
	var blocks: Array[Vector3] = []
	var pos := Vector3.ZERO
	pieces.append(_piece("static", "platform-grass-large-round", pos, 2.5))
	checkpoints.append(pos + Vector3(0, 0.6, 0))
	var last_half := 2.5
	var segments := 9 + level_n
	var star_at := [segments / 4, segments / 2, segments * 3 / 4]
	var difficulty := clampf(float(level_n) / level_count(), 0.0, 1.0)
	for s in segments:
		var roll := rng.randf()
		var kind := "hop"
		if s > 0 and s % 6 == 0:
			kind = "checkpoint"
		elif roll < 0.18:
			kind = "small"
		elif roll < 0.18 + 0.12 + difficulty * 0.08:
			kind = "mover"
		elif roll < 0.42 + difficulty * 0.12:
			kind = "falling"
		elif roll < 0.55 + difficulty * 0.12:
			kind = "bounce"
		elif roll < 0.66 + difficulty * 0.1:
			kind = "lift"
		elif roll < 0.74 + difficulty * 0.1:
			kind = "blocks"
		var gap := rng.randf_range(1.2, 1.8 + difficulty * 0.8)
		var side := rng.randf_range(-1.6, 1.6)
		var rise := rng.randf_range(-0.6, MAX_STEP * (0.5 + difficulty * 0.5))
		match kind:
			"small":
				for k in 3:
					var half := 1.0
					pos += Vector3(side * 0.5, rng.randf_range(-0.3, 0.7), -(last_half + gap * 0.8 + half))
					pieces.append(_piece("static", "platform", pos, half))
					coins.append(pos + Vector3(0, 1.2, 0))
					last_half = half
			"mover":
				var half := 1.5
				pos += Vector3(side, rise * 0.5, -(last_half + gap + half))
				var p := _piece("mover", "platform-medium", pos, half)
				p["move"] = Vector3(rng.randf_range(1.5, 2.5) * (1.0 if rng.randf() < 0.5 else -1.0), 0, 0)
				p["period"] = rng.randf_range(3.0, 4.5)
				pieces.append(p)
				coins.append(pos + Vector3(0, 1.3, 0))
				last_half = half
				# The next piece starts from where the mover is at rest, so it's reachable.
			"lift":
				var half := 1.5
				pos += Vector3(side, 0, -(last_half + gap + half))
				var p := _piece("mover", "platform-medium", pos, half)
				p["move"] = Vector3(0, 2.4, 0)
				p["period"] = 4.0
				pieces.append(p)
				pos += Vector3(0, 2.4, -(half + 1.4 + 1.5))
				pieces.append(_piece("static", "platform-medium", pos, 1.5))
				coins.append(pos + Vector3(0, 1.2, 0))
				last_half = 1.5
			"falling":
				for k in 3:
					var half := 1.1
					pos += Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.2, 0.3), -(last_half + gap * 0.7 + half))
					pieces.append(_piece("falling", "platform-falling", pos, half))
					coins.append(pos + Vector3(0, 1.2, 0))
					last_half = half
			"bounce":
				var half := 1.0
				pos += Vector3(side * 0.5, rise * 0.3, -(last_half + gap + half))
				pieces.append(_piece("bounce", "platform", pos, half))
				pos += Vector3(0, 4.0, -(half + 1.6 + 2.5))
				pieces.append(_piece("static", "platform-large", pos, 2.5))
				for k in 4:
					coins.append(pos + Vector3(0, 1.0, 1.8 - k * 1.2))
				last_half = 2.5
			"blocks":
				var half := 2.5
				pos += Vector3(side, rise * 0.5, -(last_half + gap + half))
				pieces.append(_piece("static", "platform-large", pos, half))
				blocks.append(pos + Vector3(0, 2.3, 0))
				last_half = half
			"checkpoint":
				var half := 2.5
				pos += Vector3(side * 0.5, rise * 0.4, -(last_half + gap + half))
				pieces.append(_piece("static", "platform-grass-large-round", pos, half))
				checkpoints.append(pos + Vector3(0, 0.6, 0))
				last_half = half
			_:
				var half := 1.5 if rng.randf() < 0.6 else 2.5
				pos += Vector3(side, rise, -(last_half + gap + half))
				pieces.append(_piece("static", "platform-medium" if half < 2.0 else "platform-large", pos, half))
				# An arc of coins over the gap.
				for k in 3:
					coins.append(pos + Vector3(0, 1.0 + sin(PI * (k + 1) / 4.0) * 1.2, half + gap * (k + 1) / 4.0))
				last_half = half
		if star_at.has(s):
			var last: Dictionary = pieces[-1]
			stars.append((last["pos"] as Vector3) + Vector3(0, 1.6 + (0.8 if last["kind"] == "mover" else 0.0), 0))
	var goal := pos + Vector3(0, 0, -(last_half + 1.8 + 2.5))
	pieces.append(_piece("static", "platform-grass-large-round", goal, 2.5))
	return {"pieces": pieces, "coins": coins, "stars": stars, "checkpoints": checkpoints, "goal": goal, "blocks": blocks}


static func _piece(kind: String, model: String, pos: Vector3, half: float) -> Dictionary:
	return {"kind": kind, "model": model, "pos": pos, "half": half, "move": Vector3.ZERO, "period": 0.0}


## Jump height with a double jump, for the reachability tests.
static func max_height() -> float:
	return JUMP * JUMP / (2.0 * GRAVITY) + DOUBLE_JUMP * DOUBLE_JUMP / (2.0 * GRAVITY)


static func stars_for(collected: int) -> int:
	return clampi(collected, 0, 3)


static func coins_reward(coins: int, stars: int) -> int:
	return coins + stars * 20
