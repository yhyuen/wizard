extends RefCounted
## Commissions (people spec §6; build item N-7.6.3): small paid jobs posted on a board, each a few
## steps at places in Ring 1, most of them a fight. Texture, never story. What it keeps is the
## life's (Run.life "commissions" {id: {step, lost, clean, slow}}, "crowns"), and the soul's
## (Run.soul "commissions" {id: life done}: a later life knows the way). Data in
## data/world/commissions.json; the scenes are the stories' (the board's in commissions.story).

const PATH := "res://data/world/commissions.json"
const DONE := 99

var run
var calamity  # scripts/game/calamity.gd: nothing is posted in the week before a calamity
var d: Dictionary


func _init(run_node, calamity_rules) -> void:
	run = run_node
	calamity = calamity_rules
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func ids() -> Array:
	return d["commissions"].keys()


func rec(id: String) -> Dictionary:
	return d["commissions"].get(id, {})


func _state(id: String) -> Dictionary:
	return run.life.get("commissions", {}).get(id, {})


## The step you're on: -1 not taken, then 0.., DONE once paid.
func step(id: String) -> int:
	var s := _state(id)
	return int(s["step"]) if s.has("step") else -1


func done(id: String) -> bool:
	return step(id) == DONE


## Done in an earlier life: the answer shows and its steps take no time (spec §6.1 rule 5).
func known(id: String) -> bool:
	var got: Dictionary = run.soul.get("commissions", {})
	return got.has(id) and int(got[id]) < run.loop()


## A calamity comes within the week: nobody posts (spec §6.1 rule 6).
func calamity_week() -> bool:
	for c in calamity.ids():
		var to: int = calamity.days_to(c)
		if to >= 0 and to < int(d["calamity_week"]):
			return true
	return false


## On the board now: in its window, not taken this life, and no calamity this week.
func posted(id: String) -> bool:
	var r := rec(id)
	return not r.is_empty() and step(id) < 0 and run.day() >= int(r["from"]) and run.day() <= int(r["to"]) and not calamity_week()


func posted_at(board: String) -> Array:
	return ids().filter(func(id): return posted(id) and str(rec(id)["board"]) == board)


func take(id: String) -> bool:
	if not posted(id):
		return false
	if not run.life.has("commissions"):
		run.life["commissions"] = {}
	run.life["commissions"][id] = {"step": 0, "lost": false, "clean": false, "slow": false}
	return true


## The step is done: on to the next. `spared` is whether the matter hook's `spare` held, from the
## world (slice.gd checks the props); it counts only on the step done at the hook's place.
func next(id: String, spared := false) -> void:
	var s := _state(id)
	if s.is_empty() or int(s["step"]) == DONE:
		return
	var st: Dictionary = rec(id)["steps"][int(s["step"])]
	var sp: Dictionary = rec(id).get("hook", {}).get("spare", {})
	if not sp.is_empty() and str(sp["place"]) == str(st["place"]):
		s["clean"] = spared
	s["step"] = mini(int(s["step"]) + 1, rec(id)["steps"].size() - 1)
	s["lost"] = false


## A hook without `spare`: the scene says the job was done cleanly.
func clean(id: String) -> void:
	var s := _state(id)
	if not s.is_empty():
		s["clean"] = true


## A fight lost: the step stays open, and the slow peaceful way opens (spec §6.1 rule 3).
func lose(id: String) -> void:
	var s := _state(id)
	if not s.is_empty():
		s["lost"] = true


func is_clean(id: String) -> bool:
	return bool(_state(id).get("clean", false))


func lost(id: String) -> bool:
	return bool(_state(id).get("lost", false))


## Took the slow way: the job pays less.
func slow(id: String) -> void:
	var s := _state(id)
	if not s.is_empty():
		s["slow"] = true
		s["lost"] = false


## What it pays now: the pay, +the hook's bonus if clean, x slow_pay if it went the slow way.
func pay_of(id: String) -> int:
	var r := rec(id)
	var s := _state(id)
	var k := 1.0
	if bool(s.get("clean", false)) and not r.get("hook", {}).is_empty():
		k += float(r["hook"]["bonus"])
	if bool(s.get("slow", false)):
		k *= float(d["slow_pay"])
	return int(round(float(r["pay"]) * k))


## Paid at the last step: crowns for the life, and the soul remembers the way.
func finish(id: String) -> int:
	var s := _state(id)
	if s.is_empty() or int(s["step"]) == DONE:
		return 0
	var got := pay_of(id)
	run.life["crowns"] = int(run.life.get("crowns", 0)) + got
	s["paid"] = got
	s["step"] = DONE
	if not run.soul.has("commissions"):
		run.soul["commissions"] = {}
	if not run.soul["commissions"].has(id):
		run.soul["commissions"][id] = run.loop()
	return got


## The jobs line on the HUD (UI spec §3.4): the step of the job taken most recently.
func job_line() -> String:
	var all: Dictionary = run.life.get("commissions", {})
	var ids_: Array = all.keys()
	ids_.reverse()
	for id in ids_:
		if int(all[id]["step"]) != DONE:
			return "%s: %s" % [rec(id)["title"], rec(id)["steps"][int(all[id]["step"])]["text"]]
	return ""


## The Ledger's Commissions tab: [{id, title, giver, line, state}] with state doing, posted or done.
func ledger() -> Array:
	var out: Array = []
	for id in ids():
		var r := rec(id)
		var n := step(id)
		if n == DONE:
			out.append({"id": id, "title": r["title"], "giver": r["giver"], "state": "done", "line": "Paid %d crowns." % int(_state(id).get("paid", 0))})
		elif n >= 0:
			out.append({"id": id, "title": r["title"], "giver": r["giver"], "state": "doing", "line": str(r["steps"][n]["text"]) + ("  ·  " + str(r["hook"]["text"]) if not r.get("hook", {}).is_empty() else "")})
		elif posted(id):
			out.append({"id": id, "title": r["title"], "giver": r["giver"], "state": "posted", "line": "%d crowns. Posted until %s." % [int(r["pay"]), run.date_name(int(r["to"]))]})
	return out
