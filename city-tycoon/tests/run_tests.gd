extends SceneTree
## Unit tests for the city rules. Run with:
##   godot --headless --path city-tycoon -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_roads()
	_building()
	_growth()
	_happiness()
	_budget()
	_milestones()
	_save()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _empty() -> CityState:
	var s := CityState.new()
	for i in s.tiles.size():
		s.tiles[i] = {"type": "", "level": 0, "growth": 0.0}
	s.money = 100000
	return s


func _roads() -> void:
	# Every combination of neighbours gets a piece whose openings match it.
	var openings := {"road_straight": 5, "road_corner": 6, "road_tsplit": 7, "road_junction": 15}
	for mask in 16:
		var piece := GameData.road_piece(mask)
		var m := int(openings[piece[0]])
		for k in int(piece[1]):
			m = GameData.rotate_mask(m)
		if mask in [0, 1, 2, 4, 8]:
			check(m & mask == mask, "a lone or dead-end road (%d) still lines up" % mask)
		else:
			check(m == mask, "road mask %d gets the right piece and turn" % mask)
	check(GameData.rotate_mask(GameData.rotate_mask(GameData.rotate_mask(GameData.rotate_mask(6)))) == 6, "four turns go all the way round")
	var s := _empty()
	s.build("road", Vector2i(5, 5))
	s.build("road", Vector2i(6, 5))
	s.build("road", Vector2i(5, 4))
	check(s.road_mask(Vector2i(5, 5)) == 1 | 2, "road neighbours are found (north and east)")
	check(s.connected(Vector2i(8, 8)) == false and s.connected(Vector2i(6, 4)), "lots next to roads are connected")


func _building() -> void:
	var s := _empty()
	var m0 := s.money
	check(s.build("res", Vector2i(2, 2)) and s.money == m0 - int(GameData.ZONES["res"]["cost"]), "zoning costs money")
	check(not s.build("com", Vector2i(2, 2)), "can't build on top of something")
	check(s.build_error("office", Vector2i(3, 3)) != "", "offices wait for the Town milestone")
	check(s.build_error("road", Vector2i(-1, 3)) != "", "not outside the city limits")
	s.money = 0
	check(not s.build("road", Vector2i(4, 4)), "no money, no road")
	s.money = 100
	check(s.bulldoze(Vector2i(2, 2)) and s.type_at(Vector2i(2, 2)) == "", "bulldozing clears a tile")
	check(not s.bulldoze(Vector2i(2, 2)), "nothing left to bulldoze")


func _growth() -> void:
	var s := _empty()
	for x in range(2, 12):
		s.build("road", Vector2i(x, 5))
	s.build("res", Vector2i(3, 4))
	s.build("res", Vector2i(4, 4))
	s.build("com", Vector2i(6, 4))
	s.build("ind", Vector2i(10, 6))
	s.build("res", Vector2i(3, 1))   # no road
	s.build("park", Vector2i(4, 3))
	s.build("park", Vector2i(3, 3))
	for i in 600:
		s.tick(0.5)
	check(s.population() > 0, "people move in")
	check(s.jobs() > 0, "businesses hire")
	check(float(s.at(Vector2i(3, 1))["growth"]) == 0.0, "lots without a road don't grow")
	check(int(s.at(Vector2i(3, 4))["level"]) >= 2, "happy homes grow taller")
	check(s.population() <= 2 * GameData.residents(3) + GameData.residents(1), "never more people than homes hold")


func _happiness() -> void:
	var s := _empty()
	s.build("road", Vector2i(5, 6))
	s.build("res", Vector2i(5, 5))
	var base := s.happiness_at(Vector2i(5, 5))
	s.build("park", Vector2i(6, 5))
	check(s.happiness_at(Vector2i(5, 5)) > base, "parks make neighbours happier")
	s.build("ind", Vector2i(4, 5))
	s.build("ind", Vector2i(5, 4))
	check(s.happiness_at(Vector2i(5, 5)) < base + 10, "factories next door hurt")
	check(s.happiness_at(Vector2i(5, 5)) >= 0 and s.happiness_at(Vector2i(5, 5)) <= 100, "happiness stays 0-100")


func _budget() -> void:
	var s := _empty()
	for x in 10:
		s.build("road", Vector2i(x, 0))
	check(s.upkeep() > 0.0, "roads cost upkeep")
	var m0 := s.money
	s.tick(GameData.DAY + 0.01)
	check(s.day == 2 and s.money < m0, "an empty town loses money each day")
	s.build("res", Vector2i(1, 1))
	s.tiles[s.idx(Vector2i(1, 1))]["level"] = 3
	s.tiles[s.idx(Vector2i(1, 1))]["growth"] = 1.0
	check(s.income() > 0.0, "residents pay taxes")


func _milestones() -> void:
	check(GameData.milestone_index(0) == 0 and GameData.milestone_index(100) == 1 and GameData.milestone_index(99999) == GameData.MILESTONES.size() - 1, "milestones by population")
	var s := _empty()
	var reached := [0]
	s.milestone.connect(func(i: int) -> void: reached[0] = i)
	for x in 12:
		s.build("road", Vector2i(x, 0))
		s.build("res", Vector2i(x, 1))
		s.tiles[s.idx(Vector2i(x, 1))]["level"] = 3
		s.tiles[s.idx(Vector2i(x, 1))]["growth"] = 1.0
	var m0 := s.money
	s.tick(0.1)
	check(int(reached[0]) >= 2 and s.stage >= 2, "a big population passes milestones")
	check(s.money > m0, "milestones pay a reward")
	check(GameData.unlocked("office", s.stage) and GameData.unlocked("plaza", s.stage), "and unlock new buildings")


func _save() -> void:
	var s := _empty()
	s.build("road", Vector2i(1, 1))
	s.build("res", Vector2i(1, 2))
	s.day = 9
	var c := CityState.new()
	c.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(c.type_at(Vector2i(1, 2)) == "res" and c.day == 9 and c.money == s.money, "the city round-trips")
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({"city": s.to_dict(), "sound": false})
	check(save.city.type_at(Vector2i(1, 1)) == "road" and not save.sound, "the save file loads the city")
	save.free()
