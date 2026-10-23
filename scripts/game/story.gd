extends RefCounted
## Loads the story scripts of every map (data/world/maps.json "story": the camp's in
## data/world/story/, each ruin layer's in data/ruins/<layer>/story/) and answers questions about them:
## which event plays at a place and time, which plays wherever you are, and whether a condition
## holds. The format is in design/slice/tech-plan.md §2:
##
##   === scene_id
##   place: archive          (with days and times, this scene is an event on the board)
##   days: 4                 (4, 1-7 or 2,3)
##   times: noon             (morning, noon, afternoon, dusk, night; several with commas; or any)
##   when: not f("wren_friend")
##   Wren: A line spoken by Wren.
##   A line with no speaker is narration.
##   + learn wren_sea        (an effect)
##   * A choice [condition] -> next_scene
##   ? won -> scene_after_a_won_fight
##
## Conditions are Godot expressions over k(id) (remembered), f(id) (flag this loop), seen(id)
## (scene played this loop), died(cause), count(prefix) (flags starting with prefix), done(op)
## (a once-a-day action such as "meditate" already done today), since(op) (days since that action),
## and the values loop, day, time and ring. A line, effect or outcome can start with [condition] to
## happen only when it holds. `place` can list several places; `slot: free` means playing the
## scene doesn't use up the time of day. `backdrop: north_door` paints that place behind a scene
## that has no place of its own (and the scenes it leads to).
##
## The open world (design/open-world/tech-plan.md §3) adds what starts a scene: `talk: wren`
## (talking to that person), `use: noon_note` (using that item), `arrive: market` (walking into
## that place, or any of several), and `cast: fire` with `use:` (that element hitting the item).
## Such scenes play on any day and at any time unless they say otherwise. New effects: `move
## <spot>`, `take <item>`, `sleep` (end the day), `book` (open the spellbook) and `today <op>`
## (mark a once-a-day thing done, for done(op)).
##
## The ruins (design/ruins/tech-plan.md §1) add `go <map> <spot>` (when the scene closes, the
## loading card takes you there) and `go <exit>` (through that exit of the map you're on); an
## exit you walk into plays `use: <exit id>` first, if there is such a scene.
## R2 adds `open <door>` (that door of this map stands open for the rest of the loop),
## `play_path <id>` (a recorded path from the map's paths file plays, as a cutscene) and
## `cast: hours` (Rewind's shard formed on the item).
## N-5.2 adds `bench` (work at a bench: fill your devices from your reagents, a time of day) and
## `bench stock` (the Lamplighters' spare reagents, data/schools.json devices.starter).
## N-7.2.1 adds `remember <who> <deed>` (that person remembers it this life, up to three deeds)
## and the condition remembers(who, deed).
## N-7.6.3 adds `commission <id> take|next|clean|lose|slow|work|pay` (scripts/game/commissions.gd)
## and the conditions commission_step, commission_posted, commission_done, commission_known,
## commission_lost, commission_clean and commission_board_empty.
## N-7.6.4 adds `ladder bout|win` (scripts/game/ladder.gd) and the conditions rung(), ladder_open()
## and ladder_book(n).
## N-7.6.5 adds `game <who> free|work|coin` (a minigame against who: scripts/game/minigames/; it
## stops the scene like a fight, with `? won` and `? lost`) and the conditions game_open(who),
## game_work(who), game_coin(who) and minigame_beaten(who).
## N-7.6.6 adds `companion <who> join|part` (scripts/game/companions.gd) and the conditions
## companion() (who walks with you, "" for nobody) and companion_can(who).
## N-7.6.7 adds `confront <id>` (a confrontation, scripts/game/confront.gd: stops the scene like a
## fight, then `? <close id>` or `? lost`) and the condition confronted(id) (this life: the close
## chosen, or "lost"; "" if not yet).
## N-7.6.8 adds `inherit <id>`: an inheritance's trial rooms begin (scripts/world/trials.gd, the
## map's `trials`); passing them sets its `done` flag and plays its reward scene.
## N-7.7 adds conditions for achievements: calamity_tier(id), calamity_hurt(id), best_stage(),
## school_rank(), tally(kind), commissions_done() and games_beaten().
## N-4.5.3 adds the conditions dark() (the season's dark times; Hollow sites wait for them) and
## season().

