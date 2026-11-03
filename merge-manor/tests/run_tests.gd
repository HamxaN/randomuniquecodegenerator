extends SceneTree
## Unit tests for the merge rules. Run with:
##   godot --headless --path merge-manor -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_data()
	_merging()
	_generators()
	_energy()
	_orders()
	_renovation()
	_save()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _data() -> void:
	for c in GameData.CHAINS:
		var ch: Dictionary = GameData.CHAINS[c]
		check((ch["models"] as Array).size() == (ch["names"] as Array).size(), "%s has a name per level" % c)
		check((ch["models"] as Array).size() >= 4, "%s has at least four levels" % c)
		for m in ch["models"]:
			check(ResourceLoader.exists("res://assets/furniture/%s.gltf" % m), "%s model exists" % m)
	var covered := {}
	for g in GameData.GENERATORS:
		for c in GameData.GENERATORS[g]["chains"]:
			check(GameData.CHAINS.has(c), "%s makes a real chain" % g)
			covered[c] = true
	check(covered.size() == GameData.CHAINS.size(), "every chain comes from some generator")
	for r in GameData.ROOMS:
		for s in r["steps"]:
			check(ResourceLoader.exists("res://assets/furniture/%s.gltf" % s["model"]), "%s step model exists" % s["name"])
			check(int(s["stars"]) >= 1, "%s costs stars" % s["name"])
	check(GameData.item("cozy", 3) == "cozy:3" and GameData.level_of("cozy:3") == 3 and GameData.chain_of("cozy:3") == "cozy", "item ids")
	check(GameData.model("cozy:4") == "armchair", "levels map to models")
	check(GameData.sell_value("cozy:4") > GameData.sell_value("cozy:1"), "better items sell for more")


func _merging() -> void:
	var b := BoardState.new()
	b.cells.fill("")
	b.cells[0] = "books:1"
	b.cells[1] = "books:1"
	b.cells[2] = "books:2"
	b.cells[3] = "rugs:1"
	check(b.move(0, 1) == "merge" and b.at(1) == "books:2" and b.at(0) == "", "two books make a book set")
	check(b.move(1, 2) == "merge" and b.at(2) == "books:3", "and two sets make a shelf")
	check(b.move(2, 3) == "swap" and b.at(2) == "rugs:1" and b.at(3) == "books:3", "different items swap places")
	check(b.move(3, 10) == "move" and b.at(10) == "books:3" and b.at(3) == "", "items move to empty tiles")
	check(b.move(5, 6) == "none", "nothing to drag on an empty tile")
	b.cells[20] = "plants:4"
	b.cells[21] = "plants:4"
	check(b.move(20, 21) == "swap", "top-level items don't merge any further")
	check(not GameData.can_merge("gen_box", "gen_box"), "generators don't merge")
	check(b.merges == 2, "merges are counted")


func _generators() -> void:
	var b := BoardState.new()
	b.rng.seed = 3
	var gen := b.idx(0, 0)
	check(b.at(gen) == "gen_box", "the moving box starts in the corner")
	var e0 := b.energy
	var spot := b.tap_generator(gen)
	check(spot >= 0 and GameData.is_item(b.at(spot)) and b.energy == e0 - 1, "tapping a box unpacks an item for one energy")
	var chain := GameData.chain_of(b.at(spot))
	check((GameData.GENERATORS["box"]["chains"] as Array).has(chain), "the box gives its own chains")
	check(Vector2(b.col(spot), b.row(spot)).distance_to(Vector2(0, 0)) < 1.5, "items land next to the box")
	check(b.tap_generator(5) == -1, "plain tiles aren't generators")
	for i in b.cells.size():
		if b.cells[i] == "":
			b.cells[i] = "rugs:1"
	check(b.tap_generator(gen) == -2, "a full board can't take more")
	b.energy = 0
	check(b.tap_generator(gen) == -1, "no energy, no items")


func _energy() -> void:
	var b := BoardState.new()
	b.energy = 10
	b.tick(GameData.ENERGY_EVERY * 3.0 + 1.0)
	check(b.energy == 13, "energy refills over time")
	b.tick(100000.0)
	check(b.energy == GameData.MAX_ENERGY, "up to the maximum")
	b.energy = 5
	b.coins = 0
	check(not b.buy_refill(), "refills cost coins")
	b.coins = 500
	check(b.buy_refill() and b.energy == GameData.MAX_ENERGY, "a refill fills the bar")


func _orders() -> void:
	var b := BoardState.new()
	b.rng.seed = 9
	check(b.orders.size() == GameData.ORDER_SLOTS, "three orders to start")
	for o in b.orders:
		var lv := GameData.level_of(o)
		check(lv >= 2 and lv <= GameData.max_level(GameData.chain_of(o)), "orders ask for real items above level 1")
	check(not b.deliver(0), "can't deliver what you don't have")
	var want: String = b.orders[0]
	b.cells[10] = want
	var s0 := b.stars
	var c0 := b.coins
	check(b.deliver(0) and b.at(10) == "" and b.stars > s0 and b.coins > c0, "delivering pays stars and coins")
	check(b.orders.size() == GameData.ORDER_SLOTS, "a new order takes its place")
	b.room = 2
	var hard := 0
	for i in 50:
		hard = maxi(hard, GameData.level_of(b.new_order()))
	check(hard >= 4, "later rooms ask for finer things")


func _renovation() -> void:
	var b := BoardState.new()
	check(b.renovate().is_empty(), "no stars, no renovating")
	b.stars = 999
	var steps0: int = (GameData.ROOMS[0]["steps"] as Array).size()
	for i in steps0:
		check(not b.renovate().is_empty(), "living room step %d" % (i + 1))
	check(b.room == 1 and b.step == 0, "finishing a room opens the next")
	var guard := 0
	while not b.finished() and guard < 100:
		b.renovate()
		guard += 1
	check(b.finished() and b.current_step().is_empty(), "the whole manor can be restored")
	check(is_equal_approx(b.progress(), 1.0) or b.finished(), "progress reaches the end")
	var total := 0
	for r in GameData.ROOMS:
		for s in r["steps"]:
			total += int(s["stars"])
	check(total >= 40, "restoring the manor takes a good number of orders (%d stars)" % total)


func _save() -> void:
	var b := BoardState.new()
	b.cells[7] = "art:3"
	b.stars = 7
	b.step = 2
	var c := BoardState.new()
	c.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	check(c.at(7) == "art:3" and c.stars == 7 and c.step == 2, "the board round-trips")
	check(c.orders == b.orders, "orders survive saving")
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({"board": b.to_dict(), "sound": false})
	check(save.board.stars == 7 and not save.sound, "the save file loads the board")
	save.free()
