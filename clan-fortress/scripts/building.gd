class_name Building
extends Node3D
## A building on a hex: its model (bigger at higher levels), scaffolding while it
## is being built, a bobbing bubble when there is something to collect, and
## health in battle.

var id := 0
var kind := ""
var level := 1
var team := "blue"
var cell := Vector2i.ZERO
var max_hp := 100.0
var hp := 100.0
var destroyed := false
var cooldown := 0.0

var _model: Node3D
var _scaffold: Node3D
var _timer: Label3D
var _bubble: Node3D
var _ring: MeshInstance3D
var _t := 0.0


func setup(data: Dictionary, p_team: String) -> void:
	id = int(data.get("id", 0))
	kind = data["type"]
	level = int(data["level"])
	team = p_team
	cell = Vector2i(int(data["q"]), int(data["r"]))
	position = Hex.to_world(cell)
	max_hp = float(GameData.at_level(GameData.building(kind)["hp"], level))
	hp = max_hp
	_rebuild_model()


func _rebuild_model() -> void:
	if _model != null:
		_model.queue_free()
	_model = Models.building(kind, team)
	add_child(_model)
	var s := 1.0 + 0.07 * float(level - 1)
	_model.scale = Vector3.ONE * s
	if team == "blue":
		rotation.y = 0.0


func is_defense() -> bool:
	return GameData.building(kind).has("defense")


func counts_for_destruction() -> bool:
	return kind != "well" and kind != "windmill"


## Shows scaffolding and a countdown while building.
func set_building(seconds_left: float) -> void:
	var busy := seconds_left > 0.0
	if busy and _scaffold == null:
		_scaffold = Models.prop(Models.hex("building_scaffolding"))
		add_child(_scaffold)
		_scaffold.scale = Vector3.ONE * 0.95
		_timer = Label3D.new()
		_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_timer.font = UI.font()
		_timer.font_size = 54
		_timer.outline_size = 14
		_timer.pixel_size = 0.006
		_timer.no_depth_test = true
		_timer.position = Vector3(0, 2.0, 0)
		add_child(_timer)
		_model.visible = level > 1
		if level > 1:
			_model.scale = Vector3.ONE * (1.0 + 0.07 * float(level - 2))
	elif not busy and _scaffold != null:
		_scaffold.queue_free()
		_scaffold = null
		_timer.queue_free()
		_timer = null
		_model.visible = true
		_rebuild_model()
		pop()
	if _timer != null:
		_timer.text = UI.time_text(seconds_left)


## Shows or hides the "tap to collect" bubble.
func set_bubble(resource: String) -> void:
	if resource == "" and _bubble != null:
		_bubble.queue_free()
		_bubble = null
	elif resource != "" and _bubble == null:
		_bubble = Node3D.new()
		add_child(_bubble)
		_bubble.position = Vector3(0, 2.1, 0)
		var disc := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.36
		sphere.height = 0.72
		disc.mesh = sphere
		disc.material_override = Models.material(Color(1, 1, 1, 0.9), 0.0, true)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bubble.add_child(disc)
		if resource == "gold":
			var coin := Sprite3D.new()
			coin.texture = load("res://assets/fx/coin.png")
			coin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			coin.pixel_size = 0.009
			coin.no_depth_test = true
			coin.render_priority = 2
			_bubble.add_child(coin)
		else:
			var lumber := Models.prop(Models.hex("resource_lumber"))
			lumber.scale = Vector3.ONE * 0.75
			lumber.position = Vector3(0, -0.08, 0.15)
			_bubble.add_child(lumber)


func select(on: bool) -> void:
	if on and _ring == null:
		_ring = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.95
		t.outer_radius = 1.08
		_ring.mesh = t
		_ring.material_override = Models.material(Color(1.0, 0.95, 0.4), 2.0, true)
		_ring.position.y = 0.06
		_ring.scale = Vector3(1, 0.3, 1)
		add_child(_ring)
		pop()
	elif not on and _ring != null:
		_ring.queue_free()
		_ring = null


func pop() -> void:
	var tw := create_tween()
	scale = Vector3(1.0, 0.75, 1.0)
	tw.tween_property(self, "scale", Vector3(1.0, 1.12, 1.0), 0.1)
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _bubble != null:
		_bubble.position.y = 2.1 + sin(_t * 3.0) * 0.12
		_bubble.rotation.y += delta * 1.5
	if _ring != null:
		_ring.rotation.y += delta


func top() -> Vector3:
	return global_position + Vector3(0, 1.3 if kind != "townhall" else 3.2, 0)


## Battle damage. Returns true when this hit destroyed it.
func take_damage(amount: float) -> bool:
	if destroyed:
		return false
	hp -= amount
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.04, 0.96, 1.04), 0.05)
	tw.tween_property(self, "scale", Vector3.ONE, 0.08)
	if hp <= 0.0:
		hp = 0.0
		destroyed = true
		_model.queue_free()
		var ruin := Models.prop(Models.hex("building_destroyed"))
		add_child(ruin)
		ruin.scale = Vector3.ONE * 0.9
		_model = ruin
		return true
	return false
