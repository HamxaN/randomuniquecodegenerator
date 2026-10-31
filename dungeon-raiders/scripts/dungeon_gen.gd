class_name DungeonGen
## Lays out a floor: rooms on a grid joined by corridors. The start room is the
## first, the boss room is the one farthest from it, and one dead end holds treasure.

const ROOM_TILES := 5
const TILE := 4.0
const SPACING := 32.0


## Returns {rooms: Array of {cell, kind, links}, seed}. kind is start, fight, treasure or boss.
static func generate(floor_n: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := GameData.room_count(floor_n)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var links := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var guard := 0
	while cells.size() < count and guard < 2000:
		guard += 1
		var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var d: Vector2i = dirs[rng.randi_range(0, 3)]
		var to := from + d
		if cells.has(to) or _neighbours(cells, to) > 1:
			continue
		cells.append(to)
		_link(links, from, to)
	# Distances from the start, to place the boss at the end of the longest path.
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		for n in links.get(c, []):
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	var boss := Vector2i.ZERO
	for c in cells:
		if int(dist.get(c, 0)) > int(dist.get(boss, 0)):
			boss = c
	var treasure := Vector2i(999, 999)
	for c in cells:
		if c != boss and c != Vector2i.ZERO and (links.get(c, []) as Array).size() == 1:
			treasure = c
			break
	var rooms: Array[Dictionary] = []
	for c in cells:
		var kind := "fight"
		if c == Vector2i.ZERO:
			kind = "start"
		elif c == boss:
			kind = "boss"
		elif c == treasure:
			kind = "treasure"
		rooms.append({"cell": c, "kind": kind, "links": links.get(c, []), "depth": int(dist.get(c, 0))})
	return {"rooms": rooms}


static func _neighbours(cells: Array[Vector2i], c: Vector2i) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cells.has(c + d):
			n += 1
	return n


static func _link(links: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not links.has(a):
		links[a] = []
	if not links.has(b):
		links[b] = []
	(links[a] as Array).append(b)
	(links[b] as Array).append(a)


static func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * SPACING, 0, cell.y * SPACING)


static func half_size() -> float:
	return ROOM_TILES * TILE / 2.0
