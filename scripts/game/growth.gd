extends RefCounted
## The slice's growth (design/slice/systems.md §2), on top of the Run autoload's two layers.
## This loop (reset on waking): wells, the Ring, each Model's Practice, the spellbook. Kept across
## loops: the Models you know, the best Practice each reached and the most wells you held (the
## Echo), revision choices and Fluency. Numbers are in data/slice/progression.json.
##
## Fights still run on the Progression autoload. begin_fight() lends it this loop's Practice and
## spellbook plus the slice rules (Ring-gated slots, HP and Aether from wells, Echo and Fluency
## on XP, no Magicks); end_fight() takes the Practice back and puts the old progress where it was.

var run  # the Run autoload
var prog  # the Progression autoload
var d: Dictionary  # data/slice/progression.json
var _stash := {}
var _stash_save := true
var lent := false


func _init(run_node, prog_node) -> void:
	run = run_node
	prog = prog_node
	d = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/progression.json"))


# --- wells and Rings ---------------------------------------------------------------

func wells() -> int:
	return int(run.life.get("wells", 0))


func best_wells() -> int:
	return int(run.soul.get("best_wells", 0))


## Adds wells, `echo_mult` times faster below the most you held in an earlier loop, up to
## `well_cap`. Returns the gain.
func add_wells(n: int) -> int:
	var w := wells()
	var gain := 0
	for i in n:
		gain += int(d["echo_mult"]) if w + gain < best_wells() else 1
	gain = mini(gain, maxi(0, int(d["well_cap"]) - w))
	run.life["wells"] = w + gain
	run.life["best_wells_loop"] = maxi(int(run.life.get("best_wells_loop", 0)), w + gain)
	return gain


## 0 = Apprentice … 4 = the 4th Ring.
func ring() -> int:
	if not run.flag("ring1"):
		return 0
	var r := 1
	var need: Array = d["ring_wells"]
	for i in range(2, need.size()):
		if wells() >= int(need[i]):
			r = i
	return r


func ring_name(r := -1) -> String:
	return d["rings"][ring() if r < 0 else r]


## Wells still needed for the next Ring, or -1 if the next Ring is the yard trial or there is none.
func wells_to_next() -> int:
	var r := ring()
	var need: Array = d["ring_wells"]
	if r == 0 or r + 1 >= need.size():
		return -1
	return int(need[r + 1]) - wells()


func slots() -> int:
	return int(d["slots"][ring()])


func max_hp() -> float:
	return float(d["hp_base"]) + float(d["hp_per_well"]) * wells()


func max_aether() -> float:
	return float(d["aether_base"]) + float(d["aether_per_well"]) * wells()


func blinks() -> int:
	var n := 1
	for r in d["blink_ring"]:
		if ring() >= int(r):
			n += 1
	return n


## The Ring a spell's tier needs (bolts: Apprentice, controls: 1st, signatures: 4th).
func tier_ring(id: String) -> int:
	# A spell can name its own Ring (Rewind: the Hours came back with you, so an Apprentice casts it).
	return int(prog.spell(id).get("ring", d["tier_ring"].get(prog.spell(id)["slot"], 0)))


func can_cast(id: String) -> bool:
	return ring() >= tier_ring(id)


## Once-a-day actions (meditating, training): true if `op` can still be done today, and marks it.
func use_today(op: String) -> bool:
	if not op in d["once_a_day"]:
		return true
	var key := "done_" + op
	if int(run.life.get(key, 0)) == run.day():
		return false
	run.life[key] = run.day()
	return true


# --- Models and the spellbook ---------------------------------------------------------

func knows_model(id: String) -> bool:
	return id in d["start_models"] or run.knows("model_" + id)


## Every spell you can put in the book, in the data's order.
func known_models() -> Array:
	return prog.data["spells"].keys().filter(func(id): return knows_model(id))


## Four spell ids. Only the first slots() of them are open; the rest wait for a higher Ring.
func book() -> Array:
	if not run.life.has("book"):
		run.life["book"] = _default_book()
	elif (run.life["book"] as Array).size() != prog.BOOK_SIZE:
		run.life["book"] = (run.life["book"] as Array).slice(0, prog.BOOK_SIZE)  # a save from the six-slot book
	return run.life["book"]


func _default_book() -> Array:
	var b: Array = (d["start_models"] as Array).duplicate()
	for id in prog.data["spells"]:
		if b.size() >= prog.BOOK_SIZE:
			break
		if not b.has(id):
			b.append(id)
	return b


