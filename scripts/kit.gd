extends RefCounted
## The wizard's loadout for this prototype: Fire + Earth (design doc §1, §2).
## LMB Ember Bolt, RMB Pebble, Q Pillar, E Fling, R signature (Tab swaps Pyroclasm and Avalanche),
## F the Meteor Magick, Space blink. Q, E, R and F show their telegraph while held and cast on release.

const HOLD := ["control1", "control2", "signature", "magick"]
const GHOST_CASTS := 5

var A  # the arena
var cast_t = 0.0
var signature = "pyroclasm"
var blink_charges = 1
var blink_t = 0.0
var last_element = "fire"
var holding = ""
var ghosts = {}  # spell id -> {"old": level before the level-up, "casts": casts left to show it}
var denied = {}  # slot -> seconds left on the "not ready" flash
var aim = Vector2.ZERO
var move = Vector2.ZERO


func _init(arena) -> void:
	A = arena
	Progression.spell_leveled.connect(_on_leveled)


func reset() -> void:
	cast_t = 0.0
	blink_charges = Progression.blink_charges()
	blink_t = 0.0
	holding = ""
	denied.clear()


func _on_leveled(id: String, old: int, _new: int) -> void:
	ghosts[id] = {"old": old, "casts": GHOST_CASTS}
	if A.player and not A.player.dead:
		A.fx("levelup", A.player.pos, {"life": 0.9})


func slot_spell(slot: String) -> String:
	match slot:
		"bolt1":
			return "ember_bolt"
		"bolt2":
			return "pebble"
		"control1":
			return "pillar"
		"control2":
			return "fling"
		"signature":
			return signature
		"magick":
			return "meteor"
	return ""


func cooldown_total(id: String) -> float:
	if id == "meteor":
		return float(A.D["magicks"]["meteor"]["cooldown"])
	return float(Progression.spell(id).get("cooldown", 0.0))


func element_color(e: String) -> Color:
	return PixelArt.FIRE if e == "fire" else PixelArt.EARTH


# --- input ------------------------------------------------------------------

func update(dt: float, intent: Dictionary) -> void:
	var P: Unit = A.player
	var held: Dictionary = intent.get("held", {})
	var pressed: Dictionary = intent.get("pressed", {})
	var released: Dictionary = intent.get("released", {})
	aim = intent.get("aim", A.mouse)
	move = intent.get("move", Vector2.ZERO)
	cast_t -= dt
	for k in denied.keys():
		denied[k] -= dt
		if denied[k] <= 0.0:
			denied.erase(k)
	var max_charges = Progression.blink_charges()
	if blink_charges < max_charges:
		blink_t += dt
		if blink_t >= float(A.D["wizard"]["blink_recharge"]):
			blink_t = 0.0
			blink_charges += 1
	P.moving = false
	P.flags["move"] = Vector2.ZERO
	if absf(aim.x - P.pos.x) > 1.0:
		P.facing = signf(aim.x - P.pos.x)
	if pressed.get("swap_signature", false):
		signature = "avalanche" if signature == "pyroclasm" else "pyroclasm"
		A.toast.emit("Signature: " + Progression.spell(signature)["name"], element_color(Progression.spell(signature)["element"]))
	if P.locked():
		holding = ""
		return
	if move.length() > 0.01:
		var v = move.normalized() * A.move_speed(P)
		P.pos = A.clamp_in(P.pos + v * dt, P.radius)
		P.moving = true
		P.flags["move"] = v
	if pressed.get("blink", false):
		blink()
	if held.get("bolt1", false) and cast_t <= 0.0:
		ember_bolt()
	elif held.get("bolt2", false) and cast_t <= 0.0:
		pebble()
	for s in HOLD:
		if pressed.get(s, false):
			holding = s
		if released.get(s, false):
			if holding == s:
				cast(s)
			if holding == s:
				holding = ""
	if holding != "" and not held.get(holding, false):
		holding = ""


