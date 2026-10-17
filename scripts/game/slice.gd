extends "res://scripts/ui/atlas.gd"
## The vertical slice's game flow (design/slice/tech-plan.md §3): the title card, each dawn, the
## day board, story scenes, fights (handed to the arena through main.gd), the death screen, the
## Ledger and the end of the slice. Story content lives in data/slice/story/*.story and is run by
## scripts/game/story.gd; what you remember and what resets are in the Run autoload.
##
## Everything a player can do here is also a method (pick_place, choose, advance...), so the route
## bot in tools/tests/route.gd plays the same code.

signal screen_changed(screen: String)

const Story := preload("res://scripts/game/story.gd")
const Growth := preload("res://scripts/game/growth.gd")
const BuildId := preload("res://scripts/game/build_id.gd")
## Where playtesters send their notes (design/slice/README.md §5, M5).
const FEEDBACK_URL := "https://claude.ai/artifact/HryjwPHEs8S6swcQYFam6c"
const Backdrop := preload("res://scripts/ui/backdrop.gd")
## First-loop hints (onboarding), one per screen, shown until you leave that screen once.
const HINTS := {
	"dawn": "Each dawn you can change your spellbook. Higher Rings open more slots.",
	"board": "Pick where to be for this time of day. Gold notes mark events you know are coming. Night is optional; Sleep ends the day.",
	"scene": "Number keys or a click pick a choice; Space carries on. L opens the Ledger at any time.",
	"death": "Death resets your power, never what you know. Everything in the Ledger comes with you.",
}
const SLOT_NAMES := ["1", "2", "3", "4", "5", "6"]
const LEDGER_TABS := ["Questions", "Clues", "People", "Insights"]

var main  # scripts/main.gd: runs the fights
var run  # the Run autoload
var story
var growth  # scripts/game/growth.gd: wells, Rings, Practice, the spellbook
var dawn_slot := 0  # the spellbook slot picked on the dawn card
var backdrop := Backdrop.new()
var here := ""  # the place picked on the board, for the backdrop of what plays there
var scene_t := 0.0  # seconds on this screen, for the backdrops' slow movement
var fps_t := 0.0  # time since the last frame-rate sample in a fight
var places: Dictionary = {}
var links: Array = []
var encounters: Dictionary = {}
var ledger: Dictionary = {}  # data/slice/ledger.json "entries"
var death_texts: Dictionary = {}

var screen := "title"  # title, dawn, board, scene, fight, death, end
var ledger_open := false
var ledger_tab := 0
var ledger_q := ""  # the question picked in the Questions tab
var ledger_note := ""  # feedback on a wrong deduction, shown in the Ledger
var toasts: Array = []  # {"text", "t"}

# The scene being played.
var cur: Dictionary = {}
var idx := 0
var lines: Array = []  # [{"who", "text"}] shown on the page
var pending := {}  # a blocking effect waiting for the player: {"op", "arg"}
var opts: Array = []  # the choices on the page
var uses_slot := true  # whether the pick that started this chain uses up the time of day
var fight_id := ""

## Tests set this to settle fights without playing them: func(encounter_id) -> bool (won), or
## -> {"won", "kills"}.
var fight_resolver: Callable


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	run = get_node("/root/Run")
	story = Story.new(run)
	growth = Growth.new(run, get_node("/root/Progression"))
	story.ctx.growth = growth
	story.load_all()
	for e in story.errors:
		push_error("story: " + str(e))
	var pd = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/places.json"))
	places = pd["places"]
	links = pd["links"]
	encounters = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/encounters.json"))["encounters"]
	var ld = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/ledger.json"))
	ledger = ld["entries"]
	death_texts = ld["deaths"]
	run.learned.connect(_on_learned)


func set_screen(s: String) -> void:
	if s in ["board", "death", "end"]:
		toasts.clear()  # those screens show what was learnt in their own way
	if s == "dawn" and screen != "dawn":
		Sfx.play("chime")
	if s != screen:
		scene_t = 0.0
		if hint_for(screen) != "":
			run.mem["hints"][screen] = true  # seen once is enough
	Sfx.ambience(s in ["board", "scene", "dawn"])
	screen = s
	visible = s != "fight"
	screen_changed.emit(s)


# --- flow ------------------------------------------------------------------------

func new_month() -> void:
	run.wipe()
	run.save()
	begin_day()


func continue_month() -> void:
	run.load_save()
	begin_day()


