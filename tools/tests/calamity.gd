extends SceneTree
## The calamity frame (seasons spec §6, §8, §10.2; N-7.5.1) with Lantern Night:
##
##   godot --headless --script res://tools/tests/calamity.gd
##
## Two signs pin a "?" on Seedmoon 28 and a rest stops on its Eve; resting through it unpinned lets
## it pass without you (Fallen), and four preparations raise that to Scarred; standing in the camp
## at Night plays the Onset and the Peak; surviving it with 16 lamps lit is Held (which opens the
## Lamplighter road for the next life); losing the Peak ends the life; after the Dawn tally, Ring 1's
## end card ends the life, and the next life knows the date by name. The story layer (N-7.5.2): a
## preparation takes the time of day; at the lighting, stopping the cut keeps every lamp lit
## through the Onset (the sealed stake Held needs); otherwise only re-wicked circuits hold, and 16
## lamps lit by Dawn are only Scarred.

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
	_pin_and_eve()
	_absent()
	_prep_time()
	_taken()
	_present()
	_lost()
	_vigil()
	_early_bell()
	_variants()
	for f in failures:
		print("[calamity] FAIL: " + f)
	if failures.is_empty():
		print("[calamity] the calamity frame holds")
	quit(1 if not failures.is_empty() else 0)


func _fresh(day: int, time := 0) -> void:
	slice.new_month()
	slice.finish_scene()
	run.life["day"] = day
	run.life["time"] = time


func _calendar() -> Dictionary:
	for e in slice.reach.events():
		if e["id"] == "calamity_1":
			return e
	return {}


func _pin_and_eve() -> void:
	_fresh(77)
	if _calendar()["known"]:
		failures.append("Lantern Night's date shouldn't be on a first life's calendar before its signs")
	slice._effect("sign", "lantern_night flicker")
	slice._effect("sign", "lantern_night mira_oil")
	var e := _calendar()
	if not e["known"] or e["name"] != "?":
		failures.append("two signs should pin an unnamed \"?\" on Seedmoon 28 (%s)" % str(e))
	slice.rest_until(85)
	if run.day() != 84:
		failures.append("a rest past a pinned calamity should stop on its Eve (woke on day %d)" % run.day())
	else:
		print("[calamity] two signs pinned a \"?\" on Seedmoon 28, and a rest stopped on its Eve")


func _absent() -> void:
	for raise in [false, true]:
		_fresh(80)
		if raise:
			for p in ["rewick", "bridge_rails", "clear_hay", "shelter"]:
				slice._effect("prep", "lantern_night " + p)
			slice.after = []
		slice.rest_until(86)
		var t: Dictionary = slice.calamity.state("lantern_night").get("tally", {})
		var want := "scarred" if raise else "fallen"
		if slice.screen != "tally" or str(t.get("tier", "")) != want or not t.get("absent", false):
			failures.append("resting through Lantern Night with %d preparations should pass it without you, %s (%s, %s)" % [4 if raise else 0, want, slice.screen, str(t)])
			continue
		slice.tally_done()
		if slice.screen != "death" or str(run.past_lives()[-1]["cause"]) != "build_end":
			failures.append("after the tally Ring 1's end card should end the life (%s)" % slice.screen)
	print("[calamity] without you it falls; four preparations make it Scarred; then Ring 1's end card")


## Play the current scene through: `picks` are substrings of the choices to take, in order; any
## other choice point takes its first choice.
func _play_through(picks: Array) -> void:
	var n := 0
	while slice.screen == "world" and not slice.cur.is_empty() and n < 30:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
			continue
		var at := 0
		if not picks.is_empty():
			for j in slice.opts.size():
				if str(picks[0]) in str(slice.opts[j].get("text", "")):
					at = j
					picks.pop_front()
					break
		slice.choose(at)


func _light(n_lit: int) -> Callable:
	return func(_id):
		var n := 0
		for l in slice.world.lamps:
			if l["circuit"] != "" and n < n_lit:
				l["lit"] = true
				l["by"] = "you"
				n += 1
		return true


## The town lights the Market at Dusk (world.gd does it frame by frame; the test has no frames).
func _town_lamps() -> void:
	for l in slice.world.lamps:
		if l["circuit"] != "":
			l["lit"] = true
			l["by"] = "town"


func _prep_time() -> void:
	_fresh(80, 0)
	slice.world.load_map("camp")
	run.set_flag("pinned_calamity_1")
	slice.play("ready_watch")
	_play_through(["braziers"])
	if not {"t": "period"} in slice.world.requests or not slice.calamity.state("lantern_night")["prep"].has("braziers"):
		failures.append("a preparation should count and take the time of day (%s, %s)" % [str(slice.world.requests), str(slice.calamity.state("lantern_night"))])
	else:
		print("[calamity] a preparation counts and takes the time of day")


