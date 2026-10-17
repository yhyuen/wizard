extends RefCounted
## Loads the slice's story scripts (data/slice/story/*.story) and answers questions about them:
## which event plays at a place and time, which plays wherever you are, and whether a condition
## holds. The format is in design/slice/tech-plan.md §2:
##
##   === scene_id
##   place: archive          (with days and times, this scene is an event on the board)
##   days: 4                 (4, 1-7 or 2,3)
##   times: noon             (morning, noon, afternoon, dusk, night; several with commas; or any)
##   when: not f("wren_friend")
##   Wren: A line spoken by Wren.
##   A line with no speaker is narration.
##   + learn wren_sea        (an effect)
##   * A choice [condition] -> next_scene
##   ? won -> scene_after_a_won_fight
##
## Conditions are Godot expressions over k(id) (remembered), f(id) (flag this loop), seen(id)
## (scene played this loop), died(cause), count(prefix) (flags starting with prefix), and the
## values loop, day, time and ring. A line, effect or outcome can start with [condition] to
## happen only when it holds. `place` can list several places; `slot: free` means playing the
## scene doesn't use up the time of day.

const DIR := "res://data/slice/story/"
const HEADER_KEYS := ["place", "days", "times", "when", "force", "priority", "repeat", "known", "title", "slot"]
const EFFECTS := ["learn", "set", "clear", "fight", "wells", "train", "meditate", "study", "goto", "end_loop",
	"skip_to", "slice_end", "model", "trial"]

var scenes := {}  # id -> scene dictionary
var errors: Array = []  # parse errors, for the linter
var _exprs := {}  # condition string -> Expression
var ctx := Ctx.new()


class Ctx:
	var run  # the Run autoload
	var ring := 0

	func k(id: String) -> bool:
		return run.knows(id)

	func f(id: String) -> bool:
		return run.flag(id)

	func seen(id: String) -> bool:
		return run.seen(id)

	func died(cause: String) -> bool:
		return run.died_of(cause) > 0

	func count(prefix: String) -> int:
		return run.lp["flags"].keys().filter(func(k): return str(k).begins_with(prefix)).size()


func _init(run = null) -> void:
	ctx.run = run


func load_all() -> void:
	scenes.clear()
	errors.clear()
	var dir := DirAccess.open(DIR)
	if dir == null:
		errors.append("no story directory at " + DIR)
		return
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".story"):
			files.append(f)
	files.sort()
	for f in files:
		parse(FileAccess.get_file_as_string(DIR + f), f)


## Parses one file's text into scenes.
func parse(text: String, file := "") -> void:
	var cur: Dictionary = {}
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("==="):
			var id := line.trim_prefix("===").strip_edges()
			if scenes.has(id):
				errors.append("%s:%d: scene %s is defined twice" % [file, n, id])
			cur = {"id": id, "file": file, "line": n, "steps": [], "choices": [], "outcomes": {},
				"days": [], "times": [], "place": "", "places": [], "slot": "", "when": "", "force": false, "priority": 0,
				"repeat": false, "known": "", "title": ""}
			scenes[id] = cur
			continue
		if cur.is_empty():
			errors.append("%s:%d: text before the first scene" % [file, n])
			continue
		var cond := ""
		if line.begins_with("["):
			var close := line.find("] ")
			if close < 0:
				errors.append("%s:%d: a condition needs '] ' after it" % [file, n])
				continue
			cond = line.substr(1, close - 1).strip_edges()
			line = line.substr(close + 2).strip_edges()
		var colon := line.find(":")
		if cond.is_empty() and colon > 0 and line.substr(0, colon) in HEADER_KEYS and cur["steps"].is_empty() and cur["choices"].is_empty():
			_header(cur, line.substr(0, colon), line.substr(colon + 1).strip_edges(), file, n)
		elif line.begins_with("+"):
			var parts := line.substr(1).strip_edges().split(" ", false, 1)
			var op: String = parts[0] if parts.size() > 0 else ""
			if not op in EFFECTS:
				errors.append("%s:%d: unknown effect '%s'" % [file, n, op])
			cur["steps"].append({"t": "fx", "op": op, "arg": parts[1] if parts.size() > 1 else "", "line": n, "cond": cond})
		elif line.begins_with("*"):
			if not cond.is_empty():
				errors.append("%s:%d: put a choice's condition in [ ] after its text" % [file, n])
			cur["choices"].append(_choice(line.substr(1).strip_edges(), n))
		elif line.begins_with("?"):
			var body := line.substr(1).strip_edges()
			var arrow := body.find("->")
			if arrow < 0:
				errors.append("%s:%d: an outcome needs '-> scene'" % [file, n])
				continue
			cur["outcomes"][body.substr(0, arrow).strip_edges()] = body.substr(arrow + 2).strip_edges()
		else:
			var m := _speaker(line)
			cur["steps"].append({"t": "line", "who": m[0], "text": m[1], "line": n, "cond": cond})


