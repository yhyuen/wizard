extends SceneTree
## Magic meets the world (design/open-world/interactions.md): each case casts a real spell the way
## a player does (the slot pressed, aimed at the thing), in the camp, and checks what happened:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/world_magic.gd
##
## OW1: an Ember Bolt lights a street lamp and sets a hay bale burning; Splash puts the bale out
## and the lamp too; a Pebble shoves a crate.
## OW2: a Spark flares an iron lamp and charges a puddle that then shocks a Hollow in it; Rewind
## mends the shoved crate; a Hollow won't step into a lit lamp's pool; fire in the College ruins
## makes the watch captain flinch and scold; lighting Mira's lane gets her thanks.
## N-4.1 (the matter core, spells and the environment spec §4): a Pebble at grade I only cracks the
## cart (wood, breaks at II); it breaks a crate already cracked; an Ember Bolt only smoulders a
## barrel (catches at Fire II) and only steams wet hay; a Spark sets hay alight.

const BOOK := ["ember_bolt", "pebble", "splash", "undertow"]
const STORM_BOOK := ["spark", "rewind", "splash", "ember_bolt"]
const WAIT := 150  # frames a case may take
const LIGHT_WAIT := 240  # the lamp-pool case watches a Hollow for this long

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
		["a Spark flares an iron lamp", _flare_setup, func(): return state["lamp"]["flare_t"] > 0.0],
		["a Spark charges a puddle, which shocks a Hollow", _puddle_setup, _shocked],
		["Rewind mends the shoved crate", _rewind_setup, func(): return state["prop"]["pos"].distance_to(state["prop"]["home"]) < 1.0],
		["a Hollow won't step into a lit lamp's pool", _light_setup, _kept_off],
		["fire in the College ruins: the captain flinches and scolds", _captain_setup,
			func(): return _logged("flinch", "captain") and _logged("scold", "captain")],
		["lighting Mira's lane gets her thanks", _lane_setup,
			func(): return run.flag("lit_lane") and slice.story.talk_scene("mira") == "mira_thanks"],
		["a Pebble at grade I only cracks the cart", _cart_setup, func(): return state["prop"]["integrity"] == "cracked"],
		["a Pebble breaks a cracked crate", _break_setup, func(): return state["prop"]["integrity"] == "broken"],
		["an Ember Bolt at grade I only smoulders a barrel", _barrel_setup, func(): return state["prop"]["state"] == "smoulder"],
		["an Ember Bolt only steams wet hay", _wet_hay_setup,
			func(): return _logged("steam", "hay") and state["prop"]["state"] != "burning"],
		["a Spark sets hay alight", _spark_hay_setup, func(): return state["prop"]["state"] == "burning"],
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
	if t > (LIGHT_WAIT + 20 if state.has("hollow_light") else WAIT):
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
	run.set_flag("ring1")
	run.life["wells"] = 60
	for id in BOOK + STORM_BOOK:
		run.soul["known"]["model_" + id] = 1
	_book(BOOK)


func _book(ids: Array) -> void:
	run.life["book"] = ids.duplicate()
	slice.growth.refresh()
	main.refresh_book()
	main.refresh_player()


func _logged(kind: String, what: String) -> bool:
	return world.events_log.any(func(e): return e[0] == kind and e[1] == what)


## A clear point in the city with no lamp near: where the puddle case stands.
func _dark_spot() -> Vector2:
	for id in world.map.spots:
		var p: Vector2 = world.map.spots[id]
		if world.map.solid_at(p, 20.0) or world.map.in_water(p, 20.0):
			continue
		if world.lamps.all(func(l): return l["pos"].distance_to(p) > 120.0) and world.map.place_at(p) in ["market", "square", "streets"]:
			return p
	return world.map.spots["market"]


func _clear_enemies() -> void:
	for u in main.arena.enemies():
		u.dead = true
		u.death_t = 0.0


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
	main.arena.player.cd.clear()  # each case casts fresh, whatever the last one cooled down
	var slot: String = main.arena.kit.slot_of(spell)
	if slot == "":
		failures.append("%s is not in the spellbook" % spell)
	cast = {"slot": slot, "aim": target, "f": 0}


func _intent(A) -> Dictionary:
	var out := {"move": Vector2.ZERO, "aim": A.player.pos + Vector2(40, 0), "held": {}, "pressed": {}, "released": {}}
	if cast.is_empty() or cast["slot"] == "":
		return out
	out["aim"] = cast["aim"]
	if cast["f"] == 0 and (not A.kit.wind.is_empty() or A.kit.recover_t > 0.0 or A.hitstop > 0.0):
		return out  # the last spell is still being cast, or a hit froze the frame (input is lost then)
	cast["f"] += 1
	# Held through the spell's wind-up, then released.
	var up := 2 + int(ceil(A.kit.windup(A.kit.slot_spell(cast["slot"])) * 60.0)) + 2
	if cast["f"] == 2:
		out["pressed"][cast["slot"]] = true
		out["held"][cast["slot"]] = true
	elif cast["f"] < up:
		out["held"][cast["slot"]] = true
	elif cast["f"] == up:
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


