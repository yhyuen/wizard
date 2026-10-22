extends SceneTree
## People's systems: bonds (people spec §4-5; N-7.6.1) and rumours (§10; N-7.6.2):
##
##   godot --headless --script res://tools/tests/people.gd
##
## A first talk makes you Warm; gains climb to Friendly by themselves and stop at Close's door until
## its scene; once-per-key and once-a-week caps hold; a loss stops at the bottom of the tier and
## betrayal drops one; light people stop at Close and role people have no track; a gift's gain is
## by taste and its reaction is learned for every life; Close in one life starts the next at Warm.
## Overhearing gives a rumour once, pins its date on the calendar and keeps it for later lives;
## a pool draws the unheard rumour pointing at the soonest event.
## Commissions (§6; N-7.6.3): the board posts in a window and not in a calamity's week; a job is
## taken, its fight moves it on, a lost fight opens the slow way at half pay, the matter hook pays
## +50% unless what it spares burned, the board pays, and a later life knows the way (no time).
## The ladder (§7.1; N-7.6.4): challenge only at Dusk and once a week, a win takes the rung and its
## purse, a loss costs no days, and a beaten duelist's book is known next life.

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


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _go() -> void:
	slice = main.slice
	slice.new_month()
	slice.finish_scene()
	var b = slice.bonds
	run.life["day"] = 10
	# A first talk: Warm, once a life.
	b.gain("mira", "first_talk")
	_check(b.tier("mira") == 1 and int(b.state("mira")["lamp"]) == 10, "a first talk should make you Warm (%s)" % str(b.state("mira")))
	_check(b.gain("mira", "first_talk") == 0.0, "a first talk counts once a life")
	# Kindness climbs to Friendly by itself; a key counts once.
	b.gain("mira", "kindness", "lamps")
	_check(b.gain("mira", "kindness", "lamps") == 0.0, "a kindness counts once per key")
	b.gain("mira", "kindness", "oil")
	_check(b.tier("mira") == 2, "40 lamp is Friendly (%s)" % str(b.state("mira")))
	# A spar: once a week.
	_check(b.gain("mira", "spar") == 3.0 and b.gain("mira", "spar") == 0.0, "a spar counts once a week")
	run.life["day"] = 17
	_check(b.gain("mira", "spar") == 3.0, "a spar counts again the next week")
	# The lamp stops at Close's door until its scene.
	b.gain("mira", "calamity", "lantern_night")
	b.gain("mira", "story", "s1", 40)
	_check(b.tier("mira") == 2 and int(b.state("mira")["lamp"]) == 60 and b.ready_to_cross("mira"), "the lamp should wait at Close's door (%s)" % str(b.state("mira")))
	_check(b.cross("mira") and b.tier("mira") == 3, "the crossing scene opens Close")
	# A loss stops at the bottom of the tier; betrayal drops one.
	b.gain("mira", "values_against", "x")
	_check(int(b.state("mira")["lamp"]) == 60 and b.tier("mira") == 3, "a loss stops at the bottom of the tier")
	b.betray("mira")
	_check(b.tier("mira") == 2 and int(b.state("mira")["lamp"]) == 30, "betrayal drops a tier")
	# Light people stop at Close; role people have no track.
	b.gain("bett", "story", "a", 100)
	b.cross("bett")
	b.gain("bett", "story", "b", 100)
	_check(b.tier("bett") == 3 and not b.cross("bett"), "a light person stops at Close (%s)" % str(b.state("bett")))
	_check(b.gain("dog", "kindness", "bone") == 0.0 and b.tier("dog") == 0, "role people have no track")
	# Gifts by taste, once a week; the reaction is learned.
	var before: float = float(b.state("wren")["lamp"])
	_check(b.gift("wren", "old_book") == "love" and float(b.state("wren")["lamp"]) - before == 12.0, "Wren loves a book: +12")
	_check(b.gift("wren", "honey_cake") == "", "one gift a week")
	_check(b.tastes_known("wren").get("old_book", "") == "love", "the reaction is learned")
	_check(b.taste("bett", "spirit_flask") == "cant_bear", "Bett can't bear drink")
	# The story: bond() and the effects.
	slice._effect("bond", "fennick kindness rails")
	_check(slice.story.test("bond(\"fennick\") == 1") and int(b.state("fennick")["lamp"]) == 15, "the bond effect gains (%s)" % str(b.state("fennick")))
	slice._effect("bond", "fennick first_talk")
	_check(slice.story.test("bond(\"fennick\") == 2"), "bond() reads the tier")
	# Floors: Close in this life starts the next at Warm; tastes carry.
	slice.end_loop("turned")
	slice.wake()
	_check(slice.bonds.tier("mira") == 1 and slice.bonds.tier("bett") == 1 and slice.bonds.tier("fennick") == 0, "Close starts the next life at Warm (%d, %d, %d)" % [slice.bonds.tier("mira"), slice.bonds.tier("bett"), slice.bonds.tier("fennick")])
	_check(slice.bonds.tastes_known("wren").get("old_book", "") == "love", "tastes carry")
	_rumours()
	_commissions()
	_ladder()
	for f in failures:
		print("[people] FAIL: " + f)
	if failures.is_empty():
		print("[people] bonds, rumours, commissions and the ladder hold")
	quit(1 if not failures.is_empty() else 0)