## Puts Model `id` in slot `i`; if it is already in another slot, the two swap.
func set_slot(i: int, id: String) -> bool:
	if i < 0 or i >= slots() or not knows_model(id) or not can_cast(id):
		return false
	var b: Array = book().duplicate()
	var at := b.find(id)
	if at >= 0:
		b[at] = b[i]
	b[i] = id
	run.life["book"] = b
	return true


## The spell in open slot `i`, or "" when the slot is locked or its spell's tier is too high.
func slot_spell(i: int) -> String:
	if i >= slots():
		return ""
	var id: String = book()[i]
	return id if knows_model(id) and can_cast(id) else ""


# --- Practice, Echo and Fluency ---------------------------------------------------------

func practice() -> Dictionary:
	if lent:
		return prog.p["spells"]  # lent out for the day: Progression has the live levels
	if not run.life.has("practice"):
		var p := {}
		for id in prog.data["spells"]:
			p[id] = {"level": 1, "xp": 0.0, "muts": {}}
		run.life["practice"] = p
	return run.life["practice"]


func level(id: String) -> int:
	return int(practice()[id]["level"])


## The best Practice each Model reached in an earlier loop.
func echo() -> Dictionary:
	if not run.soul.has("echo"):
		run.soul["echo"] = {}
	return run.soul["echo"]


## Insight (lives spec §4.3): each point, +1 a life up to the cap, adds to all Practice gained.
func fluency() -> float:
	var base: float = float(run.lives["insight"]["per"]) * mini(run.insight(), int(run.lives["insight"]["cap"]))
	return base * (1.0 + float(run.lives.get("omen_insight", 0.0)) * run.omens().size())  # each Omen adds to insight's effect


## What Progression needs to play by the slice's rules.
func rules() -> Dictionary:
	var open: Array = []
	for i in prog.BOOK_SIZE:
		open.append(slot_spell(i) != "")
	return {"hp": max_hp(), "aether": max_aether(), "blinks": blinks(), "open": open,
		"echo": echo().duplicate(), "echo_mult": float(d["echo_mult"]), "fluency": fluency(),
		"revisions": run.soul.get("revisions", {}).duplicate(true)}


## Lends Progression this loop's Practice, spellbook and rules (for a fight, training, or in
## the open world the whole day, since you can cast anywhere).
func begin_fight() -> void:
	if lent:
		return
	var spells: Dictionary = practice().duplicate(true)  # before lending: practice() reads the lent copy once lent
	lent = true
	_stash = prog.p
	_stash_save = prog.save_enabled
	prog.save_enabled = false
	var p: Dictionary = prog.fresh()
	p["spells"] = spells
	for id in prog.data["spells"]:
		if not p["spells"].has(id):
			p["spells"][id] = {"level": 1, "xp": 0.0, "muts": {}}
	p["spellbook"] = book().duplicate()
	p["loop"] = run.loop()
	prog.p = p
	prog.pending.clear()
	prog.rules = rules()


## While lent (the open world lends it for the whole day): the spellbook and the rules again,
## after a slot, a Ring or the wells change.
func refresh() -> void:
	if lent:
		prog.p["spellbook"] = book().duplicate()
		prog.rules = rules()


## Takes the Practice back; the Echo and the revision choices remember it.
func end_fight() -> void:
	if not lent:
		return
	lent = false
	# A milestone still waiting for a pick takes the option offered first.
	while not prog.pending.is_empty():
		prog.pick(0)
	run.life["practice"] = prog.p["spells"].duplicate(true)
	prog.p = _stash
	prog.rules = {}
	prog.save_enabled = _stash_save
	_remember_practice()


func _remember_practice() -> void:
	var e := echo()
	if not run.soul.has("revisions"):
		run.soul["revisions"] = {}
	for id in practice():
		var s: Dictionary = practice()[id]
		e[id] = maxi(int(e.get(id, 1)), int(s["level"]))
		if not s["muts"].is_empty():
			var r: Dictionary = run.soul["revisions"].get(id, {})
			r.merge(s["muts"], true)
			run.soul["revisions"][id] = r


## Training in the yard: every spell in an open slot gains `train_share` of a level (with Echo
## and Fluency). Returns {id: levels gained}.
func train() -> Dictionary:
	var before := {}
	for i in prog.BOOK_SIZE:
		var id := slot_spell(i)
		if id != "":
			before[id] = level(id)
	var was_lent := lent
	begin_fight()
	for id in before:
		prog.add_xp(id, float(d["train_share"]) * prog.xp_needed(prog.level(id)))
	if not was_lent:
		end_fight()
	var out := {}
	for id in before:
		out[id] = level(id) - int(before[id])
	return out


## The life is over: Practice comes back from Progression so the Turning (Lives.carry) sees it.
func loop_over() -> void:
	end_fight()
