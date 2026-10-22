extends RefCounted
## The weather (design/seasons/seasons-and-calamities-spec.md §3, data/world/weather.json). Each
## region has a kind of weather each day, drawn from its climate's weights for the season with a
## hash of the soul's seed, the region and the day, so the year's weather is the same every life.
## Calamity days are pinned. The Almanac (soul.almanac) remembers every day you lived in a region;
## Aldous tells you tomorrow's. The world doesn't read it yet (N-4.5.2: wet, wind, frost...).

const DATA := "res://data/world/weather.json"

var run  # the Run autoload
var d: Dictionary
var _years := {}  # "seed/region" -> [{kind, wind, dir}] for days 1..LAST_DAY


func _init(run_node) -> void:
	run = run_node
	d = JSON.parse_string(FileAccess.get_file_as_string(DATA))


## The save slot's weather seed: a soul keeps it across lives (an older save gets one now).
func seed_of() -> int:
	if not run.soul.has("seed"):
		run.soul["seed"] = randi() % 1000000 + 1
	return int(run.soul["seed"])


func climate(region: String) -> String:
	return str(d["regions"].get(region, d["regions"]["default"]))


## {kind, wind, dir} for a region on a day (default: here and today). A day changed by a spell
## (set_today) wins for that day only.
func on(region: String, day := 0) -> Dictionary:
	day = day if day > 0 else run.day()
	var changed: Dictionary = run.life.get("weather_set", {})
	var key := "%s:%d" % [region, day]
	if changed.has(key):
		return changed[key]
	return _year(region)[clampi(day, 1, run.LAST_DAY) - 1]


func kind(region: String, day := 0) -> String:
	return str(on(region, day)["kind"])


func kind_name(k: String) -> String:
	return str(d["kinds"][k]["name"])


func color(k: String) -> Color:
	return Color(str(d["kinds"][k]["color"]))


## "Rain, wind 1 from the SW"
func describe(region: String, day := 0) -> String:
	var w: Dictionary = on(region, day)
	if int(w["wind"]) == 0:
		return "%s, still air" % kind_name(w["kind"])
	return "%s, wind %d from the %s" % [kind_name(w["kind"]), int(w["wind"]), w["dir"]]


## A weather spell sets a region's weather for the rest of today (spec §3.2); the roll for later
## days is untouched, and a pinned day can't be changed.
func set_today(region: String, k: String, wind := -1) -> bool:
	if _pin(region, run.day()) != {} or not d["kinds"].has(k):
		return false
	if not run.life.has("weather_set"):
		run.life["weather_set"] = {}
	var w: Dictionary = on(region).duplicate()
	w["kind"] = k
	if wind >= 0:
		w["wind"] = wind
	run.life["weather_set"]["%s:%d" % [region, run.day()]] = w
	return true


# --- the Almanac and the forecast -------------------------------------------------------

## Writes today's weather in a region into the Almanac (it carries across lives).
func note(region: String, day := 0) -> void:
	day = day if day > 0 else run.day()
	if not run.soul.has("almanac"):
		run.soul["almanac"] = {}
	if not run.soul["almanac"].has(region):
		run.soul["almanac"][region] = {}
	run.soul["almanac"][region][str(day)] = _year(region)[day - 1]["kind"]


## The kind you know for a region's day, or "" (the Almanac, today, or a forecast for tomorrow).
func known(region: String, day: int) -> String:
	if day == run.day():
		return kind(region, day)
	if day == run.day() + 1 and int(run.life.get("forecast", 0)) == day:
		return kind(region, day)
	return str(run.soul.get("almanac", {}).get(region, {}).get(str(day), ""))


## Aldous's line about tomorrow, and you know tomorrow now.
func forecast(region: String) -> String:
	var t: int = mini(run.day() + 1, run.LAST_DAY)
	run.life["forecast"] = t
	return str(d["kinds"][kind(region, t)]["say"])


# --- the roll -------------------------------------------------------------------------

func _pin(region: String, day: int) -> Dictionary:
	for p in d["pinned"]:
		if not (region in p["regions"] or "*" in p["regions"]):
			continue
		for e in run.cal["events"]:
			if e["id"] == p["event"] and run.day_of(int(e["moon"]), int(e["day"])) == day:
				return p
	return {}