func cast(slot: String) -> void:
	var id = slot_spell(slot)
	var P: Unit = A.player
	if P.cooldown(id) > 0.0:
		denied[slot] = 0.4
		return
	var ok = false
	match id:
		"pillar":
			ok = pillar()
		"fling":
			ok = fling()
		"pyroclasm":
			ok = pyroclasm()
		"avalanche":
			ok = avalanche()
		"meteor":
			ok = meteor()
	if not ok:
		denied[slot] = 0.4
		return
	P.cd[id] = cooldown_total(id)
	_count(id)
	_use_ghost(id)


func _count(id: String) -> void:
	A.stats["casts"] += 1
	A.stats["by_spell"][id] = int(A.stats["by_spell"].get(id, 0)) + 1


func _use_ghost(id: String) -> void:
	if ghosts.has(id):
		ghosts[id]["casts"] -= 1
		if ghosts[id]["casts"] <= 0:
			ghosts.erase(id)


func _aim_dir() -> Vector2:
	var d: Vector2 = aim - A.player.pos
	return d.normalized() if d.length() > 0.5 else Vector2(A.player.facing, 0)


func _origin() -> Vector2:
	return A.player.pos + Vector2(0, -6)


func blink() -> void:
	var P: Unit = A.player
	if blink_charges <= 0:
		denied["blink"] = 0.4
		return
	var dir = move.normalized() if move.length() > 0.01 else _aim_dir()
	var dest: Vector2 = A.clamp_in(P.pos + dir * float(A.D["wizard"]["blink_dist"]), P.radius)
	A.fx("trail", P.pos + Vector2(0, -6), {"to": dest + Vector2(0, -6), "color": element_color(last_element), "life": 0.3})
	A.fx("dust", P.pos, {"r": 6.0, "life": 0.3})
	P.pos = dest
	P.iframes = maxf(P.iframes, 0.18)
	blink_charges -= 1


# --- bolts ------------------------------------------------------------------

func ember_bolt() -> void:
	var dir = _aim_dir()
	var s: Dictionary = Progression.spell("ember_bolt")
	A.spawn_proj({"kind": "ember", "team": 0, "pos": _origin() + dir * 5.0,
		"vel": dir * Progression.stat("ember_bolt", "speed"), "r": 1.5, "life": 1.4,
		"dmg": Progression.stat("ember_bolt", "damage"), "color": PixelArt.FIRE,
		"pierce": 1 if Progression.has_mut("ember_bolt", "pierce") else 0})
	if ghosts.has("ember_bolt"):
		# The ghost: a bolt at the old speed, so the new one visibly outruns it.
		var old = Progression.stat("ember_bolt", "speed", ghosts["ember_bolt"]["old"])
		A.spawn_proj({"kind": "ember", "team": 0, "ghost": true, "pos": _origin() + dir * 5.0,
			"vel": dir * old, "r": 1.5, "life": 1.2, "color": PixelArt.PAPER})
		_use_ghost("ember_bolt")
	cast_t = float(s["cast_time"])
	last_element = "fire"
	_count("ember_bolt")


func pebble() -> void:
	var dir = _aim_dir()
	var s: Dictionary = Progression.spell("pebble")
	A.spawn_proj({"kind": "pebble", "team": 0, "pos": _origin() + dir * 5.0,
		"vel": dir * float(s["speed"]), "r": Progression.stat("pebble", "size"), "life": 1.8,
		"dmg": Progression.stat("pebble", "damage"), "knock": Progression.stat("pebble", "knockback"),
		"color": PixelArt.EARTH, "wall_bounces": 1 if Progression.has_mut("pebble", "wall_bounce") else 0})
	if ghosts.has("pebble"):
		var old = Progression.stat("pebble", "size", ghosts["pebble"]["old"])
		A.spawn_proj({"kind": "pebble", "team": 0, "ghost": true, "pos": _origin() + dir * 5.0,
			"vel": dir * float(s["speed"]), "r": old, "life": 1.2, "color": PixelArt.PAPER})
		_use_ghost("pebble")
	cast_t = float(s["cast_time"])
	last_element = "earth"
	_count("pebble")


