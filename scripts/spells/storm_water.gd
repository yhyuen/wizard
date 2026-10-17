extends RefCounted
## Storm (range and charge) and Water (surfaces and setup), and their Magick, Conductor
## (design doc §2, §5). Water makes enemies Wet; lightning that touches a wet enemy chains
## further, and is how Conductor is discovered. Field objects: lightning rods (cap 3) and
## puddles (cap 3), both counted by the HP bar.

var A  # the arena
var K  # the kit
var waves: Array = []  # Undertow waves in flight


func _init(arena, kit) -> void:
	A = arena
	K = kit


func reset() -> void:
	waves.clear()


func handles_proj(_kind: String) -> bool:
	return false


func on_proj_hit(_p: Dictionary, _u: Unit) -> bool:
	return false


func detonate(z: Dictionary) -> bool:
	match z["kind"]:
		"strike":
			strike_hits(z)
		"arc":
			arc_hits(z)
		_:
			return false
	return true


func update(dt: float) -> void:
	var F: Dictionary = A.D["field"]
	for z in A.zones.duplicate():
		match z["kind"]:
			"rod":
				z["zap_t"] -= dt
				if z["zap_t"] <= 0.0:
					z["zap_t"] = float(F["rod_zap_every"])
					var u := _nearest(z["pos"], float(F["rod_zap_range"]), [])
					if u:
						A.fx("zap", z["pos"] + Vector2(0, -10), {"to": u.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.12})
						storm_hit(u, float(F["rod_zap_damage"]), 1, (u.pos - z["pos"]).normalized(), 6.0, "storm_call", 1.0)
			"puddle":
				for u in A.enemies():
					if u.pos.distance_to(z["pos"]) < float(z["r"]):
						u.wet_t = maxf(u.wet_t, 0.6)
			"whirl":
				_whirl(z, dt)
	for w in waves.duplicate():
		_wave(w, dt)


func _nearest(at: Vector2, reach_len: float, skip: Array) -> Unit:
	var best: Unit = null
	var best_d := reach_len
	for u in A.enemies():
		if u.id in skip:
			continue
		var d: float = u.pos.distance_to(at)
		if d <= best_d:
			best_d = d
			best = u
	return best


## Any lightning hit. Lightning on a wet enemy is how Conductor is discovered.
func storm_hit(u: Unit, dmg: float, impact: int, dir: Vector2, knock: float, xp_id: String, xp: float) -> void:
	var was_wet := u.wet_t > 0.0
	if not A.hit(u, dmg, impact, dir, knock):
		return
	Progression.add_xp(xp_id, xp)
	if was_wet:
		A.discover("conductor")
		A.fx("ring", u.pos + Vector2(0, -4), {"color": PixelArt.WATER, "r": 8.0, "life": 0.25})


func wet(u: Unit) -> void:
	var t := float(A.D["field"]["wet_time"])
	if Progression.has_mut("splash", "long_wet"):
		t *= 2.0
	u.wet_t = maxf(u.wet_t, t)


func add_rod(at: Vector2) -> void:
	var rods: Array = A.zones.filter(func(z): return z["kind"] == "rod")
	if rods.size() >= int(A.D["field"]["rod_cap"]):
		A.zones.erase(rods[0])
	A.add_zone({"kind": "rod", "pos": A.clamp_in(at, 3.0), "life": float(A.D["field"]["rod_life"]), "zap_t": 0.4})
	A.fx("bolt", at, {"color": PixelArt.STORM, "life": 0.2})


func add_puddle(at: Vector2, r: float) -> void:
	var puddles: Array = A.zones.filter(func(z): return z["kind"] == "puddle" and not z.get("millrace", false))
	if puddles.size() >= int(A.D["field"]["puddle_cap"]):
		A.zones.erase(puddles[0])
	A.add_zone({"kind": "puddle", "pos": A.clamp_in(at), "r": r, "life": float(A.D["field"]["puddle_life"])})


# --- storm ------------------------------------------------------------------

