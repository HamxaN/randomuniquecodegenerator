class_name Models
## Loading the KayKit models: characters (without their weapons) and the
## restaurant pieces, plus a few shared helpers.

const WEAPONS := [
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword",
	"1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "Spellbook", "Spellbook_open", "1H_Wand",
	"2H_Staff", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
	"Skeleton_Blade", "Skeleton_Axe", "Skeleton_Staff", "Skeleton_Crossbow", "Skeleton_Shield_Large_A",
	"Skeleton_Shield_Small_A", "Skeleton_Shield_Large_B", "Skeleton_Shield_Small_B",
]
const LOOPS := ["Idle", "Unarmed_Idle", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B",
	"Cheer", "Sit_Chair_Idle", "Walking_D_Skeletons", "Idle_B"]

static var _cache := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func kitchen(piece: String) -> Node3D:
	return prop("res://assets/kitchen/%s.gltf" % piece)


static func character(model: String, keep: Array = []) -> Node3D:
	var root: Node3D = scene("res://assets/chars/%s.glb" % model).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		if WEAPONS.has(n) and not keep.has(n):
			(m as MeshInstance3D).visible = false
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ap := animation_player(root)
	if ap != null:
		for anim_name in LOOPS:
			if ap.has_animation(anim_name):
				ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return root


static func animation_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() > 0 else null


static func prop(path: String) -> Node3D:
	var root: Node3D = scene(path).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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


static func cylinder(radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius if top < 0.0 else top
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 20
	mi.mesh = c
	mi.material_override = material(color)
	return mi


## A burger (or part of one) built from the restaurant pieces, bottom to top.
static func burger(items: Array, scale_factor: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var y := 0.0
	var pieces := {"bun": ["food_ingredient_bun_bottom", 0.16], "patty": ["food_ingredient_burger_cooked", 0.15],
		"cheese": ["food_ingredient_cheese_slice", 0.05], "lettuce": ["food_ingredient_lettuce_slice", 0.06],
		"tomato": ["food_ingredient_tomato_slice", 0.08]}
	for item in GameData.stacked(items):
		var p: Array = pieces[item]
		var node := kitchen(p[0])
		root.add_child(node)
		node.position.y = y + (0.08 if item == "cheese" else 0.0)
		y += float(p[1])
	if items.has("bun") and items.has("patty"):
		var top := kitchen("food_ingredient_bun_top")
		root.add_child(top)
		top.position.y = y
	root.scale = Vector3.ONE * scale_factor
	return root
