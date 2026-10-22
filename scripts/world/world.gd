extends RefCounted
## Vellmar in play (design/open-world/, design/ruins/): the clock, the people, the items, the
## lamps and props, and what magic does to them, on whichever map you stand: the survivors' camp
## or a layer of the ruin (data/world/maps.json). The arena (scripts/arena.gd) still runs the
## wizard, the spells and the fights; this reads its spells each tick and answers with the world's
## reactions: fire lights lamps and sets hay and crates burning, water puts them out, force
## shoves crates and barrels.
##
## Each map keeps its own props, lamps and scorches for the rest of the loop, so a lamp you lit in
## the halls is still lit if you go up and come back. People live in the camp only.
##
## The world never plays a scene itself. It asks the game (scripts/game/slice.gd) through
## `requests`: {"t": "talk", "id"} / {"t": "use", "id"} / {"t": "arrive", "place"} /
## {"t": "scene", "id"} / {"t": "cast", "item", "element"} / {"t": "exit", "id"} / {"t": "period"}.

const Map := preload("res://scripts/world/map.gd")
const People := preload("res://scripts/world/people.gd")
const Matter := preload("res://scripts/world/matter.gd")
const Cells := preload("res://scripts/world/cells.gd")
const MAPS := "res://data/world/maps.json"
const CAMP := "camp"

var map
var map_id := CAMP
var maps: Dictionary  # data/world/maps.json "maps"
var _maps := {}  # map id -> Map, built once
var _saved := {}  # map id -> this loop's {props, lamps, braziers, scorches} while you're elsewhere
var _in_exit := ""  # the exit you stand in (an exit asks once, when you step into it)
var people
var arena
var run  # the Run autoload
var story
var cfg: Dictionary  # data/world/world.json
var pd: Dictionary  # data/world/props.json
var matter  # scripts/world/matter.gd: what a force does to a material
var gd: Dictionary  # data/world/ground.json
var cells  # scripts/world/cells.gd: this map's ground, where fire, water and charge spread
var sky := {}  # today's weather here (scripts/world/weather.gd `on`), set by the game
var sky_kinds := {}  # data/world/weather.json "kinds"
var _cell_t := 0.0
var _shock_t := 0.0
var _fire_zones := {}  # burning cell -> its flame zone in the arena
var requests: Array = []
var busy: Callable  # func() -> bool: the game is showing a scene or a menu

var clock := 0.0  # seconds into this time of day
var here := ""  # the place the wizard is in
var lamps: Array = []  # {"pos", "group", "lit", "by"}
var braziers: Array = []  # {"pos", "lit"}
var props: Array = []  # {"kind", "pos", "vel", "rot", "home", "state" ("", "burning", "ash"), "burn_t", "embers"}
var scorches: Array = []  # {"pos", "dir"}: star-shaped burns on walls
var fire_proj := {}  # the marks that carry fire (data/materials.json carriers)
var events_log: Array = []  # what magic did, for tests: [kind, what]
var pools: Array = []  # where a lit or flaring lamp's light keeps Hollows off, rebuilt each tick
var light_shy := {}

## Flags the world sets itself (not a story scene), for the story checks.
const FLAGS := ["lit_lane"]


func _init(the_run, the_story) -> void:
	run = the_run
	story = the_story
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPS))
	maps = reg["maps"]
	map_id = str(reg.get("start", CAMP))
	map = get_map(map_id)
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world.json"))
	pd = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/props.json"))
	matter = Matter.new()
	gd = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/ground.json"))
	for k in matter.kinds_of("fire"):
		fire_proj[k] = true
	for k in pd["light_shy"]:
		light_shy[k] = true
	map.movers = movers
	people = People.new(self)
	_build_lamps()
	reset_loop()


## The map `id` (data/world/maps.json), built the first time it's asked for.
func get_map(id: String):
	if not _maps.has(id):
		var def: Dictionary = maps[id]
		_maps[id] = Map.new(str(def["path"]), id, str(def.get("kit", "town")))
		_maps[id].set_day_doors(run.day())
	return _maps[id]


func map_def(id := "") -> Dictionary:
	return maps.get(map_id if id == "" else id, {})


func in_camp() -> bool:
	return map_id == CAMP


## Steps onto map `id`: this map's props, lamps and scorches are kept for the loop, and the new
## one's come back as you left them (or as they were this morning). Doesn't move the wizard: the
## game does that (slice.gd go_map), with the arena and the view.
func load_map(id: String) -> void:
	if id == map_id:
		return
	_saved[map_id] = {"props": props, "lamps": lamps, "braziers": braziers, "scorches": scorches, "cells": cells}
	_drop_fire_zones()
	map.movers = Callable()
	map_id = id
	map = get_map(id)
	map.movers = movers
	var st: Dictionary = _saved.get(id, {})
	if st.is_empty():
		props = []
		scorches = []
		_build_lamps()
		_fresh_props()
		_fresh_cells()
	else:
		props = st["props"]
		lamps = st["lamps"]
		braziers = st["braziers"]
		scorches = st["scorches"]
		cells = st["cells"]
	_apply_sky()
	_in_exit = ""
	here = ""
	_cache_movers()
	people.think(true)


