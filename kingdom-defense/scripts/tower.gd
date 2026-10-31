class_name Tower
extends Node3D
## A tower on a hex. Archers, catapults and mages shoot the enemy furthest down
## the road within range; mines drip gold. Higher levels grow taller and stronger.

var defense: Defense
var kind := ""
var level := 1
var cell := Vector2i.ZERO
var cooldown := 0.5
var _model: Node3D
var _ring: MeshInstance3D
var _range_ring: MeshInstance3D
var _stars: Label3D


func setup(tower_kind: String, at: Vector2i) -> void:
	kind = tower_kind
	cell = at
	position = Hex.to_world(at)
	_refresh()


func info() -> Dictionary:
	return GameData.tower(kind)


func range_now() -> float:
	return float(GameData.at(info().get("range", [0.0]), level)) if info().has("range") else 0.0


func _refresh() -> void:
	if _model != null:
		_model.queue_free()
	_model = Models.building(kind, "blue")
	add_child(_model)
	_model.scale = Vector3.ONE * (1.0 + 0.12 * float(level - 1))
	if _stars == null:
		_stars = Label3D.new()
		_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stars.font = UI.font()
		_stars.font_size = 48
		_stars.outline_size = 12
		_stars.pixel_size = 0.006
		_stars.modulate = UI.GOLD
		_stars.position = Vector3(0, 2.6, 0)
		add_child(_stars)
	_stars.text = "" if level <= 1 else "Lv %d" % level
	var tw := create_tween()
	scale = Vector3(1, 0.7, 1)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func upgrade() -> void:
	level += 1
	_refresh()


func select(on: bool) -> void:
	if on and _range_ring == null and range_now() > 0.0:
		_range_ring = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = range_now()
		cyl.bottom_radius = range_now()
		cyl.height = 0.02
		cyl.radial_segments = 48
		_range_ring.mesh = cyl
		_range_ring.material_override = Models.material(Color(1, 1, 1, 0.16), 0.0, true)
		_range_ring.position.y = 0.06
		add_child(_range_ring)
	elif not on and _range_ring != null:
		_range_ring.queue_free()
		_range_ring = null


func top() -> Vector3:
	return global_position + Vector3(0, 1.6 + 0.2 * level, 0)


func step(delta: float) -> void:
	cooldown -= delta
	if cooldown > 0.0:
		return
	var d := info()
	if kind == "mine":
		cooldown = 1.0 / float(GameData.at(d["rate"], level))
		defense.mine_income(self, int(GameData.at(d["income"], level)))
		return
	var target := defense.first_enemy(global_position, range_now(), float(d.get("min_range", 0.0)))
	if target == null:
		cooldown = 0.15
		return
	cooldown = 1.0 / float(GameData.at(d["rate"], level))
	defense.tower_fire(self, target)
