extends SceneTree
## Unit checks for progression rules, headless:  godot --headless --script res://tools/tests/unit.gd

var fails := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("[unit] FAIL: " + what)


func _run() -> void:
	var P = root.get_node("Progression")
	P.save_enabled = false
	P.reset_all()
	# Stat tracks.
	ok(is_equal_approx(P.stat("ember_bolt", "speed", 1), 200.0), "Ember Bolt speed at Lv 1 is 200")
	ok(is_equal_approx(P.stat("ember_bolt", "speed", 3), 218.0), "Ember Bolt speed at Lv 3 is 218")
	ok(P.stat("pyroclasm", "bounces", 1) == 4.0 and P.stat("pyroclasm", "bounces", 15) == 8.0, "Pyroclasm bounces 4 to 8")
	ok(P.stat("pillar", "delay", 15) >= 0.5, "Pillar delay is clamped at 0.5 s")
	for lv in [1, 10, 15]:
		ok(P.stat("pillar", "delay", lv) >= P.fair_delay(P.stat("pillar", "radius", lv)) - 0.0001, "Pillar at Lv %d is dodgeable at wizard speed" % lv)
	ok(is_equal_approx(P.fair_delay(15.0), 0.25 + 20.0 / 72.0), "the dodge rule: 0.25 s + (radius + body) / speed")
	# Cadence scales the spell being cast, and only that spell.
	P.boost = {"id": "pillar", "damage": 0.7, "size": 1.3, "count": 1}
	ok(is_equal_approx(P.stat("pillar", "radius"), 15.0 * 1.3) and is_equal_approx(P.stat("pillar", "damage"), 24.0 * 0.7), "a boost scales the cast spell's size and damage")
	ok(is_equal_approx(P.stat("pillar", "radius", 1), 15.0), "a boost never touches an explicit level (ghost previews)")
	ok(is_equal_approx(P.stat("ember_bolt", "damage"), 16.0), "a boost leaves other spells alone")
	P.boost = {"id": "pyroclasm", "damage": 1.0, "size": 1.0, "count": 1}
	ok(P.stat("pyroclasm", "bounces") == 5.0, "a Resonant cast adds one to a count")
	P.boost = {}
	ok(P.stone_cap() == 3, "the stone cap starts at 3")
	# XP and levels.
	P.add_xp("ember_bolt", 8.0)
	ok(P.level("ember_bolt") == 2, "8 XP levels Ember Bolt to 2")
	P.add_xp("ember_bolt", 1000.0)
	ok(P.level("ember_bolt") == 20, "levels cap at 20")
	ok(P.pending.size() == 3, "levels 5, 10 and 15 each queue a pick (got %d)" % P.pending.size())
	P.pick(1)
	ok(P.has_mut("ember_bolt", "ember_ignite"), "picking option 2 at Lv 5 gives Ember Ignite")
	P.pick(0)
	P.pick(0)
	ok(P.pending.is_empty(), "every pick is consumed")
	ok(P.mut_names("ember_bolt").size() == 3, "three mutations on Ember Bolt")
	# Single-option milestones apply on their own.
	P.set_level("avalanche", 15)
	ok(P.has_mut("avalanche", "cap_plus"), "Avalanche Lv 15 grants Mountain without a pick")
	ok(P.stone_cap() == 7, "the stone cap reaches 7 (got %d)" % P.stone_cap())
	P.pending.clear()
	# Mastery and the Magick.
	ok(P.mastery("earth") == 1 + 1 + 15, "Earth mastery is the sum of its spell levels")
	ok(P.magick_level("meteor") == mini(P.mastery("fire"), P.mastery("earth")) / 3, "Meteor levels with the lower mastery")
	# The loop: spells stay, wizard level halves.
	P.p["wizard_level"] = 7
	P.next_loop()
	ok(P.loop() == 2, "the loop advances")
	ok(P.wizard_level() == 3, "wizard level 7 drops to 3")
	ok(P.level("ember_bolt") == 20, "spell levels survive the loop")
	ok(P.blink_charges(1) == 1 and P.blink_charges(3) == 2 and P.blink_charges(6) == 3, "blink charges at 1, 3, 6")
	# The spellbook: four spells from any sphere (spell and combat spec §5.1).
	P.reset_all()
	ok(P.spellbook() == ["ember_bolt", "pillar", "pebble", "pyroclasm"], "the first loop starts with Mars and Jupiter spells")
	ok(P.loadout() == ["fire", "earth"], "the book's spheres are Mars and Jupiter")
	P.set_spell(1, "arc_lance")
	ok(P.spellbook()[1] == "arc_lance" and P.loadout() == ["fire", "storm", "earth"], "any spell goes in any slot, and its sphere joins the book")
	P.set_spell(0, "pebble")
	ok(P.spellbook()[0] == "pebble" and P.spellbook()[2] == "ember_bolt", "a spell already in the book swaps slots")
	ok(P.valid_book(P.spellbook(), P.data["spells"]), "the book stays four different spells")
	ok(not P.valid_book(["spark", "spark", "pillar", "fling"], P.data["spells"]), "a book with a spell twice is invalid")
	ok(not P.valid_book(["ember_bolt", "pebble", "pillar", "fling", "pyroclasm", "avalanche"], P.data["spells"]), "a six-spell book (an old save) is invalid")
	P.set_loadout("fire", "earth")
	ok(P.spell_for("storm", "bolt") == "spark" and P.spell_for("water", "signature") == "maelstrom", "each element has a bolt, control and signature")
	ok(P.magick_for(["water", "storm"]) == "conductor" and P.magick_for(["earth", "fire"]) == "meteor", "a pair finds its Magick in either order")
	ok(P.magick_for(["fire", "storm"]) == "", "a pair without a Magick has none")
	P.set_loadout("storm", "storm")
	ok(P.loadout() == ["fire", "earth"], "the same sphere twice is refused as a preset")
	P.set_loadout("storm", "water")
	ok(P.spellbook() == ["spark", "splash", "arc_lance", "undertow"], "a two-sphere preset fills the book")
	ok(not P.unlocked("rewind") and not P.open_elements().has("hours"), "Hours is not in loop 1")
	P.set_spell(0, "rewind")
	ok(not P.spellbook().has("rewind"), "a spell that has not come back yet cannot go in the book")
	P.set_echo([10, 20, 1, 0, 0, 30, 40, 1, 0, 1], false)
	ok(P.echo_track().is_empty(), "this loop's own fight is not its echo")
	P.next_loop()
	ok(P.spellbook().slice(0, 3) == ["spark", "splash", "arc_lance"], "the spellbook carries into the next loop")
	ok(P.spellbook()[3] == "rewind" and P.unlocked("rewind") and P.open_elements().has("hours"), "Rewind comes back with you in loop 2, in the last slot")
	ok(P.echo_track().size() == 10, "the last loop's fight becomes the echo")
	P.set_spell(3, "maelstrom")
	P.next_loop()
	ok(not P.spellbook().has("rewind"), "Rewind is only pushed into the book once")
	# Re-picking a mutation (only the shrine calls this).
	P.set_level("pillar", 5)
	P.pick(0)
	ok(P.has_mut("pillar", "knock_up"), "Pillar Lv 5 picks Updraft")
	P.repick("pillar", 5, 1)
	ok(P.has_mut("pillar", "pillar_embers") and not P.has_mut("pillar", "knock_up"), "re-picking swaps Updraft for Cinderfall")
	ok(P.repickable("pillar").size() == 1 and P.repickable("pillar")[0]["chosen"] == 1, "the shrine lists the pick and the current choice")
	P.set_level("avalanche", 15)
	P.pick(0)
	ok(P.repickable("avalanche").size() == 1, "single-option milestones are not re-pickable (only Lv 10 is listed)")
	# Tomes hint; they never teach the Magick.
	ok(P.tome_subject() == "conductor", "the tome hints at the equipped pair's Magick first")
	P.read_tome("conductor")
	ok(P.has_hint("conductor") and not P.knows("conductor"), "a tome gives a hint, not the Magick")
	ok(P.tome_subject() == "meteor", "the next tome hints at another unknown Magick")
	P.learn("meteor")
	ok(P.tome_subject() == "", "no tome once every Magick is known or hinted")
	P.next_loop()
	ok(P.has_hint("conductor"), "hints carry over loops")
	_mastery(P)
	_controls(P)
	_kit(P)
	_growth(P)
	_world()
	_year()
	print("[unit] %d check(s), %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _it(aim: Vector2, held := {}, pressed := {}, released := {}) -> Dictionary:
	return {"held": held, "pressed": pressed, "released": released, "aim": aim}


## The combat weight pass (spell and combat spec §3–5): wind-ups and recovery, cancel and commit,
## Focus, scarce Aether, Overdraw and Strain, rest, the Ward and the staff strike.
func _kit(P) -> void:
	P.reset_all()
	var A = load("res://scripts/arena.gd").new()
	root.add_child(A)
	var K = A.kit
	var dt := 1.0 / 60.0
	A.phase = "enc"
	K.rest()
	var foe: Unit = A.spawn("hollow", A.player.pos + Vector2(60, 0))
	var at: Vector2 = foe.pos
	# A Swift spell: a tap commits it, and it flies when its wind-up ends.
	var bolt: String = K.slot_of("ember_bolt")
	K.update(dt, _it(at, {bolt: true}, {bolt: true}))
	ok(not K.wind.is_empty() and A.projs.is_empty(), "pressing a spell starts its wind-up; nothing flies yet")
	K.update(dt, _it(at, {}, {}, {bolt: true}))
	ok(K.wind.get("commit", false), "a Swift spell let go early is committed")
	var a0: float = K.aether
	for i in 30:
		K.update(dt, _it(at))
	ok(A.projs.size() == 1 and A.player.cooldown("ember_bolt") > 2.0, "it casts when its wind-up ends, then cools down")
	ok(a0 - K.aether > 12.0, "Ember Bolt costs Aether (spent %.1f)" % (a0 - K.aether))
	ok(K.recover_t > 0.0 and is_equal_approx(K.move_mult(), 0.8), "a short recovery follows, at 80% speed")
	for i in 30:
		K.update(dt, _it(at))
	# A Weave let go early is cancelled with nothing spent; held through, it casts on release.
	var ps: String = K.slot_of("pillar")
	a0 = K.aether
	K.update(dt, _it(at, {ps: true}, {ps: true}))
	K.update(dt, _it(at, {}, {}, {ps: true}))
	ok(K.wind.is_empty() and A.player.cooldown("pillar") == 0.0 and K.aether >= a0, "a Weave let go early is cancelled, nothing spent")
	K.update(dt, _it(at, {ps: true}, {ps: true}))
	ok(is_equal_approx(K.move_mult(), 0.4), "winding up a Weave slows you to 40%")
	for i in 60:
		K.update(dt, _it(at, {ps: true}))
	K.update(dt, _it(at, {}, {}, {ps: true}))
	ok(A.player.cooldown("pillar") > 0.0, "held through its wind-up, Pillar casts on release")
	for i in 40:
		K.update(dt, _it(at))
	# Focus: a hit at your Focus doesn't break a wind-up; one above it does, for half the Aether.
	var rs: String = K.slot_of("pyroclasm")
	K.update(dt, _it(at, {rs: true}, {rs: true}))
	ok(is_equal_approx(K.move_mult(), 0.0), "an Incant roots you")
	A.hit(A.player, 1.0, 1, Vector2.RIGHT)
	ok(not K.wind.is_empty() and A.player.reaction == "", "a hit at your Focus neither breaks nor flinches a wind-up")
	A.player.iframes = 0.0
	a0 = K.aether
	A.hit(A.player, 1.0, 2, Vector2.RIGHT)
	ok(K.wind.is_empty() and is_equal_approx(a0 - K.aether, 22.5), "a hit above your Focus breaks it, for half its Aether")
	A.player.iframes = 0.0
	A.player.reaction = ""
	A.player.reaction_t = 0.0
	# Overdraw: HP and Strain; Strain lowers max Aether; a backlash at 50 Strain; rest clears it.
	K.aether = 0.0
	var hp0: float = A.player.hp
	K._pay(30.0)
	ok(is_equal_approx(hp0 - A.player.hp, 30.0) and is_equal_approx(K.strain, 30.0) and is_equal_approx(K.max_aether(), 70.0), "Overdraw costs 1 HP and 1 Strain a point; Strain lowers max Aether")
	A.player.hp = A.player.max_hp
	K._pay(25.0)
	ok(A.player.stun > 1.9, "an Overdraw at 50 Strain backlashes: a 2 s stun")
	K.rest()
	ok(K.strain == 0.0 and is_equal_approx(K.aether, 100.0), "rest clears Strain and fills Aether")
	A.player.stun = 0.0
	# Aether comes back at 3/s in a fight; out of one at 15/s, but only to 60%.
	K.aether = 0.0
	K._regen(1.0)
	ok(is_equal_approx(K.aether, 3.0), "Aether comes back at 3/s in a fight")
	A.phase = "explore"
	for i in 10:
		K._regen(1.0)
	ok(is_equal_approx(K.aether, 60.0), "out of a fight it refills at 15/s, only to 60%")
	# The Ward stops a hit from the front, not from behind; Impact 3 breaks it and staggers you.
	A.phase = "enc"
	K.rest()
	var front: Vector2 = A.player.pos + Vector2(30, 0)
	K.update(dt, _it(front, {"ward": true}, {"ward": true}))
	ok(K.warding, "holding the Ward raises it")
	hp0 = A.player.hp
	ok(not A.hit(A.player, 5.0, 1, Vector2.LEFT) and A.player.hp == hp0 and K.aether < 100.0, "the Ward stops a hit from the front, for Aether")
	ok(A.hit(A.player, 5.0, 1, Vector2.RIGHT) and A.player.hp < hp0, "but not one from behind")
	A.player.iframes = 0.0
	A.hit(A.player, 5.0, 3, Vector2.LEFT)
	ok(not K.warding and A.player.reaction == "stagger", "Impact 3 breaks the Ward and staggers you")
	A.player.reaction = ""
	A.player.reaction_t = 0.0
	# The staff strike: free, short, every 0.6 s.
	K.update(dt, _it(front))
	foe.pos = A.player.pos + Vector2(15, 0)
	foe.hp = foe.max_hp
	a0 = K.aether
	K.update(dt, _it(foe.pos, {"staff": true}, {"staff": true}))
	ok(foe.hp < foe.max_hp and K.staff_t > 0.5 and K.aether >= a0, "the staff strikes what's in front, for free")
	# A cantrip: instant, on charges.
	var c1: String = K.slot_spell("cant2")
	K.update(dt, _it(foe.pos, {}, {"cant2": true}))
	ok(c1 == "douse" and foe.wet_t > 0.0 and K.cant_charges["douse"] == 1, "Douse soaks what's under the cursor and uses a charge")
	P.spell_leveled.disconnect(K._on_leveled)
	K.modules.clear()
	K.fe = null
	K.sw = null
	A.free()
	P.reset_all()


## The slice's growth (design/slice/systems.md §2): wells and Rings, Ring-gated slots and tiers,
## Practice lent to Progression for a fight, the Echo and Fluency, and the loop reset.
func _growth(P) -> void:
	var R = root.get_node("Run")
	R.save_enabled = false
	R.new_run()
	var G = load("res://scripts/game/growth.gd").new(R, P)
	P.reset_all()
	var before: Dictionary = P.p
	ok(G.ring() == 0 and G.slots() == 2 and G.max_hp() == 100.0, "a new loop starts as an Apprentice: 2 slots, 100 Vitality")
	ok(G.slot_spell(0) == "ember_bolt" and G.slot_spell(1) == "pebble" and G.slot_spell(2) == "", "an Apprentice has two Bolt slots open")
	ok(not G.set_slot(0, "pillar"), "a Control needs the 1st Ring")
	ok(not G.set_slot(0, "splash"), "a Model you haven't studied can't go in the book")
	G.add_wells(30)
	ok(G.ring() == 0, "wells alone don't pass the yard trial")
	R.set_flag("ring1")
	ok(G.ring() == 1 and G.ring_stage_need() == "4 spells at Adept", "after the trial, 30 wells alone is only the 1st Ring: the 2nd needs four spells at Adept")
	for id in ["ember_bolt", "pebble", "pillar", "fling"]:
		G.practice()[id]["stage"] = 1
	ok(G.ring() == 2 and G.slots() == 3 and G.slot_spell(2) == "pillar", "with four at Adept, 30 wells is the 2nd Ring: 3 slots, Pillar open")
	ok(not G.needs_met("pyroclasm") or G.practice()["ember_bolt"]["stage"] >= 1, "Pyroclasm needs Ember Bolt and Pillar at Adept")
	G.practice()["pillar"]["stage"] = 0
	ok(not G.needs_met("pyroclasm") and G.needs_missing("pyroclasm") == ["Pillar at Adept"], "a missing prerequisite is named")
	G.practice()["pillar"]["stage"] = 1
	ok(G.max_hp() == 160.0 and G.max_aether() == 130.0 and G.blinks() == 2, "wells raise Vitality and Aether; the 2nd Ring adds a Blink")
	ok(G.set_slot(0, "fling") and G.book()[0] == "fling" and G.book()[3] == "ember_bolt", "putting a Model in a slot swaps it with where it was")
	ok(not G.set_slot(3, "ember_bolt"), "slot 4 waits for the 3rd Ring")
	R.learn("model_pyroclasm")
	ok(G.known_models().has("pyroclasm") and not G.can_cast("pyroclasm"), "a Signature can be known before the 4th Ring lets you cast it")
	# A fight borrows the loop's Practice and gives it back.
	G.begin_fight()
	ok(P.max_hp() == 160.0 and P.max_aether() == 130.0 and P.magick_for(["fire", "earth"]) == "", "in a slice fight Progression uses wells and has no Magicks")
	ok(P.slot_open(0) and not P.slot_open(3), "in a slice fight locked slots are closed")
	var w0: float = P.p["wizard_xp"]
	P.add_xp("fling", P.xp_needed(1))
	ok(P.level("fling") == 2 and P.p["wizard_xp"] == w0, "slice Practice levels a spell and no wizard level")
	G.end_fight()
	ok(P.p == before and P.rules.is_empty(), "the old progress is back after the fight")
	ok(G.level("fling") == 2, "the fight's Practice stays with this loop")
	ok(G.use_today("meditate") and not G.use_today("meditate"), "meditating is once a day")
	var got: Dictionary = G.train()
	ok(got.has("fling") and got.has("pillar") and not got.has("splash") and G.practice()["pillar"]["xp"] > 0.0, "training adds part of a level to the spells in open slots")
	# The life ends (the Turning) and a new one starts.
	R.life["day"] = 7
	G.loop_over()
	R.end_life("turned")
	R.wake()
	ok(G.wells() == 0 and G.ring() == 0 and G.level("fling") == 1, "waking resets wells, the Ring and Practice")
	ok(G.echo()["fling"] == 2 and is_equal_approx(G.fluency(), 0.1), "the Echo keeps Fling's best Practice; a Turning adds a point of insight")
	ok(G.add_wells(5) == 15, "wells regrow three times as fast below last loop's best")
	G.add_wells(500)
	ok(G.wells() == int(G.d["well_cap"]), "wells stop at the slice's cap")
	G.begin_fight()
	P.add_xp("fling", P.xp_needed(1) / 3.3)
	ok(P.level("fling") == 2, "below its Echo, Practice grows three times as fast (plus insight)")
	G.end_fight()
	R.new_run()
	P.reset_all()


## The League-style controls turn right-clicks and Q W E R, D F into the same intent the kit reads.
func _controls(P) -> void:
	P.reset_all()
	var A = load("res://scripts/arena.gd").new()
	root.add_child(A)
	var C = load("res://scripts/controls.gd").new()
	C.save_enabled = false
	C.set_scheme("classic")
	var none := {"held": {}, "pressed": {}, "released": {}}
	var it: Dictionary = C.build(A, Vector2(10, 10), {"move": Vector2(1, 0), "held": {}, "pressed": {}, "released": {}})
	ok(it["move"] == Vector2(1, 0) and it["aim"] == Vector2(10, 10), "classic passes WASD and the mouse through")
	C.set_scheme("league")
	ok(C.key("slot1") == "Q" and C.key("slot4") == "R" and C.key("cant2") == "F" and C.key("ward") == "C", "League keys: Q W E R spells, D F cantrips, C Ward")
	var P0: Vector2 = A.player.pos
	var goal: Vector2 = P0 + Vector2(40, 0)
	var click := {"move_click": true, "held": {}, "pressed": {}, "released": {}}
	it = C.build(A, goal, click, 1.0 / 60.0)
	ok(it["move"].is_equal_approx(Vector2(1, 0)) and C.order.size() > 0, "a right-click on the ground walks toward it and leaves a marker")
	for i in 120:
		it = C.build(A, Vector2(0, 0), none, 1.0 / 60.0)
		A.kit.update(1.0 / 60.0, it)
	ok(A.player.pos.distance_to(goal) <= C.ARRIVE + 1.5 and C.dest == null, "the wizard stops on the clicked point (%s)" % A.player.pos)
	ok(it["move"] == Vector2.ZERO and C.order.is_empty(), "then stands still, and the marker fades")
	# Right-click on an enemy: walk up to it, then strike it with the staff.
	var foe: Unit = A.spawn("hollow", A.player.pos + Vector2(200, 0))
	A.hover = foe
	it = C.build(A, foe.pos, click, 1.0 / 60.0)
	A.hover = null
	ok(C.target == foe and it["move"].x > 0.9 and not it["held"].get("staff", false), "attacking a far enemy walks toward it")
	A.player.pos = foe.pos - Vector2(18, 0)
	it = C.build(A, Vector2(0, 0), none, 1.0 / 60.0)
	ok(it["move"] == Vector2.ZERO and it["held"].get("staff", false) and it["aim"] == foe.pos, "in reach, the staff strikes the enemy, not the cursor")
	it = C.build(A, Vector2(5, 5), {"held": {"slot3": true}, "pressed": {"slot3": true}, "released": {}}, 1.0 / 60.0)
	ok(it["aim"] == Vector2(5, 5) and not it["held"].get("staff", false), "a spell key aims at the cursor even mid-attack")
	foe.dead = true
	C.build(A, Vector2(0, 0), none, 1.0 / 60.0)
	ok(C.target == null, "the attack ends when the enemy falls")
	C.build(A, goal, click, 1.0 / 60.0)
	C.build(A, goal, {"stop": true, "held": {}, "pressed": {}, "released": {}}, 1.0 / 60.0)
	ok(C.dest == null, "S stops")
	# Quick cast keeps hold-and-release; smart cast casts on the press.
	it = C.build(A, goal, {"held": {"slot3": true}, "pressed": {"slot3": true}, "released": {}}, 0.0)
	ok(it["held"]["slot3"] and not it["released"].get("slot3", false), "quick cast holds the telegraph")
	C.set_scheme("league_smart")
	it = C.build(A, goal, {"held": {"slot3": true}, "pressed": {"slot3": true}, "released": {}}, 0.0)
	ok(it["released"]["slot3"] and not it["held"]["slot3"] and it["smart"], "smart cast releases on the same frame and commits the spell")
	it = C.build(A, goal, {"held": {"ward": true}, "pressed": {"ward": true}, "released": {}}, 0.0)
	ok(it["held"]["ward"] and not it["released"].get("ward", false), "the Ward stays up while held, even under smart cast")
	# Blink goes toward the cursor and ends the order.
	C.build(A, goal + Vector2(0, 30), click, 0.0)
	it = C.build(A, goal, {"held": {"blink": true}, "pressed": {"blink": true}, "released": {}}, 0.0)
	ok(it["move"] == Vector2.ZERO and C.dest == null, "blink aims at the cursor and clears the move order")
	P.spell_leveled.disconnect(A.kit._on_leveled)
	A.kit.modules.clear()  # the kit and its spell modules point at each other
	A.kit.fe = null
	A.kit.sw = null
	A.free()
	P.reset_all()


## The maps (design/ruins/tech-plan.md §2): the registry and every map in it load, exits lead to
## real spots, pits stop a walker but not a shot, a sealed door is shut, every spot and item can
## be walked to from where you arrive, schedules name real camp spots, and the clock.
func _world() -> void:
	const Map := preload("res://scripts/world/map.gd")
	const World := preload("res://scripts/world/world.gd")
	const Story := preload("res://scripts/game/story.gd")
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/maps.json"))
	ok(reg["maps"].has(reg["start"]) and reg["maps"].has("halls"), "the map registry names the camp and the halls")
	var loaded := {}
	for mid in reg["maps"]:
		var def: Dictionary = reg["maps"][mid]
		loaded[mid] = Map.new(str(def["path"]), mid, str(def.get("kit", "town")))
		ok(loaded[mid].id == mid and loaded[mid].kit == str(def.get("kit", "town")), "map %s loads with its kit" % mid)
	var bad_exits: Array = []
	for mid in loaded:
		for eid in loaded[mid].exits:
			var ex: Dictionary = loaded[mid].exits[eid]
			if not loaded.has(ex["to"]) or not loaded[ex["to"]].spots.has(ex["at"]):
				bad_exits.append("%s %s -> %s %s" % [mid, eid, ex["to"], ex["at"]])
	ok(bad_exits.is_empty(), "every exit leads to a spot on a real map: " + ", ".join(bad_exits))
	ok(loaded["camp"].exits.has("north_stair") and loaded["halls"].exits.has("stair_up"), "the north stair goes down and the halls' stair comes up")
	var h = loaded["halls"]
	var pit: Rect2 = h.pits[0]
	ok(h.blocked(pit.get_center()) and h.in_pit(pit.get_center()), "a pit stops a walker")
	ok(not h.blocks_shot(pit.get_center()), "a shot flies over a pit")
	ok(not h.in_pit(h.collide(pit.get_center() + Vector2(3, 0), 7.0), 6.9), "collision pushes a walker out of a pit")
	ok(h.solid_at((h.doors["rune_door"]["rect"] as Rect2).get_center()), "the rune door is sealed")
	ok(h.exit_at(h.exits["stair_up"]["rect"].get_center()) == "stair_up", "standing in the stair finds its exit")
	ok(h.cracks.size() > 0 and h.solid_at(h.cracks[0]["rect"].get_center()), "the glowing cracks are solid")
	var bad_feet: Array = []
	for c in h.cracks:
		if h.solid_at(c["foot"]) or h.blocked(c["foot"]):
			bad_feet.append(c["id"])
	ok(bad_feet.is_empty() and not h.crack("kiln_w").is_empty(), "embers come out of every crack onto open floor: " + ", ".join(bad_feet))
	var bd: Rect2 = h.doors["burnt_door"]["rect"]
	h.set_day_doors(9)
	var open9: bool = not h.solid_at(bd.get_center())
	h.set_day_doors(10)
	ok(open9 and h.solid_at(bd.get_center()), "the burnt door stands open on day 9 and is whole on day 10")
	var cs: Rect2 = h.doors["collapsed_stair"]["rect"]
	var choked: bool = h.solid_at(cs.get_center())
	h.doors["collapsed_stair"]["open"] = true
	var up: PackedVector2Array = h.path(h.spots["hall_north"], h.spots["cistern_c"], 7.0)
	ok(choked and not h.solid_at(cs.get_center()) and Array(up).all(func(q): return absf(q.x - 1100.0) < 80.0),
		"the collapsed stair is choked until the Hours mend it, then it is the way north to the cistern")
	h.doors["collapsed_stair"]["open"] = false
	var via: PackedVector2Array = h.path(h.spots["hall_c"], h.spots["ante_c"], 7.0)
	ok(Array(via).any(func(q): return q.x < 700.0), "a sealed rune door sends the path the long way round")
	var m = loaded["camp"]
	var tent: Array = m.d["tents"][1]
	ok(m.solid_at(Map.tent_rect(tent).get_center()), "a tent is solid")
	ok(not m.solid_at(Vector2(m.d["tents"][0][0], m.d["tents"][0][1])), "your open shelter isn't")
	var pd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/props.json"))
	var far: Array = []
	for start in [["camp", "cot"], ["halls", "landing"]]:
		var mm = loaded[start[0]]
		mm.set_day_doors(1)  # early in the month, when the burnt door stands open
		var props: Array = []
		for pr in mm.d.get("props", []):
			props.append([Vector2(pr[1], pr[2]), float(pd["kinds"][pr[0]]["r"])])
		mm.movers = func(): return props
		var targets := {}
		var reach := {}
		for sid in mm.spots:
			targets["spot " + sid] = mm.spots[sid]
			reach["spot " + sid] = 30.0
		for iid in mm.items:
			targets["item " + iid] = mm.items[iid]["at"]
			reach["item " + iid] = maxf(30.0, float(mm.items[iid].get("reach", 30)))
		for eid in mm.exits:
			targets["exit " + eid] = (mm.exits[eid]["rect"] as Rect2).get_center()
			reach["exit " + eid] = 16.0
		for tname in targets:
			var b: Vector2 = targets[tname]
			var p: Vector2 = mm.spots[start[1]]
			var route := Array(mm.path(p, b, 7.0))
			for i in 6000:
				while not route.is_empty() and p.distance_to(route[0]) < (8.0 if route.size() > 1 else 4.0):
					route.pop_front()
				if route.is_empty():
					break
				p = mm.collide(p + (route[0] - p).normalized() * 2.0, 7.0)
			if p.distance_to(b) > reach[tname]:
				far.append("%s %s (%.0f px short)" % [start[0], tname, p.distance_to(b)])
		mm.movers = Callable()
	ok(far.is_empty(), "every spot, item and exit can be walked to from the cot and the landing: " + ", ".join(far))
	var people: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/people.json"))["people"]
	var bad: Array = []
	for pid in people:
		for t in people[pid].get("schedule", {}):
			var sp: String = people[pid]["schedule"][t]
			if sp != "" and not m.spots.has(sp) and sp != "lamp_round":  # lamp_round: Mira lights the lane
				bad.append("%s %s: %s" % [pid, t, sp])
		for o in people[pid].get("overrides", []):
			if not m.spots.has(str(o["spot"])):
				bad.append("%s override: %s" % [pid, o["spot"]])
	ok(bad.is_empty(), "every schedule names a spot in the camp: " + ", ".join(bad))
	var run = root.get_node("Run")
	run.save_enabled = false
	run.new_run()
	var story = Story.new(run)
	story.load_all()
	var w = World.new(run, story)
	ok(w.period_s() > 0.0 and is_equal_approx(w.period_left(), 1.0), "a time of day starts full")
	w.clock = w.period_s() * 0.5
	ok(is_equal_approx(w.period_left(), 0.5), "the clock runs down the time of day")
	w.lamps[0]["lit"] = true
	w.load_map("halls")
	ok(w.map_id == "halls" and not w.lamps[0]["lit"], "the halls' lamps are their own")
	w.lamps[0]["lit"] = true
	w.load_map("camp")
	ok(w.lamps[0]["lit"], "a camp lamp lit before going down is still lit on coming back")
	w.load_map("halls")
	ok(w.lamps[0]["lit"], "a halls lamp lit there is still lit after going up and back")
	w.reset_loop()
	ok(w.map_id == "camp" and not w.lamps[0]["lit"], "a new loop wakes in the camp with its lamps out")


## The year (N-1.1), losses that don't end a life (N-1.3) and the roads between regions (N-1.4).
func _year() -> void:
	var R = root.get_node("Run")
	R.new_run()
	ok(R.LAST_DAY == 364 and R.moon() == 1 and R.moon_day() == 1, "a life is 13 moons of 28 days and starts on Moon 1, day 1")
	R.life["day"] = R.day_of(3, 17)
	ok(R.moon() == 3 and R.moon_day() == 17 and R.date_name() == "Moon 3 · Day 17", "day 73 is Moon 3, day 17")
	ok(R.moon_name() == "Seedmoon" and R.weekday(1)["sphere"] == "sol" and R.weekday(9)["sphere"] == "luna", "moon names, and weekdays by Sphere from Sol's day")
	R.life["day"] = R.LAST_DAY
	R.next_day()
	ok(R.day() == R.LAST_DAY, "the year stops at the Great Eclipse")
	# Losses (lives spec §3.2)
	R.new_run()
	ok(R.ends_life("eclipse") and R.ends_life("turned") and R.ends_life("calamity:lantern_night"), "the Eclipse, the shrine and calamities end a life")
	ok(not R.ends_life("fight:warden") and not R.ends_life("patrol"), "other lost fights don't")
	ok(R.lose("fight:warden") == 2 and R.injured(), "a loss costs two days and leaves you Injured")
	ok(R.lose("patrol") == 0, "a second loss the same day costs no more days")
	ok(R.lose("patrol", true) == 0 and R.died_of("patrol") == 2, "losses are counted like deaths")
	R.life["day"] = 5
	ok(R.lose("patrol", true) == 3, "alone in the wild it costs three")
	# The Reach
	var Reach = load("res://scripts/game/reach.gd")
	var reach = Reach.new(R, null)
	ok(reach.region_of("camp") == "camp" and reach.region_of("halls") == "city", "each map belongs to a region")
	ok(reach.days_between("camp", "city") == 1 and reach.days_between("mill", "archive") == 3, "travel costs the cheapest road's days")
	ok(reach.built("city") and not reach.built("mill"), "a region with no maps is a card")
	_carry(R)
	R.new_run()
	var t: Array = reach.rest_targets()
	ok(not t.is_empty() and t[0]["id"] == "moon" and int(t[0]["day"]) == 29 and t[-1]["id"] == "eclipse", "rest targets: the next moon first, the Great Eclipse last")
	ok(t.filter(func(e): return e["id"] == "calamity_1").is_empty(), "a calamity you don't know of isn't on the calendar")
	R.new_run()


## The carry table (lives spec §4, §9): heads keep, hands reset; insight caps at +3; the Turning
## needs a calamity passed in this life.
func _carry(R) -> void:
	var L = load("res://scripts/game/lives.gd")
	var rules: Dictionary = R.lives
	var soul: Dictionary = R.fresh_soul()
	soul["known"] = {"crack_order": 1}
	var life := {"n": 1, "day": 40, "time": 3, "wells": 12, "best_wells_loop": 18, "learned": ["crack_order"],
		"practice": {"fling": {"level": 4, "xp": 0.0, "muts": {"5": "split"}}, "pebble": {"level": 2, "xp": 0.0, "muts": {}}},
		"flags": {"ring1": true}, "calamities": []}
	var s: Dictionary = L.carry(soul, life, "eclipse", rules)
	ok(s["known"].has("crack_order") and s["deaths"]["eclipse"] == 1, "the soul keeps what you know and counts the ending")
	ok(s["echo"]["fling"] == 4 and s["revisions"]["fling"]["5"] == "split" and s["best_wells"] == 18, "the Echo, revisions and the most wells held carry")
	ok(not s["flags"].has("ring1") and not s.has("practice") and not s.has("wells"), "life flags, Practice and wells stay with the life")
	ok(s["insight"] == 1 and s["lives"].size() == 1 and s["lives"][0]["moon"] == 2 and s["lives"][0]["time"] == "Dusk", "insight +1 and a page for the life")
	ok(soul["lives"].is_empty() and not soul["echo"].has("fling"), "carry doesn't touch the soul it was given")
	for i in 4:
		life["n"] = s["lives"].size() + 1
		s = L.carry(s, life, "turned", rules)
	ok(s["insight"] == 3 and s["lives"].size() == 5, "insight stops at +3")
	ok(not L.can_turn(life, rules), "no Turning back the Hours before a calamity has passed")
	life["calamities"] = ["lantern_night"]
	ok(L.can_turn(life, rules), "a calamity passed lets you turn back the Hours")
	# Roads (lives spec §5): life 1 is the Apprentice road; a deed opens another; last life's road
	# isn't offered again unless nothing else is.
	var s1: Dictionary = R.fresh_soul()
	ok(L.offers(s1, rules).is_empty() and L.roads_open(s1, rules) == ["apprentice"], "a first life is offered no road but the Apprentice's")
	var l1 := {"n": 1, "road": "apprentice", "deeds": ["road_lamplighter"]}
	var s2: Dictionary = L.carry(s1, l1, "eclipse", rules)
	ok(s2["lives"][0]["opened"] == ["lamplighter"] and L.offers(s2, rules) == ["lamplighter"], "a deed opens a road, and last life's road isn't offered")
	var s3: Dictionary = L.carry(s2, {"n": 2, "road": "lamplighter"}, "eclipse", rules)
	ok(L.offers(s3, rules) == ["apprentice"], "the next life is nudged back the other way")
	var s4: Dictionary = L.carry(s3, {"n": 3, "road": "apprentice"}, "eclipse", rules)
	ok(L.offers(s4, rules).size() == 2, "from life 4 every open road offers itself")
	R.new_run()
	ok(R.road() == "apprentice" and not R.take_road("lamplighter"), "life 1 walks the Apprentice road")
	R.soul = s2
	R.life = R.fresh_life()
	ok(R.road() == "" and R.take_road("lamplighter") and R.road() == "lamplighter" and R.road_offers().is_empty(), "a later life takes an offered road for the whole year")
	R.new_run()
	R.soul = s
	R.life = R.fresh_life()
	ok(R.loop() == 6 and R.life["day"] == 1, "the next life is numbered after the soul's pages and starts on the first morning")
	_save_files(R)
	_deeds(R)
	_events(R)
	_weather(R)
	_matter()


## The save files (save spec §5, §12): a Turning cut short is finished on load, once.
func _save_files(R) -> void:
	R.save_dir = "user://unit_test_slot/"
	R.save_enabled = true
	R.wipe()
	R.new_run()
	R.life["day"] = 30
	R.learn("crack_order")
	R.save()
	R.new_run()
	ok(R.load_save() and R.day() == 30 and R.knows("crack_order"), "soul and life save and load")
	# Cut a Turning short after its mark: the soul isn't written yet.
	var ended: Dictionary = R.life.duplicate(true)
	R._write("meta.json", {"version": 1, "turning": {"from_life": 1, "life": ended, "cause": "eclipse"}})
	R.new_run()
	R.load_save()
	ok(R.soul["lives"].size() == 1 and R.insight() == 1 and R.loop() == 2 and R.day() == 1, "a Turning cut short is redone on load")
	R.new_run()
	R.load_save()
	ok(R.soul["lives"].size() == 1 and R.insight() == 1, "...and only once")
	# A life that doesn't follow the soul's pages is dropped.
	R.life["n"] = 7
	R.life["day"] = 99
	R._write("life.json", R.life)
	R.new_run()
	R.load_save()
	ok(R.loop() == 2 and R.day() == 1, "a life that doesn't match the soul wakes on the first morning")
	R.wipe()
	R.save_enabled = false
	R.save_dir = "user://slot1/"


## Achievements (lives spec §7) and Omens (§6.4).
func _deeds(R) -> void:
	var L = load("res://scripts/game/lives.gd")
	var story = load("res://scripts/game/story.gd").new(R)
	var A = load("res://scripts/game/achievements.gd").new(R, story)
	R.new_run()
	ok(A.check().is_empty(), "no achievement before its deed")
	R.set_flag("ring1")
	ok(A.check() == ["first_ring"] and R.soul["titles"] == ["Ringbearer"] and R.soul["title"] == "Ringbearer", "a deed earns its achievement and title, worn at once if none is")
	ok(A.check().is_empty() and R.life["earned"] == ["first_ring"], "...once")
	ok(A.shown("omen")["name"] == "?" and A.shown("first_ring")["earned"], "a hidden achievement shows as ?")
	R.life["ended"] = "eclipse"
	ok(A.check() == ["eclipse"], "a life-end achievement waits for its ending, and the Omen one needs an Omen")
	var rules: Dictionary = R.lives.duplicate(true)
	rules["roads"]["lamplighter"]["opens_by"] = "first_ring"
	ok("lamplighter" in L.roads_open(R.soul, rules), "an achievement can open a road")
	# Omens: from life 2, on the first morning only, for the whole life.
	ok(not R.omens_offered() and not R.take_omen("hard_foes"), "no Omens in a first life")
	var s: Dictionary = L.carry(R.soul, R.life, "eclipse", R.lives)
	ok(s["lives"][0]["earned"] == ["first_ring", "eclipse"] and s["achievements"].has("eclipse"), "the life's page lists its deeds, and the soul keeps them")
	R.soul = s
	R.life = R.fresh_life()
	ok(R.omens_offered() and R.take_omen("hard_foes") and not R.take_omen("hard_foes"), "an Omen is taken on the first morning of a later life, once")
	ok(is_equal_approx(R.omen_mult("enemy_hp"), 1.3) and is_equal_approx(R.omen_mult("aether_regen"), 1.0), "the Hard Sky toughens enemies, nothing else")
	R.life["time"] = 1
	ok(not R.take_omen("thin_aether"), "Omens can't be taken after the first morning")
	R.life["ended"] = "turned"
	ok(A.check() == ["omen"], "finishing a year under an Omen earns its deed")
	ok(L.carry(R.soul, R.life, "turned", R.lives)["lives"][1]["omens"] == ["hard_foes"], "the life's page names its Omens")
	# The profile keeps a copy (save spec §3).
	R.save_dir = "user://unit_test_slot/"
	R.profile_path = "user://unit_test_profile.json"
	R.save_enabled = true
	R.profile_earn("warden")
	var prof = JSON.parse_string(FileAccess.get_file_as_string(R.profile_path))
	ok(prof is Dictionary and prof["achievements"].has("warden"), "an achievement is copied to the profile")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(R.profile_path))
	R.wipe()
	R.save_enabled = false
	R.save_dir = "user://slot1/"
	R.profile_path = "user://profile.json"
	R.new_run()


