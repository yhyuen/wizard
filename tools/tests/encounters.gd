extends SceneTree
## Plays every slice fight in data/slice/encounters.json with the autoplay bot, headless:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/encounters.gd
##
## Each fight is started the way the slice starts it and must end (won or lost) within its time
## limit; a fight with "survive" must last at least that long. Prints each result. The tide is
## meant to be near-impossible, so only the others' wins are reported, not required (M3 tunes them).

const LIMIT := 180 * 60

var main
var bot
var ids: Array = []
var i := -1
var frames := 0
var results: Array = []
var fails: Array = []
var encounters: Dictionary


func _initialize() -> void:
	root.get_node("Progression").save_enabled = false
	root.get_node("Progression").reset_all()
	root.get_node("Run").save_enabled = false
	encounters = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/encounters.json"))["encounters"]
	ids = encounters.keys()
	bot = load("res://scripts/bot.gd").new()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null or main.slice == null:
		return false
	if i < 0:
		main.arena.fight_over.connect(_on_over)
		_next()
		return false
	frames += 1
	var a = main.arena
	if main.mode == "fight":
		a.intent = bot.intent(a)
		a.mouse = a.intent.get("aim", a.mouse)
	if frames > LIMIT:
		fails.append("%s did not end within %d s" % [ids[i], LIMIT / 60])
		_next()
	return false


func _on_over(won: bool) -> void:
	var id: String = ids[i]
	var t: float = main.arena.fight_time
	results.append({"id": id, "won": won, "time": snappedf(t, 0.1), "kills": main.arena.stats["kills"]})
	print("[encounters] %s: %s in %.1f s, %d kills" % [id, "won" if won else "lost", t, main.arena.stats["kills"]])
	var survive := float(encounters[id].get("survive", 0.0))
	if won and survive > 0.0 and t < survive - 0.5:
		fails.append("%s was won before its %d s were up" % [id, survive])
	_next.call_deferred()


func _next() -> void:
	i += 1
	frames = 0
	if i >= ids.size():
		for f in fails:
			print("[encounters] FAIL: " + f)
		quit(1 if not fails.is_empty() else 0)
		return
	main.slice.fight_id = ids[i]
	main.slice.cur = {"outcomes": {"won": "patrol_won", "lost": "trial_lost"}}
	main.start_slice_fight(encounters[ids[i]].duplicate(true))
	main.bot = func(a): return bot.intent(a)