## Returns true to keep the projectile flying (pierce, bounce).
func on_proj_hit(p: Dictionary, u: Unit) -> bool:
	var dir: Vector2 = p["vel"].normalized()
	match p["kind"]:
		"ember":
			A.hit(u, p["dmg"], int(Progression.spell("ember_bolt")["impact"]), dir, 8.0)
			A.fx("burst", p["pos"], {"color": PixelArt.FIRE, "r": 3.0, "life": 0.15})
			A.add_pips(u, 1)
			Progression.add_xp("ember_bolt", float(Progression.spell("ember_bolt")["xp_hit"]))
			if int(p["pierce"]) > 0:
				p["pierce"] -= 1
				return true
			return false
		"pebble":
			A.hit(u, p["dmg"], int(Progression.spell("pebble")["impact"]), dir, p["knock"])
			A.fx("dust", p["pos"], {"r": 6.0, "life": 0.25})
			Progression.add_xp("pebble", float(Progression.spell("pebble")["xp_hit"]))
			A.add_stone(p["pos"])
			return false
		"pyro":
			return _pyro_hit(p, u)
	return false


# --- fire -------------------------------------------------------------------

func pillar() -> bool:
	var s: Dictionary = Progression.spell("pillar")
	var z = {"kind": "pillar", "pos": _pillar_target(), "r": Progression.stat("pillar", "radius"),
		"delay": Progression.stat("pillar", "delay"), "dmg": Progression.stat("pillar", "damage"),
		"impact": 4 if Progression.has_mut("pillar", "knock_up") else int(s["impact"])}
	if ghosts.has("pillar"):
		z["ghost_r"] = Progression.stat("pillar", "radius", ghosts["pillar"]["old"])
	if Progression.has_mut("pillar", "pull_center"):
		z["pull"] = true
	A.add_zone(z)
	if Progression.has_mut("pillar", "twin_pillar"):
		var z2 = z.duplicate()
		z2["delay"] = z["delay"] + 1.0
		z2.erase("pull")
		A.add_zone(z2)
	last_element = "fire"
	return true


func _pillar_target() -> Vector2:
	var reach_len = float(Progression.spell("pillar")["range"])
	return A.clamp_in(A.player.pos + (aim - A.player.pos).limit_length(reach_len))


func pillar_hits(z: Dictionary) -> void:
	A.add_zone({"kind": "column", "pos": z["pos"], "r": z["r"], "life": 0.35})
	A.fx("burst", z["pos"], {"color": PixelArt.FIRE, "r": z["r"], "life": 0.3})
	var knock = 60.0 if Progression.has_mut("pillar", "knock_up") else 25.0
	for u in A.enemies():
		if u.pos.distance_to(z["pos"]) < z["r"] + u.radius:
			A.hit(u, z["dmg"], z["impact"], (u.pos - z["pos"]).normalized(), knock)
			A.add_pips(u, 2)
			Progression.add_xp("pillar", float(Progression.spell("pillar")["xp_hit"]))
	if Progression.has_mut("pillar", "pillar_embers"):
		A.add_ember(z["pos"])
	for st in A.stones:
		if st["pos"].distance_to(z["pos"]) < z["r"] + 3.0:
			A.discover_meteor()
			break


func pyroclasm() -> bool:
	var dir = _aim_dir()
	A.spawn_proj({"kind": "pyro", "team": 0, "pos": _origin() + dir * 5.0,
		"vel": dir * float(Progression.spell("pyroclasm")["speed"]), "r": 2.5, "life": 1.5,
		"dmg": Progression.stat("pyroclasm", "damage"), "bounces": int(Progression.stat("pyroclasm", "bounces")),
		"range": Progression.stat("pyroclasm", "range"), "color": PixelArt.FIRE})
	last_element = "fire"
	return true


