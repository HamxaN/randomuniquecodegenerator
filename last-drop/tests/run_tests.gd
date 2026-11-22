extends SceneTree
## Unit tests for the game rules: inventory, attachments, damage and the zone.
## Run with: godot --headless --path last-drop -s res://tests/run_tests.gd

var _fails := 0
var _count := 0


func _check(cond: bool, what: String) -> void:
	_count += 1
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_inventory()
	_attachments()
	_damage()
	_zone()
	_loot()
	_arsenal()
	_island()
	print("%d checks, %d failed" % [_count, _fails])
	if _fails == 0:
		print("ALL TESTS PASSED")
	quit(1 if _fails > 0 else 0)


func _inventory() -> void:
	var inv := Inventory.new()
	_check(not inv.has_weapon(), "starts unarmed")
	_check(inv.wants(GameData.item("weapon", "ar")), "wants a first gun")
	inv.take(GameData.item("weapon", "ar"))
	_check(inv.active == 0 and String(inv.current()["id"]) == "ar", "first gun goes to slot 1 and is held")
	inv.take(GameData.item("weapon", "smg"))
	_check(String(inv.weapons[1]["id"]) == "smg" and inv.active == 0, "second gun fills slot 2, still holding the first")
	_check(not inv.wants(GameData.item("weapon", "dmr")), "a third gun needs a choice")
	var out := inv.take(GameData.item("weapon", "dmr"), 1)
	_check(out.size() == 1 and String(out[0]["id"]) == "smg", "swapping drops the old gun")
	# Ammo caps.
	inv.take({"kind": "ammo", "id": "rifle", "n": 200})
	out = inv.take({"kind": "ammo", "id": "rifle", "n": 100})
	_check(int(inv.ammo["rifle"]) == 240 and out.size() == 1 and int(out[0]["n"]) == 60, "ammo is capped and the rest is left")
	# Reload.
	inv.current()["mag"] = 5
	var loaded := inv.reload()
	_check(loaded == 25 and int(inv.current()["mag"]) == 30 and int(inv.ammo["rifle"]) == 215, "reload fills the mag from the bag")
	_check(inv.use_round() and int(inv.current()["mag"]) == 29, "firing uses a round")
	# Armour upgrades only.
	inv.take(GameData.item("vest", "2"))
	_check(inv.vest == 2 and not inv.wants(GameData.item("vest", "1")), "vest upgrades and ignores worse ones")
	out = inv.take(GameData.item("vest", "3"))
	_check(inv.vest == 3 and out.size() == 1 and int(out[0]["lvl"]) == 2, "old vest is dropped on upgrade")
	# Heals cap.
	inv.take({"kind": "heal", "id": "medkit", "n": 5})
	inv.take(GameData.item("grenade", "frag"))
	_check(int(inv.heals["medkit"]) == 3, "medkits cap at 3")
	_check(inv.use_heal("medkit") and int(inv.heals["medkit"]) == 2, "using a heal spends it")
	# Round trip through the network format.
	var copy := Inventory.new()
	copy.from_dict(inv.to_dict())
	_check(copy.vest == 3 and String(copy.weapons[1]["id"]) == "dmr" and int(copy.ammo["rifle"]) == 215 and copy.throw_count("frag") == 1, "inventory survives to_dict/from_dict")
	# Drops.
	var drops := inv.drop_all()
	var kinds := {}
	for d in drops:
		kinds[d["kind"]] = true
	_check(kinds.has("weapon") and kinds.has("ammo") and kinds.has("vest") and kinds.has("heal"), "elimination drops everything")


func _attachments() -> void:
	var inv := Inventory.new()
	inv.take(GameData.item("weapon", "ar"))
	inv.take({"kind": "attach", "id": "ext_mag", "n": 1})
	_check(String(inv.current()["att"].get("mag", "")) == "ext_mag", "extended mag fits the rifle")
	_check(int(GameData.stats(inv.current())["mag"]) == 45, "extended mag holds 50% more")
	inv.take({"kind": "attach", "id": "scope2", "n": 1})
	inv.take({"kind": "attach", "id": "red_dot", "n": 1})
	_check(String(inv.current()["att"]["scope"]) == "scope2", "a worse scope doesn't replace a better one")
	_check(inv.spare.has("red_dot"), "the spare red dot is kept")
	_check(not GameData.fits("pistol", "scope2"), "pistols take no scopes")
	_check(not GameData.fits("smg", "scope8"), "8x only fits marksman guns")
	inv.take(GameData.item("weapon", "smg"))
	_check(String(inv.weapons[1]["att"].get("scope", "")) == "red_dot", "spares are fitted to new guns")
	var g := GameData.stats({"id": "ar", "mag": 30, "att": {"grip": "grip", "muzzle": "comp"}})
	_check(float(g["recoil"]) < float(GameData.WEAPONS["ar"]["recoil"]) * 0.5, "grip and compensator stack")


func _damage() -> void:
	_check(is_equal_approx(GameData.mitigate(100.0, false, 0, 0), 100.0), "no armour, full damage")
	_check(is_equal_approx(GameData.mitigate(100.0, false, 3, 0), 45.0), "level 3 vest blocks 55%")
	_check(is_equal_approx(GameData.mitigate(100.0, true, 3, 2), 55.0), "helmets protect the head, not vests")
	_check(GameData.falloff("shotgun", 10.0) == 1.0 and GameData.falloff("shotgun", 60.0) < 0.6, "shotguns fall off at range")
	_check(GameData.falloff("sniper", 300.0) == 1.0, "snipers reach far")


