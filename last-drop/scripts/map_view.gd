class_name MapView
extends Control
## The minimap (a window around you) and the full island map: terrain, towns,
## the current and next zone, the plane's path, your squad and the airdrop.
## North is up (-Z in the world).

var game
var full := false
static var _tex: ImageTexture
static var _tex_seed := -1


func _terrain_texture() -> ImageTexture:
	if _tex != null and _tex_seed == game.seed_value:
		return _tex
	var n := 160
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var ext := Island.EXTENT
	for j in n:
		for i in n:
			var x := -ext + (i + 0.5) / n * ext * 2.0
			var z := -ext + (j + 0.5) / n * ext * 2.0
			var h: float = game.island.height(x, z)
			var c: Color
			if h < -0.5:
				c = Color("2a6e8c").lerp(Color("3d8fb0"), clampf((h + 9.0) / 9.0, 0.0, 1.0))
			elif h < 2.4:
				c = Color("e3cf98")
			else:
				c = Color("6fae4a").lerp(Color("4f7d36"), clampf(h / 28.0, 0.0, 1.0))
			img.set_pixel(i, j, c)
	for b in game.island.buildings:
		var p: Vector3 = b["pos"]
		var px := int((p.x + ext) / (ext * 2.0) * n)
		var pz := int((p.z + ext) / (ext * 2.0) * n)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if px + dx >= 0 and px + dx < n and pz + dz >= 0 and pz + dz < n:
					img.set_pixel(px + dx, pz + dz, Color("8b7d6b"))
	_tex = ImageTexture.create_from_image(img)
	_tex_seed = game.seed_value
	return _tex


func _draw() -> void:
	if game == null or game.island == null:
		return
	var f: Fighter = game.rig.followed() if game.rig != null else game.local
	var ext := Island.EXTENT
	var rect: Rect2
	var world_rect: Rect2  # the part of the world shown (x, z)
	if full:
		var side := minf(size.x, size.y) * 0.9
		rect = Rect2((size - Vector2(side, side)) / 2, Vector2(side, side))
		world_rect = Rect2(-ext, -ext, ext * 2.0, ext * 2.0)
	else:
		rect = Rect2(Vector2.ZERO, size)
		var span := 220.0
		var center := Vector2(f.global_position.x, f.global_position.z) if f != null else Vector2.ZERO
		if f != null and f.state == "plane":
			span = ext * 2.0
			center = Vector2.ZERO
		world_rect = Rect2(center - Vector2(span, span) / 2, Vector2(span, span))
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0, 0, 0, 0.5))
	var tex := _terrain_texture()
	var src := Rect2((world_rect.position + Vector2(ext, ext)) / (ext * 2.0) * tex.get_width(), world_rect.size / (ext * 2.0) * tex.get_width())
	draw_texture_rect_region(tex, rect, src)
	var to_screen := func(p: Vector2) -> Vector2:
		return rect.position + (p - world_rect.position) / world_rect.size * rect.size
	var scale_k: float = rect.size.x / world_rect.size.x
	# Towns.
	if full:
		for t in game.island.towns:
			var p: Vector2 = to_screen.call(t["center"])
			var name_s := String(t["name"]).to_upper()
			var w := UI.bold().get_string_size(name_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
			draw_string_outline(UI.bold(), p + Vector2(-w / 2, 6), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.7))
			draw_string(UI.bold(), p + Vector2(-w / 2, 6), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	# Zone.
	var zs: Dictionary = game.zone_state()
	var zc: Vector2 = to_screen.call(zs["center"])
	draw_arc(zc, float(zs["radius"]) * scale_k, 0, TAU, 96, Color(0.35, 0.55, 1.0, 0.95), 3.0, true)
	var nc: Vector2 = to_screen.call(zs["next_center"])
	draw_arc(nc, float(zs["next_radius"]) * scale_k, 0, TAU, 96, Color(1, 1, 1, 0.9), 2.0, true)
	# Plane path.
	if game.clock < game.plane_duration():
		var a: Vector2 = to_screen.call(Vector2(game.plane_from.x, game.plane_from.z))
		var b: Vector2 = to_screen.call(Vector2(game.plane_to.x, game.plane_to.z))
		draw_dashed_line(a, b, Color(1, 1, 1, 0.8), 2.0, 10.0)
		var pp: Vector3 = game.plane_pos()
		draw_circle(to_screen.call(Vector2(pp.x, pp.z)), 6.0, UI.ACCENT)
	# Airdrop.
	if not game.airdrop.is_empty() and game.clock >= Match.AIRDROP_TIME:
		var ap: Vector3 = game.airdrop["pos"]
		var sp: Vector2 = to_screen.call(Vector2(ap.x, ap.z))
		draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), Color("e74c3c"))
		draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), Color.WHITE, false, 2.0)
	# Squad.
	if game.local != null:
		for m in game.squad(game.local.team):
			if not m.alive() or m.state == "plane":
				continue
			var p2: Vector2 = to_screen.call(Vector2(m.global_position.x, m.global_position.z))
			if not rect.has_point(p2):
				continue
			var col: Color = GameData.TEAM_COLORS[m.team % GameData.TEAM_COLORS.size()] if m != game.local else Color.WHITE
			if m.state == "knocked":
				col = Color("ec4a3c")
			# An arrow showing where they face.
			var fwd := Vector2(sin(m.yaw), cos(m.yaw))
			var right := Vector2(fwd.y, -fwd.x)
			var sz := 9.0 if m == game.local else 7.0
			draw_colored_polygon(PackedVector2Array([p2 + fwd * sz, p2 - fwd * sz * 0.6 + right * sz * 0.7, p2 - fwd * sz * 0.6 - right * sz * 0.7]), col)
	if not full:
		draw_rect(rect, Color(1, 1, 1, 0.35), false, 2.0)
	else:
		var hint := "Tap anywhere to close"
		var w2 := UI.bold().get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
		draw_string(UI.bold(), Vector2(size.x / 2 - w2 / 2, size.y - 20), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
