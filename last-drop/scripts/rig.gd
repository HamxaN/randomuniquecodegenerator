class_name PlayerRig
extends Node3D
## The third-person camera: over the shoulder on foot, behind the plane, above
## your parachute, chasing your car, zoomed through a scope when aiming, and
## following a teammate or your killer after you are out.

const FOV := 72.0

var game
var cam: Camera3D
var spectating: Fighter = null
var _shake := 0.0
var _dist := 3.0
var _fov := FOV
var _smooth_pos := Vector3.ZERO
var _first := true
var _close := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.08
	cam.far = 900.0
	add_child(cam)
	cam.current = true


func followed() -> Fighter:
	var f: Fighter = game.local
	if f != null and f.alive():
		spectating = null
		return f
	if spectating == null or not spectating.alive():
		spectating = null
		var pool: Array = []
		if f != null:
			for m in game.squad(f.team):
				if m.alive():
					pool.append(m)
			if pool.is_empty() and game.by_id.has(f.last_attacker) and (game.by_id[f.last_attacker] as Fighter).alive():
				pool.append(game.by_id[f.last_attacker])
		if pool.is_empty():
			for o in game.fighters:
				if o.alive():
					pool.append(o)
		if not pool.is_empty():
			spectating = pool[0]
	return spectating if spectating != null else f


func next_spectate() -> void:
	var alive: Array = []
	for o in game.fighters:
		if o.alive() and o != game.local:
			alive.append(o)
	if alive.is_empty():
		return
	var i := alive.find(spectating)
	spectating = alive[(i + 1) % alive.size()]


func zoom() -> float:
	var f: Fighter = game.local
	if f == null or not f.aiming or f.state != "ground" or not f.inv.has_weapon():
		return 1.0
	return float(GameData.stats(f.inv.current())["zoom"])


func _process(delta: float) -> void:
	var f := followed()
	if f == null:
		return
	var want_fov := FOV
	var pos := Vector3.ZERO
	var look := Vector3.ZERO
	match f.state:
		"plane":
			var dir: Vector3 = (game.plane_to - game.plane_from).normalized()
			var p: Vector3 = game.plane_pos()
			var orbit := Basis(Vector3.UP, f.yaw) * Vector3(0, 0, -1)
			pos = p + orbit * 34.0 + Vector3(0, 12.0 - f.pitch * 20.0, 0)
			look = p + dir * 6.0
		"fall", "chute":
			var back := -f.aim_dir()
			back.y = 0.0
			back = back.normalized()
			var h := 3.5 if f.state == "fall" else 4.5
			pos = f.global_position + back * (7.0 if f.state == "fall" else 9.0) + Vector3(0, h, 0)
			look = f.global_position + Vector3(0, 1.0, 0) + f.aim_dir() * 4.0
			want_fov = 80.0
		"vehicle":
			var v: Vehicle = f.vehicle
			var center: Vector3 = v.global_position if v != null else f.global_position
			var dir2 := f.aim_dir()
			pos = center - Vector3(dir2.x, 0, dir2.z).normalized() * 9.5 + Vector3(0, 4.2 - f.pitch * 6.0, 0)
			look = center + Vector3(0, 1.4, 0) + Vector3(dir2.x, 0, dir2.z) * 6.0
			want_fov = 76.0
		_:
			var z := zoom()
			var aiming := z > 1.0
			var right := Vector3(-cos(f.yaw), 0, sin(f.yaw))
			var h2 := 1.72 if f.state != "knocked" else 0.8
			var head := f.global_position + Vector3(0, h2, 0)
			var pivot := head + right * (0.72 if not aiming else 0.3)
			# Against a wall on the right, slide the shoulder in.
			var q0 := PhysicsRayQueryParameters3D.create(head, pivot + right * 0.3, 1 | 4)
			var h0 := get_world_3d().direct_space_state.intersect_ray(q0)
			if not h0.is_empty():
				pivot = head.lerp(h0["position"], 0.4)
			var target_dist := 3.4 if not aiming else 0.2
			if f.state == "dead":
				target_dist = 5.0
			_dist = lerpf(_dist, target_dist, minf(1.0, delta * 12.0))
			var dir3 := f.aim_dir()
			var want := pivot - dir3 * _dist
			# Keep the camera out of walls.
			var q := PhysicsRayQueryParameters3D.create(pivot, want, 1 | 4)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				want = (hit["position"] as Vector3) + dir3 * 0.25
			pos = want
			_close = pos.distance_to(head) < 1.2
			look = pivot + dir3 * 10.0
			want_fov = FOV / z if aiming else FOV
	# Aiming down sights: hide your own body so it never blocks the view.
	if f == game.local and f._model != null:
		var ads := zoom() > 1.0 or (_close and f.state == "ground")
		f._model.visible = not ads and f.state != "plane" and (f.state != "vehicle" or (f.vehicle != null and f.vehicle.kind == "bike"))
	_fov = lerpf(_fov, want_fov, minf(1.0, delta * 14.0))
	cam.fov = _fov
	if _first or f.state in ["ground", "knocked"] or f.state == "dead":
		_smooth_pos = pos
		_first = false
	else:
		_smooth_pos = _smooth_pos.lerp(pos, minf(1.0, delta * 10.0))
	cam.global_position = _smooth_pos
	if _smooth_pos.distance_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		cam.rotation.z += randf_range(-1, 1) * _shake * 0.04
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.08


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Recoil: kick the aim up a little, with some sideways wander.
func kick(recoil: float) -> void:
	var f: Fighter = game.local
	if f == null:
		return
	f.pitch = clampf(f.pitch + deg_to_rad(recoil * 0.42), -1.3, 1.2)
	f.yaw += deg_to_rad(randf_range(-0.25, 0.25) * recoil)
	shake(0.06 * recoil)


