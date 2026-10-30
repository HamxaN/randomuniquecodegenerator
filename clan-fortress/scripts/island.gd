class_name Island
## Builds the hex island both the village and the raids sit on: grass in the
## middle, a ring of hills, forest and mountains, then sea, with sun and sky.

static func build(root: Node3D, seed_value: int, enemy: bool) -> void:
	_environment(root, enemy)
	var land := Hex.disc(Hex.LAND_RADIUS)
	var sea: Array[Vector2i] = []
	for r in range(Hex.LAND_RADIUS + 1, Hex.WATER_RADIUS + 1):
		sea.append_array(Hex.ring(r))
	_tiles(root, Models.hex("hex_grass"), land, Color(0.62, 0.8, 0.46) if not enemy else Color(0.74, 0.72, 0.5))
	_tiles(root, Models.hex("hex_water"), sea, Color(0.55, 0.78, 0.92))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Scenery on the outer land rings, where nothing is built.
	var outer: Array[Vector2i] = []
	for r in range(Hex.BUILD_RADIUS + 1, Hex.LAND_RADIUS + 1):
		outer.append_array(Hex.ring(r))
	var scenery := ["trees_A_large", "trees_B_large", "trees_A_medium", "trees_B_medium", "mountain_A_grass_trees",
		"mountain_B_grass", "hills_A_trees", "hill_single_A", "rock_single_C", "tree_single_A", "tree_single_B"]
	for cell in outer:
		if rng.randf() < 0.82:
			var kind: String = scenery[rng.randi() % scenery.size()]
			if kind.begins_with("mountain") and Hex.distance(cell, Vector2i.ZERO) < Hex.LAND_RADIUS:
				kind = "trees_A_large"
			var node := Models.prop(Models.hex(kind))
			root.add_child(node)
			node.position = Hex.to_world(cell)
			node.rotation.y = rng.randi_range(0, 5) * PI / 3.0
	# A few lily pads on the water.
	for i in 10:
		var cell: Vector2i = sea[rng.randi() % sea.size()]
		var lily := Models.prop(Models.hex("waterlily_A"))
		root.add_child(lily)
		lily.position = Hex.to_world(cell) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))


static func _environment(root: Node3D, enemy: bool) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.6, 0.92) if not enemy else Color(0.42, 0.5, 0.75)
	sm.sky_horizon_color = Color(0.78, 0.9, 1.0) if not enemy else Color(0.95, 0.78, 0.66)
	sm.ground_horizon_color = Color(0.5, 0.7, 0.85)
	sm.ground_bottom_color = Color(0.2, 0.35, 0.5)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.8)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.82, 0.95)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.82) if not enemy else Color(1.0, 0.84, 0.66)
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)


static func _tiles(root: Node3D, path: String, cells: Array[Vector2i], tint: Color) -> void:
	var mesh := Models.first_mesh(path)
	if mesh == null:
		return
	var copy := mesh.duplicate() as Mesh
	for s in copy.get_surface_count():
		var mat := copy.surface_get_material(s)
		if mat is StandardMaterial3D:
			var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.vertex_color_use_as_albedo = true
			copy.surface_set_material(s, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = copy
	mm.instance_count = cells.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Hex.to_world(cells[i])))
		var v := rng.randf_range(0.93, 1.04)
		mm.set_instance_color(i, Color(tint.r * v, tint.g * v, tint.b * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
