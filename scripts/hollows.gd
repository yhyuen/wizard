extends RefCounted
## More Hollows (enemy spec §8.1; build item N-6.3): the Lantern-eater, the Hollow Choir and the
## Overdrawn Husk. They teach that light and fire control a crowd, and that a caster is a target.
## The Lantern-eater isn't light-shy: it walks into a lamp's pool and smothers the lamp, and the
## Hollows behind it follow into the dark. The Choir hangs back and hums; Hollows near it stand
## firmer and move faster until a heavy hit hushes it. The Husk was a wizard: it throws a wild
## ember bolt, and when Broken it leaks Aether you can stand in and drink.

var A  # the arena
var AI  # scripts/ai.gd


func _init(arena, ai) -> void:
	A = arena
	AI = ai


func mind(u: Unit, dt: float) -> bool:
	match u.kind:
		"lantern_eater":
			_eater(u, dt)
		"choir":
			_choir(u, dt)
		"husk":
			_husk(u, dt)
		"lightdrinker":
			_drinker(u, dt)
		_:
			return false
	return true


func _rec(u: Unit) -> Dictionary:
	return A.D["enemies"][u.kind]


## The nearest lit lamp it could reach and smother, or {}.
func _lamp_for(u: Unit) -> Dictionary:
	if A.town == null:
		return {}
	var best := {}
	var bd := float(_rec(u)["seek_r"])
	for l in A.town.lit_lamps_near(u.pos, bd):
		if l["lit"] and l["pos"].distance_to(u.pos) < bd:
			bd = l["pos"].distance_to(u.pos)
			best = l
	return best


func _eater(u: Unit, dt: float) -> void:
	var e := _rec(u)
	match u.state:
		"smother":
			var l: Dictionary = u.flags.get("lamp", {})
			if l.is_empty() or not l["lit"]:
				u.state = "move"  # someone put it out first, or it's gone
				return
			u.state_t -= dt
			if u.state_t <= 0.0:
				A.town.smother_lamp(l)
				A.fx("dust", l["pos"], {"color": PixelArt.INK, "r": 14.0, "life": 0.6})
				A.stats["lamps_smothered"] = int(A.stats.get("lamps_smothered", 0)) + 1
				u.flags.erase("lamp")
				u.state = "move"
			return
		"move":
			var l := _lamp_for(u)
			if not l.is_empty():
				if u.pos.distance_to(l["pos"]) < 10.0:
					u.state = "smother"
					u.state_t = float(e["smother_s"])
					u.flags["lamp"] = l
				else:
					AI._step(u, AI._toward(u, l["pos"], dt), dt)
				return
	AI._hollow(u, dt)  # no lamp left near: a Hollow like the rest