func _build_lamps() -> void:
	lamps = []
	var lane_i := 0
	for l in map.d.get("lamps", []):
		var lamp := {"pos": Vector2(l[0], l[1]), "group": str(l[2]), "lit": false, "by": "", "flare_t": 0.0,
			"iron": str(l[2]) in pd["iron_lamps"]}
		if lamp["group"] == "lane":
			lamp["id"] = "lane_lamp_%d" % lane_i
			lane_i += 1
		lamps.append(lamp)
	braziers = []
	for b in map.d.get("braziers", []):
		# [x, y] waits for fire; [x, y, true] is a cook fire kept burning, lit again each dawn
		braziers.append({"pos": Vector2(b[0], b[1]), "lit": b.size() > 2 and bool(b[2]), "kept": b.size() > 2 and bool(b[2])})


func _fresh_props() -> void:
	props = []
	for p in map.d.get("props", []):
		props.append({"kind": str(p[0]), "pos": Vector2(p[1], p[2]), "home": Vector2(p[1], p[2]), "vel": Vector2.ZERO,
			"rot": float(p[3]), "spin": 0.0, "state": "", "burn_t": 0.0, "embers": [],
			"hp": float(prop_def(str(p[0])).get("hp", 1)), "integrity": "", "wet_t": 0.0, "heat_t": 0.0})


func _fresh_cells() -> void:
	_drop_fire_zones()
	var def: Dictionary = gd["maps"].get(map_id, {"default": "stone", "indoors": true})
	def["cell"] = gd["cell"]
	cells = Cells.new(map, def, gd["spread"], matter.d["materials"])
	cells.rng.seed = hash(map_id)
	_apply_sky()


## Today's weather here, for the ground (seasons spec §4): the game calls this at dawn and on
## arriving in a region.
func set_sky(w: Dictionary, kinds: Dictionary) -> void:
	sky = w
	sky_kinds = kinds
	_apply_sky()


func _apply_sky() -> void:
	if cells == null:
		return
	var k: Dictionary = sky_kinds.get(str(sky.get("kind", "")), {})
	cells.wind = int(sky.get("wind", 0))
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var di := dirs.find(str(sky.get("dir", "N")))
	# The wind blows from its direction: from the N toward the S (+y).
	cells.downwind = Vector2.from_angle(-PI / 2.0 + di * PI / 4.0) * -1.0 if di >= 0 else Vector2.ZERO
	cells.fire_k = float(k.get("fire_spread", 1.0))
	cells.raining = bool(k.get("wet", false))


## Waking on day 1: everything the last loop burnt, shoved or took is back where it was, on
## every map, and you are in the camp.
func reset_loop() -> void:
	_saved.clear()
	if map_id != CAMP:
		map.movers = Callable()
		map_id = CAMP
		map = get_map(CAMP)
		map.movers = movers
	_fresh_props()
	_fresh_cells()
	_build_lamps()
	scorches = []
	events_log.clear()
	for m in _maps.values():
		for did in m.doors:
			m.doors[did]["open"] = m.doors[did]["state"] == "open"
	_in_exit = ""
	_cache_movers()


## A new day (dawn): the lamps are out, the cook fires lit, people go to their morning spots.
func reset_day() -> void:
	clock = 0.0
	for m in _maps.values():
		m.set_day_doors(run.day())
	for l in lamps:
		l["lit"] = false
		l["by"] = ""
		l["flare_t"] = 0.0
	for b in braziers:
		b["lit"] = b["kept"]
	people.reset_day()
	here = map.place_at(player_pos())
	_in_exit = map.exit_at(player_pos())


func player_pos() -> Vector2:
	if arena == null or arena.player == null:
		return map.spots.get("cot", map.bounds.get_center())
	return arena.player.pos


func request(r: Dictionary) -> void:
	for q in requests:
		if q == r:
			return
	requests.append(r)


## Whether something may start a conversation now (nothing else is showing or waiting).
func can_start() -> bool:
	return requests.is_empty() and not (busy.is_valid() and busy.call()) and arena != null and arena.phase == "explore"


func period_s() -> float:
	return float(cfg["period_s"])


## How much of this time of day is left, 1 .. 0.
func period_left() -> float:
	return clampf(1.0 - clock / period_s(), 0.0, 1.0)


# --- every tick (called by the arena after its own) ----------------------------------

func tick(dt: float) -> void:
	if arena == null:
		return
	var exploring: bool = arena.phase == "explore"
	if exploring and bool(cfg.get("walk_clock", true)) and not (busy.is_valid() and busy.call()) and map_def().get("clock", true):
		clock += dt
		if clock >= period_s():
			clock = period_s()
			request({"t": "period"})
	people.update(dt)
	_props(dt)
	_cache_movers()
	_magic()
	_lamps_by_time()
	_lightning(dt)
	_ground(dt)
	_light_pools()
	var now: String = map.place_at(player_pos())
	if now != here:
		here = now
		if exploring:
			request({"t": "arrive", "place": now})
	# An exit asks once as you step into it; step out and back in to ask again.
	var ex: String = map.exit_at(player_pos())
	if ex != _in_exit:
		_in_exit = ex
		if ex != "" and exploring:
			request({"t": "exit", "id": ex})


