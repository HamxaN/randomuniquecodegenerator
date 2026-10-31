class_name Kart
extends Node3D
## One racer. Arcade handling: auto-throttle, steering, and drifting that
## charges a mini-turbo released when you let go. Rivals follow the racing
## line with their own lane, skill and item tactics.

const SLIDE := 0.32

var race: Race
var is_player := false
var display_name := ""
var color := Color.WHITE
var info: Dictionary
var top_speed := 30.0
var accel := 16.0
var grip := 2.0
var nitro := 1.0
var skill := 1.0

var speed := 0.0
var heading := 0.0
var steer := 0.0
var drift_held := false
var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var spin_time := 0.0
var shield_time := 0.0
var item := ""
var item_uses := 0
var index := 0
var lap := 0
var finished := false
var finish_time := 0.0
var lane := 0.0
var offroad := false
var _lane_t := 0.0
var _item_think := 1.0

var _model: Node3D
var _body: Node3D
var _wheels: Array[Node3D] = []
var _front: Array[Node3D] = []
var _sparks: Array[CPUParticles3D] = []
var _flame: CPUParticles3D
var _shield: MeshInstance3D
var _visual_slide := 0.0


func setup(kart_info: Dictionary, player: bool, kart_name: String, kart_color: Color) -> void:
	info = kart_info
	is_player = player
	display_name = kart_name
	color = kart_color
	top_speed = float(info["speed"])
	accel = float(info["accel"])
	grip = float(info["grip"])
	_model = Models.kit(info["model"])
	add_child(_model)
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * 1.25
	_body = _model.find_child("body", true, false) as Node3D
	for n in ["wheel-front-left", "wheel-front-right", "wheel-back-left", "wheel-back-right", "wheel-front", "wheel-back"]:
		var w := _model.find_child(n, true, false) as Node3D
		if w != null:
			_wheels.append(w)
			if n.begins_with("wheel-front"):
				_front.append(w)
	for x in [-0.6, 0.6]:
		var p := _particles(Color(0.4, 0.75, 1.0), 0.09)
		p.position = Vector3(x, 0.2, 1.4)
		_sparks.append(p)
	_flame = _particles(Color(1.0, 0.6, 0.2), 0.18)
	_flame.position = Vector3(0, 0.6, 1.7)
	_flame.direction = Vector3(0, 0.2, 1)
	_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.9
	sm.height = 3.0
	_shield.mesh = sm
	_shield.material_override = Models.material(Color(0.4, 0.8, 1.0, 0.28), 1.5, true)
	_shield.position.y = 0.8
	_shield.visible = false
	add_child(_shield)
	skill = randf_range(0.93, 1.01)
	lane = randf_range(-3.5, 3.5)


