extends "res://scripts/ui/atlas.gd"
## The game flow of the ruins game (design/ruins/, built on design/open-world/): the title card,
## the camp and the ruin (with the dialogue panel, the map, the spellbook and the Ledger over
## them), the loading card between maps, and the death screen. The world lives in scripts/world/
## and asks for scenes through world.requests; this plays them with the story engine
## (scripts/game/story.gd) and each map's story (data/world/maps.json "story"). What you
## remember and what resets are in the Run autoload, as in the slice.
##
## Everything a player can do here is also a method (talk, use, choose, advance...), so the
## route bot in tools/tests/route.gd plays the same code.

signal screen_changed(screen: String)

const Story := preload("res://scripts/game/story.gd")
const Growth := preload("res://scripts/game/growth.gd")
const World := preload("res://scripts/world/world.gd")
const Reach := preload("res://scripts/game/reach.gd")
const BuildId := preload("res://scripts/game/build_id.gd")
## Where playtesters send their notes (design/slice/README.md §5, M5).
const FEEDBACK_URL := "https://claude.ai/artifact/HryjwPHEs8S6swcQYFam6c"
## First-loop hints (onboarding), shown until they're done once.
const HINTS := {
	"walk": "Walk the camp. G talks to people and uses things when you're close. M opens the map, Z waits for the next time of day.",
	"talk": "Number keys or a click pick a choice; Space carries on. L opens the Ledger at any time.",
	"death": "Death resets your power, never what you know. Everything in the Ledger comes with you.",
}
const LEDGER_TABS := ["Questions", "Clues", "People", "Insights"]
## The Ledger entry that means you know a person well enough to find them on the map.
const MAX_BARKS := 2  # speech bubbles shown at once
const KNOWN_PEOPLE := {"mira": "mira", "aldous": "aldous", "pell": "pell", "captain": "captain"}
## The loading card stays up at least this long, and until the new map's shaders are warm.
const LOAD_MIN_S := 0.9

var main  # scripts/main.gd: the arena, the 3D view, input
var run  # the Run autoload
var story
var growth  # scripts/game/growth.gd: wells, Rings, Practice, the spellbook
var world  # scripts/world/world.gd
var reach  # scripts/game/reach.gd: regions, roads, the calendar's events
var encounters: Dictionary = {}
var ledger: Dictionary = {}  # data/world/ledger.json "entries"
var death_texts: Dictionary = {}

var screen := "title"  # title, world, loading (the card between maps), death, hurt (a lost fight)
var load_to := {}  # while the loading card is up: {"map", "spot", "t"}
var overlay := ""  # over the town: "", "map", "book", "ledger"
var map_tab := 0  # in the map: 0 here, 1 the Reach (the region map), 2 the calendar
var reach_pick := ""  # the region picked on the region map
var ledger_tab := 0
var ledger_q := ""  # the question picked in the Questions tab
var ledger_note := ""  # feedback on a wrong deduction, shown in the Ledger
var toasts: Array = []  # {"text", "t"}
var book_slot := 0  # the spellbook slot picked
var scene_t := 0.0
var dawn_t := 99.0  # seconds since you woke: the "Day N" card fades
var place_t := 99.0  # seconds since you walked into a new place: its name fades
var _place := ""
var fps_t := 0.0

# The scene being played.
var cur: Dictionary = {}
var idx := 0
var lines: Array = []  # [{"who", "text"}] in the dialogue panel
var pending := {}  # a blocking effect waiting for the player: {"op", "arg"}
var opts: Array = []  # the choices
var talking := ""  # the person spoken to
var after: Array = []  # what happens when the scene closes: "sleep", "book"
var fight_id := ""

## Tests set this to settle fights without playing them: func(encounter_id) -> bool (won), or
## -> {"won", "kills"}.
var fight_resolver: Callable


## Before the town is built: the run, the story and the town's state, for main.gd's view.
func setup(the_main) -> void:
	main = the_main
	run = main.get_node("/root/Run")
	story = Story.new(run)
	growth = Growth.new(run, main.get_node("/root/Progression"))
	story.ctx.growth = growth
	story.load_all()
	for e in story.errors:
		push_error("story: " + str(e))
	encounters = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/encounters.json"))["encounters"]
	var ld = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/ledger.json"))
	ledger = ld["entries"]
	death_texts = ld["deaths"]
	world = World.new(run, story)
	reach = Reach.new(run, story)
	world.busy = busy
	run.learned.connect(_on_learned)


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_screen(s: String) -> void:
	if s == "death":
		toasts.clear()
	if s != screen:
		scene_t = 0.0
	Sfx.ambience(s == "world")
	screen = s
	overlay = ""
	screen_changed.emit(s)


## Whether the town should stand still: a scene, a menu or another screen is showing.
func busy() -> bool:
	return screen != "world" or not cur.is_empty() or overlay != ""


## Whether a scene is open in the panel now (not waiting behind a fight or a cutscene).
func in_dialogue() -> bool:
	return screen == "world" and not cur.is_empty() and main.mode == "world"


# --- the month, the loop, the day ---------------------------------------------------------

func new_month() -> void:
	run.wipe()
	run.save()
	world.reset_loop()
	begin_day()


func continue_month() -> void:
	run.load_save()
	world.reset_loop()
	begin_day()


## Dawn: you wake on your cot in the camp (the save is made here).
func begin_day() -> void:
	growth.end_fight()
	run.life["time"] = 0
	run.save()
	growth.begin_fight()  # you can cast anywhere, so the day's Practice is lent all day
	cur = {}
	main.enter_world(world.map.spots["cot"])
	main.arena.kit.rest()  # a night's sleep: full Aether, no Strain
	_hurt_state()
	world.reset_day()
	set_screen("world")
	dawn_t = 0.0
	Sfx.play("chime")
	_start_period()


## A new time of day: a forced event if one is due, else whatever happens where you stand.
func _start_period() -> void:
	var f: String = story.forced()
	if f != "":
		play(f)
		return
	world.request({"t": "arrive", "place": world.here})


## The time of day ran out (or you waited): on to the next, or to sleep after Night.
func next_period() -> void:
	if not run.advance_time():
		toast("You fall asleep where you stand.")
		end_day()
		return
	world.clock = 0.0
	Sfx.play("chime")
	toast(run.time_name())
	_start_period()


## Z: wait for the next time of day.
func wait() -> void:
	if screen != "world" or busy() or main.mode != "world":
		return
	if world.threatened():
		toast("Not with something hunting you.")
		return
	if not world.map_def().get("clock", true):
		toast("There's no telling the hour down here.")
		return
	world.request({"t": "period"})


## Night falls, or you climb out of the ruin (a descent costs the day): sleep, and wake on the cot.
## A full night's sleep ends being Injured.
func end_day() -> void:
	cur = {}
	_to_camp()
	run.life["injured"] = false
	if not pass_days(1):
		return
	begin_day()


func _to_camp() -> void:
	if world.map_id != world.CAMP:
		world.load_map(world.CAMP)
		main.enter_world(world.map.spots["cot"])


## `n` days go by (asleep, travelling, resting or hurt). Returns false if the Eclipse came first:
## then you are in the camp and its scene is playing.
func pass_days(n: int) -> bool:
	for i in n:
		if run.day() >= run.LAST_DAY:
			_to_camp()
			play("eclipse")  # the second blast
			return false
		growth.end_fight()
		run.next_day()
	return true


## Being Injured (lives spec §3.2): Vitality held below its most, and a slower first spell each
## fight, until a full night's sleep.
func _hurt_state() -> void:
	var w: Dictionary = run.lives["wake_injured"]
	main.arena.set_injured(run.injured(), float(w["vitality"]), float(w["windup"]))


## A lost fight or a story loss: the life ends only for a calamity, the Eclipse or a Turning
## (Run.ends_life); anything else knocks you down and you wake injured a few days later.
func end_loop(cause: String) -> void:
	if not run.ends_life(cause):
		_lose(cause)
		return
	Sfx.play("death")
	growth.end_fight()
	growth.loop_over()
	run.end_life(cause)
	cur = {}
	pending = {}
	after = []
	_stop_talking()
	set_screen("death")


func _lose(cause: String) -> void:
	Sfx.play("death")
	growth.end_fight()
	run.lose(cause, bool(world.map_def().get("wild", false)))
	cur = {}
	pending = {}
	after = []
	lines = []
	_stop_talking()
	set_screen("hurt")


## From the hurt screen: the days pass and you wake on your cot, Injured.
func wake_hurt() -> void:
	if screen != "hurt":
		return
	cur = {}
	set_screen("world")
	_to_camp()
	if not pass_days(int(run.life["losses"][-1]["days"])):
		return
	begin_day()