## Spark: an instant zig-zag to the nearest enemy in a cone, then chains. Each wet enemy in the
## chain adds a hop (Water lets Storm chain +1).
func spark() -> void:
	var s: Dictionary = Progression.spell("spark")
	var reach_len := Progression.stat("spark", "range")
	var cone := deg_to_rad(float(s["cone"]))
	var dir: Vector2 = K.aim_dir()
	if K.ghosts.has("spark"):
		A.fx("cone", A.player.pos + Vector2(0, -4), {"dir": dir, "cone": cone, "r": Progression.stat("spark", "range", K.ghosts["spark"]["old"]), "life": 0.5})
		K.use_ghost("spark")
	var first: Unit = null
	var best := INF
	for u in A.enemies():
		var to: Vector2 = u.pos - A.player.pos
		if to.length() <= reach_len + u.radius and absf(dir.angle_to(to)) <= cone * 0.5 and to.length() < best:
			best = to.length()
			first = u
	if first == null:
		A.fx("zap", K.origin(), {"to": K.origin() + dir * reach_len, "color": Color(PixelArt.STORM, 0.5), "life": 0.1})
		return
	var targets := int(Progression.stat("spark", "chains"))
	var bonus := 0
	var hit: Array = []
	var from: Vector2 = K.origin()
	var cur: Unit = first
	while cur and hit.size() < targets + bonus:
		A.fx("zap", from, {"to": cur.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.14})
		if cur.wet_t > 0.0 and bonus < 3:
			bonus += 1
		_spark_hit(cur, from)
		hit.append(cur.id)
		from = cur.pos + Vector2(0, -4)
		cur = _next_hop(cur.pos, hit)


func _spark_hit(u: Unit, from: Vector2) -> void:
	var s: Dictionary = Progression.spell("spark")
	storm_hit(u, Progression.stat("spark", "damage"), int(s["impact"]), (u.pos - from).normalized(), 6.0, "spark", float(s["xp_hit"]))
	if Progression.has_mut("spark", "stun_third") and not u.dead:
		u.flags["sparks"] = int(u.flags.get("sparks", 0)) + 1
		if int(u.flags["sparks"]) % 3 == 0:
			u.stun = maxf(u.stun, 0.2)
			A.fx("ring", u.pos, {"color": PixelArt.STORM, "r": 7.0, "life": 0.2})


func _next_hop(at: Vector2, hit: Array) -> Unit:
	var hop := float(Progression.spell("spark")["hop"])
	var u := _nearest(at, hop, hit)
	if u or not Progression.has_mut("spark", "rod_chain"):
		return u
	# Lightning Rod: a rod in reach passes the chain on to an enemy near it.
	for z in A.zones:
		if z["kind"] == "rod" and z["pos"].distance_to(at) <= hop:
			u = _nearest(z["pos"], hop, hit)
			if u:
				A.fx("zap", at, {"to": z["pos"] + Vector2(0, -10), "color": PixelArt.STORM, "life": 0.14})
				return u
	return null


## Arc Lance: the hold time charges the line; release strikes everything along it.
func lance_length(lv := -1) -> float:
	var k := clampf(K.hold_t / Progression.stat("arc_lance", "charge"), 0.25, 1.0)
	return Progression.stat("arc_lance", "range", lv) * k


func arc_lance() -> bool:
	var s: Dictionary = Progression.spell("arc_lance")
	var full: bool = K.hold_t >= Progression.stat("arc_lance", "charge")
	var dir: Vector2 = K.aim_dir()
	var a: Vector2 = A.player.pos + Vector2(0, -4)
	var b: Vector2 = A.clamp_in(a + dir * lance_length())
	var k := (b - a).length() / Progression.stat("arc_lance", "range")
	var dmg := Progression.stat("arc_lance", "damage") * (0.5 + 0.5 * k)
	if full and Progression.has_mut("arc_lance", "overcharge"):
		dmg *= 2.0
	var impact := int(s["full_impact"]) if full else int(s["impact"])
	A.fx("beam", a, {"to": b, "color": PixelArt.STORM, "w": float(s["width"]) if full else 3.0, "life": 0.25})
	for u in A.enemies():
		var closest := Geometry2D.get_closest_point_to_segment(u.pos, a + Vector2(0, 4), b + Vector2(0, 4))
		if u.pos.distance_to(closest) < float(s["width"]) * 0.5 + u.radius:
			storm_hit(u, dmg, impact, dir, 30.0 if full else 12.0, "arc_lance", float(s["xp_hit"]))
	if not full and Progression.has_mut("arc_lance", "lance_dash"):
		var dest: Vector2 = A.clamp_in(A.player.pos + dir * minf(48.0, (b - a).length()), A.player.radius)
		A.fx("trail", a, {"to": dest + Vector2(0, -6), "color": PixelArt.STORM, "life": 0.3})
		A.player.pos = dest
		A.player.iframes = maxf(A.player.iframes, 0.2)
	if Progression.has_mut("arc_lance", "lance_rod"):
		add_rod(b + Vector2(0, 4))
	return true


