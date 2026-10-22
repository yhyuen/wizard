extends SceneTree
## Checks the story scripts (each map's story folder, data/world/maps.json) against their maps
## and the rest of the data:
##
##   godot --headless --script res://tools/tests/story_lint.gd
##
## Every scene parses; every person, item, place, spot, exit, jump, Ledger id, Model, encounter,
## death cause, flag and condition it names exists on its own map; every person and every item on
## every map answers when you talk to it or use it; and the first playable's beats are there (C1:
## Mira says who carried you out; H1, H3, H4, H5, the sighting, Wren's chalk and the Warden's tell).
## Exits non-zero on any problem.

const Story := preload("res://scripts/game/story.gd")
const BEATS := {"C1 (who carried you out)": "carried_out", "H1 (the Provost at the Eclipse)": "provost_crossed",
	"H3 (the door that healed)": "doors_heal", "H4 (the rune on the crate)": "rune_ashlar", "H4 (the rune door opens)": "rune_opened",
	"H5 (the stair brought down)": "stair_cult", "the sighting": "figure_ahead", "Wren's chalk mark": "wren_chalk",
	"the Warden's tell": "warden_water"}

var problems: Array = []


func _initialize() -> void:
	var run = root.get_node("Run")
	run.save_enabled = false
	run.new_run()
	var story = Story.new(run)
	story.load_all()
	problems.append_array(story.errors)
	var reg: Dictionary = _json("res://data/world/maps.json")
	var maps := {}  # map id -> its map.json
	var map_of_dir := {}  # story folder -> map id
	for mid in reg["maps"]:
		maps[mid] = _json(str(reg["maps"][mid]["path"]))
		map_of_dir[str(reg["maps"][mid]["story"]).trim_suffix("/")] = mid
	var people: Dictionary = _json("res://data/world/people.json")["people"]
	var encounters: Dictionary = _json("res://data/world/encounters.json")["encounters"]
	var ld: Dictionary = _json("res://data/world/ledger.json")
	var ledger: Dictionary = ld["entries"]
	var deaths: Dictionary = ld["deaths"]
	for mid in maps:
		for ex in maps[mid].get("exits", []):
			if not maps.has(ex["to"]) or not maps[ex["to"]]["spots"].has(ex["at"]):
				problems.append("map %s: exit %s leads to %s %s, which isn't there" % [mid, ex["id"], ex["to"], ex["at"]])
	var spells: Dictionary = _json("res://data/spells.json")
	var foes: Dictionary = _json("res://data/enemies.json")["kinds"]
	var flags_set := {}
	var rumour_d: Dictionary = _json("res://data/world/rumours.json")["rumours"]
	var rumour_from := {}  # rumour id -> the scenes that give it
	var com_d: Dictionary = _json("res://data/world/commissions.json")["commissions"]
	var com_ops := {}  # commission id -> {op: scenes giving it}
	for id in load("res://scripts/world/world.gd").FLAGS:
		flags_set[id] = true  # set by the world itself
	for cid in _json("res://data/world/calamities.json")["calamities"]:
		var cr: Dictionary = _json("res://data/world/calamities.json")["calamities"][cid]
		flags_set["pinned_" + str(cr["event"])] = true  # set by calamity code (scripts/game/calamity.gd)
		var hold: Dictionary = cr.get("onset_hold", {})
		for k in ["kept", "taken"]:
			if hold.has(k):
				flags_set[str(hold[k])] = true
		for vk in cr.get("variants", {}):
			if cr["variants"][vk] is Dictionary and cr["variants"][vk].has("flag"):
				flags_set[str(cr["variants"][vk]["flag"])] = true
		for t in cr["aftermath"]:
			for fl in cr["aftermath"][t].get("flags", []):
				flags_set[str(fl)] = true
	var conds: Array = []  # [condition, where]
	for s in story.scenes.values():
		var where := "%s:%d (%s)" % [s["file"], s["line"], s["id"]]
		var mid: String = map_of_dir.get(str(s["file"]).get_base_dir(), "")
		if mid == "":
			problems.append("%s: not in any map's story folder" % where)
			continue
		var map: Dictionary = maps[mid]
		var places: Dictionary = map["places"]
		var items: Dictionary = map["items"]
		var exits := {}
		for ex in map.get("exits", []):
			exits[ex["id"]] = ex
		for p in s["arrives"]:
			if not places.has(p):
				problems.append("%s: unknown place %s" % [where, p])
		if s["talk"] != "" and not people.has(s["talk"]):
			problems.append("%s: nobody called %s in data/world/people.json" % [where, s["talk"]])
		if s["use"] != "" and not items.has(s["use"]) and not exits.has(s["use"]):
			problems.append("%s: no item or exit %s on the map %s" % [where, s["use"], mid])
		if s["cast"] != "" and not s["cast"] in ["fire", "water", "earth", "storm", "hours"]:
			problems.append("%s: cast must be an element, not %s" % [where, s["cast"]])
		for key in ["when", "known"]:
			if s[key] != "":
				conds.append([s[key], where])
		for st in s["steps"]:
			if st.get("cond", "") != "":
				conds.append([st["cond"], where])
			if st["t"] != "fx":
				continue
			var arg: String = st["arg"]
			match st["op"]:
				"learn":
					if not ledger.has(arg):
						problems.append("%s: no Ledger entry for '%s'" % [where, arg])
				"model":
					if not ledger.has("model_" + arg):
						problems.append("%s: no Ledger entry for model_%s" % [where, arg])
					if not spells["spells"].has(arg):
						problems.append("%s: no spell '%s' in data/spells.json" % [where, arg])
				"trial":
					if not ledger.has("trial_" + arg):
						problems.append("%s: no Ledger entry for trial_%s" % [where, arg])
				"set":
					flags_set[arg] = true
				"goto":
					if not story.scenes.has(arg):
						problems.append("%s: goto to missing scene %s" % [where, arg])
				"fight":
					if not encounters.has(arg):
						problems.append("%s: no encounter %s" % [where, arg])
					if not map.get("spawns", {}).has(arg):
						problems.append("%s: encounter %s has no spawns on the map %s" % [where, arg, mid])
				"move":
					if not map["spots"].has(arg):
						problems.append("%s: no spot %s on the map %s" % [where, arg, mid])
				"go":
					var parts := arg.split(" ")
					if parts.size() == 1 and not exits.has(arg):
						problems.append("%s: go %s is not an exit of the map %s" % [where, arg, mid])
					elif parts.size() == 2 and not (maps.has(parts[0]) and maps[parts[0]]["spots"].has(parts[1])):
						problems.append("%s: go %s names no spot on a map" % [where, arg])
					elif parts.size() > 2:
						problems.append("%s: go takes an exit, or a map and a spot" % where)
				"take":
					if not items.has(arg):
						problems.append("%s: no item %s to take" % [where, arg])
				"end_loop":
					if not deaths.has(arg):
						problems.append("%s: no death text for %s" % [where, arg])
				"road":
					if not root.get_node("Run").lives["roads"].has(arg):
						problems.append("%s: no road %s in data/world/lives.json" % [where, arg])
				"omen":
					if not root.get_node("Run").lives.get("omens", {}).has(arg):
						problems.append("%s: no omen %s in data/world/lives.json" % [where, arg])
				"rumour":
					if not rumour_d.has(arg):
						problems.append("%s: no rumour %s in data/world/rumours.json" % [where, arg])
					else:
						rumour_from[arg] = rumour_from.get(arg, []) + [s]
				"commission":
					var cp := arg.split(" ")
					if cp.size() != 2 or not com_d.has(cp[0]) or not cp[1] in ["take", "next", "clean", "lose", "slow", "work", "pay"]:
						problems.append("%s: commission %s is not <id in data/world/commissions.json> <take|next|clean|lose|slow|work|pay>" % [where, arg])
					else:
						if not com_ops.has(cp[0]):
							com_ops[cp[0]] = {}
						com_ops[cp[0]][cp[1]] = int(com_ops[cp[0]].get(cp[1], 0)) + 1
				"ladder":
					if not arg in ["bout", "win"]:
						problems.append("%s: ladder %s is not bout or win" % [where, arg])
				"companion":
					var cpa := arg.split(" ")
					if cpa.size() != 2 or not _json("res://data/world/companions.json")["companions"].has(cpa[0]) or not cpa[1] in ["join", "part"]:
						problems.append("%s: companion %s is not <who in data/world/companions.json> <join|part>" % [where, arg])
				"game":
					var gp := arg.split(" ")
					var gd := {"star_charts": _json("res://data/world/minigames/star_charts.json"), "sparks": _json("res://data/world/minigames/sparks.json")}
					var gg := ""
					for g in gd:
						if gd[g]["opponents"].has(gp[0]):
							gg = g
					if gp.size() != 2 or gg == "" or not gp[1] in ["free", "work", "coin"]:
						problems.append("%s: game %s is not <opponent in data/world/minigames/> <free|work|coin>" % [where, arg])
					elif gp[1] == "work" and not gd[gg]["opponents"][gp[0]].has("work"):
						problems.append("%s: %s has no work to play" % [where, gp[0]])
					elif gp[1] == "coin" and gg == "sparks":
						problems.append("%s: dice are never played for coin without playing (people spec §9.1)" % where)
					elif gp[1] != "coin" and not (s["outcomes"].has("won") and s["outcomes"].has("lost")):
						problems.append("%s: a game needs ? won and ? lost" % where)
				"bond", "gift", "bond_cross", "betray":
					var bp := arg.split(" ")
					var bd: Dictionary = _json("res://data/world/bonds.json")
					if not people.has(bp[0]) or str(people[bp[0]].get("kind", "full")) == "role":
						problems.append("%s: %s %s names nobody with a bond track" % [where, st["op"], arg])
					elif st["op"] == "bond" and (bp.size() < 2 or not bd["sources"].has(bp[1])):
						problems.append("%s: bond %s has no source from data/world/bonds.json" % [where, arg])
					elif st["op"] == "gift" and bp.size() < 2:
						problems.append("%s: gift %s names no item" % [where, arg])
				"sound":
					if not FileAccess.file_exists("res://assets/sfx/%s.wav" % arg):
						problems.append("%s: no sound assets/sfx/%s.wav" % [where, arg])
		for c in s["choices"]:
			if c["target"] != "" and not story.scenes.has(c["target"]):
				problems.append("%s: choice '%s' goes to missing scene %s" % [where, c["text"], c["target"]])
			if c["cond"] != "":
				conds.append([c["cond"], where])
		for o in s["outcomes"]:
			if not o in ["won", "lost"]:
				problems.append("%s: outcome must be won or lost, not %s" % [where, o])
			if not story.scenes.has(s["outcomes"][o]):
				problems.append("%s: outcome goes to missing scene %s" % [where, s["outcomes"][o]])
	# Fixed events (data/world/calendar.json, N-1.5): their scene, region, time and defaults exist.
	var regions: Dictionary = _json("res://data/world/regions.json")["regions"]
	for e in _json("res://data/world/calendar.json")["events"]:
		if e.get("kind", "") != "fixed":
			continue
		var where := "fixed event " + str(e["id"])
		if str(e.get("scene", "")) != "" and not story.scenes.has(str(e["scene"])):
			problems.append("%s: no scene %s" % [where, e["scene"]])
		if not regions.has(str(e.get("region", ""))):
			problems.append("%s: no region %s" % [where, e.get("region", "")])
		if not str(e.get("time", "")) in run.TIMES:
			problems.append("%s: time must be one of %s" % [where, run.TIMES])
		for fx in e.get("missed", []):
			var parts: PackedStringArray = str(fx).split(" ")
			if parts.size() != 2 or not parts[0] in ["set", "clear", "learn", "deed"]:
				problems.append("%s: missed effect %s must be set, clear, learn or deed with an id" % [where, fx])
			elif parts[0] == "learn" and not ledger.has(parts[1]):
				problems.append("%s: learns unknown Ledger entry %s" % [where, parts[1]])
			elif parts[0] == "set":
				flags_set[parts[1]] = true
	# Achievements' conditions too (data/world/achievements.json).
	var ach: Dictionary = _json("res://data/world/achievements.json")["list"]
	for id in ach:
		if str(ach[id].get("when", "")) != "":
			conds.append([str(ach[id]["when"]), "achievement " + id])
		for key in ["name", "hint", "kind"]:
			if str(ach[id].get(key, "")) == "":
				problems.append("achievement %s: no %s" % [id, key])
	# Conditions: they parse, run, and name things that exist.
	var re := RegEx.new()
	re.compile("\\b(k|f|seen|died|count|omen|ended|attended|missed|bond|bond_ready|rumour_heard|commission_[a-z]+)\\(\"([a-z0-9_]+)\"\\)")
	for pair in conds:
		var e := Expression.new()
		if e.parse(pair[0], ["loop", "day", "time", "ring"]) != OK:
			problems.append("%s: condition does not parse: %s" % [pair[1], pair[0]])
			continue
		e.execute([1, 1, "morning", 0], story.ctx)
		if e.has_execute_failed():
			problems.append("%s: condition fails to run: %s" % [pair[1], pair[0]])
		for m in re.search_all(pair[0]):
			var fn := m.get_string(1)
			var id := m.get_string(2)
			if fn == "k" and not ledger.has(id):
				problems.append("%s: k(\"%s\") is not a Ledger id" % [pair[1], id])
			elif fn == "f" and not flags_set.has(id):
				problems.append("%s: flag %s is never set" % [pair[1], id])
			elif fn == "rumour_heard" and not rumour_d.has(id):
				problems.append("%s: rumour_heard(\"%s\") is no rumour" % [pair[1], id])
			elif fn.begins_with("commission_") and not com_d.has(id):
				problems.append("%s: %s(\"%s\") is no commission" % [pair[1], fn, id])
			elif fn in ["bond", "bond_ready"] and not people.has(id):
				problems.append("%s: %s(\"%s\") is nobody in data/world/people.json" % [pair[1], fn, id])
			elif fn == "seen" and not story.scenes.has(id):
				problems.append("%s: seen(\"%s\") is not a scene" % [pair[1], id])
			elif fn == "omen" and not run.lives.get("omens", {}).has(id):
				problems.append("%s: omen(\"%s\") is not an Omen" % [pair[1], id])
			elif fn in ["attended", "missed"] and not run.cal["events"].any(func(ev): return ev["id"] == id and ev.get("kind", "") == "fixed"):
				problems.append("%s: %s(\"%s\") is not a fixed event" % [pair[1], fn, id])
			elif fn in ["died", "ended"] and not deaths.has(id):
				problems.append("%s: died(\"%s\") is not a death cause" % [pair[1], id])
	# Everyone you can walk up to says something, and every item does something, on any day
	# (talk_none: people you can't talk to, like Pip, who keeps her distance).
	for id in people:
		if id != "walker" and not people[id].get("talk_none", false) and not story.scenes.values().any(func(sc): return sc["talk"] == id and sc["days"].is_empty() and sc["when"] == ""):
			problems.append("person %s: no fallback talk scene (no days, no when)" % id)
	for mid in maps:
		for id in maps[mid]["items"]:
			if not story.scenes.values().any(func(sc): return sc["use"] == id and sc["cast"] == ""):
				problems.append("map %s, item %s: no use scene" % [mid, id])
	# Encounters and the Ledger's own references.
	for id in encounters:
		for wave in encounters[id]["waves"] + encounters[id].get("waived", []):
			for g in wave:
				if not foes.has(g["kind"]):
					problems.append("encounter %s: unknown enemy %s" % [id, g["kind"]])
	for id in ledger:
		var q: Dictionary = ledger[id]
		for key in ["opens", "clues", "needs"]:
			for ref in q.get(key, []):
				if not ledger.has(ref):
					problems.append("ledger %s: %s names unknown entry %s" % [id, key, ref])
		for key in ["insight", "closes"]:
			if q.has(key) and not ledger.has(q[key]):
				problems.append("ledger %s: %s names unknown entry %s" % [id, key, q[key]])
		if q.has("options") and not (int(q.get("answer", -1)) >= 0 and int(q["answer"]) < q["options"].size()):
			problems.append("ledger %s: answer is not one of the options" % id)
	# The first playable's beats: some scene teaches each.
	for beat in BEATS:
		var lid: String = BEATS[beat]
		if not story.scenes.values().any(func(sc): return sc["steps"].any(func(st): return st["t"] == "fx" and st["op"] == "learn" and st["arg"] == lid)):
			problems.append("beat %s: no scene teaches %s" % [beat, lid])
	# Commissions (people spec §6): each can be taken and paid, every step but the last is done by
	# some scene, every step's place is on its map, and a commission's scenes teach nothing, open no
	# road and give no merit (texture, not story).
	for cid in com_d:
		var c: Dictionary = com_d[cid]
		var ops: Dictionary = com_ops.get(cid, {})
		if not ops.has("take") or not ops.has("pay"):
			problems.append("commission %s: no scene takes it, or none pays it" % cid)
		if int(ops.get("next", 0)) < c["steps"].size() - 1:
			problems.append("commission %s: %d steps but only %d scenes move it on" % [cid, c["steps"].size(), int(ops.get("next", 0))])
		for st in c["steps"]:
			if not maps.has(str(st["map"])) or not maps[str(st["map"])]["places"].has(str(st["place"])):
				problems.append("commission %s: step place %s isn't on the map %s" % [cid, st["place"], st["map"]])
		var sp: Dictionary = c.get("hook", {}).get("spare", {})
		if not sp.is_empty() and not c["steps"].any(func(st): return st["place"] == sp["place"]):
			problems.append("commission %s: its hook spares %s, where no step is done" % [cid, sp["place"]])
		if str(c["board"]) != "" and not maps["camp"]["places"].has(str(c["board"])):
			problems.append("commission %s: no board %s in the camp" % [cid, c["board"]])
	for s in story.scenes.values():
		var is_com: bool = s["id"].begins_with("com_") or str(s["file"]).ends_with("commissions.story")
		if is_com and s["steps"].any(func(st): return st["t"] == "fx" and st["op"] in ["learn", "road", "merit", "trial", "model", "exam"]):
			problems.append("%s: a commission's scene gives something the main line needs (people spec §6.1)" % s["id"])
	# The camp ladder (people spec §7.1): every rung has its encounter, a duel, of its duelist's kind,
	# and some scene fights it.
	var lad: Dictionary = _json("res://data/world/ladders/camp.json")
	for n in range(1, lad["rungs"].size() + 1):
		var lid := "ladder_%d" % n
		var lk := str(lad["rungs"][n - 1]["kind"])
		if not encounters.has(lid) or not encounters[lid].has("hits") or str(encounters[lid]["waves"][0][0]["kind"]) != lk:
			problems.append("ladder rung %d: no duel %s of %s in data/world/encounters.json" % [n, lid, lk])
		elif not foes.has(lk):
			problems.append("ladder rung %d: no enemy kind %s" % [n, lk])
		elif not story.scenes.values().any(func(sc): return sc["steps"].any(func(st): return st["t"] == "fx" and st["op"] == "fight" and st["arg"] == lid)):
			problems.append("ladder rung %d: no scene fights %s" % [n, lid])
	# Companions (people spec §4.4): each is a person, with a role, a scene that joins them and one
	# that parts them, and night talks that exist.
	var comp: Dictionary = _json("res://data/world/companions.json")["companions"]
	for who in comp:
		var cr: Dictionary = comp[who]
		if not people.has(who) or str(people[who].get("kind", "full")) == "role":
			problems.append("companion %s: no person with a bond track" % who)
		if not str(cr["role"]) in ["guard", "cutter", "guide"]:
			problems.append("companion %s: no role %s" % [who, cr["role"]])
		for op in ["join", "part"]:
			if not story.scenes.values().any(func(sc): return sc["steps"].any(func(st): return st["t"] == "fx" and st["op"] == "companion" and st["arg"] == who + " " + op)):
				problems.append("companion %s: no scene does companion %s %s" % [who, who, op])
		for t in cr["talks"]:
			if not story.scenes.has(t):
				problems.append("companion %s: no night talk %s" % [who, t])
	# Minigames (people spec §9): every opponent is a person with a talk scene that plays their game,
	# and every Star-charts riddle's answer is among its options.
	for g in ["star_charts", "sparks"]:
		var gdat: Dictionary = _json("res://data/world/minigames/%s.json" % g)
		for who in gdat["opponents"]:
			if not people.has(who):
				problems.append("%s: no person %s" % [g, who])
			elif not story.scenes.values().any(func(sc): return sc["steps"].any(func(st): return st["t"] == "fx" and st["op"] == "game" and st["arg"].begins_with(who + " "))):
				problems.append("%s: no scene plays %s" % [g, who])
		if g == "star_charts":
			for rid in gdat["riddles"]:
				var rd: Dictionary = gdat["riddles"][rid]
				if not rd["answer"] in rd["options"] or rd["clues"].size() != 3:
					problems.append("star_charts riddle %s: three clues, and the answer among the options" % rid)
				if rd.has("rumour") and not _json("res://data/world/rumours.json")["rumours"].has(rd["rumour"]):
					problems.append("star_charts riddle %s: no rumour %s" % [rid, rd["rumour"]])
			for who in gdat["opponents"]:
				var tiers: Array = gdat["opponents"][who]["tier"].map(func(t): return int(t))
				if gdat["riddles"].values().filter(func(rd): return int(rd["tier"]) in tiers).size() < int(gdat["rounds"]):
					problems.append("star_charts: too few riddles for %s" % who)
	# Every missable event has a rumour (people spec §10): a fixed event that is an appointment has a
	# rumour pointing at it, from a scene that can play at least 7 days before it.
	var calendar: Dictionary = _json("res://data/world/calendar.json")
	for e in calendar["events"]:
		if e.get("kind", "") != "fixed" or not e.get("appointment", false):
			continue
		var at: int = (int(e["moon"]) - 1) * 28 + int(e["day"])
		var early := false
		for rid in rumour_d:
			if str(rumour_d[rid].get("points_at", {}).get("event", "")) != e["id"]:
				continue
			for sc in rumour_from.get(rid, []):
				if sc["days"].is_empty() or int(sc["days"].min()) <= at - 7:
					early = true
		if not early:
			problems.append("event %s: no rumour points at it from a scene 7 days before" % e["id"])
	print("[story] %d scenes, %d Ledger entries, %d conditions checked" % [story.scenes.size(), ledger.size(), conds.size()])
	for p in problems:
		print("[story] PROBLEM: " + str(p))
	if problems.is_empty():
		print("[story] all checks pass")
	quit(1 if not problems.is_empty() else 0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