## From the death screen: wake on day 1 of the next loop, everything in town as it was.
func wake() -> void:
	if screen == "hurt":
		wake_hurt()
		return
	if screen != "death":
		return
	run.wake()
	world.reset_loop()
	begin_day()


## The region you are in (data/world/regions.json).
func region() -> String:
	return reach.region_of(world.map_id)


## Why you can't travel or rest just now, or "" if you can.
func _cant_go() -> String:
	if screen != "world" or not cur.is_empty() or main.mode != "world":
		return "Not now."
	if world.threatened():
		return "Not with something hunting you."
	return ""


## Travel to region `id` on the region map (N-1.4): its days pass on the road and you arrive there
## in the morning. A region that isn't built yet only shows its card and costs no time.
func travel(id: String) -> bool:
	var days: int = reach.days_between(region(), id)
	if id == region() or days < 0 or not reach.built(id):
		return false
	var why := _cant_go()
	if why != "":
		toast(why)
		return false
	overlay = ""
	if not pass_days(days):
		return true
	var to: Dictionary = reach.region(id)
	growth.end_fight()
	run.life["time"] = 0
	run.save()
	growth.begin_fight()
	world.reset_day()
	dawn_t = 0.0
	go_map(str(to["maps"][0]), str(to["arrive"]))
	return true


## Rest in the camp until a day on the calendar (GDD 04 §4.2: one step, naming the event; nothing
## moves you without asking). You wake on your cot that morning, rested.
func rest_until(day: int) -> bool:
	if day <= run.day() or day > run.LAST_DAY:
		return false
	var why := _cant_go()
	if why == "" and region() != reach.d["start"]:
		why = "You can only rest that long in the camp."
	if why != "":
		toast(why)
		return false
	overlay = ""
	cur = {}
	_to_camp()
	run.life["injured"] = false
	if not pass_days(day - run.day()):
		return true
	begin_day()
	return true


## Through the loading card to `spot` on map `id`: the world switches its state, the arena and
## the view rebuild, and the new map's shaders compile behind the card.
func go_map(id: String, spot: String) -> void:
	cur = {}
	lines = []
	opts = []
	pending = {}
	_stop_talking()
	world.load_map(id)
	load_to = {"map": id, "spot": spot, "t": 0.0}
	set_screen("loading")
	main.change_map(world.map.spots[spot])


## `go halls landing` (a map and a spot there) or `go north_stair` (an exit of this map).
func _go(arg: String) -> void:
	var parts: Array = arg.split(" ", false)
	if parts.size() == 1:
		var ex: Dictionary = world.map.exits[parts[0]]
		go_map(ex["to"], ex["at"])
	else:
		go_map(parts[0], parts[1])


func _loading(dt: float) -> void:
	load_to["t"] += dt
	if load_to["t"] < LOAD_MIN_S or (main.view != null and main.view.warm > 0):
		return
	load_to = {}
	set_screen("world")
	main.resume_world()
	place_t = 0.0


# --- what the town asks for -------------------------------------------------------------------

func _process(dt: float) -> void:
	scene_t += dt
	dawn_t += dt
	place_t += dt
	_track_play(dt)
	for t in toasts.duplicate():
		t["t"] += dt
		if t["t"] > 4.0:
			toasts.erase(t)
	if screen == "loading":
		_loading(dt)
	if screen == "world":
		if world.here != _place:
			_place = world.here
			place_t = 0.0
		if not busy() and main.mode == "world":
			handle_requests()
	queue_redraw()


## Plays what the town asked for, one request at a time.
func handle_requests() -> void:
	while not world.requests.is_empty() and not busy() and main.mode == "world":
		var r: Dictionary = world.requests.pop_front()
		match r["t"]:
			"period":
				next_period()
			"talk":
				talk(r["id"], str(r.get("scene", "")))
			"use":
				use(r["id"])
			"exit":
				var s: String = story.use_scene(r["id"])
				if s != "":
					play(s)
				else:
					_go(r["id"])
			"arrive":
				var s: String = story.arrive_scene(str(r["place"]))
				if s != "":
					play(s)
			"scene":
				if not run.seen(r["id"]):
					play(r["id"])
			"cast":
				var s: String = story.cast_scene(r["item"], r["element"])
				if s != "":
					play(s)


## Talks to person `id`: their scene for now (or `scene`, when they came to you).
func talk(id: String, scene := "") -> void:
	if scene == "" or run.seen(scene):
		scene = story.talk_scene(id)
	if scene == "":
		return
	talking = id
	world.set_talking(id, true)
	if main.view != null:
		main.view.talk_to = id
	play(scene)


func use(id: String) -> void:
	var s: String = story.use_scene(id)
	if s != "":
		play(s)


func _stop_talking() -> void:
	if talking != "":
		world.set_talking(talking, false)
		talking = ""
	if main != null and main.view != null:
		main.view.talk_to = ""


# --- scenes -------------------------------------------------------------------------------

## Plays scene `id` from its first step. `append` keeps the lines already in the panel.
func play(id: String, append := false) -> void:
	if not story.scenes.has(id):
		push_error("no scene " + id)
		return
	cur = story.scenes[id]
	idx = 0
	pending = {}
	opts = []
	if not append:
		lines = []
	run.mark_seen(id)
	scene_t = 0.0
	_run_steps()


func _run_steps() -> void:
	var steps: Array = cur["steps"]
	while idx < steps.size():
		var st: Dictionary = steps[idx]
		idx += 1
		if not story.test(st.get("cond", "")):
			continue
		if st["t"] == "line":
			lines.append({"who": st["who"], "text": st["text"]})
			continue
		if _effect(st["op"], st["arg"]):
			return
	opts = story.choices(cur)
	if opts.is_empty():
		if lines.is_empty():
			finish_scene()  # nothing to read (the spellbook from the desk)
			return
		opts = [{"text": "Continue", "target": ""}]


## Applies one effect. Returns true when the scene must stop here (a fight, a jump, an ending).
func _effect(op: String, arg: String) -> bool:
	match op:
		"learn":
			run.learn(arg)
		"set":
			var r: int = growth.ring()
			run.set_flag(arg)
			_ring_toast(r)  # a Ring trial sets "ring1"
		"clear":
			run.clear_flag(arg)
		"model":
			run.learn("model_" + arg)
			growth.refresh()
		"trial":
			run.learn("trial_" + arg)
		"sound":
			Sfx.play(arg)
		"cutscene", "play_path":
			if fight_resolver.is_valid() or main == null or main.view == null:
				return false  # tests skip the pictures
			var cid := ("path:" + arg) if op == "play_path" else arg
			main.start_world_cutscene(cid, world.map.spots.get("fire_you", world.player_pos()))
			return true
		"wells", "meditate":
			if growth.use_today(op):
				gain_wells(int(arg))
				if op == "meditate" and main != null:
					main.arena.kit.rest()  # meditating is a rest: full Aether, no Strain
				if op == "meditate":
					after.append("period")  # only actions cost time (GDD 04 §4.2)
			else:
				toast("You've already meditated today. It doesn't come twice.")
		"train":
			if growth.use_today(op):
				var got: Dictionary = growth.train()
				var parts: Array = []
				for id in got:
					parts.append("%s %d" % [growth.prog.spell(id)["name"], growth.level(id)])
				toast("Practice: " + ", ".join(parts))
				after.append("period")
			else:
				toast("Your hands are done for today.")
		"move":
			main.place_player(world.map.spots[arg])
		"take":
			if not run.life.has("taken"):
				run.life["taken"] = {}
			run.life["taken"][arg] = true
		"sleep", "book":
			after.append(op)
		"go":
			after.append("go " + arg)
		"today":
			run.life["done_" + arg] = run.day()
		"open":
			world.map.doors[arg]["open"] = true
			Sfx.play("chime")
		"goto":
			if lines.is_empty():
				play(arg, true)
			else:
				pending = {"op": "goto", "arg": arg}
			return true
		"fight", "end_loop":
			pending = {"op": op, "arg": arg}
			return true
		_:
			push_warning("story effect not handled yet: " + op)
	return false


func gain_wells(n: int) -> void:
	var r: int = growth.ring()
	var got: int = growth.add_wells(n)
	if got > 0:
		toast("Wells +%d%s" % [got, "  (echo)" if got > n else ""])
	_ring_toast(r)


## Names a new Ring and the slots it opens; the day's lent rules follow.
func _ring_toast(before: int) -> void:
	growth.refresh()
	if main != null:
		main.refresh_player()
	if growth.ring() > before:
		toast("The %s: %d spellbook slots" % [growth.ring_name(), growth.slots()])


