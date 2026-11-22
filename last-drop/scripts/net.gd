extends Node
## Online play over ENet. Three roles:
##  - Dedicated server (`-- --server`): runs matches back to back, no screen.
##  - Host: a phone runs the match and plays in it; friends on the same Wi-Fi join.
##  - Client: joins a server or host, sends its own movement and actions, and
##    follows everyone else from snapshots.
## Bots fill every empty slot, so a match always has a full island.

signal status(text: String)
signal lobby_changed(info: Dictionary)
signal match_started(cfg: Dictionary)
signal match_ended
signal left(reason: String)

enum Role { NONE, DEDICATED, HOST, CLIENT }

const COUNTDOWN := 30.0
const FULL_COUNTDOWN := 8.0
const END_WAIT := 14.0

var role := Role.NONE
var headless := DisplayServer.get_name() == "headless"
var match_node  # Match
var players := {}        # peer id -> {name, skin}
var peer_actor := {}     # peer id -> fighter id in the running match
var info := {}           # last lobby info (clients)
var mode := "squad"
var bot_skill := 0.5
var state := "idle"      # server: waiting, countdown, running, ended
var timer := 0.0
var countdown := COUNTDOWN
var host_name := ""
var host_skin := "rogue"
var _enet: ENetMultiplayerPeer
var _lobby_t := 0.0


func is_server() -> bool:
	return role == Role.DEDICATED or role == Role.HOST


func online() -> bool:
	return role != Role.NONE


## Starts a server. [param dedicated] runs without a local player.
func host(port: int, dedicated: bool, match_mode: String) -> Error:
	stop()
	_enet = ENetMultiplayerPeer.new()
	var err := _enet.create_server(port, GameData.MAX_PLAYERS)
	if err != OK:
		status.emit("Couldn't open port %d (%s)" % [port, error_string(err)])
		_enet = null
		return err
	multiplayer.multiplayer_peer = _enet
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	role = Role.DEDICATED if dedicated else Role.HOST
	mode = match_mode
	state = "waiting"
	timer = 0.0
	players.clear()
	if not dedicated:
		host_name = Save.player_name
		host_skin = Save.skin
	print("Last Drop server listening on port %d (%s, %s)" % [port, mode, "dedicated" if dedicated else "host"])
	_push_lobby()
	return OK


func join(address: String, port: int) -> Error:
	stop()
	_enet = ENetMultiplayerPeer.new()
	var err := _enet.create_client(address, port)
	if err != OK:
		status.emit("Couldn't connect: %s" % error_string(err))
		_enet = null
		return err
	multiplayer.multiplayer_peer = _enet
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	role = Role.CLIENT
	status.emit("Connecting to %s..." % address)
	return OK


func stop() -> void:
	for sig in [multiplayer.peer_connected, multiplayer.peer_disconnected, multiplayer.connected_to_server,
			multiplayer.connection_failed, multiplayer.server_disconnected]:
		for c in (sig as Signal).get_connections():
			(sig as Signal).disconnect(c["callable"])
	if _enet != null:
		_enet.close()
	_enet = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	state = "idle"
	players.clear()
	peer_actor.clear()
	match_node = null


## This device's private addresses, for friends to type in.
func local_addresses() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.begins_with("192.168.") or s.begins_with("10.") or (s.begins_with("172.") and s.count(".") == 3):
			out.append(s)
	return out


# --- Server ---------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	print("peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	print("peer %d left" % id)
	players.erase(id)
	if match_node != null and peer_actor.has(id):
		# Their player keeps going as a bot.
		var f: Fighter = match_node.by_id.get(int(peer_actor[id]), null)
		if f != null and f.alive():
			f.ctl = Fighter.Ctl.BOT
			f.human = false
			f.peer = 0
			f.brain = Bot.new(f, match_node, 0.5)
			if f.state == "plane":
				f.brain.plan_drop(match_node.plane_pos(), 0.0)
	peer_actor.erase(id)
	_push_lobby()


