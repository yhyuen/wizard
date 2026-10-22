extends RefCounted
## Achievements (design/lives/lives-and-carryover-spec.md §7; build item N-1.2, the frame): deeds
## the soul remembers, from data/world/achievements.json. `check` earns every one whose story
## condition now holds; an earned one is kept in the soul with the life, moon and day, grants its
## title, and is copied to the profile so it outlives the playthrough (save spec §3).

const PATH := "res://data/world/achievements.json"

var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
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
	var t: String = str(get_def(id).get("grants", {}).get("title", ""))
	if t != "":
		if not s.has("titles"):
			s["titles"] = []
		if not t in s["titles"]:
			s["titles"].append(t)
		if str(s.get("title", "")) == "":
			s["title"] = t
	if not run.life.has("earned"):
		run.life["earned"] = []
	run.life["earned"].append(id)
	run.save_soul()
	run.profile_earn(id)
	return true


## The toast for an earned achievement (UI spec §3.6): the deed and what it grants.
func toast_text(id: String) -> String:
	var a: Dictionary = get_def(id)
	var t: String = str(a.get("grants", {}).get("title", ""))
	return "Deed: %s%s" % [a["name"], (". Title: " + t) if t != "" else ""]


## How the Deeds tab shows `id`: its name and line, a "?" and hint if hidden, nothing if sealed.
func shown(id: String) -> Dictionary:
	var a: Dictionary = get_def(id)
	if earned(id):
		var e: Dictionary = run.soul["achievements"][id]
		var t: String = str(a.get("grants", {}).get("title", ""))
		return {"name": a["name"], "line": "Life %d, %s." % [int(e["life"]), run.date_name(run.day_of(int(e["moon"]), int(e["day"])))]
			+ ((" Title: " + t + ".") if t != "" else ""), "earned": true}
	if a.get("sealed", false):
		return {"name": "A deed not yet done", "line": "", "earned": false}
	if a.get("hidden", false):
		return {"name": "?", "line": str(a.get("hint", "")), "earned": false}
	return {"name": a["name"], "line": str(a.get("hint", "")), "earned": false}
