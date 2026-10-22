extends Node
## Spell levels, milestone mutations, element mastery, wizard level, the spellbook, Magick hints
## and the Loop Ledger. Spell knowledge survives a loop; the wizard level drops to half (design doc §3).
## Every number lives in data/spells.json.

signal spell_leveled(id: String, old_level: int, new_level: int)
signal milestone_ready
signal mutation_picked(id: String, mut: Dictionary)
signal wizard_leveled(old_level: int, new_level: int)
signal magick_learned(id: String)
signal hint_learned(id: String)
signal loadout_changed
signal breakthrough(id: String, stage: int)

const SAVE_PATH := "user://progress.json"

var data: Dictionary = {}
var p: Dictionary = {}
var pending: Array = []  # milestones waiting for a pick: {"spell", "level"}
var save_enabled := true  # tests turn saving off
## While the kit casts or previews a spell, Cadence scales it: {"id", "damage", "size", "count"}.
## stat() applies it to that spell's current-level damage, size and count tracks.
var boost: Dictionary = {}
## The vertical slice's rules while it lends its Practice and spellbook for a fight
## (scripts/game/growth.gd): {"hp", "aether", "blinks", "open", "echo", "echo_mult", "fluency",
## "revisions", "ward"}. Empty outside the slice, where the old Mill fight's rules apply.
var rules: Dictionary = {}

