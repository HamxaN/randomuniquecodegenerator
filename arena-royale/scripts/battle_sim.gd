class_name BattleSim
extends RefCounted
## The whole battle as plain data on a 2D field: troops walk the lanes and
## cross the river by its bridges, fight whatever is near, towers shoot back,
## spells land, mana fills up and crowns are counted. The 3D arena only draws
## it (reading [member events]), and the unit tests play full battles with it.

const YOU := 0
const FOE := 1

var time := 0.0
var mana := [5.0, 5.0]
var mana_boost := [1.0, 1.0]
var crowns := [0, 0]
var levels := [{}, {}]          # card id -> level, per side
var entities: Array[Dictionary] = []
var events: Array[Dictionary] = []
var over := false
var winner := -1                # -1 draw / not decided
var hands := [[], []]           # four playable cards
var queues := [[], []]          # the rest of the deck, in order
var _next_id := 1


func setup(deck_you: Array, deck_foe: Array, rng: RandomNumberGenerator) -> void:
	for side in 2:
		var deck: Array = (deck_you if side == YOU else deck_foe).duplicate()
		for i in range(deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: Variant = deck[i]
			deck[i] = deck[j]
			deck[j] = t
		hands[side] = deck.slice(0, GameData.HAND_SIZE)
		queues[side] = deck.slice(GameData.HAND_SIZE)
		for tw in GameData.TOWERS:
			var p := Vector2(float(tw["x"]), float(tw["y"]))
			if side == FOE:
				p = GameData.mirror(p)
			_add({"side": side, "kind": tw["kind"], "card": "", "pos": p, "hp": float(tw["hp"]), "max": float(tw["hp"]),
				"damage": float(tw["damage"]), "range": float(tw["range"]), "rate": float(tw["rate"]), "speed": 0.0,
				"splash": 0.0, "targets": "any", "radius": 1.6 if tw["kind"] == "keep" else 1.2, "tower": true,
				"building": true})


func _add(e: Dictionary) -> Dictionary:
	e["id"] = _next_id
	_next_id += 1
	e["cd"] = 0.0
	e["stun"] = 0.0
	e["target"] = 0
	e["alive"] = true
	entities.append(e)
	return e


func by_id(id: int) -> Dictionary:
	for e in entities:
		if int(e["id"]) == id:
			return e
	return {}


func next_card(side: int) -> String:
	var q: Array = queues[side]
	return str(q[0]) if not q.is_empty() else ""


func time_left() -> float:
	if time < GameData.BATTLE_TIME:
		return GameData.BATTLE_TIME - time
	return GameData.BATTLE_TIME + GameData.OVERTIME - time


func overtime() -> bool:
	return time >= GameData.BATTLE_TIME


## Is [param p] a legal place for [param side] to put [param card_id]?
func can_place(side: int, card_id: String, p: Vector2) -> bool:
	if absf(p.x) > GameData.FIELD_W / 2.0 - 0.4 or absf(p.y) > GameData.FIELD_L / 2.0 - 0.4:
		return false
	if GameData.is_spell(card_id):
		return true
	var own_half := p.y > GameData.RIVER + 0.4 if side == YOU else p.y < -GameData.RIVER - 0.4
	if not own_half:
		return false
	# Not on top of your own towers.
	for e in entities:
		if e["tower"] and e["side"] == side and (e["pos"] as Vector2).distance_to(p) < float(e["radius"]) + 0.4:
			return false
	return true


## Plays a card from [param side]'s hand. Returns false if it can't.
func play(side: int, card_id: String, p: Vector2) -> bool:
	if over:
		return false
	var hand: Array = hands[side]
	var c := GameData.card(card_id)
	if not hand.has(card_id) or c.is_empty() or mana[side] < float(c["cost"]) or not can_place(side, card_id, p):
		return false
	mana[side] = float(mana[side]) - float(c["cost"])
	hand.erase(card_id)
	var q: Array = queues[side]
	q.append(card_id)
	hand.append(q.pop_front())
	var lv := float(GameData.level_mult(int((levels[side] as Dictionary).get(card_id, 1))))
	if GameData.is_spell(card_id):
		_cast(side, card_id, p, lv)
	else:
		var n := int(c["count"])
		for i in n:
			var off := Vector2.ZERO
			if n > 1:
				off = Vector2.from_angle(TAU * i / n) * (0.5 + 0.1 * n)
			_add({"side": side, "kind": "troop", "card": card_id, "pos": p + off, "hp": float(c["hp"]) * lv,
				"max": float(c["hp"]) * lv, "damage": float(c["damage"]) * lv, "range": float(c["range"]),
				"rate": float(c["rate"]), "speed": float(c["speed"]), "splash": float(c["splash"]),
				"targets": c["targets"], "radius": float(c["radius"]), "tower": false,
				"building": bool(c.get("building", false)), "life": float(c.get("lifetime", 0.0))})
			events.append({"type": "spawn", "id": _next_id - 1})
	events.append({"type": "play", "side": side, "card": card_id, "pos": p})
	return true


func _cast(side: int, card_id: String, p: Vector2, lv: float) -> void:
	var c := GameData.card(card_id)
	var r := float(c["radius"])
	for e in entities.duplicate():
		if not e["alive"] or (e["pos"] as Vector2).distance_to(p) > r + float(e["radius"]) * 0.5:
			continue
		if card_id == "heal":
			if e["side"] == side and not e["tower"]:
				e["hp"] = minf(float(e["max"]), float(e["hp"]) + float(c["heal"]) * lv)
			continue
		if e["side"] == side:
			continue
		var share := float(c["tower_share"]) if e["tower"] else 1.0
		if c.has("stun"):
			e["stun"] = float(c["stun"])
		_hurt(e, float(c["damage"]) * lv * share)
	events.append({"type": "spell", "card": card_id, "pos": p, "side": side})


func _hurt(e: Dictionary, amount: float) -> void:
	if not e["alive"]:
		return
	e["hp"] = float(e["hp"]) - amount
	if float(e["hp"]) <= 0.0:
		e["alive"] = false
		events.append({"type": "die", "id": e["id"], "tower": e["tower"], "kind": e["kind"], "side": e["side"]})
		if e["tower"]:
			var other := 1 - int(e["side"])
			if e["kind"] == "keep":
				crowns[other] = 3
			else:
				crowns[other] = int(crowns[other]) + 1


func tick(dt: float) -> void:
	if over:
		return
	time += dt
	for s in 2:
		mana[s] = minf(GameData.MAX_MANA, float(mana[s]) + GameData.mana_rate(time_left()) * float(mana_boost[s]) * dt)
	for e in entities:
		if not e["alive"]:
			continue
		e["stun"] = maxf(0.0, float(e["stun"]) - dt)
		e["cd"] = maxf(0.0, float(e["cd"]) - dt)
		if float(e["life"] if e.has("life") else 0.0) > 0.0:
			# Buildings crumble over their lifetime.
			_hurt(e, float(e["max"]) / float(e["life"]) * dt)
		if float(e["stun"]) > 0.0 or not e["alive"]:
			continue
		_think(e, dt)
	_separate()
	entities = entities.filter(func(e: Dictionary) -> bool: return e["alive"])
	_check_end()


func _think(e: Dictionary, dt: float) -> void:
	var target := by_id(int(e["target"]))
	if target.is_empty() or not target["alive"] or not _keep_target(e, target):
		target = _pick_target(e)
		e["target"] = int(target["id"]) if not target.is_empty() else 0
	if target.is_empty():
		return
	var p: Vector2 = e["pos"]
	var tp: Vector2 = target["pos"]
	var reach := float(e["range"]) + float(target["radius"]) + float(e["radius"]) * 0.5
	if p.distance_to(tp) <= reach:
		if float(e["cd"]) <= 0.0:
			e["cd"] = float(e["rate"])
			_attack(e, target)
	elif float(e["speed"]) > 0.0:
		var goal := _waypoint(p, tp)
		e["pos"] = p.move_toward(goal, float(e["speed"]) * dt)
		e["facing"] = (goal - p).normalized()


## Stay on what you're fighting while it is within sight.
func _keep_target(e: Dictionary, t: Dictionary) -> bool:
	if e["tower"]:
		return (e["pos"] as Vector2).distance_to(t["pos"]) <= float(e["range"]) + float(t["radius"])
	return true


func _pick_target(e: Dictionary) -> Dictionary:
	var p: Vector2 = e["pos"]
	var side := int(e["side"])
	var only_buildings: bool = e["targets"] == "buildings"
	var sight := float(e["range"]) + 0.5 if e["tower"] else maxf(5.5, float(e["range"]) + 1.0)
	var best: Dictionary = {}
	var bd := INF
	for o in entities:
		if not o["alive"] or int(o["side"]) == side:
			continue
		if only_buildings and not o["building"]:
			continue
		var d := p.distance_to(o["pos"]) - float(o["radius"])
		if d <= sight and d < bd:
			bd = d
			best = o
	if not best.is_empty() or e["tower"] or e["building"]:
		return best
	# Nothing close: march on the nearest enemy tower.
	for o in entities:
		if not o["alive"] or int(o["side"]) == side or not o["tower"]:
			continue
		var d := p.distance_to(o["pos"])
		if d < bd:
			bd = d
			best = o
	return best


## Where to walk next to reach [param to]: rivers are crossed only on bridges.
func _waypoint(from: Vector2, to: Vector2) -> Vector2:
	var r := GameData.RIVER
	var same_side := (from.y > r and to.y > r) or (from.y < -r and to.y < -r)
	if same_side:
		return to
	# On a bridge: carry straight on across.
	if absf(from.y) <= r + 0.05:
		return Vector2(from.x, (r + 0.4) * signf(to.y))
	var best_x: float = GameData.BRIDGES[0]
	for bx in GameData.BRIDGES:
		if absf(float(bx) - from.x) + absf(float(bx) - to.x) < absf(best_x - from.x) + absf(best_x - to.x):
			best_x = float(bx)
	var bank := Vector2(best_x, signf(from.y) * (r + 0.2))
	if from.distance_to(bank) < 0.25:
		return Vector2(best_x, -signf(from.y) * (r + 0.3))
	return bank


func _attack(e: Dictionary, target: Dictionary) -> void:
	events.append({"type": "attack", "id": e["id"], "target": target["id"], "ranged": float(e["range"]) > 2.0,
		"splash": float(e["splash"]) > 0.0, "tower": e["tower"]})
	var dmg := float(e["damage"])
	if float(e["splash"]) > 0.0:
		var c: Vector2 = target["pos"]
		for o in entities.duplicate():
			if o["alive"] and int(o["side"]) != int(e["side"]) and (o["pos"] as Vector2).distance_to(c) <= float(e["splash"]) + float(o["radius"]) * 0.5:
				_hurt(o, dmg)
	else:
		_hurt(target, dmg)


func _separate() -> void:
	for i in entities.size():
		var a: Dictionary = entities[i]
		if a["building"] or not a["alive"]:
			continue
		for j in entities.size():
			if i == j:
				continue
			var b: Dictionary = entities[j]
			if not b["alive"]:
				continue
			var d: Vector2 = (a["pos"] as Vector2) - (b["pos"] as Vector2)
			var min_d := (float(a["radius"]) + float(b["radius"])) * 0.8
			var l := d.length()
			if l < min_d and l > 0.001:
				var push := d / l * (min_d - l) * (1.0 if b["building"] else 0.5)
				a["pos"] = (a["pos"] as Vector2) + push
			elif l <= 0.001:
				a["pos"] = (a["pos"] as Vector2) + Vector2(0.05 * (1 if i % 2 == 0 else -1), 0)
		# Keep out of the river except on bridges.
		var p: Vector2 = a["pos"]
		if absf(p.y) < GameData.RIVER:
			var on_bridge := false
			for bx in GameData.BRIDGES:
				if absf(p.x - float(bx)) < GameData.BRIDGE_HALF:
					on_bridge = true
			if not on_bridge:
				var nearest: float = GameData.BRIDGES[0]
				for bx in GameData.BRIDGES:
					if absf(p.x - float(bx)) < absf(p.x - nearest):
						nearest = float(bx)
				p.x = move_toward(p.x, nearest, 0.2)
		p.x = clampf(p.x, -GameData.FIELD_W / 2.0 + 0.4, GameData.FIELD_W / 2.0 - 0.4)
		p.y = clampf(p.y, -GameData.FIELD_L / 2.0 + 0.4, GameData.FIELD_L / 2.0 - 0.4)
		a["pos"] = p


func _check_end() -> void:
	if int(crowns[YOU]) >= 3 or int(crowns[FOE]) >= 3:
		_finish(YOU if int(crowns[YOU]) >= 3 else FOE)
		return
	# After normal time a crown lead wins; in overtime the first crown does.
	if time >= GameData.BATTLE_TIME and int(crowns[YOU]) != int(crowns[FOE]):
		_finish(YOU if int(crowns[YOU]) > int(crowns[FOE]) else FOE)
		return
	if time >= GameData.BATTLE_TIME + GameData.OVERTIME:
		_finish(-1)


func _finish(w: int) -> void:
	over = true
	winner = w
	events.append({"type": "end", "winner": w})


func tower_hp(side: int) -> float:
	var total := 0.0
	for e in entities:
		if e["tower"] and int(e["side"]) == side:
			total += float(e["hp"])
	return total


# ---------------------------------------------------------------- the Bone Army's brain

## A simple opponent: defends when troops cross onto its half, otherwise
## pushes the lane with the weakest tower once it has saved up mana.
class Brain:
	extends RefCounted
	var sim: BattleSim
	var side := 1
	var level := 1
	var rng := RandomNumberGenerator.new()
	var _t := 1.5

	func _init(s: BattleSim, which: int, lvl: int) -> void:
		sim = s
		side = which
		level = lvl
		rng.randomize()

	func tick(dt: float) -> void:
		_t -= dt
		if _t > 0.0 or sim.over:
			return
		_t = rng.randf_range(0.6, 1.4) * (1.3 - 0.05 * level)
		var me := 1.0 if side == BattleSim.YOU else -1.0
		var hand: Array = (sim.hands[side] as Array).duplicate()
		var mana := float(sim.mana[side])
		# Threats: enemy troops on my half.
		var threats: Array[Dictionary] = []
		for e in sim.entities:
			if e["alive"] and int(e["side"]) != side and not e["tower"] and (e["pos"] as Vector2).y * me > 0.0:
				threats.append(e)
		if not threats.is_empty():
			var t: Dictionary = threats[0]
			var tp: Vector2 = t["pos"]
			# A fireball for a crowd.
			if hand.has("fireball") and mana >= 4.0 and threats.size() >= 3:
				if sim.play(side, "fireball", tp):
					return
			var options: Array = []
			for c in hand:
				if not GameData.is_spell(c) and float(GameData.card(c)["cost"]) <= mana and GameData.card(c)["targets"] == "any":
					options.append(c)
			if not options.is_empty():
				var pick: String = options[rng.randi() % options.size()]
				var spot := Vector2(clampf(tp.x + rng.randf_range(-1.5, 1.5), -8.0, 8.0), me * clampf(absf(tp.y) + 2.5, 3.0, 12.0))
				sim.play(side, pick, spot)
			return
		# Push when mana is high.
		if mana < 7.0 - minf(level, 4) * 0.5:
			return
		var options2: Array = []
		for c in hand:
			if not GameData.is_spell(c) and float(GameData.card(c)["cost"]) <= mana:
				options2.append(c)
		if options2.is_empty():
			return
		var lane := _weak_lane()
		var pick2: String = options2[rng.randi() % options2.size()]
		sim.play(side, pick2, Vector2(lane + rng.randf_range(-1.0, 1.0), me * rng.randf_range(5.0, 8.5)))

	func _weak_lane() -> float:
		var best := 0.0
		var low := INF
		for e in sim.entities:
			if e["alive"] and e["tower"] and int(e["side"]) != side and e["kind"] == "guard":
				if float(e["hp"]) < low:
					low = float(e["hp"])
					best = (e["pos"] as Vector2).x
		return best