## Fixed events and appointments (lives spec §6.2): the Run's side.
func _events(R) -> void:
	R.new_run()
	var fx: Array = R.fixed_events()
	ok(fx.size() >= 2 and fx.all(func(e): return int(e["at_time"]) >= 0), "the calendar has fixed events with a time of day")
	ok(R.due_events().is_empty(), "none is due on the first morning")
	R.life["day"] = 40
	var due: Array = R.due_events().map(func(e): return e["id"])
	ok("knights_arrive" in due and "iron_gate_shuts" in due, "events whose hour has gone by are due")
	var ig: Dictionary = fx.filter(func(e): return e["id"] == "iron_gate_shuts")[0]
	ok(R.settle_event(ig, "missed") and not R.settle_event(ig, "missed"), "a missed loss becomes an appointment, once")
	ok(R.soul["appointments"]["iron_gate_shuts"]["region"] == "iron_gate" and R.soul["dates"].has("iron_gate_shuts"), "the appointment keeps the place, and the date is known")
	ok(not R.due_events().any(func(e): return e["id"] == "iron_gate_shuts"), "a settled event isn't due again this life")
	var s: Dictionary = load("res://scripts/game/lives.gd").carry(R.soul, R.life, "eclipse", R.lives)
	R.soul = s
	R.life = R.fresh_life()
	ok(R.soul["appointments"].has("iron_gate_shuts") and R.event_state("iron_gate_shuts") == "", "appointments outlive the life; the event comes round again")
	R.new_run()


