class_name MapBuilder
## Builds an arena: sky and light, hex-tiled ground, props for cover and scenery,
## and the invisible walls around the play area.

const HEX := "res://assets/hex/%s.gltf"
const GRAVE := "res://assets/grave/%s.gltf"
const TILE_SCALE := 2.6
## Hex-pack models are tiny; Halloween ones are already at character scale.
const HEX_PROP := 4.2


static func spawn_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		out.append(Vector3(x, 0, -13.0))
		out.append(Vector3(x, 0, 13.0))
	for z in [-7.0, 0.0, 7.0]:
		out.append(Vector3(-20.5, 0, z))
		out.append(Vector3(20.5, 0, z))
	return out


static func build(root: Node3D, index: int) -> void:
	var id: String = GameData.arena(index)["id"]
	_environment(root, id)
	_ground(root, id)
	_walls(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + index
	match id:
		"graveyard":
			_graveyard(root, rng)
		"village":
			_village(root, rng)
		_:
			_fortress(root, rng)


static func _environment(root: Node3D, id: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	match id:
		"graveyard":
			sm.sky_top_color = Color(0.03, 0.04, 0.1)
			sm.sky_horizon_color = Color(0.16, 0.14, 0.27)
			sm.ground_horizon_color = Color(0.1, 0.09, 0.16)
			sm.ground_bottom_color = Color(0.02, 0.02, 0.05)
			sun.light_color = Color(0.62, 0.7, 1.0)
			sun.light_energy = 0.75
			sun.rotation_degrees = Vector3(-58, -35, 0)
			env.ambient_light_color = Color(0.32, 0.36, 0.58)
			env.ambient_light_energy = 0.9
			env.fog_light_color = Color(0.13, 0.13, 0.24)
			env.fog_density = 0.016
		"village":
			sm.sky_top_color = Color(0.24, 0.47, 0.82)
			sm.sky_horizon_color = Color(0.86, 0.8, 0.68)
			sm.ground_horizon_color = Color(0.55, 0.5, 0.4)
			sm.ground_bottom_color = Color(0.2, 0.18, 0.15)
			sun.light_color = Color(1.0, 0.92, 0.8)
			sun.light_energy = 1.0
			sun.rotation_degrees = Vector3(-50, 30, 0)
			env.ambient_light_color = Color(0.5, 0.56, 0.68)
			env.ambient_light_energy = 0.45
			env.fog_light_color = Color(0.62, 0.68, 0.76)
			env.fog_density = 0.004
			env.glow_enabled = false
			env.tonemap_exposure = 0.92
		_:
			sm.sky_top_color = Color(0.2, 0.18, 0.4)
			sm.sky_horizon_color = Color(1.0, 0.56, 0.32)
			sm.ground_horizon_color = Color(0.6, 0.38, 0.28)
			sm.ground_bottom_color = Color(0.18, 0.12, 0.12)
			sun.light_color = Color(1.0, 0.7, 0.48)
			sun.light_energy = 1.0
			sun.rotation_degrees = Vector3(-38, 60, 0)
			env.ambient_light_color = Color(0.56, 0.46, 0.55)
			env.ambient_light_energy = 0.5
			env.glow_enabled = false
			env.tonemap_exposure = 0.92
			env.fog_light_color = Color(0.72, 0.5, 0.42)
			env.fog_density = 0.009
	sky.sky_material = sm
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	root.add_child(sun)


static func _ground(root: Node3D, id: String) -> void:
	var mesh := Models.first_mesh(HEX % "hex_grass")
	if mesh == null:
		return
	var mesh_copy := mesh.duplicate() as Mesh
	var mat := mesh_copy.surface_get_material(0)
	if mat is StandardMaterial3D:
		var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = true
		mesh_copy.surface_set_material(0, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh_copy
	var w := 2.0 * TILE_SCALE
	var row := 1.732 * TILE_SCALE
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tint := Color(0.86, 0.9, 0.78)
	match id:
		"graveyard":
			tint = Color(0.5, 0.58, 0.46)
		"fortress":
			tint = Color(0.78, 0.74, 0.58)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for rz in range(-9, 10):
		for rx in range(-9, 10):
			var x := rx * w + (w / 2.0 if rz % 2 != 0 else 0.0)
			var z := rz * row
			var t := Transform3D(Basis.IDENTITY.scaled(Vector3(TILE_SCALE, TILE_SCALE, TILE_SCALE)), Vector3(x, 0, z))
			xforms.append(t)
			var v := rng.randf_range(0.9, 1.06)
			colors.append(Color(tint.r * v, tint.g * v, tint.b * v))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	root.add_child(floor_body)


static func _walls(root: Node3D) -> void:
	var half: Vector2 = Arena.HALF
	var body := StaticBody3D.new()
	body.collision_layer = 1
	for spec in [
		[Vector3(0, 2, -half.y - 0.5), Vector3(half.x * 2 + 4, 4, 1)],
		[Vector3(0, 2, half.y + 0.5), Vector3(half.x * 2 + 4, 4, 1)],
		[Vector3(-half.x - 0.5, 2, 0), Vector3(1, 4, half.y * 2 + 4)],
		[Vector3(half.x + 0.5, 2, 0), Vector3(1, 4, half.y * 2 + 4)],
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		cs.shape = box
		cs.position = spec[0]
		body.add_child(cs)
	root.add_child(body)


## Places a model. Solid props get a collider (and block bullets: that's cover).
static func place(root: Node3D, path: String, pos: Vector3, rot_deg: float, scale: float, solid: bool, shrink: float = 0.8) -> Node3D:
	var node := Models.prop(path)
	root.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(rot_deg)
	node.scale = Vector3.ONE * scale
	if solid:
		# Bounds come back in the node's unscaled space; the collider is a sibling
		# with an unscaled shape, which physics handles better than scaled bodies.
		var b := Models.bounds(node)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		root.add_child(body)
		body.position = pos
		body.rotation.y = node.rotation.y
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(b.size.x * scale * shrink, 0.4), maxf(b.size.y * scale, 1.0), maxf(b.size.z * scale * shrink, 0.4))
		cs.shape = box
		cs.position = b.get_center() * scale
		body.add_child(cs)
	return node


static func _lantern(root: Node3D, pos: Vector3, color: Color, energy: float = 2.2, height: float = 2.6) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, height, 0)
	root.add_child(light)


static func _scatter(root: Node3D, rng: RandomNumberGenerator, paths: Array, count: int, scale_min: float, scale_max: float, solid: bool) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := Vector3(rng.randf_range(-Arena.HALF.x + 2, Arena.HALF.x - 2), 0, rng.randf_range(-Arena.HALF.y + 2, Arena.HALF.y - 2))
		# Keep the start area clear.
		if p.distance_to(Vector3(0, 0, 4)) < 6.0:
			continue
		place(root, paths[rng.randi() % paths.size()], p, rng.randf() * 360.0, rng.randf_range(scale_min, scale_max), solid)
		placed += 1


static func _ring_of(root: Node3D, rng: RandomNumberGenerator, paths: Array, scale_min: float, scale_max: float) -> void:
	# Scenery around the outside of the play area, so the edges look lived in.
	for i in 44:
		var a := float(i) / 44.0 * TAU
		var p := Vector3(cos(a) * (Arena.HALF.x + 5.0 + rng.randf() * 6.0), 0, sin(a) * (Arena.HALF.y + 4.0 + rng.randf() * 5.0))
		place(root, paths[rng.randi() % paths.size()], p, rng.randf() * 360.0, rng.randf_range(scale_min, scale_max), false)


static func _graveyard(root: Node3D, rng: RandomNumberGenerator) -> void:
	place(root, GRAVE % "crypt", Vector3(0, 0, -12.5), 0.0, 0.62, true)
	place(root, GRAVE % "arch_gate", Vector3(0, 0, 15.6), 0.0, 1.1, false)
	for block in [Vector2(-12, -5), Vector2(12, -5), Vector2(-12, 6), Vector2(12, 6)]:
		for row in 2:
			for col in 3:
				var kind: String = ["grave_A", "grave_B", "gravestone"][rng.randi() % 3]
				place(root, GRAVE % kind, Vector3(block.x + (col - 1) * 3.2, 0, block.y + row * 3.4), rng.randf_range(-8, 8), 1.0, true)
	for t in [Vector3(-18, 0, -10), Vector3(17, 0, -10), Vector3(-6, 0, 10), Vector3(7, 0, -6)]:
		place(root, GRAVE % "tree_dead_large", t, rng.randf() * 360.0, 1.3, true, 0.35)
	for s in [Vector3(-6, 0, -9.5), Vector3(6, 0, -9.5)]:
		place(root, GRAVE % "shrine_candles", s, 0.0, 1.2, true)
		_lantern(root, s, Color(1.0, 0.65, 0.3), 1.6, 1.6)
	place(root, GRAVE % "coffin", Vector3(-3.5, 0, -3), 90.0, 1.0, true)
	place(root, GRAVE % "coffin", Vector3(4, 0, 1.5), 20.0, 1.0, true)
	for l in [Vector3(-8.5, 0, 0.5), Vector3(8.5, 0, 0.5), Vector3(0, 0, -6), Vector3(-17, 0, 1), Vector3(17, 0, 1)]:
		place(root, GRAVE % "post_lantern", l, 0.0, 1.0, true, 0.3)
		_lantern(root, l, Color(1.0, 0.7, 0.35))
	# Fence around the yard.
	var hx: float = Arena.HALF.x + 1.2
	var hz: float = Arena.HALF.y + 1.2
	var x := -hx
	while x < hx:
		if absf(x + 2) > 3.0:
			place(root, GRAVE % "fence", Vector3(x + 2, 0, hz), 0.0, 1.0, false)
		place(root, GRAVE % "fence", Vector3(x + 2, 0, -hz), 0.0, 1.0, false)
		x += 4.0
	var z := -hz
	while z < hz:
		place(root, GRAVE % "fence", Vector3(-hx, 0, z + 2), 90.0, 1.0, false)
		place(root, GRAVE % "fence", Vector3(hx, 0, z + 2), 90.0, 1.0, false)
		z += 4.0
	_scatter(root, rng, [GRAVE % "pumpkin_orange", GRAVE % "skull", GRAVE % "bone_A", GRAVE % "ribcage", GRAVE % "gravemarker_A", GRAVE % "pumpkin_orange_jackolantern"], 34, 0.8, 1.2, false)
	for i in 5:
		var p := Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-12, 12))
		place(root, GRAVE % "pumpkin_orange_jackolantern", p, rng.randf() * 360.0, 1.0, false)
		_lantern(root, p, Color(1.0, 0.55, 0.15), 1.4, 0.8)
	_ring_of(root, rng, [GRAVE % "tree_pine_orange_large", GRAVE % "tree_dead_large", GRAVE % "tree_dead_medium"], 1.1, 1.7)


