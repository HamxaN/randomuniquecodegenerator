extends Node
## Sound effects: recorded CC0 samples plus a few synthesised ones (the war horn,
## stars, explosions), played through a small pool so nothing cuts out.

const FILES := {
	"click": ["toggle", 1.0, -4.0],
	"place": ["placement-a", 1.0, -2.0],
	"build": ["placement-b", 1.0, -2.0],
	"remove": ["removal-a", 1.0, -4.0],
	"rotate": ["rotate", 1.0, -6.0],
	"coin": ["coin", 1.0, -6.0],
	"break": ["break", 1.0, -3.0],
	"hurt": ["enemy_hurt", 1.0, -10.0],
	"die": ["enemy_destroy", 0.9, -8.0],
	"swing": ["enemy_attack", 1.1, -12.0],
	"bow": ["blaster", 1.6, -16.0],
	"thud": ["land", 0.8, -4.0],
	"upgrade": ["weapon_change", 0.9, -4.0],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key in FILES:
		var path := "res://assets/sfx/%s.ogg" % FILES[key][0]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	_streams["boom"] = _noise_burst(0.7, 120.0, 0.8)
	_streams["horn"] = _chirp(0.7, 180.0, 300.0, 0.5)
	_streams["star"] = _chirp(0.25, 700.0, 1400.0, 0.4)
	_streams["levelup"] = _chirp(0.45, 520.0, 1040.0, 0.4)
	_streams["deny"] = _chirp(0.2, 300.0, 180.0, 0.4)


func play(key: String, pitch: float = 1.0, volume: float = 0.0) -> void:
	if not Save.sound or not _streams.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -1000)) < 45:
		return
	_last[key] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key]
	var base_pitch := 1.0
	var base_db := 0.0
	if FILES.has(key):
		base_pitch = FILES[key][1]
		base_db = FILES[key][2]
	p.pitch_scale = base_pitch * pitch * randf_range(0.95, 1.05)
	p.volume_db = base_db + volume
	p.play()


func vibrate(ms: int = 30) -> void:
	if Save.vibrate and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = data
	return w


func _noise_burst(seconds: float, cutoff: float, gain: float) -> AudioStreamWAV:
	var n := int(seconds * 22050)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var alpha := clampf(cutoff / 22050.0 * TAU, 0.0, 1.0)
	for i in n:
		var t := float(i) / n
		low += alpha * (randf_range(-1.0, 1.0) - low)
		var thump := sin(TAU * 55.0 * i / 22050.0) * exp(-t * 9.0)
		out[i] = (low * 6.0 + thump * 0.8) * pow(1.0 - t, 2.2) * gain
	return _wav(out)


func _tone(seconds: float, freq: float, gain: float) -> AudioStreamWAV:
	var n := int(seconds * 22050)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		out[i] = sin(TAU * freq * i / 22050.0) * (1.0 - t) * gain
	return _wav(out)


func _chirp(seconds: float, f0: float, f1: float, gain: float) -> AudioStreamWAV:
	var n := int(seconds * 22050)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / 22050.0
		out[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * sin(PI * t) * gain
	return _wav(out)
