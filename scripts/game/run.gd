extends Node
## The two layers of state (design/lives/lives-and-carryover-spec.md §4, design/lives/save-spec.md).
## `soul` is what you understand and remember, and keeps across lives: the Ledger, deaths, each
## spell's best Practice, the most wells you held, insight, a page per life. `life` is this year
## and resets at the Turning: the day, the time of day, flags, Practice, wells, what you learnt.
## The Turning (`end_life`) computes the new soul with scripts/game/lives.gd `carry` before it
## writes anything, and writes it so that a crash halfway can't lose it or count it twice.

const Lives := preload("res://scripts/game/lives.gd")

signal learned(id: String)

var save_dir := "user://slot1/"  # one slot for now (the save spec's three come with the title screen); tests use their own
var profile_path := "user://profile.json"  # the install's copy of every achievement earned (save spec §3)
const SAVE_VERSION := 1
const TIMES := ["morning", "noon", "afternoon", "dusk", "night"]
const TIME_NAMES := ["Morning", "Noon", "Afternoon", "Dusk", "Night"]
const CALENDAR := "res://data/world/calendar.json"
const LIVES := "res://data/world/lives.json"
const MOON_DAYS := 28
const MOONS := 13
const LAST_DAY := MOON_DAYS * MOONS  # the Great Eclipse: Moon 13, day 28

var cal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CALENDAR))
var lives: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIVES))

var soul := {}
var life := {}
var save_enabled := true


func _ready() -> void:
	save_enabled = not "--script" in OS.get_cmdline_args()
	new_run()
	if save_enabled:
		load_save()


func fresh_soul() -> Dictionary:
	return {"version": SAVE_VERSION, "lives": [], "insight": 0, "known": {}, "deaths": {}, "trials": [],
		"echo": {}, "revisions": {}, "best_wells": 0, "achievements": {}, "titles": [], "title": "",
		"play_s": 0.0, "fps": {"sum": 0.0, "n": 0, "min": 0}}  # for the playtest run summary


## The first morning of the next life: its number follows the soul's pages (save spec §5).
func fresh_life() -> Dictionary:
	var first: bool = (soul.get("lives", []) as Array).is_empty()
	return {"version": SAVE_VERSION, "n": soul.get("lives", []).size() + 1, "road": "apprentice" if first else "", "deeds": [],
		"day": 1, "time": 0, "flags": {}, "seen": {}, "learned": [], "dawn_done": false,
		"injured": false, "losses": [], "calamities": [], "omens": [], "earned": []}


## A brand new month: forgets everything.
func new_run() -> void:
	soul = fresh_soul()
	life = fresh_life()


## The Turning: this life ends (`cause`: "eclipse", "turned", "calamity:<id>"...). The soul takes
## what carries (Lives.carry) and is written at once; this life stays in memory for the death
## screen until you wake, but the saved life is already the next first morning.
func end_life(cause: String) -> void:
	var next: Dictionary = Lives.carry(soul, life, cause, lives)
	soul = next
	if save_enabled:
		_turn_on_disk(life)


## Whether you may turn back the Hours now (lives spec §3.1).
func can_turn() -> bool:
	return Lives.can_turn(life, lives)


## A calamity passed in this life (its id), which lets you turn back the Hours.
func pass_calamity(id: String) -> void:
	if not id in life["calamities"]:
		life["calamities"].append(id)


func insight() -> int:
	return int(soul.get("insight", 0))


# --- Omens (lives spec §6.4) ------------------------------------------------------------

func omens() -> Array:
	return life.get("omens", [])


## Omens are read on the first morning of life 2 onwards, before you rise.
func omens_offered() -> bool:
	return loop() > 1 and day() == 1 and time() == 0


## Takes Omen `id` for the rest of this life. Returns false if it can't be taken now.
func take_omen(id: String) -> bool:
	if not omens_offered() or id in omens() or not lives.get("omens", {}).has(id):
		return false
	life["omens"].append(id)
	return true


