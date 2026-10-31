class_name Thumbs
## Renders small portraits of the buildings for the build menu, using an
## off-screen SubViewport with its own little world.

static var _cache := {}


static func building(holder: Node, type: String, size: int = 160) -> Texture2D:
	if _cache.has(type) and is_instance_valid(_cache[type]):
		return (_cache[type] as SubViewport).get_texture()
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var model := Models.building(type)
	model.rotation.y = -0.5
	vp.add_child(model)
	var tall := type in ["wind", "crystal", "drill"]
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	var look := Vector3(0, 1.2 if tall else 0.55, 0)
	var dist := 6.2 if tall else 4.6
	cam.position = look + Vector3(0, dist * 0.5, dist)
	cam.look_at(look, Vector3.UP)
	_cache[type] = vp
	var timer := vp.get_tree().create_timer(0.4)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


static func clear() -> void:
	_cache.clear()
