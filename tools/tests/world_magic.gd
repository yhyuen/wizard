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
## N-4.2 (the ground, spec §5): Pillar on grass sets the ground burning and it spreads; Splash
## puts a ground fire out; a Spark on wet ground charges it.
## N-4.3 (supports and collapse, spec §6.4): a Pebble breaks the leaning gallery's cracked post, and
## after its telegraph the gallery comes down on a Hollow under it and leaves slow rubble.
## N-5.1 (schools): standing still a breath before casting Pillar (Astral Rite's Alignment) puts
## its column further out than its listed range.
## N-5.2 (Spark Artifice): breaking a crate leaves glass you pick up; a Spark Flask spends a charge
## and sets grass burning; a Tar Pot's tar slows a Hollow and goes up when a flask lands in it; an
## empty device won't throw; the bench fills devices from reagents and takes the time of day.
## N-5.3 (the first combined spell): inside a Star Lantern's ring a Pillar begun at once, without
## standing still, is Aligned and reaches past its listed range.
## N-6.1 (enemy records, Break, the director): Impact from behind fills a Slinger's Break meter until
## it is Broken (it can't act and takes more damage); five Hollows round you never wind up more
## than two attacks at once.

const BOOK := ["ember_bolt", "pebble", "splash", "undertow"]
const STORM_BOOK := ["spark", "rewind", "splash", "ember_bolt"]
const GROUND_BOOK := ["pillar", "splash", "spark"]
const DEVICE_BOOK := ["spark_flask", "tar_pot", "arc_rod", "smoke_jar"]
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
		["a Pebble breaks a cracked crate, and you pick up its glass", _break_setup,
			func(): return state["prop"]["integrity"] == "broken" and int(slice.growth.reagents().get("glass", 0)) > state["glass"]],
		["an Ember Bolt at grade I only smoulders a barrel", _barrel_setup, func(): return state["prop"]["state"] == "smoulder"],
		["an Ember Bolt only steams wet hay", _wet_hay_setup,
			func(): return _logged("steam", "hay") and state["prop"]["state"] != "burning"],
		["a Spark sets hay alight", _spark_hay_setup, func(): return state["prop"]["state"] == "burning"],
		["Pillar on grass sets the ground burning, and it spreads", _grass_fire_setup,
			_spread],
		["Splash puts a ground fire out", _ground_douse_setup,
			func(): return world.events_log.any(func(e): return e[0] == "ground_doused")],
		["a Spark on wet ground charges it", _wet_ground_setup,
			func(): return world.events_log.any(func(e): return e[0] == "ground_charged")],
		["a Pebble breaks the gallery's post and it comes down on a Hollow", _gallery_setup, _crushed],
		["an Aligned Pillar reaches past its listed range", _align_setup, _far_column],
		["a Spark Flask spends a charge and sets grass burning", _flask_setup,
			func(): return int(slice.growth.devices()["spark_flask"]) == 2 and _logged_since("ground_fire")],
		["a Tar Pot slows a Hollow, and a flask sets the tar alight", _tar_setup, _tar_lit],
		["an empty device won't throw", _empty_setup, _no_throw],
		["the bench fills a flask (double reagents outside the school) and takes the time of day", _bench_setup, _benched],
		["inside a Star Lantern's ring a Pillar is Aligned without standing still", _lantern_setup, _lantern_column],
		["hits from behind fill a Slinger's Break meter until it is Broken", _break_meter_setup, _broken],
		["five Hollows round you take turns: no more than two wind up at once", _director_setup, _took_turns],
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
	if t > (LIGHT_WAIT + 20 if state.has("hollow_light") or state.has("long") else WAIT):
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
	for id in BOOK + STORM_BOOK + GROUND_BOOK:
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
	if int(cast.get("delay", 0)) > 0:
		cast["delay"] -= 1  # standing still first (Alignment)
		return out
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
	state["glass"] = int(slice.growth.reagents().get("glass", 0))
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


## A clear patch of grass (every cell round it grass), away from the lamps.
func _grass_spot() -> Vector2:
	var c = world.cells
	for i in c.mat.size():
		var p: Vector2 = c.centre(i)
		if c.within(p, 30.0).all(func(j): return c.mats[c.mat[j]] == "grass") and not world.map.solid_at(p, 30.0):
			return p
	return world.map.spots["market"]


func _grass_fire_setup() -> void:
	_book(GROUND_BOOK)
	state["at"] = _grass_spot()
	state["n"] = -1
	state["long"] = true  # Pillar winds up and waits before it erupts
	world.set_sky({"kind": "clear", "wind": 0, "dir": "N"}, {})  # a dry, still day, whatever the roll
	_cast_at(state["at"], "pillar", 60.0)


## Once the Pillar's own cells have caught, the fire must reach more than those.
func _spread() -> bool:
	var n: int = world.cells.burning.size() + world.cells.ash.size()
	if state["n"] < 0:
		if _logged("ground_fire", "grass"):
			state["n"] = n
		return false
	return n > state["n"]