const FieldGuide := preload("res://scripts/field_guide.gd")
const MAPS := "res://data/world/maps.json"
const HEADER_KEYS := ["place", "days", "times", "when", "force", "priority", "repeat", "known", "title", "slot", "backdrop",
	"talk", "use", "arrive", "cast"]
const EFFECTS := ["learn", "set", "clear", "fight", "wells", "train", "meditate", "goto", "end_loop",
	"model", "trial", "sound", "cutscene", "move", "take", "sleep", "book", "today", "go", "open", "play_path", "road", "deed", "omen", "forecast", "bench", "remember", "ignite", "downed", "standing", "merit", "exam", "sign", "prep", "calamity_onset", "calamity_dawn",
	"bond", "bond_cross", "betray", "gift", "rumour", "commission", "ladder", "game", "companion", "confront", "inherit"]

var scenes := {}  # id -> scene dictionary
var errors: Array = []  # parse errors, for the linter
var _exprs := {}  # condition string -> Expression
var ctx := Ctx.new()


class Ctx:
	var run  # the Run autoload
	var ring := 0
	var growth  # scripts/game/growth.gd, when the slice has one: gives the real Ring
	var powers  # scripts/game/powers.gd, when the slice has one: standing and rank in the powers
	var calamity  # scripts/game/calamity.gd, when the slice has one
	var bonds  # scripts/game/bonds.gd, when the slice has one
	var rumours  # scripts/game/rumours.gd, when the slice has one
	var commissions  # scripts/game/commissions.gd, when the slice has one
	var ladder  # scripts/game/ladder.gd, when the slice has one
	var games  # scripts/game/minigames/games.gd, when the slice has one
	var companions  # scripts/game/companions.gd, when the slice has one
	var world  # scripts/world/world.gd, when the slice has one: the dark and today's sky

	## A once-a-day action (meditate, train) already done today.
	func done(op: String) -> bool:
		return int(run.life.get("done_" + op, 0)) == run.day()

	## Days since `today op` was last marked in this life (a large number if never): a fight site
	## cleared that long ago has filled up again (N-7.1.6).
	func since(op: String) -> int:
		return run.day() - int(run.life["done_" + op]) if run.life.has("done_" + op) else 9999

	func k(id: String) -> bool:
		return run.knows(id)

	## School `id` reached Master in this life or an earlier one (combined spells, N-5.3).
	func mastered(id: String) -> bool:
		return growth != null and growth.mastered(id)

	func f(id: String) -> bool:
		return run.flag(id)

	## Your rank in power `id` (-1 not a member, 0 Initiate, 1 Adept; powers spec §4; N-7.3.3).
	func rank(id: String) -> int:
		return powers.rank(id) if powers != null else -1

	## Standing with power `id` (powers spec §3).
	func standing(id: String) -> int:
		return powers.standing(id) if powers != null else 0

	## `who` remembers you did `deed` to them this life (people spec §3.3; N-7.2.1).
	func remembers(who: String, deed: String) -> bool:
		return deed in run.life.get("memories", {}).get(who, [])

	## Kinds of foe whose weakness the Field Guide has found, and kinds mastered (N-6.5).
	func guide_found() -> int:
		return FieldGuide.found_count(run.soul)

	func guide_mastered() -> int:
		return FieldGuide.mastered_count(run.soul)

	func seen(id: String) -> bool:
		return run.seen(id)

	## This life's road is `id` ("" before one is taken).
	func on_road(id: String) -> bool:
		return run.road() == id

	## Road `id` offers itself this life (open, not taken last life, no road taken yet).
	func offered(id: String) -> bool:
		return id in run.road_offers()

	## The Hours can be turned back (a calamity has passed in this life).
	func can_turn() -> bool:
		return run.can_turn()

	## This life is ending for `cause` (true only while the Turning checks achievements).
	func ended(cause: String) -> bool:
		return str(run.life.get("ended", "")) == cause

	## Omen `id` is taken this life.
	func omen(id: String) -> bool:
		return id in run.omens()

	## How many Omens this life is under.
	func omens() -> int:
		return run.omens().size()

	## The Omens can be read now (the first morning of life 2 onwards).
	func omens_offered() -> bool:
		return run.omens_offered()

	## Fixed event `id` happened with you there this life.
	func attended(id: String) -> bool:
		return run.event_state(id) == "attended"

	## Fixed event `id` went by without you, in this life or one before (an appointment).
	func missed(id: String) -> bool:
		return run.event_state(id) == "missed" or run.soul.get("appointments", {}).has(id)

	func died(cause: String) -> bool:
		return run.died_of(cause) > 0

	func count(prefix: String) -> int:
		return run.life["flags"].keys().filter(func(k): return str(k).begins_with(prefix)).size()

	## Days until calamity `id` comes (0 on its day; after the Early Bell, a moon sooner).
	func calamity_in(id: String) -> int:
		return calamity.days_to(id) if calamity != null else 9999

	## A rumour heard, in this life or an earlier one.
	func rumour_heard(id: String) -> bool:
		return rumours.heard(id) if rumours != null else false

	## Commission `id` (people spec §6; N-7.6.3): its step this life (-1 not taken, 99 paid), on
	## the board now, paid this life, done in an earlier life (the answer shows), a fight for it lost.
	func commission_step(id: String) -> int:
		return commissions.step(id) if commissions != null else -1

	func commission_posted(id: String) -> bool:
		return commissions.posted(id) if commissions != null else false

	func commission_done(id: String) -> bool:
		return commissions.done(id) if commissions != null else false

	func commission_known(id: String) -> bool:
		return commissions.known(id) if commissions != null else false

	func commission_lost(id: String) -> bool:
		return commissions.lost(id) if commissions != null else false

	## Its matter hook was kept (the bonus is owed).
	func commission_clean(id: String) -> bool:
		return commissions.is_clean(id) if commissions != null else false

	## Nothing posted on the camp's board now (a quiet week, or a calamity's).
	func commission_board_empty() -> bool:
		return commissions.posted_at("board").is_empty() if commissions != null else true

	## The camp ladder (people spec §7.1; N-7.6.4): the rung you hold (0 none, 6 champion), whether
	## you may challenge the next one now, and whether you know rung n's book from an earlier life.
	func rung() -> int:
		return ladder.rung() if ladder != null else 0

	func ladder_open() -> bool:
		return ladder.open() if ladder != null else false

	func ladder_book(n: int) -> bool:
		return ladder.book_known(n) if ladder != null else false

	## Minigames (people spec §9; N-7.6.5): free play open this week, work open today, playing for
	## coin (beaten in a past life, never at dice), and beaten in any life.
	func game_open(who: String) -> bool:
		return games.open(who) if games != null else false

	func game_work(who: String) -> bool:
		return games.work_open(who) if games != null else false

	func game_coin(who: String) -> bool:
		return games.coin_open(who) if games != null else false

	## Companions (people spec §4.4; N-7.6.6): who walks with you ("" for nobody), and whether
	## `who` would walk with you now (their gate holds).
	func companion() -> String:
		return companions.who() if companions != null else ""

	func companion_can(who: String) -> bool:
		return companions.can_join(who) if companions != null else false

	## A confrontation played this life: its close, "lost", or "" (people spec §11; N-7.6.7).
	func confronted(id: String) -> String:
		return str(run.life.get("confronted", {}).get(id, ""))

	func minigame_beaten(who: String) -> bool:
		return games != null and run.soul.get("games_beaten", {}).has(who)

	## Your bond tier with a person (0 Stranger .. 5 Sworn; people spec §4.1).
	func bond(who: String) -> int:
		return bonds.tier(who) if bonds != null else 0

	## Their lamp is full for this tier, and only a crossing scene opens the next.
	func bond_ready(who: String) -> bool:
		return bonds.ready_to_cross(who) if bonds != null else false

	## Its later-lives variant this life (0 before it has been Held).
	func calamity_variant(id: String) -> int:
		return calamity.variant(id) if calamity != null else 0

	## N-7.7, for achievements: how a calamity went this life (its tier id, "" before it passed),
	## and whether you were Injured when it did.
	func calamity_tier(id: String) -> String:
		return str(run.life.get("calamity", {}).get(id, {}).get("tally", {}).get("tier", ""))

	func calamity_hurt(id: String) -> bool:
		return bool(run.life.get("calamity", {}).get(id, {}).get("tally", {}).get("injured", false))

	## The highest stage any spell reached this life (0 Novice .. 3 Perfected).
	func best_stage() -> int:
		if growth == null:
			return 0
		var best := 0
		for id in growth.prog.p["spells"]:
			best = maxi(best, growth.prog.stage(id))
		return best

	## Your rank in this life's school (-1 with none).
	func school_rank() -> int:
		return growth.school_rank() if growth != null and growth.school() != "" else -1

	## It is dark now (seasons spec §5.3, N-4.5.3): the season's dark times, and more under a grey
	## sky. Hollows walk in the dark. With no world (the linter), only Night is dark.
	func dark() -> bool:
		if world != null:
			return world.dark()
		return run.time_id() == "night"

	## This moon's season: "spring", "summer", "autumn" or "winter".
	func season() -> String:
		return str(run.cal["moons"][run.moon() - 1]["season"]).to_lower()

	## Things done this life, counted (Run.tally: "collapse").
	func tally(kind: String) -> int:
		return run.tally(kind)

	func commissions_done() -> int:
		return commissions.ids().filter(func(id): return commissions.done(id)).size() if commissions != null else 0

	## Players beaten at the camp's tables, in any life.
	func games_beaten() -> int:
		return run.soul.get("games_beaten", {}).size()