func _flare_setup() -> void:
	_book(STORM_BOOK)
	state["lamp"] = _street_lamp()
	state["lamp"]["lit"] = false
	_cast_at(state["lamp"]["pos"], "spark", 40.0)


func _puddle_setup() -> void:
	var at := _dark_spot()
	state["at"] = at
	main.arena.kit.sw.add_puddle(at, 14.0)
	state["puddle"] = main.arena.zones.filter(func(z): return z["kind"] == "puddle")[-1]
	_cast_at(at, "spark", 40.0)


## Once the puddle is charged, a Hollow is put in it; it must take a shock.
func _shocked() -> bool:
	if float(state["puddle"].get("charge_t", 0.0)) > 0.0 and not state.has("hollow"):
		state["hollow"] = main.arena.spawn("hollow", state["at"])
		state["hollow"].stun = 5.0
	if state.has("hollow") and _logged("shock", "hollow"):
		_clear_enemies()
		return true
	return false


func _rewind_setup() -> void:
	for p in world.props:
		if p["kind"] == "crate" and p["pos"].distance_to(p["home"]) > 4.0:
			state["prop"] = p
			break
	if state["prop"]["pos"].distance_to(state["prop"]["home"]) < 4.0:
		state["prop"]["pos"] += Vector2(20, 0)
	state["prop"]["vel"] = Vector2.ZERO
	root.get_node("Progression").p["loop"] = 2  # Rewind comes back with you from loop 2
	_cast_at(state["prop"]["home"], "rewind", 70.0)


func _light_setup() -> void:
	_book(BOOK)
	var l := _street_lamp()
	world.light_lamp(l, "you")
	state["hollow_light"] = true
	state["lamp"] = l
	state["min_d"] = INF
	main.place_player(l["pos"] + Vector2(0, 6))
	var at: Vector2 = l["pos"]
	for k in 16:
		var p: Vector2 = l["pos"] + Vector2.from_angle(k * TAU / 16.0) * 100.0
		if not world.map.solid_at(p, 8.0) and not world.map.in_water(p, 8.0):
			at = p
			break
	state["hollow"] = main.arena.spawn("hollow", at)
	cast = {}


## The Hollow comes at you but stops at the edge of the light.
func _kept_off() -> bool:
	var u = state["hollow"]
	state["min_d"] = minf(state["min_d"], u.pos.distance_to(state["lamp"]["pos"]))
	main.arena.player.hp = main.arena.player.max_hp
	if t < LIGHT_WAIT:
		return false
	var r := float(world.pd["light_r"])
	var ok: bool = state["min_d"] >= r - 0.5 and state["min_d"] < r + 30.0
	print("[magic] the Hollow came within %.0f px of the lamp (pool %.0f)" % [state["min_d"], r])
	_clear_enemies()
	state.erase("hollow_light")
	if not ok:
		failures.append("the Hollow came within %.0f px of a lit lamp (pool %.0f), or never came" % [state["min_d"], r])
	return true


func _captain_setup() -> void:
	# The captain keeps the cordon just south of the College gate: fire from inside the gate.
	var p = world.people.get_person("captain")
	main.place_player(p.pos + Vector2(0, -40))
	main.arena.kit.aether = main.arena.kit.max_aether()
	main.arena.player.cd.clear()
	cast = {"slot": main.arena.kit.slot_of("ember_bolt"), "aim": p.pos, "f": 0}


func _lane_setup() -> void:
	run.learn("carried_out")  # her first talk (who carried you out) comes before any thanks
	for l in world.lamps:
		if l["group"] == "lane":
			state["lamp"] = l
			break
	state["lamp"]["lit"] = false
	_cast_at(state["lamp"]["pos"], "ember_bolt")


func _prop_of(kind: String, skip := {}) -> Dictionary:
	for p in world.props:
		if p["kind"] == kind and p["state"] == "" and p["integrity"] == "" and p != skip:
			return p
	return {}


func _cart_setup() -> void:
	_book(BOOK)
	state["prop"] = _prop_of("cart")
	_cast_at(state["prop"]["pos"], "pebble", 44.0)


func _break_setup() -> void:
	state["prop"] = _prop_of("crate")
	state["prop"]["integrity"] = "cracked"
	state["prop"]["hp"] = 1.0
	_cast_at(state["prop"]["pos"], "pebble")


func _barrel_setup() -> void:
	state["prop"] = _prop_of("barrel")
	state["prop"]["pos"] = _dark_spot()  # the camp's barrels stand against walls: roll one into the open
	_cast_at(state["prop"]["pos"], "ember_bolt")


func _wet_hay_setup() -> void:
	state["prop"] = _prop_of("hay")
	world.apply_force(state["prop"], "water", 1)
	_cast_at(state["prop"]["pos"], "ember_bolt")


func _spark_hay_setup() -> void:
	_book(STORM_BOOK)
	state["prop"] = _prop_of("hay", state["prop"])
	_cast_at(state["prop"]["pos"], "spark", 40.0)
