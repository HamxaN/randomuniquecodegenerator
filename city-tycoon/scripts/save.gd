extends Node
## The city on disk, plus settings. Saves every few seconds and when the app
## is closed or sent to the background.

signal changed

const PATH := "user://city.json"
const EVERY := 8.0

var city := CityState.new()
var sound := true
var vibrate := true
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
	return {"city": city.to_dict(), "sound": sound, "vibrate": vibrate}


func from_dict(d: Dictionary) -> void:
	city = CityState.new()
	city.from_dict(d.get("city", {}))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))


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


## Starts a new city (used by the play-test).
func reset() -> void:
	city = CityState.new()
	store()