## The product of this life's Omens' `key` (enemy_hp, aether_regen); 1 with none.
func omen_mult(key: String) -> float:
	var m := 1.0
	for id in life.get("omens", []):
		m *= float(lives["omens"].get(id, {}).get(key, 1.0))
	return m


# --- roads (lives spec §5) -----------------------------------------------------------

## This life's road ("" until one is taken).
func road() -> String:
	return str(life.get("road", ""))


func road_name(id := "") -> String:
	id = id if id != "" else road()
	return str(lives["roads"].get(id, {}).get("name", "no road yet"))


## The roads offering themselves this life (none once a road is taken).
func road_offers() -> Array:
	return [] if road() != "" else Lives.offers(soul, lives)


## Takes road `id` for the whole life. Returns false if it isn't on offer.
func take_road(id: String) -> bool:
	if road() != "" or not (id in road_offers() or (id == "apprentice" and lives["roads"].has(id))):
		return false
	life["road"] = id
	return true


## A deed done in this life: a soul flag the Turning keeps (it may open a road; SEALED content).
func deed(id: String) -> void:
	if not id in life["deeds"]:
		life["deeds"].append(id)


## The pages of the lives already lived, oldest first.
func past_lives() -> Array:
	return soul.get("lives", [])


## Whether `cause` ends the life (data/world/lives.json "endings", or any calamity). Every other
## loss wakes you injured (lives spec §3.2).
func ends_life(cause: String) -> bool:
	return cause in lives["endings"] or cause.begins_with("calamity:")


## A loss that doesn't end the life: counted like a death, logged on this life's page. Returns the
## days that pass before you wake: none if you already lost today (two losses don't stack).
func lose(cause: String, wild := false) -> int:
	soul["deaths"][cause] = int(soul["deaths"].get(cause, 0)) + 1
	var w: Dictionary = lives["wake_injured"]
	var again: bool = not life["losses"].is_empty() and int(life["losses"][-1]["day"]) == day()
	var days: int = 0 if again else int(w["wild_days"] if wild else w["days"])
	life["losses"].append({"day": day(), "time": time_name(), "cause": cause, "learned": life["learned"].size(), "days": days})
	life["injured"] = true
	return days


func injured() -> bool:
	return bool(life.get("injured", false))


## Wake on the first morning of the next life: the life resets, the soul stays.
func wake() -> void:
	life = fresh_life()
	save()


## This life's number, from 1.
func loop() -> int:
	return int(life.get("n", 1))


func day() -> int:
	return int(life["day"])


func time() -> int:
	return int(life["time"])


func time_id() -> String:
	return TIMES[clampi(time(), 0, TIMES.size() - 1)]


func time_name() -> String:
	return TIME_NAMES[clampi(time(), 0, TIMES.size() - 1)]


## Moves to the next time of day. Returns false after Night (the day is over).
func advance_time() -> bool:
	if time() >= TIMES.size() - 1:
		return false
	life["time"] = time() + 1
	return true


# --- the calendar (N-1.1) -------------------------------------------------------

## 1..13
func moon() -> int:
	return (day() - 1) / MOON_DAYS + 1


## 1..28, the day of the moon.
func moon_day() -> int:
	return (day() - 1) % MOON_DAYS + 1


func moon_name(m := 0) -> String:
	return str(cal["moons"][clampi((m if m > 0 else moon()) - 1, 0, MOONS - 1)]["name"])


## The weekday's Sphere, {"sphere", "name", "color"}; weeks start on Sol's day.
func weekday(d := 0) -> Dictionary:
	return cal["weekdays"][((d if d > 0 else day()) - 1) % 7]


## "Moon 3 · Day 17"
func date_name(d := 0) -> String:
	d = d if d > 0 else day()
	return "Moon %d · Day %d" % [(d - 1) / MOON_DAYS + 1, (d - 1) % MOON_DAYS + 1]


func day_of(m: int, md: int) -> int:
	return (m - 1) * MOON_DAYS + md


func days_left() -> int:
	return LAST_DAY - day()