## At the lighting nobody stops the cut: the Onset douses all but the re-wicked circuit, the
## stone is taken, and 16 lamps by Dawn are Scarred, not Held.
func _taken() -> void:
	_fresh(84, 2)
	slice.world.load_map("camp")
	run.set_flag("rewick_a")
	slice.next_period()
	if str(slice.cur.get("id", "")) != "lighting":
		failures.append("at Dusk on Seedmoon 28 in the camp the lighting should play (%s)" % slice.cur.get("id", ""))
		return
	_play_through(["crowd", "Watch"])
	if not run.knows("pell_lips"):
		failures.append("the lighting should leave the coupling in the Ledger")
	_town_lamps()
	slice.fight_resolver = func(_id):
		var a_lit: bool = slice.world.lamps.filter(func(l): return l["circuit"] == "A").all(func(l): return l["lit"])
		var others_dark: bool = slice.world.lamps.filter(func(l): return l["circuit"] in ["B", "C", "D"]).all(func(l): return not l["lit"])
		if not a_lit or not others_dark:
			failures.append("at the Onset only the re-wicked circuit should hold")
		return _light(16).call(_id)
	slice.next_period()
	_play_through([])
	slice.fight_resolver = Callable()
	var t: Dictionary = slice.calamity.state("lantern_night").get("tally", {})
	if str(t.get("tier", "")) != "scarred" or not run.flag("heart_taken"):
		failures.append("with the cut not stopped, 16 lamps should be Scarred (%s)" % str(t))
	else:
		print("[calamity] the cut not stopped: only the re-wicked circuit holds, and 16 lamps are Scarred")


func _present() -> void:
	_fresh(84, 2)
	slice.world.load_map("camp")
	run.set_flag("mira_sign_seat")
	run.learn("pell_children")
	slice.next_period()
	_play_through(["crowd", "Look", "names"])
	if not run.flag("cut_stopped"):
		failures.append("saying the names at the lighting should stop the cut")
		return
	_town_lamps()
	slice.fight_resolver = func(_id):
		if not slice.world.lamps.filter(func(l): return l["circuit"] != "").all(func(l): return l["lit"]):
			failures.append("with the cut stopped the Onset should leave the lamps lit")
		return _light(16).call(_id)
	slice.next_period()
	if str(slice.cur.get("id", "")) != "lantern_night_onset":
		failures.append("at Night on Seedmoon 28 in the camp the Onset should play (%s)" % slice.cur.get("id", ""))
		return
	var n := 0
	while slice.screen == "world" and not slice.cur.is_empty() and n < 20:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
		else:
			slice.choose(0)
	var t: Dictionary = slice.calamity.state("lantern_night").get("tally", {})
	if slice.screen != "tally" or str(t.get("tier", "")) != "held" or int(t.get("lamps", 0)) < 16:
		failures.append("surviving the Peak with 16 lamps lit should be Held (%s, %s)" % [slice.screen, str(t)])
		return
	if not run.can_turn():
		failures.append("once a calamity has passed the Hours can be turned back")
	slice.tally_done()
	slice.wake()
	slice.fight_resolver = Callable()
	var named: Dictionary = _calendar()
	if run.loop() != 2 or not ("lamplighter" in run.road_offers()) or not named["known"] or named["name"] != "Lantern Night":
		failures.append("the next life should offer the Lamplighter road and know Lantern Night by name (%s, %s)" % [str(run.road_offers()), str(named)])
	else:
		print("[calamity] the Peak survived with 16 lamps lit is Held; the next life knows Lantern Night and offers the Lamplighter road")


func _lost() -> void:
	_fresh(84, 3)
	slice.world.load_map("camp")
	slice.fight_resolver = func(_id): return false
	slice.next_period()
	var n := 0
	while slice.screen == "world" and not slice.cur.is_empty() and n < 20:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
		else:
			slice.choose(0)
	slice.fight_resolver = Callable()
	if slice.screen != "death" or str(run.past_lives()[-1]["cause"]) != "calamity:lantern_night":
		failures.append("falling in the Peak should end the life (%s)" % slice.screen)
	else:
		print("[calamity] falling in the Peak ends the life")


