extends SceneTree
## Bonds (people spec §4-5; N-7.6.1):
##
##   godot --headless --script res://tools/tests/bonds.gd
##
## A first talk makes you Warm; gains climb to Friendly by themselves and stop at Close's door until
## its scene; once-per-key and once-a-week caps hold; a loss stops at the bottom of the tier and
## betrayal drops one; light people stop at Close and role people have no track; a gift's gain is
## by taste and its reaction is learned for every life; Close in one life starts the next at Warm.

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
	for f in failures:
		print("[bonds] FAIL: " + f)
	if failures.is_empty():
		print("[bonds] bonds hold")
	quit(1 if not failures.is_empty() else 0)
