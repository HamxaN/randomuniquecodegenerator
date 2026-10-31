extends SceneTree
## Unit tests for the dungeon rules. Run with:
##   godot --headless --path dungeon-raiders -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_floors()
	_monsters()
	_loot()
	_progress()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _floors() -> void:
	for floor_n in range(1, 16):
		for seed_value in [1, 7, 42, 1234]:
			var rooms: Array = DungeonGen.generate(floor_n, seed_value)["rooms"]
			check(rooms.size() == GameData.room_count(floor_n), "floor %d has %d rooms" % [floor_n, GameData.room_count(floor_n)])
			var kinds := {}
			var cells := {}
			for r in rooms:
				kinds[r["kind"]] = int(kinds.get(r["kind"], 0)) + 1
				check(not cells.has(r["cell"]), "rooms don't overlap")
				cells[r["cell"]] = r
			check(int(kinds.get("start", 0)) == 1 and int(kinds.get("boss", 0)) == 1, "one start and one boss room")
			# Every room can be reached from the start.
			var seen := {Vector2i.ZERO: true}
			var queue: Array = [Vector2i.ZERO]
			while queue.size() > 0:
				var c: Vector2i = queue.pop_front()
				for l in cells[c]["links"]:
					check(cells.has(l), "links point at real rooms")
					if not seen.has(l):
						seen[l] = true
						queue.append(l)
			check(seen.size() == rooms.size(), "every room is reachable")
			var max_depth := 0
			var boss_depth := 0
			for r in rooms:
				max_depth = maxi(max_depth, int(r["depth"]))
				if r["kind"] == "boss":
					boss_depth = int(r["depth"])
			check(boss_depth == max_depth, "the boss is in the farthest room")
	check(GameData.room_count(20) > GameData.room_count(1), "deeper floors are bigger")


func _monsters() -> void:
	for floor_n in range(1, 12):
		var list := GameData.room_monsters(floor_n, 2, floor_n * 3)
		check(list.size() >= 3 and list.size() <= 12, "room has 3 to 12 monsters")
		for k in list:
			check(GameData.ENEMIES.has(k), "monster %s exists" % k)
		if floor_n < 2:
			check(not list.has("warrior"), "no bone knights on floor 1")
	check(GameData.monster_scale(5) > GameData.monster_scale(1), "monsters get tougher")
	check(GameData.ENEMIES.has(GameData.boss_for(1)) and GameData.ENEMIES.has(GameData.boss_for(2)), "bosses exist")
	check(GameData.boss_for(1) != GameData.boss_for(2), "bosses alternate")


func _loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := {}
	for i in 2000:
		var item := GameData.roll_item(3, rng)
		check(GameData.SLOTS.has(item["slot"]), "item has a slot")
		check(int(item["power"]) > 0, "item has power")
		counts[item["rarity"]] = int(counts.get(item["rarity"], 0)) + 1
	check(int(counts.get("common", 0)) > int(counts.get("rare", 0)), "commons are commoner than rares")
	check(int(counts.get("rare", 0)) > int(counts.get("epic", 0)), "rares are commoner than epics")
	check(int(counts.get("legendary", 0)) > 0, "legendaries do drop")
	var weak := {"slot": "weapon", "rarity": "common", "power": 10, "name": "a"}
	var strong := {"slot": "weapon", "rarity": "epic", "power": 40, "name": "b"}
	check(GameData.sell_value(strong) > GameData.sell_value(weak), "better items sell for more")
	check(GameData.item_stat(weak) == "+10 Attack", "weapon stat text")


func _progress() -> void:
	check(GameData.xp_for_level(5) > GameData.xp_for_level(1), "levels need more XP")
	check(GameData.talent_cost(5) > GameData.talent_cost(1), "talents get pricier")
	for s in 30:
		var b := GameData.boon_choices(s)
		check(b.size() == 3 and b[0]["id"] != b[1]["id"] and b[1]["id"] != b[2]["id"] and b[0]["id"] != b[2]["id"], "three different boons")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({})
	check(save.owned.has("knight"), "the knight is free")
	var weak := {"slot": "weapon", "rarity": "common", "power": 10, "name": "a"}
	var strong := {"slot": "weapon", "rarity": "epic", "power": 40, "name": "b"}
	check(save.offer_item(weak), "first weapon is equipped")
	check(save.offer_item(strong), "a better weapon replaces it")
	var gold_before: int = save.gold
	check(not save.offer_item(weak), "a worse weapon is sold")
	check(save.gold > gold_before, "selling gives gold")
	var stats: Dictionary = save.hero_stats("knight")
	check(float(stats["attack"]) >= 14.0 + 40.0, "gear adds attack")
	save.gold = 100000
	check(save.buy_talent("might") and save.talent("might") == 1, "buy a talent")
	check(save.buy_hero("mage") and save.hero == "mage", "buy a hero")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.owned.has("mage") and copy.gear_power("weapon") == 40, "profile survives a save")
	save.free()
	copy.free()