## The button under the panel when a blocking effect is waiting.
func pending_label() -> String:
	match pending.get("op", ""):
		"fight":
			return "Fight"
		"end_loop":
			return "…"
	return "Continue"


## Space, Enter or the single button: carry on past a blocking effect.
func advance() -> void:
	if not in_dialogue() and not (fight_resolver.is_valid() and not cur.is_empty()):
		return
	if not pending.is_empty():
		Sfx.play("page")
		var p: Dictionary = pending
		pending = {}
		match p["op"]:
			"goto":
				lines = []
				play(p["arg"])
			"fight":
				_start_fight(p["arg"])
			"end_loop":
				end_loop(p["arg"])
		return
	if opts.size() == 1:
		choose(0)


func choose(i: int) -> void:
	if cur.is_empty() or not pending.is_empty() or i < 0 or i >= opts.size():
		return
	var c: Dictionary = opts[i]
	Sfx.play("page")
	if c.get("target", "") != "":
		play(c["target"])
	else:
		finish_scene()


## The scene chain is over: the town carries on.
func finish_scene() -> void:
	cur = {}
	lines = []
	opts = []
	_stop_talking()
	if main != null:
		main.input_cool = 0.25  # the click that closed the panel doesn't also cast
	var a := after
	after = []
	for op in a:
		if op.begins_with("go "):
			_go(op.substr(3))
			return
	if "sleep" in a:
		end_day()
	elif "book" in a:
		overlay = "book"
	elif "period" in a and world.map_def().get("clock", true):
		world.request({"t": "period"})


# --- fights in place ---------------------------------------------------------------------

func _start_fight(id: String) -> void:
	fight_id = id
	var enc: Dictionary = encounters[id].duplicate(true)
	if enc.has("waived") and run.knows("trial_" + id.trim_suffix("_trial")):
		enc["waves"] = enc["waived"]
	if enc.has("flooded_by") and story.ctx.done(str(enc["flooded_by"])):
		# the sluice was turned this descent: the guardian starts quenched (design/ruins/content.md §4)
		for wave in enc["waves"]:
			for g in wave:
				if g.get("guardian", false):
					g["flags"] = g.get("flags", {}).duplicate()
					g["flags"]["flooded"] = true
		enc["flooded"] = true
	if fight_resolver.is_valid():
		var r = fight_resolver.call(id)  # won, or {"won", "kills"}
		if r is Dictionary:
			fight_done(bool(r["won"]), int(r.get("kills", 0)))
		else:
			fight_done(bool(r))
		return
	main.start_world_fight(enc, spawns_for(id))


## Where encounter `id` comes from (data/world/map.json "spawns"): fixed points, and/or a ring of
## mist round you ("ring": [near, far], "ring_n" points, 8 unless given). It can also move you (the tide pulls you to the north door) and open a door.
func spawns_for(id: String) -> Array:
	var rule: Dictionary = world.map.d["spawns"].get(id, {})
	if rule.has("you") and main != null:
		main.place_player(Vector2(rule["you"][0], rule["you"][1]))
	if rule.has("open"):
		world.map.doors[str(rule["open"])]["open"] = true
	var out: Array = []
	for p in rule.get("points", []):
		out.append(Vector2(p[0], p[1]))
	if rule.has("ring"):
		var at: Vector2 = world.player_pos()
		var rng := RandomNumberGenerator.new()
		rng.seed = run.day() * 31 + run.loop()
		var tries := 0
		var want: int = out.size() + int(rule.get("ring_n", 8))
		while out.size() < want and tries < 200:
			tries += 1
			var q: Vector2 = at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rule["ring"][0], rule["ring"][1])
			if world.map.bounds.grow(-20).has_point(q) and not world.map.solid_at(q, 8.0) and not world.map.in_water(q, 6.0):
				out.append(q)
	return out


## Called by main.gd when a cutscene is over: the scene carries on from where it stopped.
func cutscene_done() -> void:
	_run_steps()


## Called by main.gd when a fight started here is over.
func fight_done(won: bool, kills := 0) -> void:
	if kills > 0:
		gain_wells(kills * int(growth.d["wells"]["kill"]))
	var lethal := bool(encounters[fight_id].get("lethal", true))
	if not won and not lethal and main != null and not fight_resolver.is_valid():
		main.arena.resume_explore()
	var outs: Dictionary = cur.get("outcomes", {})
	var key := "won" if won else "lost"
	if outs.has(key):
		play(outs[key])
		return
	if not won and lethal:
		lines = []
		end_loop("fight:" + fight_id)
		return
	_run_steps()


# --- the spellbook (from your desk) ---------------------------------------------------------

func _pick_slot(i: int) -> void:
	book_slot = i


func _put_model(id: String) -> void:
	if growth.set_slot(book_slot, id):
		growth.refresh()
		main.refresh_book()


func _slot_ring(i: int) -> String:
	var sl: Array = growth.d["slots"]
	for r in sl.size():
		if int(sl[r]) > i:
			return growth.ring_name(r)
	return ""


# --- the map ---------------------------------------------------------------------------------

## The map's frame on screen, and the scale from the town's sim pixels to it.
const MAP_RECT := Rect2(40, 70, 880, 420)


func map_xf() -> Array:
	var b: Rect2 = world.map.bounds
	var k := minf(MAP_RECT.size.x / b.size.x, (MAP_RECT.size.y - 30) / b.size.y)
	var off := MAP_RECT.position + Vector2((MAP_RECT.size.x - b.size.x * k) * 0.5, 24)
	return [off, k]


func to_map(p: Vector2) -> Vector2:
	var xf := map_xf()
	return xf[0] + p * float(xf[1])


## Click a place on the map to walk there along the streets.
func map_walk(place: String) -> void:
	overlay = ""
	main.walk_to(world.map.place_centre(place))


# --- the Ledger --------------------------------------------------------------------

func _on_learned(id: String) -> void:
	var e: Dictionary = ledger.get(id, {})
	if e.is_empty():
		push_warning("no Ledger entry for " + id)
	elif e["kind"] != "trial":
		toast("Ledger: %s" % e["title"])
	# Questions open as soon as anything they're about is known.
	for qid in ledger:
		var q: Dictionary = ledger[qid]
		if q["kind"] == "question" and not run.knows(qid) and id in q.get("opens", []):
			run.learn(qid)


func entries_of(kind: String) -> Array:
	var out: Array = []
	for id in run.known_ids():
		if ledger.has(id) and ledger[id]["kind"] == kind:
			out.append(id)
	return out


func toast(s: String) -> void:
	toasts.append({"text": s, "t": 0.0})
	if toasts.size() > 6:
		toasts.pop_front()


func toggle_ledger() -> void:
	if screen in ["world", "death", "hurt"]:
		overlay = "" if overlay == "ledger" else "ledger"


func toggle_map() -> void:
	if screen == "world" and cur.is_empty():
		overlay = "" if overlay == "map" else "map"


# --- playtest ------------------------------------------------------------------------

## Counts real time played and, once a second in town, the frame rate, for the run summary.
func _track_play(dt: float) -> void:
	if screen == "title" or main == null or main.bot.is_valid() or fight_resolver.is_valid():
		return
	run.soul["play_s"] = float(run.soul.get("play_s", 0.0)) + dt
	if screen != "world":
		return
	fps_t += dt
	if fps_t >= 1.0:
		fps_t = 0.0
		var f: Dictionary = run.soul["fps"]
		var now := int(Engine.get_frames_per_second())
		f["sum"] = float(f["sum"]) + now
		f["n"] = int(f["n"]) + 1
		f["min"] = now if int(f["n"]) == 1 else mini(int(f["min"]), now)


