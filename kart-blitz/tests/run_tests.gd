extends SceneTree
## Unit tests for the racing rules. Run with:
##   godot --headless --path kart-blitz -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_tracks()
	_items()
	_rewards()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _tracks() -> void:
	for i in GameData.TRACKS.size():
		var t := GameData.track(i)
		var s := GameData.sample_track(t["points"], 2.0)
		check(s.size() > 100, "%s has a smooth centre line" % t["id"])
		var length := GameData.track_length(s)
		check(length > 250.0 and length < 900.0, "%s is a sensible length (%d m)" % [t["id"], int(length)])
		var max_gap := 0.0
		for k in s.size():
			max_gap = maxf(max_gap, s[k].distance_to(s[(k + 1) % s.size()]))
		check(max_gap < 4.0, "%s samples are close together" % t["id"])
		# The road must not cross itself: far-apart parts of the loop stay a road-width apart.
		var crossing := false
		for a in range(0, s.size(), 4):
			for b in range(0, s.size(), 4):
				var along := mini(absi(a - b), s.size() - absi(a - b))
				if along > 25 and s[a].distance_to(s[b]) < 16.0:
					crossing = true
		check(not crossing, "%s never overlaps itself" % t["id"])
		check(int(t["unlock"]) == i, "%s unlocks in order" % t["id"])


func _items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var first := {}
	var last := {}
	for k in 3000:
		var a := GameData.roll_item(1, rng)
		var b := GameData.roll_item(6, rng)
		check(GameData.ITEMS.has(a) and GameData.ITEMS.has(b), "items are real")
		first[a] = int(first.get(a, 0)) + 1
		last[b] = int(last.get(b, 0)) + 1
	check(int(last.get("rocket", 0)) > int(first.get("rocket", 0)), "racers at the back get more rockets")
	check(int(first.get("triple", 0)) == 0, "the leader never gets a triple boost")
	check(int(first.get("shield", 0)) > int(last.get("shield", 0)), "the leader gets more shields")


func _rewards() -> void:
	for p in range(1, GameData.RACERS):
		check(GameData.coins_for(p) > GameData.coins_for(p + 1), "better places pay more coins")
		check(GameData.points_for(p) > GameData.points_for(p + 1), "better places score more points")
	check(GameData.upgrade_cost(3) > GameData.upgrade_cost(1), "upgrades get pricier")
	check(int(GameData.kart("red")["cost"]) == 0, "the first kart is free")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save.from_dict({})
	check(save.unlocked == 1, "only the first track is open")
	check(save.finish_race(0, 5, 30) == "", "5th place unlocks nothing")
	check(save.finish_race(0, 2, 90) == GameData.track(1)["name"], "a podium unlocks the next track")
	check(save.unlocked == 2 and save.best_place(0) == 2, "progress is recorded")
	check(not save.buy_kart("moto"), "can't afford the bike yet")
	save.coins = 100000
	check(save.buy_kart("moto") and save.kart == "moto", "buy the bike")
	check(save.buy_upgrade("engine") and save.upgrade("engine") == 1, "buy an upgrade")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.owned.has("moto") and copy.upgrade("engine") == 1 and copy.unlocked == 2, "profile survives a save")
	save.free()
	copy.free()