func _pyro_hit(p: Dictionary, u: Unit) -> bool:
	var dir: Vector2 = p["vel"].normalized()
	A.hit(u, p["dmg"], int(Progression.spell("pyroclasm")["impact"]), dir, 10.0)
	A.fx("burst", p["pos"], {"color": PixelArt.FIRE, "r": 6.0, "life": 0.2})
	Progression.add_xp("pyroclasm", float(Progression.spell("pyroclasm")["xp_hit"]))
	if Progression.has_mut("pyroclasm", "bounce_pip"):
		A.add_pips(u, 1)
	p["bounces"] -= 1
	var next: Unit = null
	if p["bounces"] > 0:
		var best = INF
		for e in A.enemies():
			if e == u or e.pips <= 0:
				continue
			var d = e.pos.distance_to(u.pos)
			if d > p["range"]:
				continue
			if Progression.has_mut("pyroclasm", "duel_focus") and e.kind == "rival":
				d = -1.0
			if d < best:
				best = d
				next = e
	if next == null:
		if Progression.has_mut("pyroclasm", "final_ignite"):
			A.ignite_queue.append(u)
		return false
	A.fx("spark_line", u.pos + Vector2(0, -6), {"to": next.pos + Vector2(0, -6), "color": PixelArt.FIRE, "life": 0.15})
	p["pos"] = u.pos + Vector2(0, -6)
	p["last"] = u.id
	p["hit"] = []
	p["home"] = next.id
	p["life"] = 1.5
	p["vel"] = (next.pos - u.pos).normalized() * p["vel"].length()
	return true


# --- earth ------------------------------------------------------------------

func fling() -> bool:
	var s: Dictionary = Progression.spell("fling")
	var force = Progression.stat("fling", "force")
	if Progression.has_mut("fling", "pull_back"):
		var grounded: Array = A.stones.filter(func(st): return st["state"] == "ground")
		if not grounded.is_empty():
			for st in grounded:
				st["state"] = "recall"
				st["speed"] = force
				st["hit"] = []
				st["dist"] = 0.0
			last_element = "earth"
			return true
	var orb: Array = A.orbit_stones()
	if orb.is_empty():
		A.toast.emit("No lodestones in orbit. Pebble hits drop them.", PixelArt.EARTH)
		return false
	var dir = _aim_dir()
	var cone = deg_to_rad(Progression.stat("fling", "cone"))
	var reach_len = float(s["range"]) * (1.5 if Progression.has_mut("pebble", "far_fling") else 1.0)
	var n = orb.size()
	for i in n:
		var st: Dictionary = orb[i]
		var a = dir.angle()
		if n > 1:
			a += lerpf(-cone * 0.5, cone * 0.5, float(i) / (n - 1))
		st["state"] = "flung"
		st["vel"] = Vector2.from_angle(a) * force
		st["dist"] = 0.0
		st["range"] = reach_len
		st["hit"] = []
	last_element = "earth"
	return true


## A flung or recalled stone passing through enemies.
func stone_sweep(st: Dictionary) -> void:
	var dir: Vector2 = st["vel"].normalized()
	if st["state"] == "recall":
		dir = (A.player.pos - st["pos"]).normalized()
	for u in A.enemies():
		if u.id in st["hit"] or u.pos.distance_to(st["pos"]) > u.radius + 3.0:
			continue
		st["hit"].append(u.id)
		A.hit(u, Progression.stat("fling", "damage"), int(Progression.spell("fling")["impact"]), dir, 70.0)
		Progression.add_xp("fling", float(Progression.spell("fling")["xp_hit"]))
		if Progression.has_mut("fling", "wall_stun"):
			u.wall_check = 0.5