func next_day() -> void:
	life["day"] = mini(day() + 1, LAST_DAY)
	life["time"] = 0
	life["dawn_done"] = false



# --- memory ------------------------------------------------------------------

func knows(id: String) -> bool:
	return soul["known"].has(id)


## Remembers `id` for good. Returns true the first time.
func learn(id: String) -> bool:
	if knows(id):
		return false
	soul["known"][id] = loop()
	life["learned"].append(id)
	learned.emit(id)
	return true


func known_ids() -> Array:
	return soul["known"].keys()


func died_of(cause: String) -> int:
	return int(soul["deaths"].get(cause, 0))


# --- this loop -----------------------------------------------------------------

func flag(id: String) -> bool:
	return life["flags"].has(id)


func set_flag(id: String) -> void:
	life["flags"][id] = true


func clear_flag(id: String) -> void:
	life["flags"].erase(id)


func seen(scene_id: String) -> bool:
	return life["seen"].has(scene_id)


func mark_seen(scene_id: String) -> void:
	life["seen"][scene_id] = true


# --- save (save spec §2, §5; one slot) ------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_dir + "soul.json")


## Saves both layers (at dawn, on waking, after a loss).
func save() -> void:
	if not save_enabled:
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	_write("soul.json", soul)
	_write("life.json", life)


## Writes the soul alone (an achievement or what you learn is never lost to a crash).
func save_soul() -> void:
	if not save_enabled:
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	_write("soul.json", soul)


## Copies achievement `id` to the profile, which keeps it even if this playthrough is deleted.
func profile_earn(id: String) -> void:
	if not save_enabled:
		return
	var p = JSON.parse_string(FileAccess.get_file_as_string(profile_path)) if FileAccess.file_exists(profile_path) else null
	if not p is Dictionary:
		p = {"version": SAVE_VERSION, "achievements": {}}
	if not p.has("achievements"):
		p["achievements"] = {}
	if not p["achievements"].has(id):
		p["achievements"][id] = {"first_slot": save_dir.trim_suffix("/").get_file(), "date": Time.get_date_string_from_system()}
	var tmp := profile_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(p))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(profile_path))


## The Turning's writes, in the save spec's order: mark the turning, write the new soul, write the
## next first morning, clear the mark. `ended` is the life that just ended, kept so a crash before
## the soul was written can be redone on load.
func _turn_on_disk(ended: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	_write("meta.json", {"version": SAVE_VERSION, "turning": {"from_life": int(ended.get("n", 1)), "life": ended,
		"cause": soul["lives"][-1]["cause"] if not soul["lives"].is_empty() else ""}})
	_write("soul.json", soul)
	_write("life.json", fresh_life())
	_write("meta.json", {"version": SAVE_VERSION})


## Writes `name` beside a temporary copy and swaps it in, so a crash leaves the old file or the new.
func _write(name: String, data: Dictionary) -> void:
	var tmp := save_dir + name + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_dir + name))


func _read(name: String):
	if not FileAccess.file_exists(save_dir + name):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(save_dir + name))


func load_save() -> bool:
	var s = _read("soul.json")
	if not s is Dictionary:
		return false
	soul = fresh_soul()
	soul.merge(s, true)
	var meta = _read("meta.json")
	if meta is Dictionary and meta.has("turning"):
		# A Turning was cut short (save spec §5): finish it the same way either way.
		var t: Dictionary = meta["turning"]
		if soul["lives"].size() < int(t["from_life"]):
			soul = Lives.carry(soul, t["life"], str(t["cause"]), lives)
		_turn_on_disk(t["life"])
	var l = _read("life.json")
	life = fresh_life()
	if l is Dictionary and int(l.get("n", 0)) == soul["lives"].size() + 1:
		life.merge(l, true)
	# else: a life that doesn't follow the soul's pages is dropped; the soul always wins
	return true


func wipe() -> void:
	new_run()
	if save_enabled:
		for name in ["soul.json", "life.json", "meta.json"]:
			if FileAccess.file_exists(save_dir + name):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir + name))