func _rumours() -> void:
	slice.new_month()
	slice.finish_scene()
	var r = slice.rumours
	run.life["day"] = 21
	run.life["time"] = 3
	_check(r.draw("camp:m1-3") == "r_iron_gate", "the pool should draw the rumour of the soonest event ahead (%s)" % r.draw("camp:m1-3"))
	_check(slice.story.event_at("inn") == "overhear_iron_gate", "the squire talks at the inn at Dusk (%s)" % slice.story.event_at("inn"))
	slice.play("overhear_iron_gate")
	var known := false
	for e in slice.reach.events():
		if e["id"] == "iron_gate_shuts":
			known = e["known"]
	_check(r.heard("r_iron_gate") and known, "overhearing gives the rumour and pins the date")
	_check(r.of_kind("date").size() == 1 and not r.of_kind("date")[0]["earlier"], "the Ledger lists it as this year's")
	slice.end_loop("turned")
	slice.wake()
	run.life["day"] = 21
	run.life["time"] = 3
	_check(slice.story.event_at("inn") == "", "a rumour heard in any life isn't overheard again")
	_check(r.of_kind("date")[0]["earlier"], "next life it's from another year")


func _commissions() -> void:
	slice.new_month()
	slice.finish_scene()
	var c = slice.commissions
	run.life["day"] = 5
	_check(c.posted("c1_goat") and not c.posted("c2_bramble") and not c.posted("c3_round") and c.posted("c8_letters"), "the board posts in each job's window")
	_check(slice.story.use_scene("board") == "board" and slice.story.use_scene("duty_slate") == "duty_slate", "the board and the slate can be read")
	slice.play("c1_take")
	slice.finish_scene()
	_check(c.step("c1_goat") == 0 and not c.posted("c1_goat") and slice.job_line().begins_with("The Lost Goat"), "taking a job puts it on the jobs line (%s)" % slice.job_line())
	# A lost fight: the step stays open, and the slow way opens.
	c.lose("c1_goat")
	var slow_offered: bool = slice.story.choices(slice.story.scenes["com_c1_here"]).any(func(ch): return ch["target"] == "com_c1_slow")
	_check(c.step("c1_goat") == 0 and slow_offered, "a lost fight leaves the step open, with the slow way")
	# The fight in the orchard moves it on; the hook holds while the hay is whole.
	slice.world.load_map("fields")
	slice.fight_resolver = func(_id): return true
	slice.play("com_c1_go")
	var n := 0
	while not slice.cur.is_empty() and n < 10:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
		else:
			slice.finish_scene()
	slice.fight_resolver = Callable()
	_check(c.step("c1_goat") == 1 and c.is_clean("c1_goat"), "winning in the orchard moves the job on, clean (%d, %s)" % [c.step("c1_goat"), str(c.is_clean("c1_goat"))])
	slice.play("c1_pay")
	slice.finish_scene()
	_check(c.done("c1_goat") and int(run.life.get("crowns", 0)) == 38, "the board pays 25 +50%% for a clean job (%d)" % int(run.life.get("crowns", 0)))
	# The bramble: burn the fence and the bonus is gone; the slow way pays half.
	run.life["day"] = 10
	slice.play("c2_take")
	slice.finish_scene()
	for p in slice.world.props:
		if p["kind"] == "fence" and Rect2(1550, 400, 900, 620).has_point(p["pos"]):
			p["state"] = "ash"
			break
	c.lose("c2_bramble")
	slice.play("com_c2_slow")
	slice.finish_scene()
	_check(c.step("c2_bramble") == 1 and not c.is_clean("c2_bramble"), "a burned fence loses the hook")
	_check(c.pay_of("c2_bramble") == 15, "the slow way pays half (%d)" % c.pay_of("c2_bramble"))
	# Letters: three steps, no fights.
	slice.play("c8_take")
	slice.finish_scene()
	run.life["day"] = 12
	slice.play("com_c8_picket")
	slice.finish_scene()
	slice.play("com_c8_bell")
	slice.finish_scene()
	_check(c.step("c8_letters") == 2 and slice.story.test("commission_step(\"c8_letters\") == 2"), "each letter moves the job on")
	# Nothing is posted in the week before a calamity.
	run.life["day"] = 80
	_check(c.posted_at("board").is_empty() and slice.story.test("commission_board_empty()"), "nothing posted in a calamity's week")
	# A later life knows the way: the answer shows, and the work costs no time.
	slice.world.load_map("camp")
	slice.end_loop("turned")
	slice.wake()
	_check(c.known("c1_goat") and not c.known("c2_bramble") and c.step("c1_goat") == -1, "a paid job is known next life, and posted again")
	slice.after = []
	slice._effect("commission", "c1_goat work")
	_check(not "period" in slice.after, "a known job's work costs no time")
	slice._effect("commission", "c2_bramble work")
	_check("period" in slice.after, "an unknown job's work takes the time of day")
	slice.after = []


