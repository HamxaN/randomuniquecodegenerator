class_name Models
## Loading the KayKit models: troops (keeping just their own weapons), buildings
## in blue (yours) or red (the enemy's), tiles and scenery.

const WEAPONS := [
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword",
	"1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "Spellbook", "Spellbook_open", "1H_Wand",
	"2H_Staff", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
]
const LOOPS := ["Idle", "Idle_Combat", "Running_A", "Running_B", "Walking_A", "Walking_B", "Cheer", "2H_Melee_Idle",
	"Spellcasting", "Blocking", "1H_Ranged_Aiming", "2H_Ranged_Aiming"]

static var _cache := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func hex(name: String) -> String:
	return "res://assets/hex/%s.gltf" % name


static func character(model: String, keep: Array) -> Node3D:
	var root: Node3D = scene("res://assets/chars/%s.glb" % model).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		if WEAPONS.has(n) and not keep.has(n):
			(m as MeshInstance3D).visible = false
	var ap := animation_player(root)
	if ap != null:
		for anim_name in LOOPS:
			if ap.has_animation(anim_name):
				ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return root


static func animation_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() > 0 else null


## A building model; [param team] is "blue" (yours) or "red" (enemy).
static func building(kind: String, team: String) -> Node3D:
	var model: String = GameData.building(kind)["model"]
	return prop(hex("building_%s_%s" % [model, team]))


static func prop(path: String) -> Node3D:
	var root: Node3D = scene(path).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


static func first_mesh(path: String) -> Mesh:
	var root: Node3D = scene(path).instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	root.free()
	return mesh


static func bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


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
