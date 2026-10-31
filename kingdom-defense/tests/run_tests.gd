extends SceneTree
## Unit tests for the defense rules. Run with:
##   godot --headless --path kingdom-defense -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_paths()
	_waves()
	_towers()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _paths() -> void:
	for n in range(1, GameData.LEVELS + 1):
		var p := GameData.path(n)
		check(p.size() >= 10, "level %d road is long enough (%d)" % [n, p.size()])
		var seen := {}
		for i in p.size():
			check(Hex.buildable(p[i]), "level %d road stays on the island" % n)
			check(not seen.has(p[i]), "level %d road never repeats a cell" % n)
			seen[p[i]] = true
			if i > 0:
				check(Hex.distance(p[i], p[i - 1]) == 1, "level %d road is continuous" % n)
		check(Hex.distance(p[0], Vector2i.ZERO) == Hex.BUILD_RADIUS, "level %d starts at the edge" % n)
		# Room to build: plenty of grass cells next to the road.
		var spots := {}
		for c in p:
			for d in Hex.DIRS:
				var q: Vector2i = c + d
				if Hex.buildable(q) and not seen.has(q):
					spots[q] = true
		check(spots.size() >= 12, "level %d has room for towers (%d)" % [n, spots.size()])
	check(GameData.path(4) == GameData.path(4), "roads are deterministic")


func _waves() -> void:
	for n in range(1, GameData.LEVELS + 1):
		var last := GameData.wave(n, GameData.wave_count(n))
		check(last.has("boss"), "level %d ends with a boss" % n)
		for w in range(1, GameData.wave_count(n) + 1):
			for k in GameData.wave(n, w):
				check(GameData.ENEMIES.has(k), "enemy %s exists" % k)
	check(GameData.wave(1, 1).size() < GameData.wave(1, 8).size(), "waves grow")
	check(GameData.health_scale(5, 5) > GameData.health_scale(1, 1), "enemies toughen")
	check(GameData.stars(20) == 3 and GameData.stars(12) == 2 and GameData.stars(3) == 1 and GameData.stars(0) == 0, "stars from lives")


func _towers() -> void:
	for kind in GameData.TOWER_ORDER:
		var t := GameData.tower(kind)
		check((t["cost"] as Array).size() == 3, "%s has three levels" % kind)
		check(ResourceLoader.exists(Models.hex("building_%s_blue" % t["model"])), "%s model exists" % kind)
		check(GameData.sell_value(kind, 2) > GameData.sell_value(kind, 1), "%s sells for more when upgraded" % kind)
		if t.has("damage"):
			check(float(GameData.at(t["damage"], 3)) > float(GameData.at(t["damage"], 1)), "%s upgrades hit harder" % kind)
	check(GameData.START_GOLD >= int(GameData.at(GameData.tower("archer")["cost"], 1)) * 2, "you can afford two archer towers at the start")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({})
	check(save.unlocked() == 1, "only level 1 is open")
	save.finish_level(1, 2)
	check(save.unlocked() == 2 and save.total_stars() == 2, "winning opens the next level")
	save.finish_level(1, 1)
	check(save.level_stars(1) == 2, "a worse result keeps the best stars")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.level_stars(1) == 2, "progress survives a save")
	save.free()
	copy.free()
