extends RefCounted
## Seasons dress the world (design/seasons/seasons-and-calamities-spec.md §5, data/world/seasons.json):
## which times of day are dark, the rivers' water, the Mill fields' crops, how fast nature mends
## and the extra days on the roads, all from the moon (and, for the dark, the day's weather).
## Pure lookups on a Run; the world, the story, the witnesses and the Reach read them.

const DATA := "res://data/world/seasons.json"
const TIMES: Array = ["morning", "noon", "afternoon", "dusk", "night"]  # Run.TIMES

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _d


## "spring" .. "winter" for moon `m` (default: this moon).
static func season(run, m := 0) -> String:
	m = m if m > 0 else run.moon()
	return str(run.cal["moons"][m - 1]["season"]).to_lower()


static func rules(run, m := 0) -> Dictionary:
	return data()["seasons"][season(run, m)]


## The dark times of day now, given today's weather `kind` ("" for none).
static func dark_times(run, kind: String) -> Array:
	var r := rules(run)
	var out: Array = (r["dark"] as Array).duplicate()
	if kind in data()["dim_kinds"]:
		out.append_array(r["dim"])
		out.append_array(r.get("dim_moons", {}).get(str(run.moon()), []))
	return out


## Whether it is dark now (Hollows walk, witnesses see less).
static func dark(run, kind: String) -> bool:
	return run.time_id() in dark_times(run, kind)


## The earliest dark time today, as an index into Run.TIMES.
static func first_dark(run, kind: String) -> int:
	var best: int = TIMES.size() - 1
	for t in dark_times(run, kind):
		best = mini(best, TIMES.find(t))
	return best


## The value in `by_moon` that holds in moon `m`: the last one listed at or before it.
static func _by_moon(table: Dictionary, m: int, fallback: String) -> String:
	var out := fallback
	for k in range(1, m + 1):
		out = str(table.get(str(k), out))
	return out


## The rivers this moon: "high", "low", "frozen" or "" (normal).
static func river(run, m := 0) -> String:
	m = m if m > 0 else run.moon()
	return str(data()["rivers"]["by_moon"].get(str(m), ""))


## Which of map `map_id`'s water rects are rivers.
static func rivers_on(map_id: String) -> Array:
	return (data()["rivers"]["maps"].get(map_id, []) as Array).map(func(i): return int(i))


## The Mill fields' state this moon ("mud" .. "frozen") and its entry.
static func field_state(run, m := 0) -> String:
	return _by_moon(data()["fields"]["by_moon"], m if m > 0 else run.moon(), "")


static func field(run) -> Dictionary:
	return data()["fields"]["states"].get(field_state(run), {})


static func field_rects(map_id: String) -> Array:
	return (data()["fields"]["maps"].get(map_id, []) as Array).map(func(r): return Rect2(r[0], r[1], r[2], r[3]))


## Days nature takes to mend `base` days' worth this season (-1: not this season).
static func regrow_days(run, base: int) -> int:
	var k := float(rules(run)["regrow"])
	return -1 if k <= 0.0 else int(ceil(base / k))


static func regrows_on(map_id: String) -> bool:
	return map_id in data()["regrow"]["maps"]


## Days the season adds to road [a, b] (winter on every road, high water at a ford).
static func road_extra(run, a: String, b: String) -> int:
	var n := int(rules(run)["travel"])
	if river(run) == "high":
		for f in data()["rivers"]["fords"]:
			if (f[0] == a and f[1] == b) or (f[0] == b and f[1] == a):
				n += int(data()["rivers"]["ford_days"])
	return n
