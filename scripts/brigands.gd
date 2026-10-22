extends RefCounted
## Brigands and free companies (enemy spec §8.2; build item N-6.3): people, not Hollows. They fight
## dirty and carry things the world can use against them. A Cutthroat stabs, lunges and backs off;
## a Crossbowman shoots a heavy bolt and stands reloading after it; a Shieldman's wooden shield
## stops what comes from his front until fire burns it away; a Powder Monkey lobs powder pots and
## carries a keg that goes up when fire finds him; the Brigand Captain swings hard, nets you
## (Blink gets you out) and calls volleys from his Crossbowmen.

const KINDS := ["cutthroat", "crossbowman", "shieldman", "powder_monkey", "brigand_captain"]

var A  # the arena
var AI  # scripts/ai.gd


func _init(arena, ai) -> void:
	A = arena
	AI = ai


## Runs a brigand's mind; false for any other kind.
func mind(u: Unit, dt: float) -> bool:
	match u.kind:
		"cutthroat":
			_cutthroat(u, dt)
		"crossbowman":
			_crossbowman(u, dt)
		"shieldman":
			_shieldman(u, dt)
		"powder_monkey":
			_monkey(u, dt)
		"brigand_captain":
			_captain(u, dt)
		_:
			return false
	return true


func _rec(u: Unit) -> Dictionary:
	return A.D["enemies"][u.kind]


func _face(u: Unit, to: Vector2) -> void:
	u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing


## A swing: the red wedge in front of it is its hitbox.
func _swing(u: Unit, to: Vector2, extra := 2.0) -> void:
	var e := _rec(u)
	u.state = "windup"
	u.state_t = float(e["windup"])
	u.aim = to.normalized()
	_face(u, to)
	A.add_zone({"kind": "slash", "owner": u.id, "pos": u.pos, "dir": u.aim, "reach": float(e["reach"]) + extra,
		"arc": 1.7, "delay": float(e["windup"]), "dmg": float(e["damage"]), "impact": int(e.get("impact", 1))})


## Keeps about `keep` from you, sidestepping a little.
func _keep_off(u: Unit, to: Vector2, dt: float, side := 0.4) -> void:
	var keep := float(_rec(u)["keep"])
	var d := to.length()
	var dir := Vector2.ZERO
	if d > keep + 25.0:
		dir = to
	elif d < keep - 30.0:
		dir = -to
	dir += to.orthogonal().normalized() * (side if int(u.id) % 2 == 0 else -side)
	AI._step(u, dir, dt)
	_face(u, to)


