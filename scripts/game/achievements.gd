extends RefCounted
## Achievements (design/lives/lives-and-carryover-spec.md §7; build items N-1.2, the frame, and
## N-7.7, the list and its grants): deeds the soul remembers, from data/world/achievements.json.
## `check` earns every one whose story condition now holds; an earned one is kept in the soul with
## the life, moon and day, grants what it lists (a title, a sigil, a Codex page, Ledger knowledge,
## a remembered cache) and is copied to the profile so it outlives the playthrough (save spec §3).
## A cache earned is known for good; each life you mark up to `marks` of them on moon `mark_moon`,
## and a marked one's map item is there to open (`open_cache`).

const PATH := "res://data/world/achievements.json"
const KINDS := ["region", "school", "life", "craft", "story", "challenge"]

var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
var _entries := {}  # data/world/ledger.json "entries", for knowledge's names
var run  # the Run autoload
var story  # scripts/game/story.gd, for the conditions


func _init(the_run = null, the_story = null) -> void:
	run = the_run
	story = the_story


func ids() -> Array:
	return d["list"].keys()


func get_def(id: String) -> Dictionary:
	return d["list"].get(id, {})


func earned(id: String) -> bool:
	return run.soul.get("achievements", {}).has(id)


## Earns every achievement whose condition holds now. Returns the ids earned, in list order.
func check() -> Array:
	var out: Array = []
	for id in d["list"]:
		var a: Dictionary = d["list"][id]
		if earned(id) or str(a.get("when", "")) == "":
			continue
		if story.test(str(a["when"])):
			earn(id)
			out.append(id)
	return out


## Earns `id` (once): the soul keeps it and its title, this life's page lists it, and the profile
## gets a copy.
func earn(id: String) -> bool:
	if earned(id) or not d["list"].has(id):
		return false
	var s: Dictionary = run.soul
	if not s.has("achievements"):
		s["achievements"] = {}
	s["achievements"][id] = {"life": run.loop(), "moon": run.moon(), "day": run.moon_day()}
	var g: Dictionary = get_def(id).get("grants", {})
	var t: String = str(g.get("title", ""))
	if t != "":
		_add(s, "titles", t)
		if str(s.get("title", "")) == "":
			s["title"] = t
	var sg: String = str(g.get("sigil", ""))
	if sg != "":
		_add(s, "sigils", sg)
		if str(s.get("sigil", "")) == "":
			s["sigil"] = sg
	if str(g.get("codex", "")) != "":
		_add(s, "codex", str(g["codex"]))
	if str(g.get("cache", "")) != "":
		_add(s, "caches", str(g["cache"]))
	for k in g.get("knowledge", []):
		run.learn(str(k))
	if not run.life.has("earned"):
		run.life["earned"] = []
	run.life["earned"].append(id)
	run.save_soul()
	run.profile_earn(id)
	return true


func _ledger() -> Dictionary:
	if _entries.is_empty():
		_entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/ledger.json"))["entries"]
	return _entries


func _add(s: Dictionary, key: String, v: String) -> void:
	if not s.has(key):
		s[key] = []
	if not v in s[key]:
		s[key].append(v)


## What `id` grants, in words: "Title: Survivor. Sigil: The Fallen Beam. A Codex page." A road it
## opens is only "Something will be waiting next year" (lives spec §7.3).
func grant_text(id: String) -> String:
	var g: Dictionary = get_def(id).get("grants", {})
	var out: Array = []
	if str(g.get("title", "")) != "":
		out.append("Title: %s." % g["title"])
	if str(g.get("sigil", "")) != "":
		out.append("Sigil: %s." % sigil_name(str(g["sigil"])))
	if str(g.get("codex", "")) != "":
		out.append("A Codex page.")
	for k in g.get("knowledge", []):
		out.append("In the Ledger: %s." % str(_ledger().get(str(k), {}).get("title", k)))
	if str(g.get("cache", "")) != "":
		out.append("You'll remember where it was.")
	for r in run.lives.get("roads", {}).values():
		if str(r.get("opens_by", "")) == id:
			out.append("Something will be waiting next year.")
			break
	return " ".join(out)


## The toast for an earned achievement (UI spec §3.6): the deed and what it grants.
func toast_text(id: String) -> String:
	var gt := grant_text(id)
	return "Deed: %s.%s" % [get_def(id)["name"], (" " + gt) if gt != "" else ""]


func sigil_name(sid: String) -> String:
	return str(d.get("sigils", {}).get(sid, {}).get("name", sid))


## The achievements of one kind, in list order.
func of_kind(kind: String) -> Array:
	return ids().filter(func(id): return str(d["list"][id]["kind"]) == kind)


# --- the Codex: pages and caches ----------------------------------------------------------------

## The Codex pages earned, in the order earned: [{id, title, text}].
func pages() -> Array:
	var out: Array = []
	for pid in run.soul.get("codex", []):
		var pg: Dictionary = d.get("pages", {}).get(pid, {})
		if not pg.is_empty():
			out.append({"id": pid, "title": pg["title"], "text": pg["text"]})
	return out


## The caches you remember, in the order earned.
func caches() -> Array:
	return run.soul.get("caches", []).filter(func(c): return d.get("caches", {}).has(c))


func cache(cid: String) -> Dictionary:
	return d.get("caches", {}).get(cid, {})


func marked() -> Array:
	return run.life.get("marked", [])


## Caches can be marked while it is still the first moon, up to `marks` a life.
func can_mark() -> bool:
	return run.moon() <= int(d.get("mark_moon", 1))


## Marks (or unmarks) a remembered cache for this life. False if it can't be.
func mark(cid: String) -> bool:
	if not cid in caches() or not can_mark() or run.life.get("taken", {}).has(cache(cid).get("item", "")):
		return false
	if not run.life.has("marked"):
		run.life["marked"] = []
	if cid in run.life["marked"]:
		run.life["marked"].erase(cid)
		return true
	if run.life["marked"].size() >= int(d.get("marks", 2)):
		return false
	run.life["marked"].append(cid)
	return true


## The cache behind map item `item`, or "".
func cache_at(item: String) -> String:
	for cid in d.get("caches", {}):
		if str(d["caches"][cid]["item"]) == item:
			return cid
	return ""


## You open a marked cache: what it gives, {"crowns": n, "reagents": {...}}; the item is taken
## for the rest of the life. {} if it isn't marked.
func open_cache(cid: String) -> Dictionary:
	if not cid in marked():
		return {}
	var c: Dictionary = cache(cid)
	if not run.life.has("taken"):
		run.life["taken"] = {}
	run.life["taken"][str(c["item"])] = true
	var g: Dictionary = c.get("gives", {})
	if g.has("crowns"):
		run.life["crowns"] = int(run.life.get("crowns", 0)) + int(g["crowns"])
	return g


## How the Deeds tab shows `id`: its name and line, a "?" and hint if hidden, nothing if sealed.
func shown(id: String) -> Dictionary:
	var a: Dictionary = get_def(id)
	if earned(id):
		var e: Dictionary = run.soul["achievements"][id]
		var gt := grant_text(id)
		return {"name": a["name"], "line": "Life %d, %s." % [int(e["life"]), run.date_name(run.day_of(int(e["moon"]), int(e["day"])))]
			+ ((" " + gt) if gt != "" else ""), "earned": true}
	if a.get("sealed", false):
		return {"name": "A deed not yet done", "line": "", "earned": false}
	if a.get("hidden", false):
		return {"name": "?", "line": str(a.get("hint", "")), "earned": false}
	return {"name": a["name"], "line": str(a.get("hint", "")), "earned": false}