func _ground_douse_setup() -> void:
	state.erase("long")
	world.burn_ground(state["at"], 12.0, 1)
	_cast_at(state["at"], "splash", 34.0)


func _wet_ground_setup() -> void:
	var at := _dark_spot()
	world.wet_ground(at, 40.0)
	_cast_at(at, "spark", 40.0)


func _gallery_setup() -> void:
	_book(BOOK)
	var st: Dictionary = world.structures[0]
	state["gallery"] = st
	state["long"] = true
	var post: Dictionary = st["supports"][0]
	post["integrity"] = "cracked"  # one Pebble already landed
	state["hollow"] = main.arena.spawn("hollow", st["rect"].get_center())
	state["hollow"].stun = 9.0
	_cast_at(post["pos"], "pebble", 44.0)


## The warning comes first (never shorter than the fair delay), then the crash and the rubble.
func _crushed() -> bool:
	var st: Dictionary = state["gallery"]
	if st["state"] == "falling" and not state.has("warned"):
		state["warned"] = float(st["t"])
	if st["state"] != "down":
		return false
	var ok: bool = state.get("warned", 0.0) >= 1.4 and _logged("crushed", "hollow") \
		and world.ground_speed(st["rect"].get_center()) < 1.0
	_clear_enemies()
	state.erase("long")
	return ok


func _align_setup() -> void:
	_book(GROUND_BOOK)
	state["long"] = true
	var at := _dark_spot()
	var far := float(root.get_node("Progression").spell("pillar")["range"]) * 1.25
	var target := at
	for k in 16:
		var p: Vector2 = at + Vector2.from_angle(k * TAU / 16.0) * far
		if not world.map.solid_at(p, 16.0) and world.map.clear_line(at, p, 2.0):
			target = p
			break
	main.place_player(at)
	main.arena.kit.aether = main.arena.kit.max_aether()
	main.arena.player.cd.clear()
	main.arena.kit.still_t = 0.0
	state["from"] = at
	cast = {"slot": main.arena.kit.slot_of("pillar"), "aim": target, "f": 0, "delay": 80}


func _far_column() -> bool:
	for z in main.arena.zones:
		if z["kind"] == "column" and z["pos"].distance_to(state["from"]) > float(root.get_node("Progression").spell("pillar")["range"]) + 10.0:
			state.erase("long")
			return true
	return false


# --- N-5.2: Spark Artifice -----------------------------------------------------------------

## A Lamplighter's book: the four devices, with charges.
func _devices(charges: Dictionary) -> void:
	for id in DEVICE_BOOK:
		run.soul["known"]["model_" + id] = 1
	for id in charges:
		slice.growth.devices()[id] = charges[id]
	_book(DEVICE_BOOK)


func _logged_since(kind: String) -> bool:
	return world.events_log.slice(state["log_n"]).any(func(e): return e[0] == kind)


## A patch of grass nothing has burned yet.
func _fresh_grass() -> Vector2:
	var c = world.cells
	for i in c.mat.size():
		var p: Vector2 = c.centre(i)
		if c.within(p, 30.0).all(func(j): return c.mats[c.mat[j]] == "grass" and c.fuel[j] > 0.0 and c.burn[j] <= 0.0) \
				and not world.map.solid_at(p, 30.0) and p.distance_to(state.get("at", Vector2.ZERO)) > 200.0:
			return p
	return world.map.spots["market"]


func _flask_setup() -> void:
	_clear_enemies()
	_devices({"spark_flask": 3, "tar_pot": 2})
	world.set_sky({"kind": "clear", "wind": 0, "dir": "N"}, {})
	state["log_n"] = world.events_log.size()
	_cast_at(_fresh_grass(), "spark_flask", 60.0)


func _tar_setup() -> void:
	var at := _dark_spot() + Vector2(0, 30)
	state["tar_at"] = at
	state["lit"] = int(main.arena.stats.get("tar_lit", 0))
	state.erase("slowed")
	state.erase("flask")
	state["hollow"] = main.arena.spawn("hollow", at)
	state["hollow"].stun = 9.0
	_cast_at(at, "tar_pot", 60.0)


## The tar lands and slows the Hollow standing in it; then a flask thrown into it sets it alight.
func _tar_lit() -> bool:
	if state["hollow"].slow_t > 0.0 and main.arena.zones.any(func(z): return z["kind"] == "tar"):
		state["slowed"] = true
	if state.has("slowed") and not state.has("flask") and cast["f"] > 8 and main.arena.kit.recover_t <= 0.0:
		state["flask"] = true
		main.arena.player.cd.clear()
		cast = {"slot": main.arena.kit.slot_of("spark_flask"), "aim": state["tar_at"], "f": 0}
	if int(main.arena.stats.get("tar_lit", 0)) > state["lit"]:
		_clear_enemies()
		return state.has("slowed")
	return false


