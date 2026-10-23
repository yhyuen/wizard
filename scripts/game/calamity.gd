extends RefCounted
## The calamities (seasons spec §6, §8; build item N-7.5.1): signs that pin a date, the Eve that
## stops rests short, the Onset that starts the Peak where you stand (or lets it pass without you),
## the Dawn tally of stakes and tier, and the tier's aftermath; after a Held life, the next life's
## variant (N-7.5.3: soul "calamity_held"). Data in data/world/calamities.json;
## the dates are the calendar's. Everything here is the life's (Run.life "calamity" {id: state});
## the soul keeps the date once one has passed (Run.soul "dates").

const PATH := "res://data/world/calamities.json"

var run
var d: Dictionary


func _init(run_node) -> void:
	run = run_node
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func ids() -> Array:
	return d["calamities"].keys()


func rec(id: String) -> Dictionary:
	return d["calamities"][id]


## The calamity whose calendar event is `event_id`, or "".
func of_event(event_id: String) -> String:
	for id in d["calamities"]:
		if str(d["calamities"][id]["event"]) == event_id:
			return id
	return ""


## Its day of the year (the calendar's, Run.event_day: the Early Bell Omen moves it a moon sooner).
func day(id: String) -> int:
	for e in run.cal["events"]:
		if e["id"] == rec(id)["event"]:
			return run.event_day(e)
	return -1


## Days until it comes (0 on its day, negative after): what the story's `calamity_in` reads.
func days_to(id: String) -> int:
	return day(id) - run.day()


## Its later-lives variant (seasons spec §9, N-7.5.3): one more for each life it was Held, up to
## the record's `variants.max`; 0 before it has ever been Held.
func variant(id: String) -> int:
	var v: Dictionary = rec(id).get("variants", {})
	if v.is_empty():
		return 0
	return mini(int(run.soul.get("calamity_held", {}).get(id, 0)), int(v["max"]))


## This life's variant record ({} for none): an `onset` slot that replaces the calamity's, a
## life `flag` set at the Onset unless the life flag `unless` is set.
func variant_rec(id: String) -> Dictionary:
	var n := variant(id)
	return rec(id).get("variants", {}).get(str(n), {}) if n > 0 else {}


## Its Onset slot this life (a variant may move it).
func onset(id: String) -> String:
	return str(variant_rec(id).get("onset", rec(id)["onset"]))


func state(id: String) -> Dictionary:
	if not run.life.has("calamity"):
		run.life["calamity"] = {}
	if not run.life["calamity"].has(id):
		run.life["calamity"][id] = {"signs": [], "prep": [], "phase": ""}
	return run.life["calamity"][id]


# --- signs and preparations -------------------------------------------------------------------

## A sign seen (the story's `sign <id> <sign>`). Returns true when this one pins the date.
func see_sign(id: String, sign: String) -> bool:
	var st := state(id)
	if sign in st["signs"] or not rec(id)["signs"].has(sign):
		return false
	st["signs"].append(sign)
	return st["signs"].size() == int(rec(id)["signs_to_pin"])


## The date is on the calendar: two signs seen this life (an unnamed "?"), or it's known by name.
func pinned(id: String) -> bool:
	return state(id)["signs"].size() >= int(rec(id)["signs_to_pin"])


## A preparation done (the story's `prep <id> <prep>`), counted once.
func prep(id: String, what: String) -> void:
	var st := state(id)
	if what in rec(id)["prep"] and not what in st["prep"]:
		st["prep"].append(what)


func preps(id: String) -> int:
	return state(id)["prep"].size()


# --- the Eve and the Onset --------------------------------------------------------------------

## The first calamity not yet passed whose day lies after today and on or before `to`, among those
## whose date you know (pinned or named, `known` from the calendar): resting stops on its Eve.
func eve_before(to: int, known: Callable) -> String:
	for id in ids():
		var cd: int = day(id)
		if state(id)["phase"] == "" and cd > run.day() and cd <= to and known.call(id):
			return id
	return ""


## Calamities whose Onset has come (or gone while you rested or travelled), not yet begun or passed.
func due() -> Array:
	var out: Array = []
	for id in ids():
		var at: int = run.TIMES.find(onset(id))
		var cd: int = day(id)
		if state(id)["phase"] == "" and (cd < run.day() or (cd == run.day() and run.time() >= at)):
			out.append(id)
	return out


## Whether you stand in it now: its day and Onset slot, in one of its regions.
func here_now(id: String, region: String) -> bool:
	return day(id) == run.day() and run.time() == run.TIMES.find(onset(id)) and region in rec(id)["regions"]


# --- Dawn: stakes, tier, aftermath ------------------------------------------------------------

## The tier the stakes earn (rules checked in order, each with its sealed `flag` if it has one; the
## last tier if none holds).
func tier_for(id: String, lamps: int, lost: int) -> String:
	var tiers: Array = rec(id)["tiers"]
	for t in tiers:
		if not t.has("lamps_at_least") or (t.has("flag") and not run.flag(str(t["flag"]))):
			continue
		var a := lamps >= int(t["lamps_at_least"])
		var b := lost <= int(t["lost_at_most"])
		if (a or b) if t.get("any", false) else (a and b):
			return str(t["id"])
	return str(tiers[-1]["id"])


## Without you: the default tier, a tier better if enough was prepared.
func absent_tier(id: String) -> String:
	var tiers: Array = rec(id)["tiers"].map(func(t): return str(t["id"]))
	var i: int = tiers.find(str(rec(id)["default_absent"]))
	if preps(id) >= int(rec(id)["prep_for_raise"]):
		i = maxi(0, i - 1)
	return tiers[i]


func tier_name(id: String, t: String) -> String:
	for x in rec(id)["tiers"]:
		if x["id"] == t:
			return str(x["name"])
	return t


## The calamity passes with tier `t`: the aftermath's flags and deeds, its shut and shortage kept
## on the life for the economy, the Ledger entry, the date for every later life, and the Hours can
## be turned back from now. Returns the tally {id, tier, lamps, lost, absent, line}.
func settle(id: String, t: String, lamps: int, lost: int, absent: bool) -> Dictionary:
	var st := state(id)
	st["phase"] = "passed"
	var af: Dictionary = rec(id)["aftermath"].get(t, {})
	for f in af.get("flags", []):
		run.set_flag(str(f))
	for dd in af.get("deeds", []):
		run.deed(str(dd))
	for k in ["shut", "shortage", "abandons"]:
		if af.has(k):
			st[k] = af[k]
	run.learn(str(rec(id)["ledger"]))
	run.soul["dates"][str(rec(id)["event"])] = true
	run.pass_calamity(id)
	if t == "held" and not absent:
		if not run.soul.has("calamity_held"):
			run.soul["calamity_held"] = {}
		run.soul["calamity_held"][id] = int(run.soul["calamity_held"].get(id, 0)) + 1
	var tally := {"id": id, "tier": t, "lamps": lamps, "lost": lost, "absent": absent, "line": str(af.get("line", "")),
		"injured": run.injured()}
	st["tally"] = tally
	return tally