## The whole year for a region, drawn once per seed (days depend on the days before them only
## through max_run).
func _year(region: String) -> Array:
	var key := "%d/%s" % [seed_of(), region]
	if _years.has(key):
		return _years[key]
	var out: Array = []
	var table: Dictionary = d["climates"][climate(region)]
	var dirs: Array = d["dirs"]
	for day in range(1, run.LAST_DAY + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d:%s:%d" % [seed_of(), region, day]).hash()
		var m: int = (day - 1) / run.MOON_DAYS + 1
		var weights: Dictionary = (table[run.cal["moons"][m - 1]["season"]] as Dictionary).duplicate()
		for dbl in d["double"]:
			if int(dbl["moon"]) == m and weights.has(dbl["kind"]):
				weights[dbl["kind"]] = float(weights[dbl["kind"]]) * 2.0
		for k in d["max_run"]:
			var n := 0
			while n < out.size() and out[out.size() - 1 - n]["kind"] == k:
				n += 1
			if n >= int(d["max_run"][k]):
				weights.erase(k)
		var kd := _draw(weights, rng.randf())
		var wr: Array = d["kinds"][kd]["wind"]
		var w := {"kind": kd, "wind": rng.randi_range(int(wr[0]), int(wr[1])), "dir": dirs[rng.randi() % dirs.size()]}
		var pin := _pin(region, day)
		if not pin.is_empty():
			w["kind"] = pin["kind"]
			w["wind"] = int(pin.get("wind", w["wind"]))
			w["dir"] = str(pin.get("dir", w["dir"]))
			w["pinned"] = true
		out.append(w)
	_years[key] = out
	return out


static func _draw(weights: Dictionary, r: float) -> String:
	var total := 0.0
	for k in weights:
		if not str(k).begins_with("_"):
			total += float(weights[k])
	var acc := 0.0
	var last := ""
	for k in weights:
		if str(k).begins_with("_"):
			continue
		acc += float(weights[k]) / total
		last = k
		if r < acc:
			return k
	return last


# --- the glyph -------------------------------------------------------------------------

## Draws a kind's glyph centred on `c`, about `r` across the middle, with a Tris (scripts/ui/tris.gd).
static func glyph(g, k: String, c: Vector2, r: float, col: Color) -> void:
	match k:
		"clear", "heat":
			g.circle(c, r * 0.45, col)
			if k == "heat":
				g.arc(c, r * 0.8, 0, TAU, 16, col, 1.0)
			else:
				for i in 8:
					var a := TAU * i / 8.0
					g.line(c + Vector2.from_angle(a) * r * 0.65, c + Vector2.from_angle(a) * r, col, 1.0)
		"overcast", "rain", "storm", "snow":
			var cc := c + (Vector2(0, -r * 0.25) if k != "overcast" else Vector2.ZERO)
			g.circle(cc + Vector2(-r * 0.4, r * 0.1), r * 0.38, col)
			g.circle(cc + Vector2(r * 0.05, -r * 0.15), r * 0.48, col)
			g.circle(cc + Vector2(r * 0.5, r * 0.12), r * 0.34, col)
			g.rect(Rect2(cc + Vector2(-r * 0.75, r * 0.1), Vector2(r * 1.5, r * 0.36)), col)
			if k == "rain":
				for i in 3:
					var x := (i - 1) * r * 0.5
					g.line(c + Vector2(x, r * 0.45), c + Vector2(x - r * 0.2, r * 0.95), col, 1.0)
			elif k == "storm":
				g.polyline(PackedVector2Array([c + Vector2(r * 0.1, r * 0.3), c + Vector2(-r * 0.2, r * 0.7),
					c + Vector2(r * 0.15, r * 0.7), c + Vector2(-r * 0.1, r * 1.1)]), col, 1.2)
			elif k == "snow":
				for i in 3:
					g.circle(c + Vector2((i - 1) * r * 0.5, r * 0.75 + (i % 2) * r * 0.2), r * 0.12, col)
		"mist":
			for i in 3:
				var y := (i - 1) * r * 0.5
				var off := r * 0.2 * (i % 2)
				g.line(c + Vector2(-r + off, y), c + Vector2(r - r * 0.2 + off, y), col, 1.2)
		"wind":
			g.line(c + Vector2(-r, -r * 0.3), c + Vector2(r * 0.4, -r * 0.3), col, 1.2)
			g.arc(c + Vector2(r * 0.4, -r * 0.6), r * 0.3, PI / 2.0, PI / 2.0 - PI * 1.4, 8, col, 1.2)
			g.line(c + Vector2(-r * 0.8, r * 0.25), c + Vector2(r * 0.6, r * 0.25), col, 1.2)
			g.arc(c + Vector2(r * 0.6, r * 0.55), r * 0.3, -PI / 2.0, -PI / 2.0 + PI * 1.4, 8, col, 1.2)
		"frost":
			for i in 3:
				var a := PI * i / 3.0 + PI / 2.0
				g.line(c - Vector2.from_angle(a) * r, c + Vector2.from_angle(a) * r, col, 1.2)
