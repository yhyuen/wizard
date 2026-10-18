extends SceneTree
## Magic meets the world (design/open-world/interactions.md): each case casts a real spell the way
## a player does (the slot pressed, aimed at the thing), in the town, and checks what happened:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/world_magic.gd
##
## An Ember Bolt lights a street lamp and sets a hay bale burning; Splash puts the bale out and
## the lamp too; a Pebble shoves a crate; an Ember Bolt on the Observatory wall leaves the same
## star as the burnt door and teaches the scorch test's clue.

const BOOK := ["ember_bolt", "pebble", "splash", "undertow", "pillar", "fling"]
const WAIT := 150  # frames a case may take

var main
var slice
var world
var run
var frames := 0
var cases: Array = []
var i := -1
var t := 0
var cast := {}  # {"slot", "aim", "f"}: the press being played out
var state := {}
var failures: Array = []
var passed: Array = []
var done := false


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	cases = [
		["an Ember Bolt lights a street lamp", _lamp_setup, func(): return state["lamp"]["lit"] and state["lamp"]["by"] == "you"],
		["an Ember Bolt sets hay burning", _hay_setup, func(): return state["prop"]["state"] == "burning"],
		["Splash puts the burning hay out", _douse_setup, func(): return state["prop"]["state"] != "burning"],
		["Splash puts a lit lamp out", _lamp_douse_setup, func(): return not state["lamp"]["lit"]],
		["a Pebble shoves a crate", _crate_setup, func(): return state["prop"]["pos"].distance_to(state["from"]) > 4.0],
		["the scorch test teaches its clue", _scorch_setup, func(): return run.knows("scorch_match")],
	]


func _process(_dt: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 3:
		slice = main.slice
		world = slice.world
		slice.fight_resolver = func(_id): return true
		slice.new_month()
		_skip_scenes()
		_strong()
		main.bot = _intent
		_next()
	if frames <= 3:
		return false
	_skip_scenes()
	t += 1
	if cases[i][2].call():
		passed.append(cases[i][0])
		print("[magic] ok: " + cases[i][0])
		return _next()
	if t > WAIT:
		failures.append(cases[i][0] + " (nothing happened)")
		return _next()
	return false


func _next() -> bool:
	i += 1
	t = 0
	if i >= cases.size():
		for f in failures:
			print("[magic] FAIL: " + f)
		if failures.is_empty():
			print("[magic] magic meets the world in all %d cases" % passed.size())
		done = true
		quit(1 if not failures.is_empty() else 0)
		return true
	cases[i][1].call()
	return false


## A wizard who has every Model this test casts, with Aether to spare.
func _strong() -> void:
	var g = slice.growth
	run.set_flag("ring1")
	run.lp["wells"] = 60
	for id in BOOK:
		run.mem["known"]["model_" + id] = 1
	run.lp["book"] = BOOK.duplicate()
	g.refresh()
	main.refresh_book()
	main.refresh_player()


func _skip_scenes() -> void:
	for n in 20:
		if slice.cur.is_empty() or main.mode != "world":
			return
		if not slice.pending.is_empty():
			slice.advance()
		else:
			slice.choose(slice.opts.size() - 1 if slice.opts.size() > 0 else 0)


## Stands the wizard near `target` with a clear shot at it, and casts `spell` at it.
func _cast_at(target: Vector2, spell: String, dist := 50.0) -> void:
	var at := target
	for k in 16:
		var p: Vector2 = target + Vector2.from_angle(PI * 0.5 + k * TAU / 16.0) * dist
		if not world.map.solid_at(p, 8.0) and not world.map.in_water(p, 6.0) and world.map.clear_line(p, target.move_toward(p, 8.0), 2.0):
			at = p
			break
	main.place_player(at)
	main.arena.kit.aether = main.arena.kit.max_aether()
	var slot: String = main.arena.kit.slot_of(spell)
	if slot == "":
		failures.append("%s is not in the spellbook" % spell)
	cast = {"slot": slot, "aim": target, "f": 0}


func _intent(A) -> Dictionary:
	var out := {"move": Vector2.ZERO, "aim": A.player.pos + Vector2(40, 0), "held": {}, "pressed": {}, "released": {}}
	if cast.is_empty() or cast["slot"] == "":
		return out
	out["aim"] = cast["aim"]
	if cast["f"] == 0 and A.kit.cast_t > 0.0:
		return out  # the last spell is still being cast
	cast["f"] += 1
	if cast["f"] == 2:
		out["pressed"][cast["slot"]] = true
		out["held"][cast["slot"]] = true
	elif cast["f"] < 14:
		out["held"][cast["slot"]] = true
	elif cast["f"] == 14:
		out["released"][cast["slot"]] = true
	return out


func _street_lamp() -> Dictionary:
	for l in world.lamps:
		if l["group"] == "street":
			return l
	return world.lamps[0]


func _lamp_setup() -> void:
	state["lamp"] = _street_lamp()
	state["lamp"]["lit"] = false
	_cast_at(state["lamp"]["pos"], "ember_bolt")


func _hay_setup() -> void:
	for p in world.props:
		if p["kind"] == "hay":
			state["prop"] = p
			break
	_cast_at(state["prop"]["pos"], "ember_bolt")


func _douse_setup() -> void:
	if state["prop"]["state"] != "burning":
		world.ignite(state["prop"])
	_cast_at(state["prop"]["pos"], "splash", 34.0)


func _lamp_douse_setup() -> void:
	world.light_lamp(state["lamp"], "you")
	_cast_at(state["lamp"]["pos"], "splash", 34.0)


func _crate_setup() -> void:
	for p in world.props:
		if p["kind"] == "crate":
			state["prop"] = p
			break
	state["from"] = state["prop"]["pos"]
	_cast_at(state["prop"]["pos"], "pebble")


func _scorch_setup() -> void:
	# The Observatory is a round tower; aim at its wall from the burnt door's side.
	var c: Array = world.map.d["circles"].filter(func(x): return x[4] == "observatory")[0]
	var centre := Vector2(c[0], c[1])
	var door: Vector2 = world.map.items["burnt_door"]["at"]
	var at: Vector2 = door + (door - centre).normalized() * 30.0
	main.place_player(at)
	main.arena.kit.aether = main.arena.kit.max_aether()
	cast = {"slot": main.arena.kit.slot_of("ember_bolt"), "aim": centre, "f": 0}