## The College and the main streets come on at dusk; the lane waits for Mira; the ruin's lamps
## only by fire.
func _lamps_by_time() -> void:
	var t: int = run.time()
	for l in lamps:
		if t >= 3 and l["group"] in ["college", "street"] and not l["lit"] and l["by"] != "doused":
			l["lit"] = true
			l["by"] = "town"


func light_lamp(l: Dictionary, by: String) -> void:
	if l["lit"]:
		return
	l["lit"] = true
	l["by"] = by
	events_log.append(["lit", l.get("id", l["group"])])
	if by == "you" and l["group"] == "lane" and not run.flag("lit_lane"):
		# Mira's lane, lit before she got to it: she notices (and says so later, if not now).
		run.set_flag("lit_lane")
		var m = people.get_person("mira")
		if m != null and m.on and m.pos.distance_to(player_pos()) < float(cfg["bark_range"]):
			people.say(m, str(people.d["reactions"]["mira_thanks"]))


## Whether a lamp gives light now: lit, or flaring from lightning.
func lamp_on(l: Dictionary) -> bool:
	return l["lit"] or l["flare_t"] > 0.0


## Lamps lit now near a point, for the light they give (and, in OW2, for keeping Hollows off).
func lit_lamps_near(p: Vector2, r: float) -> Array:
	return lamps.filter(func(l): return lamp_on(l) and l["pos"].distance_to(p) < r)


func _light_pools() -> void:
	pools = []
	for l in lamps:
		if lamp_on(l):
			pools.append(l["pos"])


## Where a light-shy enemy at `p` may stand: pushed out to the edge of any lamp's pool it is in
## (a lit street is a safe street at night). The arena asks this for every enemy it moves.
func out_of_light(kind: String, p: Vector2, r: float) -> Vector2:
	if pools.is_empty() or not light_shy.has(kind):
		return p
	var lr := float(pd["light_r"]) + r
	for c in pools:
		var to: Vector2 = p - c
		if to.length_squared() < lr * lr:
			p = c + (to.normalized() if to.length_squared() > 0.01 else Vector2.UP) * lr
	return p


## Lightning: flaring lamps fade back, and charged puddles shock whoever stands in them.
func _lightning(dt: float) -> void:
	for l in lamps:
		if l["flare_t"] > 0.0:
			l["flare_t"] = maxf(0.0, l["flare_t"] - dt)
	for z in arena.zones:
		if z["kind"] != "puddle" or float(z.get("charge_t", 0.0)) <= 0.0:
			continue
		z["charge_t"] -= dt
		z["shock_t"] = float(z.get("shock_t", 0.0)) - dt
		if z["shock_t"] > 0.0:
			continue
		z["shock_t"] = float(pd["shock_every"])
		for u in arena.enemies():
			if u.pos.distance_to(z["pos"]) < float(z["r"]):
				arena.kit.sw.storm_hit(u, float(pd["shock_damage"]), 1, Vector2.ZERO, 0.0, "spark", 0.0)
				arena.fx("zap", z["pos"], {"to": u.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.1, "_w": true})
				events_log.append(["shock", u.kind])


## Lightning along a segment: iron lamps it passes flare, puddles it touches take the charge.
func _storm_line(a: Vector2, b: Vector2, kind: String) -> void:
	for l in lamps:
		if l["iron"] and Geometry2D.get_closest_point_to_segment(l["pos"], a, b).distance_to(l["pos"]) < float(pd["lamp_reach"]):
			l["flare_t"] = float(pd["flare_s"])
			events_log.append(["flare", l.get("id", l["group"])])
	for z in arena.zones:
		if z["kind"] == "puddle" and not z.get("millrace", false) \
				and Geometry2D.get_closest_point_to_segment(z["pos"], a, b).distance_to(z["pos"]) < float(z["r"]):
			z["charge_t"] = float(pd["charge_s"])
			events_log.append(["charged", "puddle"])
	for pr in props:
		if Geometry2D.get_closest_point_to_segment(pr["pos"], a, b).distance_to(pr["pos"]) < float(prop_def(pr["kind"])["r"]):
			hit_prop(pr, kind)
	strike_ground(a, b, grade_of(kind))


# --- the ground: fire, water and charge on the cells (spells-and-environment spec §5) ------

## Fire at `grade` on the ground within `r` of `at`: cells with fuel catch, wet ones steam.
## Returns how many caught.
func burn_ground(at: Vector2, r: float, grade: int) -> int:
	if cells == null:
		return 0
	var n := 0
	var steamed := false
	for i in cells.within(at, r):
		match cells.fire(i, grade):
			"burn":
				n += 1
			"steam":
				steamed = true
	if steamed:
		arena.fx("dust", at, {"r": r + 6.0, "life": 0.6})
	if n > 0:
		events_log.append(["ground_fire", cells.material_at(at)])
		_sync_fire_zones()
	return n


