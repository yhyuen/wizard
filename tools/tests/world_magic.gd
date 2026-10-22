extends SceneTree
## Magic meets the world (design/open-world/interactions.md): each case casts a real spell the way
## a player does (the slot pressed, aimed at the thing), in the camp, and checks what happened:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/world_magic.gd
##
## (WM_FROM=n in the environment skips the cases before index n.)
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
## N-6.2 (bodies and burning): an Ember Bolt sets a Hollow (a husk) alight and the fire spreads to
## the Hollow beside it; a soaked Hollow only dries.
## N-6.6 (armour and the Knights): an Oath Squire's mail halves a light hit and not a heavy one,
## and falls away when worn through; a Spark goes through a Shieldknight's iron shield, which fire
## doesn't burn; a Silencer's bell stops a spell inside its ring, and a heavy blow breaks it.
## N-6.7 (the cult's first cell): the first Acolyte runs for help, and catching it keeps the alarm
## down while letting it go brings two more; Splash washes out a Saboteur's oil before it's lit.
## N-4.4 (owners and witnesses): a crate broken in front of someone costs standing with its owner;
## one broken unseen is found by the next person to pass; its owner puts it back after a dawn or
## two; dousing someone's burning bale earns standing and fame.
## N-7.1.1 (the camp re-dressed): lightning on a lamp rail runs along the iron and flares that
## circuit's lamps in reach, and no other circuit's.
## N-7.1.2 (the fallen city): Bell Street's barricade smashed opens its gate, and mended it shuts;
## lightning at grade II on the depot's rail runs the winch (grade I doesn't); the glassworks'
## mirrors turned right by day open the loft and teach the fuse, and fire on the fuse opens it
## again; the Old Watch felled bridges the square's broken edge; Splash on the Archive gate's
## plaque washes the soot off.
## N-7.1.3 (the undercroft): the sluice drains the long channel (its water and wet cells go) and
## fills it again; shoving the counterweight crate opens the drain grate for good, and its exit up
## to the camp (and the camp's down) works from then on.
## N-7.1.4 (the Mill fields): the sluice drains the mill pond and the islet becomes a walk; Fire I
## burns the webs off an apple tree and leaves the tree standing.
## N-7.1.5 (the east road): Impact II breaks the bar across the waystation cellar's door and the
## door opens; breaking a quarry scaffold post brings the scaffold down on the ledge camp.
## N-7.3.2 (the cellar thing): the Kindle way's `ignite mill_cellar` sets the seed sacks burning.

