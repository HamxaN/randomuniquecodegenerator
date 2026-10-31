extends SceneTree
## Unit tests for the colony rules. Run with:
##   godot --headless --path space-colony -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_data()
	_placing()
	_economy()
	_power()
	_colonists()
	_construction()
	_missions()
	_offline_and_save()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _data() -> void:
	for type in GameData.BUILD_ORDER:
		var lv := GameData.unlock_level(type)
		check(lv >= 1 and lv <= GameData.HQ_MAX, "%s unlocks at some Hub level" % type)
		for n in range(1, GameData.HQ_MAX):
			check(GameData.limit(type, n + 1) >= GameData.limit(type, n), "%s limits never shrink" % type)
		for level in range(0, GameData.MAX_LEVEL):
			var a: Array = GameData.cost(type, level)
			var b: Array = GameData.cost(type, level + 1)
			check(int(b[0]) > int(a[0]), "%s upgrades get pricier" % type)
	for y in GameData.ROWS:
		for x in GameData.COLS:
			var c := Vector2i(x, y)
			check(GameData.world_to_cell(GameData.cell_to_world(c)) == c, "cell %s maps to the world and back" % c)
	for cell in GameData.ORE_CELLS + GameData.CRYSTAL_CELLS:
		check(GameData.in_bounds(cell) and cell != GameData.HQ_CELL, "deposit %s is on the map, off the Hub" % cell)
	check(GameData.rush_cost(1.0) == 1 and GameData.rush_cost(65.0) == 4, "rushing costs a crystal per 20 seconds")


func _placing() -> void:
	var s := ColonyState.new()
	s.credits = 99999
	s.ore = 200
	check(s.place_error("hab", GameData.HQ_CELL) != "", "can't build on the Hub")
	check(s.place_error("hab", Vector2i(-1, 0)) != "", "can't build off the map")
	check(s.place_error("drill", Vector2i(0, 0)) != "", "drills need an ore deposit")
	check(s.place_error("drill", GameData.ORE_CELLS[0]) == "", "drills fit on ore")
	check(s.place_error("hab", GameData.ORE_CELLS[0]) != "", "deposits are kept for drills")
	check(s.place_error("crystal", GameData.ORE_CELLS[0]) != "", "crystal extractors need a crystal vein")
	check(s.build_error("wind") != "", "wind turbines need Hub level 2")
	check(not s.build("solar", Vector2i(0, 0)).is_empty(), "a solar array can be built")
	check(s.build("solar", Vector2i(0, 0)).is_empty(), "not twice on the same tile")
	s.build("solar", Vector2i(1, 0))
	check(s.build_error("solar") != "", "the Hub limits how many of each")
	var poor := ColonyState.new()
	poor.credits = 10
	check(poor.build("hab", Vector2i(0, 0)).is_empty() and poor.credits == 10, "no building without the credits")


func _finish_all(s: ColonyState) -> void:
	for b in s.buildings:
		b["build"] = 0.0


func _economy() -> void:
	var s := ColonyState.new()
	var start := s.credits
	s.tick(10.0)
	check(s.credits > start, "colonists earn credits")
	check(is_equal_approx(s.credit_rate(), 4 * GameData.CREDITS_PER_COLONIST), "each colonist earns the base rate")
	s.credits = 99999
	s.build("drill", GameData.ORE_CELLS[0])
	var ore0 := s.ore
	s.tick(1.0)
	check(is_equal_approx(s.ore, ore0), "drills don't mine while under construction")
	_finish_all(s)
	s.tick(10.0)
	check(s.ore > ore0, "finished drills mine ore")
	s.ore = 0
	s.tick(100000.0)
	check(s.ore <= s.storage(), "ore is capped by storage")
	var rate := s.credit_rate()
	s.boost = 60.0
	check(is_equal_approx(s.credit_rate(), rate * 2.0), "the boost doubles credits")


