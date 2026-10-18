extends SceneTree
## Plays every fight in data/slice/encounters.json with the autoplay bot, headless, in the open
## world where the story starts it (the market at night, the yard, the Mill, the north door):
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/encounters.gd
##
## Each fight is started the way the game starts it (in place, with its spawns from
## data/world/map.json, and the day's growth lent to the fight) and
## must end within its time limit; a fight with "survive" must last at least that long. Fights are
## played as a fresh loop-1 Apprentice and as a "strong" wizard (4th Ring, Practice 10), and the
## Mill once more with Aldous's millrace tip. Some results are required, because the design rests
## on them (design/slice/content.md §4): a fresh Apprentice passes the yard trial, survives the
## Mill from the millrace, and does not survive the tide. The rest are printed for tuning.
##
## Success criterion 8 (runs well) is checked here too: --fixed-fps runs frames back to back, so
## the wall time between frames is what one frame of a fight costs without drawing (the rules,
## the AI, the bot and the 3D view's scripts). Its 95th percentile must stay under FRAME_BUDGET,
## half a 60 fps frame. That guards against slow-downs; the browser build runs slower than this
## native one, so the run summary also reports the frames per second players really got.

const LIMIT := 180 * 60
const FRAME_BUDGET := 8.0  # ms
## Where the wizard stands when each fight starts (a spot in data/world/map.json).
const AT := {"patrol": "market_c", "yard_trial": "yard_c", "silas_duel": "yard_c", "mill_risen": "mill_east", "tide": "north_in"}
const REQUIRE := {"yard_trial fresh": true, "mill_risen fresh+millrace": true, "tide fresh": false}

var main
var bot
var run
var cases: Array = []  # {"id", "profile", "millrace"}
var i := -1
var frames := 0
var fails: Array = []
var encounters: Dictionary
var last_us := 0
var frame_ms: Array = []  # this fight's frame times
var worst := {"p95": 0.0, "name": ""}


func _initialize() -> void:
	root.get_node("Progression").save_enabled = false
	root.get_node("Progression").reset_all()
	run = root.get_node("Run")
	run.save_enabled = false
	encounters = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/encounters.json"))["encounters"]
	for profile in ["fresh", "strong"]:
		for id in encounters:
			cases.append({"id": id, "profile": profile, "millrace": false})
	cases.insert(encounters.keys().find("mill_risen") + 1, {"id": "mill_risen", "profile": "fresh", "millrace": true})
	# -- --only tide: just that encounter's cases (for tuning).
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--only":
		cases = cases.filter(func(c): return c["id"] == args[1])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _name(c: Dictionary) -> String:
	return "%s %s%s" % [c["id"], c["profile"], "+millrace" if c["millrace"] else ""]


func _process(_dt: float) -> bool:
	if main == null or main.arena == null or main.slice == null:
		return false
	if i < 0:
		main.arena.fight_over.connect(_on_over)
		_next()
		return false
	frames += 1
	var now := Time.get_ticks_usec()
	if frames > 30 and last_us > 0:
		frame_ms.append((now - last_us) / 1000.0)
	last_us = now
	if frames > LIMIT:
		fails.append("%s did not end within %d s" % [_name(cases[i]), LIMIT / 60])
		_next()
	return false


func _on_over(won: bool) -> void:
	var c: Dictionary = cases[i]
	var t: float = main.arena.fight_time
	var a = main.arena
	print("[encounters] %-26s %s in %5.1f s, %2d kills, %d downs, %3d damage taken (max HP %d)" % [_name(c), "won " if won else "lost", t,
		a.stats["kills"], int(a.stats.get("downs", 0)), roundi(a.stats["damage_taken"]), int(a.player.max_hp)])
	frame_ms.sort()
	if not frame_ms.is_empty():
		var p95: float = frame_ms[int(frame_ms.size() * 0.95)]
		var mean: float = frame_ms.reduce(func(acc, x): return acc + x, 0.0) / frame_ms.size()
		print("[encounters] %-26s frame %.2f ms mean, %.2f ms p95, %.2f ms worst" % ["", mean, p95, frame_ms[-1]])
		if p95 > worst["p95"]:
			worst = {"p95": p95, "name": _name(c)}
	var survive := float(encounters[c["id"]].get("survive", 0.0))
	if won and survive > 0.0 and t < survive - 0.5:
		fails.append("%s was won before its %d s were up" % [_name(c), survive])
	if REQUIRE.has(_name(c)) and REQUIRE[_name(c)] != won:
		fails.append("%s must be %s" % [_name(c), "won" if REQUIRE[_name(c)] else "lost"])
	_next.call_deferred()


## Sets the Run up as a fresh loop-1 Apprentice or a strong wizard.
func _profile(p: String) -> void:
	run.new_run()
	if p == "strong":
		var g = main.slice.growth
		run.set_flag("ring1")
		run.lp["wells"] = 60
		for id in g.prog.data["spells"]:
			run.mem["known"]["model_" + id] = 1
			g.practice()[id]["level"] = 10
		run.lp["book"] = (g.prog.data["start_spellbook"] as Array).duplicate()


func _next() -> void:
	i += 1
	frames = 0
	frame_ms = []
	last_us = 0
	if i >= cases.size():
		print("[encounters] slowest fight: %s, %.2f ms per frame (p95), budget %.1f ms" % [worst["name"], worst["p95"], FRAME_BUDGET])
		if worst["p95"] > FRAME_BUDGET:
			fails.append("%s takes %.2f ms per frame (p95), over the %.1f ms budget" % [worst["name"], worst["p95"], FRAME_BUDGET])
		for f in fails:
			print("[encounters] FAIL: " + f)
		if fails.is_empty():
			print("[encounters] all fights behave")
		quit(1 if not fails.is_empty() else 0)
		return
	var c: Dictionary = cases[i]
	_profile(c["profile"])
	var enc: Dictionary = encounters[c["id"]].duplicate(true)
	if c["millrace"]:
		enc["millrace"] = true
	bot = load("res://scripts/bot.gd").new()
	var slice = main.slice
	slice.growth.end_fight()
	slice.growth.begin_fight()
	slice.world.reset_loop()
	slice.world.reset_day()
	slice.set_screen("world")
	main.enter_world(slice.world.map.spots[AT[c["id"]]])
	slice.fight_id = c["id"]
	slice.cur = {"outcomes": {"won": "pell", "lost": "pell"}}  # a harmless scene after each fight
	main.start_world_fight(enc, slice.spawns_for(c["id"]))
	main.bot = func(a): return bot.intent(a)