const BOOK := ["ember_bolt", "pebble", "splash", "undertow"]
const STORM_BOOK := ["spark", "rewind", "splash", "ember_bolt"]
const GROUND_BOOK := ["pillar", "splash", "spark"]
const DEVICE_BOOK := ["spark_flask", "tar_pot", "arc_rod", "smoke_jar"]
const Lives := preload("res://scripts/game/lives.gd")
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
		["an Ember Bolt sets a Hollow alight, and it spreads to the one beside it", _husk_setup,
			func(): return int(main.arena.stats.get("set_alight", 0)) >= state["alight"] + 2],
		["a soaked Hollow only dries when fire hits it", _wet_husk_setup, _dried],
		["a Shieldman's shield stops a hit from the front, not from behind, and an Ember Bolt burns it away", _shield_setup,
			func(): return state["blocked"] and state["behind"] and state["s"].flags.get("shield_gone", false)],
		["an Ember Bolt on a Powder Monkey blows his keg, and it hurts the Cutthroat beside him", _keg_setup, _keg_blown],
		["the Brigand Captain's net roots you, and Blink gets you out", _net_setup, _netted],
		["with their Captain down, a hurt Shieldman kneels and is spared, and a hurt Cutthroat runs", _yield_setup, _yielded],
		["a Lantern-eater walks into a lit lamp's pool and smothers it", _eater_setup,
			func(): return not state["lamp"]["lit"] and _logged_since("smothered")],
		["a Choir's hum makes a Hollow firmer and faster, and a heavy hit hushes it", _choir_setup, _hummed],
		["a Broken Overdrawn Husk leaks Aether you can drink", _husk_setup_leak, _drank],
		["the Field Guide notes a Shieldman seen, its shield burned and it beaten, and keeps it next life", _guide_setup, _guided],
		["an Oath Squire's mail halves a light hit, not a heavy one, and falls away when worn through", _armour_setup,
			func(): return state["armoured"]],
		["a Spark goes through a Shieldknight's iron shield, which fire doesn't burn", _iron_setup, _conducted],
		["a Silencer's bell stops spells inside its ring, and a heavy blow breaks the bell", _bell_setup, _belled],
		["the first Acolyte runs for help: caught, no alarm; left alone, the alarm brings two more", _runner_setup, _alarmed],
		["Splash washes out a Saboteur's oil before it's lit; oil left alone goes up", _oil_setup, _oiled],
		["breaking a crate someone sees costs standing; one nobody sees is found later; its owner mends it", _deeds_setup, _deeds],
		["putting out a burning bale someone owns earns standing and fame", _good_setup, _good_deed],
		["lightning on a lamp rail runs along it: that circuit's lamps in reach flare, no other circuit's", _rail_setup, _rail_flared],
		["in the fallen city, Bell Street's barricade smashed opens its gate, and mended it shuts again", _barricade_setup, _barricaded],
		["lightning at grade II on the lamp depot's rail runs its winch and the shutter opens; grade I doesn't", _winch_setup, _winched],
		["the glassworks' mirrors turned right by day open the loft and teach the fuse; fire on the fuse opens it", _mirror_setup, _mirrored],
		["felling the Old Watch bridges the Sunken Square's broken edge", _watch_setup, _bridged],
		["Splash on the Archive gate's plaque washes its soot off", _plaque_setup, _plaque_clean],
		["in the undercroft, the sluice drains the long channel and fills it again", _sluice_setup, _sluiced],
		["shoving the counterweight opens the drain grate for good (a soul memory): its exits up and down work", _weight_setup, _weighted],
		["in the Mill fields, draining the pond at its sluice makes the islet a walk", _pond_setup, _pond_walk],
		["Fire I burns the webs off an apple tree and leaves the tree standing", _web_setup, _webs_gone],
		["in the Mill cellar, the Kindle way sets the seed sacks burning", _cellar_fire_setup, _cellar_burned],
		["on the east road, Impact II breaks the bar on the waystation cellar's door and it opens", _bar_setup, _cellar_open],
		["breaking a quarry scaffold post brings the scaffold down on the ledge camp", _scaffold_setup, _scaffold_down],
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
	# WM_FROM=n runs only the cases from index n on (while working on the last few)
	if OS.get_environment("WM_FROM") != "" and i < int(OS.get_environment("WM_FROM")):
		return _next()
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
	# the market is ringed with lamps and rails now (N-7.1.1): the open east side of the square,
	# away from lamps, rails and props
	return Vector2(1752, 1032)


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
		if l["group"] == "street" and not world.map.solid_at(l["pos"], 30.0):
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


# --- N-6.2: bodies and burning ---------------------------------------------------------------

## Two Hollows side by side, held still, a clear shot at the first.
func _two_hollows() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var at := _dark_spot() + Vector2(0, 20)
	state["alight"] = int(main.arena.stats.get("set_alight", 0))
	state["h1"] = main.arena.spawn("hollow", at)
	state["h2"] = main.arena.spawn("hollow", at + Vector2(0, 10))
	for h in [state["h1"], state["h2"]]:
		h.stun = 9.0
		h.max_hp = 200.0
		h.hp = 200.0
	_cast_at(at, "ember_bolt", 50.0)


func _husk_setup() -> void:
	_two_hollows()


func _wet_husk_setup() -> void:
	_two_hollows()
	state["h1"].wet_t = 30.0
	state["h2"].wet_t = 30.0


func _dried() -> bool:
	if state["h1"].wet_t > 0.0:
		return false
	var ok: bool = int(main.arena.stats.get("set_alight", 0)) == state["alight"] and state["h1"].burn_t <= 0.0
	_clear_enemies()
	return ok


# --- N-6.3: brigands ---------------------------------------------------------------------------

