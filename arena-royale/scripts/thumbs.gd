class_name Thumbs
## Renders small 3D portraits of the cards' troops and buildings for the card
## faces, using an off-screen SubViewport with its own little world.

static var _cache := {}


static func card(holder: Node, card_id: String, size: int = 160) -> Texture2D:
	if _cache.has(card_id) and is_instance_valid(_cache[card_id]):
		return (_cache[card_id] as SubViewport).get_texture()
	var c := GameData.card(card_id)
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
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var look := Vector3(0, 1.05, 0)
	var dist := 4.2
	if card_id == "catapult":
		vp.add_child(Models.building("tower_catapult", "blue"))
		look = Vector3(0, 0.5, 0)
		dist = 3.6
	elif card_id == "minions" or card_id == "archers":
		var n := 3 if card_id == "minions" else 2
		for i in n:
			var m := Models.character(c["blue"], [])
			m.position = Vector3((i - (n - 1) / 2.0) * 0.8, 0, -absf(i - (n - 1) / 2.0) * 0.4)
			m.rotation.y = 0.3
			vp.add_child(m)
			_pose(m)
		dist = 5.0
	else:
		var model := Models.character(c["blue"], CardArt.keep(card_id))
		model.rotation.y = 0.35
		vp.add_child(model)
		_pose(model)
	cam.position = look + Vector3(0, dist * 0.32, dist)
	cam.look_at(look, Vector3.UP)
	_cache[card_id] = vp
	var timer := vp.get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


static func _pose(model: Node3D) -> void:
	var ap := Models.animation_player(model)
	if ap != null and ap.has_animation("Idle"):
		ap.play("Idle")


static func clear() -> void:
	_cache.clear()