## Storm Call: strikes around the aim point; the last lands in the middle and leaves a rod.
func strike_spots(centre: Vector2, n: int, r: float) -> Array:
	var out: Array = []
	var ring := n - 1
	for i in ring:
		var ang := -PI / 2.0 + TAU * i / ring
		out.append(A.clamp_in(centre + Vector2(cos(ang), sin(ang) * 0.8) * r * 1.5))
	out.append(centre)
	return out


func _strike_shape() -> Dictionary:
	var s: Dictionary = Progression.spell("storm_call")
	var r := Progression.stat("storm_call", "radius")
	var delay := float(s["delay"])
	var gap := float(s["gap"])
	if Progression.has_mut("storm_call", "fast_strikes"):
		r *= 0.75
		delay *= 0.5
		gap *= 0.5
	return {"r": r, "delay": delay, "gap": gap}


func storm_call() -> bool:
	var s: Dictionary = Progression.spell("storm_call")
	var shape := _strike_shape()
	var centre: Vector2 = K.aim_point(float(s["range"]))
	var spots := strike_spots(centre, int(Progression.stat("storm_call", "strikes")), shape["r"])
	for z in A.zones:
		z["hero"] = false
	for i in spots.size():
		A.add_zone({"kind": "strike", "pos": spots[i], "r": shape["r"], "delay": shape["delay"] + i * shape["gap"],
			"dmg": Progression.stat("storm_call", "damage"), "final": i == spots.size() - 1, "hero": true})
	if Progression.has_mut("storm_call", "rod_strike"):
		for rod in A.zones.filter(func(z): return z["kind"] == "rod"):
			A.add_zone({"kind": "strike", "pos": rod["pos"], "r": shape["r"], "delay": shape["delay"],
				"dmg": Progression.stat("storm_call", "damage"), "free": true})
	return true


func strike_hits(z: Dictionary) -> void:
	var s: Dictionary = Progression.spell("storm_call")
	A.fx("bolt", z["pos"], {"color": PixelArt.STORM, "life": 0.25})
	A.fx("burst", z["pos"], {"color": PixelArt.STORM, "r": z["r"], "life": 0.25})
	for u in A.enemies():
		if u.pos.distance_to(z["pos"]) < z["r"] + u.radius:
			storm_hit(u, z["dmg"], int(s["impact"]), (u.pos - z["pos"]).normalized(), 20.0, "storm_call", float(s["xp_hit"]))
			if z.get("final", false) and Progression.has_mut("storm_call", "final_stun") and not u.dead:
				u.stun = maxf(u.stun, 1.0)
	if z.get("final", false):
		add_rod(z["pos"])


# --- water ------------------------------------------------------------------

## Splash: a short spray cone. Pushes and makes everything in it Wet.
func splash() -> void:
	var s: Dictionary = Progression.spell("splash")
	var dir: Vector2 = K.aim_dir()
	var reach_len := float(s["range"])
	var cone := deg_to_rad(Progression.stat("splash", "width"))
	var o: Vector2 = A.player.pos + Vector2(0, -4)
	A.fx("spray", o, {"dir": dir, "cone": cone, "r": reach_len, "life": 0.25})
	if K.ghosts.has("splash"):
		A.fx("cone", o, {"dir": dir, "cone": deg_to_rad(Progression.stat("splash", "width", K.ghosts["splash"]["old"])), "r": reach_len, "life": 0.5})
		K.use_ghost("splash")
	var first: Unit = null
	for u in A.enemies():
		var to: Vector2 = u.pos - A.player.pos
		if to.length() <= reach_len + u.radius and absf(dir.angle_to(to)) <= cone * 0.5 + 0.15:
			if A.hit(u, Progression.stat("splash", "damage"), int(s["impact"]), dir, Progression.stat("splash", "push")):
				Progression.add_xp("splash", float(s["xp_hit"]))
			wet(u)
			if first == null or to.length() < first.pos.distance_to(A.player.pos):
				first = u
	if first and Progression.has_mut("splash", "splash_puddle"):
		add_puddle(first.pos, float(A.D["field"]["puddle_radius"]) * 0.8)


