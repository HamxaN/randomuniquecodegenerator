extends SceneTree
## Unit tests for the course generator: every jump must be possible. Run with:
##   godot --headless --path sky-hop -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_courses()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _top(p: Dictionary) -> float:
	var y := (p["pos"] as Vector3).y
	var move: Vector3 = p["move"]
	return y + (move.y if move.y > 0.0 else 0.0)


func _courses() -> void:
	var h := GameData.max_height()
	check(h > 2.0, "a double jump clears 2 m (%.2f)" % h)
	var bounce_h := GameData.BOUNCE * GameData.BOUNCE / (2.0 * GameData.GRAVITY)
	for n in range(1, GameData.level_count() + 1):
		var c := GameData.course(n)
		var pieces: Array = c["pieces"]
		check(pieces.size() >= 10, "level %d has a real course" % n)
		check((c["stars"] as Array).size() == 3, "level %d hides three stars" % n)
		check((c["coins"] as Array).size() >= 10, "level %d has plenty of coins" % n)
		check((c["checkpoints"] as Array).size() >= 2, "level %d has checkpoints" % n)
		for i in range(1, pieces.size()):
			var a: Dictionary = pieces[i - 1]
			var b: Dictionary = pieces[i]
			var pa: Vector3 = a["pos"]
			var pb: Vector3 = b["pos"]
			var flat := Vector2(pb.x - pa.x, pb.z - pa.z)
			var gap := flat.length() - float(a["half"]) - float(b["half"])
			var rise := (pb.y) - _top(a)
			if a["kind"] == "bounce":
				check(rise <= bounce_h - 0.3, "level %d piece %d: bounce pad reaches the next platform" % [n, i])
				check(gap <= 6.0, "level %d piece %d: bounce gap is fair" % [n, i])
			else:
				check(gap <= GameData.MAX_GAP + 1.4, "level %d piece %d: gap %.2f can be jumped" % [n, i, gap])
				check(rise <= h * 0.8, "level %d piece %d: step %.2f can be climbed" % [n, i, rise])
		var goal: Vector3 = c["goal"]
		check(goal.z < -40.0, "level %d is long enough" % n)
	check(GameData.course(3) == GameData.course(3), "courses are deterministic")
	check((GameData.course(18)["pieces"] as Array).size() > (GameData.course(1)["pieces"] as Array).size(), "later courses are longer")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({})
	check(save.unlocked() == 1, "only level 1 is open")
	save.finish_level(1, 2, 40, 61.0)
	check(save.unlocked() == 2 and save.level_stars(1) == 2 and save.coins == 40, "finishing opens the next level")
	save.finish_level(1, 1, 10, 50.0)
	check(save.level_stars(1) == 2 and float(save.times["1"]) == 50.0, "best stars and best time are kept")
	check(not save.buy_skin("gold"), "can't afford gold yet")
	save.coins = 5000
	check(save.buy_skin("gold") and save.skin == "gold", "buy a skin")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.owned.has("gold") and copy.level_stars(1) == 2, "progress survives a save")
	save.free()
	copy.free()