func _shield_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	var at := _dark_spot() + Vector2(0, 20)
	var s = A.spawn("shieldman", at)
	s.stun = 9.0
	s.max_hp = 200.0
	s.hp = 200.0
	state["s"] = s
	_cast_at(at, "ember_bolt", 50.0)
	# a knock straight at him from where you stand, then one from behind him
	var from_you: Vector2 = (s.pos - A.player.pos).normalized()
	state["blocked"] = not A.hit(s, 5.0, 1, from_you, 0.0) and s.hp == 200.0
	state["behind"] = A.hit(s, 5.0, 1, -from_you, 0.0) and s.hp < 200.0


func _keg_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	var at := _dark_spot() + Vector2(0, 20)
	state["kegs"] = int(A.stats.get("kegs_blown", 0))
	state["m"] = A.spawn("powder_monkey", at)
	state["c"] = A.spawn("cutthroat", at + Vector2(14, 0))
	for u in [state["m"], state["c"]]:
		u.stun = 9.0
	state["c"].max_hp = 200.0
	state["c"].hp = 200.0
	_cast_at(at, "ember_bolt", 50.0)
	A.player.iframes = 99.0  # stood a little close to the keg


func _keg_blown() -> bool:
	if int(main.arena.stats.get("kegs_blown", 0)) <= state["kegs"]:
		return false
	var ok: bool = state["m"].dead and state["c"].hp < 200.0
	main.arena.player.iframes = 0.0
	_clear_enemies()
	return ok


func _net_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	var A = main.arena
	var at := _dark_spot()
	main.place_player(at)
	A.player.iframes = 0.0
	A.kit.warding = false
	A.kit.blink_charges = 1
	var c = A.spawn("brigand_captain", at + Vector2(100, 0))
	c.state = "move"
	c.cd["attack"] = 99.0
	c.flags["volley_t"] = -99.0
	state["c"] = c
	state["netted"] = false


func _netted() -> bool:
	var A = main.arena
	if not state["netted"]:
		if not A.player.flags.has("net_t"):
			return false
		state["netted"] = A.move_speed(A.player) == 0.0
		A.kit.blink()
		return false
	var ok: bool = not A.player.flags.has("net_t") and A.move_speed(A.player) > 0.0
	_clear_enemies()
	return ok


# --- N-6.4: morale ---------------------------------------------------------------------------

func _yield_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	var A = main.arena
	A.morale.reset()
	var at := _dark_spot()
	main.place_player(at)
	A.player.iframes = 99.0
	state["spared"] = int(slice.run.life.get("spared", {}).get("brigands", 0))
	state["c"] = A.spawn("brigand_captain", at + Vector2(90, 0))
	state["s"] = A.spawn("shieldman", at + Vector2(-90, 0))
	state["t"] = A.spawn("cutthroat", at + Vector2(0, 90))
	for u in [state["c"], state["s"], state["t"]]:
		u.stun = 9.0
		u.state = "move"
	for u in [state["s"], state["t"]]:
		u.hp = u.max_hp * 0.2
	state["step"] = 0
	state["frames"] = 0


func _yielded() -> bool:
	var A = main.arena
	state["frames"] += 1
	match state["step"]:
		0:
			if state["frames"] < 10:
				return false
			# hurt, but their Captain stands and the side is whole: they fight on
			state["held"] = not state["s"].flags.has("yielded") and not state["t"].flags.has("fleeing")
			A.kill(state["c"])
			state["step"] = 1
			return false
		1:
			if state["t"].flags.has("fleeing"):
				state["t"].flags["fleeing"] = 0.2  # it runs; no need to watch it all the way off
				state["step"] = 2
			return false
	if not state["t"].dead:
		return false
	var knelt: bool = state["s"].flags.has("yielded") and state["s"].team == 2 and not A.enemies().has(state["s"])
	A.morale.settle(true)
	var spared: bool = int(slice.run.life.get("spared", {}).get("brigands", 0)) == state["spared"] + 1
	A.player.iframes = 0.0
	A.units = A.units.filter(func(u): return u.team == 0)
	return state["held"] and knelt and spared


# --- N-6.3: more Hollows -----------------------------------------------------------------------

