extends RefCounted
## Loads the story scripts of every map (data/world/maps.json "story": the camp's in
## data/world/story/, each ruin layer's in data/ruins/<layer>/story/) and answers questions about them:
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
## (scene played this loop), died(cause), count(prefix) (flags starting with prefix), done(op)
## (a once-a-day action such as "meditate" already done today), and the values loop, day, time
## and ring. A line, effect or outcome can start with [condition] to
## happen only when it holds. `place` can list several places; `slot: free` means playing the
## scene doesn't use up the time of day. `backdrop: north_door` paints that place behind a scene
## that has no place of its own (and the scenes it leads to).
##
## The open world (design/open-world/tech-plan.md §3) adds what starts a scene: `talk: wren`
## (talking to that person), `use: noon_note` (using that item), `arrive: market` (walking into
## that place, or any of several), and `cast: fire` with `use:` (that element hitting the item).
## Such scenes play on any day and at any time unless they say otherwise. New effects: `move
## <spot>`, `take <item>`, `sleep` (end the day), `book` (open the spellbook) and `today <op>`
## (mark a once-a-day thing done, for done(op)).
##
## The ruins (design/ruins/tech-plan.md §1) add `go <map> <spot>` (when the scene closes, the
## loading card takes you there) and `go <exit>` (through that exit of the map you're on); an
## exit you walk into plays `use: <exit id>` first, if there is such a scene.
## R2 adds `open <door>` (that door of this map stands open for the rest of the loop),
## `play_path <id>` (a recorded path from the map's paths file plays, as a cutscene) and
## `cast: hours` (Rewind's shard formed on the item).
## N-5.2 adds `bench` (work at a bench: fill your devices from your reagents, a time of day) and
## `bench stock` (the Lamplighters' spare reagents, data/schools.json devices.starter).

const MAPS := "res://data/world/maps.json"
const HEADER_KEYS := ["place", "days", "times", "when", "force", "priority", "repeat", "known", "title", "slot", "backdrop",
	"talk", "use", "arrive", "cast"]
const EFFECTS := ["learn", "set", "clear", "fight", "wells", "train", "meditate", "goto", "end_loop",
	"model", "trial", "sound", "cutscene", "move", "take", "sleep", "book", "today", "go", "open", "play_path", "road", "deed", "omen", "forecast", "bench"]

var scenes := {}  # id -> scene dictionary
var errors: Array = []  # parse errors, for the linter
var _exprs := {}  # condition string -> Expression
var ctx := Ctx.new()


class Ctx:
	var run  # the Run autoload
	var ring := 0
	var growth  # scripts/game/growth.gd, when the slice has one: gives the real Ring

	## A once-a-day action (meditate, train) already done today.
	func done(op: String) -> bool:
		return int(run.life.get("done_" + op, 0)) == run.day()

	func k(id: String) -> bool:
		return run.knows(id)

	func f(id: String) -> bool:
		return run.flag(id)

	func seen(id: String) -> bool:
		return run.seen(id)

	## This life's road is `id` ("" before one is taken).
	func on_road(id: String) -> bool:
		return run.road() == id

	## Road `id` offers itself this life (open, not taken last life, no road taken yet).
	func offered(id: String) -> bool:
		return id in run.road_offers()

	## The Hours can be turned back (a calamity has passed in this life).
	func can_turn() -> bool:
		return run.can_turn()

	## This life is ending for `cause` (true only while the Turning checks achievements).
	func ended(cause: String) -> bool:
		return str(run.life.get("ended", "")) == cause

	## Omen `id` is taken this life.
	func omen(id: String) -> bool:
		return id in run.omens()

	## How many Omens this life is under.
	func omens() -> int:
		return run.omens().size()

	## The Omens can be read now (the first morning of life 2 onwards).
	func omens_offered() -> bool:
		return run.omens_offered()

	## Fixed event `id` happened with you there this life.
	func attended(id: String) -> bool:
		return run.event_state(id) == "attended"

	## Fixed event `id` went by without you, in this life or one before (an appointment).
	func missed(id: String) -> bool:
		return run.event_state(id) == "missed" or run.soul.get("appointments", {}).has(id)

	func died(cause: String) -> bool:
		return run.died_of(cause) > 0

	func count(prefix: String) -> int:
		return run.life["flags"].keys().filter(func(k): return str(k).begins_with(prefix)).size()


func _init(run = null) -> void:
	ctx.run = run


