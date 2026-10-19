extends SceneTree
## Every death teaches (design/ruins/README.md):
##
##   godot --headless --script res://tools/tests/deaths.gd
##
## For each way to die in data/world/ledger.json "deaths", a fresh month plays the scene that
## leads to it (losing the fight, if there is one) through to the death screen. Dying that way
## for the first time must teach at least one Ledger entry the death screen shows.

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
	if slice.screen != "death":
		failures.append("%s: playing %s ended on screen %s, not the death screen" % [cause, scene, slice.screen])
		return
	var log: Dictionary = run.mem["log"][-1]
	if log["cause"] != cause:
		failures.append("%s: %s led to the death \"%s\"" % [cause, scene, log["cause"]])
		return
	var shown: Array = []
	for id in log["learned"]:
		if not id in before and slice.ledger.has(id) and slice.ledger[id]["kind"] != "trial":
			shown.append(slice.ledger[id]["title"])
	print("[deaths] %s: %s" % [cause, ", ".join(shown) if not shown.is_empty() else "nothing"])
	if shown.is_empty():
		failures.append("dying to %s for the first time teaches nothing" % cause)
