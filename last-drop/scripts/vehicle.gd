class_name Vehicle
extends CharacterBody3D
## A drivable car, truck or motorbike with seats for the squad. Arcade handling:
## it follows the ground, drifts a little and bounces off walls. The driver's
## device simulates it; everyone else follows network updates.

const KINDS := {
	"sedan": {"model": "res://assets/city/car_sedan.gltf", "scale": 4.6, "seats": 4, "speed": 27.0, "hp": 280.0, "accel": 13.0},
	"taxi": {"model": "res://assets/city/car_taxi.gltf", "scale": 4.6, "seats": 4, "speed": 27.0, "hp": 280.0, "accel": 13.0},
	"wagon": {"model": "res://assets/city/car_stationwagon.gltf", "scale": 4.6, "seats": 4, "speed": 25.0, "hp": 320.0, "accel": 12.0},
	"police": {"model": "res://assets/city/car_police.gltf", "scale": 4.6, "seats": 4, "speed": 30.0, "hp": 300.0, "accel": 14.0},
	"truck": {"model": "res://assets/vehicles/vehicle-truck-green.glb", "scale": 1.75, "seats": 4, "speed": 22.0, "hp": 480.0, "accel": 10.0},
	"bike": {"model": "res://assets/vehicles/vehicle-motorcycle.glb", "scale": 1.05, "seats": 2, "speed": 33.0, "hp": 160.0, "accel": 17.0},
}
const KIND_LIST := ["sedan", "taxi", "wagon", "police", "truck", "bike"]
const SEATS := [Vector3(-0.45, 0.35, 0.3), Vector3(0.45, 0.35, 0.3), Vector3(-0.45, 0.35, -0.9), Vector3(0.45, 0.35, -0.9)]
const BIKE_SEATS := [Vector3(0, 0.55, 0.0), Vector3(0, 0.6, -0.6)]

var game
var id := 0
var kind := "sedan"
var info: Dictionary
var hp := 300.0
var heading := 0.0
var speed := 0.0
var throttle := 0.0
var steer := 0.0
var seats: Array = []  # fighter ids, -1 when empty
var wrecked := false
var local_driver := false

var _model: Node3D
var _visual := true
var _buf: Array = []
var _crash_cd := 0.0
var _smoke: CPUParticles3D


func setup(g, vehicle_id: int, vehicle_kind: String, pos: Vector3, rot: float, visuals: bool) -> void:
	game = g
	id = vehicle_id
	kind = vehicle_kind
	info = KINDS[kind]
	hp = float(info["hp"])
	heading = rot
	name = "V%d" % id
	_visual = visuals
	seats.resize(int(info["seats"]))
	seats.fill(-1)
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(55)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == "bike":
		box.size = Vector3(0.8, 1.2, 2.3)
	else:
		box.size = Vector3(1.9, 1.5, 4.3) if kind != "truck" else Vector3(2.5, 2.2, 5.0)
	cs.shape = box
	cs.position.y = box.size.y * 0.5 + 0.15
	add_child(cs)
	position = pos + Vector3(0, 0.3, 0)
	rotation.y = heading
	if visuals:
		_model = Models.prop(String(info["model"]))
		_model.scale = Vector3.ONE * float(info["scale"])
		if kind in ["truck", "bike"]:
			_model.rotation.y = PI
		_model.position.y = 0.28 if kind not in ["truck", "bike"] else 0.0
		add_child(_model)


func driver() -> int:
	return int(seats[0]) if seats.size() > 0 else -1


func free_seat(prefer_driver: bool) -> int:
	if prefer_driver and int(seats[0]) < 0:
		return 0
	for i in seats.size():
		if int(seats[i]) < 0:
			return i
	return -1


func occupants() -> int:
	var n := 0
	for s in seats:
		if int(s) >= 0:
			n += 1
	return n


func seat_position(i: int) -> Vector3:
	var list: Array = BIKE_SEATS if kind == "bike" else SEATS
	var off: Vector3 = list[clampi(i, 0, list.size() - 1)]
	if kind == "truck":
		off *= Vector3(1.3, 1.6, 1.2)
	return global_transform * off


## Where someone getting out stands.
func exit_position(i: int) -> Vector3:
	var side := -1.0 if i % 2 == 0 else 1.0
	var p := global_transform * Vector3(side * 2.2, 0.2, -0.5 if i >= 2 else 0.6)
	if game != null and game.island != null:
		p.y = maxf(p.y, game.island.height(p.x, p.z) + 0.2)
	return p


func leave(f) -> void:
	for i in seats.size():
		if int(seats[i]) == f.id:
			seats[i] = -1


func forward() -> Vector3:
	return Vector3(sin(heading), 0, cos(heading))


## True if this device moves the vehicle (its driver is here, or nobody drives
## and we are the authority). Otherwise it follows network updates.
func controlled_here() -> bool:
	var d = game.by_id.get(driver(), null)
	if d != null:
		return d.ctl != Fighter.Ctl.REMOTE
	return game.authority


