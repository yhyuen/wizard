extends SceneTree
## The first playable's route (design/ruins/README.md §4, success criterion 5), by walking.
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/route.gd
##
## A bot (tools/tests/walker.gd) wakes on the cot, talks to Mira (C1) and Pell, and goes down the
## north stair to the halls' landing. It reads the rune door, which is sealed, and climbs back out,
## which costs the day: it sleeps and wakes on day 2. Then it goes down again and takes the long
## route (entrance hall, refectory, lecture gallery, antechamber) to the Kiln Warden, which kills
## it (fights are settled by fight_resolver: the rooms are won, the Warden is lost on loop 1).
## Loop 2 wakes to its own scene with the Hours stirring and puts Rewind in its spellbook. Day 1
## it reads the dwarves' crate (H4), goes down, turns the great clock back with Rewind (H1), mends
## the collapsed stair with it (H5), walks through to the cistern and turns the sluice, and climbs
## out. Day 2 it opens the rune door, takes the short route through the bell passage, beats the
## Warden and reaches the end card at the Archive stair. Loop 1 also sees the sighting and the
## burnt door, and reads Wren's chalk mark in the gallery. From where the routes part (leaving the entrance hall) to the Kiln
## hall, the short way must take under half the long way's play time, counting each fight at about
## the time the encounter test's fresh Apprentice takes to win it (FIGHT_S). Every loading card
## must rebuild the view and warm its shaders behind it.

const Walker := preload("res://tools/tests/walker.gd")
const MAX_FRAMES := 150000
const LONG := ["go:entrance_hall", "use:rune_door", "go:refectory", "go:gallery", "use:wren_chalk", "go:antechamber",
	"use:burnt_door", "go:kiln_hall"]
const SHORT := ["go:entrance_hall", "use:rune_door", "go:bell_passage", "go:antechamber", "go:kiln_hall"]

## Goals for each time of day (Morning, Noon, Afternoon, Dusk, Night); in the halls the clock
## stops, so a descent is played out under the time of day it began in.
const PLAN_1 := {
	1: [["talk:mira", "talk:pell"], ["talk:captain", "exit:north_stair", "go:entrance_hall", "use:rune_door",
		"use:stair_back>Climb out"], [], [], ["sleep"]],
	2: [["exit:north_stair"] + LONG, [], [], [], []],
}
const PLAN_2 := {
	1: [["use:dwarf_crate", "talk:captain", "exit:north_stair", "go:entrance_hall", "use:great_clock", "cast:great_clock:rewind", "use:collapsed_stair",
		"cast:collapsed_stair:rewind", "go:cistern", "use:sluice>Turn the wheel", "use:stair_back>Climb out"], [], [], [], ["sleep"]],
	2: [["exit:north_stair"] + SHORT + ["use:archive_stair>Sit on the bottom step"], [], [], [], []],
}
const PREFER := ["Go down", "Face it", "\"Which way did it go?\"", "Train", "Meditate"]
## Seconds of play each fight takes (tools/tests/encounters.gd, fresh, rounded).
const FIGHT_S := {"hall_fight": 12.0, "refectory_fight": 19.0, "gallery_fight": 14.0, "ante_fight": 5.0, "warden": 0.0}

