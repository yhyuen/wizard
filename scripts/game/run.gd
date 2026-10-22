extends Node
## The two layers of state (design/slice/systems.md §1; design/gdd/04-progression-and-loop.md).
## `mem` is what you remember and keeps across loops: the Ledger, Models, trials passed, deaths.
## `lp` is this loop and resets when you wake in the camp: the day, the time of day, flags, and
## what you learnt this loop (for the death screen). Saved at each dawn and at the end of a loop.

signal learned(id: String)

const SAVE_PATH := "user://ruins.json"  # the ruins game; the open world's saves (slice.json) don't carry over
const TIMES := ["morning", "noon", "afternoon", "dusk", "night"]
const TIME_NAMES := ["Morning", "Noon", "Afternoon", "Dusk", "Night"]
const CALENDAR := "res://data/world/calendar.json"
const LIVES := "res://data/world/lives.json"
const MOON_DAYS := 28
const MOONS := 13
const LAST_DAY := MOON_DAYS * MOONS  # the Great Eclipse: Moon 13, day 28

var cal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CALENDAR))
var lives: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIVES))

var mem := {}
var lp := {}
var save_enabled := true


func _ready() -> void:
	save_enabled = not "--script" in OS.get_cmdline_args()
	new_run()
	if save_enabled:
		load_save()


func fresh_mem() -> Dictionary:
	return {"loop": 1, "known": {}, "deaths": {}, "trials": [], "fluency": 0, "log": [],
		"play_s": 0.0, "fps": {"sum": 0.0, "n": 0, "min": 0}}  # for the playtest run summary


func fresh_loop() -> Dictionary:
	return {"day": 1, "time": 0, "flags": {}, "seen": {}, "learned": [], "dawn_done": false,
		"injured": false, "losses": [], "region": str(JSON.parse_string(FileAccess.get_file_as_string("res://data/world/regions.json"))["start"])}


## A brand new month: forgets everything.
func new_run() -> void:
	mem = fresh_mem()
	lp = fresh_loop()


## Ends this loop (`cause` is why: "patrol", "shrine", "eclipse", "fight:patrol"...). The
## memory keeps a count of each way you have died.
func end_loop(cause: String) -> void:
	mem["deaths"][cause] = int(mem["deaths"].get(cause, 0)) + 1
	mem["log"].append({"loop": loop(), "day": day(), "time": time_name(), "cause": cause, "learned": lp["learned"].duplicate()})
	save()


## Whether `cause` ends the life (data/world/lives.json "endings", or any calamity). Every other
## loss wakes you injured (lives spec §3.2).
func ends_life(cause: String) -> bool:
	return cause in lives["endings"] or cause.begins_with("calamity:")


## A loss that doesn't end the life: counted like a death, logged on this life's page. Returns the
## days that pass before you wake: none if you already lost today (two losses don't stack).
func lose(cause: String, wild := false) -> int:
	mem["deaths"][cause] = int(mem["deaths"].get(cause, 0)) + 1
	var w: Dictionary = lives["wake_injured"]
	var again: bool = not lp["losses"].is_empty() and int(lp["losses"][-1]["day"]) == day()
	var days: int = 0 if again else int(w["wild_days"] if wild else w["days"])
	lp["losses"].append({"day": day(), "time": time_name(), "cause": cause, "learned": lp["learned"].size(), "days": days})
	lp["injured"] = true
	return days


func injured() -> bool:
	return bool(lp.get("injured", false))


## Wake on day 1 of the next loop: the loop state resets, the memory stays.
func wake() -> void:
	mem["loop"] = loop() + 1
	lp = fresh_loop()
	save()


func loop() -> int:
	return int(mem["loop"])


func day() -> int:
	return int(lp["day"])


func time() -> int:
	return int(lp["time"])


func time_id() -> String:
	return TIMES[clampi(time(), 0, TIMES.size() - 1)]


func time_name() -> String:
	return TIME_NAMES[clampi(time(), 0, TIMES.size() - 1)]


## Moves to the next time of day. Returns false after Night (the day is over).
func advance_time() -> bool:
	if time() >= TIMES.size() - 1:
		return false
	lp["time"] = time() + 1
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
	lp["day"] = mini(day() + 1, LAST_DAY)
	lp["time"] = 0
	lp["dawn_done"] = false



# --- memory ------------------------------------------------------------------

func knows(id: String) -> bool:
	return mem["known"].has(id)


## Remembers `id` for good. Returns true the first time.
func learn(id: String) -> bool:
	if knows(id):
		return false
	mem["known"][id] = loop()
	lp["learned"].append(id)
	learned.emit(id)
	return true


func known_ids() -> Array:
	return mem["known"].keys()


func died_of(cause: String) -> int:
	return int(mem["deaths"].get(cause, 0))


# --- this loop -----------------------------------------------------------------

func flag(id: String) -> bool:
	return lp["flags"].has(id)


func set_flag(id: String) -> void:
	lp["flags"][id] = true


func clear_flag(id: String) -> void:
	lp["flags"].erase(id)


func seen(scene_id: String) -> bool:
	return lp["seen"].has(scene_id)


func mark_seen(scene_id: String) -> void:
	lp["seen"][scene_id] = true


# --- save ----------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"mem": mem, "loop": lp}))


func load_save() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary and d.has("mem") and d.has("loop")):
		return false
	mem = fresh_mem()
	mem.merge(d["mem"], true)
	lp = fresh_loop()
	lp.merge(d["loop"], true)
	return true


func wipe() -> void:
	new_run()
	if save_enabled and has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
