extends Node
## Spell levels, milestone mutations, element mastery, wizard level and the Loop Ledger.
## Spell knowledge survives a loop; the wizard level drops to half (design doc §3).
## Every number lives in data/spells.json.

signal spell_leveled(id: String, old_level: int, new_level: int)
signal milestone_ready
signal mutation_picked(id: String, mut: Dictionary)
signal wizard_leveled(old_level: int, new_level: int)
signal magick_learned(id: String)

const SAVE_PATH := "user://progress.json"

var data: Dictionary = {}
var p: Dictionary = {}
var pending: Array = []  # milestones waiting for a pick: {"spell", "level"}
var save_enabled := true  # tests turn saving off


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
	var spells := {}
	for id in data.get("spells", {}):
		spells[id] = {"level": 1, "xp": 0.0, "muts": {}}
	return {
		"spells": spells,
		"wizard_level": 1,
		"wizard_xp": 0.0,
		"loop": 1,
		"magicks": [],
		"ledger": [],
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
	if lv < 0:
		lv = level(id)
	var v := stat_value(spell(id)["stats"][key], lv)
	if id == "avalanche" and key == "cap" and has_mut("avalanche", "cap_plus"):
		v += 2
	return v


func stone_cap() -> int:
	return int(stat("avalanche", "cap"))


## Adds spell XP and levels the spell up (several levels if needed). Milestone levels queue a pick.
func add_xp(id: String, amount: float) -> void:
	if not p["spells"].has(id):
		return
	var s: Dictionary = p["spells"][id]
	var old := int(s["level"])
	if old >= max_level():
		return
	s["xp"] = float(s["xp"]) + amount
	while int(s["level"]) < max_level() and float(s["xp"]) >= xp_needed(int(s["level"])):
		s["xp"] = float(s["xp"]) - xp_needed(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		_reach(id, int(s["level"]))
	if int(s["level"]) >= max_level():
		s["xp"] = 0.0
	if int(s["level"]) != old:
		spell_leveled.emit(id, old, int(s["level"]))
	add_wizard_xp(amount * 0.5)


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
	var opts: Array = spell(id).get("milestones", {}).get(str(lv), [])
	if opts.is_empty() or p["spells"][id]["muts"].has(str(lv)):
		return
	if opts.size() == 1:
		_apply_mut(id, lv, opts[0])
		return
	pending.append({"spell": id, "level": lv})
	milestone_ready.emit()


func milestone_options(entry: Dictionary) -> Array:
	return spell(entry["spell"])["milestones"][str(entry["level"])]


## Picks option `index` (0 or 1) for the oldest pending milestone.
func pick(index: int) -> void:
	if pending.is_empty():
		return
	var entry: Dictionary = pending.pop_front()
	var opts := milestone_options(entry)
	_apply_mut(entry["spell"], int(entry["level"]), opts[clampi(index, 0, opts.size() - 1)])


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


# --- magicks --------------------------------------------------------------

func knows(magick: String) -> bool:
	return magick in p["magicks"]


func learn(magick: String) -> void:
	if knows(magick):
		return
	p["magicks"].append(magick)
	magick_learned.emit(magick)
	save()


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
	var old := wizard_level()
	p["wizard_xp"] = float(p["wizard_xp"]) + amount
	while float(p["wizard_xp"]) >= wizard_xp_needed(int(p["wizard_level"])):
		p["wizard_xp"] = float(p["wizard_xp"]) - wizard_xp_needed(int(p["wizard_level"]))
		p["wizard_level"] = int(p["wizard_level"]) + 1
	if wizard_level() != old:
		wizard_leveled.emit(old, wizard_level())


func max_hp(lv := -1) -> float:
	if lv < 0:
		lv = wizard_level()
	var pr: Dictionary = data["progression"]
	return float(pr["wizard_hp_base"]) + float(pr["wizard_hp_per_level"]) * (lv - 1)


func blink_charges(lv := -1) -> int:
	if lv < 0:
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
	save()


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