func _init(run = null) -> void:
	ctx.run = run


## Every map's story folder, from the maps registry.
static func dirs() -> Array:
	var out: Array = []
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPS))
	for id in reg["maps"]:
		var d: String = str(reg["maps"][id].get("story", ""))
		if d != "" and not d in out:
			out.append(d)
	return out


func load_all() -> void:
	scenes.clear()
	errors.clear()
	for dir_path in dirs():
		var dir := DirAccess.open(dir_path)
		if dir == null:
			errors.append("no story directory at " + dir_path)
			continue
		var files: Array = []
		for f in dir.get_files():
			if f.ends_with(".story"):
				files.append(f)
		files.sort()
		for f in files:
			parse(FileAccess.get_file_as_string(dir_path + f), dir_path + f)


## Parses one file's text into scenes.
func parse(text: String, file := "") -> void:
	var cur: Dictionary = {}
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("==="):
			var id := line.trim_prefix("===").strip_edges()
			if scenes.has(id):
				errors.append("%s:%d: scene %s is defined twice" % [file, n, id])
			cur = {"id": id, "file": file, "line": n, "steps": [], "choices": [], "outcomes": {},
				"days": [], "times": [], "place": "", "places": [], "slot": "", "when": "", "force": false, "priority": 0,
				"repeat": false, "known": "", "title": "", "backdrop": "", "talk": "", "use": "", "arrive": "", "arrives": [], "cast": ""}
			scenes[id] = cur
			continue
		if cur.is_empty():
			errors.append("%s:%d: text before the first scene" % [file, n])
			continue
		var cond := ""
		if line.begins_with("["):
			var close := line.find("] ")
			if close < 0:
				errors.append("%s:%d: a condition needs '] ' after it" % [file, n])
				continue
			cond = line.substr(1, close - 1).strip_edges()
			line = line.substr(close + 2).strip_edges()
		var colon := line.find(":")
		if cond.is_empty() and colon > 0 and line.substr(0, colon) in HEADER_KEYS and cur["steps"].is_empty() and cur["choices"].is_empty():
			_header(cur, line.substr(0, colon), line.substr(colon + 1).strip_edges(), file, n)
		elif line.begins_with("+"):
			var parts := line.substr(1).strip_edges().split(" ", false, 1)
			var op: String = parts[0] if parts.size() > 0 else ""
			if not op in EFFECTS:
				errors.append("%s:%d: unknown effect '%s'" % [file, n, op])
			cur["steps"].append({"t": "fx", "op": op, "arg": parts[1] if parts.size() > 1 else "", "line": n, "cond": cond})
		elif line.begins_with("*"):
			if not cond.is_empty():
				errors.append("%s:%d: put a choice's condition in [ ] after its text" % [file, n])
			cur["choices"].append(_choice(line.substr(1).strip_edges(), n))
		elif line.begins_with("?"):
			var body := line.substr(1).strip_edges()
			var arrow := body.find("->")
			if arrow < 0:
				errors.append("%s:%d: an outcome needs '-> scene'" % [file, n])
				continue
			cur["outcomes"][body.substr(0, arrow).strip_edges()] = body.substr(arrow + 2).strip_edges()
		else:
			var m := _speaker(line)
			cur["steps"].append({"t": "line", "who": m[0], "text": m[1], "line": n, "cond": cond})