## The start of a day: the end-of-slice card if it is due, otherwise the dawn card.
func begin_day() -> void:
	here = "room"  # you wake in your room
	run.lp["time"] = 0
	run.save()
	if run.knows("long_night") and not run.mem.get("slice_end_shown", false):
		set_screen("end")
		return
	set_screen("dawn")


## From the dawn card into the day.
func start_day() -> void:
	run.lp["dawn_done"] = true
	next_slot()


## The board for this time of day, unless something happens wherever you are.
func next_slot() -> void:
	var f: String = story.forced()
	if f != "":
		uses_slot = cur_slot_used(f)
		play(f)
		return
	set_screen("board")


func cur_slot_used(id: String) -> bool:
	return story.scenes[id].get("slot", "") != "free"


## Go to a place on the board.
func pick_place(id: String) -> void:
	if screen != "board":
		return
	var ev: String = story.event_at(id)
	if ev == "":
		ev = places[id]["idle"]
	uses_slot = cur_slot_used(ev)
	here = id
	Sfx.play("step")
	play(ev)


## Skip the rest of the day.
func sleep() -> void:
	if screen != "board":
		return
	end_day()


func end_day() -> void:
	if run.day() >= run.LAST_DAY:
		end_loop("eclipse_alone")
		return
	run.next_day()
	begin_day()


## Plays scene `id` from its first step. `append` keeps the lines already on the page.
func play(id: String, append := false) -> void:
	if not story.scenes.has(id):
		push_error("no scene " + id)
		finish_pick()
		return
	cur = story.scenes[id]
	if cur.get("backdrop", "") != "":
		here = cur["backdrop"]
	elif cur.get("places", []).size() == 1 and places.has(cur["places"][0]):
		here = cur["places"][0]
	idx = 0
	pending = {}
	opts = []
	if not append:
		lines = []
	run.mark_seen(id)
	set_screen("scene")
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
		opts = [{"text": "Continue", "target": ""}]


## Applies one effect. Returns true when the scene must stop here (a fight, a jump, an ending).
func _effect(op: String, arg: String) -> bool:
	match op:
		"learn":
			run.learn(arg)
		"set":
			var r: int = growth.ring()
			if arg.begins_with("topic_") and not run.flag(arg):
				Sfx.play("hiss")  # another topic in the censer
			run.set_flag(arg)
			_ring_toast(r)  # the yard trial sets "ring1"
		"clear":
			run.clear_flag(arg)
		"model":
			run.learn("model_" + arg)
		"trial":
			run.learn("trial_" + arg)
		"sound":
			Sfx.play(arg)
		"cutscene":
			if fight_resolver.is_valid() or main == null:
				return false  # tests skip the pictures
			set_screen("fight")
			main.start_cutscene(arg)
			return true
		"wells", "meditate":
			if growth.use_today(op):
				gain_wells(int(arg))
			else:
				toast("You've already meditated today. It doesn't come twice.")
		"train":
			if growth.use_today(op):
				var got: Dictionary = growth.train()
				var parts: Array = []
				for id in got:
					parts.append("%s %d" % [growth.prog.spell(id)["name"], growth.level(id)])
				toast("Practice: " + ", ".join(parts))
			else:
				toast("Your hands are done for today.")
		"goto":
			if lines.is_empty():
				play(arg, true)
			else:
				pending = {"op": "goto", "arg": arg}
			return true
		"fight", "end_loop", "skip_to":
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


## Names a new Ring and the slots it opens.
func _ring_toast(before: int) -> void:
	if growth.ring() > before:
		toast("The %s: %d spellbook slots" % [growth.ring_name(), growth.slots()])


## The button under the page when a blocking effect is waiting.
func pending_label() -> String:
	match pending.get("op", ""):
		"fight":
			return "Fight"
		"end_loop":
			return "…"
	return "Continue"


## Space, Enter or the single button: carry on past a blocking effect.
func advance() -> void:
	if screen != "scene":
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
			"skip_to":
				var parts: Array = str(p["arg"]).split(" ")
				var t := 0
				if parts.size() > 1:
					t = maxi(0, run.TIMES.find(parts[1]))
				run.skip_to(int(parts[0]), t)
				run.save()
				next_slot()
		return
	if opts.size() == 1:
		choose(0)


