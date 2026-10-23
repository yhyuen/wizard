extends RefCounted
## Spark Artifice, the Lamplighters' school (spell spec §7, economy spec §5.3; build item N-5.2).
## Its spells are devices: thrown with no wind-up and no Aether, each throw spends a charge, and
## charges come back only at a bench. A device flies for a moment to where you aim, then:
## the Spark Flask bursts into flame (it lights the ground and what stands on it), the Arc Rod plants
## and arcs into the nearest foe until it burns out, the Smoke Jar leaves a cloud foes can't strike
## from, and the Tar Pot coats the ground in tar that slows and burns like a lamp when fire finds it.
## The Star Lantern (N-5.3) is the first combined spell, Spark Artifice with Astral Rite: a device
## that hangs where it lands; inside its ring every spell you begin is Aligned, and its light keeps
## light-shy things out.

const FIRE_KINDS := ["ember", "blaze", "column", "kindle", "flask"]

var A  # the arena
var K  # the kit


func _init(arena, kit) -> void:
	A = arena
	K = kit


func reset() -> void:
	pass


func handles_proj(_kind: String) -> bool:
	return false


func on_proj_hit(_p: Dictionary, _u: Unit) -> bool:
	return false


## Where a device lands: the aim point, no further than its range.
func land_point(id: String) -> Vector2:
	return K.aim_point(Progression.reach(id))


## The size of what it leaves: the flask's burst, the jar's cloud, the pot's pool, the rod's reach.
func size_of(id: String) -> float:
	return Progression.stat(id, "reach" if id == "arc_rod" else "radius")


func _throw(id: String) -> bool:
	var s: Dictionary = Progression.spell(id)
	A.add_zone({"kind": "throw", "device": id, "from": K.origin(), "pos": land_point(id),
		"r": size_of(id), "delay": float(s["flight"])})
	return true


func spark_flask() -> bool:
	return _throw("spark_flask")


func arc_rod() -> bool:
	return _throw("arc_rod")


func smoke_jar() -> bool:
	return _throw("smoke_jar")


func tar_pot() -> bool:
	return _throw("tar_pot")


func star_lantern() -> bool:
	return _throw("star_lantern")


## Inside a Star Lantern's ring: a spell begun here is Aligned.
func in_lantern(p: Vector2) -> bool:
	return A.zones.any(func(z): return z["kind"] == "lantern" and z["pos"].distance_to(p) <= float(z["r"]))


func detonate(z: Dictionary) -> bool:
	if z["kind"] != "throw":
		return false
	match z["device"]:
		"spark_flask":
			_flask(z["pos"], float(z["r"]))
		"arc_rod":
			A.add_zone({"kind": "arc_rod", "pos": A.clamp_in(z["pos"], 3.0), "r": float(z["r"]),
				"life": Progression.stat("arc_rod", "life"), "zap_t": 0.2})
			A.fx("bolt", z["pos"], {"color": PixelArt.STORM, "life": 0.2})
			if A.town != null:
				A.town.strike_ground(z["pos"], z["pos"], 1)  # a puddle under it carries the arc
		"smoke_jar":
			A.add_zone({"kind": "smoke", "pos": z["pos"], "r": float(z["r"]), "life": Progression.stat("smoke_jar", "life")})
			A.fx("dust", z["pos"], {"r": float(z["r"]), "life": 0.6})
		"star_lantern":
			A.add_zone({"kind": "lantern", "pos": z["pos"], "r": float(z["r"]), "life": Progression.stat("star_lantern", "life")})
			A.fx("ring", z["pos"], {"color": PixelArt.GOLD, "r": float(z["r"]), "life": 0.5})
			Progression.add_xp("star_lantern", float(Progression.spell("star_lantern")["xp_cast"]))
		"tar_pot":
			A.add_zone({"kind": "tar", "pos": z["pos"], "r": float(z["r"]), "life": Progression.stat("tar_pot", "life")})
			A.fx("dust", z["pos"], {"color": PixelArt.INK, "r": float(z["r"]) * 0.6, "life": 0.4})
			if A.town != null and A.town.cells != null:
				for i in A.town.cells.within(z["pos"], float(z["r"])):
					A.town.cells.tar(i)
	return true


## The flask bursts: fire on everything inside, and a mark the world reads (it lights the ground,
## lamps and props, data/materials.json "flask"). Tar inside goes up with it.
func _flask(at: Vector2, r: float) -> void:
	var s: Dictionary = Progression.spell("spark_flask")
	A.fx("burst", at, {"color": PixelArt.FIRE, "r": r, "life": 0.35})
	A.fx("ring", at, {"color": PixelArt.FIRE_HOT, "r": r, "life": 0.25})
	for u in A.enemies():
		if u.pos.distance_to(at) < r + u.radius:
			A._src_kind = "fire"
			var hit: bool = A.hit(u, Progression.stat("spark_flask", "damage"), int(s["impact"]), (u.pos - at).normalized(), 14.0)
			A._src_kind = ""
			if hit:
				A.add_pips(u, int(s["pips"]))
				Progression.add_xp("spark_flask", float(s["xp_hit"]))
	A.add_zone({"kind": "flask", "pos": at, "r": r, "life": 0.2})
	Sfx.play("cast_fire", 3.0)