func _physics_process(delta: float) -> void:
	if game == null:
		return
	_crash_cd = maxf(0.0, _crash_cd - delta)
	if controlled_here():
		_simulate(delta)


func _simulate(delta: float) -> void:
	if wrecked:
		throttle = 0.0
		steer = 0.0
	var top := float(info["speed"])
	var has_driver := driver() >= 0 and not wrecked
	if not has_driver:
		throttle = 0.0
	var in_water := global_position.y < Island.SEA_LEVEL - 0.6
	if in_water:
		top *= 0.15
	if throttle > 0.05:
		speed = move_toward(speed, top * throttle, float(info["accel"]) * delta)
	elif throttle < -0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 30.0 * delta)
		else:
			speed = move_toward(speed, -top * 0.4 * -throttle, float(info["accel"]) * 0.7 * delta)
	else:
		speed = move_toward(speed, 0.0, 6.0 * delta)
	var turn := steer * clampf(absf(speed) / 8.0, 0.0, 1.0) * (1.9 if kind == "bike" else 1.5)
	heading -= turn * delta * signf(speed if absf(speed) > 0.1 else 1.0)
	var fwd := forward()
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y -= 22.0 * delta
	var before := speed
	move_and_slide()
	rotation.y = heading
	# Hitting something solid.
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		var n := c.get_normal()
		if other is Fighter:
			if game.authority:
				game.run_over(self, other as Fighter, absf(before))
			continue
		if n.y < 0.5 and n.dot(-fwd * signf(before)) > 0.45:
			speed = -before * 0.25
			if absf(before) > 8.0 and _crash_cd <= 0.0:
				_crash_cd = 0.6
				if game.authority:
					game.damage_vehicle(self, absf(before) * 2.2, 0)
				if _visual:
					Sfx.play_at("crash", global_position)
			break
	if in_water:
		global_position.y = maxf(global_position.y, Island.SEA_LEVEL - 1.2)


func _process(delta: float) -> void:
	if game == null:
		return
	if not game.authority and not controlled_here():
		_follow()
	if not _visual or _model == null:
		return
	# Tilt the body with the ground.
	var n: Vector3 = game.island.normal_at(global_position.x, global_position.z) if global_position.y < game.island.height(global_position.x, global_position.z) + 1.0 else Vector3.UP
	var target := Basis(Vector3.UP, heading)
	var right := target.x
	var fwd := target.z
	var pitch_a := asin(clampf(n.dot(-fwd), -0.6, 0.6))
	var roll_a := asin(clampf(n.dot(right), -0.6, 0.6))
	if kind == "bike":
		roll_a -= steer * clampf(absf(speed) / 20.0, 0.0, 1.0) * 0.35
	_model.rotation.x = lerpf(_model.rotation.x, -pitch_a, minf(1.0, delta * 8.0))
	_model.rotation.z = lerpf(_model.rotation.z, roll_a, minf(1.0, delta * 8.0))


func push_state(t: float, pos: Vector3, h: float, spd: float, health: float, seat_ids: Array) -> void:
	hp = health
	if hp <= 0.0 and not wrecked:
		_wreck_visual()
	for i in mini(seats.size(), seat_ids.size()):
		seats[i] = int(seat_ids[i])
	if local_driver:
		return
	_buf.append([t, pos, h, spd])
	while _buf.size() > 10:
		_buf.pop_front()


func _follow() -> void:
	if _buf.is_empty():
		return
	var rt: float = game.clock - Fighter.INTERP_DELAY
	var a: Array = _buf[0]
	var b: Array = _buf[_buf.size() - 1]
	for i in _buf.size() - 1:
		if float(_buf[i][0]) <= rt and float(_buf[i + 1][0]) >= rt:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var span := float(b[0]) - float(a[0])
	var k := 1.0 if span <= 0.0001 else clampf((rt - float(a[0])) / span, 0.0, 1.0)
	global_position = (a[1] as Vector3).lerp(b[1], k)
	heading = lerp_angle(float(a[2]), float(b[2]), k)
	speed = lerpf(float(a[3]), float(b[3]), k)
	rotation.y = heading


func set_wrecked() -> void:
	if wrecked:
		return
	wrecked = true
	hp = 0.0
	speed = 0.0
	_wreck_visual()


func _wreck_visual() -> void:
	wrecked = true
	if not _visual or _model == null:
		return
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = Models.material(Color(0.05, 0.05, 0.05, 0.75))
	_smoke = CPUParticles3D.new()
	_smoke.amount = 24
	_smoke.lifetime = 2.5
	_smoke.direction = Vector3.UP
	_smoke.spread = 15.0
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 3.5
	_smoke.gravity = Vector3(0, 0.6, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	_smoke.mesh = sm
	_smoke.material_override = Models.material(Color(0.12, 0.12, 0.12, 0.6))
	_smoke.position.y = 1.4
	add_child(_smoke)
