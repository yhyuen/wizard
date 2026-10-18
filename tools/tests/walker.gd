extends RefCounted
## A bot that plays the open world the way a player does, for the route, relearn and deaths
## tests: each time of day it works through a list of goals by walking the streets (along the
## map's street graph, with the clock running), talking to people where they stand and using
## things with the same request G sends, then waits (Z) for the next time of day. Scenes are read
## through slice.advance and slice.choose, picking from `prefer`.
##
## Goals: "talk:wren", "use:desk", "go:market" (a place), "spot:room_in", "sleep" (walk to the bed
## and sleep), "wait" (Z at once), "cast:burnt_door:ember_bolt" (walk up to it and cast that spell
## at it). "use:bed>Sleep until dawn" prefers that choice when the scene comes up.
## Fights go through slice.fight_resolver, which the test sets.

const LINE_SECONDS := 3.5
const CHOICE_SECONDS := 2.5
const STUCK_S := 12.0

var main
var slice
var world
var run
var prefer: Array = []
var leave := ["Leave", "Continue", "Get up", "Promise to come", "Just read", "Look away until it's over", "Slip away"]

var goals: Array = []
var goal := ""
var goal_t := 0.0
var route := PackedVector2Array()
var repath_t := 0.0
var best_d := INF
var best_t := 0.0
var play_s := 0.0  # estimated seconds of play: walking, plus reading and choosing
var missed: Array = []  # goals a time of day ran out on: "day 3 noon talk:wren"
var stuck: Array = []  # goals the bot could not walk to
var log_goals := false
var _cast := {}  # casting at an item: {"slot", "aim", "t", "pressed"}
var _want_next := ""  # the choice the last goal asked for ("use:bed>Sleep until dawn")


func _init(the_main) -> void:
	main = the_main
	slice = main.slice
	world = slice.world
	run = slice.run
	main.bot = intent


## Sets the goals for this time of day (the ones not reached yet are dropped and noted).
func set_goals(g: Array) -> void:
	for left in ([goal] if goal != "" else []) + goals:
		missed.append("day %d %s %s" % [run.day(), run.time_name(), left])
	goals = g.duplicate()
	goal = ""
	route = PackedVector2Array()


## The move for this physics frame: along the route, or still.
func intent(A) -> Dictionary:
	var P = A.player
	var out := {"move": Vector2.ZERO, "aim": P.pos + Vector2(40, 0), "held": {}, "pressed": {}, "released": {}}
	while not route.is_empty() and P.pos.distance_to(route[0]) < (8.0 if route.size() > 1 else 4.0):
		route.remove_at(0)
	if not route.is_empty():
		out["move"] = (route[0] - P.pos).normalized()
	if not _cast.is_empty():
		# Pressed, held a moment (a bolt fires while held), then let go (other spells fire then).
		out["aim"] = _cast["aim"]
		_cast["f"] += 1
		if _cast["f"] == 1:
			out["pressed"][_cast["slot"]] = true
		if _cast["f"] < 12:
			out["held"][_cast["slot"]] = true
		elif _cast["f"] == 12:
			out["released"][_cast["slot"]] = true
	return out


## One frame of play. Returns what the bot is doing: "scene", "walking", "idle" (all goals done).
func tick(dt: float) -> String:
	if slice.overlay != "":
		slice.overlay = ""  # the spellbook from the desk: close it
	if not slice.cur.is_empty():
		route = PackedVector2Array()
		if main.mode != "world":
			return "scene"  # a fight or a cutscene is playing
		if not slice.pending.is_empty():
			play_s += slice.lines.size() * LINE_SECONDS * 0.5
			slice.advance()
		elif not slice.opts.is_empty():
			play_s += slice.lines.size() * LINE_SECONDS * 0.5 + CHOICE_SECONDS
			slice.choose(pick(slice.opts))
		return "scene"
	if slice.screen != "world" or main.mode != "world" or not world.requests.is_empty():
		return "scene"
	play_s += dt
	if goal == "":
		if goals.is_empty():
			return "idle"
		goal = goals.pop_front()
		goal_t = 0.0
		best_d = INF
		best_t = 0.0
		repath_t = 0.0
		if log_goals:
			print("[walker] day %d %s: %s" % [run.day(), run.time_name(), goal])
	goal_t += dt
	if not _cast.is_empty():
		_cast["t"] -= dt
		if _cast["t"] <= 0.0:
			_cast = {}
			goal = ""
		return "walking"
	_work(dt)
	return "walking"


func _work(dt: float) -> void:
	var kind: String = goal.split(":")[0]
	var id: String = goal.split(":")[1].split(">")[0] if ":" in goal else ""
	var at: Vector2 = world.player_pos()
	match kind:
		"wait":
			goal = ""
			slice.wait()
			return
		"sleep":
			goals.push_front("use:bed>Sleep until dawn")
			goal = ""
			return
	var target := _target(kind, id)
	if target == Vector2.INF:
		stuck.append("day %d %s: %s is nowhere" % [run.day(), run.time_name(), goal])
		goal = ""
		return
	# Arrived?
	var reach := float(world.cfg["reach"]) * 0.8
	var done := false
	match kind:
		"go":
			done = world.here == id
		"spot":
			done = at.distance_to(target) < 10.0
		"talk":
			done = at.distance_to(target) < reach
		"use", "cast":
			done = at.distance_to(target) < float(world.map.items[id].get("reach", world.cfg["reach"])) * 0.8
	if done:
		route = PackedVector2Array()
		_want_next = goal.split(">")[1] if ">" in goal else ""
		if kind == "cast":
			var spell: String = goal.split(":")[2]
			var slot: String = main.arena.kit.slot_of(spell)
			if slot == "":
				stuck.append("day %d %s: %s is not in the spellbook" % [run.day(), run.time_name(), spell])
				goal = ""
				return
			_cast = {"slot": slot, "aim": target + (target - at).normalized() * 40.0, "t": 1.5, "f": 0}
			return
		if kind == "talk":
			world.interact({"type": "person", "id": id})
		elif kind == "use":
			world.interact({"type": "item", "id": id})
		goal = ""
		return
	# Walk there, re-planning now and then (people move), and give up if it stops getting closer.
	repath_t -= dt
	if route.is_empty() or repath_t <= 0.0:
		repath_t = 1.0 if kind == "talk" else 5.0
		route = world.map.path(at, target, main.arena.player.radius)
		if route.is_empty():
			route = PackedVector2Array([target])
	var d: float = at.distance_to(target)
	if d < best_d - 4.0:
		best_d = d
		best_t = goal_t
	elif goal_t - best_t > STUCK_S:
		stuck.append("day %d %s: stuck walking to %s at %s (%.0f px away)" % [run.day(), run.time_name(), goal, at.round(), d])
		route = PackedVector2Array()
		goal = ""


func _target(kind: String, id: String) -> Vector2:
	match kind:
		"talk":
			var p = world.people.get_person(id)
			return p.pos if p != null else Vector2.INF
		"use", "cast":
			return world.map.items[id]["at"] if world.map.items.has(id) and world.item_visible(id) else Vector2.INF
		"go":
			return world.map.place_centre(id)
		"spot":
			return world.map.spots.get(id, Vector2.INF)
	return Vector2.INF


func pick(opts: Array) -> int:
	var want: Array = prefer.duplicate()
	if _want_next != "":
		want.push_front(_want_next)
	for w in want:
		for i in opts.size():
			if w in str(opts[i]["text"]):
				return i
	for i in opts.size():
		if str(opts[i]["text"]) in leave:
			return i
	return 0

