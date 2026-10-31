extends SceneTree
## Unit tests for the restaurant rules. Run with:
##   godot --headless --path burger-rush -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_menu_unlocks()
	_days()
	_matching()
	_grill()
	_plates()
	_sides()
	_economy()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _menu_unlocks() -> void:
	for day in range(1, GameData.day_count() + 1):
		var plan := GameData.day_plan(day)
		for o in plan["orders"]:
			var order: Dictionary = o
			var burger: Array = order["burger"]
			check(burger.has("bun") and burger.has("patty"), "day %d: every burger has a bun and a patty" % day)
			for item in burger:
				check(GameData.unlocked(item, day), "day %d: %s is on the menu" % [day, item])
			check(not order["fries"] or GameData.unlocked("fries", day), "day %d: fries only once unlocked" % day)
			check(not order["drink"] or GameData.unlocked("drink", day), "day %d: drinks only once unlocked" % day)
	check(GameData.new_item(2) == "cheese", "cheese arrives on day 2")
	check(GameData.new_item(1) == "", "nothing new on day 1")


func _days() -> void:
	var prev_count := 0
	for day in range(1, GameData.day_count() + 1):
		var a := GameData.day_plan(day)
		var b := GameData.day_plan(day)
		check(a["orders"] == b["orders"] and a["times"] == b["times"], "day %d is the same every time" % day)
		var times: Array = a["times"]
		for i in range(1, times.size()):
			check(float(times[i]) > float(times[i - 1]), "day %d: customers arrive in order" % day)
		var goals: Array = a["goals"]
		check(int(goals[0]) < int(goals[1]) and int(goals[1]) < int(goals[2]), "day %d: star goals rise" % day)
		var total := 0
		for o in a["orders"]:
			total += GameData.order_price(o)
		check(int(goals[2]) > total, "day %d: three stars need tips" % day)
		check(a["orders"].size() >= prev_count, "day %d is at least as busy as the day before" % day)
		prev_count = a["orders"].size()
	check(GameData.location_index(1) == 0 and GameData.location_index(11) == 1 and GameData.location_index(30) == 2, "locations change every ten days")


func _matching() -> void:
	check(GameData.burger_matches(["bun", "patty", "cheese"], ["bun", "cheese", "patty"]), "stacking order doesn't matter")
	check(not GameData.burger_matches(["bun", "patty"], ["bun", "patty", "cheese"]), "missing cheese doesn't match")
	check(not GameData.burger_matches(["bun", "patty", "tomato"], ["bun", "patty"]), "extra tomato doesn't match")
	check(GameData.stacked(["tomato", "patty", "bun"]) == ["bun", "patty", "tomato"], "burgers stack bottom to top")


func _grill() -> void:
	var k := KitchenState.new()
	k.setup(2, 2)
	check(k.start_patty() == 0 and k.start_patty() == 1, "two patties fit on a two-slot grill")
	check(k.start_patty() == -1, "a full grill takes no more")
	k.tick(k.cook_time * 0.5)
	check(k.grill[0]["state"] == "cooking", "half-cooked patties are still cooking")
	check(k.take_patty(0) == -1, "can't take a raw patty")
	k.tick(k.cook_time * 0.6)
	check(k.grill[0]["state"] == "ready", "patties cook through")
	check(k.take_patty(0) == -1, "a cooked patty needs a bun to go on")
	k.add_bun()
	check(k.take_patty(0) == 0, "a cooked patty goes on the plate with a bun")
	check(k.grill[0]["state"] == "empty", "the grill slot is free again")
	k.tick(k.burn_time + 0.1)
	check(k.grill[1]["state"] == "burnt", "patties left too long burn")
	check(k.take_patty(1) == -2 and k.burnt == 1, "burnt patties get thrown away")
	var fast := KitchenState.new()
	fast.cook_time = GameData.cook_time(4)
	check(fast.cook_time < GameData.COOK_TIME, "hotter flames cook faster")


