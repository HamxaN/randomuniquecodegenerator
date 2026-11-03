class_name RoomView
extends Node3D
## The manor room you are restoring, as a little 3D diorama: wooden floor,
## papered walls, a sunny window, and the furniture from every finished step.
## Before you start, it is dusty, dim and full of cobwebs; each step brightens it.

var room_index := 0
var camera: Camera3D
var _items: Node3D
var _walls: Array[MeshInstance3D] = []
var _floor: MeshInstance3D
var _dust: Array[Node3D] = []
var _sun: DirectionalLight3D
var _env: Environment
var _t := 0.0


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.2, 0.17, 0.22)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1.0, 0.92, 0.85)
	_env.ambient_light_energy = 0.5
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.92, 0.8)
	_sun.light_energy = 0.9
	_sun.rotation_degrees = Vector3(-50, 35, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 30.0
	add_child(_sun)
	camera = Camera3D.new()
	camera.fov = 40.0
	# The merge board covers the right of the screen, so frame the room to the left.
	camera.h_offset = 2.6
	add_child(camera)
	camera.current = true
	_items = Node3D.new()
	add_child(_items)


func _process(delta: float) -> void:
	_t += delta
	camera.position = Vector3(6.4 + sin(_t * 0.15) * 0.4, 5.6, 7.6)
	camera.look_at(Vector3(-0.2, 0.9, -0.5), Vector3.UP)


## Builds room [param index] with the first [param steps_done] steps in place.
func build(index: int, steps_done: int) -> void:
	room_index = index
	for c in get_children():
		if c != camera and c != _sun and not c is WorldEnvironment and c != _items:
			c.queue_free()
	for c in _items.get_children():
		c.queue_free()
	_walls.clear()
	_dust.clear()
	var r: Dictionary = GameData.ROOMS[mini(index, GameData.ROOMS.size() - 1)]
	# Floor boards.
	var img := Image.create(8, 64, false, Image.FORMAT_RGB8)
	var wood: Color = r["floor"]
	for y in 64:
		for x in 8:
			var plank := (x / 2 + (y / 16) % 2) % 2
			var c := wood.lightened(0.06) if plank == 0 else wood.darkened(0.05)
			if x % 2 == 1 and y % 16 == 0:
				c = wood.darkened(0.3)
			img.set_pixel(x, y, c)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.uv1_scale = Vector3(3, 3, 1)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	fm.roughness = 0.7
	_floor = MeshInstance3D.new()
	var fp := BoxMesh.new()
	fp.size = Vector3(6.2, 0.2, 6.2)
	_floor.mesh = fp
	_floor.material_override = fm
	_floor.position = Vector3(0, -0.1, 0)
	add_child(_floor)
	# Two papered walls with a skirting board.
	var paper := _wallpaper(r["wall"])
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.2, 3.6, 0.2)
	back.mesh = bm
	back.material_override = paper
	back.position = Vector3(0, 1.8, -3.1)
	add_child(back)
	_walls.append(back)
	var left := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.2, 3.6, 6.2)
	left.mesh = lm
	left.material_override = paper
	left.position = Vector3(-3.1, 1.8, 0)
	add_child(left)
	_walls.append(left)
	for skirt in [[Vector3(6.2, 0.25, 0.08), Vector3(0, 0.12, -2.98)], [Vector3(0.08, 0.25, 6.2), Vector3(-2.98, 0.12, 0)]]:
		var s := Models.box(skirt[0], Color(0.95, 0.93, 0.88))
		s.position = skirt[1]
		add_child(s)
	# A sunny window on the back wall.
	var frame := Models.box(Vector3(1.6, 1.7, 0.1), Color(0.96, 0.95, 0.9))
	frame.position = Vector3(1.8, 2.0, -2.98)
	add_child(frame)
	var glass := Models.box(Vector3(1.36, 1.46, 0.1), Color(0.75, 0.9, 1.0))
	glass.material_override = Models.material(Color(0.75, 0.9, 1.0), 1.4)
	glass.position = Vector3(1.8, 2.0, -2.95)
	add_child(glass)
	var bar := Models.box(Vector3(0.06, 1.46, 0.12), Color(0.96, 0.95, 0.9))
	bar.position = Vector3(1.8, 2.0, -2.93)
	add_child(bar)
	var sill := Models.box(Vector3(1.8, 0.08, 0.3), Color(0.96, 0.95, 0.9))
	sill.position = Vector3(1.8, 1.12, -2.85)
	add_child(sill)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(1.8, 2.0, -2.2)
	add_child(light)
	# Dust and cobwebs, cleared as the room comes back to life.
	for p in [[Vector3(-2.9, 3.2, -2.9), 0.0], [Vector3(2.9, 3.2, -2.9), PI / 2], [Vector3(-2.9, 3.2, 2.9), -PI / 2]]:
		var web := _cobweb()
		web.position = p[0]
		web.rotation.y = p[1]
		add_child(web)
		_dust.append(web)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 11 + 2
	for i in 5:
		var crate := Models.box(Vector3(0.7, 0.55, 0.6), Color(0.62, 0.48, 0.32))
		crate.position = Vector3(rng.randf_range(-2.2, 2.2), 0.28, rng.randf_range(0.6, 2.4))
		crate.rotation.y = rng.randf() * TAU
		add_child(crate)
		_dust.append(crate)
	var steps: Array = r["steps"]
	for i in mini(steps_done, steps.size()):
		_place(steps[i], false)
	_freshen(steps_done, steps.size())


