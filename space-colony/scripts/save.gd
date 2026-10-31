extends Node
## The colony on disk, plus settings. Saves every few seconds and when the app
## is closed or sent to the background, and works out what was earned while away.

signal changed

const PATH := "user://colony.json"
const EVERY := 8.0

var colony := ColonyState.new()
var sound := true
var vibrate := true
var last_seen := 0
var away := {}   # what was earned while the game was closed: {credits, ore, seconds}
var _t := 0.0


func _ready() -> void:
	load_profile()


func _process(delta: float) -> void:
	_t += delta
	if _t >= EVERY:
		_t = 0.0
		store()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		store()


func to_dict() -> Dictionary:
	return {"colony": colony.to_dict(), "sound": sound, "vibrate": vibrate,
		"last_seen": int(Time.get_unix_time_from_system())}


func from_dict(d: Dictionary) -> void:
	colony = ColonyState.new()
	colony.from_dict(d.get("colony", {}))
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
		var gone := float(int(Time.get_unix_time_from_system()) - last_seen)
		if last_seen > 0 and gone > 60.0:
			away = colony.offline(gone)


## Starts a brand-new colony (used by the play-test).
func reset() -> void:
	colony = ColonyState.new()
	away = {}
	store()
