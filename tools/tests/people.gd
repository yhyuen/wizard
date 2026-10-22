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
## Minigames (§9; N-7.6.5): each game's core plays alone and ends (a sharp Star-charts player wins,
## one who always waits mostly loses; Sparks counts lamps as any face and only takes higher bids);
## free play is once a week and none in a calamity's week; a win pays the stake, gains bond, learns
## the tell for every life and, once a season, picks a rumour; work pays a wage and a rumour and
## costs half a day; a Star-charts opponent beaten in a past life pays for coin, never at dice.
## Companions (§4.4-4.5; N-7.6.6): one walks with you once Close (Brogan once home), follows you,
## fights beside you in 1 vs many only (a Cutter cuts a wind-up, a Guard shoves an enemy off you,
## their kills train nothing), a won fight is +2 bond once a day, a night talk plays as you wake
## (one a night), the Guide passes on a rumour on reaching a region once a season; at most three
## Sworn a life.
## Confrontations (§11; N-7.6.7): every scene can be won with its evidence; a miss costs a lamp
## (never in your first, never in a soft talk), a near costs nothing, three misses lose it; pressing
## can show a hidden statement; the scene closes into its story outcome, and a won scene's breaks
## are remembered next life.

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
	_minigames()
	_companions()
	_confronts()
	for f in failures:
		print("[people] FAIL: " + f)
	if failures.is_empty():
		print("[people] bonds, rumours, commissions, the ladder, the minigames, companions and confrontations hold")
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


