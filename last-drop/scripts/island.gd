class_name Island
extends Node3D
## The battle island, generated from the match seed so every peer builds the same
## one: rolling terrain, beaches and sea, towns of buildings, forests, rocks, loot
## spots and parked vehicles. The server builds only collision; clients add visuals.

const CELL := 5.0
const EXTENT := 340.0
const BUILDING_SCALE := 5.0
const SEA_LEVEL := 0.0
## Footprint (x size, height, z min, z max) of each KayKit building at scale 1.
const BUILDINGS := {
	"A": [1.207, 1.55, -0.65, 0.8], "B": [1.607, 1.55, -0.65, 0.65], "C": [1.207, 2.25, -0.65, 0.65],
	"D": [1.607, 2.25, -0.65, 0.65], "E": [2.007, 2.25, -0.65, 0.8], "F": [2.007, 2.25, -0.65, 0.65],
	"G": [2.007, 2.25, -0.65, 0.8], "H": [2.007, 2.95, -0.65, 0.65],
}

var seed_value := 0
var towns: Array = []          # {name, center: Vector2, radius, height}
var buildings: Array = []      # {pos: Vector3, rot, model, size: Vector3}
var crates: Array = []         # Vector3 positions
var trees: Array = []          # Vector4 (x, y, z, scale)
var rocks: Array = []          # Vector4
var loot_spots: Array[Vector3] = []
var vehicle_spots: Array = []  # {pos: Vector3, rot}
var _noise: FastNoiseLite
var _detail: FastNoiseLite


## Lays out everything (no nodes). Deterministic for [param s].
func generate(s: int) -> void:
	seed_value = s
	_noise = FastNoiseLite.new()
	_noise.seed = s
	_noise.frequency = 0.0055
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = s + 101
	_detail.frequency = 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + 7
	_place_towns(rng)
	for t in towns:
		_layout_town(t, rng)
	_scatter_nature(rng)
	_wild_loot(rng)
	_vehicles(rng)


## Terrain height before towns are flattened.
func _raw(x: float, z: float) -> float:
	var r := GameData.ISLAND_RADIUS
	var d := Vector2(x, z).length() / r
	var coast := d + _noise.get_noise_2d(x * 0.6, z * 0.6) * 0.18
	var land := 1.0 - smoothstep(0.72, 1.02, coast)
	var hills := (_noise.get_noise_2d(x, z) + 0.35) * 26.0
	var ridge := maxf(0.0, 1.0 - absf(_noise.get_noise_2d(z * 0.7 + 400.0, x * 0.7)) * 4.0) * 16.0 * smoothstep(0.85, 0.3, d)
	var bumps := _detail.get_noise_2d(x, z) * 1.2
	var h := 3.0 + maxf(hills, -2.0) * 0.55 + ridge + bumps
	return lerpf(-9.0, maxf(h, 1.8), land) if land < 1.0 else maxf(h, 1.8)


## Ground height at a point, with town plateaus flattened.
func height(x: float, z: float) -> float:
	var h := _raw(x, z)
	for t in towns:
		var c: Vector2 = t["center"]
		var dist := Vector2(x, z).distance_to(c)
		var r := float(t["radius"])
		if dist < r + 30.0:
			var k := smoothstep(r + 30.0, r, dist)
			h = lerpf(h, float(t["height"]), k)
	return h


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.5
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func _place_towns(rng: RandomNumberGenerator) -> void:
	var names := GameData.TOWN_NAMES.duplicate()
	var base := rng.randf() * TAU
	var count := 6
	for i in count:
		var placed := false
		for attempt in 30:
			var ang := base + TAU * i / count + rng.randf_range(-0.35, 0.35)
			var dist := GameData.ISLAND_RADIUS * rng.randf_range(0.42, 0.66)
			var c := Vector2.from_angle(ang) * dist
			if _raw(c.x, c.y) < 2.5:
				continue
			var ok := true
			for t in towns:
				if (t["center"] as Vector2).distance_to(c) < 95.0:
					ok = false
			if not ok:
				continue
			towns.append({"name": names[i], "center": c, "radius": rng.randf_range(30.0, 42.0), "height": maxf(_raw(c.x, c.y), 3.0)})
			placed = true
			break
		if not placed:
			var c := Vector2.from_angle(base + TAU * i / count) * GameData.ISLAND_RADIUS * 0.35
			towns.append({"name": names[i], "center": c, "radius": 30.0, "height": maxf(_raw(c.x, c.y), 3.0)})
	# A lookout near the middle, away from the other towns.
	var best := Vector2.ZERO
	var best_gap := 0.0
	for attempt in 24:
		var c := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * GameData.ISLAND_RADIUS * 0.25
		var gap := 1e9
		for t in towns:
			gap = minf(gap, (t["center"] as Vector2).distance_to(c))
		if gap > best_gap and _raw(c.x, c.y) > 2.5:
			best_gap = gap
			best = c
	towns.append({"name": names[6], "center": best, "radius": 22.0, "height": maxf(_raw(best.x, best.y), 4.0)})