func _header(cur: Dictionary, key: String, val: String, file: String, n: int) -> void:
	match key:
		"days":
			var bad: Array = []
			cur["days"].append_array(parse_days(val, bad))
			for b in bad:
				errors.append("%s:%d: bad day '%s'" % [file, n, b])
		"times":
			var bad: Array = []
			cur["times"].append_array(parse_times(val, bad))
			for b in bad:
				errors.append("%s:%d: bad time '%s'" % [file, n, b])
		"force", "repeat":
			cur[key] = val == "true"
		"priority":
			cur[key] = int(val)
		"place":
			cur["place"] = val
			for part in val.split(","):
				cur["places"].append(part.strip_edges())
		"arrive":
			cur["arrive"] = val
			for part in val.split(","):
				cur["arrives"].append(part.strip_edges())
		_:
			cur[key] = val


## "4", "1-7" or "2,3" -> the days. Anything that doesn't parse goes into `bad`.
static func parse_days(val: String, bad: Array = []) -> Array:
	var out: Array = []
	for part in val.split(","):
		part = part.strip_edges()
		if "-" in part:
			var ab := part.split("-")
			for d in range(int(ab[0]), int(ab[1]) + 1):
				out.append(d)
		elif part.is_valid_int():
			out.append(int(part))
		else:
			bad.append(part)
	return out