## Water on the ground: within `r` of `at`, inside `cone` (radians) round `dir`. Puts out the
## cells' fires and wets them. Returns how many fires it put out.
func wet_ground(at: Vector2, r: float, dir := Vector2.RIGHT, cone := TAU) -> int:
	if cells == null:
		return 0
	var n := 0
	for i in cells.within(at, r):
		var to: Vector2 = cells.centre(i) - at
		if cone < TAU and to.length() > cells.size * 0.5 and absf(dir.angle_to(to)) > cone * 0.5 + 0.2:
			continue
		if cells.douse(i):
			n += 1
	if n > 0:
		events_log.append(["ground_doused", n])
		_sync_fire_zones()
	return n


## Lightning along a segment strikes each cell under it: a wet or metal cell fills its network.
func strike_ground(a: Vector2, b: Vector2, grade: int) -> int:
	if cells == null:
		return 0
	var hit := {}
	var steps := maxi(1, int(ceil(a.distance_to(b) / (cells.size * 0.5))))
	for s in steps + 1:
		var i: int = cells.index(a.lerp(b, float(s) / steps))
		if i < 0 or hit.has(i) or cells.charge[i] > 0.0:
			continue
		for c in cells.strike(i, grade):
			hit[c] = true
	if not hit.is_empty():
		events_log.append(["ground_charged", hit.size()])
	_sync_fire_zones()
	return hit.size()


## A shot of yours that ends (runs out or hits something): fire lights the ground it falls on.
func on_spent(p: Dictionary) -> void:
	if p.get("team", 0) == 0 and not p.get("ghost", false) and fire_proj.has(p["kind"]):
		burn_ground(p["pos"], 0.0, grade_of(p["kind"]))


func _ground(dt: float) -> void:
	if cells == null:
		return
	_cell_t += dt
	if _cell_t >= 0.25:
		var res: Dictionary = cells.tick(_cell_t)
		_cell_t = 0.0
		if not res["ash"].is_empty():
			events_log.append(["ground_ash", res["ash"].size()])
		for i in res["out"]:
			arena.fx("dust", cells.centre(i), {"r": 8.0, "life": 0.8})
		# A burning prop lights the ground under it; a burning cell, the props standing on it.
		for p in props:
			var i: int = cells.index(p["pos"])
			if i < 0:
				continue
			if p["state"] == "burning":
				cells.fire(i, 1)
			elif cells.burn[i] > 0.0 and p["state"] == "" and p["wet_t"] <= 0.0:
				apply_force(p, "fire", 1)
		_sync_fire_zones()
	# Standing in fire burns and a charged cell shocks, foe or wizard (you take self_k of it).
	_shock_t -= dt
	if _shock_t > 0.0:
		return
	var sp: Dictionary = gd["spread"]
	_shock_t = float(sp["shock_every"])
	var fire_hit := float(sp["fire_dps"]) * float(sp["shock_every"])
	for u in arena.enemies():
		var i: int = cells.index(u.pos)
		if i < 0:
			continue
		if cells.charge[i] > 0.0:
			arena.kit.sw.storm_hit(u, float(sp["shock"]), 1, Vector2.ZERO, 0.0, "spark", 0.0)
			arena.fx("zap", cells.centre(i), {"to": u.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.1, "_w": true})
			events_log.append(["shock", u.kind])
		if cells.burn[i] > 0.0:
			arena._src_kind = "fire"
			arena.hit(u, fire_hit, -1, Vector2.ZERO, 0.0, true)
			arena._src_kind = ""
	var me = arena.player
	if me != null and not me.dead:
		var i: int = cells.index(me.pos)
		if i >= 0 and cells.charge[i] > 0.0:
			arena.hit(me, float(sp["shock"]) * float(sp["self_k"]), -1, Vector2.ZERO, 0.0, true)
		if i >= 0 and cells.burn[i] > 0.0:
			arena.hit(me, fire_hit * float(sp["self_k"]), -1, Vector2.ZERO, 0.0, true)


## Keeps one flame in the arena for every burning cell (the arena draws and the view lights
## them; the arena forgets its zones when you change maps, so this puts them back).
func _sync_fire_zones() -> void:
	if cells == null or arena == null:
		return
	for i in _fire_zones.keys():
		if cells.burn[i] <= 0.0:
			arena.zones.erase(_fire_zones[i])
			_fire_zones.erase(i)
	for i in cells.burning:
		if _fire_zones.has(i) and arena.zones.has(_fire_zones[i]):
			continue
		var jit := Vector2(fmod(i * 7.3, 9.0) - 4.5, fmod(i * 3.1, 9.0) - 4.5)
		_fire_zones[i] = arena.add_zone({"kind": "ember", "pos": cells.centre(i) + jit, "life": 1.0e9, "world": true, "cell": i})


func _drop_fire_zones() -> void:
	if arena != null:
		for z in _fire_zones.values():
			arena.zones.erase(z)
	_fire_zones.clear()


