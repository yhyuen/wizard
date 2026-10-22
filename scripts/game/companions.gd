extends RefCounted
## Companions (people spec §4.4; build item N-7.6.6): who walks with you (one at a time), whether
## someone will, their night talks and their road sense. The life keeps it all (Run.life
## "companion", "talk_day", "guide_heard" {region:season: true}). Their part in a fight is
## scripts/ally.gd; following you is scripts/world/people.gd. Data in data/world/companions.json.

const PATH := "res://data/world/companions.json"

var run
var story  # for the gates (story conditions)
var rumours
var d: Dictionary


func _init(run_node, story_, rumours_) -> void:
	run = run_node
	story = story_
	rumours = rumours_
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func rec(who: String) -> Dictionary:
	return d["companions"].get(who, {})


## Who walks with you ("" for nobody).
func who() -> String:
	return str(run.life.get("companion", ""))


## `id` would walk with you now: a companion, their gate holds, and nobody walks with you yet
## (one at a time: part with one before asking another).
func can_join(id: String) -> bool:
	return not rec(id).is_empty() and who() == "" and story.test(str(rec(id)["gate"]))


func join(id: String) -> bool:
	if not can_join(id):
		return false
	run.life["companion"] = id
	return true


func part() -> void:
	run.life.erase("companion")


## Their next night talk not yet heard, if none has played tonight ("" otherwise).
func next_talk() -> String:
	if who() == "" or int(run.life.get("talk_day", -1)) == run.day():
		return ""
	for t in rec(who())["talks"]:
		if not run.seen(t):
			return t
	return ""


## A night talk is starting: one a night.
func talked() -> void:
	run.life["talk_day"] = run.day()


## The Guide's road sense: on first reaching `region` this season, one rumour from its pool.
## Returns the rumour heard, or "".
func region_rumour(region: String) -> String:
	if who() == "" or str(rec(who()).get("perk", "")) != "rumour" or region == "":
		return ""
	var key := "%s:%s" % [region, run.cal["moons"][run.moon() - 1]["season"]]
	if run.life.get("guide_heard", {}).has(key):
		return ""
	if not run.life.has("guide_heard"):
		run.life["guide_heard"] = {}
	run.life["guide_heard"][key] = true
	var r: String = rumours.draw(rumours.pool_now(region))
	if r != "" and rumours.hear(r):
		return r
	return ""