func _eater_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	state["lamp"] = _street_lamp()
	state["lamp"]["by"] = ""
	state["lamp"]["lit"] = false
	world.light_lamp(state["lamp"], "town")
	state["log_n"] = world.events_log.size()
	main.place_player(state["lamp"]["pos"] + Vector2(0, 160))
	main.arena.player.iframes = 99.0
	var u = main.arena.spawn("lantern_eater", state["lamp"]["pos"] + Vector2(60, 0))
	u.state = "move"
	state["long"] = true  # it walks there, then takes its time


func _choir_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	var A = main.arena
	var at := _dark_spot()
	main.place_player(at)
	A.player.iframes = 99.0
	state["c"] = A.spawn("choir", at + Vector2(110, 0))
	state["h"] = A.spawn("hollow", at + Vector2(110, 30))
	state["c"].state = "move"
	state["h"].stun = 9.0
	state["step"] = 0
	state["frames"] = 0


func _hummed() -> bool:
	var A = main.arena
	var h = state["h"]
	state["frames"] += 1
	if state["step"] == 0:
		if not h.flags.has("hum_t"):
			return false
		state["firm"] = A.poise_of(h) == h.poise + 1 and A.move_speed(h) > h.speed
		A.hit(state["c"], 1.0, 2, Vector2.RIGHT, 0.0)  # above its Focus
		state["step"] = 1
		state["frames"] = 0
		return false
	if state["frames"] < 30:
		return false
	var ok: bool = state["firm"] and not h.flags.has("hum_t") and state["c"].cooldown("attack") > 0.0
	A.player.iframes = 0.0
	_clear_enemies()
	return ok


func _husk_setup_leak() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	var A = main.arena
	var at := _dark_spot()
	main.place_player(at + Vector2(0, 60))
	A.player.iframes = 99.0
	var u = A.spawn("husk", at)
	u.max_hp = 500.0
	u.hp = 500.0
	u.state = "move"
	while u.broken_t <= 0.0:
		A.hit(u, 1.0, 3, Vector2.DOWN, 0.0)
	A.kit.aether = 10.0
	state["drank"] = float(A.stats.get("drank", 0.0))
	main.place_player(at)


func _drank() -> bool:
	var A = main.arena
	if float(A.stats.get("drank", 0.0)) - state["drank"] < 19.9:
		return false
	var ok: bool = A.kit.aether >= 29.0
	A.player.iframes = 0.0
	_clear_enemies()
	return ok


# --- N-6.5: the Field Guide --------------------------------------------------------------------

func _guide_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	run.soul.erase("guide")
	var A = main.arena
	var at := _dark_spot() + Vector2(0, 20)
	var s = A.spawn("shieldman", at)
	s.stun = 9.0
	state["s"] = s
	state["seen"] = int(run.soul["guide"]["shieldman"]["seen"]) > 0
	_cast_at(at, "ember_bolt", 50.0)


func _guided() -> bool:
	var A = main.arena
	var s = state["s"]
	if not s.flags.get("shield_gone", false):
		return false
	A.kill(s)
	var e: Dictionary = run.soul["guide"]["shieldman"]
	var next: Dictionary = Lives.carry(run.soul, run.life, "test", run.lives)
	var kept: bool = next.get("guide", {}).has("shieldman")
	return state["seen"] and int(e["beaten"]) == 1 and "shield_burned" in e["found"] and kept


# --- N-6.6: armour and the Knights' picket ------------------------------------------------------

func _armour_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	var q = A.spawn("oath_squire", _dark_spot() + Vector2(0, 20))
	q.stun = 9.0
	q.max_hp = 200.0
	q.hp = 200.0
	var dir: Vector2 = (q.pos - A.player.pos).normalized()
	q.facing = -signf(dir.x) if absf(dir.x) > 0.1 else q.facing  # facing you: no from-behind Break
	A.hit(q, 10.0, 1, dir, 0.0)  # below mail's grade II: half gets through
	var light: float = 200.0 - q.hp
	var hp: float = q.hp
	q.brk = 0.0  # keep it from being Broken (Broken takes more): this is about the mail
	A.hit(q, 10.0, 2, dir, 0.0)  # at its grade: all of it
	var heavy: float = hp - q.hp
	q.brk = 0.0
	A.hit(q, 10.0, 1, dir, 0.0)  # 30 worn off its 25: sundered
	hp = q.hp
	q.brk = 0.0
	q.broken_t = 0.0
	A.hit(q, 10.0, 1, dir, 0.0)
	var bare: float = hp - q.hp
	var found: Array = run.soul["guide"]["oath_squire"]["found"]
	state["armoured"] = is_equal_approx(light, 5.0) and is_equal_approx(heavy, 10.0) and q.flags.get("sundered", false) \
		and is_equal_approx(bare, 10.0) and "sundered" in found