## The ground's marks for the arena's decal layer, near `at`: soft blots of ash, water and fire,
## and a crackle on charged cells (overlapping blots read as one patch, not a grid).
func draw_ground(g: CanvasItem, at: Vector2, r: float) -> void:
	if cells == null:
		return
	var s: float = cells.size
	for i in cells.ash:
		var c: Vector2 = cells.centre(i)
		if c.distance_to(at) < r:
			g.draw_circle(c, s * 0.7, Color(0.04, 0.03, 0.03, 0.45), true, -1.0, true)
	var now := Time.get_ticks_msec() * 0.001
	for i in cells.active:
		var c: Vector2 = cells.centre(i)
		if c.distance_to(at) >= r:
			continue
		if cells.burn[i] > 0.0:
			g.draw_circle(c, s * 0.68, Color(PixelArt.FIRE, 0.28), true, -1.0, true)
		elif cells.wet[i] > 0.0:
			g.draw_circle(c, s * 0.68, Color(PixelArt.WATER, 0.22 * clampf(cells.wet[i] / 4.0, 0.3, 1.0)), true, -1.0, true)
		if cells.charge[i] > 0.0:
			var k := int(now * 12.0 + i) % 3
			var a := c + Vector2(-s * 0.35, (k - 1) * s * 0.2)
			var pts := PackedVector2Array([a, a + Vector2(s * 0.2, -s * 0.15), a + Vector2(s * 0.4, s * 0.12), a + Vector2(s * 0.7, -s * 0.05)])
			g.draw_polyline(pts, Color(PixelArt.STORM, 0.9), 1.0, true)


# --- props ----------------------------------------------------------------------------

func prop_def(kind: String) -> Dictionary:
	return pd["kinds"].get(kind, {})


## Solid props for the collision of everything that walks, rebuilt once a tick (collision asks
## for it twice per unit per frame, and a horde at the north door is dozens of units).
var _movers: Array = []


func movers() -> Array:
	return _movers


func _cache_movers() -> void:
	_movers = []
	for p in props:
		if p["state"] != "ash" and p["integrity"] != "broken":
			_movers.append([p["pos"], float(prop_def(p["kind"])["r"])])


func _props(dt: float) -> void:
	var sh: Dictionary = pd["shove"]
	for p in props:
		var def := prop_def(p["kind"])
		if p["vel"].length() > 1.0:
			var r := float(def["r"])
			var want: Vector2 = p["pos"] + p["vel"] * dt
			# Out of walls and houses (not out of the other props: they get knocked on instead).
			var saved: Callable = map.movers
			map.movers = Callable()
			var got: Vector2 = map.collide(want, r)
			map.movers = saved
			if got.distance_to(want) > 0.5:
				p["vel"] *= 0.3
			p["pos"] = got
			for q in props:
				if q != p and q["state"] != "ash" and q["pos"].distance_to(p["pos"]) < r + float(prop_def(q["kind"])["r"]):
					var push: Vector2 = (q["pos"] - p["pos"]).normalized()
					q["vel"] += push * p["vel"].length() * 0.5
					p["vel"] *= 0.5
					q["pos"] = p["pos"] + push * (r + float(prop_def(q["kind"])["r"]) + 0.5)
			var fr := float(sh["roll_friction"]) if def.get("roll", false) else float(sh["friction"])
			p["vel"] *= exp(-fr * dt)
			p["spin"] += p["vel"].length() * dt * 0.08
			for e in p["embers"]:
				e["pos"] = p["pos"] + e["off"]
		if p["wet_t"] > 0.0:
			p["wet_t"] = maxf(0.0, p["wet_t"] - dt)
		if p["heat_t"] > 0.0:
			p["heat_t"] -= dt
			if p["heat_t"] <= 0.0 and p["state"] in ["smoulder", "chilled", "brittle"]:
				p["state"] = ""
		if p["state"] == "burning":
			p["burn_t"] -= dt
			for q in props:
				if q != p and q["state"] == "" and q["wet_t"] <= 0.0 and q["pos"].distance_to(p["pos"]) < float(def.get("spread", 0)):
					apply_force(q, "fire", 1)  # a spreading fire is grade I: a barrel only smoulders
			if p["burn_t"] <= 0.0:
				_put_out(p)
				p["state"] = "ash"
				events_log.append(["ash", p["kind"]])


func ignite(p: Dictionary) -> bool:
	var def := prop_def(p["kind"])
	if p["state"] in ["burning", "ash"] or float(def.get("burns", 0)) <= 0.0:
		return false
	p["state"] = "burning"
	p["burn_t"] = float(def["burns"])
	var r := float(def["r"])
	for i in 3:
		var off := Vector2.from_angle(i * TAU / 3.0 + 0.4) * r * 0.45
		var z: Dictionary = arena.add_zone({"kind": "ember", "pos": p["pos"] + off, "life": 1.0e9, "world": true})
		z["off"] = off
		p["embers"].append(z)
	events_log.append(["burn", p["kind"]])
	return true


func _put_out(p: Dictionary) -> void:
	for z in p["embers"]:
		arena.zones.erase(z)
	p["embers"].clear()


