extends RefCounted
## Rumours (people spec §10; build item N-7.6.2): what you hear, kept for every life (Run.soul
## "rumours" {id: life heard}); a date rumour pins its event on the calendar (Run.soul "dates");
## pools for minigames and companions to draw from. Data in data/world/rumours.json.

const PATH := "res://data/world/rumours.json"
const BANDS := [[1, 3, "m1-3"], [4, 7, "m4-7"], [8, 10, "m8-10"], [11, 13, "m11-13"]]

var run
var d: Dictionary


func _init(run_node) -> void:
	run = run_node
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func rec(id: String) -> Dictionary:
	return d["rumours"].get(id, {})


func heard(id: String) -> bool:
	return run.soul.get("rumours", {}).has(id)


## Hears rumour `id` (the story's `rumour <id>`). Returns true the first time, in any life.
func hear(id: String) -> bool:
	if heard(id) or rec(id).is_empty():
		return false
	if not run.soul.has("rumours"):
		run.soul["rumours"] = {}
	run.soul["rumours"][id] = run.loop()
	var ev := str(rec(id).get("points_at", {}).get("event", ""))
	if ev != "":
		run.soul["dates"][ev] = true  # the calendar pins it, this life and every later one
	return true


## Heard rumours of `kind`, as [{id, text, earlier}] (earlier: heard in a past life).
func of_kind(kind: String) -> Array:
	var out: Array = []
	var got: Dictionary = run.soul.get("rumours", {})
	for id in d["rumours"]:
		if got.has(id) and str(d["rumours"][id]["kind"]) == kind:
			out.append({"id": id, "text": str(d["rumours"][id]["text"]), "earlier": int(got[id]) < run.loop()})
	return out


## This moon's pool for `region` ("camp:m1-3").
func pool_now(region: String) -> String:
	for b in BANDS:
		if run.moon() >= b[0] and run.moon() <= b[1]:
			return "%s:%s" % [region, b[2]]
	return region


## Draws from `pool`: the unheard rumour pointing at the soonest event still ahead, else any
## unheard one; "" when the pool is dry.
func draw(pool: String) -> String:
	var best := ""
	var best_day := 99999
	for id in d["rumours"]:
		var r: Dictionary = d["rumours"][id]
		if str(r.get("pool", "")) != pool or heard(id):
			continue
		var at := 99998
		var ev := str(r.get("points_at", {}).get("event", ""))
		if ev != "":
			for e in run.cal["events"]:
				if e["id"] == ev:
					at = run.event_day(e)
			if at < run.day():
				continue
		if at < best_day:
			best_day = at
			best = id
	return best