func _plates() -> void:
	var k := KitchenState.new()
	k.setup(2, 3)
	check(k.add_topping("cheese") == -1, "no topping without a bun")
	check(k.add_bun() == 0 and k.add_bun() == 1, "buns fill the plates in order")
	check(k.add_bun() == -1, "no free plate for a third bun")
	check(k.add_topping("cheese") == 1, "toppings go on the last plate touched")
	check(k.add_topping("cheese") == 0, "then on the next plate that needs it")
	check(k.add_topping("cheese") == -1, "never two slices of cheese")
	var items := k.take_plate(0)
	check(items == ["bun", "cheese"] and (k.plates[0] as Array).is_empty(), "serving clears the plate")
	k.add_bun()
	k.add_topping("lettuce")
	check(k.trash() == 0 and (k.plates[0] as Array).is_empty(), "the bin empties the last plate touched")


func _sides() -> void:
	var k := KitchenState.new()
	k.setup(2, 2, 2)
	check(k.start_fries() and not k.start_fries(), "one batch of fries at a time")
	check(not k.take_fries(), "fries need to finish frying")
	k.tick(k.fry_time + 0.01)
	check(k.fries == k.batch, "a batch makes several portions")
	for i in k.batch:
		check(k.take_fries(), "portion %d of fries" % (i + 1))
	check(k.fryer_state == "empty" and not k.take_fries(), "the fryer empties")
	check(k.start_drink(0) and not k.start_drink(0), "one drink per cup")
	check(not k.take_drink(0), "a drink must finish pouring")
	k.tick(k.pour_time + 0.01)
	check(k.take_drink(0), "a poured drink can be served")


func _economy() -> void:
	var order := {"burger": ["bun", "patty", "cheese"], "fries": true, "drink": false}
	check(GameData.order_price(order) == 13, "a cheeseburger and fries cost 13")
	check(GameData.order_parts(order) == 2, "two things to hand over")
	check(GameData.tip(13, 1.0, 0) > GameData.tip(13, 0.3, 0), "happier customers tip more")
	check(GameData.tip(13, 0.0, 4) == 0, "no tip at the last second")
	check(GameData.tip(20, 1.0, 4) > GameData.tip(20, 1.0, 0), "the tip jar raises tips")
	check(GameData.stars(0, [10, 20, 30]) == 0 and GameData.stars(25, [10, 20, 30]) == 2, "stars count goals reached")
	for u in GameData.UPGRADES:
		var id: String = u["id"]
		for lv in int(u["max"]) - 1:
			check(GameData.upgrade_cost(id, lv + 1) > GameData.upgrade_cost(id, lv), "%s gets pricier" % id)
	check(GameData.chef_speed(4) > GameData.chef_speed(0), "running shoes speed the chef up")
	check(GameData.patience_mult(4) > 1.0, "decor makes customers patient")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.coins = 1000
	check(save.unlocked_day() == 1, "a new profile starts on day 1")
	check(save.finish_day(1, 50, 2, 6), "a first clear is a new best")
	check(save.unlocked_day() == 2 and save.coins == 1050, "clearing a day opens the next and pays out")
	check(not save.finish_day(1, 10, 1, 3), "a worse result isn't a new best")
	check(save.day_stars(1) == 2, "the best stars are kept")
	check(save.finish_day(2, 0, 0, 0) == false and save.unlocked_day() == 2, "failing a day keeps the next one locked")
	check(save.buy_upgrade("grill") and save.level("grill") == 1, "upgrades can be bought")
	var before: int = save.coins
	check(save.buy_upgrade("grill") and save.level("grill") == 2, "and bought again")
	check(not save.buy_upgrade("grill"), "but not past the max")
	check(save.coins < before, "upgrades cost coins")
	save.coins = 0
	check(not save.pick_chef("lance"), "chefs cost coins")
	save.coins = 5000
	check(save.pick_chef("lance") and save.chef == "lance", "hired chefs start cooking")
	check(save.pick_chef("bruno") and save.coins == 5000 - 400, "switching back is free")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(save.to_dict())
	check(copy.to_dict() == save.to_dict(), "the profile round-trips through JSON data")
	save.free()
	copy.free()