func douse(p: Dictionary) -> bool:
	if p["state"] == "smoulder":
		p["state"] = ""
		p["heat_t"] = 0.0
		return true
	if p["state"] != "burning":
		return false
	_put_out(p)
	p["state"] = ""
	p["burn_t"] = 0.0
	events_log.append(["doused", p["kind"]])
	return true


func shove(p: Dictionary, dir: Vector2, power := 1.0) -> void:
	var def := prop_def(p["kind"])
	var mass := float(def.get("mass", 0))
	if mass <= 0.0 or p["state"] == "ash" or p["integrity"] == "broken":
		return
	p["vel"] += dir.normalized() * float(pd["shove"]["speed"]) * power / mass
	events_log.append(["shoved", p["kind"]])


## A force at a grade on a prop (spec §4): the matter core says what it does to the prop's
## material, and this does it. `impact` is the structure damage an Impact at or above the break
## grade deals; `push` shoves it along `dir` too (Pebble, Fling, a wave). Returns the op.
func apply_force(p: Dictionary, force: String, grade: int, impact := 1.0, dir := Vector2.ZERO, push := 0.0) -> String:
	var def := prop_def(p["kind"])
	if p["state"] == "ash" and force != "time":
		return "none"
	var op: String = matter.result(force, grade, str(def.get("material", "wood")), def)
	match op:
		"burn":
			if p["wet_t"] > 0.0:
				p["wet_t"] = 0.0  # fire on a wet thing dries it in a puff of steam; it won't burn yet
				op = "steam"
				arena.fx("dust", p["pos"], {"r": 8.0, "life": 0.5})
			elif not ignite(p):
				op = "none"
		"smoulder", "scorch":
			if p["state"] == "" and p["wet_t"] <= 0.0:
				p["state"] = "smoulder"
				p["heat_t"] = matter.state_s("smoulder")
				arena.fx("dust", p["pos"], {"r": 6.0, "life": 0.6})
			else:
				op = "none"
		"wet":
			douse(p)
			p["wet_t"] = matter.state_s("wet")
		"chill", "brittle":
			if p["state"] == "":
				p["state"] = "chilled" if op == "chill" else "brittle"
				p["heat_t"] = matter.state_s(p["state"])
		"damage":
			p["hp"] -= impact * (1.5 if p["state"] == "brittle" else 1.0)
			if p["hp"] <= 0.0:
				_break(p)
				op = "broke"
			elif p["integrity"] == "":
				p["integrity"] = "cracked"
		"crack":
			if p["integrity"] == "cracked" or p["state"] == "brittle":
				_break(p)  # cracked, the next hit one grade short breaks it
				op = "broke"
			elif p["integrity"] == "":
				p["integrity"] = "cracked"
			else:
				op = "none"
		"mend":
			if not mend(p):
				op = "none"
	if push > 0.0 and dir != Vector2.ZERO:
		shove(p, dir, push)
	if op != "none":
		events_log.append([op, p["kind"]])
	return op


func _break(p: Dictionary) -> void:
	p["integrity"] = "broken"
	p["hp"] = 0.0
	p["vel"] = Vector2.ZERO
	arena.fx("dust", p["pos"], {"r": float(prop_def(p["kind"])["r"]) * 1.4, "life": 0.5})


## The Force grade a spell's mark carries (spell spec §6.3): its stage, capped by the Ring;
## cantrips are grade I.
func grade_of(kind: String) -> int:
	var spell: String = str(matter.carrier(kind).get("spell", ""))
	return maxi(1, _prog().grade(spell)) if spell != "" else 1


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node("Progression")


## Applies a spell mark's force (data/materials.json carriers) to a prop.
func hit_prop(p: Dictionary, kind: String, dir := Vector2.ZERO) -> String:
	var c: Dictionary = matter.carrier(kind)
	if c.is_empty():
		return "none"
	var spell: String = str(c.get("spell", ""))
	var imp: float = float(_prog().spell(spell).get("impact", 1)) if spell != "" else 1.0
	return apply_force(p, str(c["force"]), grade_of(kind), imp, dir, float(c.get("shove", 0.0)))


## The prop nearest `at` within `r` (plus its own size), or {}.
## Rewind on a prop: back to how it was this morning, unburnt and where it stood.
func mend(p: Dictionary) -> bool:
	if p["state"] == "" and p["integrity"] == "" and p["pos"].distance_to(p["home"]) < 2.0:
		return false
	_put_out(p)
	p["state"] = ""
	p["burn_t"] = 0.0
	p["hp"] = float(prop_def(p["kind"]).get("hp", 1))
	p["integrity"] = ""
	p["wet_t"] = 0.0
	p["heat_t"] = 0.0
	p["pos"] = p["home"]
	p["vel"] = Vector2.ZERO
	p["spin"] = 0.0
	events_log.append(["mended", p["kind"]])
	return true