func _iron_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(STORM_BOOK)
	var A = main.arena
	var at := _dark_spot() + Vector2(0, 20)
	var k = A.spawn("shieldknight", at)
	k.stun = 9.0
	k.max_hp = 200.0
	k.hp = 200.0
	state["k"] = k
	_cast_at(at, "spark", 50.0)
	# fire from the front: the iron shield takes it and doesn't burn
	A._src_kind = "fire"
	state["iron"] = not A.hit(k, 5.0, 1, (k.pos - A.player.pos).normalized(), 0.0) and not k.flags.get("shield_gone", false)
	A._src_kind = ""


func _conducted() -> bool:
	var k = state["k"]
	return state["iron"] and k.hp < 200.0 and "conducted" in run.soul["guide"]["shieldknight"]["found"]


func _bell_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	main.place_player(_dark_spot())
	A.kit.aether = A.kit.max_aether()
	A.player.cd.clear()
	state["sil"] = A.spawn("silencer", A.player.pos + Vector2(70, 0))
	state["sil"].max_hp = 400.0
	state["sil"].hp = 400.0
	A.player.max_hp = 999.0
	A.player.hp = 999.0


func _belled() -> bool:
	var A = main.arena
	var sil = state["sil"]
	if not A.ai.knights.hushed(A.player.pos):
		return false
	A.kit.begin(A.kit.slot_of("ember_bolt"))
	var refused: bool = A.kit.wind.is_empty()
	A.hit(sil, 1.0, 3, (sil.pos - A.player.pos).normalized(), 0.0)
	return refused and sil.flags.get("bell_gone", false) and "bell_broken" in run.soul["guide"]["silencer"]["found"]


# --- N-6.7: the cult's first cell ----------------------------------------------------------------

func _runner_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	main.place_player(_dark_spot())
	A.stats.erase("runner_id")
	A.player.max_hp = 999.0
	A.player.hp = 999.0
	state["alarms"] = int(A.stats.get("alarms", 0))
	state["caught"] = A.spawn("acolyte", A.player.pos + Vector2(60, 0))
	state["caught"].state = "move"
	state["phase"] = 0


func _alarmed() -> bool:
	var A = main.arena
	var r = state["caught"]
	if state["phase"] == 0:
		if not r.flags.has("runner"):
			return false
		A.kill(r)  # caught it
		state["phase"] = 1
		state["found"] = "caught_runner" in run.soul["guide"]["acolyte"]["found"]
		A.stats.erase("runner_id")
		state["free"] = A.spawn("acolyte", A.player.pos + Vector2(60, 0))
		state["free"].state = "move"
		return false
	var f = state["free"]
	if f.flags.has("runner"):
		f.flags["runner"] = minf(float(f.flags["runner"]), 0.3)  # let it get away quickly
		return false
	var callers: int = A.enemies().filter(func(u): return u.flags.has("caller")).size()
	return state["found"] and int(A.stats.get("alarms", 0)) == state["alarms"] + 1 and callers == 2 and f.dead


func _oil_setup() -> void:
	_clear_enemies()
	main.arena.zones.clear()
	_book(BOOK)
	var A = main.arena
	var at := _dark_spot() + Vector2(0, 20)
	var s = A.spawn("saboteur", at + Vector2(90, 0))
	s.stun = 9.0
	state["far"] = at + Vector2(-80, -60)
	A.add_zone({"kind": "fuse", "owner": -1, "by": s.id, "pos": at, "r": 26.0, "delay": 2.0})
	A.add_zone({"kind": "fuse", "owner": -1, "by": s.id, "pos": state["far"], "r": 26.0, "delay": 1.0})
	state["defused"] = int(A.stats.get("defused", 0))
	_cast_at(at, "splash", 40.0)