static func _village(root: Node3D, rng: RandomNumberGenerator) -> void:
	var houses := [
		["building_home_A_blue", Vector3(-15, 0, -9.5), 25.0], ["building_home_B_blue", Vector3(-6, 0, -11.5), 0.0],
		["building_blacksmith_blue", Vector3(6.5, 0, -11), -10.0], ["building_windmill_blue", Vector3(16, 0, -9.5), 200.0],
		["building_home_B_blue", Vector3(-16.5, 0, 8), 160.0], ["building_tower_A_blue", Vector3(17, 0, 9), 0.0],
		["building_home_A_blue", Vector3(-7, 0, 10.5), 180.0], ["building_destroyed", Vector3(8, 0, 10), 30.0],
	]
	for h in houses:
		place(root, HEX % h[0], h[1], h[2], HEX_PROP, true, 0.75)
	place(root, HEX % "building_well_blue", Vector3(0, 0, -2), 0.0, 3.4, true, 0.7)
	for c in [Vector3(-5, 0, -4), Vector3(5.5, 0, 4.5), Vector3(-11, 0, 1), Vector3(11, 0, -2), Vector3(-1, 0, 8.5)]:
		place(root, HEX % "crate_A_big", c, rng.randf() * 90.0, 6.0, true)
		place(root, HEX % "barrel", c + Vector3(1.4, 0, 0.6), 0.0, 6.0, true)
		place(root, HEX % "crate_long_A", c + Vector3(-0.6, 0, 1.6), rng.randf() * 90.0, 6.0, true)
	for t in [Vector3(12, 0, 3), Vector3(-13, 0, -2.5)]:
		place(root, HEX % "tent", t, rng.randf() * 360.0, 5.0, true)
	for f in [[Vector3(-3.5, 0, 4), 90.0], [Vector3(14, 0, -3), 0.0], [Vector3(-15, 0, -1), 0.0]]:
		place(root, HEX % "fence_stone_straight", f[0], f[1], HEX_PROP, true)
	place(root, HEX % "trees_A_large", Vector3(-20, 0, -1), 0.0, 3.6, true, 0.5)
	place(root, HEX % "trees_B_medium", Vector3(20, 0, 0), 0.0, 3.6, true, 0.5)
	place(root, HEX % "resource_lumber", Vector3(3, 0, -6), 15.0, 5.0, true)
	_scatter(root, rng, [HEX % "rock_single_A", HEX % "rock_single_C", HEX % "sack", HEX % "tree_single_A"], 22, 4.0, 5.5, false)
	_ring_of(root, rng, [HEX % "trees_A_large", HEX % "trees_B_medium", HEX % "tree_single_A"], 3.4, 4.6)