func prop_at(at: Vector2, r := 0.0) -> Dictionary:
	var best := {}
	var bd := INF
	for p in props:
		if p["state"] == "ash":
			continue
		var d: float = p["pos"].distance_to(at) - float(prop_def(p["kind"])["r"])
		if d < r and d < bd:
			bd = d
			best = p
	return best


# --- magic on the world ------------------------------------------------------------------

## Reads the arena's spells and answers: fire lights and burns, water puts out, force shoves.
## Cantrips leave a short mark: Kindle acts like Pillar's fire, Douse like a splash all round.
func _magic() -> void:
	var reach := float(pd["lamp_reach"])
	var exploring: bool = arena.phase == "explore"
	for p in arena.projs.duplicate():
		if p.get("team", 0) != 0 or p.get("ghost", false):
			continue
		var k: String = p["kind"]
		var at: Vector2 = p["pos"]
		if exploring:
			people.flinch(at)
			if fire_proj.has(k) and map.places.get(map.place_at(at), {}).get("district", "") == "college":
				people.scold_fire(at)
		if fire_proj.has(k):
			var lit := false
			for l in lamps:
				if not l["lit"] and l["pos"].distance_to(at) < reach:
					light_lamp(l, "you")
					lit = true
			for b in braziers:
				if not b["lit"] and b["pos"].distance_to(at) < reach:
					b["lit"] = true
					lit = true
					events_log.append(["lit", "brazier"])
			var pr := prop_at(at, float(p["r"]))
			if not pr.is_empty():
				hit_prop(pr, k)
				lit = true
			if lit:
				arena.projs.erase(p)
				arena.fx("burst", at, {"color": PixelArt.FIRE, "r": 7.0, "life": 0.3})
		elif matter.carrier(k).get("force", "") == "impact":
			var pr := prop_at(at, float(p["r"]))
			if not pr.is_empty():
				hit_prop(pr, k, p["vel"])
				arena.projs.erase(p)
				arena.fx("dust", at, {"r": 5.0, "life": 0.25})
	# Splash: a spray cone, once, when it is cast. Lightning: along its line, once.
	for f in arena.fxs:
		if f.has("_w"):
			continue
		f["_w"] = true
		if f["kind"] == "spray":
			_water_cone(f["pos"], f["dir"], float(f["cone"]), float(f["r"]), "spray")
			if exploring:
				people.flinch(f["pos"] + f["dir"] * float(f["r"]) * 0.5)
		elif f.has("to") and matter.carrier(f["kind"]).get("force", "") == "lightning":
			_storm_line(f["pos"], f["to"], f["kind"])
			if exploring:
				people.flinch(f["to"])
	# Undertow: the wave douses and carries what it passes.
	for w in arena.kit.sw.waves:
		if w["delay"] > 0.0:
			continue
		var n: Vector2 = w["dir"].orthogonal()
		for pr in props:
			var to: Vector2 = pr["pos"] - w["pos"]
			if absf(to.dot(w["dir"])) < 10.0 + float(prop_def(pr["kind"])["r"]) and absf(to.dot(n)) < float(w["w"]) * 0.5 + 6.0:
				hit_prop(pr, "wave", w["dir"] if pr["vel"].length() < 60.0 else Vector2.ZERO)
		for l in lamps:
			if l["lit"] and l["pos"].distance_to(w["pos"]) < float(w["w"]) * 0.5 + 6.0:
				_douse_lamp(l)
		wet_ground(w["pos"], float(w["w"]) * 0.5)
	# Pillar's column of fire, puddles and whirlpools: once each.
	var quench := []
	for z in arena.zones:
		if z.has("_w"):
			continue
		z["_w"] = true
		match z["kind"]:
			"column", "kindle":
				burn_ground(z["pos"], float(z["r"]), grade_of(z["kind"]))
				for pr in props:
					if pr["pos"].distance_to(z["pos"]) < float(z["r"]) + float(prop_def(pr["kind"])["r"]):
						hit_prop(pr, z["kind"])
				for l in lamps:
					if l["pos"].distance_to(z["pos"]) < float(z["r"]) + 6.0:
						light_lamp(l, "you")
				for b in braziers:
					if b["pos"].distance_to(z["pos"]) < float(z["r"]) + 6.0:
						b["lit"] = true
			"rewind_form":
				for pr in props:
					if pr["home"].distance_to(z["pos"]) < float(pd["rewind_r"]) or pr["pos"].distance_to(z["pos"]) < float(pd["rewind_r"]):
						hit_prop(pr, "rewind_form")
				# The Hours on a thing in the ruin: the great clock's replay, the stair mended.
				for iid in map.items:
					if map.items[iid]["at"].distance_to(z["pos"]) < float(pd["rewind_r"]) + 10.0 and item_visible(iid):
						request({"t": "cast", "item": iid, "element": "hours"})
						break
			"douse":
				_water_cone(z["pos"], Vector2.RIGHT, TAU, float(z["r"]), "douse")
			"puddle", "whirl":
				if z.get("millrace", false):
					continue
				wet_ground(z["pos"], float(z["r"]))
				for pr in props:
					if pr["pos"].distance_to(z["pos"]) < float(z["r"]) + float(prop_def(pr["kind"])["r"]):
						hit_prop(pr, z["kind"])
				for bz in arena.zones:
					if bz["kind"] == "blaze" and bz["pos"].distance_to(z["pos"]) < float(z["r"]) + float(bz["r"]):
						quench.append(bz)
	for bz in quench:
		_quench(bz)
	# Lodestones flung into props knock them on.
	for s in arena.stones:
		if s["state"] != "flung":
			continue
		var pr := prop_at(s["pos"], 3.0)
		if not pr.is_empty() and not s["hit"].has(pr["home"]):
			s["hit"].append(pr["home"])
			hit_prop(pr, "fling", s["vel"])