func _oiled() -> bool:
	var A = main.arena
	var fuses: int = A.zones.filter(func(z): return z["kind"] == "fuse").size()
	var lit: bool = A.zones.any(func(z): return z["kind"] == "blaze" and z["pos"] == state["far"])
	return fuses == 0 and lit and int(A.stats.get("defused", 0)) == state["defused"] + 1 \
		and "defused" in run.soul["guide"]["saboteur"]["found"]


# --- N-4.4: owners and witnesses -----------------------------------------------------------------

## A prop of `kind` that someone owns, whole and unburnt, as far as can be from everyone.
func _owned_prop(kind: String, far: bool) -> Dictionary:
	var best := {}
	var score := -INF
	for p in world.props:
		if p["kind"] != kind or p["state"] != "" or p["integrity"] != "" or world.deeds.owner_of(p) == "":
			continue
		var near := INF
		for q in world.people.list:
			if q.on:
				near = minf(near, q.pos.distance_to(p["pos"]))
		var sc: float = near if far else -near
		if sc > score:
			score = sc
			best = p
	return best


func _someone() -> Object:
	for q in world.people.list:
		if q.on and not q.talking:
			return q
	return null


func _deeds_setup() -> void:
	_clear_enemies()
	var D = world.deeds
	var seen_crate := _owned_prop("crate", false)
	var owner: String = D.owner_of(seen_crate)
	var who = _someone()
	who.pos = seen_crate["pos"] + Vector2(24, 0)
	who.fade = 0.0
	state["owner"] = owner
	state["before"] = D.standing(owner)
	world.apply_force(seen_crate, "impact", 4, 4.0)
	state["seen"] = D.standing(owner) < state["before"] and who.bark != ""
	# one nobody sees: everyone well away first
	var lone := _owned_prop("crate", true)
	for q in world.people.list:
		if q.on and q.pos.distance_to(lone["pos"]) < 140.0:
			q.pos = lone["pos"] + (q.pos - lone["pos"]).normalized() * 140.0
	state["lone"] = lone
	state["lone_owner"] = D.owner_of(lone)
	state["unseen"] = (run.life.get("unseen", []) as Array).size()
	world.apply_force(lone, "impact", 4, 4.0)
	state["missed"] = (run.life.get("unseen", []) as Array).size() == state["unseen"] + 1
	state["sus"] = int(run.life.get("suspicion", {}).get(state["lone_owner"], 0))
	who.pos = lone["pos"] + Vector2(0, 30)  # someone comes by


func _deeds() -> bool:
	var D = world.deeds
	if int(run.life.get("suspicion", {}).get(state["lone_owner"], 0)) <= state["sus"]:
		return false
	var lone: Dictionary = state["lone"]
	run.life["day"] = run.day() + 3
	D.new_day()
	run.life["day"] = run.day() - 3
	return state["seen"] and state["missed"] and lone["integrity"] == "" and not lone.has("broke_day")


func _good_setup() -> void:
	_clear_enemies()
	var D = world.deeds
	var bale := _owned_prop("hay", false)
	state["bale"] = bale
	state["bale_owner"] = D.owner_of(bale)
	state["fame"] = int(run.life.get("fame", 0))
	world.ignite(bale)
	state["after_fire"] = D.standing(state["bale_owner"])
	_cast_at(bale["pos"], "splash", 40.0)


func _good_deed() -> bool:
	var D = world.deeds
	if state["bale"]["state"] == "burning":
		return false
	return D.standing(state["bale_owner"]) > state["after_fire"] and int(run.life.get("fame", 0)) == state["fame"] + 1


## A grade III strike on circuit C's rail (between the market and the square): the charge runs
## 240 px along the iron, so C's nearer lamps flare and its far end doesn't; A, B and D don't.
func _rail_setup() -> void:
	for l in world.lamps:
		l["flare_t"] = 0.0
	var at := Vector2(1284, 1044)
	state["at"] = at
	world.strike_ground(at, at, 3)


func _rail_flared() -> bool:
	var near := 0
	for l in world.lamps:
		var flared: bool = l["flare_t"] > 0.0
		if l["circuit"] == "C" and l["pos"].distance_to(state["at"]) < 200.0:
			near += 1
			if not flared:
				return false
		elif flared and (l["circuit"] != "C" or l["pos"].distance_to(state["at"]) > 280.0):
			return false
	return near >= 4


