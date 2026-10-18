extends SceneTree
## Success criterion 8 (design/open-world/README.md §4, as the slice), relearning:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/relearn.gd
##
## A bot that grinds by walking the town (tools/tests/walker.gd: the yard trial and training in
## the yard, meditating in your room, studying with Wren, and the night patrol in the market)
## plays three loops through the real story, dying to the north door each time. Loop 1 must reach
## the 3rd Ring; loop 3 must regain it by day 3, in at most half the days loop 1 took. Its Ember
## Bolt Practice must also be back to loop 1's day-7 level by day 3. Fights are settled
## instantly (won, with every killable enemy killed), except the tide, which is lost.

const Walker := preload("res://tools/tests/walker.gd")
const GRIND := [["talk:examiner", "use:targets"], ["use:bed>Meditate"], ["talk:examiner", "use:targets"], ["talk:wren"], ["go:market", "sleep"]]
const PREFER := ["Take the yard trial", "Train", "Meditate", "Fight them", "Study with Wren", "Luna: Splash", "Mercury: Spark"]
const MAX_FRAMES := 400000

var main
var slice
var run
var bot
var frames := 0
var last_key := []
var ring3_day := {}  # loop -> the day the 3rd Ring was first held
var practice := {}  # loop -> {day: Ember Bolt Practice at the end of that day}
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
	if frames < 3:
		return false
	if frames > MAX_FRAMES:
		failures.append("timed out on loop %d, day %d" % [run.loop(), run.day()])
		return _report()
	_note()
	match slice.screen:
		"death":
			var p: Dictionary = practice.get(run.loop(), {})
			p[run.day()] = slice.growth.level("ember_bolt")
			practice[run.loop()] = p
			print("[relearn] loop %d ends on day %d: %s, %d wells, Ember Bolt Practice %d" % [run.loop(), run.day(),
				slice.growth.ring_name(), slice.growth.wells(), slice.growth.level("ember_bolt")])
			slice.wake()
		"world":
			var key := [run.loop(), run.day(), run.time()]
			if key != last_key:
				if run.time() == 0 and run.day() > 1:
					var p: Dictionary = practice.get(run.loop(), {})
					p[run.day() - 1] = slice.growth.level("ember_bolt")
					practice[run.loop()] = p
				if run.loop() == 3 and run.day() > 3:
					return _report()
				last_key = key
				bot.set_goals(GRIND[run.time()])
			if bot.tick(1.0 / 60.0) == "idle":
				slice.wait()
		_:
			failures.append("stuck on screen " + slice.screen)
			return _report()
	return false


func _note() -> void:
	if slice.growth.ring() >= 3 and not ring3_day.has(run.loop()):
		ring3_day[run.loop()] = run.day()
		print("[relearn] loop %d: the 3rd Ring on day %d (%d wells)" % [run.loop(), run.day(), slice.growth.wells()])


func _report() -> bool:
	done = true
	for st in bot.stuck:
		failures.append(st)
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
	return true