## A plain-text report of this month for the feedback form.
func run_summary() -> String:
	var out: Array = ["The Shattered Orrery, first playable · build %s · %s" % [BuildId.ID, OS.get_name()]]
	out.append("Played %d min · loop %d, day %d, %s · %s, %d wells" % [roundi(float(run.soul.get("play_s", 0.0)) / 60.0),
		run.loop(), run.day(), run.time_name().to_lower(), growth.ring_name(), growth.wells()])
	var known: Array = run.known_ids().filter(func(id): return ledger.has(id) and ledger[id]["kind"] != "trial")
	var qs: Array = ledger.keys().filter(func(id): return ledger[id]["kind"] == "question")
	out.append("Ledger: %d entries · questions answered %d of %d" % [known.size(), qs.filter(func(q): return solved(q)).size(), qs.size()])
	var reached: Array = []
	for f in ["ring1"]:
		if run.flag(f):
			reached.append(f)
	for k in ["carried_out", "rune_ashlar", "the_halls"]:
		if run.knows(k):
			reached.append(k)
	out.append("This loop / ever: " + (", ".join(reached) if not reached.is_empty() else "nothing yet"))
	out.append("Now: %s" % str(world.map_def().get("name", world.map_id)))
	for d in run.past_lives():
		out.append("Loop %d ended on %s, %s: %s (%d learned)" % [d["loop"], run.date_name(int(d["day"])), str(d["time"]).to_lower(), d["cause"], d["learned"].size()])
	for l in run.life["losses"]:
		out.append("This loop: lost on %s, %s: %s; woke Injured %d days later" % [run.date_name(int(l["day"])), str(l["time"]).to_lower(), l["cause"], int(l["days"])])
	var f: Dictionary = run.soul.get("fps", {})
	if int(f.get("n", 0)) > 0:
		out.append("In town: %d fps on average, %d at worst · graphics %s%s" % [roundi(float(f["sum"]) / int(f["n"])), int(f["min"]),
			main.gfx, " (now low)" if main.view != null and main.view.low and main.gfx == "auto" else ""])
	return "\n".join(out)


func copy_summary() -> void:
	DisplayServer.clipboard_set(run_summary())
	toast("Run summary copied. Paste it into the feedback form.")


func open_feedback() -> void:
	OS.shell_open(FEEDBACK_URL)
	toast("The feedback form opens in a new tab.")


## The two playtest buttons, top right.
func _draw_playtest_buttons(summary := true) -> void:
	if summary:
		button(Rect2(626, 16, 170, 26), "Copy run summary", copy_summary, 0, 13)
	button(Rect2(806, 16, 134, 26), "Feedback form", open_feedback, 0, 13)

func _unhandled_input(ev: InputEvent) -> void:
	if main == null or main.bot.is_valid():
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = ev.physical_keycode
	var dlg := in_dialogue()
	if k == KEY_L:
		toggle_ledger()
	elif k == KEY_F8:
		Sfx.muted = not Sfx.muted
		Sfx.ambience(not Sfx.muted and screen == "world")
		toast("Sound off (F8)" if Sfx.muted else "Sound on (F8)")
	elif k == KEY_M and screen == "world":
		toggle_map()
	elif k == KEY_ESCAPE and overlay != "":
		overlay = ""
	elif overlay == "ledger" and k >= KEY_1 and k <= KEY_4:
		ledger_tab = k - KEY_1
	elif overlay == "map" and k >= KEY_1 and k <= KEY_3:
		map_tab = k - KEY_1
	elif (dlg or overlay == "book") and k >= KEY_1 and k <= KEY_9:
		press_key(k - KEY_0)
	elif k == KEY_G and screen == "world" and not dlg and overlay == "" and main.mode == "world":
		world.interact(world.reachable())
	elif k == KEY_Z and screen == "world" and not dlg and overlay == "":
		wait()
	elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		if dlg:
			advance()
		elif overlay == "book":
			overlay = ""
		else:
			match screen:
				"death", "hurt":
					wake()
				"title":
					if run.has_save():
						continue_month()
					else:
						new_month()
				_:
					return
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if click(ev.position):
			accept_event()


# --- drawing -------------------------------------------------------------------------

func _draw() -> void:
	begin_text(screen == "world" and overlay == "")  # the map, book and Ledger cover the town
	begin_buttons()
	match screen:
		"title":
			draw_rect(Rect2(0, 0, 960, 540), NIGHT)
			_draw_title()
		"world":
			if main.mode in ["world", "fight"]:
				_draw_world()
		"death":
			draw_rect(Rect2(0, 0, 960, 540), NIGHT)
			_draw_death()
		"hurt":
			draw_rect(Rect2(0, 0, 960, 540), NIGHT)
			_draw_hurt()
		"loading":
			draw_rect(Rect2(0, 0, 960, 540), NIGHT)
			_draw_loading()
	match overlay:
		"ledger":
			begin_buttons()
			_draw_ledger()
		"map":
			begin_buttons()
			_draw_map()
		"book":
			begin_buttons()
			_draw_book()
	if overlay != "ledger":
		_draw_toasts()
	end_buttons()


## A first-loop hint, or "" once it has been done.
func hint_for(s: String) -> String:
	if not HINTS.has(s) or run.loop() > 1 and s != "death":
		return ""
	if not run.soul.has("hints"):
		run.soul["hints"] = {}
	return "" if run.soul["hints"].has(s) else HINTS[s]


func _draw_hint(h: String, r: Rect2) -> void:
	var rows: Array = wrap_text(h, r.size.x - 28, 13)
	r.size.y = 14 + rows.size() * 17
	draw_rect(r, Color(0.02, 0.03, 0.07, 0.9))
	draw_rect(r, Color(HOURS, 0.6), false, 1.0)
	for i in rows.size():
		text(r.position + Vector2(14, 20 + i * 17), rows[i], 13, Color(HOURS, 0.95))