func choose(i: int) -> void:
	if screen != "scene" or not pending.is_empty() or i < 0 or i >= opts.size():
		return
	var c: Dictionary = opts[i]
	Sfx.play("page")
	if c.get("target", "") != "":
		play(c["target"])
	else:
		finish_pick()


## The scene chain is over: use up the time of day (unless it was free) and move on.
func finish_pick() -> void:
	cur = {}
	if uses_slot and not run.advance_time():
		end_day()
		return
	uses_slot = true
	next_slot()


func _start_fight(id: String) -> void:
	fight_id = id
	var enc: Dictionary = encounters[id].duplicate(true)
	if enc.has("waived") and run.knows("trial_" + id.trim_suffix("_trial")):
		enc["waves"] = enc["waived"]
	if id == "mill_risen" and run.knows("millrace"):
		enc["millrace"] = true
	if fight_resolver.is_valid():
		var r = fight_resolver.call(id)  # won, or {"won", "kills"}
		if r is Dictionary:
			fight_done(bool(r["won"]), int(r.get("kills", 0)))
		else:
			fight_done(bool(r))
		return
	set_screen("fight")
	main.start_slice_fight(enc)


## Called by main.gd when a cutscene is over: the scene carries on from where it stopped.
func cutscene_done() -> void:
	set_screen("scene")
	_run_steps()


## Called by main.gd when a fight started here is over.
func fight_done(won: bool, kills := 0) -> void:
	set_screen("scene")
	if kills > 0:
		gain_wells(kills * int(growth.d["wells"]["kill"]))
	var outs: Dictionary = cur.get("outcomes", {})
	var key := "won" if won else "lost"
	if outs.has(key):
		play(outs[key])
		return
	if not won and bool(encounters[fight_id].get("lethal", true)):
		lines = []
		end_loop("fight:" + fight_id)
		return
	_run_steps()


func end_loop(cause: String) -> void:
	Sfx.play("death")
	growth.loop_over()
	run.end_loop(cause)
	cur = {}
	pending = {}
	set_screen("death")


## From the death screen: wake on day 1 of the next loop.
func wake() -> void:
	if screen != "death":
		return
	run.wake()
	begin_day()


## From the end-of-slice card: keep playing loops.
func keep_playing() -> void:
	run.mem["slice_end_shown"] = true
	run.save()
	set_screen("dawn")


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
	if screen in ["board", "scene", "dawn", "death"]:
		ledger_open = not ledger_open


# --- input -------------------------------------------------------------------------

func _process(dt: float) -> void:
	scene_t += dt
	_track_play(dt)
	for t in toasts.duplicate():
		t["t"] += dt
		if t["t"] > 4.0:
			toasts.erase(t)
	if visible:
		queue_redraw()


# --- playtest ------------------------------------------------------------------------

## Counts real time played and, once a second in a fight, the frame rate, for the run summary.
func _track_play(dt: float) -> void:
	if screen == "title" or main == null or main.bot.is_valid() or fight_resolver.is_valid():
		return
	run.mem["play_s"] = float(run.mem.get("play_s", 0.0)) + dt
	if screen != "fight":
		return
	fps_t += dt
	if fps_t >= 1.0:
		fps_t = 0.0
		var f: Dictionary = run.mem["fps"]
		var now := int(Engine.get_frames_per_second())
		f["sum"] = float(f["sum"]) + now
		f["n"] = int(f["n"]) + 1
		f["min"] = now if int(f["n"]) == 1 else mini(int(f["min"]), now)