func _ladder() -> void:
	slice.new_month()
	slice.finish_scene()
	var l = slice.ladder
	run.life["day"] = 10
	run.life["time"] = 1
	var ch: Array = slice.story.choices(slice.story.scenes["ladder_post"])
	_check(slice.story.use_scene("ladder_post") == "ladder_post" and not ch.any(func(c): return c["target"] == "ladder_1"), "no bouts but at Dusk")
	run.life["time"] = 3
	ch = slice.story.choices(slice.story.scenes["ladder_post"])
	_check(ch.any(func(c): return c["target"] == "ladder_1") and not ch.any(func(c): return c["target"] == "ladder_2"), "at Dusk you challenge the first rung only")
	slice.fight_resolver = func(_id): return true
	_play("ladder_1")
	_check(l.rung() == 1 and int(run.life.get("crowns", 0)) == 10, "a win takes the rung and its purse (%d, %d)" % [l.rung(), int(run.life.get("crowns", 0))])
	_check(not l.open(), "one bout a week")
	run.life["day"] = 17
	slice.fight_resolver = func(_id): return false
	var day_before: int = run.day()
	_play("ladder_2")
	_check(l.rung() == 1 and run.day() == day_before and slice.screen == "world", "a loss keeps your rung and costs no days")
	slice.fight_resolver = Callable()
	slice.end_loop("turned")
	slice.wake()
	_check(l.rung() == 0 and l.book_known(1) and not l.book_known(2), "the rung resets; a beaten duelist's book carries")
	_check(slice.story.test("ladder_book(1)"), "ladder_book() reads it")


## Plays a scene through its fight, taking the first choice anywhere else.
func _play(id: String) -> void:
	slice.play(id)
	var n := 0
	while not slice.cur.is_empty() and n < 10:
		n += 1
		if not slice.pending.is_empty():
			slice.advance()
		elif slice.opts.size() > 0:
			slice.choose(0)
		else:
			slice.finish_scene()