## "morning, noon", or "any" -> the times of day.
static func parse_times(val: String, bad: Array = []) -> Array:
	var all: Array = Array(preload("res://scripts/game/run.gd").TIMES)
	var out: Array = []
	for part in val.split(","):
		part = part.strip_edges()
		if part == "any":
			return all.duplicate()
		elif part in all:
			out.append(part)
		else:
			bad.append(part)
	return out


func _choice(body: String, n: int) -> Dictionary:
	var c := {"text": body, "cond": "", "target": "", "line": n}
	var arrow := body.find("->")
	if arrow >= 0:
		c["target"] = body.substr(arrow + 2).strip_edges()
		body = body.substr(0, arrow).strip_edges()
	if body.ends_with("]") and body.find("[") >= 0:
		var b := body.rfind("[")
		c["cond"] = body.substr(b + 1, body.length() - b - 2).strip_edges()
		body = body.substr(0, b).strip_edges()
	c["text"] = body
	return c


## "Wren: Hello." -> ["Wren", "Hello."]. A speaker is one capitalised word before ": ".
func _speaker(line: String) -> Array:
	var colon := line.find(": ")
	if colon > 0 and colon <= 12:
		var who := line.substr(0, colon)
		if not " " in who and who[0] == who[0].to_upper() and who.is_valid_identifier():
			return [who, line.substr(colon + 2)]
	return ["", line]


# --- queries -----------------------------------------------------------------------