@rpc("any_peer", "call_remote", "reliable")
func c_hello(player_name: String, skin_id: String, version: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != GameData.VERSION:
		s_error.rpc_id(id, "Server runs version %s; update the app." % GameData.VERSION)
		return
	if players.size() + (0 if role == Role.DEDICATED else 1) >= GameData.MAX_PLAYERS:
		s_error.rpc_id(id, "Server is full.")
		return
	var clean := player_name.substr(0, 16).strip_edges()
	players[id] = {"name": clean if clean != "" else "Player", "skin": skin_id}
	print("%s joined (peer %d)" % [players[id]["name"], id])
	_push_lobby()


func _process(delta: float) -> void:
	if not is_server():
		return
	match state:
		"waiting":
			if role == Role.DEDICATED and players.size() > 0:
				state = "countdown"
				timer = countdown
				_push_lobby()
		"countdown":
			timer -= delta
			if players.size() == 0 and role == Role.DEDICATED:
				state = "waiting"
				_push_lobby()
			elif players.size() + (0 if role == Role.DEDICATED else 1) >= GameData.MAX_PLAYERS and timer > FULL_COUNTDOWN:
				timer = FULL_COUNTDOWN
			if timer <= 0.0 and state == "countdown":
				start_match()
		"running":
			if match_node != null and match_node.phase == "over":
				state = "ended"
				timer = END_WAIT
		"ended":
			timer -= delta
			if timer <= 0.0:
				end_match()
	_lobby_t -= delta
	if _lobby_t <= 0.0 and state == "countdown":
		_lobby_t = 1.0
		_push_lobby()


## Host only: start now instead of waiting.
func host_start() -> void:
	if role == Role.HOST and state in ["waiting", "countdown"]:
		start_match()


func lobby_info() -> Dictionary:
	var list: Array = []
	if role == Role.HOST:
		list.append({"name": host_name, "skin": host_skin})
	for id in players:
		list.append(players[id])
	return {"state": state, "timer": timer, "mode": mode, "players": list, "max": GameData.MAX_PLAYERS,
		"dedicated": role == Role.DEDICATED}


func _push_lobby() -> void:
	var i := lobby_info()
	info = i
	if _enet != null and not players.is_empty():
		s_lobby.rpc(i)
	lobby_changed.emit(i)


func start_match() -> void:
	state = "running"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi() % 1000000
	var humans: Array = []
	if role == Role.HOST:
		humans.append({"peer": 1, "name": host_name, "skin": host_skin})
	for id in players:
		humans.append({"peer": id, "name": players[id]["name"], "skin": players[id]["skin"]})
	var roster := build_roster(humans, mode, rng)
	peer_actor.clear()
	for r in roster:
		if int(r["peer"]) > 0:
			peer_actor[int(r["peer"])] = int(r["id"])
	var base := {"seed": seed_value, "mode": mode, "roster": roster, "bot_skill": bot_skill}
	for id in players:
		var cfg := base.duplicate()
		cfg["local_id"] = peer_actor.get(id, -1)
		cfg["authority"] = false
		cfg["networked"] = true
		s_start.rpc_id(id, cfg)
	var mine := base.duplicate()
	mine["local_id"] = peer_actor.get(1, -1) if role == Role.HOST else -1
	mine["authority"] = true
	mine["networked"] = true
	mine["visuals"] = not headless
	print("match %d started: %d humans, %d total" % [seed_value, humans.size(), roster.size()])
	match_started.emit(mine)
	_push_lobby()


func end_match() -> void:
	state = "waiting"
	peer_actor.clear()
	if _enet != null and not players.is_empty():
		s_end.rpc()
	match_node = null
	match_ended.emit()
	_push_lobby()


## Puts humans into squads in join order and fills the island with bots.
static func build_roster(humans: Array, match_mode: String, rng: RandomNumberGenerator) -> Array:
	var size := GameData.SQUAD_SIZE if match_mode == "squad" else 1
	var roster: Array = []
	var names := GameData.BOT_NAMES.duplicate()
	for i in names.size():
		var j := rng.randi() % names.size()
		var t = names[i]
		names[i] = names[j]
		names[j] = t
	var next_id := 1
	var team := 0
	var slot := 0
	for h in humans:
		roster.append({"id": next_id, "name": h["name"], "skin": h["skin"], "team": team, "human": true, "peer": h["peer"]})
		next_id += 1
		slot += 1
		if slot >= size:
			slot = 0
			team += 1
	var skins := GameData.SKINS
	var bi := 0
	while roster.size() < GameData.MAX_PLAYERS:
		roster.append({"id": next_id, "name": names[bi % names.size()], "skin": skins[rng.randi() % skins.size()]["id"],
			"team": team, "human": false, "peer": 0})
		next_id += 1
		bi += 1
		slot += 1
		if slot >= size:
			slot = 0
			team += 1
	return roster


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_state(d: PackedFloat32Array) -> void:
	var f := _sender_fighter()
	if f != null:
		match_node.on_client_state(f, d)


@rpc("any_peer", "call_remote", "reliable")
func c_fire(origin: Vector3, dirs: PackedVector3Array) -> void:
	var f := _sender_fighter()
	if f != null and dirs.size() <= 12:
		match_node.client_fired(f, origin, dirs)


@rpc("any_peer", "call_remote", "reliable")
func c_action(action: String, arg) -> void:
	var f := _sender_fighter()
	if f != null:
		match_node.handle(f, action, arg)


func _sender_fighter() -> Fighter:
	if not is_server() or match_node == null:
		return null
	var id := multiplayer.get_remote_sender_id()
	if not peer_actor.has(id):
		return null
	return match_node.by_id.get(int(peer_actor[id]), null)


func broadcast_snapshot(data: PackedFloat32Array) -> void:
	if _enet != null and not players.is_empty():
		s_snap.rpc(data)


func broadcast_event(kind: String, data) -> void:
	if _enet != null and not players.is_empty():
		s_event.rpc(kind, data)


func send_event(peer: int, kind: String, data) -> void:
	if _enet != null and players.has(peer):
		s_event.rpc_id(peer, kind, data)


func broadcast_shot(fid: int, ends: Array, wcode: int, quiet: bool, except_peer: int) -> void:
	if _enet == null:
		return
	for id in players:
		if id != except_peer:
			s_shot.rpc_id(id, fid, ends, wcode, quiet)


func send_inventory(peer: int, d: Dictionary, hp: float, boost: float) -> void:
	if _enet != null and players.has(peer):
		s_inv.rpc_id(peer, d, hp, boost)


# --- Client -----------------------------------------------------------------------------

func _on_connected() -> void:
	status.emit("Connected. Joining...")
	c_hello.rpc_id(1, Save.player_name, Save.skin, GameData.VERSION)


func _on_failed() -> void:
	stop()
	status.emit("Couldn't reach the server.")
	left.emit("Couldn't reach the server.")


func _on_server_gone() -> void:
	stop()
	left.emit("The server closed the connection.")


func send_state(d: PackedFloat32Array) -> void:
	if role == Role.CLIENT and _enet != null:
		c_state.rpc_id(1, d)


func send_fire(origin: Vector3, dirs: PackedVector3Array) -> void:
	if role == Role.CLIENT and _enet != null:
		c_fire.rpc_id(1, origin, dirs)


func send_action(action: String, arg) -> void:
	if role == Role.CLIENT and _enet != null:
		c_action.rpc_id(1, action, arg)


@rpc("authority", "call_remote", "reliable")
func s_error(text: String) -> void:
	stop()
	status.emit(text)
	left.emit(text)


@rpc("authority", "call_remote", "reliable")
func s_lobby(i: Dictionary) -> void:
	info = i
	lobby_changed.emit(i)


@rpc("authority", "call_remote", "reliable")
func s_start(cfg: Dictionary) -> void:
	cfg["visuals"] = not headless
	match_started.emit(cfg)


@rpc("authority", "call_remote", "reliable")
func s_end() -> void:
	match_node = null
	match_ended.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func s_snap(data: PackedFloat32Array) -> void:
	if match_node != null:
		match_node.on_snapshot(data)


@rpc("authority", "call_remote", "reliable")
func s_event(kind: String, data) -> void:
	if match_node != null:
		match_node.on_event(kind, data)


@rpc("authority", "call_remote", "reliable")
func s_shot(fid: int, ends: Array, wcode: int, quiet: bool) -> void:
	if match_node != null:
		match_node.on_shot(fid, ends, wcode, quiet)


@rpc("authority", "call_remote", "reliable")
func s_inv(d: Dictionary, hp: float, boost: float) -> void:
	if match_node != null:
		match_node.on_inventory(d, hp, boost)
