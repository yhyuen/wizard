extends SceneTree
## Every death teaches (design/ruins/README.md):
##
##   godot --headless --script res://tools/tests/deaths.gd
##
## For each way to die in data/world/ledger.json "deaths", a fresh month plays the scene that
## leads to it (losing the fight, if there is one) through to the death screen, or, for a loss that
## doesn't end the life (lives spec §3.2), to the hurt screen and waking injured two days later.
## Dying or falling that way for the first time must teach at least one Ledger entry the screen
## shows. Also the life 1 main line's Thaw examination and the stair fall that costs the watch, and
## the Lamplighter road's opening, round and reckoning (N-7.4).

## Death cause -> the scene that leads to it. A new cause must be added here.
const ROUTES := {
	"patrol": "patrol_fight",
	"eclipse": "eclipse",
	"turned": "shrine_release",
	"fight:hall_fight": "entrance_hall",
	"fight:refectory_fight": "refectory",
	"fight:gallery_fight": "gallery",
	"fight:ante_fight": "antechamber",
	"fight:warden": "warden_fight",
	"fall": "daybook_study",
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
	_fixed_events()
	_shrine_waits()
	_thaw_exam()
	_daybook_fall()
	_lamplighter()
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
	var log: Dictionary = run.soul["lives"][-1] if ends else run.life["losses"][-1]
	if log["cause"] != cause:
		failures.append("%s: %s led to \"%s\"" % [cause, scene, log["cause"]])
		return
	var learned: Array = log["learned"] if ends else run.life["learned"]
	if not ends:
		_wake_injured(cause)
	var shown: Array = []
	for id in learned:
		if not id in before and slice.ledger.has(id) and slice.ledger[id]["kind"] != "trial":
			shown.append(slice.ledger[id]["title"])
	print("[deaths] %s: %s" % [cause, ", ".join(shown) if not shown.is_empty() else "nothing"])
	if shown.is_empty():
		failures.append("dying to %s for the first time teaches nothing" % cause)


## A loss that doesn't end the life (lives spec §3.2): you wake on your cot two days later (a lost
## fight) or as many as the story says (`downed`), Injured,
## with Vitality held down until a full night's sleep.
func _wake_injured(cause: String) -> void:
	var day: int = run.day()
	var days: int = int(run.life["losses"][-1]["days"])  # the story sets its own (`downed`)
	if cause.begins_with("fight") or cause == "patrol":
		if days != int(run.lives["wake_injured"]["days"]):
			failures.append("%s: a lost fight should cost %d days, not %d" % [cause, int(run.lives["wake_injured"]["days"]), days])
	slice.wake()
	if slice.screen != "world" or run.day() != day + days:
		failures.append("%s: should wake in the world %d days later (day %d), got %s on day %d" % [cause, days, day + days, slice.screen, run.day()])
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
	if slice.travel("archive") or run.day() != 29:
		failures.append("the Archive district isn't built: going there must cost no time and go nowhere")
	if not slice.travel("city") or run.day() != 30 or slice.world.map_id != "city":
		failures.append("the road to the fallen city should take a day and arrive at the wall gap (day %d, %s)" % [run.day(), slice.world.map_id])
	else:
		print("[deaths] rested to %s, then travelled to the fallen city, arriving %s" % [run.date_name(29), run.date_name()])


## Fixed events (lives spec §6.2): one plays if you're in its region at its hour; one you sleep
## through runs its default, and one that costs something becomes an appointment for later lives.
func _fixed_events() -> void:
	slice.new_month()
	slice.finish_scene()
	run.life["day"] = 2
	run.life["time"] = 2  # afternoon: the Knights ride in at dusk
	slice.next_period()
	if str(slice.cur.get("id", "")) != "knights_arrive" or run.event_state("knights_arrive") != "attended":
		failures.append("the Knights should arrive while you're in the camp at dusk on Ashmoon 2 (%s, %s)" % [slice.cur.get("id", ""), run.event_state("knights_arrive")])
	slice.finish_scene()
	if not slice.rest_until(40) or run.event_state("iron_gate_shuts") != "missed" or not run.flag("iron_gate_shut"):
		failures.append("resting past Thaw 2 should run the Iron Gate's default (%s)" % run.event_state("iron_gate_shuts"))
	elif not run.soul["appointments"].has("iron_gate_shuts") or run.soul["appointments"].has("knights_arrive"):
		failures.append("only a missed event that costs something becomes an appointment: %s" % str(run.soul["appointments"].keys()))
	else:
		var pinned: Array = slice.reach.events().filter(func(e): return e["known"]).map(func(e): return e["id"])
		if not ("knights_arrive" in pinned and "iron_gate_shuts" in pinned):
			failures.append("fixed events seen or missed should be pinned from then on: %s" % str(pinned))
		else:
			print("[deaths] the Knights came at dusk on Ashmoon 2; the Iron Gate shut while you rested, and the Ledger kept the date")


## The shrine turns back the Hours only once a calamity has passed in this life (lives spec §3.1).
func _shrine_waits() -> void:
	slice.new_month()
	slice.play("shrine")
	var texts: Array = slice.opts.map(func(o): return str(o["text"]))
	if "Turn back the Hours" in texts:
		failures.append("the shrine offers to turn back the Hours before any calamity: %s" % str(texts))
	slice.finish_scene()
	run.pass_calamity("stand_in")
	slice.play("shrine")
	texts = slice.opts.map(func(o): return str(o["text"]))
	if not "Turn back the Hours" in texts:
		failures.append("the shrine should offer to turn back the Hours once a calamity has passed: %s" % str(texts))
	slice.finish_scene()


## The life 1 main line (N-7.3.2): the fall on the way back from Wren's book on Seedmoon 11 keeps
## you down three days, so the watch on Seedmoon 12 goes by without you and becomes an appointment.
func _daybook_fall() -> void:
	slice.new_month()
	slice.finish_scene()
	run.life["day"] = 67
	run.life["time"] = 2
	slice.play("daybook_study")
	slice.choose(0)
	slice.choose(0)
	if slice.screen != "hurt":
		failures.append("the stair should knock you down (screen %s)" % slice.screen)
		return
	slice.wake()
	if run.day() != 70 or run.event_state("two_on_watch") != "missed" or not run.flag("tam_taken"):
		failures.append("three days down from Seedmoon 11 should miss the watch on the 12th (day %d, %s)" % [run.day(), run.event_state("two_on_watch")])
	elif not run.soul["appointments"].has("two_on_watch"):
		failures.append("the missed watch should become an appointment")
	elif slice.story.arrive_scene("tent") != "daybook_wake":
		failures.append("you should wake to Mira after the fall, not %s" % slice.story.arrive_scene("tent"))
	else:
		print("[deaths] the stair fall on Seedmoon 11 cost three days, and the watch on the 12th became an appointment")


## The Thaw examination (N-7.3.2): the right chart and Alignment pass; the wrong chart fails.
func _thaw_exam() -> void:
	for right in [true, false]:
		slice.new_month()
		slice.finish_scene()
		run.learn("alignment")
		slice.play("thaw_exam")
		slice.choose(0 if right else 1)
		for i in 3:
			if not slice.cur.is_empty():
				slice.choose(0)
		if run.flag("exam_passed_thaw") != right:
			failures.append("the Thaw examination with the %s chart should %s" % ["right" if right else "wrong", "pass" if right else "fail"])
	print("[deaths] the Thaw examination passes on the right chart with Alignment, and fails on the wrong one")


## The Lamplighter road (N-7.4): a second life with the road open takes Fennick's offer, joins the
## Guild, packs a flask, walks Mira's round (all 24 circuit lamps by hand) and passes the reckoning.
func _lamplighter() -> void:
	slice.new_month()
	slice.finish_scene()
	if not run.soul.has("flags"):
		run.soul["flags"] = {}
	run.soul["flags"]["road_lamplighter"] = true
	run.soul["lives"] = [{"n": 1, "road": "apprentice"}]
	run.soul["last_road"] = "apprentice"
	run.life = run.fresh_life()
	run.learn("pell_children")
	slice.play("fennick_flap")
	slice.choose(0)
	slice.finish_scene()
	if run.road() != "lamplighter" or slice.powers.rank("guild") != 0 or slice.powers.standing("guild") != 20:
		failures.append("taking Fennick's offer should put you on the Lamplighter road, an Initiate of the Guild (%s)" % run.road())
		return
	slice.play("rule_one")
	slice.choose(0)
	slice.finish_scene()
	run.life["day"] = 4
	run.life["time"] = 3
	run.life["done_round"] = 4
	var world = slice.world
	for l in world.lamps:
		if l["circuit"] != "" and l["by"] == "town":
			l["lit"] = false
			l["by"] = ""
	for l in world.lamps:
		if l["circuit"] != "":
			world.light_lamp(l, "you")
	run.life["day"] = 70
	run.life["time"] = 0
	slice.play("reckoning")
	slice.choose(0)
	slice.choose(0)
	slice.choose(0)
	if not (run.flag("rule_one") and run.flag("round_done") and run.flag("reckoning_passed") and run.flag("reckoning_rich")):
		failures.append("the Lamplighter road: rule one %s, the round %s, the reckoning %s" % [run.flag("rule_one"), run.flag("round_done"), run.flag("reckoning_passed")])
	elif slice.powers.merit() != 5:
		failures.append("rule one should earn 5 merit (got %d)" % slice.powers.merit())
	else:
		print("[deaths] the Lamplighter road: Fennick's offer, rule one, all 24 lamps by hand, and in the black at the reckoning")
	slice.finish_scene()
