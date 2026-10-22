extends RefCounted
## The carry table as code (design/lives/lives-and-carryover-spec.md §4, §8; build item N-1.2).
## `carry` is pure: it takes the soul and the life that just ended and returns the new soul,
## touching nothing else, so the Turning (scripts/game/run.gd) can compute it before it writes
## anything, and tools/tests/unit.gd can check it with built lives.
##
## Kept by the soul (heads keep): what you know, deaths by cause, each spell's best Practice (the
## Echo) and its revision picks, the most wells you held, insight (+1 a life, up to the cap), and a
## page for each life. Everything in the life (hands reset) is left behind.

const TIME_NAMES := ["Morning", "Noon", "Afternoon", "Dusk", "Night"]


## The new soul after the life `life` ended for `cause`. `rules` is data/world/lives.json.
static func carry(soul: Dictionary, life: Dictionary, cause: String, rules: Dictionary) -> Dictionary:
	var s: Dictionary = soul.duplicate(true)
	for k in ["lives", "known", "deaths", "echo", "revisions"]:
		if not s.has(k):
			s[k] = [] if k == "lives" else {}
	var n: int = int(life.get("n", s["lives"].size() + 1))
	s["deaths"][cause] = int(s["deaths"].get(cause, 0)) + 1
	# Insight: +1 at every Turning, whatever the ending, up to the cap.
	s["insight"] = mini(int(rules["insight"]["cap"]), int(s.get("insight", 0)) + 1)
	# Wells: the most you held regrows faster next life.
	var held: int = maxi(int(life.get("best_wells_loop", 0)), int(life.get("wells", 0)))
	s["best_wells"] = maxi(int(s.get("best_wells", 0)), held)
	# Each spell's best Practice (the Echo) and the revisions you picked.
	var practice: Dictionary = life.get("practice", {})
	for id in practice:
		var p: Dictionary = practice[id]
		s["echo"][id] = maxi(int(s["echo"].get(id, 1)), int(p.get("level", 1)))
		var muts: Dictionary = p.get("muts", {})
		if not muts.is_empty():
			var r: Dictionary = s["revisions"].get(id, {})
			r.merge(muts, true)
			s["revisions"][id] = r
	# The life's page.
	var day: int = int(life.get("day", 1))
	var t: int = clampi(int(life.get("time", 0)), 0, TIME_NAMES.size() - 1)
	s["lives"].append({"loop": n, "road": str(life.get("road", "apprentice")), "cause": cause,
		"day": day, "moon": (day - 1) / 28 + 1, "time": TIME_NAMES[t], "insight": s["insight"],
		"wells": held, "learned": (life.get("learned", []) as Array).duplicate()})
	return s


## A Turning back the Hours (cause `turned`) is allowed only once a calamity has passed in this
## life, if lives.json says so (lives spec §3.1).
static func can_turn(life: Dictionary, rules: Dictionary) -> bool:
	return not bool(rules.get("turning_needs_calamity", true)) or not (life.get("calamities", []) as Array).is_empty()
