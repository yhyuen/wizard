extends SceneTree
## Plays every slice fight in data/slice/encounters.json with the autoplay bot, headless:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/encounters.gd
##
## Each fight is started the way the slice starts it (the slice lends the fight its growth) and
## must end within its time limit; a fight with "survive" must last at least that long. Fights are
## played as a fresh loop-1 Apprentice and as a "strong" wizard (4th Ring, Practice 10), and the
## Mill once more with Aldous's millrace tip. Some results are required, because the design rests
## on them (design/slice/content.md §4): a fresh Apprentice passes the yard trial, survives the
## Mill from the millrace, and does not survive the tide. The rest are printed for tuning.

const LIMIT := 180 * 60
const REQUIRE := {"yard_trial fresh": true, "mill_risen fresh+millrace": true, "tide fresh": false}

var main
var bot
var run
var cases: Array = []  # {"id", "profile", "millrace"}
var i := -1
var frames := 0
var fails: Array = []
var encounters: Dictionary


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
	if i >= cases.size():
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
	main.slice.fight_id = c["id"]
	main.slice.cur = {"outcomes": {"won": "patrol_won", "lost": "trial_lost"}}
	main.start_slice_fight(enc)
	main.bot = func(a): return bot.intent(a)
