class_name Models
## Loading and preparing the 3D models: KayKit characters (with their built-in
## swords and shields hidden), Kenney blasters, and the arena props.

const HIDE := [
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword",
	"1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "Spellbook", "Spellbook_open", "1H_Wand",
	"2H_Staff", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
]
const LOOPS := [
	"Idle", "Idle_Combat", "Running_A", "Running_B", "Running_C", "Walking_A", "Walking_B", "Walking_C", "Walking_Backwards",
	"Walking_D_Skeletons", "Running_Strafe_Left", "Running_Strafe_Right", "2H_Ranged_Aiming", "1H_Ranged_Aiming",
	"2H_Ranged_Shooting", "1H_Ranged_Shooting", "Unarmed_Idle", "2H_Melee_Idle", "Spellcasting", "Cheer", "Blocking",
	"Taunt_Longer", "Sit_Floor_Idle", "Lie_Idle",
]

static var _cache := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func character(model: String) -> Node3D:
	var root: Node3D = scene("res://assets/chars/%s.glb" % model).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if HIDE.has(String(m.name)):
			(m as MeshInstance3D).visible = false
	var ap := animation_player(root)
	if ap != null:
		for anim_name in LOOPS:
			if ap.has_animation(anim_name):
				ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


static func animation_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() > 0 else null


static func skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if found.size() > 0 else null


## A BoneAttachment3D following the right hand's weapon slot.
static func hand_slot(root: Node3D, left: bool = false) -> BoneAttachment3D:
	var sk := skeleton(root)
	if sk == null:
		return null
	var wanted := "handslot.l" if left else "handslot.r"
	var bone := sk.find_bone(wanted)
	if bone < 0:
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i).to_lower()
			if n.contains("hand") and n.ends_with("l" if left else "r"):
				bone = i
				break
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = sk.get_bone_name(bone)
	sk.add_child(att)
	return att


static func gun(model: String, tint: Color) -> Node3D:
	var root: Node3D = scene("res://assets/guns/%s.glb" % model).instantiate()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.55
	mat.roughness = 0.42
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# Keep the Kenney colour map but darken it towards a gunmetal finish.
		for s in mi.get_surface_override_material_count():
			var src := mi.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				var copy := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = tint.lightened(0.35)
				copy.metallic = 0.5
				copy.roughness = 0.45
				mi.set_surface_override_material(s, copy)
			else:
				mi.set_surface_override_material(s, mat)
	return root


static func gear(model: String) -> Node3D:
	return scene("res://assets/skelgear/%s.gltf" % model).instantiate()


static func prop(path: String) -> Node3D:
	var root: Node3D = scene(path).instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


## The combined bounds of every mesh under [param root], in root's space.
static func bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var xf: Transform3D
		if root.is_inside_tree():
			xf = inv * mi.global_transform
		else:
			xf = _relative(root, mi)
		var box := xf * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## The first mesh in a model, for MultiMesh ground tiles.
static func first_mesh(path: String) -> Mesh:
	var root: Node3D = scene(path).instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	root.free()
	return mesh


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
