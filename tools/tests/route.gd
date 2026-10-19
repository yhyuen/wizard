extends SceneTree
## The first playable's route skeleton (design/ruins/tech-plan.md §8, R1): the camp, the way
## down and back, by walking.
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/route.gd
##
## A bot (tools/tests/walker.gd) wakes on the cot, talks to Mira (C1), reads the dwarves' crate
## (H4), walks to the north stair and goes down through the loading card to the halls' landing,
## reads the rune door, comes back up into the camp, and sleeps. On day 2 it goes down again and
## lets the loop go at the shrine. Loop 2 must wake to its own scene, with the Hours stirring.
## Every map change must rebuild the view and warm its shaders behind the card. R2 replaces this
## with the long-route, short-route loops of success criterion 5.

const Walker := preload("res://tools/tests/walker.gd")
const MAX_FRAMES := 120000

## Goals for each time of day (Morning, Noon, Afternoon, Dusk, Night); a day not listed waits
## out the day and sleeps.
const PLAN_1 := {
	1: [["talk:mira", "use:dwarf_crate", "talk:pell"], ["talk:captain", "exit:north_stair", "go:entrance_hall", "use:rune_door",
		"exit:stair_up"], ["use:east_gate"], ["talk:aldous"], ["sleep"]],
	2: [["exit:north_stair", "use:shrine>Let this loop go"], [], [], [], []],
}
const PLAN_2 := {
	1: [["use:cot>Change the spellbook"], [], [], [], []],
}
const PREFER := ["Go down", "\"Which way did it go?\"", "Train", "Meditate"]

var main
var slice
var run
var bot
var frames := 0
var last_key := []
var failures: Array = []
var done := false
var maps_seen := {}  # map id -> the view was built for it, warm, when its loading card lifted
var loads := 0
var was_loading := false


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
		slice.fight_resolver = func(_id: String) -> Dictionary: return {"won": true, "kills": 0}
		slice.new_month()
	if frames < 3:
		return false
	if frames > MAX_FRAMES:
		failures.append("timed out on loop %d, day %d, %s, on %s" % [run.loop(), run.day(), run.time_name(), slice.world.map_id])
		return _report()
	_watch_loading()
	match slice.screen:
		"death":
			var log: Dictionary = run.mem["log"][-1]
			print("[route] loop %d ends on day %d (%s), learned %d" % [run.loop(), run.day(), log["cause"], log["learned"].size()])
			if run.loop() >= 2:
				failures.append("loop 2 ended too")
				return _report()
			slice.wake()
		"world", "loading":
			if slice.screen == "loading":
				bot.tick(1.0 / 60.0)
				return false
			var key := [run.loop(), run.day(), run.time()]
			if key != last_key:
				last_key = key
				var plan: Dictionary = PLAN_1 if run.loop() == 1 else PLAN_2
				if run.loop() == 2 and not plan.has(run.day()):
					return _report()
				var day_plan: Array = plan.get(run.day(), [[], [], [], [], ["sleep"]])
				bot.set_goals(day_plan[run.time()])
				if run.time() == 0:
					print("[route] loop %d, day %d, on %s" % [run.loop(), run.day(), slice.world.map_id])
			if bot.tick(1.0 / 60.0) == "idle":
				if run.loop() == 2 and run.day() == 1 and slice.cur.is_empty():
					return _report()
				slice.wait()
		_:
			failures.append("stuck on screen " + slice.screen)
			return _report()
	return false


## Each loading card: the world and the view must agree on the map, and its shaders must have
## been warmed before the card lifts.
func _watch_loading() -> void:
	var loading: bool = slice.screen == "loading"
	if loading and not was_loading:
		loads += 1
		if main.view.warm <= 0:
			failures.append("the loading card to %s didn't warm the shaders" % slice.world.map_id)
	if was_loading and not loading:
		var id: String = slice.world.map_id
		maps_seen[id] = main.view.built_for == id and main.view.warm == 0
		if main.view.built_for != id:
			failures.append("the view shows %s after the card, the world is on %s" % [main.view.built_for, id])
		print("[route] the loading card lifted on %s (%s)" % [slice.world.map_def()["name"], slice.world.map.place_name(slice.world.here)])
	was_loading = loading


func _report() -> bool:
	done = true
	for need in ["orrery_light", "carried_out", "rune_ashlar", "wren_cipher", "captain", "the_halls", "rune_shape", "backward_prints",
			"mill_cellars", "shrine_release", "hours_stirs", "model_rewind"]:
		if not run.knows(need):
			failures.append("never learned " + need)
	var log: Array = run.mem["log"]
	if log.is_empty() or log[0]["cause"] != "shrine" or int(log[0]["day"]) != 2:
		failures.append("loop 1 must end at the shrine on day 2, got %s" % [str(log[0]) if not log.is_empty() else "no ending"])
	if run.loop() != 2:
		failures.append("the route ended on loop %d, not loop 2" % run.loop())
	if not run.seen("wake_again"):
		failures.append("loop 2 didn't wake to its own scene")
	if not maps_seen.get("halls", false) or not maps_seen.get("camp", false):
		failures.append("the view wasn't rebuilt for both maps: %s" % maps_seen)
	if loads < 3:
		failures.append("expected three loading cards (down, up, down), got %d" % loads)
	if slice.world.map_id != "camp" or main.view.built_for != "camp":
		failures.append("loop 2 should wake in the camp (world %s, view %s)" % [slice.world.map_id, main.view.built_for])
	for s in bot.stuck:
		failures.append(s)
	for m in bot.missed:
		print("[route] note: the time of day ran out before " + m)
	print("[route] about %.1f minutes of play, %d Ledger entries known, %d frames" % [bot.play_s / 60.0, run.known_ids().size(), frames])
	var summary: String = slice.run_summary()
	print("[route] run summary:\n" + summary)
	for want in ["The Shattered Orrery, first playable · build", "Loop 1 died on day 2", "carried_out"]:
		if not want in summary:
			failures.append("the run summary has no \"%s\"" % want)
	for f in failures:
		print("[route] FAIL: " + f)
	if failures.is_empty():
		print("[route] the camp and the way down play through by walking")
	quit(1 if not failures.is_empty() else 0)
	return true