func _header(cur: Dictionary, key: String, val: String, file: String, n: int) -> void:
	match key:
		"days":
			for part in val.split(","):
				part = part.strip_edges()
				if "-" in part:
					var ab := part.split("-")
					for d in range(int(ab[0]), int(ab[1]) + 1):
						cur["days"].append(d)
				elif part.is_valid_int():
					cur["days"].append(int(part))
				else:
					errors.append("%s:%d: bad day '%s'" % [file, n, part])
		"times":
			for part in val.split(","):
				part = part.strip_edges()
				if part == "any":
					cur["times"] = Array(preload("res://scripts/game/run.gd").TIMES)
				elif part in preload("res://scripts/game/run.gd").TIMES:
					cur["times"].append(part)
				else:
					errors.append("%s:%d: bad time '%s'" % [file, n, part])
		"force", "repeat":
			cur[key] = val == "true"
		"priority":
			cur[key] = int(val)
		"place":
			cur["place"] = val
			for part in val.split(","):
				cur["places"].append(part.strip_edges())
		_:
			cur[key] = val


func _choice(body: String, n: int) -> Dictionary:
	var c := {"text": body, "cond": "", "target": "", "line": n}
	var arrow := body.find("->")
	if arrow >= 0:
		c["target"] = body.substr(arrow + 2).strip_edges()
		body = body.substr(0, arrow).strip_edges()
	if body.ends_with("]") and body.find("[") >= 0:
		var b := body.rfind("[")
		c["cond"] = body.substr(b + 1, body.length() - b - 2).strip_edges()
		body = body.substr(0, b).strip_edges()
	c["text"] = body
	return c


## "Wren: Hello." -> ["Wren", "Hello."]. A speaker is one capitalised word before ": ".
func _speaker(line: String) -> Array:
	var colon := line.find(": ")
	if colon > 0 and colon <= 12:
		var who := line.substr(0, colon)
		if not " " in who and who[0] == who[0].to_upper() and who.is_valid_identifier():
			return [who, line.substr(colon + 2)]
	return ["", line]


# --- queries -----------------------------------------------------------------------

## Whether `cond` holds now. An empty condition always holds.
func test(cond: String) -> bool:
	if cond.strip_edges().is_empty():
		return true
	var e: Expression = _exprs.get(cond)
	if e == null:
		e = Expression.new()
		if e.parse(cond, ["loop", "day", "time", "ring"]) != OK:
			push_error("story condition does not parse: %s (%s)" % [cond, e.get_error_text()])
			return false
		_exprs[cond] = e
	var r = e.execute([ctx.run.loop(), ctx.run.day(), ctx.run.time_id(), ctx.ring], ctx)
	if e.has_execute_failed():
		push_error("story condition failed: %s" % cond)
		return false
	return bool(r)


## Whether scene `s` can play now as an event (its day, time and condition, and not yet this loop).
func eligible(s: Dictionary) -> bool:
	if s["days"].is_empty() or s["times"].is_empty():
		return false
	if not ctx.run.day() in s["days"] or not ctx.run.time_id() in s["times"]:
		return false
	if not s["repeat"] and ctx.run.seen(s["id"]):
		return false
	return test(s["when"])


## The event that plays if you go to `place` now, or "" for none. Highest priority wins.
func event_at(place: String) -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		if place in s["places"] and not s["force"] and eligible(s) and int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## A forced event for this time (plays wherever you are), or "".
func forced() -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		if s["force"] and eligible(s) and int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## Events at `place` today (any time) whose `known` condition holds: what the board can show
## because you already know it will happen. Returns [{"id", "time", "title"}].
func known_today(place: String) -> Array:
	var out: Array = []
	for s in scenes.values():
		if not place in s["places"] or s["known"].is_empty() or not ctx.run.day() in s["days"]:
			continue
		if ctx.run.seen(s["id"]) or not test(s["known"]):
			continue
		out.append({"id": s["id"], "time": s["times"][0] if s["times"].size() > 0 else "", "title": s["title"]})
	return out


func choices(s: Dictionary) -> Array:
	return s["choices"].filter(func(c): return test(c["cond"]))
