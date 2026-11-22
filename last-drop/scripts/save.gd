extends Node
## The player's profile and settings, saved as JSON in user://.

signal changed

const PATH := "user://profile.json"

var player_name := ""
var skin := "rogue"
var owned_skins: Array = ["rogue", "knight"]
var coins := 0
var xp := 0
var matches := 0
var wins := 0
var kills := 0
var top5 := 0
var best_kills := 0
var mode := "squad"
var server := ""
var sound := true
var vibrate := true
var sensitivity := 1.0
var aim_assist := true
var quality := 1  # 0 low, 1 medium, 2 high
var tutorial_done := false


func _ready() -> void:
	load_profile()
	if player_name == "":
		player_name = "Player%03d" % (randi() % 1000)


func level() -> int:
	return GameData.level_for_xp(xp)


func owns(skin_id: String) -> bool:
	return owned_skins.has(skin_id)


func buy(skin_id: String) -> bool:
	var s := GameData.skin(skin_id)
	if owns(skin_id) or coins < int(s["price"]):
		return false
	coins -= int(s["price"])
	owned_skins.append(skin_id)
	store()
	return true


## Adds a finished match to the record. Returns {coins, xp}.
func record(place: int, match_kills: int, players: int) -> Dictionary:
	matches += 1
	kills += match_kills
	best_kills = maxi(best_kills, match_kills)
	if place == 1:
		wins += 1
	if place <= 5:
		top5 += 1
	var c := match_kills * GameData.COINS_PER_KILL
	if place - 1 < GameData.COINS_FOR_PLACE.size():
		c += int(GameData.COINS_FOR_PLACE[place - 1])
	c += 20
	var x := 120 + match_kills * 80 + maxi(0, players - place) * 15
	coins += c
	xp += x
	store()
	return {"coins": c, "xp": x}


func store() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"name": player_name, "skin": skin, "owned": owned_skins, "coins": coins, "xp": xp, "matches": matches,
		"wins": wins, "kills": kills, "top5": top5, "best_kills": best_kills, "mode": mode, "server": server,
		"sound": sound, "vibrate": vibrate, "sens": sensitivity, "assist": aim_assist, "quality": quality,
		"tutorial": tutorial_done,
	}))
	changed.emit()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	player_name = String(d.get("name", player_name))
	skin = String(d.get("skin", skin))
	owned_skins = d.get("owned", owned_skins)
	coins = int(d.get("coins", 0))
	xp = int(d.get("xp", 0))
	matches = int(d.get("matches", 0))
	wins = int(d.get("wins", 0))
	kills = int(d.get("kills", 0))
	top5 = int(d.get("top5", 0))
	best_kills = int(d.get("best_kills", 0))
	mode = String(d.get("mode", mode))
	server = String(d.get("server", ""))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	sensitivity = float(d.get("sens", 1.0))
	aim_assist = bool(d.get("assist", true))
	quality = int(d.get("quality", 1))
	tutorial_done = bool(d.get("tutorial", false))
