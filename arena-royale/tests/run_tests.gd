extends SceneTree
## Unit tests for the battle rules. Run with:
##   godot --headless --path arena-royale -s res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_data()
	_placing()
	_mana_and_cards()
	_combat()
	_full_battles()
	_profile()
	print("tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _sim(seed_value: int = 1) -> BattleSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s := BattleSim.new()
	s.setup(GameData.STARTER_DECK, GameData.STARTER_DECK, rng)
	return s


func _data() -> void:
	check(GameData.STARTER_DECK.size() == GameData.DECK_SIZE, "the starter deck is a full deck")
	for id in GameData.CARD_ORDER:
		var c := GameData.card(id)
		check(not c.is_empty() and int(c["cost"]) >= 1 and int(c["cost"]) <= 10, "%s costs 1-10 mana" % id)
		if not GameData.is_spell(id):
			check(float(c["hp"]) > 0 and float(c["damage"]) > 0, "%s can fight" % id)
	var seen := {}
	for a in GameData.ARENAS:
		for id in a["unlock"]:
			check(GameData.CARDS.has(id) and not seen.has(id), "%s unlocks once" % id)
			seen[id] = true
	check(GameData.arena_index(0) == 0 and GameData.arena_index(300) == 1 and GameData.arena_index(5000) == 2, "trophies pick the arena")
	check(GameData.unlocked_cards(800).size() > GameData.unlocked_cards(0).size(), "higher arenas unlock more cards")
	check(GameData.trophy_change(true, false, 3) > GameData.trophy_change(true, false, 1), "more crowns, more trophies")
	check(GameData.trophy_change(false, false, 0) < 0 and GameData.trophy_change(false, true, 1) == 0, "losses cost trophies, draws don't")
	check(GameData.level_mult(5) > GameData.level_mult(1), "levels make cards stronger")
	check(GameData.upgrade_cost(5) > GameData.upgrade_cost(4), "upgrades get pricier")
	check(GameData.mana_rate(30.0) > GameData.mana_rate(120.0), "mana flows faster in the last minute")


func _placing() -> void:
	var s := _sim()
	check(s.can_place(BattleSim.YOU, "knight", Vector2(0, 6)), "troops go on your half")
	check(not s.can_place(BattleSim.YOU, "knight", Vector2(0, -6)), "not on the enemy half")
	check(not s.can_place(BattleSim.YOU, "knight", Vector2(0, 0.5)), "not in the river")
	check(not s.can_place(BattleSim.YOU, "knight", Vector2(0, 13.8)), "not on top of your keep")
	check(s.can_place(BattleSim.YOU, "fireball", Vector2(0, -10)), "spells go anywhere")
	check(s.can_place(BattleSim.FOE, "knight", Vector2(2, -7)), "the enemy places on its own half")
	check(not s.can_place(BattleSim.YOU, "knight", Vector2(20, 6)), "not off the field")


func _mana_and_cards() -> void:
	var s := _sim()
	check(s.hands[0].size() == GameData.HAND_SIZE and s.queues[0].size() == GameData.DECK_SIZE - GameData.HAND_SIZE, "4 in hand, 4 waiting")
	s.mana[0] = 0.0
	var first: String = s.hands[0][0]
	check(not s.play(0, first, Vector2(0, 6)), "no mana, no card")
	s.tick(GameData.MANA_EVERY * 3.0)
	check(absf(float(s.mana[0]) - 3.0) < 0.05, "a mana every %.1f seconds" % GameData.MANA_EVERY)
	s.mana[0] = 10.0
	s.tick(10.0)
	check(float(s.mana[0]) <= GameData.MAX_MANA, "mana caps at 10")
	var nxt := s.next_card(0)
	var spell := GameData.is_spell(first)
	check(s.play(0, first, Vector2(0, -6) if spell else Vector2(0, 6)), "a card can be played")
	check(not (s.hands[0] as Array).has(first) or (s.hands[0] as Array).count(first) == 1, "the card leaves the hand")
	check((s.hands[0] as Array).has(nxt), "the next card comes into the hand")
	check((s.queues[0] as Array).back() == first, "the played card goes to the back")
	check(not s.play(0, "golem", Vector2(0, 6)), "can't play a card that isn't in hand")


func _combat() -> void:
	# A knight walks over a bridge and knocks down a guard tower.
	var s := _sim()
	(s.hands[0] as Array)[0] = "knight"
	s.mana[0] = 10.0
	s.mana[1] = 0.0
	s.mana_boost[1] = 0.0
	check(s.play(0, "knight", Vector2(-5.5, 6.0)), "deploy a knight")
	var knight: Dictionary = {}
	for e in s.entities:
		if e["card"] == "knight":
			knight = e
	var crossed_in_river_off_bridge := false
	for i in 1400:
		s.mana[0] = 0.0
		s.tick(0.05)
		if not knight["alive"]:
			break
		var p: Vector2 = knight["pos"]
		if absf(p.y) < GameData.RIVER - 0.1:
			var near := false
			for bx in GameData.BRIDGES:
				if absf(p.x - float(bx)) < GameData.BRIDGE_HALF + 0.2:
					near = true
			if not near:
				crossed_in_river_off_bridge = true
		if int(s.crowns[0]) > 0:
			break
	check(not crossed_in_river_off_bridge, "troops only cross the river on bridges")
	check((knight["pos"] as Vector2).y < 0.0 or not knight["alive"], "the knight reached the enemy side")
	# Spells.
	var t := _sim(3)
	(t.hands[0] as Array)[0] = "fireball"
	t.mana[0] = 10.0
	var guard: Dictionary = {}
	for e in t.entities:
		if e["tower"] and int(e["side"]) == 1 and e["kind"] == "guard":
			guard = e
	var hp0 := float(guard["hp"])
	check(t.play(0, "fireball", guard["pos"]), "fireball the tower")
	check(float(guard["hp"]) < hp0 and float(guard["hp"]) > hp0 - 380.0, "towers take only part of a fireball")
	(t.hands[0] as Array)[0] = "freeze"
	t.mana[0] = 10.0
	t.play(0, "freeze", guard["pos"])
	check(float(guard["stun"]) > 0.0, "frost freezes towers")


func _full_battles() -> void:
	var results := {"you": 0, "foe": 0, "draw": 0}
	for seed_value in range(1, 5):
		var s := _sim(seed_value)
		var a := BattleSim.Brain.new(s, BattleSim.YOU, 4)
		var b := BattleSim.Brain.new(s, BattleSim.FOE, 4)
		a.rng.seed = seed_value * 3
		b.rng.seed = seed_value * 7
		var steps := 0
		while not s.over and steps < 3000:
			a.tick(0.1)
			b.tick(0.1)
			s.tick(0.1)
			steps += 1
		check(s.over, "battle %d ends" % seed_value)
		check(s.time <= GameData.BATTLE_TIME + GameData.OVERTIME + 0.1, "battle %d ends by the end of overtime" % seed_value)
		if s.winner == BattleSim.YOU:
			results["you"] = int(results["you"]) + 1
			check(int(s.crowns[0]) > int(s.crowns[1]), "the winner has more crowns")
		elif s.winner == BattleSim.FOE:
			results["foe"] = int(results["foe"]) + 1
			check(int(s.crowns[1]) > int(s.crowns[0]), "the winner has more crowns")
		else:
			results["draw"] = int(results["draw"]) + 1
		for e in s.entities:
			var p: Vector2 = e["pos"]
			check(absf(p.x) <= GameData.FIELD_W / 2.0 and absf(p.y) <= GameData.FIELD_L / 2.0, "everything stays on the field")
	print("AI vs AI: ", results)
	check(int(results["draw"]) < 4, "battles get decided")


func _profile() -> void:
	var save: Node = load("res://scripts/save.gd").new()
	save._ensure_cards()
	check(save.owns("knight") and not save.owns("golem"), "you start with the first arena's cards")
	check(save.deck.size() == GameData.DECK_SIZE, "a full starter deck")
	check(not save.swap("knight", "golem"), "can't use cards you don't own")
	check(save.swap("knight", "knight") == false, "can't swap a card with itself")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var chest: Dictionary = save.finish_battle(true, 30, 60, rng)
	check(save.trophies == 30 and save.wins == 1 and save.gold >= 160, "a win pays trophies and gold")
	check(not (chest["shards"] as Dictionary).is_empty(), "a win opens a chest of shards")
	save.finish_battle(false, -100, 10, rng)
	check(save.trophies == 0, "trophies never go below zero")
	var chest2: Dictionary = save.finish_battle(true, 400, 60, rng)
	check(save.owns("golem") == false and save.owns("heal") and (chest2["new"] as Array).has("heal"), "a new arena unlocks its cards")
	check(bool(chest2["arena_up"]), "and says so")
	save.cards["knight"] = {"level": 1, "shards": 10}
	save.gold = 1000
	check(save.can_upgrade("knight") and save.upgrade("knight") and save.level("knight") == 2, "upgrade with shards and gold")
	check(save.shards("knight") == 10 - GameData.shards_needed(1), "upgrades use shards")
	var copy: Node = load("res://scripts/save.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.level("knight") == 2 and copy.trophies == save.trophies, "the profile round-trips")
	save.free()
	copy.free()