const SIZE_KEYS := ["radius", "size", "cone", "width"]
const BOOK_SIZE := 4
const COUNT_KEYS := ["bounces", "strikes", "chains"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = load_data()
	p = fresh()
	if "--script" in OS.get_cmdline_args():
		save_enabled = false
	else:
		_load()


static func load_data() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/spells.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("data/spells.json could not be parsed")
		return {}
	return parsed


func fresh() -> Dictionary:
	if data.is_empty():
		data = load_data()
	var spells := {}
	for id in data.get("spells", {}):
		spells[id] = {"level": 1, "xp": 0.0, "muts": {}}
	return {
		"spells": spells,
		"wizard_level": 1,
		"wizard_xp": 0.0,
		"loop": 1,
		"magicks": [],
		"hints": [],
		"spellbook": (data["start_spellbook"] as Array).duplicate(),
		"ledger": [],
		"echo": {},  # your last fight, replayed backwards next loop: {"loop", "won", "track"}
	}


# --- spells ---------------------------------------------------------------

func spell(id: String) -> Dictionary:
	return data["spells"][id]


func level(id: String) -> int:
	return int(p["spells"][id]["level"])


func xp(id: String) -> float:
	return float(p["spells"][id]["xp"])


func xp_needed(lv: int) -> float:
	var pr: Dictionary = data["progression"]
	return float(pr["xp_base"]) + float(pr["xp_step"]) * (lv - 1)


func max_level() -> int:
	return int(data["progression"]["max_level"])


## A stat track at a given level: base + per × (level − 1), with floor/min/max from the data.
static func stat_value(def: Dictionary, lv: int) -> float:
	var v := float(def["base"]) + float(def.get("per", 0.0)) * (lv - 1)
	if def.has("min"):
		v = maxf(v, float(def["min"]))
	if def.has("max"):
		v = minf(v, float(def["max"]))
	if def.get("floor", false):
		v = floorf(v + 0.0001)
	return v


func stat(id: String, key: String, lv := -1) -> float:
	var current := lv < 0
	if current:
		lv = level(id)
	var v := stat_value(spell(id)["stats"][key], lv)
	# A minor axis steps up at each breakthrough (§6.2).
	if walls() and key in spell(id).get("minor", []):
		v *= pow(1.0 + float(data["progression"]["minor_step"]), stage(id))
	if id == "avalanche" and key == "cap" and has_mut("avalanche", "cap_plus"):
		v += 2
	if current and not boost.is_empty() and boost["id"] == id:
		if key == "damage":
			v *= float(boost["damage"])
		elif key in SIZE_KEYS:
			v *= float(boost["size"])
		elif key in COUNT_KEYS:
			v += int(boost["count"])
	# The telegraph never lands faster than a wizard-speed target can leave it.
	if id == "pillar" and key == "delay":
		v = maxf(v, fair_delay(stat("pillar", "radius", -1 if current else lv)))
	return v


## The shortest fair delay for a circle telegraph of radius `r`: a target as fast as the wizard,
## standing at its centre, can still step out (data "dodge"; design/magic-world-revisit.md §3).
func fair_delay(r: float) -> float:
	var w: Dictionary = data["wizard"]
	return float(data["dodge"]["reaction"]) + (r + float(w["radius"])) / float(w["speed"])


func stone_cap() -> int:
	return int(stat("avalanche", "cap"))


## In the slice, Practice grows faster below the best this Model reached in an earlier loop (Echo)
## and with each loop that reached day 7 (Fluency).
func xp_mult(id: String) -> float:
	if rules.is_empty():
		return 1.0
	var m := 1.0 + float(rules.get("fluency", 0.0))
	if level(id) < int(rules.get("echo", {}).get(id, 1)):
		m *= float(rules.get("echo_mult", 1.0))
	return m


## Adds spell XP and levels the spell up (several levels if needed). Milestone levels queue a pick.
## In the slice a stage's top level is a wall (spell spec §6.4): XP banks up to `xp_bank` of a
## level there until the spell breaks through. `practice` false (training) doesn't count towards
## the spell's feats.
func add_xp(id: String, amount: float, practice := true) -> void:
	if not p["spells"].has(id):
		return
	var s: Dictionary = p["spells"][id]
	var old := int(s["level"])
	if practice and walls():
		s["hits"] = int(s.get("hits", 0)) + 1
	if old >= max_level():
		return
	s["xp"] = float(s["xp"]) + amount * xp_mult(id)
	_climb(id)
	if int(s["level"]) != old:
		spell_leveled.emit(id, old, int(s["level"]))
	add_wizard_xp(amount * 0.5)


## Turns banked XP into levels, breaking through a stage's wall when its trials are done.
func _climb(id: String) -> void:
	var s: Dictionary = p["spells"][id]
	while int(s["level"]) < max_level() and float(s["xp"]) >= xp_needed(int(s["level"])):
		if at_wall(id):
			_check_trials(id)
			if not can_break(id):
				s["xp"] = minf(float(s["xp"]), xp_needed(int(s["level"])) * float(data["progression"]["xp_bank"]))
				return
			_break(id)
		s["xp"] = float(s["xp"]) - xp_needed(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		_reach(id, int(s["level"]))
	if int(s["level"]) >= max_level():
		s["xp"] = 0.0
	elif at_wall(id):
		_check_trials(id)


# --- mastery: stages, walls, trials, breakthroughs (spell spec §6.4; build item N-3) --------

## Stage walls apply in the slice only (the old Mill fight levels straight to the top).
func walls() -> bool:
	return bool(rules.get("walls", false))


## 0 Novice, 1 Adept, 2 Master, 3 Perfected: the breakthroughs made this life.
func stage(id: String) -> int:
	return int(p["spells"][id].get("stage", 0))


func stage_name(st: int) -> String:
	return str(data["progression"]["stages"][clampi(st, 0, 3)])


## The top level of stage `st` (5, 10, 15, 20).
func stage_top(st: int) -> int:
	return int(data["progression"]["stage_top"][clampi(st, 0, 3)])


## At the top of its stage, with a breakthrough still to come.
func at_wall(id: String) -> bool:
	return walls() and stage(id) < 3 and level(id) >= stage_top(stage(id))


## The Force grade it casts at (§6.3): its stage's grade, capped by your Ring.
func grade(id: String) -> int:
	var g := int(data["progression"]["grade_by_stage"][stage(id)])
	return mini(g, int(rules.get("grade_cap", g)))


## The three trials of spell `id`'s next breakthrough: [{"kind", "text", "done"}].
func trials(id: String) -> Array:
	var st := stage(id) + 1
	if st > 3:
		return []
	var done: Array = p["spells"][id].get("trials", {}).get(str(st), [])
	var pr: Dictionary = data["progression"]
	var f: Dictionary = spell(id).get("feats", pr["feats"])[st - 1]
	var out: Array = [{"kind": "feat", "text": str(f["text"]) % int(f["n"]), "done": "feat" in done}]
	var ins: Array = spell(id).get("insights", [])
	out.append({"kind": "insight", "text": "Insight: a teacher, a tome or a mural that shows it" if ins.size() < st or str(ins[st - 1]) == ""
		else "Insight: " + str(ins[st - 1]), "done": "insight" in done})
	out.append({"kind": "meditation", "text": "Meditate on it on %s's day" % element_sphere_name(spell(id)["element"]), "done": "meditation" in done})
	return out


func trials_needed(st: int) -> int:
	return int(data["progression"]["breakthrough_trials"][clampi(st - 1, 0, 2)])


## Marks trial `kind` passed for spell `id`'s next breakthrough, and breaks through if it can.
func pass_trial(id: String, kind: String) -> bool:
	var s: Dictionary = p["spells"][id]
	if stage(id) >= 3:
		return false
	if not s.has("trials"):
		s["trials"] = {}
	var key := str(stage(id) + 1)
	var done: Array = s["trials"].get(key, [])
	if kind in done:
		return false
	done.append(kind)
	s["trials"][key] = done
	_climb(id)
	return true


## A breakthrough can happen: at the wall, its trials done (or remembered from a past life), and
## for Perfected, the spell was taken to Master in a past life (§6.7).
func can_break(id: String) -> bool:
	if not at_wall(id):
		return false
	var st := stage(id) + 1
	if st == 3 and int(rules.get("echo", {}).get(id, 1)) < stage_top(1) + 1:
		return false
	if int(rules.get("broken", {}).get(id, 0)) >= st:
		return true
	return p["spells"][id].get("trials", {}).get(str(st), []).size() >= trials_needed(st)


## The feat and the insight are checked as you go (the meditation is the slice's).
func _check_trials(id: String) -> void:
	var st := stage(id) + 1
	if st > 3:
		return
	var s: Dictionary = p["spells"][id]
	var done: Array = s.get("trials", {}).get(str(st), [])
	var f: Dictionary = spell(id).get("feats", data["progression"]["feats"])[st - 1]
	if not "feat" in done and int(s.get(str(f["counter"]), 0)) >= int(f["n"]):
		done.append("feat")
	var ins: Array = spell(id).get("insights", [])
	if not "insight" in done and ins.size() >= st and str(ins[st - 1]) != "" and rules.get("known", {}).has(str(ins[st - 1])):
		done.append("insight")
	if not s.has("trials"):
		s["trials"] = {}
	s["trials"][str(st)] = done


## The breakthrough: the next stage, its step on the minor axes and grade (stat(), grade()) and
## its Revision pick.
func _break(id: String) -> void:
	var s: Dictionary = p["spells"][id]
	s["stage"] = stage(id) + 1
	breakthrough.emit(id, stage(id))
	var key := str(stage_top(stage(id) - 1))
	var opts: Array = spell(id).get("milestones", {}).get(key, [])
	if opts.is_empty() or s["muts"].has(key):
		return
	if opts.size() == 1:
		_apply_mut(id, int(key), opts[0])
		return
	pending.append({"spell": id, "level": int(key)})
	milestone_ready.emit()


## The weekday Sphere a spell's element belongs to ("mars"; the Hours are Saturn's).
func element_sphere(element: String) -> String:
	return str(data["elements"][element].get("sphere", element))


func element_sphere_name(element: String) -> String:
	return element_sphere(element).capitalize()


func set_level(id: String, lv: int) -> void:
	var s: Dictionary = p["spells"][id]
	var old := int(s["level"])
	lv = clampi(lv, 1, max_level())
	for l in range(old + 1, lv + 1):
		_reach(id, l)
	s["level"] = lv
	s["xp"] = 0.0
	if lv != old:
		spell_leveled.emit(id, old, lv)


func _reach(id: String, lv: int) -> void:
	if walls():
		return  # in the slice, the Revision comes with the breakthrough (_break)
	var opts: Array = spell(id).get("milestones", {}).get(str(lv), [])
	if opts.is_empty() or p["spells"][id]["muts"].has(str(lv)):
		return
	if opts.size() == 1:
		_apply_mut(id, lv, opts[0])
		return
	pending.append({"spell": id, "level": lv})
	milestone_ready.emit()


## A milestone's options. In the slice, the one you chose in an earlier loop comes first.
func milestone_options(entry: Dictionary) -> Array:
	var opts: Array = spell(entry["spell"])["milestones"][str(entry["level"])]
	var before: String = rules.get("revisions", {}).get(entry["spell"], {}).get(str(entry["level"]), "")
	if before == "":
		return opts
	var out: Array = opts.filter(func(m): return m["id"] == before)
	out.append_array(opts.filter(func(m): return m["id"] != before))
	return out


## Picks option `index` (0 or 1) for the oldest pending milestone.
func pick(index: int) -> void:
	if pending.is_empty():
		return
	var entry: Dictionary = pending.pop_front()
	var opts := milestone_options(entry)
	_apply_mut(entry["spell"], int(entry["level"]), opts[clampi(index, 0, opts.size() - 1)])


## The milestones a spell has reached that offer a choice: [{"level", "options", "chosen"}].
## Re-picking happens only at an Orrery shrine (design doc §7, decided 2026-10-14).
func repickable(id: String) -> Array:
	var out: Array = []
	var ms: Dictionary = spell(id).get("milestones", {})
	for lv in ms:
		var opts: Array = ms[lv]
		if opts.size() < 2 or not p["spells"][id]["muts"].has(lv):
			continue
		var chosen := 0
		for i in opts.size():
			if opts[i]["id"] == p["spells"][id]["muts"][lv]:
				chosen = i
		out.append({"level": int(lv), "options": opts, "chosen": chosen})
	return out


func repick(id: String, lv: int, index: int) -> void:
	var opts: Array = spell(id).get("milestones", {}).get(str(lv), [])
	if opts.size() < 2 or not p["spells"][id]["muts"].has(str(lv)):
		return
	var mut: Dictionary = opts[clampi(index, 0, opts.size() - 1)]
	if p["spells"][id]["muts"][str(lv)] == mut["id"]:
		return
	_apply_mut(id, lv, mut)


func _apply_mut(id: String, lv: int, mut: Dictionary) -> void:
	p["spells"][id]["muts"][str(lv)] = mut["id"]
	mutation_picked.emit(id, mut)
	save()


func has_mut(id: String, mut_id: String) -> bool:
	return mut_id in p["spells"][id]["muts"].values()


func mutated(id: String) -> bool:
	return not p["spells"][id]["muts"].is_empty()


func mut_names(id: String) -> Array:
	var out: Array = []
	var ms: Dictionary = spell(id).get("milestones", {})
	for lv in ms:
		var chosen = p["spells"][id]["muts"].get(lv, "")
		for m in ms[lv]:
			if m["id"] == chosen:
				out.append(m["name"])
	return out


## Element mastery: the sum of that element's spell levels (3 to 45 for a three-spell kit).
func mastery(element: String) -> int:
	var total := 0
	for id in data["spells"]:
		if data["spells"][id]["element"] == element:
			total += level(id)
	return total


# --- the spellbook --------------------------------------------------------

## Four spells, one per slot (Q, E, R, F), from any sphere (spell and combat spec §5.1).
func spellbook() -> Array:
	return p["spellbook"]


## The spheres in the spellbook, in slot order (only the open slots, in the slice).
func loadout() -> Array:
	var out: Array = []
	var book := spellbook()
	for i in book.size():
		if not slot_open(i):
			continue
		var e: String = spell(book[i])["element"]
		if not out.has(e):
			out.append(e)
	if out.is_empty():
		out.append(spell(book[0])["element"])
	return out


## In the slice a slot is closed until your Ring opens it, or while its spell's tier is too high.
func slot_open(i: int) -> bool:
	var open: Array = rules.get("open", [])
	return open.is_empty() or (i < open.size() and bool(open[i]))


func elements() -> Array:
	return data["elements"].keys()


## The spell of `element` in `slot` (bolt, control or signature).
func spell_for(element: String, slot: String) -> String:
	for id in data["spells"]:
		var s: Dictionary = data["spells"][id]
		if s["element"] == element and s["slot"] == slot:
			return id
	return ""


## Puts spell `id` in slot `index`. If it is already in another slot, the two swap.
func set_spell(index: int, id: String) -> void:
	if not data["spells"].has(id) or not unlocked(id) or index < 0 or index >= spellbook().size():
		return
	var book: Array = spellbook().duplicate()
	if book[index] == id:
		return
	var at := book.find(id)
	if at >= 0:
		book[at] = book[index]
	book[index] = id
	p["spellbook"] = book
	loadout_changed.emit()
	save()


## Some spells only come back with you: Hours (Rewind) is there from loop 2 ("from_loop").
func unlocked(id: String) -> bool:
	return loop() >= int(spell(id).get("from_loop", 1))


## The spheres with at least one spell you can put in the book now.
func open_elements() -> Array:
	return elements().filter(func(e):
		for id in data["spells"]:
			if data["spells"][id]["element"] == e and unlocked(id):
				return true
		return false)


static func valid_book(book, spells: Dictionary) -> bool:
	if typeof(book) != TYPE_ARRAY or book.size() != BOOK_SIZE:
		return false
	var seen := {}
	for id in book:
		if typeof(id) != TYPE_STRING or not spells.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true


## Fills the book from two spheres: their Bolts, then their Controls (a quick preset; the desk sets
## slots one by one).
func set_loadout(a: String, b: String) -> void:
	if a == b or not data["elements"].has(a) or not data["elements"].has(b):
		return
	var book: Array = []
	for slot in ["bolt", "control"]:
		book.append(spell_for(a, slot))
		book.append(spell_for(b, slot))
	if book == spellbook():
		return
	p["spellbook"] = book
	loadout_changed.emit()
	save()


## The first Magick whose two spheres are both in `spheres`, or "" if there is none.
func magick_for(pair: Array) -> String:
	if not rules.is_empty():
		return ""  # no Magicks in the slice; C is the Ward
	for id in data["magicks"]:
		var mp: Array = data["magicks"][id]["pair"]
		if pair.has(mp[0]) and pair.has(mp[1]):
			return id
	return ""


# --- magicks --------------------------------------------------------------

func knows(magick: String) -> bool:
	return magick in p["magicks"]


func learn(magick: String) -> void:
	if knows(magick):
		return
	p["magicks"].append(magick)
	magick_learned.emit(magick)
	save()


## Tomes give a hint toward a Magick rather than the Magick itself (design doc §5). Hints persist.
func has_hint(magick: String) -> bool:
	return magick in p["hints"]


func read_tome(magick: String) -> void:
	if has_hint(magick):
		return
	p["hints"].append(magick)
	hint_learned.emit(magick)
	save()


## The Magick the next tome hints at: unknown and unhinted, the equipped pair's first.
func tome_subject() -> String:
	var mine := magick_for(loadout())
	if mine != "" and not knows(mine) and not has_hint(mine):
		return mine
	for id in data["magicks"]:
		if not knows(id) and not has_hint(id):
			return id
	return ""


## A Magick levels with the lower of its two masteries (every 3 mastery points is a level).
func magick_level(magick: String) -> int:
	var pair: Array = data["magicks"][magick]["pair"]
	var low := mini(mastery(pair[0]), mastery(pair[1]))
	return clampi(low / 3, 1, max_level())


func magick_stat(magick: String, key: String) -> float:
	return stat_value(data["magicks"][magick]["stats"][key], magick_level(magick))


# --- wizard ---------------------------------------------------------------

func wizard_level() -> int:
	return int(p["wizard_level"])


func wizard_xp_needed(lv: int) -> float:
	var pr: Dictionary = data["progression"]
	return float(pr["wizard_xp_base"]) + float(pr["wizard_xp_step"]) * (lv - 1)


func add_wizard_xp(amount: float) -> void:
	if not rules.is_empty():
		return  # the slice grows by wells and Rings instead
	var old := wizard_level()
	p["wizard_xp"] = float(p["wizard_xp"]) + amount
	while float(p["wizard_xp"]) >= wizard_xp_needed(int(p["wizard_level"])):
		p["wizard_xp"] = float(p["wizard_xp"]) - wizard_xp_needed(int(p["wizard_level"]))
		p["wizard_level"] = int(p["wizard_level"]) + 1
	if wizard_level() != old:
		wizard_leveled.emit(old, wizard_level())


func max_hp(lv := -1) -> float:
	if lv < 0:
		if rules.has("hp"):
			return float(rules["hp"])
		lv = wizard_level()
	var pr: Dictionary = data["progression"]
	return float(pr["wizard_hp_base"]) + float(pr["wizard_hp_per_level"]) * (lv - 1)


func max_aether() -> float:
	return float(rules.get("aether", data["aether"]["max"]))


func blink_charges(lv := -1) -> int:
	if lv < 0:
		if rules.has("blinks"):
			return int(rules["blinks"])
		lv = wizard_level()
	var n := 1
	for at in data["progression"]["blink_charge_levels"]:
		if lv >= int(at):
			n += 1
	return n


# --- the loop -------------------------------------------------------------

func loop() -> int:
	return int(p["loop"])


func record(entry: Dictionary) -> void:
	entry["loop"] = loop()
	p["ledger"].append(entry)
	save()


## Wakes in the next loop: spells, mutations and Magicks stay; the wizard level drops to half.
func next_loop() -> void:
	p["loop"] = loop() + 1
	var keep := float(data["progression"]["loop_wizard_level_keep"])
	p["wizard_level"] = maxi(1, int(floor(wizard_level() * keep)))
	p["wizard_xp"] = 0.0
	pending.clear()
	# A spell that first comes back with you this loop goes straight into the last slot.
	for id in data["spells"]:
		if int(spell(id).get("from_loop", 1)) == loop() and not spellbook().has(id):
			var book: Array = spellbook().duplicate()
			book[book.size() - 1] = id
			p["spellbook"] = book
	save()


## Keeps the fight you just played, to be replayed backwards in the next loop.
func set_echo(track: Array, won: bool) -> void:
	p["echo"] = {"loop": loop(), "won": won, "track": track}
	save()


## The last fight's track if it came from an earlier loop, else [].
func echo_track() -> Array:
	var e = p.get("echo", {})
	if typeof(e) != TYPE_DICTIONARY or int(e.get("loop", loop())) >= loop():
		return []
	return e.get("track", [])


func reset_all() -> void:
	p = fresh()
	pending.clear()
	save()


# --- saving ---------------------------------------------------------------

func save() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var base := fresh()
	for k in base:
		if parsed.has(k):
			base[k] = parsed[k]
	# Spells added to the data after the save was written start at level 1.
	for id in data["spells"]:
		if not base["spells"].has(id):
			base["spells"][id] = {"level": 1, "xp": 0.0, "muts": {}}
	p = base
	# Saves from before the spellbook carried two elements: fill the book with their kits.
	if not valid_book(p["spellbook"], data["spells"]):
		p["spellbook"] = (data["start_spellbook"] as Array).duplicate()
		var lo = parsed.get("loadout", [])
		if typeof(lo) == TYPE_ARRAY and lo.size() == 2:
			set_loadout(str(lo[0]), str(lo[1]))
