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
var requests: Array = []
var busy: Callable  # func() -> bool: the game is showing a scene or a menu

var clock := 0.0  # seconds into this time of day
var here := ""  # the place the wizard is in
var lamps: Array = []  # {"pos", "group", "lit", "by"}
var braziers: Array = []  # {"pos", "lit"}
var props: Array = []  # {"kind", "pos", "vel", "rot", "home", "state" ("", "burning", "ash"), "burn_t", "embers"}
var scorches: Array = []  # {"pos", "dir"}: star-shaped burns on walls
var fire_proj := {}
var water_kinds := {}
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
	for k in pd["fire_spells"]:
		fire_proj[k] = true
	for k in pd["water_spells"]:
		water_kinds[k] = true
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
	_saved[map_id] = {"props": props, "lamps": lamps, "braziers": braziers, "scorches": scorches}
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
	else:
		props = st["props"]
		lamps = st["lamps"]
		braziers = st["braziers"]
		scorches = st["scorches"]
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
			"rot": float(p[3]), "spin": 0.0, "state": "", "burn_t": 0.0, "embers": []})


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
func _storm_line(a: Vector2, b: Vector2) -> void:
	for l in lamps:
		if l["iron"] and Geometry2D.get_closest_point_to_segment(l["pos"], a, b).distance_to(l["pos"]) < float(pd["lamp_reach"]):
			l["flare_t"] = float(pd["flare_s"])
			events_log.append(["flare", l.get("id", l["group"])])
	for z in arena.zones:
		if z["kind"] == "puddle" and not z.get("millrace", false) \
				and Geometry2D.get_closest_point_to_segment(z["pos"], a, b).distance_to(z["pos"]) < float(z["r"]):
			z["charge_t"] = float(pd["charge_s"])
			events_log.append(["charged", "puddle"])


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
		if p["state"] != "ash":
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
		if p["state"] == "burning":
			p["burn_t"] -= dt
			for q in props:
				if q != p and q["state"] == "" and float(prop_def(q["kind"]).get("burns", 0)) > 0.0 \
						and q["pos"].distance_to(p["pos"]) < float(def.get("spread", 0)):
					ignite(q)
			if p["burn_t"] <= 0.0:
				_put_out(p)
				p["state"] = "ash"
				events_log.append(["ash", p["kind"]])


func ignite(p: Dictionary) -> bool:
	var def := prop_def(p["kind"])
	if p["state"] != "" or float(def.get("burns", 0)) <= 0.0:
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
	if mass <= 0.0 or p["state"] == "ash":
		return
	p["vel"] += dir.normalized() * float(pd["shove"]["speed"]) * power / mass
	events_log.append(["shoved", p["kind"]])


## The prop nearest `at` within `r` (plus its own size), or {}.
## Rewind on a prop: back to how it was this morning, unburnt and where it stood.
func mend(p: Dictionary) -> bool:
	if p["state"] == "" and p["pos"].distance_to(p["home"]) < 2.0:
		return false
	_put_out(p)
	p["state"] = ""
	p["burn_t"] = 0.0
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
				ignite(pr)
				lit = true
			if lit:
				arena.projs.erase(p)
				arena.fx("burst", at, {"color": PixelArt.FIRE, "r": 7.0, "life": 0.3})
		elif k == "pebble":
			var pr := prop_at(at, float(p["r"]))
			if not pr.is_empty():
				shove(pr, p["vel"])
				arena.projs.erase(p)
				arena.fx("dust", at, {"r": 5.0, "life": 0.25})
	# Splash: a spray cone, once, when it is cast. Lightning: along its line, once.
	for f in arena.fxs:
		if f.has("_w"):
			continue
		f["_w"] = true
		if f["kind"] == "spray":
			_water_cone(f["pos"], f["dir"], float(f["cone"]), float(f["r"]))
			if exploring:
				people.flinch(f["pos"] + f["dir"] * float(f["r"]) * 0.5)
		elif f.has("to") and f["kind"] in pd["storm_zaps"]:
			_storm_line(f["pos"], f["to"])
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
				douse(pr)
				if pr["vel"].length() < 60.0:
					shove(pr, w["dir"], 0.35)
		for l in lamps:
			if l["lit"] and l["pos"].distance_to(w["pos"]) < float(w["w"]) * 0.5 + 6.0:
				_douse_lamp(l)
	# Pillar's column of fire, puddles and whirlpools: once each.
	var quench := []
	for z in arena.zones:
		if z.has("_w"):
			continue
		z["_w"] = true
		match z["kind"]:
			"column", "kindle":
				for pr in props:
					if pr["pos"].distance_to(z["pos"]) < float(z["r"]) + float(prop_def(pr["kind"])["r"]):
						ignite(pr)
				for l in lamps:
					if l["pos"].distance_to(z["pos"]) < float(z["r"]) + 6.0:
						light_lamp(l, "you")
				for b in braziers:
					if b["pos"].distance_to(z["pos"]) < float(z["r"]) + 6.0:
						b["lit"] = true
			"rewind_form":
				for pr in props:
					if pr["home"].distance_to(z["pos"]) < float(pd["rewind_r"]) or pr["pos"].distance_to(z["pos"]) < float(pd["rewind_r"]):
						mend(pr)
				# The Hours on a thing in the ruin: the great clock's replay, the stair mended.
				for iid in map.items:
					if map.items[iid]["at"].distance_to(z["pos"]) < float(pd["rewind_r"]) + 10.0 and item_visible(iid):
						request({"t": "cast", "item": iid, "element": "hours"})
						break
			"douse":
				_water_cone(z["pos"], Vector2.RIGHT, TAU, float(z["r"]))
			"puddle", "whirl":
				if z.get("millrace", false):
					continue
				for pr in props:
					if pr["pos"].distance_to(z["pos"]) < float(z["r"]) + float(prop_def(pr["kind"])["r"]):
						douse(pr)
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
			shove(pr, s["vel"], 0.8)


func _water_cone(at: Vector2, dir: Vector2, cone: float, r: float) -> void:
	var inside := func(p: Vector2, pad: float) -> bool:
		var to := p - at
		return to.length() <= r + pad and absf(dir.angle_to(to)) <= cone * 0.5 + 0.2
	for pr in props:
		if inside.call(pr["pos"], float(prop_def(pr["kind"])["r"])):
			douse(pr)
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
	scorches.append({"pos": at, "dir": p["vel"].normalized()})
	events_log.append(["scorch", map_id])
	if scorches.size() > 24:
		scorches.pop_front()


# --- what the wizard can reach ---------------------------------------------------------

func item_visible(id: String) -> bool:
	return not run.lp.get("taken", {}).has(id)


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
