class_name Thumbs
## Renders small portraits of real 3D models (buildings, troops) for the shop and
## army cards, using an off-screen SubViewport with its own little world.

static var _cache := {}


## Returns a texture of [param key]'s model. The viewport lives under [param holder].
static func get_texture(holder: Node, key: String, size: int = 180) -> Texture2D:
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return (_cache[key] as SubViewport).get_texture()
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var model: Node3D
	var look := Vector3.ZERO
	var dist := 4.2
	if key.begins_with("troop:"):
		var t: Dictionary = GameData.troop(key.trim_prefix("troop:"))
		model = Models.character(t["model"], t["keep"])
		vp.add_child(model)
		var b := Models.bounds(model)
		model.scale = Vector3.ONE * (2.0 / maxf(b.end.y, 0.3))
		model.rotation.y = 0.35
		var ap := Models.animation_player(model)
		if ap != null and ap.has_animation("Idle"):
			ap.play("Idle")
		look = Vector3(0, 1.15, 0)
		dist = 4.6
	else:
		model = Models.building(key, "blue")
		vp.add_child(model)
		var b := Models.bounds(model)
		look = b.get_center()
		dist = maxf(b.size.length() * 1.9, 3.0)
		model.rotation.y = -0.4
	cam.position = look + Vector3(0, dist * 0.42, dist)
	cam.look_at(look, Vector3.UP)
	_cache[key] = vp
	# Render a few frames (so animations pose), then freeze the image.
	var timer := vp.get_tree().create_timer(0.4)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


static func clear() -> void:
	_cache.clear()