# --- the fallen city (N-7.1.2) -----------------------------------------------------------------

func _city_prop(tag: String) -> Dictionary:
	for p in world.props:
		if str(p.get("tag", "")) == tag:
			return p
	return {}


func _barricade_setup() -> void:
	world.load_map("city")
	slice.set_screen("world")
	main.enter_world(world.map.spots["sunken_square"])
	_clear_enemies()
	var p := _city_prop("barricade")
	state["shut"] = world.map.solid_at((world.map.doors["bell_barricade"]["rect"] as Rect2).get_center())
	world.apply_force(p, "impact", 2, 4.0)
	state["p"] = p
	state["phase"] = 0


func _barricaded() -> bool:
	var dr: Dictionary = world.map.doors["bell_barricade"]
	if state["phase"] == 0:
		if not dr["open"]:
			return false
		state["phase"] = 1
		world.mend(state["p"])  # its owner puts it back
		return false
	return state["shut"] and not dr["open"] and state["p"]["integrity"] == ""


func _winch_setup() -> void:
	var w: Array = world.map.doors["depot_shutter"]["winch"]
	state["w"] = Vector2(w[0], w[1])
	world.strike_ground(state["w"], state["w"], 1)
	state["weak"] = not world.map.doors["depot_shutter"]["open"]
	world.cells.charge.fill(0.0)
	world.strike_ground(state["w"], state["w"], 2)


func _winched() -> bool:
	var dr: Dictionary = world.map.doors["depot_shutter"]
	return state["weak"] and dr["open"] and dr.get("opened", false) and not world.map.solid_at((dr["rect"] as Rect2).get_center())


func _mirror_setup() -> void:
	var L: Dictionary = world.map.d["lens"]
	state["knew"] = run.knows(str(L["know"]))
	for tag in L["mirrors"]:
		var p := _city_prop(tag)
		for k in int(L["mirrors"][tag]):
			world.apply_force(p, "impact", 1, 1.0)
	state["phase"] = 0


func _mirrored() -> bool:
	var L: Dictionary = world.map.d["lens"]
	var dr: Dictionary = world.map.doors[str(L["door"])]
	if state["phase"] == 0:
		if not dr["open"] or not run.knows(str(L["know"])):
			return false
		state["phase"] = 1
		# a later life: the mirrors are back as they were, but you know where the fuse is
		dr["open"] = false
		dr.erase("opened")
		for tag in L["mirrors"]:
			_city_prop(tag)["turn"] = 0
		world.burn_ground(Vector2(L["fuse"][0], L["fuse"][1]), 12.0, 1)
		return false
	return not state["knew"] and dr["open"]


func _watch_setup() -> void:
	var post := {}
	for p in world.props:
		if p.get("holds", "") == "old_watch":
			post = p
	state["edge"] = Vector2(2124, 1150)
	state["pit"] = world.map.in_pit(state["edge"])
	world.apply_force(post, "impact", 3, 4.0)
	state["long"] = true


func _bridged() -> bool:
	return state["pit"] and not world.map.in_pit(state["edge"]) and world.structures[0]["state"] == "down"


func _plaque_setup() -> void:
	state.erase("long")
	_book(BOOK)
	var at: Vector2 = world.map.items["archive_plaque"]["at"]
	_cast_at(at + Vector2(0, 14), "splash", 50.0)


func _plaque_clean() -> bool:
	return run.flag("plaque_clean") and run.knows("archive_key")


# --- the undercroft (N-7.1.3) -------------------------------------------------------------------

func _sluice_setup() -> void:
	world.load_map("undercroft")
	slice.set_screen("world")
	main.enter_world(world.map.spots["drain_stair"])
	_clear_enemies()
	state["mid"] = Vector2(690, 516)
	state["wet"] = world.map.in_water(state["mid"]) and world.cells.material_at(state["mid"]) == "water"
	run.set_flag("channel_dry")
	state["phase"] = 0


