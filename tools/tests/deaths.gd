extends SceneTree
## Every death teaches (design/ruins/README.md):
##
##   godot --headless --script res://tools/tests/deaths.gd
##
## For each way to die in data/world/ledger.json "deaths", a fresh month plays the scene that
## leads to it (losing the fight, if there is one) through to the death screen, or, for a loss that
## doesn't end the life (lives spec §3.2), to the hurt screen and waking injured two days later.
## Dying or falling that way for the first time must teach at least one Ledger entry the screen
## shows.

## Death cause -> the scene that leads to it. A new cause must be added here.
const ROUTES := {
	"patrol": "patrol_fight",
	"eclipse": "eclipse",
	"shrine": "shrine_release",
	"fight:hall_fight": "entrance_hall",
	"fight:refectory_fight": "refectory",
	"fight:gallery_fight": "gallery",
	"fight:ante_fight": "antechamber",
	"fight:warden": "warden_fight",
}
const GENERIC := ["fight"]  # the fallback text for a lethal fight with no death scene of its own
const NOT_DEATHS := ["first_playable_end"]  # the end card, reached by winning

var main
var slice
var run
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
	slice.fight_resolver = func(_id): return false
	for cause in slice.death_texts:
		if cause in GENERIC or cause in NOT_DEATHS:
			continue
		if not ROUTES.has(cause):
			failures.append("no route to the death \"%s\": add one to tools/tests/deaths.gd" % cause)
			continue
		_die(cause, ROUTES[cause])
	_rest_and_travel()
	for f in failures:
		print("[deaths] FAIL: " + f)
	if failures.is_empty():
		print("[deaths] every first death teaches something")
	quit(1 if not failures.is_empty() else 0)


func _die(cause: String, scene: String) -> void:
	slice.new_month()
	var before: Array = run.known_ids()
	slice.play(scene)
	var n := 0
	while slice.screen == "world" and not slice.cur.is_empty() and n < 50:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
		else:
			slice.choose(0)
	var ends: bool = run.ends_life(cause)
	var want := "death" if ends else "hurt"
	if slice.screen != want:
		failures.append("%s: playing %s ended on screen %s, not the %s screen" % [cause, scene, slice.screen, want])
		return
	var log: Dictionary = run.mem["log"][-1] if ends else run.lp["losses"][-1]
	if log["cause"] != cause:
		failures.append("%s: %s led to \"%s\"" % [cause, scene, log["cause"]])
		return
	var learned: Array = log["learned"] if ends else run.lp["learned"]
	if not ends:
		_wake_injured(cause)
	var shown: Array = []
	for id in learned:
		if not id in before and slice.ledger.has(id) and slice.ledger[id]["kind"] != "trial":
			shown.append(slice.ledger[id]["title"])
	print("[deaths] %s: %s" % [cause, ", ".join(shown) if not shown.is_empty() else "nothing"])
	if shown.is_empty():
		failures.append("dying to %s for the first time teaches nothing" % cause)


## A loss that doesn't end the life (lives spec §3.2): you wake on your cot two days later, Injured,
## with Vitality held down until a full night's sleep.
func _wake_injured(cause: String) -> void:
	var day: int = run.day()
	slice.wake()
	if slice.screen != "world" or run.day() != day + int(run.lives["wake_injured"]["days"]):
		failures.append("%s: should wake in the world two days later (day %d), got %s on day %d" % [cause, day + 2, slice.screen, run.day()])
	elif not run.injured() or main.arena.hp_cap >= 1.0 or main.arena.player.hp > main.arena.player.max_hp * 0.76:
		failures.append("%s: waking after a loss should leave you Injured" % cause)


## Resting until a date on the calendar (N-1.1) and travelling the roads (N-1.4) cost days; a
## region that isn't built yet is only a card.
func _rest_and_travel() -> void:
	slice.new_month()
	slice.fight_resolver = Callable()
	var rested: bool = slice.rest_until(29)
	if not rested or run.day() != 29 or run.moon() != 2 or slice.screen != "world" or run.time() != 0:
		failures.append("resting until Thaw begins should wake you on Moon 2, day 1 (day %d, %s)" % [run.day(), slice.screen])
	if slice.travel("mill") or run.day() != 29:
		failures.append("the Mill fields aren't built: going there must cost no time and go nowhere")
	if not slice.travel("city") or run.day() != 30 or slice.world.map_id != "halls":
		failures.append("the road to the fallen city should take a day and arrive at the halls (day %d, %s)" % [run.day(), slice.world.map_id])
	else:
		print("[deaths] rested to %s, then travelled to the fallen city, arriving %s" % [run.date_name(29), run.date_name()])
