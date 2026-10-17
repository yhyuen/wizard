extends Node
## The slice's sounds (design/slice/systems.md §7), all synthesised by tools/sfx/make_sfx.py into
## assets/sfx/. play("tick") plays a one-shot from a small pool; a name played again within its
## gap is skipped, so a Bolt held down doesn't machine-gun. ambience(true) loops the night wind.

const DIR := "res://assets/sfx/"
const POOL := 8
## Shortest time between two plays of the same sound, and its volume in dB.
const GAP := {"hit": 0.07, "hurt": 0.15, "cast_fire": 0.12, "cast_earth": 0.12, "cast_storm": 0.12,
	"cast_water": 0.12, "cast_hours": 0.2, "tick": 0.03, "page": 0.05, "step": 0.2}
const DB := {"hit": -10.0, "cast_fire": -12.0, "cast_earth": -10.0, "cast_storm": -14.0, "cast_water": -12.0,
	"tick": -8.0, "page": -6.0, "step": -6.0, "night": -14.0}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var amb: AudioStreamPlayer
var last := {}  # name -> time last played
var _next := 0
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := DirAccess.open(DIR)
	if dir:
		for f in dir.get_files():
			var n := f.trim_suffix(".import")
			if n.ends_with(".wav") and not streams.has(n.get_basename()):
				var s = load(DIR + n)
				if s:
					streams[n.get_basename()] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	amb = AudioStreamPlayer.new()
	add_child(amb)
	if streams.has("night"):
		var w: AudioStreamWAV = streams["night"].duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		amb.stream = w
		amb.volume_db = DB["night"]


func play(name: String, db := 0.0) -> void:
	if muted or not streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -10.0)) < float(GAP.get(name, 0.0)):
		return
	last[name] = now
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = streams[name]
	p.volume_db = float(DB.get(name, 0.0)) + db
	p.play()


func ambience(on: bool) -> void:
	if amb.stream == null:
		return
	if on and not amb.playing and not muted:
		amb.play()
	elif not on and amb.playing:
		amb.stop()
