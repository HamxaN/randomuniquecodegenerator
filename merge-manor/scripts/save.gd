extends Node
## The manor on disk: the board, energy, coins, stars and renovation progress,
## plus settings. Saves often, and refills energy for the time you were away.

signal changed

const PATH := "user://manor.json"
const EVERY := 6.0

var board := BoardState.new()
var sound := true
var vibrate := true
var last_seen := 0
var _t := 0.0


func _ready() -> void:
	load_profile()


func _process(delta: float) -> void:
	board.tick(delta)
	_t += delta
	if _t >= EVERY:
		_t = 0.0
		store()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		store()


func to_dict() -> Dictionary:
	return {"board": board.to_dict(), "sound": sound, "vibrate": vibrate, "last_seen": int(Time.get_unix_time_from_system())}


func from_dict(d: Dictionary) -> void:
	board = BoardState.new()
	board.from_dict(d.get("board", {}))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	last_seen = int(d.get("last_seen", 0))


func store() -> void:
	# Only the game's own profile is written to disk (not copies made by tests).
	if not is_inside_tree():
		changed.emit()
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		from_dict(parsed)
		var away := float(int(Time.get_unix_time_from_system()) - last_seen)
		if last_seen > 0 and away > 0.0:
			board.tick(minf(away, GameData.ENERGY_EVERY * GameData.MAX_ENERGY))


## Starts the manor over (used by the play-test).
func reset() -> void:
	board = BoardState.new()
	store()
