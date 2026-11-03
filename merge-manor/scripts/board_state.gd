class_name BoardState
extends RefCounted
## The merge board and the manor's progress: cells with items and
## generators, energy, coins and stars, the three open orders and the
## renovation steps. Pure data, so every rule is unit tested.

signal changed

var cells: Array = []      # COLS * ROWS ids ("" = empty)
var energy := GameData.MAX_ENERGY
var energy_t := 0.0
var coins := 50
var stars := 0
var orders: Array = []     # item ids
var room := 0
var step := 0
var merges := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	cells.resize(GameData.COLS * GameData.ROWS)
	cells.fill("")
	cells[idx(0, 0)] = "gen_box"
	cells[idx(GameData.COLS - 1, 0)] = "gen_basket"
	cells[idx(3, GameData.ROWS - 1)] = "gen_bench"
	for p in [[2, 2, "cozy:1"], [3, 2, "cozy:1"], [4, 3, "books:1"], [1, 4, "plants:1"]]:
		cells[idx(p[0], p[1])] = p[2]
	for i in GameData.ORDER_SLOTS:
		orders.append(new_order())


func idx(c: int, r: int) -> int:
	return r * GameData.COLS + c


func col(i: int) -> int:
	return i % GameData.COLS


func row(i: int) -> int:
	return i / GameData.COLS


func at(i: int) -> String:
	return cells[i] if i >= 0 and i < cells.size() else ""


## Drags the item at [param from] onto [param to]: merge, move or swap.
## Returns "merge", "move", "swap" or "none".
func move(from: int, to: int) -> String:
	if from == to or at(from) == "" or to < 0 or to >= cells.size():
		return "none"
	var a := at(from)
	var b := at(to)
	if b == "":
		cells[to] = a
		cells[from] = ""
		changed.emit()
		return "move"
	if GameData.can_merge(a, b):
		cells[to] = GameData.merged(a)
		cells[from] = ""
		merges += 1
		changed.emit()
		return "merge"
	cells[to] = a
	cells[from] = b
	changed.emit()
	return "swap"


## The empty cell closest to [param i], or -1 if the board is full.
func nearest_empty(i: int) -> int:
	var best := -1
	var bd := INF
	for k in cells.size():
		if cells[k] != "":
			continue
		var d := Vector2(col(k) - col(i), row(k) - row(i)).length()
		if d < bd:
			bd = d
			best = k
	return best


## Taps a generator: costs one energy and drops a new item next to it.
## Returns the cell it landed in, -1 without energy, -2 with a full board.
func tap_generator(i: int) -> int:
	var id := at(i)
	if not GameData.is_generator(id):
		return -1
	if energy <= 0:
		return -1
	var spot := nearest_empty(i)
	if spot < 0:
		return -2
	var chains: Array = GameData.GENERATORS[id.trim_prefix("gen_")]["chains"]
	var chain: String = chains[rng.randi() % chains.size()]
	var lv := 2 if rng.randf() < 0.12 else 1
	cells[spot] = GameData.item(chain, lv)
	energy -= 1
	changed.emit()
	return spot


func tick(dt: float) -> void:
	if energy >= GameData.MAX_ENERGY:
		energy_t = 0.0
		return
	energy_t += dt
	while energy_t >= GameData.ENERGY_EVERY and energy < GameData.MAX_ENERGY:
		energy_t -= GameData.ENERGY_EVERY
		energy += 1
		changed.emit()


## How far through the manor you are (0..1), which makes orders harder.
func progress() -> float:
	var done := 0
	for i in room:
		done += (GameData.ROOMS[i]["steps"] as Array).size()
	return float(done + step) / GameData.total_steps()


func new_order() -> String:
	var chain: String = GameData.CHAINS.keys()[rng.randi() % GameData.CHAINS.size()]
	var top := GameData.max_level(chain)
	var hi := clampi(3 + int(progress() * 4.0), 2, top)
	var lo := clampi(hi - 2, 2, top)
	return GameData.item(chain, rng.randi_range(lo, hi))


## The board cell holding what order [param o] wants, or -1.
func find_for_order(o: int) -> int:
	var want: String = orders[o]
	for i in cells.size():
		if cells[i] == want:
			return i
	return -1


func deliver(o: int) -> bool:
	var i := find_for_order(o)
	if i < 0:
		return false
	var reward := GameData.order_reward(orders[o])
	cells[i] = ""
	stars += int(reward["stars"])
	coins += int(reward["coins"])
	orders[o] = new_order()
	changed.emit()
	return true


func sell(i: int) -> int:
	var id := at(i)
	if not GameData.is_item(id):
		return 0
	var v := GameData.sell_value(id)
	coins += v
	cells[i] = ""
	changed.emit()
	return v


func finished() -> bool:
	return room >= GameData.ROOMS.size()


func current_step() -> Dictionary:
	if finished():
		return {}
	return GameData.ROOMS[room]["steps"][step]


## Spends stars on the next renovation step. Returns the step done, or {}.
func renovate() -> Dictionary:
	var s := current_step()
	if s.is_empty() or stars < int(s["stars"]):
		return {}
	stars -= int(s["stars"])
	step += 1
	if step >= (GameData.ROOMS[room]["steps"] as Array).size():
		room += 1
		step = 0
	changed.emit()
	return s


## Buying energy with coins (a refill) costs more the emptier you are.
func refill_cost() -> int:
	return 20 + (GameData.MAX_ENERGY - energy)


func buy_refill() -> bool:
	var c := refill_cost()
	if coins < c or energy >= GameData.MAX_ENERGY:
		return false
	coins -= c
	energy = GameData.MAX_ENERGY
	changed.emit()
	return true


func to_dict() -> Dictionary:
	return {"cells": cells, "energy": energy, "energy_t": energy_t, "coins": coins, "stars": stars, "orders": orders,
		"room": room, "step": step, "merges": merges}


func from_dict(d: Dictionary) -> void:
	var c: Array = d.get("cells", [])
	if c.size() == GameData.COLS * GameData.ROWS:
		cells = c
	energy = int(d.get("energy", GameData.MAX_ENERGY))
	energy_t = float(d.get("energy_t", 0.0))
	coins = int(d.get("coins", 50))
	stars = int(d.get("stars", 0))
	room = int(d.get("room", 0))
	step = int(d.get("step", 0))
	merges = int(d.get("merges", 0))
	var o: Array = d.get("orders", [])
	if o.size() == GameData.ORDER_SLOTS:
		orders = o