## Undertow: a wave that carries enemies along and leaves a puddle where it breaks.
func undertow() -> bool:
	var dir: Vector2 = K.aim_dir()
	var dist := Progression.stat("undertow", "distance")
	var pull := Progression.has_mut("undertow", "undertow_pull")
	var n := 2 if Progression.has_mut("undertow", "two_waves") else 1
	for i in n:
		var start: Vector2 = A.player.pos + dir * 8.0
		var move_dir := dir
		if pull:
			start = A.clamp_in(A.player.pos + dir * dist)
			move_dir = -dir
		waves.append({"pos": start, "dir": move_dir, "left": dist - (8.0 if not pull else 14.0), "w": Progression.stat("undertow", "width"),
			"hit": [], "delay": i * 0.45, "dmg": Progression.stat("undertow", "damage"), "puddle_at": start if pull else Vector2.INF})
	return true


func _wave(w: Dictionary, dt: float) -> void:
	if w["delay"] > 0.0:
		w["delay"] -= dt
		return
	var s: Dictionary = Progression.spell("undertow")
	var step := float(s["speed"]) * dt
	w["pos"] = w["pos"] + w["dir"] * step
	w["left"] -= step
	var n: Vector2 = w["dir"].orthogonal()
	for u in A.enemies():
		var to: Vector2 = u.pos - w["pos"]
		if absf(to.dot(w["dir"])) < 7.0 + u.radius and absf(to.dot(n)) < w["w"] * 0.5 + u.radius:
			u.pos = A.clamp_in(u.pos + w["dir"] * step * 0.85, u.radius)
			wet(u)
			if not u.id in w["hit"]:
				w["hit"].append(u.id)
				if A.hit(u, w["dmg"], int(s["impact"]), w["dir"], 30.0):
					Progression.add_xp("undertow", float(s["xp_hit"]))
	if w["left"] <= 0.0 or not A.BOUNDS.grow(4).has_point(w["pos"]):
		waves.erase(w)
		var r := float(A.D["field"]["puddle_radius"]) * (1.6 if Progression.has_mut("undertow", "big_puddle") else 1.0)
		add_puddle(w["pos"] if w["puddle_at"] == Vector2.INF else w["puddle_at"], r)
		A.fx("ring", w["pos"], {"color": PixelArt.WATER, "r": 14.0, "life": 0.3})


## Maelstrom: a whirlpool that pulls enemies to its centre and wears them down.
func maelstrom() -> bool:
	var s: Dictionary = Progression.spell("maelstrom")
	for z in A.zones:
		z["hero"] = false
	A.add_zone({"kind": "whirl", "pos": K.aim_point(float(s["range"])), "r": Progression.stat("maelstrom", "radius"),
		"life": Progression.stat("maelstrom", "duration"), "tick": 0.0, "dmg": Progression.stat("maelstrom", "damage"), "hero": true})
	return true


func in_whirl(u: Unit) -> bool:
	for z in A.zones:
		if z["kind"] == "whirl" and u.pos.distance_to(z["pos"]) < float(z["r"]):
			return true
	return false


func _whirl(z: Dictionary, dt: float) -> void:
	var s: Dictionary = Progression.spell("maelstrom")
	var inside: Array = A.enemies().filter(func(u): return u.pos.distance_to(z["pos"]) < float(z["r"]))
	for u in inside:
		var to: Vector2 = z["pos"] - u.pos
		if to.length() > 3.0:
			var pull := float(s["pull"]) * (0.4 + 0.6 * to.length() / float(z["r"]))
			u.pos = A.clamp_in(u.pos + to.normalized() * minf(pull * dt, to.length()), u.radius)
		if Progression.has_mut("maelstrom", "whirl_wet"):
			wet(u)
	z["tick"] -= dt
	if z["tick"] <= 0.0:
		z["tick"] = float(s["tick"])
		for u in inside:
			if A.hit(u, z["dmg"], int(s["impact"]), Vector2.ZERO, 0.0, true):
				Progression.add_xp("maelstrom", float(s["xp_hit"]))
	if z["t"] >= z["life"]:
		A.zones.erase(z)
		if Progression.has_mut("maelstrom", "whirl_throw"):
			A.fx("ring", z["pos"], {"color": PixelArt.WATER, "r": z["r"] * 1.4, "life": 0.35})
			for u in inside:
				var out: Vector2 = (u.pos - z["pos"]).normalized() if u.pos.distance_to(z["pos"]) > 1.0 else Vector2.RIGHT
				A.hit(u, z["dmg"] * 3.0, 3, out, 140.0)


