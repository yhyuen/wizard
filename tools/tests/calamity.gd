extends SceneTree
## The calamity frame (seasons spec §6, §8, §10.2; N-7.5.1) with Lantern Night:
##
##   godot --headless --script res://tools/tests/calamity.gd
##
## Two signs pin a "?" on Seedmoon 28 and a rest stops on its Eve; resting through it unpinned lets
## it pass without you (Fallen), and four preparations raise that to Scarred; standing in the camp
## at Night plays the Onset and the Peak; surviving it with 16 lamps lit is Held (which opens the
## Lamplighter road for the next life); losing the Peak ends the life; after the Dawn tally, Ring 1's
## end card ends the life, and the next life knows the date by name.

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
	_present()
	_lost()
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


func _present() -> void:
	_fresh(84, 3)
	slice.world.load_map("camp")
	slice.fight_resolver = func(_id):
		var n := 0
		for l in slice.world.lamps:
			if l["circuit"] != "" and n < 16:
				l["lit"] = true
				l["by"] = "you"
				n += 1
		return true
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
	if slice.screen != "tally" or str(t.get("tier", "")) != "held" or int(t.get("lamps", 0)) != 16:
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