func _minigames() -> void:
	slice.new_month()
	slice.finish_scene()
	slice.world.load_map("camp")
	var g = slice.games
	var SC = g.StarCharts
	var SP = g.Sparks
	# Star-charts alone: a sharp player always wins; one who always waits mostly loses to Marrow.
	var sharp := 0
	var slow := 0
	for seed_ in 20:
		if SC.new(g.d["star_charts"], g.opp("wren"), seed_, {}).bot(1.0):
			sharp += 1
		if SC.new(g.d["star_charts"], g.opp("marrow"), seed_, {}).bot(0.0):
			slow += 1
	_check(sharp == 20 and slow < 8, "Star-charts: a sharp player wins (%d/20), a waiting one mostly loses (%d/20)" % [sharp, slow])
	var easy = SC.new(g.d["star_charts"], g.opp("wren"), 3, {}, true)
	_check(easy.struck >= 0 and easy.options()[easy.struck] != easy.riddle()["answer"] and easy.tell, "easy mode strikes out a wrong answer and shows the tell")
	var told = SC.new(g.d["star_charts"], g.opp("wren"), 3, {}, false, true)
	var hush: bool = told.sign() == "" if told.stage < told.buzz[0] else true
	while told.stage < told.buzz[0]:
		told.wait()
	_check(hush and told.sign() != "", "the tell shows only when they're about to answer")
	# Sparks alone: lamps count, bids only go up, every game ends, the same seed plays the same game.
	_check(SP.count([1, 5, 5, 3], 5) == 3 and SP.count([1, 1, 4], 1) == 2, "lamps count as any face, but only as themselves when bid")
	var sp = SP.new(g.d["sparks"], g.opp("mira"), 5)
	sp.bid = [2, 5]
	_check(sp.legal(2, 6) and not sp.legal(2, 4) and sp.legal(3, 2) and sp.min_on(4) == 3, "a bid must be more dice, or as many on a higher face")
	var ends := true
	var same := true
	var wins := 0
	for seed_ in 20:
		var a = SP.new(g.d["sparks"], g.opp("pell"), seed_)
		var w: bool = a.bot(1.0)
		ends = ends and a.over()
		same = same and SP.new(g.d["sparks"], g.opp("pell"), seed_).bot(1.0) == w
		wins += 1 if w else 0
	_check(ends and same and wins > 0 and wins < 20, "Sparks games end, play the same by seed, and go both ways (%d/20)" % wins)
	# The frame in the camp: Star-charts only at Dusk and Night; Sparks any time.
	run.life["day"] = 10
	run.life["time"] = 1
	var chs: Array = slice.story.choices(slice.story.scenes["wren"])
	_check(not chs.any(func(c): return c["target"] == "charts_wren"), "no Star-charts by day")
	run.life["time"] = 3
	chs = slice.story.choices(slice.story.scenes["wren"])
	_check(chs.any(func(c): return c["target"] == "charts_wren") and not chs.any(func(c): return c["target"] == "charts_wren_coin"), "Star-charts at Dusk; no coin before you've won")
	# A win: the stake, the bond, the tell for every life; once a week.
	slice.game_resolver = func(_core): return true
	var crowns := int(run.life.get("crowns", 0))
	var lamp := float(slice.bonds.state("mira")["lamp"])
	_play("sparks_mira")
	_check(int(run.life.get("crowns", 0)) == crowns + 4 and float(slice.bonds.state("mira")["lamp"]) > lamp, "a win pays the stake and gains bond")
	_check(g.tell_known("mira") and not g.open("mira") and not slice.story.test("game_open(\"mira\")"), "the tell is learned; one free game a week")
	_check(slice.story.test("minigame_beaten(\"mira\")"), "minigame_beaten() reads it")
	run.life["day"] = 15
	_check(g.open("mira"), "free play again the next week")
	# The first win in a season picks a rumour; the second doesn't.
	var first: Dictionary = g.finish("pell", "free", true, null, "camp")
	var again: Dictionary = g.finish("pell", "free", true, null, "camp")
	_check(not first["pick"].is_empty() and again["pick"].is_empty(), "a first win this season offers a pick, once (%s)" % str(first["pick"]))
	var picked: String = g.pick("person", "camp")
	_check(picked != "" and str(slice.rumours.rec(picked)["kind"]) == "person" and slice.rumours.heard(picked), "the pick hears a rumour of that kind")
	# Work: a wage, a rumour, half a day.
	slice.world.requests.clear()
	crowns = int(run.life.get("crowns", 0))
	var heard: int = run.soul.get("rumours", {}).size()
	slice.game_resolver = func(_core): return false
	_play("sparks_kestrel_work")
	_check(int(run.life.get("crowns", 0)) == crowns + 6 and run.soul.get("rumours", {}).size() == heard + 1, "work pays its wage and a rumour, win or lose")
	_check(slice.world.requests.filter(func(q): return q["t"] == "period").size() == 2 and not g.work_open("kestrel"), "work costs half a day, once a day")
	# A loss costs the stake if you have it.
	crowns = int(run.life.get("crowns", 0))
	_play("sparks_mira")
	_check(int(run.life.get("crowns", 0)) == crowns - 4, "a loss costs the stake")
	# No games in a calamity's week.
	run.life["day"] = 80
	_check(not g.open("wren") and not g.work_open("kestrel"), "no games in a calamity's week")
	# Star-charts answers carry; beaten in a past life, they pay for coin (never at dice).
	run.life["day"] = 17
	var sc = g.start("wren", "free")
	sc.bot(1.0)
	g.finish("wren", "free", true, sc, "camp")
	slice.game_resolver = Callable()
	slice.world.requests.clear()
	slice.end_loop("turned")
	slice.wake()
	run.life["day"] = 10
	run.life["time"] = 3
	var charts: Dictionary = run.soul.get("charts", {})
	var again_sc = SC.new(g.d["star_charts"], g.opp("wren"), 0, charts)
	while not again_sc.over() and not again_sc.remembered():
		again_sc.wait()
	_check(charts.size() >= 2 and (again_sc.remembered() or not again_sc.order.any(func(id): return charts.has(id))), "Star-charts answers carry (%s)" % str(charts.keys()))
	_check(g.coin_open("wren") and not g.coin_open("mira") and g.tell_known("mira"), "coin for Star-charts, never for dice; tells carry")
	crowns = int(run.life.get("crowns", 0))
	_play("charts_wren_coin")
	_check(int(run.life.get("crowns", 0)) == crowns + 5 and not g.open("wren"), "playing for coin pays the stake and takes the week's game")


