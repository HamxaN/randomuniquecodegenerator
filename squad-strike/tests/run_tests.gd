extends SceneTree
## Unit tests for the game rules. Run with:
##   godot --headless --path squad-strike -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_waves()
	_scaling()
	_levels()
	_costs()
	_perks()
	_profile()
	_lookups()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _waves() -> void:
	var last := 0
	for n in range(1, 31):
		var w := GameData.wave(n)
		check(w.size() > 0, "wave %d has enemies" % n)
		check(w.size() >= last - 1, "wave %d is not much smaller than the one before" % n)
		last = w.size()
		check(w.has("boss") == (n % 5 == 0), "boss only on every fifth wave (wave %d)" % n)
		for kind in w:
			check(GameData.ENEMIES.has(kind), "wave %d enemy %s exists" % [n, kind])
		if n < 2:
			check(not w.has("rogue"), "no archers in wave 1")
		if n < 3:
			check(not w.has("warrior"), "no bone knights before wave 3")
		if n < 4:
			check(not w.has("mage"), "no necromancers before wave 4")
	check(GameData.wave(7) == GameData.wave(7), "waves are deterministic")
	check(GameData.wave(12).size() > GameData.wave(2).size() * 2, "later waves are much bigger")


func _scaling() -> void:
	check(is_equal_approx(GameData.health_scale(1), 1.0), "wave 1 health is base")
	check(GameData.health_scale(10) > GameData.health_scale(5), "health grows")
	check(GameData.damage_scale(10) > 1.2, "damage grows")
	check(GameData.wave_bonus(5) > GameData.wave_bonus(1), "bonus grows")


func _levels() -> void:
	check(GameData.level_for_xp(0) == 1, "start at level 1")
	check(GameData.level_for_xp(GameData.xp_to_reach(2)) == 2, "reach level 2 exactly")
	check(GameData.level_for_xp(GameData.xp_to_reach(2) - 1) == 1, "just short of level 2")
	var prev := 0
	for lv in range(2, 30):
		var need := GameData.xp_to_reach(lv) - GameData.xp_to_reach(lv - 1)
		check(need >= prev, "each level needs at least as much XP as the last (%d)" % lv)
		prev = need
	for a in GameData.ARENAS.size():
		check(int(GameData.arena(a)["unlock"]) >= 0, "arena %d has an unlock level" % a)


func _costs() -> void:
	check(GameData.weapon_power(1) == 1.0, "level 1 weapon is base power")
	check(GameData.weapon_power(GameData.MAX_WEAPON_LEVEL) > 1.8, "max level nearly doubles damage")
	for lv in range(1, GameData.MAX_WEAPON_LEVEL):
		check(GameData.upgrade_cost(lv + 1) > GameData.upgrade_cost(lv), "upgrades get pricier (%d)" % lv)
	check(int(GameData.weapon("ar")["cost"]) == 0, "starting rifle is free")
	check(int(GameData.operator("rogue")["cost"]) == 0, "starting operator is free")


func _perks() -> void:
	for seed_value in 40:
		var picks := GameData.perk_choices(seed_value)
		check(picks.size() == 3, "three perks offered")
		check(picks[0]["id"] != picks[1]["id"] and picks[1]["id"] != picks[2]["id"] and picks[0]["id"] != picks[2]["id"], "perks are different")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({})
	check(save.coins == 0 and save.owned_operators.has("rogue"), "fresh profile")
	save.coins = 10000
	save.weapon_levels["smg"] = 1
	var data: Dictionary = save.to_dict()
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(data)))
	check(copy.coins == 10000, "coins survive a save")
	check(copy.weapon_level("smg") == 1, "weapons survive a save")
	check(copy.weapon_level("dmr") == 0, "unowned weapon has level 0")
	save.free()
	copy.free()


func _lookups() -> void:
	check(GameData.operator("nope")["id"] == "rogue", "unknown operator falls back")
	check(GameData.weapon("nope")["id"] == "ar", "unknown weapon falls back")
	check(GameData.arena(99)["id"] == GameData.ARENAS[-1]["id"], "arena index is clamped")
	for w in GameData.WEAPONS:
		check(float(w["rate"]) > 0 and int(w["mag"]) > 0 and float(w["range"]) > 4, "weapon %s stats are sane" % w["id"])
