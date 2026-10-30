class_name Hex
## Pointy-top hex grid in axial coordinates (q, r). One hex is 2 units wide,
## matching the KayKit tiles.

const W := 2.0
const ROW := 1.7320508
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
## Cells within this distance of the centre can be built on.
const BUILD_RADIUS := 5
const LAND_RADIUS := 7
const WATER_RADIUS := 12


static func to_world(cell: Vector2i) -> Vector3:
	return Vector3(W * (cell.x + cell.y * 0.5), 0, ROW * cell.y)


static func from_world(p: Vector3) -> Vector2i:
	var r := p.z / ROW
	var q := p.x / W - r * 0.5
	return round_axial(q, r)


static func round_axial(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundi(qf)
	var r := roundi(rf)
	var s := roundi(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(q, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


static func ring(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius == 0:
		out.append(Vector2i.ZERO)
		return out
	var cell: Vector2i = DIRS[4] * radius
	for side in 6:
		for step in radius:
			out.append(cell)
			cell += DIRS[side]
	return out


static func disc(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in radius + 1:
		out.append_array(ring(r))
	return out


static func random_on_ring(rng: RandomNumberGenerator, radius: int) -> Vector2i:
	var cells := ring(radius)
	return cells[rng.randi_range(0, cells.size() - 1)]


static func buildable(cell: Vector2i) -> bool:
	return distance(cell, Vector2i.ZERO) <= BUILD_RADIUS