func _companions() -> void:
	slice.new_month()
	slice.finish_scene()
	slice.world.load_map("camp")
	var c = slice.companions
	var b = slice.bonds
	run.life["day"] = 10
	run.life["time"] = 1
	_check(not c.can_join("mira"), "nobody walks with you before Close")
	b.gain("mira", "story", "a", 100)
	b.cross("mira")
	b.gain("brogan", "story", "a", 100)
	b.cross("brogan")
	_check(c.can_join("mira") and not c.can_join("brogan"), "Close opens the walk; Brogan waits until he's home")
	_check(slice.story.choices(slice.story.scenes["mira"]).any(func(ch): return ch["target"] == "walk_mira"), "Mira offers to walk with you")
	_play("walk_mira")
	_check(c.who() == "mira" and slice.story.test("companion() == \"mira\""), "Mira walks with you")
	run.set_flag("brogan_home")
	_check(not c.can_join("brogan"), "one companion at a time")
	var mp = slice.world.people.get_person("mira")
	mp.pos = slice.world.player_pos() + Vector2(600, 0)
	slice.world.people.think()
	_check(mp.on and mp.mode == "follow" and mp.pos.distance_to(slice.world.player_pos()) < 60.0, "your companion follows you (%s, %s)" % [mp.mode, str(mp.pos)])
	# In a fight: only 1 vs many; a Guide stays out.
	var A = main.arena
	_check(A._ally_for({"hits": 3}) == null and A._ally_for({}) != null, "a companion fights in 1 vs many, never a duel")
	var Ally = A.Ally
	var cut = Ally.new(A, "mira", c.rec("mira"), A.player.pos + Vector2(10, 0), 72.0)
	var foe = A.spawn("hollow", A.player.pos + Vector2(24, 0))
	foe.state = "windup"
	foe.state_t = 1.0
	cut.tick(0.05)
	_check(cut.helps == 1 and foe.state != "windup", "a Cutter cuts short a wind-up near you (%s)" % foe.state)
	var kills: int = A.stats["kills"]
	foe.hp = 1.0
	cut._hit(foe, 5.0, 1, 0.0)
	_check(foe.dead and A.stats["kills"] == kills, "what a companion finishes trains nothing of yours")
	var guard = Ally.new(A, "brogan", c.rec("brogan"), A.player.pos, 72.0)
	var foe2 = A.spawn("hollow", A.player.pos + Vector2(20, 0))
	guard.tick(0.05)
	_check(guard.helps == 0, "a Guard waits while you stand")
	A.player.hp = A.player.max_hp * 0.2
	guard.tick(0.05)
	_check(guard.helps == 1 and foe2.vel.length() > 50.0, "a Guard shoves the nearest enemy off you when you're low")
	A.player.hp = A.player.max_hp
	for u in A.enemies():
		u.dead = true
	# A fight won together: +2 bond, once a day.
	var lamp := float(b.state("mira")["lamp"])
	slice.fight_id = "com_goat"
	slice.cur = {"steps": [], "choices": [], "outcomes": {}}
	slice.idx = 0
	slice.fight_done(true)
	slice.cur = {"steps": [], "choices": [], "outcomes": {}}
	slice.idx = 0
	slice.fight_done(true)
	_check(float(b.state("mira")["lamp"]) - lamp == 2.0, "a fight won together is +2 bond, once a day (%s)" % str(float(b.state("mira")["lamp"]) - lamp))
	slice.finish_scene()
	# A night talk as you wake, one a night.
	slice.world.requests.clear()
	slice.begin_day()
	_check(slice.world.requests.any(func(q): return q.get("id", "") == "night_mira_1"), "a night talk plays as you wake")
	run.mark_seen("night_mira_1")
	_check(c.next_talk() == "", "one night talk a night")
	run.life["day"] = 11
	_check(c.next_talk() == "night_mira_2", "the next night, the next talk")
	# The Guide's road sense: a rumour on reaching a region, once a season.
	_play("part_mira")
	slice.world.people.think()
	_check(c.who() == "" and mp.mode != "follow", "parting sends them home")
	b.gain("wren", "story", "a", 100)
	b.cross("wren")
	_play("walk_wren")
	_check(A._ally_for({}) == null, "a Guide stays out of the fight")
	var pool: String = slice.rumours.pool_now("camp")
	var has_one: bool = slice.rumours.draw(pool) != ""
	var got: String = c.region_rumour("camp")
	_check((got != "") == has_one and c.region_rumour("camp") == "", "the Guide passes on a rumour on reaching a region, once a season")
	# At most three Sworn a life.
	for who in ["pell", "fennick", "silas"]:
		b.state(who)["tier"] = 5
		b.state(who)["lamp"] = 100.0
	b.state("marrow")["tier"] = 4
	b.state("marrow")["lamp"] = 100.0
	_check(b.sworn() == 3 and b.ready_to_cross("marrow") and not b.cross("marrow"), "at most three Sworn a life")
	slice.end_loop("turned")
	slice.wake()
	_check(c.who() == "", "a new life walks alone")