func avalanche() -> bool:
	var pool: Array = A.stones.filter(func(st): return st["state"] in ["orbit", "ground", "return"])
	if pool.is_empty():
		A.toast.emit("Avalanche needs lodestones. Pebble hits drop them.", PixelArt.EARTH)
		return false
	var t = avalanche_target()
	if t == null:
		return false
	for i in pool.size():
		var st: Dictionary = pool[i]
		st["state"] = "slam"
		st["target"] = t.id
		st["delay"] = i * 0.07
		st["final"] = i == pool.size() - 1
	last_element = "earth"
	return true


func avalanche_target() -> Unit:
	var best: Unit = null
	var best_d = 40.0
	for u in A.enemies():
		var d = u.pos.distance_to(aim)
		if d < best_d:
			best_d = d
			best = u
	if best:
		return best
	best_d = float(Progression.spell("avalanche")["range"])
	for u in A.enemies():
		var d = u.pos.distance_to(A.player.pos)
		if d < best_d:
			best_d = d
			best = u
	return best


func avalanche_hit(st: Dictionary, t: Unit) -> void:
	var s: Dictionary = Progression.spell("avalanche")
	var dmg = Progression.stat("avalanche", "damage")
	if Progression.has_mut("avalanche", "single_target"):
		var alone = true
		for e in A.enemies():
			if e != t and e.pos.distance_to(t.pos) < 40.0:
				alone = false
		if alone:
			dmg *= 1.5
	var final: bool = st.get("final", false)
	A.hit(t, dmg, int(s["final_impact"]) if final else int(s["impact"]), (t.pos - A.player.pos).normalized(), 25.0 if final else 4.0)
	A.fx("dust", st["pos"], {"r": 7.0, "life": 0.25})
	Progression.add_xp("avalanche", float(s["xp_hit"]))
	if Progression.has_mut("avalanche", "gravel"):
		A.stones.erase(st)
		var near = A.zones.filter(func(z): return z["kind"] == "gravel" and z["pos"].distance_to(t.pos) < 8.0)
		if near.is_empty():
			A.add_zone({"kind": "gravel", "pos": t.pos, "r": 16.0, "life": float(A.D["field"]["gravel_life"])})
		return
	st["state"] = "ground"
	A._ground_tip()
	st["pos"] = A.clamp_in(t.pos + Vector2(A.rng.randf_range(-10, 10), A.rng.randf_range(-6, 8)), 3.0)


# --- the Magick ---------------------------------------------------------------

func meteor() -> bool:
	var m: Dictionary = A.D["magicks"]["meteor"]
	if not Progression.knows("meteor"):
		A.toast.emit("Meteor is unknown. " + m["hint"], PixelArt.FIRE_HOT)
		return false
	var pool: Array = A.stones.filter(func(st): return st["state"] in ["orbit", "ground", "return"])
	if pool.is_empty():
		A.toast.emit("Meteor needs lodestones to set alight.", PixelArt.FIRE_HOT)
		return false
	var targets: Array = A.enemies().filter(func(u): return u.pos.distance_to(aim) < 70.0)
	targets.sort_custom(func(a, b): return a.pos.distance_to(aim) < b.pos.distance_to(aim))
	for z in A.zones:
		z["hero"] = false
	for i in pool.size():
		var st: Dictionary = pool[i]
		var at: Vector2 = aim + Vector2(A.rng.randf_range(-24, 24), A.rng.randf_range(-16, 16))
		if not targets.is_empty():
			at = targets[i % targets.size()].pos
		A.fx("rise", st["pos"], {"life": 0.4})
		A.stones.erase(st)
		A.add_zone({"kind": "meteor", "pos": A.clamp_in(at), "r": Progression.magick_stat("meteor", "radius"),
			"delay": 0.7 + i * 0.12, "dmg": Progression.magick_stat("meteor", "damage"), "hero": true})
	return true


