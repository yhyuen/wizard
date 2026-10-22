extends RefCounted
## Confrontations (people spec §11; build item N-7.6.7): a scene with statements. Press one (they
## say more, and may let slip one that was hidden) or present evidence at one: the right evidence
## at the right statement breaks it; right but at the wrong one is near (free); anything else is a
## miss and costs one of three lamps. Break `need` statements and choose how it closes; lamps out
## and it's over for this life. A soft talk has no lamps and never fails; a believer forgives one
## miss once you're Close; your very first confrontation never loses a lamp. Pure and testable.
## The scenes are data/world/confront/*.json (SPOILER: their text is sealed story).

const DIR := "res://data/world/confront/"
const LAMPS := 3

var d: Dictionary
var have: Array = []  # evidence ids you hold now
var lamps := LAMPS
var shown := {}  # statement id -> true once it can be seen
var broken := {}  # statement id -> the evidence that broke it
var said := ""  # what just happened, for the panel
var free_misses := 0  # misses that cost nothing (the first confrontation; a believer at Close)
var hints := {}  # statement id -> evidence that broke it in an earlier life
var result := ""  # "", "won" or "lost"


static func load_scene(id: String) -> Dictionary:
	var f := DIR + id + ".json"
	return JSON.parse_string(FileAccess.get_file_as_string(f)) if FileAccess.file_exists(f) else {}


func _init(rec: Dictionary, have_: Array, free_ := 0, hints_ := {}) -> void:
	d = rec
	have = have_
	free_misses = free_
	hints = hints_
	for s in d["statements"]:
		if not s.get("hidden", false):
			shown[s["id"]] = true


func soft() -> bool:
	return str(d["kind"]) == "soft"


func statements() -> Array:
	return d["statements"].filter(func(s): return shown.has(s["id"]))


func evidence() -> Array:
	return d["evidence"].filter(func(e): return e["id"] in have)


func _stmt(sid: String) -> Dictionary:
	for s in d["statements"]:
		if s["id"] == sid:
			return s
	return {}


func press(sid: String) -> void:
	var s := _stmt(sid)
	if s.is_empty() or not shown.has(sid) or result != "":
		return
	said = str(s.get("press", "..."))
	for r in s.get("reveals", []):
		shown[r] = true


## Presents evidence `eid` at statement `sid`: "break", "near", "miss" (or "" if it can't).
func present(eid: String, sid: String) -> String:
	if result != "" or not shown.has(sid) or broken.has(sid) or not eid in have:
		return ""
	for b in d["breaks"]:
		if b["statement"] == sid and b["evidence"] == eid:
			broken[sid] = eid
			said = str(b["text"])
			if broken.size() >= int(d["need"]):
				result = "won"
			return "break"
	if d["breaks"].any(func(b): return b["evidence"] == eid and not broken.has(b["statement"])):
		said = "That's true. It just isn't the answer to this."
		return "near"
	if soft():
		said = "They don't follow. It doesn't matter."
		return "miss"
	if free_misses > 0:
		free_misses -= 1
		said = "It doesn't land. You get another try."
		return "miss"
	lamps -= 1
	said = "It doesn't land. A lamp goes out."
	if lamps <= 0:
		result = "lost"
	return "miss"


## A data check: every break is reachable (its statement shown, or revealed by pressing one that
## is), names real evidence, and enough breaks exist for `need`; there's a close. [] when sound.
static func check(rec: Dictionary) -> Array:
	var out: Array = []
	var ids := {}
	var reach := {}
	for s in rec["statements"]:
		ids[s["id"]] = s
		if not s.get("hidden", false):
			reach[s["id"]] = true
	var grew := true
	while grew:
		grew = false
		for sid in reach.keys():
			for r in ids[sid].get("reveals", []):
				if not reach.has(r):
					reach[r] = true
					grew = true
	var ev: Array = rec["evidence"].map(func(e): return e["id"])
	for b in rec["breaks"]:
		if not reach.has(b["statement"]):
			out.append("break at %s can't be reached" % b["statement"])
		if not b["evidence"] in ev:
			out.append("break at %s names no evidence %s" % [b["statement"], b["evidence"]])
	if rec["breaks"].size() < int(rec["need"]):
		out.append("needs %d breaks but has %d" % [int(rec["need"]), rec["breaks"].size()])
	if rec["closes"].is_empty():
		out.append("no close")
	if not str(rec["kind"]) in ["liar", "believer", "soft"]:
		out.append("no kind %s" % rec["kind"])
	return out


## A bot for tests: presses everything, then tries each piece of evidence at each statement.
func bot() -> String:
	for n in 3:
		for s in statements():
			press(s["id"])
	for s in statements():
		for e in have:
			if result == "" and not broken.has(s["id"]) and _breaks(s["id"], e):
				present(e, s["id"])
	return result


func _breaks(sid: String, eid: String) -> bool:
	return d["breaks"].any(func(b): return b["statement"] == sid and b["evidence"] == eid)