func _layout_town(t: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = t["center"]
	var r := float(t["radius"])
	var y := float(t["height"])
	var heading := rng.randf() * TAU
	var models := BUILDINGS.keys()
	# Buildings in two rows facing a main street, plus a few scattered.
	var spacing := 14.0
	var row_len := int(r * 2.0 / spacing)
	for side in [-1, 1]:
		for k in row_len:
			if rng.randf() < 0.18:
				continue
			var along := -r + spacing * 0.5 + k * spacing
			var local := Vector2(along, side * 11.0)
			_add_building(c, heading, local, side, y, String(models[rng.randi() % models.size()]), rng)
	for k in 3:
		var local := Vector2(rng.randf_range(-r, r), rng.randf_range(20.0, r) * (1 if rng.randf() < 0.5 else -1))
		_add_building(c, heading, local, 1 if local.y < 0 else -1, y, String(models[rng.randi() % models.size()]), rng)
	# Crates and loot on the street.
	for k in 6:
		var local := Vector2(rng.randf_range(-r * 0.9, r * 0.9), rng.randf_range(-4.0, 4.0))
		var p := c + local.rotated(heading)
		var pos := Vector3(p.x, y, p.y)
		crates.append(pos)
		loot_spots.append(pos + Vector3(rng.randf_range(-1.5, 1.5), 0, 2.0))
	for k in 5:
		var local := Vector2(rng.randf_range(-r, r), rng.randf_range(-3.0, 3.0))
		var p := c + local.rotated(heading)
		loot_spots.append(Vector3(p.x, y, p.y))
	t["heading"] = heading


func _add_building(c: Vector2, heading: float, local: Vector2, side: int, y: float, model: String, rng: RandomNumberGenerator) -> void:
	var f: Array = BUILDINGS[model]
	var s := BUILDING_SCALE
	var size := Vector3(float(f[0]) * s, float(f[1]) * s, (float(f[3]) - float(f[2])) * s)
	# Face the street: models face +z, so rows on the +y side turn round.
	var rot := heading + (PI if side > 0 else 0.0) + PI * 0.5 * 0.0
	var p := c + local.rotated(heading)
	var pos := Vector3(p.x, y, p.y)
	# Don't overlap earlier buildings.
	for b in buildings:
		if (b["pos"] as Vector3).distance_to(pos) < 11.0:
			return
	buildings.append({"pos": pos, "rot": -rot, "model": model, "size": size, "zoff": (float(f[2]) + float(f[3])) * 0.5 * s})
	# Loot by the front door and around the sides.
	var fwd := Vector3(sin(-rot), 0, cos(-rot))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var front := pos + fwd * (size.z * 0.5 + 2.2)
	loot_spots.append(front + right * rng.randf_range(-1.5, 1.5))
	loot_spots.append(pos + right * (size.x * 0.5 + 1.6) + fwd * rng.randf_range(-2.0, 2.0))
	if rng.randf() < 0.6:
		loot_spots.append(pos - right * (size.x * 0.5 + 1.6) + fwd * rng.randf_range(-2.0, 2.0))
	if rng.randf() < 0.5:
		loot_spots.append(pos - fwd * (size.z * 0.5 + 1.8))


func _near_town(x: float, z: float, pad: float) -> bool:
	for t in towns:
		if (t["center"] as Vector2).distance_to(Vector2(x, z)) < float(t["radius"]) + pad:
			return true
	return false


func _scatter_nature(rng: RandomNumberGenerator) -> void:
	var r := GameData.ISLAND_RADIUS
	var tries := 0
	while trees.size() < 340 and tries < 5000:
		tries += 1
		var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.95
		# Forests clump where the noise says so.
		if _noise.get_noise_2d(p.x * 1.7 + 900.0, p.y * 1.7) < -0.05 and rng.randf() < 0.75:
			continue
		var h := height(p.x, p.y)
		if h < 2.2 or _near_town(p.x, p.y, 6.0):
			continue
		trees.append(Vector4(p.x, h, p.y, rng.randf_range(5.5, 8.5)))
	tries = 0
	while rocks.size() < 70 and tries < 2000:
		tries += 1
		var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
		var h := height(p.x, p.y)
		if h < 0.6 or _near_town(p.x, p.y, 4.0):
			continue
		rocks.append(Vector4(p.x, h, p.y, rng.randf_range(10.0, 22.0)))


func _wild_loot(rng: RandomNumberGenerator) -> void:
	var count := 0
	var tries := 0
	while count < 45 and tries < 800:
		tries += 1
		var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * GameData.ISLAND_RADIUS * 0.85
		var h := height(p.x, p.y)
		if h < 2.0 or _near_town(p.x, p.y, 10.0):
			continue
		loot_spots.append(Vector3(p.x, h, p.y))
		count += 1


func _vehicles(rng: RandomNumberGenerator) -> void:
	for t in towns:
		var c: Vector2 = t["center"]
		var heading := float(t.get("heading", 0.0))
		var n := 2 if float(t["radius"]) > 32.0 else 1
		for k in n:
			var local := Vector2(rng.randf_range(-t["radius"] * 0.7, t["radius"] * 0.7), rng.randf_range(-3.5, 3.5))
			var p := c + local.rotated(heading)
			vehicle_spots.append({"pos": Vector3(p.x, float(t["height"]), p.y), "rot": -heading + PI * 0.5})
	var tries := 0
	while vehicle_spots.size() < 12 and tries < 400:
		tries += 1
		var p := Vector2.from_angle(rng.randf() * TAU) * GameData.ISLAND_RADIUS * rng.randf_range(0.2, 0.75)
		var h := height(p.x, p.y)
		if h < 2.5 or _near_town(p.x, p.y, 8.0) or normal_at(p.x, p.y).y < 0.93:
			continue
		vehicle_spots.append({"pos": Vector3(p.x, h, p.y), "rot": rng.randf() * TAU})


## Creates the nodes: collision always, meshes only when [param visuals].
func build(visuals: bool) -> void:
	_build_terrain(visuals)
	_build_buildings(visuals)
	_build_nature(visuals)
	if visuals:
		_build_sea()


func _build_terrain(visuals: bool) -> void:
	var n := int(EXTENT * 2.0 / CELL) + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			var x := -EXTENT + i * CELL
			var z := -EXTENT + j * CELL
			hs[j * n + i] = height(x, z)
	# Collision as a triangle mesh (works with every physics engine, no scaling).
	var faces := PackedVector3Array()
	faces.resize((n - 1) * (n - 1) * 6)
	var fi := 0
	for j in n - 1:
		for i in n - 1:
			var a := Vector3(-EXTENT + i * CELL, hs[j * n + i], -EXTENT + j * CELL)
			var b := Vector3(a.x + CELL, hs[j * n + i + 1], a.z)
			var c := Vector3(a.x, hs[(j + 1) * n + i], a.z + CELL)
			var d := Vector3(a.x + CELL, hs[(j + 1) * n + i + 1], a.z + CELL)
			faces[fi] = a
			faces[fi + 1] = b
			faces[fi + 2] = c
			faces[fi + 3] = b
			faces[fi + 4] = d
			faces[fi + 5] = c
			fi += 6
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	if not visuals:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x := -EXTENT + i * CELL
			var z := -EXTENT + j * CELL
			var h := hs[j * n + i]
			st.set_color(_ground_color(x, z, h))
			st.set_uv(Vector2(x, z) * 0.05)
			st.add_vertex(Vector3(x, h, z))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ground_color(x: float, z: float, h: float) -> Color:
	var sand := Color("d2b97f")
	var grass := Color("6fae4a").lerp(Color("5a9a3e"), clampf(_detail.get_noise_2d(x * 0.5, z * 0.5) + 0.5, 0.0, 1.0))
	var rock := Color("8a8578")
	var deep := Color("2c6f86")
	if h < -0.5:
		return deep.lerp(sand, clampf((h + 9.0) / 8.5, 0.0, 1.0) * 0.6)
	if h < 2.4:
		return sand
	var c := grass
	if h > 18.0:
		c = grass.lerp(rock, clampf((h - 18.0) / 8.0, 0.0, 0.8))
	if _near_town(x, z, 4.0):
		c = c.lerp(Color("8f8068"), 0.6)
	return c


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(EXTENT * 6.0, EXTENT * 6.0)
	sea.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.52, 0.72, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic = 0.2
	sea.material_override = m
	sea.position.y = SEA_LEVEL
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _build_buildings(visuals: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "Structures"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for b in buildings:
		var size: Vector3 = b["size"]
		var pos: Vector3 = b["pos"]
		var rot := float(b["rot"])
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		var fwd := Vector3(sin(rot), 0, cos(rot))
		cs.position = pos + Vector3(0, size.y * 0.5, 0) + fwd * float(b["zoff"])
		cs.rotation.y = rot
		body.add_child(cs)
		if visuals:
			var m := Models.prop("res://assets/city/building_%s_withoutBase.gltf" % b["model"])
			m.scale = Vector3.ONE * BUILDING_SCALE
			m.position = pos - Vector3(0, 0.1 * BUILDING_SCALE, 0)
			m.rotation.y = rot
			_far(m, 320.0)
			add_child(m)
	for p in crates:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.3, 1.15, 1.3)
		cs.shape = box
		cs.position = (p as Vector3) + Vector3(0, 0.57, 0)
		body.add_child(cs)
		if visuals:
			var m := Models.prop("res://assets/city/box_A.gltf")
			m.scale = Vector3.ONE * 6.5
			m.position = p
			m.rotation.y = fmod(p.x * 3.1, TAU)
			_far(m, 140.0)
			add_child(m)


func _far(n: Node3D, dist: float) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visibility_range_end = dist
		(m as MeshInstance3D).visibility_range_end_margin = 10.0


func _build_nature(visuals: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "Nature"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for t in trees:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45
		cyl.height = 5.0
		cs.shape = cyl
		cs.position = Vector3(t.x, t.y + 2.4, t.z)
		body.add_child(cs)
	for r in rocks:
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.15 * r.w
		cs.shape = sph
		cs.position = Vector3(r.x, r.y, r.z)
		body.add_child(cs)
	if not visuals:
		return
	var tree_meshes := [Models.first_mesh("res://assets/nature/tree_single_A.gltf"), Models.first_mesh("res://assets/nature/tree_single_B.gltf")]
	for k in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_meshes[k]
		var list: Array = []
		for i in trees.size():
			if i % 2 == k:
				list.append(trees[i])
		mm.instance_count = list.size()
		for i in list.size():
			var t: Vector4 = list[i]
			var xf := Transform3D(Basis(Vector3.UP, fmod(t.x * 1.7, TAU)).scaled(Vector3.ONE * t.w), Vector3(t.x, t.y - 0.3, t.z))
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	var rock_mesh := Models.first_mesh("res://assets/nature/rock_single_C.gltf")
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = rock_mesh
	rm.instance_count = rocks.size()
	for i in rocks.size():
		var r: Vector4 = rocks[i]
		rm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, fmod(r.z, TAU)).scaled(Vector3(r.w, r.w * 0.8, r.w)), Vector3(r.x, r.y - 0.4, r.z)))
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rm
	add_child(rmi)