func _wallpaper(base: Color) -> StandardMaterial3D:
	var img := Image.create(16, 4, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 4:
			img.set_pixel(x, y, base if (x / 4) % 2 == 0 else base.darkened(0.06))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(4, 1, 1)
	m.roughness = 0.9
	return m


func _cobweb() -> Node3D:
	var root := Node3D.new()
	var mat := Models.material(Color(1, 1, 1, 0.55), 0.0, true)
	for k in 4:
		var strand := Models.box(Vector3(0.02, 0.02, 1.2), Color.WHITE)
		strand.material_override = mat
		var a := PI / 2 * k / 3.0
		strand.position = Vector3(sin(a), -0.3 - cos(a) * 0.3, cos(a)) * 0.45
		strand.rotation = Vector3(-0.5, a, 0)
		root.add_child(strand)
	for k in 3:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.2 + k * 0.2
		t.outer_radius = t.inner_radius + 0.015
		ring.mesh = t
		ring.material_override = mat
		ring.rotation = Vector3(PI / 2, 0, PI / 4)
		ring.scale = Vector3(1, 1, 0.5)
		root.add_child(ring)
	return root


## Dust fades and the room brightens as more of it is restored.
func _freshen(done: int, total: int) -> void:
	var k := float(done) / maxf(total, 1)
	_env.ambient_light_energy = lerpf(0.32, 0.6, k)
	_sun.light_energy = lerpf(0.5, 1.0, k)
	var r: Dictionary = GameData.ROOMS[mini(room_index, GameData.ROOMS.size() - 1)]
	var dusty := (r["wall"] as Color).darkened(0.35).lerp(Color(0.5, 0.48, 0.45), 0.4)
	for w in _walls:
		w.material_overlay = Models.material(Color(dusty, (1.0 - k) * 0.6))
	for i in _dust.size():
		_dust[i].visible = float(i) / _dust.size() >= k


## Puts a finished step's furniture in the room, with a little celebration.
func place(step: Dictionary, done: int, total: int) -> void:
	_place(step, true)
	_freshen(done, total)


func _place(step: Dictionary, animate: bool) -> void:
	var m := Models.furniture(step["model"])
	m.position = step["pos"]
	m.rotation.y = float(step["rot"])
	_items.add_child(m)
	if animate:
		var target := m.position
		m.position = target + Vector3(0, 2.5, 0)
		m.scale = Vector3.ONE * 0.4
		var tw := m.create_tween().set_parallel()
		tw.tween_property(m, "position", target, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_sparkle(target + Vector3(0, 0.6, 0))


func _sparkle(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -2, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	bm.radial_segments = 6
	bm.rings = 3
	p.mesh = bm
	p.material_override = Models.material(Color(1.0, 0.88, 0.4), 3.0)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)
