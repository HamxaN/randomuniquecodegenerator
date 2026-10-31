class_name Thumbs
## Renders small portraits of the chefs for the chef picker, using an
## off-screen SubViewport with its own little world.

static var _cache := {}


static func chef(holder: Node, model_name: String, size: int = 200) -> Texture2D:
	if _cache.has(model_name) and is_instance_valid(_cache[model_name]):
		return (_cache[model_name] as SubViewport).get_texture()
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.78, 0.75)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var model := Models.character(model_name)
	vp.add_child(model)
	model.rotation.y = 0.35
	var ap := Models.animation_player(model)
	if ap != null and ap.has_animation("Cheer"):
		ap.play("Cheer")
		ap.seek(0.5, true)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0, 1.6, 4.2)
	cam.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	_cache[model_name] = vp
	var timer := vp.get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


static func clear() -> void:
	_cache.clear()
