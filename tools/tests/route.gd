extends SceneTree
## Success criteria 5 and 6 (design/open-world/README.md §4): the story plays by walking.
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/route.gd
##
## A bot (tools/tests/walker.gd) walks the town with the clock running, talks to people where they
## are and uses things. Loop 1 explores days 1–7 like a first-time player and must die at the
## north door on day 7. Loop 2 uses what loop 1 learnt: tells Wren about the sea, bars the north
## door, reaches the Long Night, keeps silent, and must reach the end. Fights are settled
## instantly (tools/tests/encounters.gd plays them). Prints each loop's estimated playing time:
## the walking itself, plus the lines read and the choices made.

const Walker := preload("res://tools/tests/walker.gd")
const FIGHT_SECONDS := 75.0
const MAX_FRAMES := 400000

## Goals for each time of day (Morning, Noon, Afternoon, Dusk, Night); a day not listed waits
## out the day and sleeps.
const PLAN_1 := {
	1: [["use:desk", "use:bed", "talk:wren"], ["use:chalk", "use:gate_letter"], ["use:burnt_door", "use:shard"], ["talk:mira"], ["sleep"]],
	2: [["talk:examiner", "talk:silas"], ["use:dog_corner", "use:targets"], ["talk:wren"], ["talk:aldous"], ["sleep"]],
	3: [["talk:pell", "talk:porter"], ["go:market"], ["talk:old_woman", "talk:pie_seller"], ["spot:room_in"], ["sleep"]],
	4: [["talk:aldous"], ["talk:wren"], ["use:chalk", "use:gate_letter"], ["use:bed"], ["sleep"]],
	5: [["talk:examiner"], ["talk:wren"], ["go:mill"], ["spot:room_in"], ["sleep"]],
	6: [["go:yard", "go:road"], ["use:burnt_door"], ["talk:wren"], ["spot:room_in"], ["sleep"]],
	7: [["talk:wren"], ["go:yard"], ["wait"], [], []],
}
const PLAN_2 := {
	1: [["talk:wren", "use:shard"], ["use:gate_letter", "use:chalk"], ["use:bed"], ["talk:mira"], ["sleep"]],
	2: [["talk:examiner"], ["talk:wren"], [], [], ["sleep"]],
	3: [[], ["go:market"], [], ["spot:room_in"], ["sleep"]],
	4: [["talk:aldous"], ["talk:wren"], [], [], ["sleep"]],
	5: [[], [], ["go:mill"], ["spot:room_in"], ["sleep"]],
	6: [["go:yard"], ["cast:burnt_door:ember_bolt"], [], [], ["sleep"]],
	7: [["use:beam"], [], ["wait"], [], []],
}
const PREFER := ["Tell Wren about the sea", "\"More than once.\"", "Ask Wren to read", "Watch the figure", "Ask what he's seen",
	"Ask about the light", "Study the shard", "Take the yard trial", "Fight them", "Ask about the Orrery", "The north door",
	"Day four, noon", "The brass star", "Say nothing", "Study with Wren", "Luna: Splash", "Mercury: Spark", "Luna: Undertow",
	"Mercury: Arc Lance", "Train"]