func _confronts() -> void:
	slice.new_month()
	slice.finish_scene()
	var Confront = slice.Confront
	var rec: Dictionary = Confront.load_scene("pell_lamps")
	var all: Array = rec["evidence"].map(func(e): return e["id"])
	_check(Confront.new(rec, all).bot() == "won", "a confrontation can be won with all its evidence")
	# Press can show a hidden statement.
	var cf = Confront.new(rec, all)
	var hidden: Array = rec["statements"].filter(func(x): return x.get("hidden", false)).map(func(x): return x["id"])
	_check(not cf.statements().any(func(x): return x["id"] in hidden), "hidden statements start hidden")
	for x in cf.statements():
		cf.press(x["id"])
	_check(cf.statements().any(func(x): return x["id"] in hidden), "pressing shows a hidden statement")
	# Near costs nothing; a miss costs a lamp; three misses and it's lost.
	var b0: Dictionary = rec["breaks"][0]
	var b1: Dictionary = rec["breaks"][1]
	_check(cf.present(b1["evidence"], b0["statement"]) == "near" and cf.lamps == 3, "right evidence at the wrong statement is near, and free")
	var wrong = Confront.new(rec, all)
	var junk: String = b0["evidence"]
	var at := ""
	for x in wrong.statements():
		if not rec["breaks"].any(func(b): return b["evidence"] == junk and b["statement"] == x["id"]):
			at = x["id"]
	wrong.broken[b0["statement"]] = junk  # the evidence's own break is spent: now it only misses
	_check(wrong.present(junk, at) == "miss" and wrong.lamps == 2, "a miss costs a lamp (%d)" % wrong.lamps)
	wrong.present(junk, at)
	wrong.present(junk, at)
	_check(wrong.result == "lost" and wrong.lamps == 0, "three misses and the lamps are out")
	var first = Confront.new(rec, all, 1)
	first.broken[b0["statement"]] = junk
	first.present(junk, at)
	_check(first.lamps == 3, "the first confrontation's miss is free")
	var soft = Confront.new(Confront.load_scene("cass_drawings"), ["silas"])
	for x in soft.statements():
		soft.present("silas", x["id"])
	_check(soft.lamps == 3 and soft.result == "", "a soft talk never loses a lamp")
	for fn in DirAccess.get_files_at(Confront.DIR):
		if fn.ends_with(".json"):
			_check(Confront.check(Confront.load_scene(fn.get_basename())).is_empty(), "the data check passes for " + fn)
	# In the story: the scene opens after Lantern Night with what you hold, and closes into its outcome.
	run.life["day"] = slice.calamity.day("lantern_night") + 1
	slice._effect("learn", "pell_lips")
	slice._effect("learn", "pell_children")
	run.set_flag("oil_grey")
	_check(slice.story.choices(slice.story.scenes["pell_confront_ask"]).any(func(ch): return ch["target"] == "pell_confront") and slice.story.test("confronted(\"pell_lamps\") == \"\""), "after Lantern Night you can ask Pell about the lamps")
	var held: Array = []
	slice.confront_resolver = func(c):
		held.append_array(c.have)
		c.bot()
		return "bargain"
	_play("pell_confront")
	_check(not "mira" in held and "grey_oil" in held and "lips" in held, "you present only what you hold (%s)" % str(held))
	_check(slice.story.test("confronted(\"pell_lamps\") == \"bargain\"") and run.flag("pell_bargain"), "the close you choose runs its outcome")
	_check(not run.soul.get("confront_breaks", {}).get("pell_lamps", {}).is_empty(), "a won scene's breaks are remembered")
	slice.confront_resolver = Callable()
	slice.end_loop("turned")
	slice.wake()
	_check(slice.story.test("confronted(\"pell_lamps\") == \"\""), "a new life can confront again")
	var again = Confront.new(rec, all, 0, run.soul["confront_breaks"]["pell_lamps"])
	_check(not again.hints.is_empty() and again.broken.is_empty(), "next life shows the old breaks as hints, nothing broken")


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
