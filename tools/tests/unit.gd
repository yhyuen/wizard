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
	print("[unit] %d check(s), %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