func _empty_setup() -> void:
	slice.growth.devices()["spark_flask"] = 0
	state["empty_t"] = 0
	state.erase("threw")
	_cast_at(_dark_spot(), "spark_flask", 50.0)


func _no_throw() -> bool:
	if main.arena.zones.any(func(z): return z["kind"] == "throw"):
		state["threw"] = true
	state["empty_t"] += 1
	return state["empty_t"] > 40 and not state.has("threw") and int(slice.growth.devices()["spark_flask"]) == 0


func _bench_setup() -> void:
	cast = {}
	slice.growth.devices()["spark_flask"] = 0
	slice.growth.reagents()["oil"] = 2
	slice.growth.reagents()["glass"] = 5
	state["time"] = run.time()
	slice.after.clear()
	slice._effect("bench", "")


## An Apprentice never trained in Spark Artifice pays double: 2 oil fill one flask.
func _benched() -> bool:
	return int(slice.growth.devices()["spark_flask"]) == 1 and int(slice.growth.reagents()["oil"]) == 0 \
		and (slice.after.has("period") or run.time() != state["time"])


# --- N-5.3: the Star Lantern ---------------------------------------------------------------

func _lantern_setup() -> void:
	run.soul["schools"] = {"astral_rite": 2, "spark_artifice": 2}  # both mastered in earlier lives
	slice.growth.practice()["spark_flask"]["stage"] = 2
	slice.growth.practice()["ember_bolt"]["stage"] = 2
	run.soul["known"]["model_star_lantern"] = 1
	slice.growth.devices()["star_lantern"] = 1
	_book(["star_lantern", "pillar", "splash", "spark"])
	state["long"] = true
	state.erase("pillar")
	var at := _dark_spot()
	var far := float(root.get_node("Progression").spell("pillar")["range"]) * 1.25
	state["target"] = at
	for k in 16:
		var p: Vector2 = at + Vector2.from_angle(k * TAU / 16.0) * far
		if not world.map.solid_at(p, 16.0) and world.map.clear_line(at, p, 2.0):
			state["target"] = p
			break
	main.place_player(at)
	main.arena.kit.aether = main.arena.kit.max_aether()
	main.arena.player.cd.clear()
	state["from"] = at
	cast = {"slot": main.arena.kit.slot_of("star_lantern"), "aim": at + Vector2(12, 0), "f": 0}


## The lantern hangs; then a Pillar begun at once (no time to stand still) reaches further.
func _lantern_column() -> bool:
	var lit: bool = main.arena.zones.any(func(z): return z["kind"] == "lantern")
	if lit and not state.has("pillar") and main.arena.kit.recover_t <= 0.0 and main.arena.kit.wind.is_empty():
		state["pillar"] = true
		main.arena.kit.still_t = 0.0
		cast = {"slot": main.arena.kit.slot_of("pillar"), "aim": state["target"], "f": 0}
	return state.has("pillar") and _far_column()


# --- N-6.1: Break and the director ----------------------------------------------------------

func _break_meter_setup() -> void:
	cast = {}
	state.erase("long")
	_clear_enemies()
	var at := _dark_spot()
	main.place_player(at)
	var u = main.arena.spawn("slinger", at + Vector2(40, 0))
	u.state = "move"
	u.facing = 1.0  # facing away from you: your hits come from behind
	state["slinger"] = u
	state["hp0"] = 0.0


## Two Impact-2 hits from behind (30 each, on a 35 meter) break it; a Broken Slinger takes ×1.5.
func _broken() -> bool:
	var u = state["slinger"]
	var A = main.arena
	if u.broken_t <= 0.0:
		u.hp = u.max_hp
		u.reaction_t = 0.0
		u.stun = 0.0
		u.facing = 1.0
		A.hit(u, 1.0, 2, Vector2.RIGHT, 0.0)
		return false
	var before: float = u.hp
	A.hit(u, 4.0, 1, Vector2.RIGHT, 0.0)
	var ok: bool = u.locked() and is_equal_approx(before - u.hp, 6.0) and A.break_max(u) == 35.0
	_clear_enemies()
	return ok


func _director_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()  # the Star Lantern's light would keep these Hollows off
	var at := _dark_spot()
	main.place_player(at)
	main.arena.player.iframes = 99.0  # they may hit you; this case only counts their turns
	state["max_winding"] = 0
	state["frames"] = 0
	for k in 5:
		var h = main.arena.spawn("hollow", at + Vector2.from_angle(k * TAU / 5.0) * 14.0)
		h.state = "move"


func _took_turns() -> bool:
	var n: int = main.arena.enemies().filter(func(u): return u.state == "windup").size()
	state["max_winding"] = maxi(state["max_winding"], n)
	state["frames"] += 1
	if state["frames"] < 120:
		return false
	main.arena.player.iframes = 0.0
	_clear_enemies()
	return state["max_winding"] == 2
