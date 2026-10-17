extends SceneTree
## Checks the slice's story scripts (data/slice/story/) against the rest of the slice's data:
##
##   godot --headless --script res://tools/tests/story_lint.gd
##
## Every scene parses; every jump, Ledger id, Model, encounter, place, death cause, flag and
## condition it names exists; and the events for the traces days 1–7 need (R0–R4) are there.
## Exits non-zero on any problem.

const Story := preload("res://scripts/game/story.gd")
const TRACE_SCENES := {"R0": ["sit_with_wren"], "R1": ["fire"], "R2": ["mourner"], "R3": ["mill_risen"], "R4": ["tide", "bar_door"]}

var problems: Array = []


func _initialize() -> void:
	var run = root.get_node("Run")
	run.save_enabled = false
	run.new_run()
	var story = Story.new(run)
	story.load_all()
	problems.append_array(story.errors)
	var places: Dictionary = _json("res://data/slice/places.json")["places"]
	var encounters: Dictionary = _json("res://data/slice/encounters.json")["encounters"]
	var ld: Dictionary = _json("res://data/slice/ledger.json")
	var ledger: Dictionary = ld["entries"]
	var deaths: Dictionary = ld["deaths"]
	var spells: Dictionary = _json("res://data/spells.json")
	var flags_set := {}
	var conds: Array = []  # [condition, where]
	for s in story.scenes.values():
		var where := "%s:%d (%s)" % [s["file"], s["line"], s["id"]]
		for p in s["places"]:
			if p != "anywhere" and not places.has(p):
				problems.append("%s: unknown place %s" % [where, p])
		if not s["places"].is_empty() and (s["days"].is_empty() or s["times"].is_empty()):
			problems.append("%s: an event needs days and times" % where)
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
				"end_loop":
					if not deaths.has(arg):
						problems.append("%s: no death text for %s" % [where, arg])
				"cutscene":
					if not arg in ["fire", "mourner"]:
						problems.append("%s: no cutscene '%s' (scripts/game/cutscene.gd)" % [where, arg])
				"sound":
					if not FileAccess.file_exists("res://assets/sfx/%s.wav" % arg):
						problems.append("%s: no sound assets/sfx/%s.wav" % [where, arg])
				"skip_to":
					if not str(arg.split(" ")[0]).is_valid_int():
						problems.append("%s: skip_to needs a day" % where)
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
	# Conditions: they parse, run, and name things that exist.
	var re := RegEx.new()
	re.compile("(k|f|seen|died|count)\\(\"([a-z0-9_]+)\"\\)")
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
			elif fn == "seen" and not story.scenes.has(id):
				problems.append("%s: seen(\"%s\") is not a scene" % [pair[1], id])
			elif fn == "died" and not deaths.has(id):
				problems.append("%s: died(\"%s\") is not a death cause" % [pair[1], id])
	# Places, encounters and the Ledger's own references.
	for id in places:
		if not story.scenes.has(places[id]["idle"]):
			problems.append("place %s: idle scene %s is missing" % [id, places[id]["idle"]])
	for id in encounters:
		for wave in encounters[id]["waves"] + encounters[id].get("waived", []):
			for g in wave:
				if not spells["enemies"].has(g["kind"]):
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
	# The traces days 1–7 need.
	for t in TRACE_SCENES:
		for sid in TRACE_SCENES[t]:
			if not story.scenes.has(sid):
				problems.append("trace %s: scene %s is missing" % [t, sid])
			elif story.scenes[sid]["days"].filter(func(d): return d >= 1 and d <= 7).is_empty():
				problems.append("trace %s: scene %s is not on days 1-7" % [t, sid])
	print("[story] %d scenes, %d Ledger entries, %d conditions checked" % [story.scenes.size(), ledger.size(), conds.size()])
	for p in problems:
		print("[story] PROBLEM: " + str(p))
	if problems.is_empty():
		print("[story] all checks pass")
	quit(1 if not problems.is_empty() else 0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