## The weather (seasons spec §3, N-4.5.1): the same year from the same seed, calamity days pinned,
## no long storm runs, a spell's change lasts the day, the Almanac and Aldous's forecast.
func _weather(R) -> void:
	R.new_run()
	var W = load("res://scripts/world/weather.gd")
	var wx = W.new(R)
	R.soul["seed"] = 4242
	var year: Array = []
	for d in range(1, R.LAST_DAY + 1):
		year.append(wx.kind("camp", d))
	var wx2 = W.new(R)
	ok(range(1, R.LAST_DAY + 1).all(func(d): return wx2.kind("camp", d) == year[d - 1]), "the same seed draws the same year")
	R.soul["seed"] = 4243
	var other := 0
	for d in range(1, R.LAST_DAY + 1):
		other += 1 if wx.kind("camp", d) != year[d - 1] else 0
	ok(other > 60, "another seed draws another year (%d days differ)" % other)
	R.soul["seed"] = 4242
	var c1: Dictionary = wx.on("camp", R.day_of(3, 28))
	ok(c1["kind"] == "mist" and int(c1["wind"]) == 0 and c1.get("pinned", false), "Lantern Night is pinned: mist, still air")
	ok(wx.kind("city", R.LAST_DAY) == "snow" and wx.kind("camp", R.day_of(9, 21)) == "heat", "the Eclipse snows; the Purge is a heat day")
	var run_n := 0
	var worst := 0
	var seen := {}
	for k in year:
		run_n = run_n + 1 if k == "storm" else 0
		worst = maxi(worst, run_n)
		seen[k] = true
	ok(worst <= 3, "never more than three storm days in a row")
	ok(seen.size() >= 7, "the plateau's year has most kinds of weather (%d)" % seen.size())
	ok(range(R.day_of(11, 1), R.LAST_DAY).all(func(d): return wx.kind("camp", d) != "rain" and wx.kind("camp", d) != "heat"), "no rain or heat in winter")
	R.life["day"] = 20
	var was: String = wx.kind("camp")
	var to := "storm" if was != "storm" else "clear"
	ok(wx.set_today("camp", to) and wx.kind("camp") == to and wx.kind("camp", 21) == year[20], "a weather spell changes today only")
	R.life["day"] = R.day_of(3, 28)
	ok(not wx.set_today("camp", "clear") and wx.kind("camp") == "mist", "a pinned day can't be changed")
	R.life["day"] = 30
	ok(wx.known("camp", 31) == "" and wx.known("camp", 30) == year[29], "today is known, tomorrow isn't")
	var said: String = wx.forecast("camp")
	ok(said != "" and wx.known("camp", 31) == year[30], "Aldous's forecast makes tomorrow known")
	wx.note("camp")
	var s: Dictionary = load("res://scripts/game/lives.gd").carry(R.soul, R.life, "eclipse", R.lives)
	R.soul = s
	R.life = R.fresh_life()
	ok(wx.known("camp", 30) == year[29] and wx.known("camp", 31) == "" and int(R.soul["seed"]) == 4242, "the Almanac and the seed carry into the next life")
	R.new_run()