## The Peak's vigil (encounter `vigil`): a dark pool with a Hollow in it for 10 s loses its people;
## helpers relight a dark lamp with nothing near it.
func _vigil() -> void:
	_fresh(84, 4)
	slice.world.load_map("camp")
	run.set_flag("helpers_coming")
	var a = main.arena
	a.encounter = {"vigil": {"people": 30, "shelter": {"flag": "sheltered", "n": 10}, "near_r": 72, "taken_s": 10,
		"helpers": {"flag": "helpers_coming", "every": 15}}}
	a.phase = "enc"
	var circuit: Array = slice.world.lamps.filter(func(l): return l["circuit"] != "")
	for l in circuit:
		l["lit"] = false
		l["by"] = "doused"
	var h = a.spawn("hollow", circuit[0]["pos"] + Vector2(10, 0))
	for i in 66:
		slice.world._vigil(1.0 / 6.0)
	var lost := int(run.life.get("calamity_lost", 0))
	var early: int = circuit.filter(func(l): return l["by"] == "helper").size()
	for i in 30:
		slice.world._vigil(1.0 / 6.0)
	var helped: int = circuit.filter(func(l): return l["by"] == "helper" and l["pos"].distance_to(h.pos) > 72.0).size()
	h.dead = true
	a.phase = "explore"
	a.encounter = {}
	slice.world._vigil(0.1)
	if lost < 1 or lost > 4:
		failures.append("a dark pool with a Hollow in it for 10 s should lose its people (lost %d)" % lost)
	elif early != 0 or helped != 1:
		failures.append("a helper should relight one dark lamp with nothing near it after 15 s (%d, %d)" % [early, helped])
	else:
		print("[calamity] a dark pool with a Hollow in it for 10 s loses its people (%d); a helper relights a lamp" % lost)


## The Early Bell Omen (N-7.5.3): Lantern Night and its lighting come a moon sooner, and the
## calendar shows it there.
func _early_bell() -> void:
	_fresh(30, 0)
	run.life["omens"] = ["early_calamity"]
	var lighting: Array = run.fixed_events().filter(func(e): return e["id"] == "lantern_lighting")
	var shown: Dictionary = _calendar()
	if slice.calamity.day("lantern_night") != 56 or lighting.is_empty() or int(lighting[0]["at_day"]) != 56 or int(shown["day"]) != 56:
		failures.append("the Early Bell should move Lantern Night and its lighting to day 56 (%d, %s, %s)" % [slice.calamity.day("lantern_night"), str(lighting), str(shown)])
	else:
		print("[calamity] the Early Bell moves Lantern Night and its lighting a moon sooner, on the calendar too")
	run.life["omens"] = []


## Later lives (N-7.5.3): each Held life brings the next variant; each has its answer.
func _variants() -> void:
	_fresh(84, 2)
	run.soul["calamity_held"] = {"lantern_night": 1}
	slice.world.load_map("camp")
	run.learn("drain_cut")
	slice.next_period()
	_play_through(["cellar grate"])
	if slice.calamity.variant("lantern_night") != 1 or not run.flag("cut_stopped"):
		failures.append("variant 1: waiting at the cellar grate should stop the cut (%d)" % slice.calamity.variant("lantern_night"))
	_fresh(84, 2)
	run.soul["calamity_held"] = {"lantern_night": 2}
	slice.world.load_map("camp")
	slice.fight_resolver = func(_id): return true
	slice.next_period()
	var early_onset: bool = str(slice.cur.get("id", "")) == "lantern_night_onset"
	_play_through([])
	if not early_onset or not run.knows("early_cut"):
		failures.append("variant 2: the Onset should come at Dusk, and teach why (%s)" % str(early_onset))
	_fresh(84, 2)
	run.soul["calamity_held"] = {"lantern_night": 2}
	run.learn("early_cut")
	if slice.story.event_at("great_lamp") != "coupling_watch":
		failures.append("variant 2: knowing it, you can sit at the coupling in the afternoon")
	_fresh(84, 4)
	run.soul["calamity_held"] = {"lantern_night": 3}
	slice.world.load_map("camp")
	slice._effect("calamity_onset", "lantern_night")
	var bribed: bool = run.flag("helper_bribed")
	_fresh(84, 4)
	run.soul["calamity_held"] = {"lantern_night": 3}
	run.set_flag("helper_read")
	slice._effect("calamity_onset", "lantern_night")
	if not bribed or run.flag("helper_bribed"):
		failures.append("variant 3: a helper is bought unless you read them first")
	slice.fight_resolver = Callable()
	run.soul["calamity_held"] = {}
	if failures.is_empty():
		print("[calamity] later lives: the cellar drain, the early cut and the bought helper, each with its answer")