func update(dt: float) -> void:
	var ignite: Array = []
	for z in A.zones:
		match z["kind"]:
			"arc_rod":
				_rod(z, dt)
			"smoke":
				var blind := float(Progression.spell("smoke_jar")["blind"])
				for u in A.enemies():
					if u.pos.distance_to(z["pos"]) < float(z["r"]) + u.radius:
						u.cd["attack"] = maxf(u.cooldown("attack"), blind)  # can't see to strike
			"tar":
				var slow := float(Progression.spell("tar_pot")["slow"])
				for u in A.units:
					if not u.dead and u.pos.distance_to(z["pos"]) < float(z["r"]) + u.radius:
						u.slow_t = maxf(u.slow_t, slow)
						u.oil_t = maxf(u.oil_t, float(A.D["foes"]["states"]["oil_s"]))  # oiled: it burns (N-6.2)
				for f in A.zones:
					if f["kind"] in FIRE_KINDS and f["pos"].distance_to(z["pos"]) < float(z["r"]) + float(f.get("r", 4.0)):
						ignite.append(z)
						break
	for z in ignite:
		_ignite(z)


## Fire found the tar: it all goes up at once.
func _ignite(z: Dictionary) -> void:
	A.zones.erase(z)
	A.fx("burst", z["pos"], {"color": PixelArt.FIRE, "r": float(z["r"]), "life": 0.5})
	if A.town != null:
		A.town.burn_ground(z["pos"], float(z["r"]), 1)
	else:
		A.add_zone({"kind": "ember", "pos": z["pos"], "r": float(z["r"]), "life": 4.0})
	A.stats["tar_lit"] = int(A.stats.get("tar_lit", 0)) + 1


## The rod arcs into the nearest foe in reach, every `zap_every` seconds.
func _rod(z: Dictionary, dt: float) -> void:
	var s: Dictionary = Progression.spell("arc_rod")
	z["zap_t"] = float(z["zap_t"]) - dt
	if z["zap_t"] > 0.0:
		return
	var best: Unit = null
	var bd := float(z["r"])
	for u in A.enemies():
		var d: float = u.pos.distance_to(z["pos"])
		if d <= bd:
			bd = d
			best = u
	if best == null:
		z["zap_t"] = 0.15
		return
	z["zap_t"] = float(s["zap_every"])
	var top: Vector2 = z["pos"] + Vector2(0, -10)
	A.fx("zap", top, {"to": best.pos + Vector2(0, -4), "color": PixelArt.STORM, "life": 0.14})
	if A.hit(best, Progression.stat("arc_rod", "damage"), int(s["impact"]), (best.pos - z["pos"]).normalized(), 6.0):
		Progression.add_xp("arc_rod", float(s["xp_hit"]))


func draw_field(c) -> void:
	for z in A.zones:
		match z["kind"]:
			"throw":
				# the device in the air over a ring where it will land
				var k := clampf(float(z["t"]) / maxf(0.01, float(z["delay"])), 0.0, 1.0)
				var at: Vector2 = z["from"].lerp(z["pos"], k) + Vector2(0, -26.0 * sin(PI * k))
				c.mark_circle(at, 2.0, _col(z["device"]), true, -1.0, true)
				c.mark_arc(z["pos"], float(z["r"]), 0, TAU, 24, Color(_col(z["device"]), 0.4 + 0.5 * k), 1.0, true)
			"smoke":
				var fade := clampf((float(z["life"]) - float(z["t"])) / 1.0, 0.0, 1.0)
				for i in 6:
					var o := Vector2.from_angle(i * 1.05 + float(z["t"]) * 0.3) * float(z["r"]) * 0.45
					c.mark_circle(z["pos"] + o, float(z["r"]) * 0.6, Color(0.55, 0.58, 0.64, 0.16 * fade), true, -1.0, true)
			"tar":
				c.mark_circle(z["pos"], float(z["r"]), Color(0.06, 0.05, 0.04, 0.55), true, -1.0, true)
				c.mark_arc(z["pos"], float(z["r"]), 0, TAU, 24, Color(PixelArt.FIRE, 0.25), 1.0, true)
			"arc_rod":
				c.mark_arc(z["pos"], float(z["r"]), 0, TAU, 32, Color(PixelArt.STORM, 0.18), 1.0, true)
			"lantern":
				# its ring on the ground, eight gold stars turning round it
				var fade := clampf((float(z["life"]) - float(z["t"])) / 1.5, 0.2, 1.0)
				c.mark_arc(z["pos"], float(z["r"]), 0, TAU, 40, Color(PixelArt.GOLD, 0.45 * fade), 1.0, true)
				c.mark_circle(z["pos"], float(z["r"]), Color(PixelArt.GOLD, 0.05 * fade), true, -1.0, true)
				for i in 8:
					var at: Vector2 = z["pos"] + Vector2.from_angle(TAU * i / 8.0 + float(z["t"]) * 0.4) * float(z["r"])
					c.mark_circle(at, 1.2, Color(PixelArt.GOLD, 0.9 * fade), true, -1.0, true)


func _col(id: String) -> Color:
	match id:
		"arc_rod":
			return PixelArt.STORM
		"smoke_jar":
			return PixelArt.PAPER
		"tar_pot":
			return PixelArt.EARTH
		"star_lantern":
			return PixelArt.GOLD
	return PixelArt.FIRE


## Holding the key shows where it lands and how big what it leaves will be.
func draw_preview(c, id: String, _ghost_old: int) -> bool:
	if not Progression.is_device(id):
		return false
	var at := land_point(id)
	var r := size_of(id)
	var col := _col(id)
	c.mark_line(K.origin(), at, Color(col, 0.35), 1.0, true)
	c.mark_arc(at, r, 0, TAU, 28, col, 1.0, true)
	c.mark_circle(at, r, Color(col, 0.08), true, -1.0, true)
	return true