func _power() -> void:
	var s := ColonyState.new()
	s.credits = 99999
	s.ore = 99999
	check(is_equal_approx(s.efficiency(), 1.0), "the Hub powers itself")
	s.build("drill", GameData.ORE_CELLS[0])
	s.build("drill", GameData.ORE_CELLS[1])
	_finish_all(s)
	check(s.power_demand() == 4.0 and s.power_supply() == 2.0, "two drills want more power than the Hub makes")
	check(is_equal_approx(s.efficiency(), 0.5), "short of power, everything runs at half speed")
	s.build("solar", Vector2i(0, 0))
	_finish_all(s)
	check(is_equal_approx(s.efficiency(), 1.0), "a solar array covers the shortfall")
	s.storm = true
	check(s.power_supply() == 4.0, "dust storms halve solar power")
	var b := s.at(Vector2i(0, 0))
	s.damage(b)
	check(not s.working(b), "meteor damage stops a building")
	check(s.repair(b) and s.working(b), "repairs bring it back")
	s.damage(s.hq())
	check(s.working(s.hq()), "the Hub can't be knocked out")


func _colonists() -> void:
	var s := ColonyState.new()
	check(s.capacity() == 4, "the Hub houses and supplies air for 4")
	s.tick(GameData.LANDER_EVERY + 1.0)
	check(s.colonists == 4, "no rockets without room")
	s.credits = 99999
	s.ore = 99999
	s.build("hab", Vector2i(0, 0))
	_finish_all(s)
	check(s.housing() == 9 and s.capacity() == 4, "homes alone aren't enough: colonists need oxygen")
	s.build("dome", Vector2i(1, 0))
	s.build("solar", Vector2i(2, 0))
	_finish_all(s)
	check(s.capacity() == 9, "with a greenhouse the new homes fill up")
	var landed := [0]
	s.lander.connect(func() -> void: landed[0] += 1)
	for i in 10:
		s.tick(GameData.LANDER_EVERY / 2.0)
	check(landed[0] > 0 and s.colonists > 4, "rockets bring colonists")
	check(s.colonists <= s.capacity(), "never more colonists than room")


func _construction() -> void:
	var s := ColonyState.new()
	s.credits = 99999
	s.ore = 99999
	var b := s.build("hab", Vector2i(0, 0))
	check(float(b["build"]) > 0.0 and not s.working(b), "buildings take time to go up")
	var done := [false]
	s.built.connect(func(_x: Dictionary) -> void: done[0] = true)
	s.tick(float(b["build"]) + 0.1)
	check(done[0] and s.working(b), "and announce when they're ready")
	check(s.upgrade(b) and int(b["level"]) == 2, "buildings can be upgraded")
	check(not s.working(b), "upgrades take time too")
	var cr := s.crystals
	check(s.rush(b) and s.crystals < cr and s.working(b), "crystals finish a build at once")
	check(not s.upgrade(b), "buildings can't outgrow the Hub by more than a level")
	check(s.upgrade(s.hq()), "the Hub can be upgraded")
	s.rush(s.hq())
	check(s.hq_level() == 2 and s.upgrade(b), "a bigger Hub allows bigger buildings")


func _missions() -> void:
	var s := ColonyState.new()
	check(not s.mission_complete(), "the first mission starts open")
	s.credits = 99999
	s.build("solar", Vector2i(0, 0))
	check(not s.mission_complete(), "a building only counts once it's finished")
	_finish_all(s)
	check(s.mission_complete(), "finishing the solar array completes the mission")
	var c := s.crystals
	check(s.claim_mission() and s.mission == 1 and s.crystals > c, "claiming pays out and moves on")
	check(not s.claim_mission(), "can't claim twice")
	for m in GameData.MISSIONS:
		check(int(m["goal"]) > 0 and int(m["credits"]) > 0, "mission '%s' has a goal and a reward" % m["text"])


func _offline_and_save() -> void:
	var s := ColonyState.new()
	var got := s.offline(600.0)
	check(int(got["credits"]) > 0, "the colony earns while you're away")
	var capped := ColonyState.new().offline(1e9)
	check(float(capped["seconds"]) == GameData.OFFLINE_CAP, "offline time is capped")
	s.credits = 99999
	s.ore = 99999
	s.build("hab", Vector2i(3, 2))
	s.crystals = 17
	var copy := ColonyState.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(copy.count("hab") == 1 and copy.at(Vector2i(3, 2))["type"] == "hab", "buildings survive saving")
	check(copy.crystals == 17 and copy.hq_level() == 1, "stockpiles survive saving")
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({"colony": s.to_dict(), "sound": false})
	check(save.colony.count("hab") == 1 and not save.sound, "the save file loads the colony and settings")
	save.free()
