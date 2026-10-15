extends SceneTree
## Plays the whole Mill fight with the bot, headless, and checks that it runs end to end:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/fight.gd -- [--loops 2] [--seconds 300]
##
## Loop 1 is the Mars + Jupiter book. Before loop 2 the bot visits the Orrery shrine, fills the book
## with the Mercury + Luna spells slot by slot and re-picks a mutation, so two loops cast every spell
## and both Magicks. Each loop must also weave (a Resonant cast) and spend Aether.
## Exits non-zero if nothing levels, a spell is never cast, the shrine fails, or the run stalls.


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
		"meteor": Progression.knows("meteor"), "conductor": Progression.knows("conductor"),
		"elements": Progression.loadout().duplicate(), "phase_reached": a.phase, "by_spell": a.stats["by_spell"].duplicate(),
		"loop": Progression.loop(), "resonant": int(a.stats.get("resonant", 0)), "aether_spent": roundf(float(a.stats.get("aether_spent", 0.0))),
		"dulled": int(a.stats.get("dulled", 0)), "overdraws": int(a.stats.get("overdraws", 0))})
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
		if Progression.loop() == 2:
			_visit_shrine()
	if frames > limit:
		print("[fight] stalled in phase %s after %d s" % [main.arena.phase, limit / 60])
		results.append({"won": false, "stalled": true, "phase_reached": main.arena.phase})
		done += 1
		frames = 0
		main.start_fight()
	return false


var shrine_fails: Array = []


## The Orrery: put the Mercury + Luna spells in the book and flip one Ember Bolt mutation, through
## the same calls the menu makes.
func _visit_shrine() -> void:
	if not main.arena.shrine_ready():
		shrine_fails.append("the shrine was not usable at the start of the loop")
		return
	main.open_shrine()
	var book := ["spark", "splash", "arc_lance", "undertow", "storm_call", "maelstrom"]
	for i in book.size():
		main.shrine_spell(i, book[i])
	for entry in Progression.repickable("ember_bolt"):
		main.shrine_repick("ember_bolt", entry["level"], 1 - int(entry["chosen"]))
		if Progression.repickable("ember_bolt")[0]["chosen"] == entry["chosen"]:
			shrine_fails.append("re-picking a mutation at the shrine did nothing")
		break
	main.close_shrine()
	if Progression.spellbook() != book:
		shrine_fails.append("the shrine did not fill the spellbook (got %s)" % [Progression.spellbook()])
	print("[fight] shrine: now %s" % [Progression.loadout()])


func _finish() -> bool:
	var fails: Array = shrine_fails.duplicate()
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
	var expect := ["ember_bolt", "pebble", "pillar", "fling", "pyroclasm", "avalanche", "meteor"]
	if loops >= 2:
		expect += ["spark", "arc_lance", "storm_call", "splash", "undertow", "maelstrom", "conductor"]
	for id in expect:
		if not cast_ids.has(id):
			fails.append("the bot never cast " + id)
	for r in results:
		if r.has("resonant") and int(r["resonant"]) < 1:
			fails.append("loop %s never made a Resonant cast" % r.get("loop", "?"))
		if r.has("aether_spent") and float(r["aether_spent"]) < 100.0:
			fails.append("loop %s spent under 100 Aether" % r.get("loop", "?"))
	print("[fight] reached the duel: %s" % reached_duel)
	for f in fails:
		print("[fight] FAIL: " + f)
	quit(1 if not fails.is_empty() else 0)
	return true