## Whether `cond` holds now. An empty condition always holds.
func test(cond: String) -> bool:
	if cond.strip_edges().is_empty():
		return true
	var e: Expression = _exprs.get(cond)
	if e == null:
		e = Expression.new()
		if e.parse(cond, ["loop", "day", "time", "ring"]) != OK:
			push_error("story condition does not parse: %s (%s)" % [cond, e.get_error_text()])
			return false
		_exprs[cond] = e
	var ring: int = ctx.growth.ring() if ctx.growth != null else ctx.ring
	var r = e.execute([ctx.run.loop(), ctx.run.day(), ctx.run.time_id(), ring], ctx)
	if e.has_execute_failed():
		push_error("story condition failed: %s" % cond)
		return false
	return bool(r)


## Whether scene `s` can play now as an event (its day, time and condition, and not yet this loop).
func eligible(s: Dictionary) -> bool:
	if s["days"].is_empty() or s["times"].is_empty():
		return false
	if not ctx.run.day() in s["days"] or not ctx.run.time_id() in s["times"]:
		return false
	if not s["repeat"] and ctx.run.seen(s["id"]):
		return false
	return test(s["when"])


## The event that plays if you go to `place` now, or "" for none. Highest priority wins.
func event_at(place: String) -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		if place in s["places"] and not s["force"] and eligible(s) and int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## A forced event for this time (plays wherever you are), or "".
func forced() -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		if s["force"] and eligible(s) and int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## Events at `place` today (any time) whose `known` condition holds: what the board can show
## because you already know it will happen. Returns [{"id", "time", "title"}].
func known_today(place: String) -> Array:
	var out: Array = []
	for s in scenes.values():
		if not place in s["places"] or s["known"].is_empty() or not ctx.run.day() in s["days"]:
			continue
		if ctx.run.seen(s["id"]) or not test(s["known"]):
			continue
		out.append({"id": s["id"], "time": s["times"][0] if s["times"].size() > 0 else "", "title": s["title"]})
	return out


# --- the open world --------------------------------------------------------------

## Whether a talk, use or arrive scene can play now: its days and times (any, when it names
## none), its condition, and not yet this loop unless it repeats.
func eligible_any(s: Dictionary) -> bool:
	if not s["days"].is_empty() and not ctx.run.day() in s["days"]:
		return false
	if not s["times"].is_empty() and not ctx.run.time_id() in s["times"]:
		return false
	if not s["repeat"] and ctx.run.seen(s["id"]):
		return false
	return test(s["when"])


func _best(key: String, val: String, extra := "") -> String:
	var best := ""
	var best_p := -999999
	for s in scenes.values():
		var match_: bool = val in s["arrives"] if key == "arrive" else s[key] == val
		if not match_ or s["cast"] != extra or not eligible_any(s):
			continue
		if int(s["priority"]) > best_p:
			best = s["id"]
			best_p = int(s["priority"])
	return best


## The conversation with `person` now, or "".
func talk_scene(person: String) -> String:
	return _best("talk", person)


## What using `item` plays now, or "".
func use_scene(item: String) -> String:
	return _best("use", item)


## What walking into `place` plays now, or "".
func arrive_scene(place: String) -> String:
	return _best("arrive", place)


## What `element` hitting `item` plays now, or "".
func cast_scene(item: String, element: String) -> String:
	return _best("use", item, element)


## Events today whose `known` condition holds, for the map: [{"id", "time", "title", "where"}].
## `where` is the place, person or item the event belongs to.
func known_events() -> Array:
	var out: Array = []
	for s in scenes.values():
		if s["known"].is_empty() or not ctx.run.day() in s["days"] or ctx.run.seen(s["id"]) or not test(s["known"]):
			continue
		var where: String = s["arrive"] if s["arrive"] != "" else (s["talk"] if s["talk"] != "" else s["use"])
		out.append({"id": s["id"], "time": s["times"][0] if s["times"].size() > 0 else "", "title": s["title"], "where": where})
	return out


func choices(s: Dictionary) -> Array:
	return s["choices"].filter(func(c): return test(c["cond"]))
