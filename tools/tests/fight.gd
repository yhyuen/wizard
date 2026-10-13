extends SceneTree
## Plays the whole Mill fight with the bot, headless, and checks that it runs end to end:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/fight.gd -- [--loops 2] [--seconds 300]
##
## Exits non-zero if the fight never reaches the duel, nothing levels, or the run stalls.


var main
var bot
var frames := 0
var limit := 300 * 60
var loops := 1
var done := 0
var results: Array = []
var Progression


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--loops":
			loops = int(args[i + 1])
		elif args[i] == "--seconds":
			limit = int(args[i + 1]) * 60
	Progression = root.get_node("Progression")
	Progression.save_enabled = false
	Progression.reset_all()
	bot = load("res://scripts/bot.gd").new()  # loaded late: it needs the autoloads
	main = load("res://scenes/main.tscn").instantiate()
	main.bot = func(a): return bot.intent(a)
	root.add_child.call_deferred(main)
	_hook.call_deferred()


func _hook() -> void:
	main.arena.fight_over.connect(_on_over)


func _on_over(won: bool) -> void:
	var a = main.arena
	var levels := {}
	for id in Progression.data["spells"]:
		levels[id] = Progression.level(id)
	results.append({"won": won, "time": snappedf(a.fight_time, 0.1), "casts": a.stats["casts"],
		"taken": roundf(a.stats["damage_taken"]), "wizard": Progression.wizard_level(), "levels": levels,
		"meteor": Progression.knows("meteor"), "phase_reached": a.phase, "by_spell": a.stats["by_spell"].duplicate()})
	print("[fight] loop %d: %s" % [Progression.loop(), JSON.stringify(results[-1])])
	done += 1
	frames = 0


func _process(_dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	frames += 1
	if frames % 600 == 0:
		var a = main.arena
		print("[fight] t=%ds phase=%s foes=%d hp=%d casts=%d" % [frames / 60, a.phase, a.enemies().size(), int(a.player.hp), int(a.stats["casts"])])
	if done >= loops:
		return _finish()
	if main.mode == "ledger":
		bot.last_pebbles = 0
		Progression.next_loop()
		main.start_fight()
	if frames > limit:
		print("[fight] stalled in phase %s after %d s" % [main.arena.phase, limit / 60])
		results.append({"won": false, "stalled": true, "phase_reached": main.arena.phase})
		done += 1
		frames = 0
		main.start_fight()
	return false


func _finish() -> bool:
	var fails: Array = []
	for r in results:
		if r.get("stalled", false):
			fails.append("a loop stalled")
	var first: Dictionary = results[0]
	if first.has("levels") and int(first["levels"]["ember_bolt"]) < 3:
		fails.append("Ember Bolt never reached level 3")
	if first.has("casts") and int(first["casts"]) < 30:
		fails.append("fewer than 30 casts")
	var reached_duel := false
	for r in results:
		if r.get("won", false) or r.get("phase_reached", "") in ["duel", "won"]:
			reached_duel = true
	if Progression.p["ledger"].size() != results.filter(func(r): return not r.get("stalled", false)).size():
		fails.append("the ledger did not record every finished loop")
	var cast_ids := {}
	for r in results:
		for id in r.get("by_spell", {}):
			cast_ids[id] = true
	for id in ["ember_bolt", "pebble", "pillar", "fling", "pyroclasm", "avalanche", "meteor"]:
		if not cast_ids.has(id):
			fails.append("the bot never cast " + id)
	print("[fight] reached the duel: %s" % reached_duel)
	for f in fails:
		print("[fight] FAIL: " + f)
	quit(1 if not fails.is_empty() else 0)
	return true