var main
var slice
var run
var bot
var frames := 0
var last_key := []
var loop_secs := {}
var loop_start := 0.0
var deaths: Array = []
var failures: Array = []
var fights := 0
var done := false


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(dt: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 3:
		slice = main.slice
		bot = Walker.new(main)
		bot.prefer = PREFER
		slice.fight_resolver = func(id: String) -> Dictionary:
			fights += 1
			bot.play_s += FIGHT_SECONDS
			var won: bool = id != "tide"  # loop 1 can't survive the tide; loop 2 never opens the door
			return {"won": won, "kills": _kills(id) if won else 0}
		slice.new_month()
	if frames < 3:
		return false
	if frames > MAX_FRAMES:
		failures.append("timed out on loop %d, day %d, %s" % [run.loop(), run.day(), run.time_name()])
		return _report()
	match slice.screen:
		"death":
			_death()
			if run.loop() >= 3:
				failures.append("the route reached a third loop")
				return _report()
			slice.wake()
		"end":
			print("[route] the end of the Long Night reached in loop %d" % run.loop())
			_loop_time()
			return _report()
		"world":
			var key := [run.loop(), run.day(), run.time()]
			if key != last_key:
				last_key = key
				var plan: Dictionary = PLAN_1 if run.loop() == 1 else PLAN_2
				var day_plan: Array = plan.get(run.day(), [[], [], [], [], ["sleep"]])
				bot.set_goals(day_plan[run.time()])
				if run.time() == 0:
					print("[route] loop %d, day %d: %s, %d wells" % [run.loop(), run.day(), slice.growth.ring_name(), slice.growth.wells()])
			if bot.tick(1.0 / 60.0) == "idle":
				slice.wait()
		_:
			failures.append("stuck on screen " + slice.screen)
			return _report()
	return false


func _loop_time() -> void:
	loop_secs[run.loop()] = bot.play_s - loop_start
	loop_start = bot.play_s


func _death() -> void:
	_loop_time()
	_deduce()
	var log: Dictionary = run.mem["log"][-1]
	deaths.append({"loop": run.loop(), "day": run.day(), "cause": log["cause"], "learned": log["learned"].size()})
	print("[route] loop %d ends on day %d (%s), learned %d, %s with %d wells" % [run.loop(), run.day(), log["cause"],
		log["learned"].size(), slice.growth.ring_name(), slice.growth.wells()])


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
		bot.play_s += 20.0


func _report() -> bool:
	done = true
	if deaths.size() < 1 or deaths[0]["cause"] != "north_door" or int(deaths[0]["day"]) != 7:
		failures.append("loop 1 must end at the north door on day 7, got %s" % [str(deaths[0]) if deaths.size() > 0 else "no death"])
	for need in ["cipher", "wren_sea", "noon_note", "warning_read", "mourner", "risen", "died_north_door"]:
		if not run.knows(need):
			failures.append("never learned " + need)
	for need in ["the_bell", "long_night", "notes_are_ours", "kept_silence", "a_fire", "a_door", "a_notes"]:
		if not run.knows(need):
			failures.append("loop 2 never reached " + need)
	if slice.screen != "end":
		failures.append("the Long Night never ended (screen %s, loop %d, day %d)" % [slice.screen, run.loop(), run.day()])
	for i in deaths.size():
		if int(deaths[i]["learned"]) < 1:
			failures.append("loop %d's death taught nothing" % deaths[i]["loop"])
	for s in bot.stuck:
		failures.append(s)
	for m in bot.missed:
		print("[route] note: the time of day ran out before " + m)
	for l in loop_secs:
		print("[route] loop %d: about %.1f minutes of play" % [l, loop_secs[l] / 60.0])
	# Criterion 6: loop 1 takes 10-25 minutes; the loop that reaches the Long Night, 30 at most.
	var m1: float = float(loop_secs.get(1, 0.0)) / 60.0
	var m2: float = float(loop_secs.get(2, 0.0)) / 60.0
	if m1 < 10.0 or m1 > 25.0:
		failures.append("loop 1 takes %.1f minutes, not 10 to 25" % m1)
	if m2 > 30.0:
		failures.append("the loop that reaches the Long Night takes %.1f minutes, more than 30" % m2)
	print("[route] %d Ledger entries known, %d fights, %d frames" % [run.known_ids().size(), fights, frames])
	var summary: String = slice.run_summary()
	print("[route] run summary:\n" + summary)
	for want in ["Vellmar open world · build", "Loop 1 died on day 7", "long_night"]:
		if not want in summary:
			failures.append("the run summary has no \"%s\"" % want)
	for f in failures:
		print("[route] FAIL: " + f)
	if failures.is_empty():
		print("[route] the route plays through by walking")
	quit(1 if not failures.is_empty() else 0)
	return true
