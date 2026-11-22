class_name GunModel
extends Node3D
## A weapon built from simple shapes so every attachment shows on the gun:
## scopes on top, a longer magazine, a grip under the barrel, a muzzle device.
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
	var att: Dictionary = w.get("att", {})
	var body_col: Color = d["color"]
	var metal := Models.material(body_col.darkened(0.25))
	metal.metallic = 0.6
	metal.roughness = 0.4
	var body := Models.material(body_col)
	body.roughness = 0.55
	var dark := Models.material(Color("1b1e22"))
	var len := float(d["len"])
	var thick := 0.075 if weapon_id != "pistol" else 0.06
	# Receiver and barrel.
	_box(Vector3(thick, 0.1, len * 0.45), Vector3(0, 0.03, -len * 0.12), body)
	_cyl(0.022, len * 0.6, Vector3(0, 0.05, -len * 0.55), metal)
	# Stock (not on pistols / SMG gets a short one).
	if weapon_id != "pistol":
		var sl := 0.12 if weapon_id == "smg" else 0.24
		_box(Vector3(thick * 0.8, 0.085, sl), Vector3(0, 0.0, len * 0.1 + sl * 0.5), body)
	# Grip.
	_box(Vector3(thick * 0.8, 0.13, 0.05), Vector3(0, -0.07, 0.02), dark).rotation.x = 0.25
	# Magazine: longer with an extended mag.
	var mag_len := 0.13 * (1.45 if att.has("mag") else 1.0)
	if weapon_id == "shotgun":
		_cyl(0.026, len * 0.45, Vector3(0, 0.0, -len * 0.35), dark)
	else:
		var m := _box(Vector3(thick * 0.7, mag_len, 0.06), Vector3(0, -0.02 - mag_len * 0.5, -len * 0.12), dark)
		m.rotation.x = -0.12
	# Scope.
	var scope := String(att.get("scope", ""))
	if scope == "red_dot":
		_box(Vector3(0.05, 0.05, 0.07), Vector3(0, 0.11, -len * 0.08), dark)
		_box(Vector3(0.012, 0.012, 0.01), Vector3(0, 0.12, -len * 0.08 - 0.036), Models.material(Color(1, 0.2, 0.2), 3.0))
	elif scope != "":
		var sl := {"scope2": 0.16, "scope4": 0.22, "scope8": 0.3}.get(scope, 0.18) as float
		_cyl(0.03 if scope != "scope8" else 0.036, sl, Vector3(0, 0.13, -len * 0.1), dark)
		_box(Vector3(0.025, 0.04, 0.03), Vector3(0, 0.095, -len * 0.1), dark)
	elif weapon_id != "pistol":
		_box(Vector3(0.012, 0.03, 0.012), Vector3(0, 0.1, -len * 0.38), dark)
	# Grip under the barrel.
	if att.has("grip"):
		_box(Vector3(0.035, 0.1, 0.035), Vector3(0, -0.04, -len * 0.38), dark)
	# Muzzle device.
	var tip := -len * 0.85
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
	for m in find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
