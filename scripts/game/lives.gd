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
	for k in ["lives", "known", "deaths", "echo", "revisions", "flags", "roads_played"]:
		if not s.has(k):
			s[k] = [] if k in ["lives", "roads_played"] else {}
	var opened_before: Array = roads_open(s, rules)
	var n: int = int(life.get("n", s["lives"].size() + 1))
	s["deaths"][cause] = int(s["deaths"].get(cause, 0)) + 1
	# Insight: +1 at every Turning, whatever the ending, up to the cap.
	s["insight"] = mini(int(rules["insight"]["cap"]), int(s.get("insight", 0)) + 1)
	# Wells: the most you held regrows faster next life.
	var held: int = maxi(int(life.get("best_wells_loop", 0)), int(life.get("wells", 0)))
	s["best_wells"] = maxi(int(s.get("best_wells", 0)), held)
	# Each spell's best Practice (the Echo) and the revisions you picked.
	var practice: Dictionary = life.get("practice", {})
	var raised := {}
	for id in practice:
		var p: Dictionary = practice[id]
		var was: int = int(s["echo"].get(id, 1))
		if int(p.get("level", 1)) > was:
			raised[id] = int(p.get("level", 1))
		s["echo"][id] = maxi(was, int(p.get("level", 1)))
		# Breakthroughs are remembered: the next life breaks through without the trials (§6.7).
		if int(p.get("stage", 0)) > 0:
			if not s.has("broken"):
				s["broken"] = {}
			s["broken"][id] = maxi(int(s["broken"].get(id, 0)), int(p["stage"]))
		var muts: Dictionary = p.get("muts", {})
		if not muts.is_empty():
			var r: Dictionary = s["revisions"].get(id, {})
			r.merge(muts, true)
			s["revisions"][id] = r
	# School rank (spell spec §8): the best rank each school reached is remembered.
	for sid in life.get("schools", {}):
		if not s.has("schools"):
			s["schools"] = {}
		s["schools"][sid] = maxi(int(s["schools"].get(sid, -1)), int(life["schools"][sid].get("rank", 0)))
	# Deeds done this life (soul flags) and the road walked.
	for f in life.get("deeds", []):
		s["flags"][f] = true
	var road: String = str(life.get("road", "")) if str(life.get("road", "")) != "" else "apprentice"
	if not road in s["roads_played"]:
		s["roads_played"].append(road)
	# The life's page (lives spec §3.3): Kept, Opened, Left behind.
	var day: int = int(life.get("day", 1))
	var t: int = clampi(int(life.get("time", 0)), 0, TIME_NAMES.size() - 1)
	var opened: Array = roads_open(s, rules).filter(func(r): return not r in opened_before)
	s["lives"].append({"loop": n, "road": road, "cause": cause,
		"day": day, "moon": (day - 1) / 28 + 1, "time": TIME_NAMES[t], "insight": s["insight"],
		"wells": held, "ring": str(life.get("ring_name", "")), "raised": raised, "opened": opened,
		"learned": (life.get("learned", []) as Array).duplicate(),
		"omens": (life.get("omens", []) as Array).duplicate(), "earned": (life.get("earned", []) as Array).duplicate()})
	s["last_road"] = road
	return s


## The roads a soul has opened: those with no deed to open them, and those whose deed (a soul flag)
## or achievement is done.
static func roads_open(soul: Dictionary, rules: Dictionary) -> Array:
	var out: Array = []
	var flags: Dictionary = soul.get("flags", {})
	var got: Dictionary = soul.get("achievements", {})
	for id in rules.get("roads", {}):
		var by: String = str(rules["roads"][id].get("opens_by", ""))
		if by == "" or flags.has(by) or got.has(by):
			out.append(id)
	return out


## The roads that offer themselves on a first morning (lives spec §5.2): every open road but the
## one taken last life, unless that leaves nothing; from life 4, every open road. Life 1 offers
## nothing: it is always the Apprentice road.
static func offers(soul: Dictionary, rules: Dictionary) -> Array:
	var lived: int = (soul.get("lives", []) as Array).size()
	if lived == 0:
		return []
	var open: Array = roads_open(soul, rules)
	if lived >= 3:
		return open
	var nudged: Array = open.filter(func(r): return r != str(soul.get("last_road", "")))
	return nudged if not nudged.is_empty() else open


## A Turning back the Hours (cause `turned`) is allowed only once a calamity has passed in this
## life, if lives.json says so (lives spec §3.1).
static func can_turn(life: Dictionary, rules: Dictionary) -> bool:
	return not bool(rules.get("turning_needs_calamity", true)) or not (life.get("calamities", []) as Array).is_empty()