func _particles(c: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.35
	p.emitting = false
	p.direction = Vector3(0, 1, 1)
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = Models.material(c, 4.0, true)
	add_child(p)
	return p


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func progress() -> float:
	return float(lap) * race.track.samples.size() + float(index)


func step(delta: float) -> void:
	var tr := race.track
	boost_time = maxf(0.0, boost_time - delta)
	shield_time = maxf(0.0, shield_time - delta)
	_shield.visible = shield_time > 0.0
	if spin_time > 0.0:
		spin_time -= delta
		speed = move_toward(speed, 0.0, 40.0 * delta)
		_model.rotation.y += delta * 14.0
		position += forward() * speed * delta
		if spin_time <= 0.0:
			_model.rotation.y = PI
		_after_move(tr, delta)
		return
	if not is_player:
		_ai(delta)
	var gas := 1.0 if race.state == "race" and not finished else 0.0
	if finished:
		gas = 0.6
	var target := top_speed * race.speed_bonus(self)
	if boost_time > 0.0:
		target *= 1.4
	if offroad:
		target *= 0.55
	speed = move_toward(speed, target * gas, (accel if speed < target * gas else accel * 1.6) * delta)
	# Drifting: hold the drift button while turning.
	if drift_held and absf(steer) > 0.2 and speed > 12.0 and not drifting:
		drifting = true
		drift_dir = signf(steer)
		drift_charge = 0.0
	if drifting and (not drift_held or speed < 8.0):
		_release_drift()
	var turn := steer * grip * clampf(speed / 12.0, 0.35, 1.0)
	if drifting:
		turn = (drift_dir * 0.75 + steer * 0.55) * grip * 1.15
		drift_charge += delta * (1.0 + absf(steer) * 0.6)
	heading -= turn * delta
	var slide := drift_dir * SLIDE if drifting else 0.0
	_visual_slide = lerpf(_visual_slide, slide, clampf(delta * 8.0, 0, 1))
	var move_dir := forward().rotated(Vector3.UP, _visual_slide * 0.6)
	position += move_dir * speed * delta
	_after_move(tr, delta)
	# Effects.
	for w in _wheels:
		w.rotate_x(speed * delta * 2.2)
	for w in _front:
		w.rotation.y = steer * 0.45
	if _body != null:
		_body.rotation.z = lerpf(_body.rotation.z, steer * 0.08 * clampf(speed / top_speed, 0, 1), delta * 6.0)
	_model.rotation.y = PI + _visual_slide
	var charge_col := Color(0.4, 0.75, 1.0) if drift_charge < 2.0 else Color(1.0, 0.55, 0.2)
	for s in _sparks:
		s.emitting = drifting and drift_charge > 0.6
		(s.material_override as StandardMaterial3D).albedo_color = charge_col
		(s.material_override as StandardMaterial3D).emission = charge_col
	_flame.emitting = boost_time > 0.0


func _release_drift() -> void:
	drifting = false
	drift_dir = 0.0
	if drift_charge > 2.0:
		boost_time = maxf(boost_time, 1.2 * nitro)
		race.on_mini_turbo(self, true)
	elif drift_charge > 1.0:
		boost_time = maxf(boost_time, 0.6 * nitro)
		race.on_mini_turbo(self, false)
	drift_charge = 0.0


func _after_move(tr: Track, delta: float) -> void:
	var n := tr.samples.size()
	var old := index
	index = tr.nearest(position, index)
	if old > n * 0.85 and index < n * 0.15:
		lap += 1
		race.on_lap(self)
	elif old < n * 0.15 and index > n * 0.85:
		lap -= 1
	var lat := tr.lateral(position, index)
	offroad = absf(lat) > Track.WIDTH / 2 + Track.KERB
	var wall := Track.WIDTH / 2 + Track.KERB + 2.0
	if absf(lat) > wall:
		position -= tr.side(index) * (absf(lat) - wall) * signf(lat)
		speed *= 0.82
		# Turn the nose back along the track.
		var t := tr.tangents[index]
		var want := atan2(-t.x, -t.z)
		heading = lerp_angle(heading, want, clampf(delta * 6.0, 0, 1))
		if is_player:
			race.bump()
	position.y = 0.0
	rotation.y = heading


func _ai(delta: float) -> void:
	var tr := race.track
	var n := tr.samples.size()
	_lane_t -= delta
	if _lane_t <= 0.0:
		_lane_t = randf_range(2.0, 5.0)
		lane = 0.0 if is_player else clampf(lane + randf_range(-2.5, 2.5), -3.5, 3.5)
	var look := 9 + int(speed * 0.3)
	var ti := (index + look) % n
	var target := tr.samples[ti] + tr.side(ti) * lane
	var to := target - position
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - heading, -PI, PI)
	steer = clampf(-diff * 1.7, -1.0, 1.0)
	# Drift through long bends, like a player would.
	var bend := absf(wrapf(atan2(-tr.tangents[(index + 18) % n].x, -tr.tangents[(index + 18) % n].z) - atan2(-tr.tangents[index].x, -tr.tangents[index].z), -PI, PI))
	drift_held = bend > 0.55 and speed > 18.0
	_item_think -= delta
	if _item_think <= 0.0 and item != "":
		_item_think = randf_range(0.6, 1.6)
		race.ai_item(self)


func hit(duration: float) -> bool:
	if shield_time > 0.0:
		shield_time = 0.0
		return false
	spin_time = duration
	drifting = false
	drift_charge = 0.0
	return true