## The matter core (spells and the environment spec §2-§4, N-4.1): every table cell names an op
## the build knows, carriers name real spells, and the grade gates work both ways.
func _matter() -> void:
	var M = load("res://scripts/world/matter.gd").new()
	const OPS := ["burn", "smoulder", "scorch", "wet", "chill", "brittle", "damage", "crack", "mend", "charge",
		"flatten", "grow", "sprout", "reveal", "split", "lean", "dry", "dig", "dust", "freeze", "mud", "hot", "slick", "root",
		"wash", "shatter", "store", "focus", "dent", "reflect", "ring", "steam", "splash", "flood", "lilies", "glitter",
		"still", "melt", "refract", "burst", "spatter", "thicken", "spread", "explode", "scatter", "damp", "ruin",
		"burn_off", "blow", "rime", "glow", "sign", "stagger", "shock", "dazzle", "unmake", "none"]
	var bad: Array = []
	for mat in M.d["materials"]:
		if not M.d["results"].has(mat):
			bad.append(mat + ": no row")
	for mat in M.d["results"]:
		for force in M.d["results"][mat]:
			if not force in M.d["forces"]:
				bad.append("%s: no force %s" % [mat, force])
			for op in M.d["results"][mat][force]:
				if not op in OPS:
					bad.append("%s × %s: unknown op %s" % [mat, force, op])
	ok(bad.is_empty(), "every table cell is a known op (%s)" % ", ".join(bad))
	var spells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/spells.json"))["spells"]
	var c: Dictionary = M.d["carriers"]
	ok(c.keys().all(func(k): return c[k]["force"] in M.d["forces"] and (not c[k].has("spell") or spells.has(c[k]["spell"]))), "every carrier names a force and a real spell")
	ok(M.result("fire", 1, "wood") == "burn" and M.result("fire", 1, "living_wood") == "smoulder" and M.result("fire", 2, "living_wood") == "burn", "fire lights wood at I, living wood only at II")
	ok(M.result("impact", 4, "stone") == "damage" and M.result("impact", 3, "stone") == "crack" and M.result("impact", 2, "stone") == "dent", "Impact: breaks stone at IV, cracks it at III, only dents below")
	ok(M.result("lightning", 1, "iron") == "charge" and M.result("lightning", 1, "wood") == "scorch" and M.result("lightning", 2, "wood") == "burn" and M.result("lightning", 1, "cloth") == "burn", "lightning conducts in iron, lights wood at II and hay at I")
	ok(M.result("impact", 5, "warded") == "none" and M.result("fire", 5, "warded") == "none", "warded things don't answer to force")
	ok(M.result("fire", 1, "wood", {"fire": 2}) == "smoulder" and M.result("impact", 1, "wood", {"break": 2}) == "crack", "a prop kind's own grades win (the barrel, the cart)")
	ok(M.result("water", 1, "earth") == "mud" and M.result("growth", 1, "water") == "lilies" and M.result("light", 1, "stone") == "reveal", "forces with no grade gate work at grade I")


