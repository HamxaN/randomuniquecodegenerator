extends Node
## Starts the manor. With `-- --shots=<dir>` it plays itself and saves
## screenshots (CI).

var manor: Manor


func _ready() -> void:
	var shots_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	if shots_dir != "":
		Save.reset()
	manor = Manor.new()
	add_child(manor)
	if shots_dir != "":
		var s := Shots.new()
		s.main = self
		s.out_dir = shots_dir
		add_child(s)
