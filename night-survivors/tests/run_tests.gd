extends SceneTree
## Unit tests for the night's rules. Run with:
##   godot --headless --path night-survivors -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_data()
	_horde()
	_levels()
	_choices()
	_stats()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _data() -> void:
	for id in GameData.WEAPONS:
		var levels: Array = GameData.WEAPONS[id]["levels"]
		check(levels.size() == GameData.MAX_LEVEL, "%s has %d levels" % [id, GameData.MAX_LEVEL])
		for i in range(1, levels.size()):
			var a: Dictionary = levels[i - 1]
			var b: Dictionary = levels[i]
			check(float(b["damage"]) >= float(a["damage"]) and float(b["cooldown"]) <= float(a["cooldown"]), "%s level %d is no worse" % [id, i + 1])
			check(int(b["count"]) >= int(a["count"]) and float(b["area"]) >= float(a["area"]), "%s level %d keeps its reach" % [id, i + 1])
	for h in GameData.HEROES:
		check(GameData.WEAPONS.has(h["weapon"]), "%s starts with a real weapon" % h["name"])
	for m in GameData.META:
		for lv in int(m["max"]) - 1:
			check(GameData.meta_cost(m["id"], lv + 1) > GameData.meta_cost(m["id"], lv), "%s gets pricier" % m["id"])
	check(GameData.gold_reward(600.0, 1000, 0) > GameData.gold_reward(120.0, 100, 0), "longer nights pay more")
	check(GameData.gold_reward(300.0, 200, 5) > GameData.gold_reward(300.0, 200, 0), "greed adds gold")


func _horde() -> void:
	var prev := 0
	for t in range(0, 601, 30):
		var n := GameData.horde_size(float(t))
		check(n >= prev, "the horde never shrinks (t=%d)" % t)
		prev = n
	check(GameData.horde_size(0.0) < 20 and GameData.horde_size(600.0) > 200, "the night starts gently and ends in a flood")
	check(not GameData.spawn_table(10.0).has("warrior"), "no warriors in the first minutes")
	check(GameData.spawn_table(400.0).has("mage"), "necromancers arrive later")
	check(GameData.hp_scale(600.0) > GameData.hp_scale(0.0), "foes toughen through the night")
	var counts := {}
	for i in 1000:
		var k := GameData.pick_weighted({"a": 3.0, "b": 1.0}, i / 1000.0)
		counts[k] = int(counts.get(k, 0)) + 1
	check(int(counts["a"]) > int(counts["b"]) * 2, "weighted picks follow their weights")
	check(GameData.pick_weighted({"a": 1.0}, 1.0) == "a", "a roll of 1 still picks something")


func _levels() -> void:
	var r := RunState.new("knight")
	check(r.level == 1 and r.weapons.has("axes"), "the knight starts with spinning axes")
	var need := GameData.xp_to_next(1)
	check(r.add_xp(need - 1) == 0 and r.level == 1, "not quite a level")
	check(r.add_xp(1) == 1 and r.level == 2 and r.xp == 0, "one more gem levels up")
	var big := r.add_xp(500)
	check(big > 1 and r.xp < GameData.xp_to_next(r.level), "a big gem can give several levels")
	for lv in range(1, 30):
		check(GameData.xp_to_next(lv + 1) > GameData.xp_to_next(lv), "each level needs more XP (%d)" % lv)


func _choices() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r := RunState.new("mage")
	for i in 200:
		var c := r.choices(rng)
		check(c.size() >= 1 and c.size() <= 3, "1 to 3 choices")
		var seen := {}
		for x in c:
			var key := "%s:%s" % [x["kind"], x["id"]]
			check(not seen.has(key), "no duplicate choices")
			seen[key] = true
			if x["kind"] == "weapon":
				check(int(x["level"]) <= GameData.MAX_LEVEL, "never past the max level")
		r.apply(c[0])
		check(r.weapons.size() <= GameData.MAX_WEAPONS and r.relics.size() <= GameData.MAX_RELICS, "slots never overflow")
	var maxed := RunState.new("knight")
	for id in GameData.WEAPONS:
		maxed.weapons[id] = GameData.MAX_LEVEL
	for id in GameData.RELICS:
		maxed.relics[id] = GameData.MAX_LEVEL
	var c := maxed.choices(rng)
	check(c.size() == 1 and c[0]["kind"] == "gold", "with everything maxed you get gold")
	var g := maxed.gold
	maxed.apply(c[0])
	check(maxed.gold == g + 25, "gold choice pays out")


func _stats() -> void:
	var r := RunState.new("knight")
	var hp0 := r.max_hp()
	var dmg0 := r.might()
	var cd0 := r.cooldown_mult()
	r.apply({"kind": "relic", "id": "vigor", "level": 2})
	r.apply({"kind": "relic", "id": "might", "level": 1})
	r.apply({"kind": "relic", "id": "haste", "level": 3})
	check(r.max_hp() == hp0 + 40.0, "Troll Blood adds health")
	check(r.might() > dmg0, "Ember Heart adds damage")
	check(r.cooldown_mult() < cd0, "the Hourglass speeds weapons up")
	var meta := RunState.new("knight", {"hp": 2, "armor": 1, "speed": 3})
	check(meta.max_hp() == hp0 + 20.0, "power-ups add health")
	check(meta.armor() == 2.0, "armour stacks with the knight's own")
	check(meta.speed() > RunState.new("knight").speed(), "swiftness speeds you up")
	check(RunState.new("mage").cooldown_mult() < 1.0, "the mage's perk fires faster")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.gold = 1000
	check(save.buy_meta("might") and save.meta_level("might") == 1 and save.gold == 1000 - 120, "power-ups can be bought")
	check(not save.pick_hero("barbarian"), "heroes cost gold")
	save.gold = 5000
	check(save.pick_hero("mage") and save.hero == "mage", "unlocked heroes are chosen")
	check(save.pick_hero("knight") and save.gold == 5000 - 600, "switching back is free")
	check(save.finish_run(300.0, 400, 120, false), "a first run is a best time")
	check(not save.finish_run(100.0, 50, 10, false), "a shorter run isn't")
	check(save.finish_run(600.0, 900, 300, true) and save.dawns == 1, "surviving to dawn counts")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(save.to_dict())
	check(copy.to_dict() == save.to_dict(), "the profile round-trips")
	save.free()
	copy.free()
