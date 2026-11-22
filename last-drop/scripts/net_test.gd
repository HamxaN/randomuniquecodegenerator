class_name NetTest
extends Node
## CI check for online play: joins a server as a client, lets a bot brain play
## our player through the network path, and checks that snapshots, landing and
## server-side looting all work. Prints NET TEST OK and exits 0 on success.

const LIMIT := 150.0

var main
var address := "127.0.0.1"
var _t := 0.0
var _done := false
var _fired := false
var _fired_at := 0.0


func _ready() -> void:
	Net.join(address, GameData.PORT)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var m: Match = main.game()
	if m != null and m.local != null:
		var f := m.local
		# Shoot at the sky once armed, to exercise the fire path.
		if not _fired and f.state == "ground" and f.inv.has_weapon() and int(f.inv.current()["mag"]) > 0:
			_fired = f.try_fire(f.eye() + Vector3(0, 50, 1))
			_fired_at = _t
		var landed := f.state in ["ground", "knocked", "dead", "vehicle"]
		var looted := m.inventory_updates > 0
		if m.snapshots_seen > 60 and landed and looted and _fired and _t - _fired_at > 2.0:
			_finish(true, "snapshots=%d state=%s inventory_updates=%d fired=%s alive=%d" % [m.snapshots_seen, f.state,
				m.inventory_updates, str(_fired), m.alive_count()])
			return
	if _t > LIMIT:
		var detail := "no match"
		if m != null:
			detail = "snapshots=%d state=%s inventory_updates=%d" % [m.snapshots_seen, m.local.state if m.local != null else "-", m.inventory_updates]
		_finish(false, detail)


func _finish(ok: bool, detail: String) -> void:
	_done = true
	print(("NET TEST OK " if ok else "NET TEST FAILED ") + detail)
	Net.stop()
	get_tree().quit(0 if ok else 1)
