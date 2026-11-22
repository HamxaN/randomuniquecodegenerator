class_name GunModel
extends Node3D
## A weapon built from simple shapes, with a silhouette per class (pistol,
## revolver, SMG, rifle, LMG, shotgun, marksman, sniper) and every attachment
## visible: scopes on top, longer mags, a grip under the barrel, muzzle devices.
## Rarity adds a coloured trim (Legendary guns are gold); camos tint the body.
## The barrel points along -Z; the origin is the grip hand.

var weapon_id := ""
var muzzle: Marker3D


static func make(w: Dictionary) -> GunModel:
	var g := GunModel.new()
	g.build(w)
	return g


func build(w: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	weapon_id = String(w.get("id", "pistol"))
	var d := GameData.weapon(weapon_id)
	var cls := String(d["class"])
	var att: Dictionary = w.get("att", {})
	var rar := clampi(int(w.get("rar", 0)), 0, 3)
	var camo := GameData.camo(String(w.get("camo", "none")))
	var body_col: Color = d["color"]
	if camo["id"] != "none":
		body_col = camo["color"]
	if rar == 3 and camo["id"] == "none":
		body_col = Color("c9a03a")
	var body := Models.material(body_col)
	body.roughness = 0.5
	if camo.get("metal", false) or (rar == 3 and camo["id"] == "none"):
		body.metallic = 0.85
		body.roughness = 0.25
	if camo.get("glow", false):
		body.emission_enabled = true
		body.emission = body_col
		body.emission_energy_multiplier = 0.6
	var metal := Models.material(Color("2b2f35"))
	metal.metallic = 0.7
	metal.roughness = 0.35
	var dark := Models.material(Color("1b1e22"))
	var trim := Models.material(GameData.RARITY[rar]["color"], 0.9 if rar > 0 else 0.0)
	var len := float(d["len"])
	var thick := 0.06 if cls == "pistol" else 0.075
	var tip := -len * 0.85
	match cls:
		"pistol":
			if weapon_id == "revolver":
				_box(Vector3(thick, 0.08, 0.16), Vector3(0, 0.04, -0.05), body)
				_cyl(0.045, 0.08, Vector3(0, 0.035, -0.08), metal)
				_cyl(0.02, len * 0.7, Vector3(0, 0.06, -len * 0.55), metal)
				tip = -len * 0.9
			else:
				_box(Vector3(thick, 0.08, len * 0.85), Vector3(0, 0.04, -len * 0.35), body)
				_cyl(0.016, 0.06, Vector3(0, 0.05, -len * 0.8), metal)
			_box(Vector3(thick * 0.85, 0.13, 0.05), Vector3(0, -0.06, 0.02), dark).rotation.x = 0.3
		"lmg":
			_box(Vector3(0.1, 0.12, len * 0.5), Vector3(0, 0.03, -len * 0.15), body)
			_cyl(0.026, len * 0.6, Vector3(0, 0.05, -len * 0.6), metal)
			_box(Vector3(0.08, 0.085, 0.26), Vector3(0, 0.0, len * 0.12 + 0.13), body)
			# Box magazine and bipod.
			_box(Vector3(0.12, 0.14 * (1.3 if att.has("mag") else 1.0), 0.14), Vector3(-0.07, -0.06, -len * 0.12), dark)
			var leg := _box(Vector3(0.012, 0.2, 0.012), Vector3(0.04, -0.06, -len * 0.75), dark)
			leg.rotation.z = 0.4
			var leg2 := _box(Vector3(0.012, 0.2, 0.012), Vector3(-0.04, -0.06, -len * 0.75), dark)
			leg2.rotation.z = -0.4
			_box(Vector3(thick * 0.8, 0.13, 0.05), Vector3(0, -0.07, 0.02), dark).rotation.x = 0.25
		"shotgun":
			_box(Vector3(thick, 0.1, len * 0.4), Vector3(0, 0.03, -len * 0.1), body)
			_cyl(0.03, len * 0.6, Vector3(0, 0.06, -len * 0.55), metal)
			_cyl(0.026, len * 0.45, Vector3(0, 0.0, -len * 0.42), dark)
			if weapon_id == "riot":
				_box(Vector3(thick * 0.7, 0.13 * (1.4 if att.has("mag") else 1.0), 0.08), Vector3(0, -0.07, -len * 0.1), dark)
			_box(Vector3(thick * 0.8, 0.09, 0.24), Vector3(0, 0.0, len * 0.1 + 0.12), body)
			_box(Vector3(thick * 0.8, 0.12, 0.05), Vector3(0, -0.07, 0.02), dark).rotation.x = 0.25
		_:
			# Rifles, SMGs, marksman and sniper rifles.
			_box(Vector3(thick, 0.1, len * 0.45), Vector3(0, 0.03, -len * 0.12), body)
			var barrel_r := 0.024 if cls != "sniper" else 0.02
			_cyl(barrel_r, len * 0.6, Vector3(0, 0.05, -len * 0.55), metal)
			if cls != "smg":
				_box(Vector3(thick * 0.75, 0.07, len * 0.3), Vector3(0, 0.02, -len * 0.45), body)
			var sl := 0.12 if cls == "smg" else (0.3 if cls == "sniper" else 0.24)
			_box(Vector3(thick * 0.8, 0.085 if cls != "sniper" else 0.11, sl), Vector3(0, 0.0, len * 0.1 + sl * 0.5), body)
			_box(Vector3(thick * 0.8, 0.13, 0.05), Vector3(0, -0.07, 0.02), dark).rotation.x = 0.25
			var mag_len := 0.13 * (1.45 if att.has("mag") else 1.0)
			if cls == "sniper":
				mag_len *= 0.6
				_box(Vector3(0.02, 0.02, 0.06), Vector3(0.06, 0.06, -0.02), metal)  # bolt handle
			var m := _box(Vector3(thick * 0.7, mag_len, 0.06), Vector3(0, -0.02 - mag_len * 0.5, -len * 0.12), dark)
			m.rotation.x = -0.12 if cls != "sniper" else 0.0
			if weapon_id == "burst":
				_box(Vector3(thick * 1.05, 0.03, len * 0.2), Vector3(0, 0.085, -len * 0.05), trim)
	# Rarity trim along the side.
	if rar > 0:
		_box(Vector3(thick * 1.08, 0.018, len * 0.3), Vector3(0, 0.035, -len * 0.12), trim)
	# Scope.
	var scope := String(att.get("scope", ""))
	var sy := 0.11 if cls != "lmg" else 0.12
	if scope == "red_dot":
		_box(Vector3(0.05, 0.05, 0.07), Vector3(0, sy, -len * 0.08), dark)
		_box(Vector3(0.012, 0.012, 0.01), Vector3(0, sy + 0.01, -len * 0.08 - 0.036), Models.material(Color(1, 0.2, 0.2), 3.0))
	elif scope != "":
		var scl := {"scope2": 0.16, "scope4": 0.22, "scope8": 0.3}.get(scope, 0.18) as float
		_cyl(0.03 if scope != "scope8" else 0.036, scl, Vector3(0, sy + 0.02, -len * 0.1), dark)
		_cyl(0.034, 0.02, Vector3(0, sy + 0.02, -len * 0.1 - scl * 0.5), Models.material(Color(0.3, 0.55, 0.9), 0.8))
		_box(Vector3(0.025, 0.04, 0.03), Vector3(0, sy - 0.015, -len * 0.1), dark)
	elif cls != "pistol":
		_box(Vector3(0.012, 0.03, 0.012), Vector3(0, 0.1, -len * 0.38), dark)
	if att.has("grip"):
		_box(Vector3(0.035, 0.1, 0.035), Vector3(0, -0.04, -len * 0.38), dark)
	match String(att.get("muzzle", "")):
		"silencer":
			_cyl(0.035, 0.22, Vector3(0, 0.05, tip - 0.11), dark)
			tip -= 0.22
		"comp":
			_cyl(0.03, 0.07, Vector3(0, 0.05, tip - 0.035), dark)
			tip -= 0.07
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.05, tip - 0.02)
	add_child(muzzle)
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _cyl(r: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI / 2
	add_child(mi)
	return mi