var main
var slice
var run
var bot
var frames := 0
var last_key := []
var failures: Array = []
var done := false
var loads := 0
var was_loading := false
var down_at := -1.0  # play seconds when this loop's descent reached the landing
var fork_at := -1.0  # play seconds when it left the entrance hall, where the routes part
var to_warden := {}  # loop -> play seconds from the fork to the Kiln hall
var surfaced := ""  # where the day after the first climb out began


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
			bot.play_s += float(FIGHT_S.get(id, 10.0))
			return {"won": not (id == "warden" and run.loop() == 1), "kills": 0}
		slice.new_month()
	if frames < 3:
		return false
	if frames > MAX_FRAMES:
		failures.append("timed out on loop %d, day %d, %s, on %s" % [run.loop(), run.day(), run.time_name(), slice.world.map_id])
		return _report()
	_watch_loading()
	_watch_route()
	match slice.screen:
		"death":
			var log: Dictionary = run.mem["log"][-1]
			print("[route] loop %d ends on day %d (%s), learned %d" % [run.loop(), run.day(), log["cause"], log["learned"].size()])
			if run.loop() >= 2:
				return _report()
			down_at = -1.0
			fork_at = -1.0
			slice.wake()
		"world", "loading":
			if slice.screen == "loading":
				bot.tick(1.0 / 60.0)
				return false
			var key := [run.loop(), run.day(), run.time()]
			if key != last_key:
				last_key = key
				var plan: Dictionary = PLAN_1 if run.loop() == 1 else PLAN_2
				if run.loop() == 1 and run.day() == 2 and run.time() == 0 and surfaced == "":
					surfaced = "%s/%s" % [slice.world.map_id, main.view.built_for]
				if run.loop() == 2 and run.day() == 1 and run.time() == 0 and slice.growth.prog.spellbook()[1] != "rewind":
					# what a player does at the cot once the Hours stir: Rewind into the second slot
					var book: Array = slice.growth.prog.spellbook().duplicate()
					book[book.find("rewind") if book.has("rewind") else 1] = book[1]
					book[1] = "rewind"
					run.lp["book"] = book
					slice.growth.refresh()
					main.refresh_book()
				if not plan.has(run.day()):
					failures.append("loop %d got to day %d without ending" % [run.loop(), run.day()])
					return _report()
				var day_plan: Array = plan[run.day()]
				bot.set_goals(day_plan[run.time()])
				if run.time() == 0:
					print("[route] loop %d, day %d, on %s" % [run.loop(), run.day(), slice.world.map_id])
			if bot.tick(1.0 / 60.0) == "idle" and slice.cur.is_empty():
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
		if main.view.built_for != id:
			failures.append("the view shows %s after the card, the world is on %s" % [main.view.built_for, id])
		print("[route] the loading card lifted on %s (%s)" % [slice.world.map_def()["name"], slice.world.map.place_name(slice.world.here)])
		if id == "halls" and run.day() == 2:
			down_at = bot.play_s  # the descent that goes to the Warden
			fork_at = -1.0
	was_loading = loading


## The way from the fork to the Kiln hall, timed in play seconds.
var _last_here := ""
func _watch_route() -> void:
	if slice.world.here != _last_here and down_at >= 0.0:
		if _last_here == "entrance_hall" and fork_at < 0.0:
			fork_at = bot.play_s
		_last_here = slice.world.here
	if fork_at >= 0.0 and slice.world.map_id == "halls" and slice.world.here == "kiln_hall" and not to_warden.has(run.loop()):
		to_warden[run.loop()] = bot.play_s - fork_at
		print("[route] loop %d reached the Kiln hall %.0f s after the landing, %.0f s after leaving the entrance hall" % [
			run.loop(), bot.play_s - down_at, to_warden[run.loop()]])


func _report() -> bool:
	done = true
	for need in ["orrery_light", "carried_out", "wren_cipher", "captain", "the_halls", "rune_shape", "rune_ashlar", "rune_opened",
			"crack_order", "short_route", "warden_water", "hours_stirs", "trial_warden", "figure_ahead", "wren_chalk",
			"burnt_far_side", "provost_crossed", "stair_cult", "stair_mend", "sluice_flood"]:
		if not run.knows(need):
			failures.append("never learned " + need)
	var log: Array = run.mem["log"]
	var causes: Array = log.map(func(l): return l["cause"])
	if not run.mem["log"].is_empty() and int(run.mem["log"][-1]["day"]) != 2:
		failures.append("loop 2 should reach the end card on day 2 (the stair and the sluice took day 1)")
	if causes != ["fight:warden", "first_playable_end"]:
		failures.append("loop 1 must die to the Warden and loop 2 reach the end card, got %s" % str(causes))
	if surfaced != "camp/camp":
		failures.append("climbing out should end the day and wake in the camp (day 2 began on %s)" % surfaced)
	if not run.seen("wake_again"):
		failures.append("loop 2 didn't wake to its own scene")
	if loads < 3:
		failures.append("expected three loading cards (down, down, down), got %d" % loads)
	if not (to_warden.has(1) and to_warden.has(2)):
		failures.append("both loops must reach the Kiln hall: %s" % str(to_warden))
	elif to_warden[2] >= to_warden[1] * 0.5:
		failures.append("the short route (%.0f s) must take under half the long route (%.0f s)" % [to_warden[2], to_warden[1]])
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
		print("[route] loop 1 takes the long way and dies; loop 2 takes the short way to the end card")
	quit(1 if not failures.is_empty() else 0)
	return true
