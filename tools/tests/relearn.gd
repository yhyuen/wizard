extends SceneTree
## Relearning (design/ruins/README.md; Harold, 2026-10-15: levels don't carry over, but each loop
## relearns faster):
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/relearn.gd
##
## A bot that grinds by walking the camp (tools/tests/walker.gd: the watch's targets, meditating on
## the cot, and the night patrol in the College yard) plays three loops through the real story,
## letting each loop go at the halls' shrine on day 7. By the end of day 3, loop 3 must be back to
## loop 1's day-7 wells and Ember Bolt Practice. Fights are settled instantly (won, with every
## killable enemy killed). R2 adds the Rings, once the Warden's trial gives the 1st.

const Walker := preload("res://tools/tests/walker.gd")
const GRIND := [["use:targets>Train"], ["use:cot>Meditate"], ["use:targets>Train"], ["use:targets>Train"], ["go:yard", "sleep"]]
const LAST := [["exit:north_stair", "use:shrine>Let this loop go"], [], [], [], []]
const END_DAY := 7
const PREFER := ["Train", "Meditate", "Fight them", "Let this loop go"]
const MAX_FRAMES := 400000

var main
var slice
var run
var bot
var frames := 0
var last_key := []
var practice := {}  # loop -> {day: Ember Bolt Practice at the end of that day}
var wells := {}  # loop -> {day: wells at the end of that day}
var failures: Array = []
var done := false


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(_dt: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 3:
		slice = main.slice
		bot = Walker.new(main)
		bot.prefer = PREFER
		slice.fight_resolver = func(id: String) -> Dictionary:
			var enc: Dictionary = slice.encounters[id]
			var n := 0
			for wave in enc["waves"]:
				for g in wave:
					if not g["kind"] in enc.get("unkillable", []) and g["kind"] != "rival":
						n += int(g["n"])
			return {"won": true, "kills": n}
		slice.new_month()
	if frames < 3:
		return false
	if frames > MAX_FRAMES:
		failures.append("timed out on loop %d, day %d" % [run.loop(), run.day()])
		return _report()
	match slice.screen:
		"death":
			_measure(run.day())
			print("[relearn] loop %d ends on day %d: %s, %d wells, Ember Bolt Practice %d" % [run.loop(), run.day(),
				slice.growth.ring_name(), slice.growth.wells(), slice.growth.level("ember_bolt")])
			slice.wake()
		"world", "loading":
			if slice.screen == "loading":
				bot.tick(1.0 / 60.0)
				return false
			var key := [run.loop(), run.day(), run.time()]
			if key != last_key:
				if run.time() == 0 and run.day() > 1:
					_measure(run.day() - 1)
				if run.loop() == 3 and run.day() > 3:
					return _report()
				last_key = key
				bot.set_goals((LAST if run.day() >= END_DAY else GRIND)[run.time()])
			if bot.tick(1.0 / 60.0) == "idle":
				slice.wait()
		_:
			failures.append("stuck on screen " + slice.screen)
			return _report()
	return false


func _measure(day: int) -> void:
	var p: Dictionary = practice.get(run.loop(), {})
	p[day] = slice.growth.level("ember_bolt")
	practice[run.loop()] = p
	var w: Dictionary = wells.get(run.loop(), {})
	w[day] = slice.growth.wells()
	wells[run.loop()] = w


func _report() -> bool:
	done = true
	for st in bot.stuck:
		failures.append(st)
	for loop in [1, 2]:
		var log: Array = run.mem["log"]
		if log.size() < loop or log[loop - 1]["cause"] != "shrine" or int(log[loop - 1]["day"]) != END_DAY:
			failures.append("loop %d should end at the shrine on day %d: %s" % [loop, END_DAY, log[loop - 1] if log.size() >= loop else "it didn't end"])
	var w1: Dictionary = wells.get(1, {})
	var w3: Dictionary = wells.get(3, {})
	if w1.has(END_DAY) and w3.has(3):
		print("[relearn] wells: %d on day %d of loop 1, %d on day 3 of loop 3" % [w1[END_DAY], END_DAY, w3[3]])
		if int(w1[END_DAY]) <= 0:
			failures.append("loop 1 gained no wells to relearn")
		if w1.has(3) and int(w3[3]) <= int(w1[3]):
			failures.append("loop 3 is no quicker: %d wells by day 3, loop 1 had %d" % [w3[3], w1[3]])
		if int(w3[3]) < int(w1[END_DAY]):
			failures.append("wells come back too slowly: %d by day 3 of loop 3, %d by day %d of loop 1" % [w3[3], w1[END_DAY], END_DAY])
	else:
		failures.append("wells not measured (loop 1 days %s, loop 3 days %s)" % [w1.keys(), w3.keys()])
	var p1: Dictionary = practice.get(1, {})
	var p3: Dictionary = practice.get(3, {})
	if p1.has(END_DAY) and p3.has(3):
		print("[relearn] Ember Bolt Practice: %d on day %d of loop 1, %d on day 3 of loop 3" % [p1[END_DAY], END_DAY, p3[3]])
		if int(p3[3]) < int(p1[END_DAY]):
			failures.append("Practice relearns too slowly: %d by day 3 of loop 3, %d by day %d of loop 1" % [p3[3], p1[END_DAY], END_DAY])
	else:
		failures.append("Practice not measured (loop 1 days %s, loop 3 days %s)" % [p1.keys(), p3.keys()])
	for f in failures:
		print("[relearn] FAIL: " + f)
	if failures.is_empty():
		print("[relearn] relearning is fast enough")
	quit(1 if not failures.is_empty() else 0)
	return true
