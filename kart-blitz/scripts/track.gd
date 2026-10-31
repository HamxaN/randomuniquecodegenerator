class_name Track
extends Node3D
## Builds a race track from its centre line: asphalt with a racing stripe,
## red-and-white kerbs, barriers, the start arch, item boxes and scenery.

const WIDTH := 13.0
const KERB := 1.1

var info: Dictionary
var samples := PackedVector3Array()
var tangents := PackedVector3Array()
var box_spots: Array[Vector3] = []
var theme := "meadow"


func build(track_info: Dictionary) -> void:
	info = track_info
	theme = info["theme"]
	samples = GameData.sample_track(info["points"], 2.0)
	var n := samples.size()
	tangents.resize(n)
	for i in n:
		tangents[i] = (samples[(i + 1) % n] - samples[(i - 1 + n) % n]).normalized()
	_environment()
	_ground()
	_road()
	_kerbs_and_barriers()
	_start_line()
	_scenery()
	for frac in [0.22, 0.5, 0.78]:
		box_spots.append(samples[int(n * frac)])


func side(i: int) -> Vector3:
	var t := tangents[i % tangents.size()]
	return Vector3(-t.z, 0, t.x)


## The closest sample to [param p], searching around [param hint].
func nearest(p: Vector3, hint: int, window: int = 40) -> int:
	var n := samples.size()
	var best := hint
	var best_d := INF
	for k in range(-window, window + 1):
		var i := (hint + k + n) % n
		var d := samples[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func lateral(p: Vector3, i: int) -> float:
	return (p - samples[i]).dot(side(i))


func _palette() -> Dictionary:
	match theme:
		"desert":
			return {"ground": Color(0.86, 0.68, 0.42), "sky_top": Color(0.35, 0.58, 0.9), "horizon": Color(0.98, 0.85, 0.65), "sun": Color(1, 0.92, 0.78), "energy": 1.1, "ambient": 0.6}
		"snow":
			return {"ground": Color(0.92, 0.95, 1.0), "sky_top": Color(0.45, 0.62, 0.86), "horizon": Color(0.88, 0.92, 1.0), "sun": Color(0.95, 0.97, 1.0), "energy": 0.95, "ambient": 0.6}
		"dusk":
			return {"ground": Color(0.32, 0.5, 0.36), "sky_top": Color(0.18, 0.15, 0.38), "horizon": Color(1.0, 0.55, 0.42), "sun": Color(1.0, 0.65, 0.5), "energy": 0.9, "ambient": 0.5}
		"lava":
			return {"ground": Color(0.3, 0.24, 0.22), "sky_top": Color(0.22, 0.12, 0.14), "horizon": Color(0.8, 0.42, 0.3), "sun": Color(1.0, 0.65, 0.45), "energy": 0.95, "ambient": 0.4}
		_:
			return {"ground": Color(0.3, 0.58, 0.26), "sky_top": Color(0.25, 0.5, 0.9), "horizon": Color(0.78, 0.88, 0.98), "sun": Color(1, 0.95, 0.85), "energy": 1.05, "ambient": 0.4}


func _environment() -> void:
	var pal := _palette()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = pal["sky_top"]
	sm.sky_horizon_color = pal["horizon"]
	sm.ground_horizon_color = (pal["ground"] as Color).darkened(0.2)
	sm.ground_bottom_color = (pal["ground"] as Color).darkened(0.5)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = pal["ambient"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = pal["horizon"]
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = pal["sun"]
	sun.light_energy = pal["energy"]
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _ground() -> void:
	var pal := _palette()
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	mi.mesh = plane
	var mat := Models.material(pal["ground"])
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = Vector3(60, -0.05, 60)
	add_child(mi)
	if theme == "lava":
		for k in 6:
			var pool := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 9.0
			cyl.bottom_radius = 9.0
			cyl.height = 0.05
			pool.mesh = cyl
			pool.material_override = Models.material(Color(1.0, 0.45, 0.1), 4.0, true)
			pool.position = _far_spot(k * 977 + 3, 30.0) + Vector3(0, -0.02, 0)
			add_child(pool)


func _ribbon(offset_a: float, offset_b: float, height: float, colors: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := samples.size()
	for i in n:
		var j := (i + 1) % n
		var a0 := samples[i] + side(i) * offset_a + Vector3(0, height, 0)
		var b0 := samples[i] + side(i) * offset_b + Vector3(0, height, 0)
		var a1 := samples[j] + side(j) * offset_a + Vector3(0, height, 0)
		var b1 := samples[j] + side(j) * offset_b + Vector3(0, height, 0)
		var c: Color = colors.call(i)
		st.set_color(c)
		st.set_normal(Vector3.UP)
		for v in [a0, b0, a1, b0, b1, a1]:
			st.add_vertex(v)
	return st.commit()


func _road() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var road := MeshInstance3D.new()
	var asphalt := Color(0.24, 0.25, 0.28) if theme != "snow" else Color(0.3, 0.32, 0.36)
	road.mesh = _ribbon(-WIDTH / 2, WIDTH / 2, 0.02, func(_i: int) -> Color: return asphalt)
	road.material_override = mat
	add_child(road)
	var stripe := MeshInstance3D.new()
	stripe.mesh = _ribbon(-0.15, 0.15, 0.03, func(i: int) -> Color: return Color(0.95, 0.95, 0.9) if (i / 3) % 2 == 0 else asphalt)
	stripe.material_override = mat
	add_child(stripe)


func _kerbs_and_barriers() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stripes := func(i: int) -> Color: return Color(0.9, 0.15, 0.15) if (i / 2) % 2 == 0 else Color(0.97, 0.97, 0.97)
	for sgn in [-1.0, 1.0]:
		var k := MeshInstance3D.new()
		k.mesh = _ribbon(sgn * WIDTH / 2, sgn * (WIDTH / 2 + KERB), 0.05, stripes)
		k.material_override = mat
		add_child(k)
	# Low striped barriers a little way outside the kerbs.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := samples.size()
	for sgn in [-1.0, 1.0]:
		var off: float = sgn * (WIDTH / 2 + KERB + 2.5)
		for i in n:
			var j := (i + 1) % n
			var a := samples[i] + side(i) * off
			var b := samples[j] + side(j) * off
			var up := Vector3(0, 0.9, 0)
			st.set_color(Color(0.95, 0.95, 0.95) if (i / 2) % 2 == 0 else Color(0.2, 0.45, 0.9))
			st.set_normal(side(i) * -sgn)
			for v in [a, a + up, b, a + up, b + up, b]:
				st.add_vertex(v)
	var bar := MeshInstance3D.new()
	bar.mesh = st.commit()
	bar.material_override = mat
	add_child(bar)


func _start_line() -> void:
	var chk := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := samples[0]
	var t := tangents[0]
	var s := side(0)
	var cells := 10
	for row in 2:
		for c in cells:
			var a := p + s * (-WIDTH / 2 + WIDTH * c / cells) + t * (row - 1) * 1.0 + Vector3(0, 0.04, 0)
			var b := a + s * (WIDTH / cells)
			var d := a + t * 1.0
			var e := b + t * 1.0
			st.set_color(Color.WHITE if (c + row) % 2 == 0 else Color(0.1, 0.1, 0.1))
			st.set_normal(Vector3.UP)
			for v in [a, b, d, b, e, d]:
				st.add_vertex(v)
	chk.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	chk.material_override = mat
	add_child(chk)
	var arch := Models.kit("track-finish")
	add_child(arch)
	arch.global_position = p
	arch.look_at(p + t, Vector3.UP)
	arch.scale = Vector3.ONE * ((WIDTH + KERB * 2 + 3.0) / 14.0)


func _far_spot(seed_value: int, min_dist: float) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in 60:
		var p := samples[rng.randi_range(0, samples.size() - 1)]
		var q := p + Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45))
		var ok := true
		for i in range(0, samples.size(), 3):
			if samples[i].distance_to(q) < min_dist:
				ok = false
				break
		if ok:
			return q
	return Vector3(-80, 0, -80)


func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(info["id"])
	var trees: Array = ["trees_A_large", "trees_B_large", "tree_single_A", "tree_single_B"]
	if theme == "desert":
		trees = ["rock_single_A", "rock_single_C", "mountain_B_grass", "rock_single_C"]
	elif theme == "lava":
		trees = ["rock_single_C", "mountain_B_grass", "rock_single_A"]
	for k in 140:
		var q := _far_spot(rng.randi(), WIDTH / 2 + 12.0)
		var node := Models.prop("res://assets/decor/%s.gltf" % trees[rng.randi() % trees.size()])
		add_child(node)
		node.position = q
		node.rotation.y = rng.randf() * TAU
		node.scale = Vector3.ONE * rng.randf_range(3.5, 6.0)
		if theme == "snow":
			for m in node.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_overlay = Models.material(Color(1, 1, 1, 0.45), 0.0, false)
	for k in 6:
		var deco := Models.kit("decoration-tents" if k % 2 == 0 else "decoration-forest")
		add_child(deco)
		deco.position = _far_spot(rng.randi(), WIDTH / 2 + 10.0)
		deco.rotation.y = rng.randf() * TAU
		deco.scale = Vector3.ONE * 1.3
	for k in 3:
		var m := Models.prop("res://assets/decor/mountain_A_grass_trees.gltf")
		add_child(m)
		m.position = _far_spot(rng.randi(), 70.0) + Vector3(0, -1, 0)
		m.scale = Vector3.ONE * rng.randf_range(16.0, 24.0)