func _zone() -> void:
	var z := Zone.new(1234, GameData.ISLAND_RADIUS)
	var z2 := Zone.new(1234, GameData.ISLAND_RADIUS)
	_check(z.centers == z2.centers, "same seed, same circles")
	var prev_r := 1e9
	for i in z.radii.size():
		_check(z.radii[i] <= prev_r, "circles only shrink (%d)" % i)
		prev_r = z.radii[i]
		if i > 0:
			_check(z.centers[i].distance_to(z.centers[i - 1]) <= z.radii[i - 1] - z.radii[i] + 0.01, "each circle sits inside the last (%d)" % i)
	var s0 := z.state(0.0)
	_check(int(s0["phase"]) == 1 and not bool(s0["shrinking"]), "starts waiting in phase 1")
	var mid := z.state(float(Zone.PHASES[0][0]) + float(Zone.PHASES[0][1]) * 0.5)
	_check(bool(mid["shrinking"]) and float(mid["radius"]) < z.radii[0] and float(mid["radius"]) > z.radii[1], "shrinks between circles")
	var end := z.state(z.end_time + 10.0)
	_check(float(end["radius"]) == 0.0 and float(end["dps"]) > 10.0, "the final circle closes completely")
	var z3 := Zone.new(99, GameData.ISLAND_RADIUS)
	_check(z3.centers != z.centers, "different seeds differ")


func _loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for i in 600:
		var it := GameData.roll_loot(rng)
		seen[it["kind"]] = true
		_check(GameData.item_name(it) != "", "every item has a name")
	_check(seen.size() >= 7, "every kind of loot shows up")


func _arsenal() -> void:
	_check(GameData.WEAPONS.size() >= 14, "at least 14 guns")
	var classes := {}
	for id in GameData.WEAPONS:
		var d: Dictionary = GameData.WEAPONS[id]
		classes[d["class"]] = true
		for key in ["name", "ammo", "dmg", "rpm", "mag", "hip", "ads", "recoil", "range", "reload", "move", "desc", "slots"]:
			_check(d.has(key), "%s has %s" % [id, key])
		_check(GameData.AMMO.has(d["ammo"]), "%s uses a real ammo type" % id)
		var w := GameData.item("weapon", id)
		_check(GameData.weapon_score(w) > 0.0, "%s scores above zero" % id)
	_check(classes.size() == 7, "seven weapon classes")
	# Rarity.
	var common := GameData.stats({"id": "ar", "mag": 30, "att": {}, "rar": 0})
	var legend := GameData.stats({"id": "ar", "mag": 30, "att": {}, "rar": 3})
	_check(float(legend["dmg"]) > float(common["dmg"]) * 1.1, "legendary guns hit harder")
	_check(int(GameData.stats({"id": "burst", "att": {}})["burst"]) == 3, "the burst rifle fires bursts of 3")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen_rar := {}
	var fitted_ok := true
	for i in 2000:
		var it := GameData.roll_loot(rng)
		if it["kind"] == "weapon":
			seen_rar[int(it["rar"])] = true
			if (it["att"] as Dictionary).size() > int(it["rar"]):
				fitted_ok = false
			for slot in it["att"]:
				if not GameData.fits(String(it["id"]), String(it["att"][slot])):
					fitted_ok = false
			if int(it["mag"]) != int(GameData.stats(it)["mag"]):
				fitted_ok = false
	_check(seen_rar.size() == 4, "all four rarities drop")
	_check(fitted_ok, "rarity attachments fit and mags are full")
	var inv := Inventory.new()
	inv.take({"kind": "weapon", "id": "talon", "n": 1, "mag": 30, "att": {}, "rar": 2})
	_check(int(inv.current()["rar"]) == 2, "rarity is kept when picked up")
	var dropped := inv.drop_all()
	_check(int(dropped[0]["rar"]) == 2, "rarity is kept when dropped")
	_check(GameData.weapon_score(GameData.item("weapon", "pistol")) < GameData.weapon_score(GameData.item("weapon", "ar")), "rifles outrank pistols")
	# Throwables.
	var t := Inventory.new()
	t.take(GameData.item("grenade", "smoke"))
	t.take(GameData.item("grenade", "molotov"))
	t.take({"kind": "grenade", "id": "frag", "n": 5})
	_check(t.throw_count("frag") == 3 and t.throw_count("smoke") == 1 and t.throw_count() == 5, "throwables stack per kind")
	_check(t.throw_sel == "smoke", "the first throwable picked up is selected")
	t.cycle_throwable()
	_check(t.throw_sel == "molotov", "cycling picks the next kind you have")
	_check(t.use_throwable("molotov") and t.throw_count("molotov") == 0 and t.throw_sel != "molotov", "using the last one moves the selection on")
	_check(GameData.camo("gold")["price"] > 0 and GameData.camo("nope")["id"] == "none", "camos look up safely")


func _island() -> void:
	var a := Island.new()
	a.generate(42)
	var b := Island.new()
	b.generate(42)
	_check(a.towns.size() >= 5, "the island has towns")
	_check(a.loot_spots.size() > 150, "plenty of loot spots (%d)" % a.loot_spots.size())
	_check(a.loot_spots.size() == b.loot_spots.size() and a.loot_spots[10].is_equal_approx(b.loot_spots[10]), "same seed, same island")
	_check(a.height(0.0, 0.0) > 1.0, "the middle is above water")
	_check(a.height(GameData.ISLAND_RADIUS * 1.3, 0.0) < 0.0, "the edge is sea")
	for t in a.towns:
		_check(a.height(t["center"].x, t["center"].y) > 1.0, "towns are on land")
	_check(a.vehicle_spots.size() >= 8, "there are vehicles to find")
	a.free()
	b.free()
