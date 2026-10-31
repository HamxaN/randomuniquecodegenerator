class_name Models
## Loading the KayKit Space Base pieces and putting together each building.

static var _cache := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func base(piece: String) -> Node3D:
	var root: Node3D = scene("res://assets/base/%s.gltf" % piece).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


## The 3D model for a building type, about one 2x2 cell in size.
static func building(type: String) -> Node3D:
	var root := Node3D.new()
	match type:
		"solar":
			var plate := box(Vector3(1.8, 0.12, 1.8), Color(0.55, 0.57, 0.62))
			plate.position.y = 0.06
			root.add_child(plate)
			for i in 2:
				for k in 2:
					var p := base("solarpanel")
					p.position = Vector3(-0.45 + k * 0.9, 0.12, -0.42 + i * 0.84)
					root.add_child(p)
		"hq":
			root.add_child(base("basemodule_D"))
			var roof := base("roofmodule_solarpanels")
			roof.position.y = 1.0
			root.add_child(roof)
			var mast := base("lights")
			mast.position = Vector3(0.75, 1.0, -0.6)
			root.add_child(mast)
		"hab":
			root.add_child(base("basemodule_A"))
			var roof := base("roofmodule_base")
			roof.position.y = 1.0
			root.add_child(roof)
		"lab":
			root.add_child(base("basemodule_C"))
			var roof := base("roofmodule_cargo_B")
			roof.position.y = 1.0
			root.add_child(roof)
		"crystal":
			root.add_child(base("structure_tall"))
			var glow := crystal_cluster(0.9)
			glow.position.y = 0.05
			root.add_child(glow)
			var lamp := base("lights")
			lamp.position.y = 2.0
			root.add_child(lamp)
		_:
			var b := GameData.info(type)
			root.add_child(base(b.get("model", "basemodule_B")))
	return root


## A little cluster of glowing cyan crystals.
static func crystal_cluster(size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size * 1000)
	for i in 6:
		var mi := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.radial_segments = 6
		prism.rings = 1
		prism.top_radius = 0.0
		prism.bottom_radius = rng.randf_range(0.1, 0.18) * size
		prism.height = rng.randf_range(0.5, 1.0) * size
		mi.mesh = prism
		mi.material_override = material(Color(0.35, 0.95, 1.0), 1.6)
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		mi.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.4) * size + Vector3(0, prism.height / 2, 0)
		mi.rotation = Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		root.add_child(mi)
	return root


static func material(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material(color)
	return mi


static func sphere(radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = material(color, emission)
	return mi


static func first_mesh(path: String) -> Mesh:
	var root: Node3D = scene(path).instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	root.free()
	return mesh