func meteor_hits(z: Dictionary) -> void:
	var m: Dictionary = A.D["magicks"]["meteor"]
	A.fx("burst", z["pos"], {"color": PixelArt.FIRE, "r": z["r"], "life": 0.35})
	A.fx("burst", z["pos"], {"color": PixelArt.EARTH, "r": z["r"] * 0.6, "life": 0.25})
	A.fx("dust", z["pos"], {"r": z["r"], "life": 0.4})
	for u in A.enemies():
		if u.pos.distance_to(z["pos"]) < z["r"] + u.radius:
			A.hit(u, z["dmg"], int(m["impact"]), (u.pos - z["pos"]).normalized(), 40.0)
			A.add_pips(u, int(m["pips"]))


# --- previews -----------------------------------------------------------------

## While Q/E/R/F is held, its telegraph shows exactly what will be hit. After a level-up, a
## dashed ghost shows the old size for a few casts (design doc §3).
func draw(c: CanvasItem) -> void:
	var P: Unit = A.player
	if P.dead or holding == "":
		return
	var id = slot_spell(holding)
	var ghost_old: int = ghosts[id]["old"] if ghosts.has(id) else 0
	var ghost_col = Color(PixelArt.PAPER, 0.7)
	match id:
		"pillar":
			var at = _pillar_target()
			var r = Progression.stat("pillar", "radius")
			c.draw_arc(at, r, 0, TAU, 32, Color(PixelArt.FIRE, 0.9), 1.0, false)
			c.draw_circle(at, r, Color(PixelArt.FIRE, 0.12), true, -1.0, false)
			if ghost_old > 0:
				A.draw_dashed_circle(at, Progression.stat("pillar", "radius", ghost_old), ghost_col)
		"fling":
			var reach_len = float(Progression.spell("fling")["range"]) * (1.5 if Progression.has_mut("pebble", "far_fling") else 1.0)
			_draw_cone(c, _aim_dir(), deg_to_rad(Progression.stat("fling", "cone")), reach_len, Color(PixelArt.EARTH, 0.9))
			if ghost_old > 0:
				_draw_cone(c, _aim_dir(), deg_to_rad(Progression.stat("fling", "cone", ghost_old)), reach_len, ghost_col)
		"pyroclasm":
			var o = P.pos + Vector2(0, -6)
			c.draw_line(o, o + _aim_dir() * 40.0, Color(PixelArt.FIRE, 0.8), 1.0)
			var reach_len = Progression.stat("pyroclasm", "range")
			for e in A.enemies():
				if e.pips > 0:
					c.draw_arc(e.pos, 7.0, 0, TAU, 12, Color(PixelArt.FIRE, 0.9), 1.0, false)
			c.draw_arc(aim, reach_len, 0, TAU, 40, Color(PixelArt.FIRE, 0.25), 1.0, false)
			if ghost_old > 0:
				A.draw_dashed_circle(aim, Progression.stat("pyroclasm", "range", ghost_old), ghost_col)
		"avalanche":
			var t = avalanche_target()
			if t:
				c.draw_arc(t.pos, 8.0, 0, TAU, 16, PixelArt.EARTH, 1.0, false)
				for st in A.stones:
					if st["state"] in ["orbit", "ground", "return"]:
						c.draw_line(st["pos"], t.pos, Color(PixelArt.EARTH, 0.4), 1.0)
		"meteor":
			if Progression.knows("meteor"):
				A.draw_dashed_circle(aim, 70.0, Color(PixelArt.FIRE_HOT, 0.7))


func _draw_cone(c: CanvasItem, dir: Vector2, cone: float, reach_len: float, col: Color) -> void:
	var o: Vector2 = A.player.pos + Vector2(0, -4)
	var a = dir.angle()
	c.draw_line(o, o + Vector2.from_angle(a - cone * 0.5) * reach_len, col, 1.0)
	c.draw_line(o, o + Vector2.from_angle(a + cone * 0.5) * reach_len, col, 1.0)
	c.draw_arc(o, reach_len, a - cone * 0.5, a + cone * 0.5, 16, col, 1.0, false)
