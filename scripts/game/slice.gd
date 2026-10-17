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
const LEDGER_TABS := ["Questions", "Clues", "People", "Insights"]

var main  # scripts/main.gd: runs the fights
var run  # the Run autoload
var story
var places: Dictionary = {}
var links: Array = []
var encounters: Dictionary = {}
var ledger: Dictionary = {}  # data/slice/ledger.json "entries"
var death_texts: Dictionary = {}

var screen := "title"  # title, dawn, board, scene, fight, death, end
var ledger_open := false
var ledger_tab := 0
var toasts: Array = []  # {"text", "t"}

# The scene being played.
var cur: Dictionary = {}
var idx := 0
var lines: Array = []  # [{"who", "text"}] shown on the page
var pending := {}  # a blocking effect waiting for the player: {"op", "arg"}
var opts: Array = []  # the choices on the page
var uses_slot := true  # whether the pick that started this chain uses up the time of day
var fight_id := ""

## Tests set this to settle fights without playing them: func(encounter_id) -> bool (won).
var fight_resolver: Callable


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	run = get_node("/root/Run")
	story = Story.new(run)
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
			run.set_flag(arg)
		"clear":
			run.clear_flag(arg)
		"model":
			run.learn("model_" + arg)
		"trial":
			run.learn("trial_" + arg)
		"wells", "meditate":
			run.lp["wells"] = int(run.lp.get("wells", 0)) + int(arg)
			toast("Wells +%s" % arg)
		"train":
			run.lp["trained"] = int(run.lp.get("trained", 0)) + 1
			toast("Practice +")
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
	if fight_resolver.is_valid():
		fight_done(bool(fight_resolver.call(id)))
		return
	set_screen("fight")
	main.start_slice_fight(enc)


## Called by main.gd when a fight started here is over.
func fight_done(won: bool) -> void:
	set_screen("scene")
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
	for t in toasts.duplicate():
		t["t"] += dt
		if t["t"] > 4.0:
			toasts.erase(t)
	if visible:
		queue_redraw()


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or main == null or main.bot.is_valid():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if k == KEY_L:
			toggle_ledger()
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
	_draw_toasts()
	end_buttons()


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
	var ctl = main.controls
	text(Vector2(0, 470), "Tab  ·  Fight controls: %s" % ctl.NAMES[ctl.scheme], 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	text(Vector2(0, 494), "Pick places on the board with the mouse. Number keys pick choices, Space carries on, L opens the Ledger.", 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_dawn() -> void:
	_header()
	var r := Rect2(250, 150, 460, 230)
	panel(r)
	title(r.position + Vector2(0, 52), "Day %d" % run.day(), 34, GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var sub := "Dawn over Vellmar."
	if run.day() == 1 and run.loop() == 1:
		sub = "The first day."
	elif run.day() == 1:
		sub = "Day one again. You remember everything."
	elif run.day() == 7:
		sub = "The seventh day."
	text(r.position + Vector2(0, 92), sub, 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var left: int = 28 - run.day()
	text(r.position + Vector2(0, 124), "%d days to the Eclipse" % left, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	button(Rect2(r.position.x + 150, r.end.y - 62, 160, 34), "Begin the day", start_day, 1, 15)


func _draw_board() -> void:
	_header()
	var map := Rect2(24, 76, 912, 412)
	panel(map, Color(HAIR, 0.35))
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


func _draw_scene() -> void:
	_header()
	var r := Rect2(40, 90, 640, 400)
	panel(r)
	var place_name := ""
	if cur.get("places", []).size() == 1 and places.has(cur["places"][0]):
		place_name = places[cur["places"][0]]["name"]
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
	if not pending.is_empty():
		button(Rect2(r.position.x + 28, y, 200, 34), pending_label(), advance, 1, 15)
		return
	for i in opts.size():
		button(Rect2(r.position.x + 28, y, r.size.x - 56, 34), opts[i]["text"], choose.bind(i), i + 1, 15)
		y += 40.0


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
		"You can keep playing loops: everything you know stays with you.",
	]
	for b in body:
		y = para(Vector2(r.position.x + 40, y), b, r.size.x - 80, 15, PAPER) + 10.0
	button(Rect2(r.position.x + 200, r.end.y - 56, 220, 34), "Keep playing", keep_playing, 1, 15)


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
			for qid in entries_of("question"):
				var q: Dictionary = ledger[qid]
				var solved: bool = q.has("insight") and run.knows(q["insight"]) or q.has("closes") and run.knows(q["closes"])
				text(Vector2(r.position.x + 28, y), q["title"], 15, PAPER if not solved else Color(GOLD, 0.9))
				var known: Array = q.get("clues", []).filter(func(c): return run.knows(c))
				var line := "%d clue%s" % [known.size(), "" if known.size() == 1 else "s"]
				if solved:
					line = "Answered: " + str(ledger.get(q.get("insight", q.get("closes", "")), {}).get("title", ""))
				text(Vector2(r.position.x + 420, y), line, 12, DIM, HORIZONTAL_ALIGNMENT_LEFT, w - 400)
				y += 22.0
				if y > r.end.y - 30:
					break
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