func _cutthroat(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 8.0 and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				_swing(u, to, 4.0)
			else:
				AI._step(u, AI._toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				# the stab ends in a lunge, then he backs off out of reach
				u.vel = u.aim * float(e["lunge"])
				u.state = "back"
				u.state_t = float(e["back_off"])
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.85, 1.15)
		"back":
			u.state_t -= dt
			AI._step(u, -to, dt, 0.8)
			if u.state_t <= 0.0:
				u.state = "move"


func _crossbowman(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			_keep_off(u, to, dt, 0.25)
			var called: bool = u.flags.get("volley", false)
			if to.length() < float(e["range"]) and u.cooldown("attack") <= 0.0 and (called or AI.may_attack(u)):
				u.flags.erase("volley")
				u.state = "windup"
				u.state_t = float(e["windup"])
				var start := u.pos + Vector2(0, -6)
				A.add_zone({"kind": "line", "owner": u.id, "a": start, "b": start + to.normalized() * float(e["range"]),
					"delay": float(e["windup"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "reload"  # he stands winding the crossbow: the opening
				u.state_t = float(e["reload"])
		"reload":
			u.state_t -= dt
			_face(u, to)
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"])


func _shieldman(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 3.0 and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				_swing(u, to)
			else:
				AI._step(u, AI._toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"])


func _monkey(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			_keep_off(u, to, dt)
			if to.length() < float(e["range"]) and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				var pot: Dictionary = e["pot"]
				u.state = "windup"
				u.state_t = float(e["windup"])
				# the circle where it lands shows from the start: the wind-up, then the pot's flight
				u.flags["pot"] = A.add_zone({"kind": "pot", "owner": u.id, "from": u.pos, "pos": A.clamp_in(A.player.pos, 2.0),
					"r": float(pot["r"]), "fly_at": float(e["windup"]), "delay": float(e["windup"]) + float(pot["flight"]),
					"dmg": float(pot["damage"]), "impact": int(pot["impact"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.85, 1.15)
				var z: Dictionary = u.flags.get("pot", {})
				if not z.is_empty():
					z["owner"] = -1  # thrown: it lands whatever happens to him now
					z["from"] = u.pos
				u.flags.erase("pot")


func _captain(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	var d := to.length()
	# He calls a volley: every Crossbowman ready to shoot does, together.
	u.flags["volley_t"] = float(u.flags.get("volley_t", 0.0)) + dt
	if u.flags["volley_t"] >= float(e["volley"]["every"]):
		u.flags["volley_t"] = 0.0
		var n := 0
		for o in A.enemies():
			if o.kind == "crossbowman" and o.state == "move":
				o.flags["volley"] = true
				o.cd["attack"] = 0.0
				n += 1
		if n > 0:
			A.fx("ring", u.pos, {"color": PixelArt.DANGER, "r": 18.0, "life": 0.4})
			A.stats["volleys"] = int(A.stats.get("volleys", 0)) + 1
			if not A.stats.has("volley_seen"):
				A.stats["volley_seen"] = true
				A.toast.emit("\"Loose!\" The Captain calls a volley.", PixelArt.DANGER)
	match u.state:
		"move":
			var net: Dictionary = e["net"]
			if d < float(e["reach"]) + 4.0 and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				_swing(u, to)
			elif d > 50.0 and d < float(net["range"]) and u.cooldown("net") <= 0.0 and AI.may_attack(u):
				u.state = "windup"
				u.state_t = float(net["windup"])
				u.cd["net"] = float(net["cooldown"])
				_face(u, to)
				var start := u.pos + Vector2(0, -6)
				A.add_zone({"kind": "line", "owner": u.id, "a": start, "b": start + to.normalized() * float(net["range"]),
					"delay": float(net["windup"]), "net": true})
			else:
				AI._step(u, AI._toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = maxf(u.cooldown("attack"), float(e["cooldown"]))


## The shot a "line" telegraph lets fly, for its owner: a Slinger's stone, a Crossbowman's bolt, the
## Captain's net.
func shot(o: Unit, z: Dictionary) -> Dictionary:
	var e := _rec(o)
	var dir: Vector2 = (z["b"] - z["a"]).normalized()
	if z.get("net", false):
		var n: Dictionary = e["net"]
		return {"kind": "net", "team": 1, "pos": z["a"], "vel": dir * float(n["speed"]), "r": float(n["radius"]), "dmg": 2.0,
			"impact": 0, "life": float(n["range"]) / float(n["speed"]), "color": PixelArt.PAPER, "root": float(n["root"])}
	return {"kind": str(e.get("shot_kind", "rock")), "team": 1, "pos": z["a"], "vel": dir * float(e["shot_speed"]),
		"r": float(e["shot_radius"]), "dmg": float(e["damage"]), "impact": int(e.get("impact", 1)), "life": 1.6,
		"color": PixelArt.DANGER}


## A powder pot lands: a burst that throws you, and the ground under it catches.
func pot(z: Dictionary) -> void:
	A.fx("burst", z["pos"], {"color": PixelArt.FIRE, "r": float(z["r"]), "life": 0.35})
	A.fx("dust", z["pos"], {"r": float(z["r"]), "life": 0.6})
	var to: Vector2 = A.player.pos - z["pos"]
	if to.length() < float(z["r"]) + A.player.radius:
		A.hit(A.player, float(z["dmg"]), int(z["impact"]), to.normalized(), 70.0)
	if A.town != null:
		A.town.burn_ground(z["pos"], float(z["r"]) * 0.4, 1)
	Sfx.play("cast_fire", -2.0)


## Where its shield faces: straight at you, or for a heavy one (with `turn`) wherever it has
## swung round to so far.
func shield_dir(u: Unit) -> Vector2:
	return u.flags.get("guard_dir", (A.player.pos - u.pos).normalized())


## A Shieldman's guard: a hit from inside his shield's arc, no heavier than it stops, is blocked.
## Fire on the shield burns it away instead. A Shieldknight's iron shield doesn't burn, but
## lightning runs through it. True if the shield took the hit.
func guards(u: Unit, dir: Vector2, impact: int, fire: bool, storm := false) -> bool:
	var g: Dictionary = _rec(u).get("guard", {})
	if g.is_empty() or u.flags.get("shield_gone", false) or dir.length() < 0.1 or u.broken_t > 0.0:
		return false
	var front: Vector2 = shield_dir(u)
	if (-dir).dot(front) < cos(deg_to_rad(float(g["arc"]) * 0.5)):
		A.guide.found(u, "flanked")
		return false  # from the side or behind
	if storm and g.get("iron", false):
		A.guide.found(u, "conducted")
		return false
	if fire and not g.get("iron", false):
		u.flags["shield_gone"] = true
		A.guide.found(u, "shield_burned")
		A.fx("burst", u.pos + front * 6.0 + Vector2(0, -6), {"color": PixelArt.FIRE, "r": 9.0, "life": 0.5})
		A.stats["shields_burned"] = int(A.stats.get("shields_burned", 0)) + 1
		u.reaction = "stagger"
		u.reaction_t = float(A.D["reaction_time"]["stagger"])
		u.reaction_len = u.reaction_t
		return true
	if impact > int(g["stops_impact"]):
		return false  # a heavy blow goes through
	A.fx("clink", u.pos + front * 6.0 + Vector2(0, -8), {"life": 0.3})
	A.stats["guarded"] = int(A.stats.get("guarded", 0)) + 1
	return true


## Fire found a Powder Monkey: his keg goes up, hurting everyone near, him first.
func on_fire(u: Unit) -> void:
	var e := _rec(u)
	if not e.has("keg") or u.flags.get("keg_gone", false) or u.dead:
		return
	u.flags["keg_gone"] = true
	A.guide.found(u, "keg")
	var k: Dictionary = e["keg"]
	var r := float(k["r"])
	A.fx("burst", u.pos, {"color": PixelArt.FIRE_HOT, "r": r, "life": 0.45})
	A.fx("ring", u.pos, {"color": PixelArt.FIRE, "r": r, "life": 0.35})
	A.shake = maxf(A.shake, 4.0)
	A.stats["kegs_blown"] = int(A.stats.get("kegs_blown", 0)) + 1
	Sfx.play("cast_fire", 4.0)
	if A.town != null:
		A.town.burn_ground(u.pos, r * 0.5, 1)
	var was: String = A._src_kind
	for o in A.units.duplicate():
		if o.dead or o.pos.distance_to(u.pos) > r + o.radius:
			continue
		var dir: Vector2 = (o.pos - u.pos).normalized() if o != u else Vector2.ZERO
		A._src_kind = "fire" if o.team == 1 else ""  # it sets alight what catches, and the next keg
		A.hit(o, float(k["damage"]), int(k["impact"]), dir, 80.0)
	A._src_kind = was


## The Captain's net caught you: you can't walk until it lets go or you Blink out.
func netted() -> void:
	A.player.flags["net_t"] = float(A.D["enemies"]["brigand_captain"]["net"]["root"])
	A.fx("ring", A.player.pos, {"color": PixelArt.PAPER, "r": 10.0, "life": 0.4})
	if not A.stats.has("net_seen"):
		A.stats["net_seen"] = true
		A.toast.emit("Netted! Blink out, or wait for it to slip.", PixelArt.PAPER)