# --- the Magick ---------------------------------------------------------------

## Conductor: a chain arc runs from the wizard through every wet enemy in reach.
func conductor_targets() -> Array:
	var reach_len := Progression.magick_stat("conductor", "range")
	var eye := Progression.has_mut("maelstrom", "whirl_magick")
	return A.enemies().filter(func(u): return (u.wet_t > 0.0 or (eye and in_whirl(u))) and u.pos.distance_to(A.player.pos) <= reach_len)


func conductor() -> bool:
	if not Progression.knows("conductor"):
		A.unknown_magick_toast("conductor")
		return false
	var pool := conductor_targets()
	if pool.is_empty():
		A.toast.emit("Conductor needs wet enemies in reach. Splash, Undertow and puddles soak them.", PixelArt.WATER)
		return false
	for z in A.zones:
		z["hero"] = false
	var from: Vector2 = K.origin()
	var i := 0
	while not pool.is_empty():
		pool.sort_custom(func(a, b): return a.pos.distance_to(from) < b.pos.distance_to(from))
		var u: Unit = pool.pop_front()
		A.add_zone({"kind": "arc", "from": from, "pos": u.pos, "target": u.id, "delay": i * 0.07,
			"dmg": Progression.magick_stat("conductor", "damage"), "hero": true})
		from = u.pos + Vector2(0, -4)
		i += 1
	return true


func arc_hits(z: Dictionary) -> void:
	var u: Unit = A.unit_by_id(z["target"])
	if u == null or u.dead:
		return
	A.fx("zap", z["from"], {"to": u.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.25, "w": 2.0})
	A.fx("burst", u.pos + Vector2(0, -4), {"color": PixelArt.WATER, "r": 8.0, "life": 0.25})
	A.hit(u, z["dmg"], int(A.D["magicks"]["conductor"]["impact"]), (u.pos - z["from"]).normalized(), 20.0)


# --- drawing ------------------------------------------------------------------

## Field objects and the wizard's own telegraphs, drawn under the units.
func draw_field(c: CanvasItem) -> void:
	for z in A.zones:
		var t: float = z["t"]
		match z["kind"]:
			"puddle":
				var fade := clampf((z["life"] - t) / 1.0, 0.25, 1.0)
				A.draw_ellipse_px(z["pos"], z["r"], z["r"] * 0.6, Color(PixelArt.WATER, 0.6 * fade))
				A.draw_ellipse_px(z["pos"], z["r"] - 2.0, z["r"] * 0.6 - 2.0, Color(PixelArt.WATER_DEEP, 0.5 * fade))
				A.draw_ellipse_px(z["pos"] + Vector2(-z["r"] * 0.3, -1), z["r"] * 0.35, z["r"] * 0.15, Color(PixelArt.PAPER, 0.3 * fade))
			"rod":
				if A.view != null:
					continue  # the 3D view stands it up
				var p: Vector2 = z["pos"].round()
				c.draw_rect(Rect2(p + Vector2(-1, -12), Vector2(2, 12)), PixelArt.STEEL)
				c.draw_rect(Rect2(p + Vector2(-2, -13), Vector2(4, 2)), PixelArt.STORM)
				if z["zap_t"] < 0.15 or int(t * 4.0) % 2 == 0:
					c.draw_rect(Rect2(p + Vector2(-1, -15), Vector2(2, 2)), Color(PixelArt.STORM, 0.8))
			"whirl":
				var bright: bool = z.get("hero", false)
				c.draw_arc(z["pos"], z["r"], 0, TAU, 32, Color(PixelArt.WATER, 0.9), 1.0, false)
				c.draw_circle(z["pos"], z["r"], Color(PixelArt.WATER, 0.18 if bright else 0.08), true, -1.0, false)
				for i in 3:
					var a: float = -t * 5.0 + i * TAU / 3.0
					c.draw_arc(z["pos"], z["r"] * (0.35 + 0.2 * i), a, a + 2.0, 8, Color(PixelArt.PAPER, 0.45), 1.0, false)
			"strike":
				var k := clampf(t / z["delay"], 0.0, 1.0)
				var bright: bool = z.get("hero", false) or t < 0.3
				c.draw_arc(z["pos"], z["r"], 0, TAU, 32, PixelArt.STORM, 1.0, false)
				c.draw_arc(z["pos"], maxf(1.0, z["r"] - 2.0), 0, TAU, 32, Color(PixelArt.PAPER, 0.5), 1.0, false)
				c.draw_circle(z["pos"], z["r"] * k, Color(PixelArt.STORM, 0.3 if bright else 0.12), true, -1.0, false)
	for w in waves:
		if w["delay"] > 0.0:
			continue
		var n: Vector2 = w["dir"].orthogonal() * w["w"] * 0.5
		var p: Vector2 = w["pos"]
		c.draw_colored_polygon(PackedVector2Array([p + n, p + n - w["dir"] * 6.0, p - n - w["dir"] * 6.0, p - n]), Color(PixelArt.WATER, 0.45))
		c.draw_line(p + n, p - n, PixelArt.PAPER, 1.0)


