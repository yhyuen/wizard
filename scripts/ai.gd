extends RefCounted
## Enemy minds. Every attack has a telegraph that is its hitbox, so the player can dodge on read.
## Hollows swing a short red wedge, Slingers aim a red line, and Silas Vane (Storm) uses a
## skill-shot Spark, a charged Arc Lance line and Storm Call circles, and blinks out of Pillars.

var A


func _init(arena) -> void:
	A = arena


func update(u: Unit, dt: float) -> void:
	u.moving = false
	if u.state == "enter":
		u.state_t -= dt
		if u.state_t <= 0.0:
			u.state = "move"
		return
	if u.locked() or A.player.dead or A.phase in ["won", "lost"]:
		return
	if u.flags.get("dummy", false):
		_step(u, A.player.pos - u.pos, dt, 0.3 if u.pos.distance_to(A.player.pos) > 30.0 else 0.0)
		return
	match u.kind:
		"hollow":
			_hollow(u, dt)
		"slinger":
			_slinger(u, dt)
		"inverted":
			_inverted(u, dt)
		"rival":
			_rival(u, dt)


## A hard hit (stagger or more) breaks a wind-up: the telegraph goes away.
func interrupt(u: Unit) -> void:
	if u.state in ["windup", "spark", "lance"]:
		A.cancel_zones(u.id)
		u.state = "move"
		u.state_t = 0.4


func _step(u: Unit, dir: Vector2, dt: float, mult := 1.0) -> void:
	if dir.length() < 0.01:
		return
	u.pos = A.clamp_in(u.pos + dir.normalized() * A.move_speed(u) * mult * dt, u.radius)
	u.moving = true
	if absf(dir.x) > 0.1:
		u.facing = signf(dir.x)


