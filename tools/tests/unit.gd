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
	ok(is_equal_approx(P.stat("pillar", "radius"), 15.0 * 1.3) and is_equal_approx(P.stat("pillar", "damage"), 14.0 * 0.7), "a boost scales the cast spell's size and damage")
	ok(is_equal_approx(P.stat("pillar", "radius", 1), 15.0), "a boost never touches an explicit level (ghost previews)")
	ok(is_equal_approx(P.stat("ember_bolt", "damage"), 6.0), "a boost leaves other spells alone")
	P.boost = {"id": "pyroclasm", "damage": 1.0, "size": 1.0, "count": 1}
	ok(P.stat("pyroclasm", "bounces") == 5.0, "a Resonant cast adds one to a count")
	P.boost = {}
	ok(P.stone_cap() == 3, "the stone cap starts at 3")
	# XP and levels.
	P.add_xp("ember_bolt", 8.0)
	ok(P.level("ember_bolt") == 2, "8 XP levels Ember Bolt to 2")
	P.add_xp("ember_bolt", 1000.0)
	ok(P.level("ember_bolt") == 15, "levels cap at 15")
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
	ok(P.level("ember_bolt") == 15, "spell levels survive the loop")
	ok(P.blink_charges(1) == 1 and P.blink_charges(3) == 2 and P.blink_charges(6) == 3, "blink charges at 1, 3, 6")
	# The spellbook: six spells from any sphere, set at the Orrery.
	P.reset_all()
	ok(P.spellbook() == ["ember_bolt", "pebble", "pillar", "fling", "pyroclasm", "avalanche"], "the first loop starts with the Mars and Jupiter kits")
	ok(P.loadout() == ["fire", "earth"], "the book's spheres are Mars and Jupiter")
	P.set_spell(2, "arc_lance")
	ok(P.spellbook()[2] == "arc_lance" and P.loadout() == ["fire", "earth", "storm"], "any spell goes in any slot, and its sphere joins the book")
	P.set_spell(0, "pebble")
	ok(P.spellbook()[0] == "pebble" and P.spellbook()[1] == "ember_bolt", "a spell already in the book swaps slots")
	ok(P.valid_book(P.spellbook(), P.data["spells"]), "the book stays six different spells")
	ok(not P.valid_book(["spark", "spark", "pillar", "fling", "pyroclasm", "avalanche"], P.data["spells"]), "a book with a spell twice is invalid")
	P.set_loadout("fire", "earth")
	ok(P.spell_for("storm", "bolt") == "spark" and P.spell_for("water", "signature") == "maelstrom", "each element has a bolt, control and signature")
	ok(P.magick_for(["water", "storm"]) == "conductor" and P.magick_for(["earth", "fire"]) == "meteor", "a pair finds its Magick in either order")
	ok(P.magick_for(["fire", "storm"]) == "", "a pair without a Magick has none")
	P.set_loadout("storm", "storm")
	ok(P.loadout() == ["fire", "earth"], "the same sphere twice is refused as a preset")
	P.set_loadout("storm", "water")
	ok(P.spellbook() == ["spark", "splash", "arc_lance", "undertow", "storm_call", "maelstrom"], "a two-sphere preset fills the book")
	ok(not P.unlocked("rewind") and not P.open_elements().has("hours"), "Hours is not in loop 1")
	P.set_spell(0, "rewind")
	ok(not P.spellbook().has("rewind"), "a spell that has not come back yet cannot go in the book")
	P.set_echo([10, 20, 1, 0, 0, 30, 40, 1, 0, 1], false)
	ok(P.echo_track().is_empty(), "this loop's own fight is not its echo")
	P.next_loop()
	ok(P.spellbook().slice(0, 5) == ["spark", "splash", "arc_lance", "undertow", "storm_call"], "the spellbook carries into the next loop")
	ok(P.spellbook()[5] == "rewind" and P.unlocked("rewind") and P.open_elements().has("hours"), "Rewind comes back with you in loop 2, in the last slot")
	ok(P.echo_track().size() == 10, "the last loop's fight becomes the echo")
	P.set_spell(5, "maelstrom")
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
	_controls(P)
	_growth(P)
	_world()
	print("[unit] %d check(s), %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


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
	ok(G.ring() == 2 and G.slots() == 4 and G.slot_spell(2) == "pillar", "after the trial, 30 wells is the 2nd Ring with Pillar open")
	ok(G.max_hp() == 160.0 and G.max_aether() == 130.0 and G.blinks() == 2, "wells raise Vitality and Aether; the 2nd Ring adds a Blink")
	ok(G.set_slot(0, "fling") and G.book()[0] == "fling" and G.book()[3] == "ember_bolt", "putting a Model in a slot swaps it with where it was")
	ok(not G.set_slot(4, "ember_bolt"), "slot 5 waits for the 4th Ring")
	R.learn("model_pyroclasm")
	ok(G.known_models().has("pyroclasm") and not G.can_cast("pyroclasm"), "a Signature can be known before the 4th Ring lets you cast it")
	# A fight borrows the loop's Practice and gives it back.
	G.begin_fight()
	ok(P.max_hp() == 160.0 and P.max_aether() == 130.0 and P.magick_for(["fire", "earth"]) == "", "in a slice fight Progression uses wells and has no Magicks")
	ok(P.slot_open(0) and not P.slot_open(4), "in a slice fight locked slots are closed")
	var w0: float = P.p["wizard_xp"]
	P.add_xp("fling", P.xp_needed(1))
	ok(P.level("fling") == 2 and P.p["wizard_xp"] == w0, "slice Practice levels a spell and no wizard level")
	G.end_fight()
	ok(P.p == before and P.rules.is_empty(), "the old progress is back after the fight")
	ok(G.level("fling") == 2, "the fight's Practice stays with this loop")
	ok(G.use_today("meditate") and not G.use_today("meditate"), "meditating is once a day")
	var got: Dictionary = G.train()
	ok(got.has("fling") and got.has("pillar") and not got.has("splash") and G.practice()["pillar"]["xp"] > 0.0, "training adds part of a level to the spells in open slots")
	# The loop ends on day 7 and a new one starts.
	R.lp["day"] = 7
	G.loop_over()
	R.wake()
	ok(G.wells() == 0 and G.ring() == 0 and G.level("fling") == 1, "waking resets wells, the Ring and Practice")
	ok(G.echo()["fling"] == 2 and is_equal_approx(G.fluency(), 0.1), "the Echo keeps Fling's best Practice; reaching day 7 adds Fluency")
	ok(G.add_wells(5) == 15, "wells regrow three times as fast below last loop's best")
	G.add_wells(500)
	ok(G.wells() == int(G.d["well_cap"]), "wells stop at the slice's cap")
	G.begin_fight()
	P.add_xp("fling", P.xp_needed(1) / 3.3)
	ok(P.level("fling") == 2, "below its Echo, Practice grows three times as fast (plus Fluency)")
	G.end_fight()
	R.new_run()
	P.reset_all()


## The League-style controls turn right-clicks and Q W E R D F into the same intent the kit reads.
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
	ok(C.key("slot1") == "Q" and C.key("slot6") == "F", "League keys are Q W E R D F")
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
	# Right-click on an enemy: walk into Bolt range, then hold the Bolt at it.
	var foe: Unit = A.spawn("hollow", A.player.pos + Vector2(200, 0))
	A.hover = foe
	it = C.build(A, foe.pos, click, 1.0 / 60.0)
	A.hover = null
	ok(C.target == foe and it["move"].x > 0.9 and not it["held"].get("slot1", false), "attacking a far enemy walks toward it")
	A.player.pos = foe.pos - Vector2(60, 0)
	it = C.build(A, Vector2(0, 0), none, 1.0 / 60.0)
	ok(it["move"] == Vector2.ZERO and it["held"].get("slot1", false) and it["aim"] == foe.pos, "in range, the Bolt fires at the enemy, not the cursor")
	it = C.build(A, Vector2(5, 5), {"held": {"slot3": true}, "pressed": {"slot3": true}, "released": {}}, 1.0 / 60.0)
	ok(it["aim"] == Vector2(5, 5) and not it["held"].get("slot1", false), "a spell key aims at the cursor even mid-attack")
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
	ok(it["released"]["slot3"] and not it["held"]["slot3"], "smart cast releases on the same frame")
	it = C.build(A, goal, {"held": {"slot1": true}, "pressed": {"slot1": true}, "released": {}}, 0.0)
	ok(it["held"]["slot1"] and not it["released"].get("slot1", false), "a Bolt still fires while held")
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
