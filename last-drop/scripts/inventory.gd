class_name Inventory
extends RefCounted
## What one fighter carries: two weapon slots with attachments, ammo, armour,
## heals and grenades. Pure logic, so the server can own it and tests can run it.

var weapons: Array = [{}, {}]
var active := -1
var ammo := {"light": 0, "rifle": 0, "shells": 0, "heavy": 0}
var vest := 0
var helmet := 0
var heals := {"bandage": 0, "medkit": 0, "drink": 0}
var grenades := 0
## Attachments that don't fit a carried weapon yet; fitted automatically later.
var spare: Array = []


func current() -> Dictionary:
	if active < 0 or active > 1:
		return {}
	return weapons[active]


func has_weapon() -> bool:
	return not current().is_empty()


func weapon_count() -> int:
	return int(not weapons[0].is_empty()) + int(not weapons[1].is_empty())


## True if picking [param it] up needs no decision (no weapon swap).
func wants(it: Dictionary) -> bool:
	var id := String(it.get("id", ""))
	match String(it.get("kind", "")):
		"ammo":
			return int(ammo.get(id, 0)) < int(GameData.AMMO[id]["max"])
		"heal":
			return int(heals.get(id, 0)) < int(GameData.HEALS[id]["max"])
		"grenade":
			return grenades < GameData.MAX_GRENADES
		"vest":
			return int(it.get("lvl", 0)) > vest
		"helmet":
			return int(it.get("lvl", 0)) > helmet
		"attach":
			return _attach_target(id) >= 0 or (spare.size() < 6 and not spare.has(id))
		"weapon":
			return weapon_count() < 2
	return false


## Takes [param it]. Returns the items that come out (a swapped weapon, an old vest,
## leftovers that didn't fit). [param slot] picks which weapon slot a gun replaces.
func take(it: Dictionary, slot: int = -1) -> Array:
	var out: Array = []
	var id := String(it.get("id", ""))
	var n := int(it.get("n", 1))
	match String(it.get("kind", "")):
		"ammo":
			var cap := int(GameData.AMMO[id]["max"])
			var room := cap - int(ammo[id])
			var got := mini(room, n)
			ammo[id] = int(ammo[id]) + got
			if n - got > 0:
				out.append({"kind": "ammo", "id": id, "n": n - got})
		"heal":
			var cap := int(GameData.HEALS[id]["max"])
			var got := mini(cap - int(heals[id]), n)
			heals[id] = int(heals[id]) + got
			if n - got > 0:
				out.append({"kind": "heal", "id": id, "n": n - got})
		"grenade":
			var got := mini(GameData.MAX_GRENADES - grenades, n)
			grenades += got
			if n - got > 0:
				out.append({"kind": "grenade", "id": "frag", "n": n - got})
		"vest":
			if vest > 0:
				out.append(GameData.item("vest", str(vest)))
			vest = int(it.get("lvl", 1))
		"helmet":
			if helmet > 0:
				out.append(GameData.item("helmet", str(helmet)))
			helmet = int(it.get("lvl", 1))
		"attach":
			var target := _attach_target(id)
			if target >= 0:
				var w: Dictionary = weapons[target]
				var att: Dictionary = w["att"]
				var aslot := String(GameData.ATTACH[id]["slot"])
				if att.has(aslot):
					_stash(String(att[aslot]), out)
				att[aslot] = id
				_clamp_mag(w)
			else:
				_stash(id, out)
		"weapon":
			var w := {"id": id, "mag": int(it.get("mag", 0)), "att": (it.get("att", {}) as Dictionary).duplicate()}
			var s := slot
			if s < 0 or s > 1:
				s = 0 if weapons[0].is_empty() else (1 if weapons[1].is_empty() else maxi(active, 0))
			if not weapons[s].is_empty():
				out.append(_as_item(weapons[s]))
			weapons[s] = w
			if active < 0 or weapons[active].is_empty():
				active = s
			_fit_spares()
	return out


## Where an attachment should go: the active weapon if it fits and is an upgrade, else the other one.
func _attach_target(id: String) -> int:
	var order := [active, 1 - active] if active >= 0 else [0, 1]
	var a: Dictionary = GameData.ATTACH[id]
	var aslot := String(a["slot"])
	for i in order:
		var w: Dictionary = weapons[i]
		if w.is_empty() or not GameData.fits(String(w["id"]), id):
			continue
		var att: Dictionary = w["att"]
		if not att.has(aslot):
			return i
		var cur: Dictionary = GameData.ATTACH.get(String(att[aslot]), {})
		if int(a["tier"]) > int(cur.get("tier", 0)):
			return i
	return -1


