class_name Zone
extends RefCounted
## The shrinking safe zone. Fully decided by the match seed, so every peer
## computes the same circles from the shared match clock.

## wait (s) before shrinking, shrink time (s), final radius, damage per second outside.
const PHASES := [
	[75.0, 40.0, 175.0, 1.0],
	[45.0, 35.0, 110.0, 2.0],
	[40.0, 30.0, 66.0, 4.0],
	[30.0, 25.0, 36.0, 7.0],
	[25.0, 20.0, 16.0, 10.0],
	[15.0, 25.0, 0.0, 16.0],
]

var centers: Array[Vector2] = []
var radii: Array[float] = []
## When each phase's wait starts (index i), and the match time the last circle closes.
var starts: Array[float] = []
var end_time := 0.0


func _init(seed_value: int, island_radius: float, start_offset: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	centers.append(Vector2.ZERO)
	radii.append(island_radius * 1.15)
	var t := start_offset
	for p in PHASES:
		starts.append(t)
		var cur_c: Vector2 = centers[centers.size() - 1]
		var cur_r: float = radii[radii.size() - 1]
		var new_r := float(p[2])
		var slack := maxf(0.0, cur_r - new_r)
		# Keep circles on land: pull the new centre towards the middle of the island.
		var c := cur_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, slack * 0.8)
		var max_off := maxf(0.0, island_radius * 0.82 - new_r)
		if c.length() > max_off:
			c = c.normalized() * max_off
		if c.distance_to(cur_c) > slack:
			c = cur_c + (c - cur_c).normalized() * slack
		centers.append(c)
		radii.append(new_r)
		t += float(p[0]) + float(p[1])
	end_time = t


## The circle at match time [param t]: centre, radius, the next circle, damage
## outside, and seconds until the next change.
func state(t: float) -> Dictionary:
	for i in PHASES.size():
		var p: Array = PHASES[i]
		var wait_end := starts[i] + float(p[0])
		var shrink_end := wait_end + float(p[1])
		if t < wait_end:
			return {"phase": i + 1, "center": centers[i], "radius": radii[i], "next_center": centers[i + 1],
				"next_radius": radii[i + 1], "dps": _dps(i), "shrinking": false, "timer": wait_end - t}
		if t < shrink_end:
			var k := (t - wait_end) / float(p[1])
			return {"phase": i + 1, "center": centers[i].lerp(centers[i + 1], k), "radius": lerpf(radii[i], radii[i + 1], k),
				"next_center": centers[i + 1], "next_radius": radii[i + 1], "dps": float(p[3]), "shrinking": true,
				"timer": shrink_end - t}
	var last := centers.size() - 1
	return {"phase": PHASES.size(), "center": centers[last], "radius": radii[last], "next_center": centers[last],
		"next_radius": radii[last], "dps": float(PHASES[PHASES.size() - 1][3]) * 1.5, "shrinking": false, "timer": 0.0}


func _dps(i: int) -> float:
	# Before the first shrink the outside still hurts a little.
	return 0.5 if i == 0 else float(PHASES[i - 1][3])


func outside(pos: Vector3, t: float) -> bool:
	var s := state(t)
	return Vector2(pos.x, pos.z).distance_to(s["center"]) > float(s["radius"])
