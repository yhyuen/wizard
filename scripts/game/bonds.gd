extends RefCounted
## Bonds (people spec §4-5; build item N-7.6.1): each person's lamp and tier this life, gains with
## their caps, crossing scenes, gifts and tastes, and the floors the next life starts from. Data in
## data/world/bonds.json; who has a track (and how far) is people.json `kind`. Everything here is
## the life's (Run.life "bonds" {who: {lamp, tier, keys, weeks}}) except what the soul keeps: the
## best tier reached (Run.soul "bond_best", kept as it rises; the next life's floors) and tastes learned
## (Run.soul "tastes" {who: {item: reaction}}).

const PATH := "res://data/world/bonds.json"
const PEOPLE := "res://data/world/people.json"

var run
var d: Dictionary
var people: Dictionary


func _init(run_node) -> void:
	run = run_node
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	people = JSON.parse_string(FileAccess.get_file_as_string(PEOPLE))["people"]


## The highest tier `who` can reach (-1: no track).
func cap(who: String) -> int:
	if not people.has(who):
		return -1
	return int(d["caps"].get(str(people[who].get("kind", "full")), -1))


## Their bond this life, started from the soul's floor the first time it's asked.
func state(who: String) -> Dictionary:
	if not run.life.has("bonds"):
		run.life["bonds"] = {}
	if not run.life["bonds"].has(who):
		var t: int = mini(floor_tier(who), maxi(cap(who), 0))
		run.life["bonds"][who] = {"lamp": float(d["tiers"][t]["from"]), "tier": t, "keys": {}, "weeks": {}}
	return run.life["bonds"][who]


## The tier the next life starts `who` at (bonds.json floors over the best tier ever reached).
func floor_tier(who: String) -> int:
	var best: int = int(run.soul.get("bond_best", {}).get(who, 0))
	var f := 0
	for k in d["floors"]:
		if best >= int(k):
			f = maxi(f, int(d["floors"][k]))
	return f


func tier(who: String) -> int:
	return int(state(who)["tier"]) if cap(who) >= 0 else 0


func tier_name(t: int) -> String:
	return str(d["tiers"][clampi(t, 0, d["tiers"].size() - 1)]["name"])


## The lamp's ceiling at tier `t`: the next tier's start, or full.
func _top(t: int) -> float:
	return float(d["tiers"][t + 1]["from"]) if t + 1 < d["tiers"].size() else float(d["full"])


## Gains bond with `who` from `source` (bonds.json sources; `key` for once-per-key sources,
## `amount` for story gains). Returns the lamp points actually gained (0 if capped or no track).
func gain(who: String, source: String, key := "", amount := 0) -> float:
	if cap(who) < 0 or not d["sources"].has(source):
		return 0.0
	var src: Dictionary = d["sources"][source]
	var st := state(who)
	match str(src.get("per", "key")):
		"key":
			var kk := source + ":" + key
			if st["keys"].has(kk):
				return 0.0
			st["keys"][kk] = true
		"life":
			if st["keys"].has(source):
				return 0.0
			st["keys"][source] = true
		"week":
			var wk: int = (run.day() - 1) / 7
			if int(st["weeks"].get(source, -1)) == wk:
				return 0.0
			st["weeks"][source] = wk
		"day":
			if int(st["weeks"].get(source + ":day", -1)) == run.day():
				return 0.0
			st["weeks"][source + ":day"] = run.day()
	var t := int(st["tier"])
	var before := float(st["lamp"])
	if src.get("fill", false):
		st["lamp"] = maxf(before, _top(t))
	else:
		var g: float = float(amount) if amount != 0 else float(src.get("gain", 0))
		st["lamp"] = before + g
	_settle(who)
	return float(st["lamp"]) - before


## Holds the lamp inside the tier (the top waits for a crossing scene; a loss stops at the
## bottom) and climbs the tiers that need no scene.
func _settle(who: String) -> void:
	var st := state(who)
	var tiers: Array = d["tiers"]
	while int(st["tier"]) + 1 <= cap(who) and int(st["tier"]) + 1 < tiers.size() \
			and not tiers[int(st["tier"]) + 1].get("scene", false) and float(st["lamp"]) >= float(tiers[int(st["tier"]) + 1]["from"]):
		st["tier"] = int(st["tier"]) + 1
	var t := int(st["tier"])
	st["lamp"] = clampf(float(st["lamp"]), float(tiers[t]["from"]), _top(t))
	_best(who, t)


func _best(who: String, t: int) -> void:
	if not run.soul.has("bond_best"):
		run.soul["bond_best"] = {}
	run.soul["bond_best"][who] = maxi(int(run.soul["bond_best"].get(who, 0)), t)


## The lamp is full for this tier, and the next is a scene's to open.
func ready_to_cross(who: String) -> bool:
	var st := state(who)
	var t := int(st["tier"])
	return t + 1 <= cap(who) and t + 1 < d["tiers"].size() and float(st["lamp"]) >= _top(t)


## A crossing scene played (the story's `bond_cross <who>`): the next tier, if the lamp was full.
func cross(who: String) -> bool:
	if not ready_to_cross(who):
		return false
	var st := state(who)
	if int(st["tier"]) + 1 == d["tiers"].size() - 1 and sworn() >= int(d.get("sworn_max", 3)):
		return false  # Sworn: at most three a life (people spec §4.5)
	st["tier"] = int(st["tier"]) + 1
	_best(who, int(st["tier"]))
	return true


## How many are Sworn to you this life.
func sworn() -> int:
	var top: int = d["tiers"].size() - 1
	return run.life.get("bonds", {}).values().filter(func(b): return int(b["tier"]) >= top).size()


## Betrayal (a broken promise, an attack, a sell-out): one tier down, the lamp at its bottom.
func betray(who: String) -> void:
	if cap(who) < 0:
		return
	var st := state(who)
	st["tier"] = maxi(0, int(st["tier"]) - 1)
	st["lamp"] = float(d["tiers"][int(st["tier"])]["from"])


## How `who` takes `item` (love, like, plain, dislike, cant_bear): matched in that order of
## love, cant_bear, dislike, like, by the item id or its gift kind.
func taste(who: String, item: String) -> String:
	var t: Dictionary = people.get(who, {}).get("tastes", {})
	var kind := str(d["gift_kinds"].get(item, ""))
	for r in ["love", "cant_bear", "dislike", "like"]:
		var l: Array = t.get(r, [])
		if item in l or (kind != "" and kind in l):
			return r
	return "plain"


## A gift (the story's `gift <who> <item>`): the gain by taste, once a week per person; the
## reaction is learned for every life. Returns the reaction, or "" if it's too soon.
func gift(who: String, item: String) -> String:
	if cap(who) < 0:
		return ""
	var st := state(who)
	var wk: int = (run.day() - 1) / 7
	if int(st["weeks"].get("gift", -1)) == wk:
		return ""
	st["weeks"]["gift"] = wk
	var r := taste(who, item)
	st["lamp"] = float(st["lamp"]) + float(d["gifts"][r])
	_settle(who)
	if not run.soul.has("tastes"):
		run.soul["tastes"] = {}
	if not run.soul["tastes"].has(who):
		run.soul["tastes"][who] = {}
	run.soul["tastes"][who][item] = r
	return r


## Tastes learned for `who` in any life: {item: reaction}.
func tastes_known(who: String) -> Dictionary:
	return run.soul.get("tastes", {}).get(who, {})