## Every map's story folder, from the maps registry.
static func dirs() -> Array:
	var out: Array = []
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPS))
	for id in reg["maps"]:
		var d: String = str(reg["maps"][id].get("story", ""))
		if d != "" and not d in out:
			out.append(d)
	return out


func load_all() -> void:
	scenes.clear()
	errors.clear()
	for dir_path in dirs():
		var dir := DirAccess.open(dir_path)
		if dir == null:
			errors.append("no story directory at " + dir_path)
			continue
		var files: Array = []
		for f in dir.get_files():
			if f.ends_with(".story"):
				files.append(f)
		files.sort()
		for f in files:
			parse(FileAccess.get_file_as_string(dir_path + f), dir_path + f)


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
				"repeat": false, "known": "", "title": "", "backdrop": "", "talk": "", "use": "", "arrive": "", "arrives": [], "cast": ""}
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
			var bad: Array = []
			cur["days"].append_array(parse_days(val, bad))
			for b in bad:
				errors.append("%s:%d: bad day '%s'" % [file, n, b])
		"times":
			var bad: Array = []
			cur["times"].append_array(parse_times(val, bad))
			for b in bad:
				errors.append("%s:%d: bad time '%s'" % [file, n, b])
		"force", "repeat":
			cur[key] = val == "true"
		"priority":
			cur[key] = int(val)
		"place":
			cur["place"] = val
			for part in val.split(","):
				cur["places"].append(part.strip_edges())
		"arrive":
			cur["arrive"] = val
			for part in val.split(","):
				cur["arrives"].append(part.strip_edges())
		_:
			cur[key] = val


## "4", "1-7" or "2,3" -> the days. Anything that doesn't parse goes into `bad`.
static func parse_days(val: String, bad: Array = []) -> Array:
	var out: Array = []
	for part in val.split(","):
		part = part.strip_edges()
		if "-" in part:
			var ab := part.split("-")
			for d in range(int(ab[0]), int(ab[1]) + 1):
				out.append(d)
		elif part.is_valid_int():
			out.append(int(part))
		else:
			bad.append(part)
	return out


## "morning, noon", or "any" -> the times of day.
static func parse_times(val: String, bad: Array = []) -> Array:
	var all: Array = Array(preload("res://scripts/game/run.gd").TIMES)
	var out: Array = []
	for part in val.split(","):
		part = part.strip_edges()
		if part == "any":
			return all.duplicate()
		elif part in all:
			out.append(part)
		else:
			bad.append(part)
	return out


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
	var ring: int = ctx.growth.ring() if ctx.growth != null else ctx.ring
	var r = e.execute([ctx.run.loop(), ctx.run.day(), ctx.run.time_id(), ring], ctx)
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


# --- the open world --------------------------------------------------------------

## Whether a talk, use or arrive scene can play now: its days and times (any, when it names
## none), its condition, and not yet this loop unless it repeats.
func eligible_any(s: Dictionary) -> bool:
	if not s["days"].is_empty() and not ctx.run.day() in s["days"]:
		return false
	if not s["times"].is_empty() and not ctx.run.time_id() in s["times"]:
		return false
	if not s["repeat"] and ctx.run.seen(s["id"]):
		return false
	return test(s["when"])


func _best(key: String, val: String, extra := "") -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		var match_: bool = val in s["arrives"] if key == "arrive" else s[key] == val
		if not match_ or s["cast"] != extra or not eligible_any(s):
			continue
		if int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## The conversation with `person` now, or "".
func talk_scene(person: String) -> String:
	return _best("talk", person)


## What using `item` plays now, or "".
func use_scene(item: String) -> String:
	return _best("use", item)


## What walking into `place` plays now, or "".
func arrive_scene(place: String) -> String:
	return _best("arrive", place)


## What `element` hitting `item` plays now, or "".
func cast_scene(item: String, element: String) -> String:
	return _best("use", item, element)


## Events today whose `known` condition holds, for the map: [{"id", "time", "title", "where"}].
## `where` is the place, person or item the event belongs to.
func known_events() -> Array:
	var out: Array = []
	for s in scenes.values():
		if s["known"].is_empty() or not ctx.run.day() in s["days"] or ctx.run.seen(s["id"]) or not test(s["known"]):
			continue
		var where: String = s["arrive"] if s["arrive"] != "" else (s["talk"] if s["talk"] != "" else s["use"])
		out.append({"id": s["id"], "time": s["times"][0] if s["times"].size() > 0 else "", "title": s["title"], "where": where})
	return out


func choices(s: Dictionary) -> Array:
	return s["choices"].filter(func(c): return test(c["cond"]))