## A plain-text report of this month for the feedback form.
func run_summary() -> String:
	var out: Array = ["Vellmar slice · build %s · %s" % [BuildId.ID, OS.get_name()]]
	out.append("Played %d min · loop %d, day %d, %s · %s, %d wells" % [roundi(float(run.mem.get("play_s", 0.0)) / 60.0),
		run.loop(), run.day(), run.time_name().to_lower(), growth.ring_name(), growth.wells()])
	var known: Array = run.known_ids().filter(func(id): return ledger.has(id) and ledger[id]["kind"] != "trial")
	var qs: Array = ledger.keys().filter(func(id): return ledger[id]["kind"] == "question")
	out.append("Ledger: %d entries · questions answered %d of %d" % [known.size(), qs.filter(func(q): return solved(q)).size(), qs.size()])
	var reached: Array = []
	for f in ["ring1", "wren_friend", "door_barred", "survived_day7"]:
		if run.flag(f):
			reached.append(f)
	if run.knows("long_night"):
		reached.append("long_night")
	if run.mem.get("slice_end_shown", false):
		reached.append("slice_end")
	out.append("This loop / ever: " + (", ".join(reached) if not reached.is_empty() else "nothing yet"))
	for d in run.mem["log"]:
		out.append("Loop %d died on day %d, %s: %s (%d learned)" % [d["loop"], d["day"], str(d["time"]).to_lower(), d["cause"], d["learned"].size()])
	var f: Dictionary = run.mem.get("fps", {})
	if int(f.get("n", 0)) > 0:
		out.append("Fights: %d fps on average, %d at worst · graphics %s%s" % [roundi(float(f["sum"]) / int(f["n"])), int(f["min"]),
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
	if not visible or main == null or main.bot.is_valid():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if k == KEY_L:
			toggle_ledger()
		elif k == KEY_M:
			Sfx.muted = not Sfx.muted
			Sfx.ambience(not Sfx.muted and screen in ["board", "scene", "dawn"])
			toast("Sound off (M)" if Sfx.muted else "Sound on (M)")
		elif ledger_open and k == KEY_ESCAPE:
			ledger_open = false
		elif ledger_open and k >= KEY_1 and k <= KEY_4:
			ledger_tab = k - KEY_1
		elif k >= KEY_1 and k <= KEY_9:
			press_key(k - KEY_0)
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			match screen:
				"scene":
					advance()
				"dawn":
					start_day()
				"death":
					wake()
				"end":
					keep_playing()
				"title":
					if run.has_save():
						continue_month()
					else:
						new_month()
		else:
			return
		get_viewport().set_input_as_handled()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if click(ev.position):
			accept_event()


# --- drawing -------------------------------------------------------------------------

func _draw() -> void:
	begin_buttons()
	draw_rect(Rect2(0, 0, 960, 540), NIGHT)
	match screen:
		"title":
			_draw_title()
		"dawn":
			_draw_dawn()
		"board":
			_draw_board()
		"scene":
			_draw_scene()
		"death":
			_draw_death()
		"end":
			_draw_end()
	if ledger_open:
		begin_buttons()
		_draw_ledger()
	else:
		_draw_hint()
		_draw_toasts()
	end_buttons()


## This screen's first-loop hint, or "" once it has been seen.
func hint_for(s: String) -> String:
	if not HINTS.has(s) or run.loop() > 1 and s != "death":
		return ""
	if not run.mem.has("hints"):
		run.mem["hints"] = {}
	return "" if run.mem["hints"].has(s) else HINTS[s]


func _draw_hint() -> void:
	var h := hint_for(screen)
	if h == "":
		return
	var rows: Array = wrap_text(h, 560.0, 13)
	var r := Rect2(190, 502 - (rows.size() - 1) * 17, 580, 14 + rows.size() * 17)
	if screen == "scene":
		r.position = Vector2(700, 300)
		r.size.x = 236
		rows = wrap_text(h, 200.0, 13)
		r.size.y = 14 + rows.size() * 17
	draw_rect(r, Color(0.02, 0.03, 0.07, 0.94))
	draw_rect(r, Color(HOURS, 0.6), false, 1.0)
	for i in rows.size():
		text(r.position + Vector2(14, 20 + i * 17), rows[i], 13, Color(HOURS, 0.95))


func _header() -> void:
	moons(Vector2(480, 26), run.day())
	title(Vector2(24, 60), "Loop %d  ·  Day %d" % [run.loop(), run.day()], 18, GOLD)
	if screen in ["board", "scene"]:
		var x := 960.0 - 24.0
		for i in range(run.TIME_NAMES.size() - 1, -1, -1):
			var n: String = run.TIME_NAMES[i]
			var w := text_w(n, 13) + 16.0
			x -= w
			var col: Color = GOLD if i == run.time() else Color(PAPER, 0.35 if i < run.time() else 0.7)
			text(Vector2(x, 60), n, 13, col)
	button(Rect2(24, 500, 120, 28), "Ledger  (L)", toggle_ledger, 0, 13)


func _draw_title() -> void:
	title(Vector2(0, 150), "Wizard", 58, HAIR, HORIZONTAL_ALIGNMENT_CENTER, 960)
	text(Vector2(0, 186), "The last month of Vellmar  ·  vertical slice: days 1 to 7 and the Long Night", 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var y := 250.0
	if run.has_save() and run.loop() >= 1 and not run.known_ids().is_empty():
		button(Rect2(370, y, 220, 34), "Continue  (loop %d, day %d)" % [run.loop(), run.day()], continue_month, 1, 15)
		y += 44.0
		button(Rect2(370, y, 220, 34), "Begin a new month", new_month, 2, 15)
	else:
		button(Rect2(370, y, 220, 34), "Begin", new_month, 1, 15)
	y += 44.0
	button(Rect2(370, y, 220, 34), "Test scenes", func(): main.open_tests(), 3, 15)
	_draw_playtest_buttons(run.has_save() and not run.known_ids().is_empty())
	var ctl = main.controls
	var g: String = {"auto": "auto", "high": "high", "low": "low"}.get(main.gfx, "auto")
	text(Vector2(0, 470), "Tab  ·  Fight controls: %s        F4  ·  Graphics: %s" % [ctl.NAMES[ctl.scheme], g], 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	text(Vector2(0, 494), "Pick places on the board with the mouse. Number keys pick choices, Space carries on, L opens the Ledger.", 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_dawn() -> void:
	backdrop.paint(self, "room", 0, run.day(), scene_t)
	_header()
	var r := Rect2(130, 84, 700, 404)
	panel(r)
	title(r.position + Vector2(0, 44), "Day %d" % run.day(), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var sub := "Dawn over Vellmar."
	if run.day() == 1 and run.loop() == 1:
		sub = "The first day."
	elif run.day() == 1:
		sub = "Day one again. You remember everything; your hands don't."
	elif run.day() == 7:
		sub = "The seventh day."
	var left: int = 28 - run.day()
	text(r.position + Vector2(0, 72), "%s  %d day%s to the Eclipse." % [sub, left, "" if left == 1 else "s"], 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_draw_growth(Vector2(r.position.x + 40, r.position.y + 110))
	_draw_book_editor(Vector2(r.position.x + 40, r.position.y + 168))
	button(Rect2(r.position.x + r.size.x / 2.0 - 80, r.end.y - 48, 160, 34), "Begin the day", start_day, 0, 15)


## Your Ring, wells, Vitality and Aether, and how fast you are relearning.
func _draw_growth(at: Vector2) -> void:
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
		bits.append("Fluency +%d%%" % roundi(growth.fluency() * 100.0))
	if not bits.is_empty():
		next += ("  " if next != "" else "") + "Echo: " + ", ".join(bits) + "."
	text(at + Vector2(0, 24), next, 13, DIM)


## The spellbook: pick a slot, then a Model you know. Slots open with each Ring; a spell's tier
## needs a Ring too (controls the 1st, signatures the 4th).
func _draw_book_editor(at: Vector2) -> void:
	title(at, "Spellbook", 15, PAPER)
	text(at + Vector2(96, 0), "pick a slot, then a spell", 12, DIM)
	var book: Array = growth.book()
	for i in 6:
		var rr := Rect2(at + Vector2(i * 104, 14), Vector2(98, 46))
		var open: bool = i < growth.slots()
		var id: String = growth.slot_spell(i)
		var border := Color(GOLD, 0.9) if open and i == dawn_slot else Color(HAIR, 0.45 if open else 0.15)
		panel(rr, border)
		if open:
			var nm: String = growth.prog.spell(book[i])["name"] if id != "" else "(empty)"
			text(rr.position + Vector2(0, 20), nm, 13, PAPER, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			if id != "":
				text(rr.position + Vector2(0, 38), "Practice %d" % growth.level(id), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			buttons.append({"r": rr, "act": _pick_slot.bind(i), "key": 0})
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
		button(rr, label, _put_model.bind(id), 0, 12, ok and dawn_slot < growth.slots())


func _slot_ring(i: int) -> String:
	var sl: Array = growth.d["slots"]
	for r in sl.size():
		if int(sl[r]) > i:
			return growth.ring_name(r)
	return ""


func _pick_slot(i: int) -> void:
	dawn_slot = i


func _put_model(id: String) -> void:
	growth.set_slot(dawn_slot, id)


func _draw_board() -> void:
	_header()
	var map := Rect2(24, 76, 912, 412)
	panel(map, Color(HAIR, 0.35))
	_draw_atlas(map)
	title(Vector2(120, 300), "The College of Hours", 13, Color(HAIR, 0.5))
	title(Vector2(560, 420), "Vellmar", 13, Color(HAIR, 0.5))
	title(Vector2(770, 112), "The plateau", 13, Color(HAIR, 0.5))
	for l in links:
		var a: Array = places[l[0]]["pos"]
		var b: Array = places[l[1]]["pos"]
		draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), Color(HAIR, 0.22), 1.0)
	var mouse := get_local_mouse_position()
	for id in places:
		var p: Dictionary = places[id]
		var c := Vector2(p["pos"][0], p["pos"][1])
		var r := Rect2(c - Vector2(60, 14), Vector2(120, 40))
		var hot := r.has_point(mouse)
		star(c, 7.0 if hot else 5.0, GOLD if hot else Color(PAPER, 0.85))
		text(Vector2(c.x - 70, c.y + 22), p["name"], 13, GOLD if hot else PAPER, HORIZONTAL_ALIGNMENT_CENTER, 140)
		var known: Array = story.known_today(id)
		var ky := c.y + 38
		for k in known:
			text(Vector2(c.x - 80, ky), "%s: %s" % [str(k["time"]).capitalize(), k["title"]], 11, HOURS, HORIZONTAL_ALIGNMENT_CENTER, 160)
			ky += 14
		buttons.append({"r": r, "act": pick_place.bind(id), "key": 0})
	text(Vector2(0, 474), "Where will you be at %s?" % run.time_name().to_lower(), 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	if run.time() >= 3:
		button(Rect2(816, 500, 120, 28), "Sleep", sleep, 0, 13)


## The place a scene is set in: its own place if it has one, else where you went.
func scene_place() -> String:
	if in_long_night():
		return "room"
	return here


## The board as a star atlas: a field of faint stars, the graticule of a celestial chart, and a
## soft glow over each district.
func _draw_atlas(map: Rect2) -> void:
	for i in 160:
		var p := map.position + Vector2(fmod(i * 211.7, map.size.x), fmod(i * 97.3 + i * i * 0.13, map.size.y))
		var a := 0.12 + fmod(i * 0.071, 0.25)
		draw_circle(p, 0.7 + fmod(i * 0.37, 0.9), Color(PAPER, a * (0.75 + 0.25 * sin(scene_t * 0.8 + i))))
	var pole := Vector2(480, 900)
	for k in 7:
		draw_arc(pole, 420.0 + k * 70.0, -PI * 0.78, -PI * 0.22, 64, Color(HAIR, 0.06), 1.0, true)
	for k in 9:
		var a := -PI * 0.75 + k * PI * 0.0625
		var from := pole + Vector2.from_angle(a) * 420.0
		var to := pole + Vector2.from_angle(a) * 900.0
		draw_line(from, to, Color(HAIR, 0.05), 1.0)
	for g in [[Vector2(250, 190), 190.0, HAIR], [Vector2(620, 320), 200.0, HOURS], [Vector2(830, 170), 120.0, PAPER]]:
		for i in 6:
			draw_circle(g[0], g[1] * (1.0 - i / 6.0), Color(g[2], 0.012))
	var t: int = run.time()
	# The hour: a small dial, the sun's or moon's position for this time of day.
	var dc := Vector2(map.end.x - 46, map.end.y - 40)
	draw_arc(dc, 22.0, PI, TAU, 24, Color(HAIR, 0.4), 1.0, true)
	var ang := PI + PI * t / 4.0
	var body := dc + Vector2.from_angle(ang) * 22.0
	draw_circle(body, 4.0, HOURS if t < 4 else PAPER)


func _draw_scene() -> void:
	backdrop.paint(self, scene_place(), run.time(), run.day(), scene_t)
	_header()
	var r := Rect2(40, 90, 640, 400)
	panel(r)
	var place_name := ""
	if places.has(scene_place()):
		place_name = places[scene_place()]["name"]
	if place_name != "":
		title(r.position + Vector2(28, 34), place_name, 16, Color(HAIR, 0.8))
	var y := r.position.y + 70.0
	var shown := lines.slice(maxi(0, lines.size() - 9))
	for ln in shown:
		var who: String = ln["who"]
		if who != "":
			text(Vector2(r.position.x + 28, y), who, 14, GOLD)
			y = para(Vector2(r.position.x + 110, y), ln["text"], r.size.x - 140, 15, PAPER)
		else:
			y = para(Vector2(r.position.x + 28, y), ln["text"], r.size.x - 56, 15, Color(PAPER, 0.85))
		y += 6.0
	y = maxf(y + 8.0, r.end.y - 44.0 * maxi(1, opts.size()) - 12.0) if pending.is_empty() else maxf(y + 8.0, r.end.y - 56.0)
	if in_long_night():
		_draw_censer(Vector2(818, 400))
	if not pending.is_empty():
		button(Rect2(r.position.x + 28, y, 200, 34), pending_label(), advance, 1, 15)
		return
	for i in opts.size():
		button(Rect2(r.position.x + 28, y, r.size.x - 56, 34), opts[i]["text"], choose.bind(i), i + 1, 15)
		y += 40.0


func in_long_night() -> bool:
	var id: String = cur.get("id", "")
	return id == "long_night" or id.begins_with("ln_")


## The Long Night's censer: it fills with each topic, and the night ends when it's full.
func _draw_censer(c: Vector2) -> void:
	var told: int = mini(story.ctx.count("topic_"), 3)
	var t := Time.get_ticks_msec() / 1000.0
	# Chains, bowl, lid.
	for dx in [-14.0, 0.0, 14.0]:
		draw_line(c + Vector2(0, -70), c + Vector2(dx, -18), Color(HAIR, 0.6), 1.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -18), c + Vector2(22, -18), c + Vector2(14, 6), c + Vector2(-14, 6)]), Color("8a6a34"))
	draw_arc(c + Vector2(0, -18), 22.0, PI, TAU, 16, Color("c8a050"), 2.0)
	draw_rect(Rect2(c + Vector2(-8, 6), Vector2(16, 6)), Color("6a4e26"))
	# Smoke: one plume per topic told, rising and curling.
	for i in told:
		for k in 6:
			var f := fmod(t * 0.35 + k / 6.0 + i * 0.13, 1.0)
			var p := c + Vector2(sin(f * 6.0 + i * 2.0) * (6.0 + f * 14.0), -26.0 - f * (60.0 + i * 18.0))
			draw_circle(p, 3.0 + f * 7.0, Color(0.8, 0.82, 0.9, 0.22 * (1.0 - f)))
	for i in 3:
		var pc := c + Vector2(-16 + i * 16, 30)
		if i < told:
			star(pc, 5.0, HOURS)
		else:
			draw_arc(pc, 4.0, 0, TAU, 12, Color(HAIR, 0.5), 1.0)
	text(Vector2(c.x - 80, c.y + 58), "The censer: %d of 3" % told, 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, 160)


func _draw_death() -> void:
	var r := Rect2(220, 70, 520, 400)
	panel(r, Color(HOURS, 0.6))
	var log: Dictionary = run.mem["log"][-1] if not run.mem["log"].is_empty() else {}
	var cause: String = str(log.get("cause", ""))
	var why: String = death_texts.get(cause, death_texts.get(cause.split(":")[0], "The month ends."))
	title(r.position + Vector2(0, 46), "Loop %d ends" % run.loop(), 28, HOURS, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(r.position + Vector2(0, 76), "Day %d, %s.  %s" % [run.day(), run.time_name().to_lower(), why], 14, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	title(r.position + Vector2(32, 120), "What you learned this loop", 15, GOLD)
	var y := r.position.y + 146.0
	var learned: Array = run.lp["learned"].filter(func(id): return ledger.has(id) and ledger[id]["kind"] != "trial")
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


func _draw_end() -> void:
	var r := Rect2(170, 80, 620, 380)
	panel(r, Color(GOLD, 0.7))
	title(r.position + Vector2(0, 54), "The Last Month can begin", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y := r.position.y + 100.0
	var body := [
		"You know now where the notes come from: they are what you tell Wren on the Long Night." if run.knows("notes_are_ours")
			else "You told Wren what you could. Somewhere in those pages is where the notes come from.",
		"In the full game, this is where you can choose to live one deliberate Last Month, making every message come true, and decide at the Gate who walks back.",
		"This is the end of the vertical slice. Thank you for playing it.",
		"You can keep playing loops: everything you know stays with you. If you're playtesting, copy your run summary (top right) into the feedback form.",
	]
	for b in body:
		y = para(Vector2(r.position.x + 40, y), b, r.size.x - 80, 15, PAPER) + 10.0
	button(Rect2(r.position.x + 200, r.end.y - 56, 220, 34), "Keep playing", keep_playing, 1, 15)
	_draw_playtest_buttons()


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