## Spell mastery in the slice (spell spec §6.4, N-3): walls, trials, breakthroughs, remembered
## breakthroughs, Perfected only after a past-life Master, minor steps, the Force grade.
func _mastery(P) -> void:
	P.reset_all()
	P.rules = {"walls": true, "grade_cap": 2, "echo": {}, "broken": {}, "known": {}}
	P.add_xp("pillar", 1000.0)
	ok(P.level("pillar") == 5 and P.stage("pillar") == 0 and P.at_wall("pillar"), "Practice stops at the top of Novice until a breakthrough")
	ok(P.xp("pillar") <= P.xp_needed(5) + 0.001, "XP banks up to one level at the wall")
	var dmg0: float = P.stat("pillar", "damage")
	ok(P.trials("pillar").size() == 3 and not P.trials("pillar")[0]["done"], "three trials, the feat not done yet")
	ok(P.pass_trial("pillar", "meditation") and P.stage("pillar") == 1 and P.level("pillar") == 6, "one trial breaks through into Adept, and the banked XP carries on")
	ok(P.pending.size() == 1 and P.pending[0]["level"] == 5, "the breakthrough offers the Revision")
	P.pick(0)
	ok(is_equal_approx(P.stat("pillar", "damage"), P.stat_value(P.spell("pillar")["stats"]["damage"], 6) * 1.2) and P.stat("pillar", "damage") > dmg0, "the minor axis steps up 20%")
	ok(P.grade("pillar") == 2, "Adept casts at Force grade II")
	P.rules["grade_cap"] = 1
	ok(P.grade("pillar") == 1, "...unless the Ring caps it")
	P.rules["grade_cap"] = 2
	P.add_xp("pillar", 1000.0)
	P.pass_trial("pillar", "meditation")
	ok(P.level("pillar") == 10 and P.stage("pillar") == 1, "Master needs two trials")
	P.p["spells"]["pillar"]["hits"] = 45
	P.add_xp("pillar", 1.0)
	ok(P.stage("pillar") == 2 and P.level("pillar") > 10, "the feat (45 hits) and the meditation break through into Master")
	P.add_xp("pillar", 1000.0)
	for k in ["feat", "insight", "meditation"]:
		P.pass_trial("pillar", k)
	ok(P.level("pillar") == 15 and P.stage("pillar") == 2, "Perfected waits for a spell mastered in a past life")
	P.rules["echo"] = {"pillar": 12}
	P.add_xp("pillar", 1.0)
	ok(P.stage("pillar") == 3, "...and comes once it was")
	for i in range(P.pending.size()):
		P.pick(0)
	# A breakthrough made in a past life needs no trial.
	P.p = P.fresh()
	P.rules["broken"] = {"spark": 1}
	P.add_xp("spark", 1000.0)
	ok(P.stage("spark") == 1 and P.level("spark") == 10, "a remembered breakthrough happens as soon as the level is reached")
	for lv in range(1, 21):
		ok(P.stat("pillar", "delay", lv) >= P.fair_delay(P.stat("pillar", "radius", lv)) - 0.0001, "Pillar at Lv %d keeps the fair-dodge rule" % lv)
	P.pending.clear()
	P.rules = {}
	P.reset_all()
