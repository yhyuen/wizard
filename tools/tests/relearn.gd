extends SceneTree
## Success criterion 6 (design/slice/README.md §4), relearning:
##
##   godot --headless --script res://tools/tests/relearn.gd
##
## A bot that grinds (the yard trial, training, meditating and a night patrol every day) plays
## three loops through the real story, dying to the north door each time. Loop 1 must reach the
## 3rd Ring; loop 3 must regain it by day 3, in at most half the days loop 1 took. Its Ember Bolt
## Practice must also be back to loop 1's day-7 level by day 3. Fights are settled instantly
## (won, with every killable enemy killed), except the tide, which is lost.

const GRIND := ["yard", "room", "yard", "archive", "market"]  # one place per time of day
const PREFER := ["Take the yard trial", "Train", "Meditate", "Fight them"]

var main
var slice
var run
var steps := 0
var ring3_day := {}  # loop -> the day the 3rd Ring was first held
var practice := {}  # loop -> {day: Ember Bolt Practice at the end of that day}
var failures: Array = []


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
		if id == "tide":
			return {"won": false}
		var enc: Dictionary = slice.encounters[id]
		var n := 0
		for wave in enc["waves"]:
			for g in wave:
				if not g["kind"] in enc.get("unkillable", []) and g["kind"] != "rival":
					n += int(g["n"])
		return {"won": true, "kills": n}
	slice.new_month()
	while steps < 6000 and _step():
		steps += 1
	_report()


func _note() -> void:
	if slice.growth.ring() >= 3 and not ring3_day.has(run.loop()):
		ring3_day[run.loop()] = run.day()
		print("[relearn] loop %d: the 3rd Ring on day %d (%d wells)" % [run.loop(), run.day(), slice.growth.wells()])


func _step() -> bool:
	_note()
	match slice.screen:
		"dawn":
			if run.day() > 1:
				var p: Dictionary = practice.get(run.loop(), {})
				p[run.day() - 1] = slice.growth.level("ember_bolt")
				practice[run.loop()] = p
			if run.loop() == 3 and run.day() > 3:
				return false
			slice.start_day()
		"board":
			slice.pick_place(GRIND[run.time()])
		"scene":
			if not slice.pending.is_empty():
				slice.advance()
			else:
				slice.choose(_pick(slice.opts))
		"death":
			var p: Dictionary = practice.get(run.loop(), {})
			p[run.day()] = slice.growth.level("ember_bolt")
			practice[run.loop()] = p
			print("[relearn] loop %d ends on day %d: %s, %d wells, Ember Bolt Practice %d" % [run.loop(), run.day(),
				slice.growth.ring_name(), slice.growth.wells(), slice.growth.level("ember_bolt")])
			slice.wake()
		_:
			failures.append("stuck on screen " + slice.screen)
			return false
	return true


func _pick(opts: Array) -> int:
	for want in PREFER:
		for i in opts.size():
			if want in str(opts[i]["text"]):
				return i
	for i in opts.size():
		if str(opts[i]["text"]) in ["Leave", "Continue", "Get up", "Slip away home", "Just read"]:
			return i
	return opts.size() - 1


func _report() -> void:
	if not ring3_day.has(1):
		failures.append("loop 1 never reached the 3rd Ring, so there is nothing to relearn")
	elif not ring3_day.has(3):
		failures.append("loop 3 did not regain the 3rd Ring by day 3")
	else:
		var d1: int = ring3_day[1]
		var d3: int = ring3_day[3]
		print("[relearn] the 3rd Ring: day %d in loop 1, day %d in loop 3" % [d1, d3])
		if d3 > 3 or d3 > maxf(1.0, d1 / 2.0):
			failures.append("loop 3 took %d days to regain the 3rd Ring (loop 1: %d)" % [d3, d1])
	var p1: Dictionary = practice.get(1, {})
	var p3: Dictionary = practice.get(3, {})
	if p1.has(7) and p3.has(3):
		print("[relearn] Ember Bolt Practice: %d on day 7 of loop 1, %d on day 3 of loop 3" % [p1[7], p3[3]])
		if int(p3[3]) < int(p1[7]):
			failures.append("Practice relearns too slowly: %d by day 3 of loop 3, %d by day 7 of loop 1" % [p3[3], p1[7]])
	else:
		failures.append("Practice not measured (loop 1 days %s, loop 3 days %s)" % [p1.keys(), p3.keys()])
	for f in failures:
		print("[relearn] FAIL: " + f)
	if failures.is_empty():
		print("[relearn] relearning is fast enough")
	quit(1 if not failures.is_empty() else 0)