func _choir(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	var keep := float(e["keep"])
	var dir := Vector2.ZERO
	if to.length() > keep + 30.0:
		dir = to
	elif to.length() < keep - 20.0:
		dir = -to
	AI._step(u, dir, dt)
	u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
	if u.cooldown("attack") > 0.0:
		u.state = "move"  # hushed
		return
	u.state = "hum"
	u.state_t = 1.0
	for o in A.enemies():
		if o != u and o.pos.distance_to(u.pos) < float(e["hum_r"]) and str(A.D["enemies"][o.kind].get("faction", "")) == "hollows":
			o.flags["hum_t"] = 0.25
	u.flags["ring_t"] = float(u.flags.get("ring_t", 0.0)) - dt
	if u.flags["ring_t"] <= 0.0:
		u.flags["ring_t"] = 0.8
		A.fx("ring", u.pos, {"color": PixelArt.HOURS, "r": float(e["hum_r"]), "life": 0.8})


## The Choir was interrupted: quiet for a while.
func hush(u: Unit) -> void:
	u.cd["attack"] = float(_rec(u)["hush_s"])
	u.state = "move"
	A.stats["hushed"] = int(A.stats.get("hushed", 0)) + 1


func _husk(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			var keep := float(e["keep"])
			var dir := Vector2.ZERO
			if to.length() > keep + 25.0:
				dir = to
			elif to.length() < keep - 30.0:
				dir = -to
			AI._step(u, dir, dt)
			u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
			if to.length() < float(e["range"]) and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				u.state = "windup"
				u.state_t = float(e["windup"])
				# it aims badly: the line shows where the bolt will really go
				u.aim = to.normalized().rotated(A.rng.randf_range(-1.0, 1.0) * float(e["wild"]))
				var start := u.pos + Vector2(0, -8)
				A.add_zone({"kind": "line", "owner": u.id, "a": start, "b": start + u.aim * float(e["range"]),
					"delay": float(e["windup"]), "ember": true})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.85, 1.15)


## The ember bolt a Husk lets fly.
func shot(o: Unit, z: Dictionary) -> Dictionary:
	var e := _rec(o)
	var dir: Vector2 = (z["b"] - z["a"]).normalized()
	return {"kind": "ember", "team": 1, "pos": z["a"], "vel": dir * float(e["shot_speed"]), "r": float(e["shot_radius"]),
		"dmg": float(e["damage"]), "impact": 1, "life": float(e["range"]) / float(e["shot_speed"]), "color": PixelArt.FIRE}


## An enemy was Broken: a Husk leaks its Aether onto the ground.
func on_broken(u: Unit) -> void:
	if u.kind == "lightdrinker" and A.town != null:
		# Broken, it spits the light back out: the dark lamps round it relight.
		for l in A.town.lamps:
			if not l["lit"] and l["pos"].distance_to(u.pos) < float(_rec(u)["spit_r"]):
				A.town.light_lamp(l, "spat")
		A.fx("ring", u.pos, {"color": PixelArt.GOLD, "r": float(_rec(u)["spit_r"]), "life": 0.8})
		A.stats["light_spat"] = int(A.stats.get("light_spat", 0)) + 1
		return
	if u.kind != "husk":
		return
	var k: Dictionary = _rec(u)["leak"]
	A.add_zone({"kind": "leak", "pos": u.pos, "r": float(k["r"]), "life": float(k["life"]), "left": float(k["aether"])})
	A.stats["leaks"] = int(A.stats.get("leaks", 0)) + 1


## A leak gives you Aether while you stand in it.
func update(dt: float) -> void:
	for z in A.zones:
		if z["kind"] != "leak" or float(z["left"]) <= 0.0:
			continue
		if A.player.pos.distance_to(z["pos"]) < float(z["r"]) + A.player.radius:
			var k: Dictionary = A.D["enemies"]["husk"]["leak"]
			var take: float = minf(float(z["left"]), float(k["rate"]) * dt)
			take = minf(take, A.kit.max_aether() - A.kit.aether)
			if take > 0.0:
				z["left"] = float(z["left"]) - take
				A.kit.aether += take
				A.stats["drank"] = float(A.stats.get("drank", 0.0)) + take


## The Lightdrinker (Lantern Night's boss): every lamp near it goes out as it walks at you, and it
## swings like a great Hollow.
func _drinker(u: Unit, dt: float) -> void:
	var e := _rec(u)
	if A.town != null:
		for l in A.town.lit_lamps_near(u.pos, float(e["drink_r"])):
			if l["lit"]:
				A.town.smother_lamp(l)
				A.stats["lamps_drunk"] = int(A.stats.get("lamps_drunk", 0)) + 1
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 4.0 and u.cooldown("attack") <= 0.0:
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
				A.add_zone({"kind": "slash", "owner": u.id, "pos": u.pos, "dir": to.normalized(),
					"reach": float(e["reach"]) + 4.0, "arc": 2.2, "delay": float(e["windup"]), "dmg": float(e["damage"])})
			else:
				AI._step(u, AI._toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"])