func draw_preview(c: CanvasItem, id: String, ghost_old: int) -> bool:
	var ghost_col := Color(PixelArt.PAPER, 0.7)
	var P: Unit = A.player
	match id:
		"arc_lance":
			var a: Vector2 = P.pos + Vector2(0, -4)
			var dir: Vector2 = K.aim_dir()
			var full: bool = K.hold_t >= Progression.stat("arc_lance", "charge")
			var w := float(Progression.spell("arc_lance")["width"])
			c.draw_line(a, a + dir * Progression.stat("arc_lance", "range"), Color(PixelArt.STORM, 0.3), 1.0)
			var b: Vector2 = A.clamp_in(a + dir * lance_length())
			var n := dir.orthogonal() * w * 0.5
			c.draw_polyline(PackedVector2Array([a + n, b + n, b - n, a - n, a + n]), PixelArt.PAPER if full else PixelArt.STORM, 1.0)
			if ghost_old > 0:
				A.draw_dashed_line(a, a + dir * Progression.stat("arc_lance", "range", ghost_old), ghost_col)
		"storm_call":
			var shape := _strike_shape()
			var centre: Vector2 = K.aim_point(float(Progression.spell("storm_call")["range"]))
			for p in strike_spots(centre, int(Progression.stat("storm_call", "strikes")), shape["r"]):
				c.draw_arc(p, shape["r"], 0, TAU, 24, Color(PixelArt.STORM, 0.9), 1.0, false)
			if ghost_old > 0:
				A.draw_dashed_circle(centre, Progression.stat("storm_call", "radius", ghost_old), ghost_col)
		"undertow":
			var dir: Vector2 = K.aim_dir()
			var dist := Progression.stat("undertow", "distance")
			var n := dir.orthogonal() * Progression.stat("undertow", "width") * 0.5
			var a: Vector2 = P.pos
			var b: Vector2 = P.pos + dir * dist
			c.draw_polyline(PackedVector2Array([a + n, b + n, b - n, a - n, a + n]), Color(PixelArt.WATER, 0.9), 1.0)
			c.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(PixelArt.WATER, 0.12))
			if ghost_old > 0:
				var go := dir.orthogonal() * Progression.stat("undertow", "width", ghost_old) * 0.5
				A.draw_dashed_line(a + go, b + go, ghost_col)
				A.draw_dashed_line(a - go, b - go, ghost_col)
		"maelstrom":
			var at: Vector2 = K.aim_point(float(Progression.spell("maelstrom")["range"]))
			var r := Progression.stat("maelstrom", "radius")
			c.draw_arc(at, r, 0, TAU, 32, Color(PixelArt.WATER, 0.9), 1.0, false)
			c.draw_circle(at, r, Color(PixelArt.WATER, 0.12), true, -1.0, false)
			if ghost_old > 0:
				A.draw_dashed_circle(at, Progression.stat("maelstrom", "radius", ghost_old), ghost_col)
		"conductor":
			if Progression.knows("conductor"):
				A.draw_dashed_circle(P.pos, Progression.magick_stat("conductor", "range"), Color(PixelArt.STORM, 0.5))
				for u in conductor_targets():
					c.draw_arc(u.pos, 7.0, 0, TAU, 12, PixelArt.STORM, 1.0, false)
		_:
			return false
	return true
