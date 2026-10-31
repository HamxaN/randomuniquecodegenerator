class_name KitchenState
extends RefCounted
## What is on the plates, the grill, in the fryer and at the drinks machine.
## The 3D kitchen only draws this, so the rules can be unit tested.

signal changed

var plates: Array = []   # each plate is an Array of ingredient names ([] = empty)
var grill: Array = []    # each slot is {"state": empty|cooking|ready|burnt, "t": seconds}
var cups: Array = []     # each slot is {"state": empty|pouring|ready, "t": seconds}
var fryer_state := "empty"   # empty, frying, ready
var fryer_t := 0.0
var fries := 0
var last_plate := -1
var burnt := 0

var cook_time := GameData.COOK_TIME
var burn_time := GameData.BURN_TIME
var fry_time := GameData.FRY_TIME
var pour_time := GameData.POUR_TIME
var batch := GameData.FRIES_PER_BATCH


func setup(plate_count: int, grill_slots: int, cup_slots: int = 2) -> void:
	plates.clear()
	for i in plate_count:
		plates.append([])
	grill.clear()
	for i in grill_slots:
		grill.append({"state": "empty", "t": 0.0})
	cups.clear()
	for i in cup_slots:
		cups.append({"state": "empty", "t": 0.0})


## Puts a bun on the first empty plate. Returns the plate, or -1 if none is free.
func add_bun() -> int:
	for i in plates.size():
		if (plates[i] as Array).is_empty():
			plates[i] = ["bun"]
			last_plate = i
			changed.emit()
			return i
	return -1


## Which plate [param kind] would go on: the last one touched if it fits, else the first that does.
func plate_for(kind: String) -> int:
	if last_plate >= 0 and last_plate < plates.size() and _fits(plates[last_plate], kind):
		return last_plate
	for i in plates.size():
		if _fits(plates[i], kind):
			return i
	return -1


func _fits(plate: Array, kind: String) -> bool:
	return plate.has("bun") and not plate.has(kind)


func add_topping(kind: String) -> int:
	var i := plate_for(kind)
	if i < 0:
		return -1
	(plates[i] as Array).append(kind)
	last_plate = i
	changed.emit()
	return i


## Starts a raw patty on the first free grill slot. Returns the slot or -1.
func start_patty() -> int:
	for i in grill.size():
		if grill[i]["state"] == "empty":
			grill[i] = {"state": "cooking", "t": 0.0}
			changed.emit()
			return i
	return -1


## Takes a patty off the grill. Returns the plate it went on, -1 if it can't
## go anywhere (or isn't ready yet) and -2 if it was burnt and got thrown away.
func take_patty(slot: int) -> int:
	if slot < 0 or slot >= grill.size():
		return -1
	var state: String = grill[slot]["state"]
	if state == "burnt":
		grill[slot] = {"state": "empty", "t": 0.0}
		burnt += 1
		changed.emit()
		return -2
	if state != "ready":
		return -1
	var plate := add_topping("patty")
	if plate >= 0:
		grill[slot] = {"state": "empty", "t": 0.0}
		changed.emit()
	return plate


## The first slot holding a cooked patty, or -1.
func ready_patty() -> int:
	for i in grill.size():
		if grill[i]["state"] == "ready":
			return i
	return -1


func start_fries() -> bool:
	if fryer_state != "empty":
		return false
	fryer_state = "frying"
	fryer_t = 0.0
	changed.emit()
	return true


func take_fries() -> bool:
	if fryer_state != "ready" or fries <= 0:
		return false
	fries -= 1
	if fries == 0:
		fryer_state = "empty"
	changed.emit()
	return true


func start_drink(slot: int) -> bool:
	if slot < 0 or slot >= cups.size() or cups[slot]["state"] != "empty":
		return false
	cups[slot] = {"state": "pouring", "t": 0.0}
	changed.emit()
	return true


func take_drink(slot: int) -> bool:
	if slot < 0 or slot >= cups.size() or cups[slot]["state"] != "ready":
		return false
	cups[slot] = {"state": "empty", "t": 0.0}
	changed.emit()
	return true


## Hands over everything on a plate and clears it.
func take_plate(i: int) -> Array:
	var items: Array = plates[i]
	plates[i] = []
	changed.emit()
	return items


## Throws away the last plate touched (or the first one with food on it).
func trash() -> int:
	var i := last_plate if last_plate >= 0 and last_plate < plates.size() and not (plates[last_plate] as Array).is_empty() else -1
	if i < 0:
		for k in plates.size():
			if not (plates[k] as Array).is_empty():
				i = k
				break
	if i < 0:
		return -1
	plates[i] = []
	changed.emit()
	return i


func tick(delta: float) -> void:
	var dirty := false
	for i in grill.size():
		var s: Dictionary = grill[i]
		match s["state"]:
			"cooking":
				s["t"] = float(s["t"]) + delta
				if s["t"] >= cook_time:
					s["state"] = "ready"
					s["t"] = 0.0
					dirty = true
			"ready":
				s["t"] = float(s["t"]) + delta
				if s["t"] >= burn_time:
					s["state"] = "burnt"
					dirty = true
	if fryer_state == "frying":
		fryer_t += delta
		if fryer_t >= fry_time:
			fryer_state = "ready"
			fries = batch
			dirty = true
	for i in cups.size():
		var c: Dictionary = cups[i]
		if c["state"] == "pouring":
			c["t"] = float(c["t"]) + delta
			if c["t"] >= pour_time:
				c["state"] = "ready"
				dirty = true
	if dirty:
		changed.emit()


## 0..1 progress of a grill slot's current stage.
func grill_progress(i: int) -> float:
	var s: Dictionary = grill[i]
	match s["state"]:
		"cooking":
			return clampf(float(s["t"]) / cook_time, 0.0, 1.0)
		"ready":
			return clampf(float(s["t"]) / burn_time, 0.0, 1.0)
	return 0.0