func _stash(id: String, out: Array) -> void:
	if spare.size() < 6 and not spare.has(id):
		spare.append(id)
	else:
		out.append({"kind": "attach", "id": id, "n": 1})


func _fit_spares() -> void:
	for id in spare.duplicate():
		var t := _attach_target(String(id))
		if t >= 0:
			spare.erase(id)
			var w: Dictionary = weapons[t]
			var aslot := String(GameData.ATTACH[id]["slot"])
			var att: Dictionary = w["att"]
			if att.has(aslot):
				spare.append(att[aslot])
			att[aslot] = id
			_clamp_mag(w)


func _clamp_mag(w: Dictionary) -> void:
	w["mag"] = mini(int(w["mag"]), int(GameData.stats(w)["mag"]))


func _as_item(w: Dictionary) -> Dictionary:
	return {"kind": "weapon", "id": w["id"], "n": 1, "mag": int(w["mag"]), "att": (w["att"] as Dictionary).duplicate()}


## Rounds the active weapon can load from the bag right now.
func reload_amount() -> int:
	var w := current()
	if w.is_empty():
		return 0
	var s := GameData.stats(w)
	var need := int(s["mag"]) - int(w["mag"])
	return mini(need, int(ammo[String(s["ammo"])]))


func reload() -> int:
	var n := reload_amount()
	if n <= 0:
		return 0
	var w := current()
	var kind := String(GameData.weapon(String(w["id"]))["ammo"])
	ammo[kind] = int(ammo[kind]) - n
	w["mag"] = int(w["mag"]) + n
	return n


## Uses one round from the active weapon. False if it is empty.
func use_round() -> bool:
	var w := current()
	if w.is_empty() or int(w["mag"]) <= 0:
		return false
	w["mag"] = int(w["mag"]) - 1
	return true


func switch_to(slot: int) -> bool:
	if slot < 0 or slot > 1 or weapons[slot].is_empty() or slot == active:
		return false
	active = slot
	return true


func use_heal(id: String) -> bool:
	if int(heals.get(id, 0)) <= 0:
		return false
	heals[id] = int(heals[id]) - 1
	return true


## Every item this fighter drops when eliminated.
func drop_all() -> Array:
	var out: Array = []
	for w in weapons:
		if not (w as Dictionary).is_empty():
			out.append(_as_item(w))
	for k in ammo:
		if int(ammo[k]) > 0:
			out.append({"kind": "ammo", "id": k, "n": int(ammo[k])})
	for k in heals:
		if int(heals[k]) > 0:
			out.append({"kind": "heal", "id": k, "n": int(heals[k])})
	if grenades > 0:
		out.append({"kind": "grenade", "id": "frag", "n": grenades})
	if vest > 0:
		out.append(GameData.item("vest", str(vest)))
	if helmet > 0:
		out.append(GameData.item("helmet", str(helmet)))
	for id in spare:
		out.append({"kind": "attach", "id": id, "n": 1})
	return out


func to_dict() -> Dictionary:
	return {"w": weapons.duplicate(true), "a": active, "am": ammo.duplicate(), "v": vest, "h": helmet,
		"he": heals.duplicate(), "g": grenades, "sp": spare.duplicate()}


func from_dict(d: Dictionary) -> void:
	weapons = (d.get("w", [{}, {}]) as Array).duplicate(true)
	active = int(d.get("a", -1))
	ammo = (d.get("am", ammo) as Dictionary).duplicate()
	vest = int(d.get("v", 0))
	helmet = int(d.get("h", 0))
	heals = (d.get("he", heals) as Dictionary).duplicate()
	grenades = int(d.get("g", 0))
	spare = (d.get("sp", []) as Array).duplicate()


## A rough score of how well equipped this fighter is (bots use it to decide when to fight).
func power() -> float:
	var p := float(vest + helmet) * 10.0
	for w in weapons:
		if not (w as Dictionary).is_empty():
			var s := GameData.stats(w)
			p += float(s["dmg"]) * float(s["pellets"]) * float(s["rpm"]) / 600.0
	return p