func _sluiced() -> bool:
	var dry: bool = not world.map.in_water(state["mid"]) and world.cells.material_at(state["mid"]) != "water"
	if state["phase"] == 0:
		if not dry:
			return false
		state["phase"] = 1
		run.life["flags"].erase("channel_dry")
		return false
	return state["wet"] and world.map.in_water(state["mid"]) and world.cells.material_at(state["mid"]) == "water"


func _weight_setup() -> void:
	state["shut"] = not world.exit_open("grate_up")
	var crate := _city_prop("counterweight")
	state["crate"] = crate
	world.shove(crate, Vector2.LEFT, 4.0)
	state["phase"] = 0


func _weighted() -> bool:
	if not run.knows("drain_open"):
		var crate: Dictionary = state["crate"]
		if crate["vel"].length() < 1.0 and state["phase"] < 20:
			state["phase"] += 1
			world.shove(crate, (Vector2(1135, 620) - crate["pos"]).normalized(), 2.0)
		return false
	var camp_side: bool = world.get_map("camp").exits["drain_down"]["opened_by"] == "drain_open"
	return state["shut"] and world.exit_open("grate_up") and camp_side and run.knows("drain_open")


# --- the Mill fields (N-7.1.4) -----------------------------------------------------------------

func _pond_setup() -> void:
	world.load_map("fields")
	slice.set_screen("world")
	main.enter_world(world.map.spots["mill_bridge"])
	_clear_enemies()
	state["wade"] = Vector2(1030, 560)  # deep water between the bank and the islet
	state["deep"] = world.map.blocked(state["wade"])
	run.set_flag("pond_dry")


func _pond_walk() -> bool:
	if world.map.blocked(state["wade"]):
		return false
	var route: PackedVector2Array = world.map.path(world.map.spots["mill_pond"], world.map.spots["pond_islet"], 7.0)
	return state["deep"] and route.size() > 0 and route[route.size() - 1] == world.map.spots["pond_islet"]


func _web_setup() -> void:
	run.life["flags"].erase("pond_dry")
	var web := {}
	for p in world.props:
		if p["kind"] == "web":
			web = p
			break
	var tree := {}
	for p in world.props:
		if p["kind"] == "apple_tree" and (tree.is_empty() or p["pos"].distance_to(web["pos"]) < tree["pos"].distance_to(web["pos"])):
			tree = p
	state["web"] = web
	state["tree"] = tree
	world.apply_force(web, "fire", 1)
	state["long"] = true


func _webs_gone() -> bool:
	if state["web"]["state"] != "ash":
		return false
	return state["tree"]["state"] != "burning" and state["tree"]["state"] != "ash"


# --- the cellar thing (N-7.3.2): the story's ignite effect -------------------------------------

func _cellar_fire_setup() -> void:
	state.erase("long")
	main.enter_world(world.map.spots["mill_cellar"])
	_clear_enemies()
	slice.play("cellar_fire")
	slice.finish_scene()


func _cellar_burned() -> bool:
	var seed: Array = world.props.filter(func(p): return str(p.get("tag", "")).begins_with("seed_"))
	return seed.size() == 4 and seed.all(func(p): return p["state"] in ["burning", "ash"])


# --- the east road (N-7.1.5) -------------------------------------------------------------------

func _bar_setup() -> void:
	state.erase("long")
	world.load_map("east_road")
	slice.set_screen("world")
	main.enter_world(world.map.spots["waystation"])
	_clear_enemies()
	var bar := {}
	for p in world.props:
		if str(p.get("tag", "")) == "cellar_bar":
			bar = p
	state["shut"] = not world.map.doors["cellar_door"]["open"]
	world.apply_force(bar, "impact", 2, 4.0)


func _cellar_open() -> bool:
	var dr: Dictionary = world.map.doors["cellar_door"]
	return state["shut"] and dr["open"] and not world.map.solid_at((dr["rect"] as Rect2).get_center())


func _scaffold_setup() -> void:
	var post := {}
	for p in world.props:
		if p.get("holds", "") == "quarry_scaffold":
			post = p
	world.apply_force(post, "impact", 3, 4.0)
	state["long"] = true


func _scaffold_down() -> bool:
	for st in world.structures:
		if st["id"] == "quarry_scaffold":
			return st["state"] == "down"
	return false
