extends SceneTree
## Unit tests for the game rules. Run with:
##   godot --headless --path clan-fortress -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_hex()
	_buildings()
	_production()
	_troops()
	_stars()
	_campaign()
	_village()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _hex() -> void:
	for cell in Hex.disc(6):
		check(Hex.from_world(Hex.to_world(cell)) == cell, "hex round trip %s" % cell)
	check(Hex.ring(0).size() == 1, "ring 0 is the centre")
	for r in range(1, 6):
		check(Hex.ring(r).size() == 6 * r, "ring %d has %d cells" % [r, 6 * r])
		for c in Hex.ring(r):
			check(Hex.distance(c, Vector2i.ZERO) == r, "ring %d cells are at distance %d" % [r, r])
	check(Hex.disc(3).size() == 37, "disc of radius 3 has 37 cells")
	check(Hex.buildable(Vector2i(0, 0)) and not Hex.buildable(Vector2i(Hex.BUILD_RADIUS + 1, 0)), "build radius")


func _buildings() -> void:
	for kind in GameData.BUILDINGS:
		var b: Dictionary = GameData.BUILDINGS[kind]
		for key in ["hp", "cost", "time", "limit"]:
			check((b[key] as Array).size() == GameData.MAX_LEVEL, "%s has %d %s values" % [kind, GameData.MAX_LEVEL, key])
		for lv in range(2, GameData.max_level(kind) + 1):
			check(GameData.cost(kind, lv) >= GameData.cost(kind, lv - 1), "%s costs grow" % kind)
			check(GameData.build_time(kind, lv) >= GameData.build_time(kind, lv - 1), "%s build times grow" % kind)
		check(ResourceLoader.exists(Models.hex("building_%s_blue" % b["model"])), "%s has a blue model" % kind)
		check(ResourceLoader.exists(Models.hex("building_%s_red" % b["model"])), "%s has a red model" % kind)
		if b.has("defense"):
			check(float(b["range"]) > 2.0 and float(b["rate"]) > 0.0, "%s can shoot" % kind)
	check(GameData.limit("townhall", 1) == 1, "one Town Hall")
	check(GameData.limit("catapult", 1) == 0 and GameData.limit("catapult", 2) == 1, "catapults unlock at Town Hall 2")
	check(GameData.gems_to_finish(1.0) == 1 and GameData.gems_to_finish(61.0) == 4, "gem prices")


func _production() -> void:
	check(GameData.produced("goldmine", 1, 0.0) == 0, "nothing at once")
	check(GameData.produced("goldmine", 1, 60.0) == 24, "a minute of level 1 gold")
	check(GameData.produced("goldmine", 1, 999999.0) == 400, "storage cap")
	check(GameData.produced("goldmine", 3, 60.0) > GameData.produced("goldmine", 1, 60.0), "higher levels dig faster")
	check(GameData.produced("barracks", 1, 600.0) == 0, "barracks make nothing")


func _troops() -> void:
	var first := GameData.troops_for_barracks(1)
	check(first.size() == 1 and first[0] == "barbarian", "barracks 1 trains barbarians")
	check(GameData.troops_for_barracks(4).size() == 4, "barracks 4 trains everything")
	for t in GameData.TROOPS:
		var info: Dictionary = GameData.TROOPS[t]
		check(ResourceLoader.exists("res://assets/chars/%s.glb" % info["model"]), "%s model exists" % t)
		check(float(GameData.at_level(info["hp"], 5)) > float(GameData.at_level(info["hp"], 1)), "%s gets tougher" % t)
	check(GameData.troop_upgrade_cost(2) > GameData.troop_upgrade_cost(1), "troop upgrades get pricier")


func _stars() -> void:
	check(GameData.stars(0.3, false) == 0, "no stars for a scratch")
	check(GameData.stars(0.5, false) == 1, "half destroyed")
	check(GameData.stars(0.3, true) == 1, "town hall alone")
	check(GameData.stars(0.6, true) == 2, "half plus town hall")
	check(GameData.stars(1.0, true) == 3, "flattened")


func _campaign() -> void:
	var prev_size := 0
	for n in range(1, GameData.CAMPAIGN_SIZE + 1):
		var base := GameData.enemy_base(n)
		var cells := {}
		var th := 0
		for b in base:
			var cell := Vector2i(int(b["q"]), int(b["r"]))
			check(not cells.has(cell), "level %d: no two buildings share a cell" % n)
			cells[cell] = true
			check(Hex.buildable(cell), "level %d: buildings are on the island" % n)
			check(int(b["level"]) >= 1 and int(b["level"]) <= GameData.max_level(b["type"]), "level %d: building levels valid" % n)
			if b["type"] == "townhall":
				th += 1
		check(th == 1, "level %d has one Town Hall" % n)
		check(base.size() >= prev_size - 1, "level %d is not smaller than before" % n)
		prev_size = base.size()
		check(GameData.enemy_loot(n)["gold"] > 0, "level %d has loot" % n)
	check(GameData.enemy_base(5) == GameData.enemy_base(5), "levels are deterministic")
	check(GameData.enemy_base(20).size() > GameData.enemy_base(1).size(), "late villages are bigger")


func _village() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.new_village()
	check(save.count("townhall") == 1, "new village has a Town Hall")
	check(save.housing_capacity() == GameData.BASE_HOUSING + 6, "one army camp")
	var free_cell := Vector2i(3, 0)
	save.gold = 0
	check(save.place("house", free_cell) != "", "can't build without gold")
	save.gold = 10000
	save.wood = 10000
	check(save.place("house", Vector2i(0, 0)) != "", "can't build on the Town Hall")
	check(save.place("house", free_cell) == "", "build a second army camp")
	check(save.builders_busy() == 1, "a builder is busy")
	check(save.place("goldmine", Vector2i(4, 0)) == "Upgrade your Town Hall to build more", "only one mine at Town Hall 1")
	check(save.train("knight") != "", "knights need a better barracks")
	var before: int = save.wood
	check(save.train("barbarian") == "", "train a barbarian")
	check(save.wood == before - 25, "training costs wood")
	save.finish_raid(1, 2, {"gold": 100, "wood": 50}, {"barbarian": 3})
	check(save.campaign_stars(1) == 2 and save.next_campaign_level() == 2, "raid recorded")
	check(int(save.army["barbarian"]) == 5, "deployed troops are used up")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.count("house") == 2 and copy.campaign_stars(1) == 2, "village survives a save")
	save.free()
	copy.free()