func _hollow(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["hollow"]
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 3.0 and u.cooldown("attack") <= 0.0:
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
				A.add_zone({"kind": "slash", "owner": u.id, "pos": u.pos, "dir": to.normalized(),
					"reach": float(e["reach"]) + 2.0, "arc": 1.9, "delay": float(e["windup"]), "dmg": float(e["damage"])})
			else:
				_step(u, to, dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"])


func _slinger(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["slinger"]
	var to: Vector2 = A.player.pos - u.pos
	var d = to.length()
	match u.state:
		"move":
			var keep = float(e["keep"])
			var dir = Vector2.ZERO
			if d > keep + 25.0:
				dir = to
			elif d < keep - 30.0:
				dir = -to
			dir += to.orthogonal().normalized() * (0.6 if int(u.id) % 2 == 0 else -0.6)
			_step(u, dir, dt)
			if d < float(e["range"]) and u.cooldown("attack") <= 0.0:
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
				var start = u.pos + Vector2(0, -6)
				A.add_zone({"kind": "line", "owner": u.id, "a": start, "b": start + to.normalized() * float(e["range"]),
					"delay": float(e["windup"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.8, 1.2)


## The Backward Slinger: keeps its back to you, and its stones fly the wrong way. The telegraph
## runs from a spot behind you to its hand; the stone appears at that spot and flies home.
func _inverted(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["inverted"]
	var to: Vector2 = A.player.pos - u.pos
	var d = to.length()
	match u.state:
		"move":
			var keep = float(e["keep"])
			var dir = Vector2.ZERO
			if d > keep + 25.0:
				dir = to
			elif d < keep - 30.0:
				dir = -to
			dir += to.orthogonal().normalized() * (-0.6 if int(u.id) % 2 == 0 else 0.6)
			_step(u, dir, dt)
			u.facing = -signf(to.x) if absf(to.x) > 0.1 else u.facing
			if d < float(e["range"]) and u.cooldown("attack") <= 0.0:
				u.state = "windup"
				u.state_t = float(e["windup"])
				var hand = u.pos + Vector2(0, -6)
				var from = A.clamp_in(A.player.pos + to.normalized() * float(e["behind"]), 2.0)
				A.add_zone({"kind": "rline", "owner": u.id, "a": from, "b": hand, "delay": float(e["windup"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.8, 1.2)


func _rival(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["rival"]
	var P: Unit = A.player
	var to: Vector2 = P.pos - u.pos
	var d = to.length()
	# Dodge on read: a Pillar or Meteor circle over him makes him blink out after a short delay.
	if u.cooldown("blink") <= 0.0 and not u.flags.has("blink_in"):
		for z in A.zones:
			if z["kind"] in ["pillar", "meteor", "strike"] and u.pos.distance_to(z["pos"]) < z["r"] + u.radius:
				u.flags["blink_in"] = float(e["blink"]["react"])
				break
	if u.flags.has("blink_in"):
		u.flags["blink_in"] -= dt
		if u.flags["blink_in"] <= 0.0:
			u.flags.erase("blink_in")
			_rival_blink(u, to)
			return
	match u.state:
		"move":
			var dir = Vector2.ZERO
			if d > 150.0:
				dir = to
			elif d < 95.0:
				dir = -to
			u.flags["strafe_t"] = float(u.flags.get("strafe_t", 0.0)) - dt
			if u.flags["strafe_t"] <= 0.0:
				u.flags["strafe"] = 1.0 if A.rng.randf() < 0.5 else -1.0
				u.flags["strafe_t"] = A.rng.randf_range(1.5, 3.0)
			dir += to.orthogonal().normalized() * float(u.flags["strafe"]) * 0.8
			_step(u, dir, dt)
			u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
			u.state_t -= dt
			if u.state_t <= 0.0:
				_rival_choose(u, to)
		"spark":
			u.state_t -= dt
			if u.state_t <= 0.0:
				var s: Dictionary = e["spark"]
				var dir: Vector2 = (u.aim - u.pos).normalized()
				A.spawn_proj({"kind": "spark", "team": 1, "pos": u.pos + Vector2(0, -8) + dir * 6.0,
					"vel": dir * float(s["speed"]), "r": float(s.get("radius", 3.0)), "dmg": float(s["damage"]), "impact": 1,
					"life": 1.6, "color": PixelArt.STORM})
				_rival_recover(u, 0.35)
		"lance":
			u.state_t -= dt
			if u.state_t <= 0.0:
				_rival_recover(u, 0.5)


func _rival_choose(u: Unit, to: Vector2) -> void:
	var e: Dictionary = A.D["enemies"]["rival"]
	var d = to.length()
	var roll = A.rng.randf()
	if u.cooldown("storm") <= 0.0 and roll < 0.3:
		var s: Dictionary = e["storm"]
		var P: Unit = A.player
		var lead: Vector2 = P.flags.get("move", Vector2.ZERO) * 0.7
		var spots = [P.pos, P.pos + lead, P.pos + Vector2(A.rng.randf_range(-30, 30), A.rng.randf_range(-24, 24))]
		for i in spots.size():
			A.add_zone({"kind": "storm", "owner": u.id, "pos": A.clamp_in(spots[i]), "r": float(s["radius"]),
				"delay": float(s["delay"]) + i * 0.15, "dmg": float(s["damage"])})
		u.cd["storm"] = float(s["cooldown"])
		u.state_t = 0.9
		return
	if d < 165.0 and roll < 0.6 and u.cooldown("lance") <= 0.0:
		var l: Dictionary = e["lance"]
		var start = u.pos + Vector2(0, -6)
		A.add_zone({"kind": "lance", "owner": u.id, "a": start, "b": start + to.normalized() * float(l["length"]),
			"w": float(l["width"]), "delay": float(l["windup"]), "dmg": float(l["damage"]), "impact": int(l["impact"])})
		u.state = "lance"
		u.state_t = float(l["windup"])
		u.cd["lance"] = 2.5
		return
	u.state = "spark"
	u.state_t = float(e["spark"]["windup"])
	u.aim = A.player.pos
	A.add_zone({"kind": "line", "owner": u.id, "a": u.pos + Vector2(0, -8), "b": u.pos + Vector2(0, -8) + to.normalized() * 40.0,
		"delay": float(e["spark"]["windup"]), "visual": true})


func _rival_recover(u: Unit, t: float) -> void:
	u.state = "move"
	u.state_t = t + A.rng.randf_range(0.2, 0.6)


func _rival_blink(u: Unit, to: Vector2) -> void:
	var e: Dictionary = A.D["enemies"]["rival"]
	var side = to.orthogonal().normalized() * (1.0 if A.rng.randf() < 0.5 else -1.0)
	var dest: Vector2 = A.clamp_in(u.pos + side * float(e["blink"]["dist"]), u.radius)
	A.fx("trail", u.pos + Vector2(0, -8), {"to": dest + Vector2(0, -8), "color": PixelArt.STORM, "life": 0.3})
	A.cancel_zones(u.id)
	u.pos = dest
	u.cd["blink"] = float(e["blink"]["cooldown"])
	u.state = "move"
	u.state_t = 0.3