func _draw_title() -> void:
	title(Vector2(0, 150), "The Shattered Orrery", 50, HAIR, HORIZONTAL_ALIGNMENT_CENTER, 960)
	text(Vector2(0, 186), "First playable, R1  ·  the survivors' camp and the way down", 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	text(Vector2(0, 210), "The Orrery fell last night and took most of Vellmar with it. Wren is somewhere below.", 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var y := 250.0
	if run.has_save() and not run.known_ids().is_empty():
		button(Rect2(370, y, 220, 34), "Continue  (loop %d, %s)" % [run.loop(), run.date_name()], continue_month, 1, 15)
		y += 44.0
		button(Rect2(370, y, 220, 34), "Begin a new month", new_month, 2, 15)
	else:
		button(Rect2(370, y, 220, 34), "Begin", new_month, 1, 15)
	_draw_playtest_buttons(run.has_save() and not run.known_ids().is_empty())
	var ctl = main.controls
	var g: String = {"auto": "auto", "high": "high", "low": "low"}.get(main.gfx, "auto")
	text(Vector2(0, 446), "Tab  ·  Controls: %s        F4  ·  Graphics: %s" % [ctl.NAMES[ctl.scheme], g], 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var walk := "Right-click to walk and to talk" if ctl.league() else "WASD to walk"
	text(Vector2(0, 472), "%s  ·  G talks and uses  ·  M map  ·  Z wait  ·  L Ledger  ·  F8 sound" % walk, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960)


## The town's own layer: the day card, the place you walked into, what people say as you pass,
## what G would do, and the dialogue panel.
func _draw_world() -> void:
	var view = main.view
	if view == null:
		return
	var dlg := in_dialogue()
	# People's barks over their heads.
	# The nearest few only, and never over the HUD or each other, so a crowd stays readable.
	if not dlg and main.mode == "world":
		var near: Array = world.people.list.filter(func(p): return p.bark != "" and p.on and p.fade <= 0.5)
		var me: Vector2 = world.player_pos()
		near.sort_custom(func(a, b): return a.pos.distance_squared_to(me) < b.pos.distance_squared_to(me))
		var taken: Array = [Rect2(0, 0, 960, 90), Rect2(0, 0, 236, 150), Rect2(220, 405, 740, 135)]
		if overlay == "" and hint_for("walk") != "":
			taken.append(Rect2(250, 322, 460, 50))  # the walk hint, drawn below
		var shown := 0
		for p in near:
			if shown >= MAX_BARKS:
				break
			var at: Vector2 = view.to_screen(p.pos, 2.5)
			var a := clampf(float(world.cfg["bark_life"]) - p.bark_t, 0.0, 1.0) * clampf(p.bark_t * 5.0, 0.0, 1.0)
			var r := _bubble_rect(at, p.bark, p.name if not p.crowd else "")
			if taken.any(func(t): return t.intersects(r.grow(4.0))):
				continue
			taken.append(r)
			shown += 1
			_bubble(r, p.bark, a, p.name if not p.crowd else "")
	# What G would do.
	var target: Dictionary = world.reachable() if not dlg and overlay == "" and main.mode == "world" else {}
	if not target.is_empty():
		var h := 2.2 if target["type"] == "person" else float(world.map.items[target["id"]].get("height", 1.1))
		var at: Vector2 = view.to_screen(target["pos"], h)
		var label := "G  ·  %s %s" % [target["verb"], target["name"]] if target["type"] == "person" else "G  ·  %s: %s" % [target["verb"], target["name"]]
		var w := text_w(label, 13) + 20.0
		var r := Rect2(at + Vector2(-w * 0.5, -30), Vector2(w, 22))
		draw_rect(r, Color(BG, 0.85))
		draw_rect(r, Color(GOLD, 0.6), false, 1.0)
		text(r.position + Vector2(10, 16), label, 13, GOLD)
	# The day card at dawn, and the name of each place you walk into.
	var card_s := float(world.cfg["dawn_card_s"])
	if dawn_t < card_s:
		var a := clampf(card_s - dawn_t, 0.0, 1.0) * clampf(dawn_t * 3.0, 0.0, 1.0)
		var left: int = run.days_left()
		var sub := "Dawn over the camp."
		if run.day() == 1 and run.loop() == 1:
			sub = "The morning after the Orrery fell."
		elif run.day() == 1:
			sub = "The morning after, again. You remember everything; your hands don't."
		elif run.time() == 4:
			sub = "Night."
		title(Vector2(0, 170), "%s, day %d" % [run.moon_name(), run.moon_day()], 40, Color(GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
		text(Vector2(0, 222), "%s  ·  %s" % [run.date_name(), run.weekday()["name"]], 13, Color(HAIR, a * 0.8), HORIZONTAL_ALIGNMENT_CENTER, 960)
		if run.injured():
			sub = "You wake stiff and sore. You're Injured until you next sleep a full night."
		text(Vector2(0, 200), "%s  %d day%s to the Eclipse." % [sub, left, "" if left == 1 else "s"], 15, Color(PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
	elif place_t < 3.0 and _place != "" and not dlg and main.mode == "world":
		var a := clampf(3.0 - place_t, 0.0, 1.0) * clampf(place_t * 3.0, 0.0, 1.0)
		title(Vector2(0, 130), world.map.place_name(_place), 20, Color(HAIR, a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, 960)
	if dlg:
		_draw_dialogue()
	elif main.mode == "world" and overlay == "":
		var h := hint_for("walk")
		if h != "":
			_draw_hint(h, Rect2(250, 322, 460, 0))  # under the wizard, clear of the place name
			if scene_t > 12.0 or world.clock > 20.0:
				run.soul["hints"]["walk"] = true


## A speech bubble over a head: a line someone says as you pass.
func _bubble_rect(at: Vector2, s: String, who := "") -> Rect2:
	var rows: Array = wrap_text(s, 220.0, 12)
	var w := 0.0
	for row in rows:
		w = maxf(w, text_w(row, 12))
	w += 18.0
	var h := 8.0 + rows.size() * 15.0 + (14.0 if who != "" else 0.0)
	var r := Rect2(at + Vector2(-w * 0.5, -h - 8), Vector2(w, h))
	r.position.x = clampf(r.position.x, 8, 952 - w)
	return r


func _bubble(r: Rect2, s: String, a: float, who := "") -> void:
	var rows: Array = wrap_text(s, 220.0, 12)
	draw_rect(r, Color(BG, 0.8 * a))
	draw_rect(r, Color(HAIR, 0.35 * a), false, 1.0)
	var y := r.position.y + 14
	if who != "":
		text(Vector2(r.position.x + 9, y), who, 11, Color(GOLD, a))
		y += 14
	for row in rows:
		text(Vector2(r.position.x + 9, y), row, 12, Color(PAPER, a))
		y += 15


## The dialogue panel at the bottom of the screen, over the live town.
func _draw_dialogue() -> void:
	var r := Rect2(130, 318, 700, 212)
	panel(r)
	var who: String = world.people.get_person(talking).name if talking != "" and world.people.get_person(talking) != null else world.map.place_name(world.here)
	title(r.position + Vector2(24, 26), who, 15, Color(HAIR, 0.85))
	var nopt := maxi(1, opts.size()) if pending.is_empty() else 1
	var bottom := r.end.y - 12.0 - 34.0 * nopt
	# The newest lines that fit above the choices.
	var shown: Array = []
	var room := bottom - (r.position.y + 50.0)
	for i in range(lines.size() - 1, -1, -1):
		var ln: Dictionary = lines[i]
		var hgt := float(wrap_text(ln["text"], r.size.x - (150.0 if ln["who"] != "" else 48.0), 14).size()) * 18.5 + 5.0
		if room - hgt < 0.0 and not shown.is_empty():
			break
		room -= hgt
		shown.push_front(ln)
	var y := r.position.y + 50.0
	for ln in shown:
		if ln["who"] != "":
			text(Vector2(r.position.x + 24, y), ln["who"], 13, GOLD)
			y = para(Vector2(r.position.x + 110, y), ln["text"], r.size.x - 134, 14, PAPER) + 5.0
		else:
			y = para(Vector2(r.position.x + 24, y), ln["text"], r.size.x - 48, 14, Color(PAPER, 0.85)) + 5.0
	if not pending.is_empty():
		button(Rect2(r.position.x + 24, r.end.y - 44, 200, 30), pending_label(), advance, 1, 14)
		return
	y = bottom
	for i in opts.size():
		button(Rect2(r.position.x + 24, y, r.size.x - 48, 30), opts[i]["text"], choose.bind(i), i + 1, 14)
		y += 34.0
	var h := hint_for("talk")
	if h != "":
		_draw_hint(h, Rect2(r.position.x + 120, r.position.y - 60, 460, 0))
		if scene_t > 6.0:
			run.soul["hints"]["talk"] = true


const MAP_TABS := ["Here", "The Reach", "Calendar"]


## The map (M), in three tabs (1–3): this map, the Reach (the region map) and the calendar.
func _draw_map() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.72))
	draw_rect(MAP_RECT, NIGHT)
	panel(MAP_RECT, Color(GOLD, 0.6))
	var x := MAP_RECT.position.x
	for i in MAP_TABS.size():
		var tr := Rect2(x, MAP_RECT.position.y - 32, 130, 26)
		var on := i == map_tab
		draw_rect(tr, Color(GOLD, 0.25) if on else Color(0, 0, 0, 0.5))
		draw_rect(tr, Color(GOLD, 0.8 if on else 0.3), false, 1.0)
		text(tr.position + Vector2(10, 18), "%d  %s" % [i + 1, MAP_TABS[i]], 13, GOLD if on else PAPER)
		buttons.append({"r": tr, "act": func(): map_tab = i, "key": 0})
		x += 138.0
	match map_tab:
		1:
			_draw_reach()
		2:
			_draw_calendar()
		_:
			_draw_here()


## This map in Star Atlas lines, its places, you, the people you know, and the events you know
## are coming today. Click a place to walk there.
func _draw_here() -> void:
	var when: String = "%s, %s" % [run.date_name(), run.time_name().to_lower()] if world.map_def().get("clock", true) else run.date_name()
	title(MAP_RECT.position + Vector2(20, 22), "%s  ·  %s" % [world.map_def().get("name", "Vellmar"), when], 15, GOLD)
	var xf := map_xf()
	var k := float(xf[1])
	var m = world.map
	var rect := func(r: Rect2) -> Rect2: return Rect2(to_map(r.position), r.size * k)
	var shade := {"cliff": Color(HAIR, 0.04), "wall": Color(HAIR, 0.5), "rubble": Color(PAPER, 0.2), "building": Color(PAPER, 0.14),
		"crack": Color(DANGER, 0.6)}
	for rr in m.rects:
		draw_rect(rect.call(rr[0]), shade.get(rr[1], Color(PAPER, 0.08)))
	for w: Rect2 in m.water:
		draw_rect(rect.call(w), Color(0.4, 0.6, 0.9, 0.45))
	for pit: Rect2 in m.pits:
		draw_rect(rect.call(pit), Color(0, 0, 0, 0.8))
		draw_rect(rect.call(pit), Color(HAIR, 0.3), false, 1.0)
	for c in m.circles:
		draw_circle(to_map(c[0]), float(c[1]) * k, Color(PAPER, 0.12))
	for did in m.doors:
		if not m.doors[did]["open"]:
			draw_rect(rect.call(m.doors[did]["rect"]), Color(GOLD, 0.6))
	for eid in m.exits:
		var er: Rect2 = rect.call(m.exits[eid]["rect"])
		draw_rect(er, Color(HOURS, 0.5), false, 1.0)
		star(er.get_center(), 4.0, HOURS)
	var mouse := get_local_mouse_position()
	var events: Array = story.known_events()
	for id in m.places:
		if id in ["streets", "college"]:
			continue
		var c: Vector2 = to_map(m.place_centre(id))
		var hot := c.distance_to(mouse) < 26.0
		star(c, 6.0 if hot else 4.0, GOLD if hot else Color(PAPER, 0.85))
		text(c + Vector2(-70, 18), m.place_name(id), 12, GOLD if hot else PAPER, HORIZONTAL_ALIGNMENT_CENTER, 140)
		var ky := c.y + 32
		for e in events:
			if id in str(e["where"]).split(", ") or _where_place(e["where"]) == id:
				text(Vector2(c.x - 80, ky), "%s: %s" % [str(e["time"]).capitalize(), e["title"]], 11, HOURS, HORIZONTAL_ALIGNMENT_CENTER, 160)
				ky += 13
		buttons.append({"r": Rect2(c - Vector2(30, 14), Vector2(60, 40)), "act": map_walk.bind(id), "key": 0})
	for p in world.people.list:
		var known_as: String = KNOWN_PEOPLE.get(p.id, "")
		if p.on and known_as != "" and run.knows(known_as):
			var c := to_map(p.pos)
			draw_circle(c, 3.0, HOURS)
			text(c + Vector2(5, 4), p.name, 10, Color(HOURS, 0.9))
	var you := to_map(world.player_pos())
	draw_circle(you, 4.5, Color(0.5, 0.75, 1.0))
	draw_arc(you, 7.5, 0, TAU, 16, Color(0.5, 0.75, 1.0, 0.6), 1.0)
	if not main.controls.route.is_empty():
		var prev := you
		for q in main.controls.route:
			draw_line(prev, to_map(q), Color(0.5, 0.75, 1.0, 0.5), 1.0)
			prev = to_map(q)
	text(Vector2(MAP_RECT.position.x, MAP_RECT.end.y - 10), "Click a place to walk there  ·  2 the Reach, 3 the calendar  ·  M or Esc closes", 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, MAP_RECT.size.x)


## The Reach (N-1.4): the regions as an engraved chart, roads with their day costs, unbuilt places
## as cards. Pick a region to see its card; travel asks once, naming the days and the arrival.
func _draw_reach() -> void:
	title(MAP_RECT.position + Vector2(20, 22), "The Reach  ·  %s, %s" % [run.date_name(), run.time_name().to_lower()], 15, GOLD)
	var chart := Rect2(MAP_RECT.position + Vector2(20, 36), Vector2(560, MAP_RECT.size.y - 60))
	var at := func(id: String) -> Vector2:
		var p: Array = reach.region(id)["pos"]
		return chart.position + Vector2(float(p[0]) * chart.size.x, float(p[1]) * chart.size.y)
	var here := region()
	for road in reach.d["roads"]:
		var a: Vector2 = at.call(road[0])
		var b: Vector2 = at.call(road[1])
		var lit: bool = reach.built(road[0]) and reach.built(road[1])
		draw_line(a, b, Color(HAIR, 0.5 if lit else 0.2), 1.0)
		text((a + b) * 0.5 + Vector2(-30, -4), "%d day%s" % [road[2], "" if int(road[2]) == 1 else "s"], 10, Color(HAIR, 0.7 if lit else 0.35), HORIZONTAL_ALIGNMENT_CENTER, 60)
	var mouse := get_local_mouse_position()
	for id in reach.regions():
		var g: Dictionary = reach.region(id)
		var c: Vector2 = at.call(id)
		var hot: bool = c.distance_to(mouse) < 22.0 or id == reach_pick
		var col: Color = GOLD if reach.built(id) else Color(PAPER, 0.45)
		if hot:
			col = GOLD
		star(c, 7.0 if id == here else (5.5 if hot else 4.0), col)
		if id == here:
			draw_arc(c, 11.0, 0, TAU, 20, Color(0.5, 0.75, 1.0, 0.8), 1.5)
		text(c + Vector2(-80, 20), str(g["name"]), 11, col, HORIZONTAL_ALIGNMENT_CENTER, 160)
		if int(g.get("ring", 1)) > 1:
			text(c + Vector2(-80, 33), "Ring %d" % int(g["ring"]), 10, DIM, HORIZONTAL_ALIGNMENT_CENTER, 160)
		buttons.append({"r": Rect2(c - Vector2(24, 18), Vector2(48, 44)), "act": func(): reach_pick = id, "key": 0})
	# the card of the region picked
	var card := Rect2(MAP_RECT.position.x + 600, MAP_RECT.position.y + 40, 260, MAP_RECT.size.y - 70)
	draw_rect(card, Color(0, 0, 0, 0.35))
	draw_rect(card, Color(GOLD, 0.35), false, 1.0)
	var pick := reach_pick if reach_pick != "" else here
	var g: Dictionary = reach.region(pick)
	if g.is_empty():
		return
	var y := para(card.position + Vector2(16, 28), str(g["name"]), card.size.x - 32, 16, GOLD) + 8.0
	y = para(Vector2(card.position.x + 16, y), str(g.get("blurb", "")), card.size.x - 32, 13, PAPER) + 12.0
	var days: int = reach.days_between(here, pick)
	if pick == here:
		text(Vector2(card.position.x + 16, y), "You are here.", 13, Color(0.5, 0.75, 1.0))
	elif not reach.built(pick):
		text(Vector2(card.position.x + 16, y), "Not built yet. Going costs no time.", 13, DIM)
	elif days < 0:
		text(Vector2(card.position.x + 16, y), "No road leads there yet.", 13, DIM)
	else:
		var arrive: int = mini(run.day() + days, run.LAST_DAY)
		y = para(Vector2(card.position.x + 16, y), "%d day%s on the road. Arrive %s, Morning." % [days, "" if days == 1 else "s", run.date_name(arrive)],
			card.size.x - 32, 13, PAPER) + 10.0
		var why := _cant_go()
		if why != "":
			text(Vector2(card.position.x + 16, y + 4), why, 12, DANGER)
		else:
			button(Rect2(card.position.x + 16, y, card.size.x - 32, 30), "Go to %s" % str(g["name"]).trim_prefix("The "), travel.bind(pick), 0, 13)
	text(Vector2(MAP_RECT.position.x, MAP_RECT.end.y - 10), "Click a region for its card  ·  Walking inside a region is free; roads cost days", 12, DIM,
		HORIZONTAL_ALIGNMENT_CENTER, MAP_RECT.size.x)


## The calendar (N-1.1): the year's 13 moons, this moon's four weeks by their weekday Spheres,
## the dates you know, and Rest until… for the next of them.
func _draw_calendar() -> void:
	title(MAP_RECT.position + Vector2(20, 22), "%s  ·  %s  ·  %s, %s" % [run.moon_name(), run.cal["moons"][run.moon() - 1]["season"], run.date_name(),
		run.weekday()["name"]], 15, GOLD)
	var events: Array = reach.events()
	var known_on := {}
	for e in events:
		if e["known"]:
			known_on[int(e["day"])] = e
	# the year: one row of moons
	var x0 := MAP_RECT.position.x + 30.0
	for m in run.MOONS:
		var c := Vector2(x0 + 22 + m * 62.0, MAP_RECT.position.y + 62)
		var now: bool = m + 1 == run.moon()
		var past: bool = m + 1 < run.moon()
		draw_circle(c, 9.0, Color("dfe4f2", 0.75 if now else (0.18 if past else 0.4)))
		if now:
			draw_arc(c, 13.0, 0, TAU, 24, HAIR, 1.0)
		for e in events:
			if e["known"] and (int(e["day"]) - 1) / run.MOON_DAYS == m:
				draw_circle(c + Vector2(8, -8), 4.0, Color(0, 0, 0))
				draw_arc(c + Vector2(8, -8), 4.5, 0, TAU, 12, Color(GOLD, 0.8), 1.0)
		text(c + Vector2(-31, 26), run.moon_name(m + 1), 10, GOLD if now else DIM, HORIZONTAL_ALIGNMENT_CENTER, 62)
	# this moon: four weeks of seven days
	var gx := MAP_RECT.position.x + 40.0
	var gy := MAP_RECT.position.y + 120.0
	for wd in 7:
		var w: Dictionary = run.weekday(wd + 1)
		text(Vector2(gx + wd * 62.0, gy), str(w["sphere"]).capitalize(), 11, Color(w["color"]), HORIZONTAL_ALIGNMENT_CENTER, 58)
	var first: int = run.day_of(run.moon(), 1)
	for i in run.MOON_DAYS:
		var d: int = first + i
		var cell := Rect2(gx + (i % 7) * 62.0, gy + 10 + (i / 7) * 52.0, 58, 46)
		var w: Dictionary = run.weekday(d)
		draw_rect(cell, Color(Color(w["color"]), 0.12 if d == run.day() else 0.04))
		draw_rect(cell, Color(HAIR, 0.8 if d == run.day() else 0.18), false, 1.0)
		text(cell.position + Vector2(6, 15), str(i + 1), 12, PAPER if d >= run.day() else DIM)
		if known_on.has(d):
			draw_circle(cell.position + Vector2(44, 12), 5.0, Color(0, 0, 0))
			draw_arc(cell.position + Vector2(44, 12), 5.5, 0, TAU, 14, GOLD, 1.0)
			para(cell.position + Vector2(4, 30), str(known_on[d]["name"]), 54, 9, GOLD)
	# Rest until…
	var rx := MAP_RECT.position.x + 490.0
	var ry := gy
	title(Vector2(rx, ry + 4), "Rest until…", 15, GOLD)
	ry += 16.0
	var can: bool = _cant_go() == "" and region() == reach.d["start"]
	for t in reach.rest_targets().slice(0, 5):
		var n: int = int(t["day"]) - run.day()
		var label := "%s  ·  %s  (%d day%s)" % [t["name"], run.date_name(int(t["day"])), n, "" if n == 1 else "s"]
		button(Rect2(rx, ry, 360, 28), label, rest_until.bind(int(t["day"])), 0, 12, can)
		ry += 34.0
	text(Vector2(rx, ry + 12), "%d days to the Great Eclipse." % run.days_left(), 13, PAPER)
	if not can:
		text(Vector2(rx, ry + 32), "You can rest that long only in the camp, with nothing hunting you.", 12, DIM)
	text(Vector2(MAP_RECT.position.x, MAP_RECT.end.y - 10), "Only actions cost time: waiting (Z), training, meditating, sleeping, the road", 12, DIM,
		HORIZONTAL_ALIGNMENT_CENTER, MAP_RECT.size.x)


## Which place an event's person or item belongs to, for the map.
func _where_place(where: String) -> String:
	if world.map.items.has(where):
		return world.map.place_at(world.map.items[where]["at"])
	var p = world.people.get_person(where)
	return world.map.place_at(p.pos) if p != null else ""


## The spellbook, opened from your desk: pick a slot, then a Model you know. Slots open with
## each Ring; a spell's tier needs a Ring too (controls the 1st, signatures the 4th).
func _draw_book() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.6))
	var r := Rect2(130, 84, 700, 380)
	draw_rect(r, NIGHT)
	panel(r, Color(GOLD, 0.6))
	title(r.position + Vector2(40, 40), "Your spellbook", 22, GOLD)
	var at := Vector2(r.position.x + 40, r.position.y + 70)
	var line := "%s  ·  %d wells  ·  Vitality %d  ·  Aether %d" % [growth.ring_name(), growth.wells(), int(growth.max_hp()), int(growth.max_aether())]
	title(at, line, 15, HAIR)
	var next := "The yard trial opens the 1st Ring." if growth.ring() == 0 else ""
	if growth.wells_to_next() > 0:
		next = "%d more wells for the %s." % [growth.wells_to_next(), growth.ring_name(growth.ring() + 1)]
	var bits: Array = []
	if growth.best_wells() > growth.wells():
		bits.append("wells regrow ×%d up to %d" % [int(growth.d["echo_mult"]), growth.best_wells()])
	if not growth.echo().is_empty():
		bits.append("Practice regrows ×%d up to your best" % int(growth.d["echo_mult"]))
	if growth.fluency() > 0.0:
		bits.append("insight +%d%%" % roundi(growth.fluency() * 100.0))
	if not bits.is_empty():
		next += ("  " if next != "" else "") + "Echo: " + ", ".join(bits) + "."
	text(at + Vector2(0, 24), next, 13, DIM)
	at += Vector2(0, 58)
	title(at, "Spellbook", 15, PAPER)
	text(at + Vector2(96, 0), "pick a slot, then a spell", 12, DIM)
	var book: Array = growth.book()
	for i in growth.prog.BOOK_SIZE:
		var rr := Rect2(at + Vector2(i * 104, 14), Vector2(98, 46))
		var open: bool = i < growth.slots()
		var id: String = growth.slot_spell(i)
		var border := Color(GOLD, 0.9) if open and i == book_slot else Color(HAIR, 0.45 if open else 0.15)
		panel(rr, border)
		if open:
			var nm: String = growth.prog.spell(book[i])["name"] if id != "" else "(empty)"
			text(rr.position + Vector2(0, 20), nm, 13, PAPER, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			if id != "":
				text(rr.position + Vector2(0, 38), "Practice %d" % growth.level(id), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			buttons.append({"r": rr, "act": _pick_slot.bind(i), "key": i + 1})
		else:
			text(rr.position + Vector2(0, 28), _slot_ring(i), 12, Color(PAPER, 0.35), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	title(at + Vector2(0, 86), "Models you know", 15, PAPER)
	var models: Array = growth.known_models()
	for j in models.size():
		var id: String = models[j]
		var rr := Rect2(at + Vector2((j % 6) * 104, 98 + (j / 6) * 34), Vector2(98, 28))
		var ok: bool = growth.can_cast(id)
		var label: String = growth.prog.spell(id)["name"]
		if not ok:
			label += "  (%s)" % growth.ring_name(growth.tier_ring(id)).trim_suffix(" Ring")
		button(rr, label, _put_model.bind(id), 0, 12, ok and book_slot < growth.slots())
	button(Rect2(r.position.x + r.size.x / 2.0 - 80, r.end.y - 48, 160, 32), "Close  (Space)", func(): overlay = "", 0, 14)


func _draw_death() -> void:
	var r := Rect2(220, 70, 520, 400)
	panel(r, Color(HOURS, 0.6))
	var log: Dictionary = run.past_lives()[-1] if not run.past_lives().is_empty() else {}
	var cause: String = str(log.get("cause", ""))
	var why: String = death_texts.get(cause, death_texts.get(cause.split(":")[0], "The month ends."))
	var the_end := cause == "first_playable_end"
	title(r.position + Vector2(0, 46), "The end of the first playable" if the_end else "Loop %d ends" % run.loop(), 28,
		GOLD if the_end else HOURS, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(r.position + Vector2(0, 76), why if the_end else "%s, %s.  %s" % [run.date_name(), run.time_name().to_lower(), why], 14, PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	title(r.position + Vector2(32, 120), "What you learned this loop", 15, GOLD)
	var y := r.position.y + 146.0
	var learned: Array = run.life["learned"].filter(func(id): return ledger.has(id) and ledger[id]["kind"] != "trial")
	if learned.is_empty():
		text(Vector2(r.position.x + 32, y), "Nothing new. But nothing you know is ever lost.", 14, DIM)
	for id in learned.slice(0, 11):
		star(Vector2(r.position.x + 38, y - 5), 4.0, GOLD)
		var label: String = ledger[id]["title"]
		if ledger[id]["kind"] == "question":
			label = "A question: " + label
		text(Vector2(r.position.x + 50, y), label, 14, PAPER, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80)
		y += 20.0
	if learned.size() > 11:
		text(Vector2(r.position.x + 50, y), "and %d more, in the Ledger" % (learned.size() - 11), 13, DIM)
	text(Vector2(0, r.end.y - 52), "Your body and your skill reset. Everything you know stays.", 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960 - 0.0)
	button(Rect2(r.position.x + 170, r.end.y - 42, 180, 32), "Wake", wake, 1, 15)
	button(Rect2(24, 500, 120, 28), "Ledger  (L)", toggle_ledger, 0, 13)
	_draw_playtest_buttons()


## A lost fight that doesn't end the life (lives spec §3.2): what happened, what you learned, and
## the days that pass before you wake on your cot, Injured.
func _draw_hurt() -> void:
	var r := Rect2(220, 70, 520, 400)
	panel(r, Color(DANGER, 0.5))
	var loss: Dictionary = run.life["losses"][-1] if not run.life["losses"].is_empty() else {}
	var cause: String = str(loss.get("cause", ""))
	var why: String = death_texts.get(cause, death_texts.get(cause.split(":")[0], "You go down."))
	title(r.position + Vector2(0, 46), "You go down", 28, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	para(r.position + Vector2(40, 76), "%s, %s.  %s" % [run.date_name(), run.time_name().to_lower(), why], r.size.x - 80, 14, PAPER)
	title(r.position + Vector2(32, 150), "What you learned", 15, GOLD)
	var y := r.position.y + 176.0
	var losses: Array = run.life["losses"]
	var from: int = int(losses[-2]["learned"]) if losses.size() > 1 else 0
	var learned: Array = run.life["learned"].slice(from).filter(func(id): return ledger.has(id) and ledger[id]["kind"] != "trial")
	if learned.is_empty():
		text(Vector2(r.position.x + 32, y), "Nothing new this time.", 14, DIM)
	for id in learned.slice(0, 8):
		star(Vector2(r.position.x + 38, y - 5), 4.0, GOLD)
		text(Vector2(r.position.x + 50, y), ledger[id]["title"], 14, PAPER, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80)
		y += 20.0
	var days: int = int(loss.get("days", 0))
	var wake_line := "Someone carries you back to camp. %d days pass; you wake on your cot, Injured until you next sleep a full night." % days
	if days == 0:
		wake_line = "You come round on your cot the same day, still Injured."
	para(Vector2(r.position.x + 40, r.end.y - 92), wake_line, r.size.x - 80, 13, DIM)
	button(Rect2(r.position.x + 170, r.end.y - 42, 180, 32), "Wake", wake, 1, 15)
	button(Rect2(24, 500, 120, 28), "Ledger  (L)", toggle_ledger, 0, 13)
	_draw_playtest_buttons()


## The loading card between maps: the map's name over a ring of the Orrery's seven planets,
## one lit after another while the new map's shaders compile behind it.
func _draw_loading() -> void:
	var c := Vector2(480, 250)
	var name: String = str(world.map_def().get("name", ""))
	var t: float = float(load_to.get("t", 0.0))
	draw_arc(c, 64.0, 0, TAU, 48, Color(HAIR, 0.35), 1.0)
	draw_arc(c, 40.0, 0, TAU, 40, Color(HAIR, 0.2), 1.0)
	for i in 7:
		var a := -PI / 2.0 + i * TAU / 7.0
		var on := t * 7.0 / LOAD_MIN_S > i
		star(c + Vector2(cos(a), sin(a)) * 64.0, 5.0 if on else 3.0, GOLD if on else Color(HAIR, 0.5))
	star(c, 7.0, HOURS)
	title(Vector2(0, c.y + 112), name, 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var sub := "Down into the dark." if world.map.kit == "ruin" else "Up into the grey light, and the camp."
	text(Vector2(0, c.y + 140), sub, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_ledger() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.7))
	var r := Rect2(90, 50, 780, 450)
	draw_rect(r, NIGHT)
	panel(r, Color(GOLD, 0.7))
	title(r.position + Vector2(28, 36), "The Ledger", 24, GOLD)
	var x := r.position.x + 220.0
	for i in LEDGER_TABS.size():
		var tr := Rect2(x, r.position.y + 14, 116, 28)
		var on := i == ledger_tab
		draw_rect(tr, Color(GOLD, 0.25) if on else Color(0, 0, 0, 0.3))
		draw_rect(tr, Color(GOLD, 0.8 if on else 0.3), false, 1.0)
		text(tr.position + Vector2(10, 19), "%d  %s" % [i + 1, LEDGER_TABS[i]], 13, GOLD if on else PAPER)
		buttons.append({"r": tr, "act": func(): ledger_tab = i, "key": 0})
		x += 124.0
	var y := r.position.y + 76.0
	var w := r.size.x - 56.0
	match ledger_tab:
		0:
			_draw_questions(r)
		1, 2, 3:
			var kinds: Array = [["clue"], ["person"], ["insight", "model"]][ledger_tab - 1]
			var ids: Array = []
			for kd in kinds:
				ids.append_array(entries_of(kd))
			for id in ids:
				var e: Dictionary = ledger[id]
				text(Vector2(r.position.x + 28, y), e["title"], 14, GOLD)
				y = para(Vector2(r.position.x + 250, y), e["text"], w - 230, 12, Color(PAPER, 0.85), 1.2) + 4.0
				if y > r.end.y - 30:
					text(Vector2(r.position.x + 28, r.end.y - 14), "…", 13, DIM)
					break
	if run.known_ids().is_empty():
		text(Vector2(r.position.x + 28, y), "Nothing yet.", 14, DIM)
	button(Rect2(r.end.x - 120, r.end.y - 36, 100, 26), "Close  (L)", toggle_ledger, 0, 13)


## The Questions tab: questions down the left; the one picked shows its clues on the right, and,
## for a deduction whose clues are all in, the answers to choose from.
func _draw_questions(r: Rect2) -> void:
	var qs := entries_of("question")
	if qs.is_empty():
		return
	if not ledger_q in qs:
		ledger_q = qs[0]
	var y := r.position.y + 76.0
	var mouse := get_local_mouse_position()
	for qid in qs:
		var row := Rect2(r.position.x + 20, y - 17, 330, 24)
		var on: bool = qid == ledger_q
		if on or row.has_point(mouse):
			draw_rect(row, Color(GOLD, 0.18 if on else 0.08))
		var col := Color(GOLD, 0.95) if solved(qid) else PAPER
		if deduction_ready(qid):
			star(Vector2(row.position.x + 8, y - 5), 4.0, HOURS)
		text(Vector2(row.position.x + 20, y), ledger[qid]["title"], 14, col, HORIZONTAL_ALIGNMENT_LEFT, 300)
		buttons.append({"r": row, "act": _pick_question.bind(qid), "key": 0})
		y += 26.0
		if y > r.end.y - 20:
			break
	# The picked question.
	var q: Dictionary = ledger[ledger_q]
	var x := r.position.x + 372.0
	var w := r.end.x - 28.0 - x
	draw_line(Vector2(x - 12, r.position.y + 62), Vector2(x - 12, r.end.y - 48), Color(HAIR, 0.3), 1.0)
	y = para(Vector2(x, r.position.y + 80), q["title"], w, 17, GOLD) + 4.0
	var clues: Array = q.get("clues", [])
	var missing := 0
	for c in clues:
		if run.knows(c):
			star(Vector2(x + 4, y - 5), 3.5, GOLD)
			y = para(Vector2(x + 16, y), ledger[c]["title"], w - 16, 13, PAPER, 1.2) + 2.0
		else:
			missing += 1
	if missing > 0:
		text(Vector2(x + 16, y), "%d more to find" % missing if not solved(ledger_q) else "", 12, DIM)
		y += 18.0
	y += 8.0
	if solved(ledger_q):
		var ans: Dictionary = ledger.get(q.get("insight", q.get("closes", "")), {})
		text(Vector2(x, y), "Answered", 13, HOURS)
		para(Vector2(x, y + 20), "%s. %s" % [ans.get("title", ""), ans.get("text", "")], w, 13, PAPER, 1.2)
	elif deduction_ready(ledger_q):
		text(Vector2(x, y), "You have enough to work it out:", 13, HOURS)
		y += 12.0
		if ledger_note != "":
			y = para(Vector2(x, y + 8), ledger_note, w, 12, DANGER, 1.2)
		var opts_q: Array = q["options"]
		for i in opts_q.size():
			button(Rect2(x, y, w, 28), opts_q[i], deduce.bind(ledger_q, i), 0, 13)
			y += 32.0
	elif q.has("options"):
		text(Vector2(x, y), "Find more before you can work this out.", 12, DIM)
	else:
		text(Vector2(x, y), "Still open.", 12, DIM)


func _pick_question(qid: String) -> void:
	ledger_q = qid
	ledger_note = ""


func solved(qid: String) -> bool:
	var q: Dictionary = ledger[qid]
	return q.has("insight") and run.knows(q["insight"]) or q.has("closes") and run.knows(q["closes"])


## A deduction whose needed clues are all known and which isn't answered yet.
func deduction_ready(qid: String) -> bool:
	var q: Dictionary = ledger[qid]
	if not q.has("options") or solved(qid):
		return false
	return q.get("needs", []).all(func(c): return run.knows(c))


## Picks answer `i` to deduction `qid`: the right one becomes an insight; a wrong one costs nothing.
func deduce(qid: String, i: int) -> bool:
	if not deduction_ready(qid):
		return false
	if i == int(ledger[qid]["answer"]):
		run.learn(ledger[qid]["insight"])
		ledger_note = ""
		return true
	ledger_note = "That doesn't fit everything you know. Nothing is lost; think again."
	return false


## New Ledger entries and the like, in a column down the right-hand side.
func _draw_toasts() -> void:
	var y := 96.0
	for t in toasts:
		var a := clampf(4.0 - float(t["t"]), 0.0, 1.0)
		var rows: Array = wrap_text(t["text"], 196.0, 13)
		var r := Rect2(700, y, 236, 10 + rows.size() * 17)
		draw_rect(r, Color(0.03, 0.05, 0.1, 0.9 * a))
		draw_rect(r, Color(GOLD, 0.5 * a), false, 1.0)
		star(r.position + Vector2(12, 14), 3.5, Color(GOLD, a))
		for i in rows.size():
			text(r.position + Vector2(24, 18 + i * 17), rows[i], 13, Color(PAPER, a))
		y += r.size.y + 6.0
