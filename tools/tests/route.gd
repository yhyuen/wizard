extends SceneTree
## Plays the slice's story the way a player would, through the same methods the buttons call:
##
##   godot --headless --script res://tools/tests/route.gd
##
## Loop 1 explores days 1–7 like a first-time player and must die at the north door on day 7.
## Loop 2 uses what loop 1 learnt: tells Wren the secret, bars the north door, reaches the Long
## Night, realises where the notes come from, keeps silent, and must reach the end of the slice.
## Fights are settled instantly (the fight bot tests them). Prints an estimate of each loop's
## playing time from the lines read, the choices made and the fights fought.

const FIGHT_SECONDS := 75.0
const LINE_SECONDS := 3.5
const CHOICE_SECONDS := 2.5

## Where the bot goes each day: one place per time of day (Morning … Night), "" to sleep.
const PLAN_1 := {
	1: ["archive", "room", "north_door", "lane", ""],
	2: ["yard", "yard", "gate", "observatory", ""],
	3: ["square", "market", "archive", "room", ""],
	4: ["market", "archive", "north_door", "room", "market"],
	5: ["yard", "gate", "mill", "lane", ""],
	6: ["yard", "archive", "observatory", "lane", ""],
	7: ["archive", "yard", "room", "room", ""],
}
const PLAN_2 := {
	1: ["archive", "room", "archive", "lane", ""],
	2: ["yard", "yard", "gate", "observatory", ""],
	3: ["archive", "market", "archive", "room", ""],
	4: ["market", "archive", "room", "lane", ""],
	5: ["yard", "archive", "mill", "lane", ""],
	6: ["yard", "archive", "observatory", "lane", ""],
	7: ["north_door", "yard", "room", "room", ""],
}
## Choices the bot prefers, in order; otherwise it leaves or carries on.
const PREFER := ["Tell Wren about the sea", "Ask Wren to read", "Watch the figure", "Ask what he's seen", "Ask about the light",
	"Study the shard", "Let them go", "Cast an Ember Bolt", "Take the yard trial", "Fight them", "Ask about the Orrery",
	"The north door", "Day four, noon", "The brass star", "Say nothing", "\"More than once.\"", "Study with Wren", "Luna: Splash",
	"Mercury: Spark", "Luna: Undertow", "Mercury: Arc Lance"]

var main
var slice
var run
var steps := 0
var loop_secs := {}
var deaths: Array = []
var failures: Array = []
var rings := {}  # loop -> the highest Ring seen at a dawn


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	_go.call_deferred()


func _go() -> void:
	slice = main.slice
	slice.fight_resolver = func(id: String) -> Dictionary:
		_add_time(FIGHT_SECONDS)
		var won: bool = id != "tide"  # loop 1 can't survive the tide; loop 2 never opens the door
		return {"won": won, "kills": _kills(id) if won else 0}
	slice.new_month()
	while steps < 4000:
		steps += 1
		if not _step():
			break
	_report()


func _add_time(s: float) -> void:
	loop_secs[run.loop()] = float(loop_secs.get(run.loop(), 0.0)) + s


## One action. Returns false when the route is over.
func _step() -> bool:
	match slice.screen:
		"dawn":
			var r: int = slice.growth.ring()
			if r > int(rings.get(run.loop(), -1)):
				rings[run.loop()] = r
				print("[route] loop %d, dawn of day %d: %s, %d wells" % [run.loop(), run.day(), slice.growth.ring_name(), slice.growth.wells()])
			slice.start_day()
		"board":
			var plan: Dictionary = PLAN_1 if run.loop() == 1 else PLAN_2
			var day_plan: Array = plan.get(run.day(), ["", "", "", "", ""])
			var where: String = day_plan[run.time()]
			if where == "":
				slice.sleep()
			else:
				slice.pick_place(where)
			_add_time(CHOICE_SECONDS)
		"scene":
			_add_time(slice.lines.size() * LINE_SECONDS * 0.5)
			if not slice.pending.is_empty():
				slice.advance()
			else:
				slice.choose(_pick(slice.opts))
				_add_time(CHOICE_SECONDS)
		"death":
			_deduce()
			print("[route] loop %d: %s with %d wells at the end" % [run.loop(), slice.growth.ring_name(), slice.growth.wells()])
			var log: Dictionary = run.mem["log"][-1]
			deaths.append({"loop": run.loop(), "day": run.day(), "cause": log["cause"], "learned": log["learned"].size()})
			print("[route] loop %d ends on day %d (%s), learned %d" % [run.loop(), run.day(), log["cause"], log["learned"].size()])
			if run.loop() >= 3:
				failures.append("the route reached a third loop")
				return false
			slice.wake()
		"end":
			print("[route] end of the slice reached at the start of loop %d" % run.loop())
			return false
		_:
			failures.append("stuck on screen " + slice.screen)
			return false
	return true


## Everything killable in a won fight (the risen get up again; Silas walks off).
func _kills(id: String) -> int:
	var enc: Dictionary = slice.encounters[id]
	var n := 0
	for wave in enc["waves"]:
		for g in wave:
			if not g["kind"] in enc.get("unkillable", []) and g["kind"] != "rival":
				n += int(g["n"])
	return n


## At each death, work out every deduction that's ready: a wrong answer first (which must teach
## nothing), then the right one (which must teach its insight).
func _deduce() -> void:
	for qid in slice.ledger:
		if not slice.deduction_ready(qid):
			continue
		var q: Dictionary = slice.ledger[qid]
		var wrong: int = (int(q["answer"]) + 1) % q["options"].size()
		if slice.deduce(qid, wrong) or run.knows(q["insight"]):
			failures.append("a wrong answer solved " + qid)
		if not slice.deduce(qid, int(q["answer"])) or not run.knows(q["insight"]):
			failures.append("the right answer did not solve " + qid)
		print("[route] loop %d: worked out %s" % [run.loop(), q["title"]])
		_add_time(20.0)


func _pick(opts: Array) -> int:
	for want in PREFER:
		for i in opts.size():
			if want in str(opts[i]["text"]):
				return i
	for i in opts.size():
		if str(opts[i]["text"]) in ["Leave", "Continue", "Get up", "Promise to come", "Just read", "Look away until it's over"]:
			return i
	return 0


func _report() -> void:
	if deaths.size() < 1 or deaths[0]["cause"] != "north_door" or int(deaths[0]["day"]) != 7:
		failures.append("loop 1 must end at the north door on day 7, got %s" % [str(deaths[0]) if deaths.size() > 0 else "no death"])
	for need in ["cipher", "wren_sea", "noon_note", "warning_read", "mourner", "risen", "died_north_door"]:
		if not run.knows(need):
			failures.append("never learned " + need)
	for need in ["the_bell", "long_night", "notes_are_ours", "kept_silence", "a_fire", "a_door", "a_notes"]:
		if not run.knows(need):
			failures.append("loop 2 never reached " + need)
	if slice.screen != "end":
		failures.append("the slice never ended (screen %s, loop %d, day %d)" % [slice.screen, run.loop(), run.day()])
	for i in deaths.size():
		if int(deaths[i]["learned"]) < 1:
			failures.append("loop %d's death taught nothing" % deaths[i]["loop"])
	for l in loop_secs:
		print("[route] loop %d: about %.1f minutes of play" % [l, loop_secs[l] / 60.0])
	print("[route] %d Ledger entries known, %d steps" % [run.known_ids().size(), steps])
	for f in failures:
		print("[route] FAIL: " + f)
	if failures.is_empty():
		print("[route] the route plays through")
	quit(1 if not failures.is_empty() else 0)
