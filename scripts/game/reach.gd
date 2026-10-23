extends RefCounted
## The Reach between maps (build items N-1.1 and N-1.4): which region a map belongs to, the days a
## journey costs along the roads (data/world/regions.json), and the calendar's dated events
## (data/world/calendar.json) that you know of and can rest until.

const REGIONS := "res://data/world/regions.json"
const Seasons := preload("res://scripts/world/seasons.gd")

var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
var run  # the Run autoload
var story  # scripts/game/story.gd, for the events' "known" conditions


func _init(the_run = null, the_story = null) -> void:
	run = the_run
	story = the_story


func regions() -> Dictionary:
	return d["regions"]


func region(id: String) -> Dictionary:
	return d["regions"].get(id, {})


## A region with no maps is a card: it isn't built yet, and going there costs no time.
func built(id: String) -> bool:
	return not region(id).get("maps", []).is_empty()


## The region a map belongs to ("" if none lists it).
func region_of(map_id: String) -> String:
	for id in d["regions"]:
		if map_id in d["regions"][id].get("maps", []):
			return id
	return ""


## Days road [a, b, days] takes now: winter adds a day to every road, and the Thaw's high water a
## day at a ford (seasons spec §5.2, N-4.5.3).
func road_days(road: Array) -> int:
	return int(road[2]) + (Seasons.road_extra(run, str(road[0]), str(road[1])) if run != null else 0)


## Days along the cheapest roads from `a` to `b`, or -1 if no road leads there.
func days_between(a: String, b: String) -> int:
	if a == b:
		return 0
	var best := {a: 0}
	var open := [a]
	while not open.is_empty():
		open.sort_custom(func(x, y): return best[x] < best[y])
		var at: String = open.pop_front()
		for road in d["roads"]:
			var to := ""
			if road[0] == at:
				to = road[1]
			elif road[1] == at:
				to = road[0]
			if to == "":
				continue
			var cost: int = int(best[at]) + road_days(road)
			if not best.has(to) or cost < int(best[to]):
				best[to] = cost
				open.append(to)
	return int(best.get(b, -1))


## The calendar's events as days of the year, each {"id", "name", "kind", "day", "known",
## "appointment", "time"}.
func events() -> Array:
	var out: Array = []
	for e in run.cal["events"]:
		var known = e.get("known", false)
		var k: bool = known if known is bool else (story != null and str(known) != "" and story.test(str(known)))
		# A fixed event's date is known once you've seen it come or go in any life.
		k = k or run.soul.get("dates", {}).has(e["id"])
		# A calamity's signs pin its date before you know its name (seasons spec §6.2): "?".
		var pin: bool = not k and run.flag("pinned_" + str(e["id"]))
		out.append({"id": e["id"], "name": "?" if pin else e["name"], "kind": e.get("kind", "fixed"),
			"day": run.event_day(e), "known": k or pin,
			"appointment": run.soul.get("appointments", {}).has(e["id"]), "time": str(e.get("time", ""))})
	out.sort_custom(func(x, y): return x["day"] < y["day"])
	return out


## What you can rest until from here: the known events still ahead, and the next moon's first day,
## soonest first.
func rest_targets() -> Array:
	var out: Array = events().filter(func(e): return e["known"] and e["day"] > run.day())
	if run.moon() < run.MOONS:
		out.append({"id": "moon", "name": "%s begins" % run.moon_name(run.moon() + 1), "kind": "moon",
			"day": run.day_of(run.moon() + 1, 1), "known": true})
	out.sort_custom(func(x, y): return x["day"] < y["day"])
	return out