func _water_cone(at: Vector2, dir: Vector2, cone: float, r: float, kind: String) -> void:
	wet_ground(at, r, dir, cone)
	var inside := func(p: Vector2, pad: float) -> bool:
		var to := p - at
		return to.length() <= r + pad and absf(dir.angle_to(to)) <= cone * 0.5 + 0.2
	for pr in props:
		if inside.call(pr["pos"], float(prop_def(pr["kind"])["r"])):
			hit_prop(pr, kind)
			if prop_def(pr["kind"]).get("roll", false):
				shove(pr, pr["pos"] - at, 0.25)
	for l in lamps:
		if l["lit"] and inside.call(l["pos"], 4.0):
			_douse_lamp(l)
	for b in braziers:
		if b["lit"] and inside.call(b["pos"], 4.0):
			b["lit"] = false
			events_log.append(["doused", "brazier"])
	for z in arena.zones.duplicate():
		if z["kind"] == "blaze" and inside.call(z["pos"], float(z["r"])):
			_quench(z)


## Luna puts out an ember's burning patch.
func _quench(z: Dictionary) -> void:
	if arena.zones.has(z):
		arena.zones.erase(z)
		arena.fx("dust", z["pos"], {"r": float(z["r"]), "life": 0.5})
		events_log.append(["doused", "blaze"])


func _douse_lamp(l: Dictionary) -> void:
	l["lit"] = false
	l["by"] = "doused"
	events_log.append(["doused", l.get("id", l["group"])])


## The arena calls this when one of your shots hits a wall: fire leaves a star-shaped scorch.
func on_wall(p: Dictionary) -> void:
	if p.get("team", 0) != 0 or not fire_proj.has(p["kind"]):
		return
	var at: Vector2 = p["pos"] - p["vel"].normalized() * 3.0
	burn_ground(p["pos"] - p["vel"].normalized() * 12.0, 0.0, grade_of(p["kind"]))
	scorches.append({"pos": at, "dir": p["vel"].normalized()})
	events_log.append(["scorch", map_id])
	if scorches.size() > 24:
		scorches.pop_front()


# --- what the wizard can reach ---------------------------------------------------------

func item_visible(id: String) -> bool:
	return not run.life.get("taken", {}).has(id)


## The person or item the wizard would talk to or use with G: the nearest in reach, or {}.
## {"type": "person" or "item", "id", "pos", "name", "verb"}
func reachable() -> Dictionary:
	var at := player_pos()
	var best := {}
	var bd := INF
	for p in people.talkable():
		var reach := float(p.def.get("reach", cfg["reach"]))
		var d: float = p.pos.distance_to(at)
		if d < reach and d < bd:
			bd = d
			best = {"type": "person", "id": p.id, "pos": p.pos, "name": p.name, "verb": "Talk to"}
	for id in map.items:
		if not item_visible(id):
			continue
		var it: Dictionary = map.items[id]
		var d: float = it["at"].distance_to(at)
		if d < float(it.get("reach", cfg["reach"])) and d < bd:
			bd = d
			best = {"type": "item", "id": id, "pos": it["at"], "name": it["name"], "verb": it["verb"]}
	return best


## The person or item under a sim point (the mouse), within `r`, or {}.
func under(at: Vector2, r := 14.0) -> Dictionary:
	for p in people.talkable():
		if p.pos.distance_to(at) < r:
			return {"type": "person", "id": p.id, "pos": p.pos, "name": p.name, "verb": "Talk to"}
	for id in map.items:
		if item_visible(id) and map.items[id]["at"].distance_to(at) < r:
			var it: Dictionary = map.items[id]
			return {"type": "item", "id": id, "pos": it["at"], "name": it["name"], "verb": it["verb"]}
	return {}


func interact(target: Dictionary) -> void:
	if target.is_empty():
		return
	if target["type"] == "person":
		request({"t": "talk", "id": target["id"]})
	else:
		request({"t": "use", "id": target["id"]})


## Turns the person to face the wizard while they talk (and back to their day afterwards).
func set_talking(id: String, on: bool) -> void:
	var p = people.get_person(id)
	if p != null:
		p.talking = on
		p.path = PackedVector2Array()
		if not on:
			p.spot = "-"  # walk back to wherever the time of day says


## Whether anything is attacking the wizard (then Z won't wait).
func threatened() -> bool:
	return arena != null and (arena.phase != "explore" or not arena.enemies().is_empty())