static func _fortress(root: Node3D, rng: RandomNumberGenerator) -> void:
	var walls := [
		[Vector3(-14, 0, -12), 0.0], [Vector3(-7, 0, -12), 0.0], [Vector3(7, 0, -12), 0.0], [Vector3(14, 0, -12), 0.0],
		[Vector3(-19, 0, -4), 90.0], [Vector3(19, 0, -4), 90.0], [Vector3(-19, 0, 6), 90.0], [Vector3(19, 0, 6), 90.0],
		[Vector3(-9, 0, -3), 0.0], [Vector3(9, 0, 3), 0.0],
	]
	for w in walls:
		place(root, HEX % "wall_straight", w[0], w[1], 3.5, true, 0.95)
	for t in [Vector3(-19, 0, -12), Vector3(19, 0, -12)]:
		place(root, HEX % "building_tower_A_blue", t, 0.0, 3.6, true, 0.7)
	place(root, HEX % "building_scaffolding", Vector3(0, 0, -12), 0.0, 3.6, true, 0.7)
	place(root, HEX % "building_destroyed", Vector3(-10, 0, 9), 40.0, HEX_PROP, true, 0.7)
	place(root, HEX % "building_destroyed", Vector3(12, 0, 9.5), -20.0, HEX_PROP, true, 0.7)
	for c in [Vector3(-3, 0, 2), Vector3(3, 0, -5), Vector3(-13, 0, 2), Vector3(13, 0, -4)]:
		place(root, HEX % "crate_A_big", c, rng.randf() * 90.0, 6.0, true)
		place(root, HEX % "crate_A_big", c + Vector3(1.2, 0, 0.3), rng.randf() * 90.0, 6.0, true)
		place(root, HEX % "barrel", c + Vector3(0.4, 0, 1.4), 0.0, 6.0, true)
	place(root, HEX % "weaponrack", Vector3(-6, 0, -9.5), 0.0, 6.5, true)
	place(root, HEX % "weaponrack", Vector3(6, 0, -9.5), 0.0, 6.5, true)
	for t in [Vector3(-14, 0, 10), Vector3(15, 0, 1)]:
		place(root, HEX % "tent", t, rng.randf() * 360.0, 5.0, true)
	_scatter(root, rng, [HEX % "rock_single_A", HEX % "rock_single_C", HEX % "sack", HEX % "resource_lumber"], 20, 4.0, 5.5, false)
	_ring_of(root, rng, [HEX % "trees_B_medium", HEX % "rock_single_C", HEX % "trees_A_large"], 3.2, 4.8)
	for p in [Vector3(-9, 0, -2), Vector3(9, 0, 2)]:
		_lantern(root, p, Color(1.0, 0.6, 0.3), 1.2, 3.0)