## What the crosshair is on: the world point under the centre of the screen.
func aim_point() -> Vector3:
	var f: Fighter = game.local
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var to := from + dir * 600.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4)
	var ex: Array[RID] = []
	if f != null:
		ex.append(f.get_rid())
		if f.vehicle != null:
			ex.append(f.vehicle.get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var p: Vector3 = hit["position"]
	# Don't shoot the wall right next to your shoulder when the target is in front.
	if f != null and p.distance_to(f.eye()) < 1.0:
		return to
	return p


func aim_dir() -> Vector3:
	var f: Fighter = game.local
	if f == null:
		return -cam.global_basis.z
	return (aim_point() - f.eye()).normalized()


## Gentle aim help on touch screens: drift towards an enemy near the crosshair.
func assist(delta: float, firing: bool) -> void:
	var f: Fighter = game.local
	if f == null or f.state != "ground" or not f.inv.has_weapon() or not Save.aim_assist:
		return
	var best: Fighter = null
	var best_a := deg_to_rad(6.0 if f.aiming else 4.5)
	var fwd := -cam.global_basis.z
	var reach := float(GameData.stats(f.inv.current())["range"]) * 1.6
	for o in game.fighters:
		if o.team == f.team or not o.alive() or o.state in ["plane", "fall"]:
			continue
		var to: Vector3 = o.chest_pos() - cam.global_position
		if to.length() > reach:
			continue
		var a := fwd.angle_to(to)
		if a < best_a:
			best_a = a
			best = o
	if best == null:
		return
	if not game.line_of_sight(f.eye(), best.chest_pos(), f, best):
		return
	var to2: Vector3 = best.chest_pos() - f.eye()
	var want_yaw := atan2(to2.x, to2.z)
	var want_pitch := atan2(to2.y, Vector2(to2.x, to2.z).length())
	var k := (2.6 if firing else 0.9) * delta
	f.yaw = lerp_angle(f.yaw, want_yaw, clampf(k, 0.0, 1.0))
	f.pitch = lerpf(f.pitch, want_pitch, clampf(k * 0.6, 0.0, 1.0))
