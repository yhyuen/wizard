extends RefCounted
## The Knights of the Iron Oath's picket (enemy spec §8.3; build item N-6.6): the anti-wizard
## order. The Oath Squire fights in mail that eats small spells. The Shieldknight wears plate and
## carries an iron shield fire can't burn; Shieldknights advance side by side, a wall you go round
## or send lightning through. The Silencer hangs back and rings a witch-bell: a circle where no spell
## can be cast for a moment. Step out, or break the bell with a heavy blow.

var A  # the arena
var AI  # scripts/ai.gd


func _init(arena, ai) -> void:
	A = arena
	AI = ai


func mind(u: Unit, dt: float) -> bool:
	match u.kind:
		"oath_squire":
			_squire(u, dt)
		"shieldknight":
			_shieldknight(u, dt)
		"silencer":
			_silencer(u, dt)
		_:
			return false
	return true


func _rec(u: Unit) -> Dictionary:
	return A.D["enemies"][u.kind]


## Closes in and swings, like a brigand with a sword.
func _melee(u: Unit, dt: float, step: Vector2) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 3.0 and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				AI.brig._swing(u, to)
			else:
				AI._step(u, step, dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.9, 1.1)


func _squire(u: Unit, dt: float) -> void:
	_melee(u, dt, AI._toward(u, A.player.pos, dt))


## Toward you, but keeping `wall` px from the other Shieldknights: they come on side by side. The
## iron shield swings round after you slowly, so a quick wizard can get to its side.
func _shieldknight(u: Unit, dt: float) -> void:
	var want: Vector2 = (A.player.pos - u.pos).normalized()
	var g: Vector2 = u.flags.get("guard_dir", want)
	if u.stun <= 0.0 and u.broken_t <= 0.0:
		var step := deg_to_rad(float(_rec(u)["guard"]["turn"])) * dt
		g = g.rotated(clampf(g.angle_to(want), -step, step))
	u.flags["guard_dir"] = g
	var dir: Vector2 = AI._toward(u, A.player.pos, dt).normalized()
	var wall := float(_rec(u)["wall"])
	for o in A.enemies():
		if o != u and o.kind == "shieldknight":
			var away: Vector2 = u.pos - o.pos
			if away.length() < wall and away.length() > 0.1:
				dir += away.normalized() * (1.0 - away.length() / wall) * 1.5
	_melee(u, dt, dir)


func _silencer(u: Unit, dt: float) -> void:
	var e := _rec(u)
	if u.flags.get("bell_gone", false):
		_melee(u, dt, AI._toward(u, A.player.pos, dt))  # the bell's broken: it comes at you with the mace
		return
	var b: Dictionary = e["bell"]
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			AI.brig._keep_off(u, to, dt, 0.2)
			if to.length() < float(e["range"]) and u.cooldown("bell") <= 0.0 and AI.may_attack(u):
				u.state = "windup"
				u.state_t = float(b["windup"])
				u.cd["bell"] = float(b["cooldown"])
				# the circle shows where the bell's ring will land, and how big it is
				A.add_zone({"kind": "bell", "owner": u.id, "pos": A.clamp_in(A.player.pos, 2.0), "r": float(b["r"]),
					"delay": float(b["windup"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"


## The bell rings: for a moment no spell can be cast inside the circle, and a cast you are winding
## there breaks.
func ring(z: Dictionary) -> void:
	var b: Dictionary = A.D["enemies"]["silencer"]["bell"]
	A.add_zone({"kind": "hush", "pos": z["pos"], "r": float(z["r"]), "life": float(b["hush_s"])})
	A.fx("ring", z["pos"], {"color": PixelArt.PAPER, "r": float(z["r"]), "life": 0.5})
	Sfx.play("cast_storm", -6.0)
	A.stats["bells"] = int(A.stats.get("bells", 0)) + 1
	if hushed(A.player.pos):
		if not A.kit.wind.is_empty():
			A.kit.interrupt()
		if not A.stats.has("bell_seen"):
			A.stats["bell_seen"] = true
			A.toast.emit("The bell rings. No spell works inside its circle.", PixelArt.PAPER)


## True if a Silencer's ring stops spells at `at`.
func hushed(at: Vector2) -> bool:
	for z in A.zones:
		if z["kind"] == "hush" and at.distance_to(z["pos"]) < float(z["r"]):
			return true
	return false


## A Silencer took a hit: a heavy one breaks its bell.
func struck(u: Unit, impact: int) -> void:
	if u.kind == "silencer" and impact >= int(_rec(u)["bell"]["breaks_at"]):
		break_bell(u)


func break_bell(u: Unit) -> void:
	if u.kind != "silencer" or u.flags.get("bell_gone", false):
		return
	u.flags["bell_gone"] = true
	A.guide.found(u, "bell_broken")
	A.cancel_zones(u.id)
	if u.state == "windup":
		u.state = "move"
	A.fx("burst", u.pos + Vector2(0, -8), {"color": PixelArt.PAPER, "r": 8.0, "life": 0.4})
	A.fx("clink", u.pos + Vector2(0, -12), {"life": 0.4})
	A.stats["bells_broken"] = int(A.stats.get("bells_broken", 0)) + 1
