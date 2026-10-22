extends RefCounted
## Enemy minds. Every attack has a telegraph that is its hitbox, so the player can dodge on read.
## Hollows swing a short red wedge, Slingers aim a red line, and Silas Vane (Storm) uses a
## skill-shot Spark, a charged Arc Lance line and Storm Call circles, and blinks out of Pillars.
## In the halls, embers rush and lunge, and the Kiln Warden never moves: its fight is reading its rhythm.

const Brigands := preload("res://scripts/brigands.gd")

var A
var brig  # brigands' minds, guard, keg and net (N-6.3)


func _init(arena) -> void:
	A = arena
	brig = Brigands.new(arena, self)


func update(u: Unit, dt: float) -> void:
	u.moving = false
	if u.state == "enter":
		u.state_t -= dt
		if u.state_t <= 0.0:
			u.state = "move"
		return
	if u.locked() or A.player.dead or A.phase in ["won", "lost"]:
		return
	# A burning husk panics: it runs from you, lighting what it passes (enemy spec §5.2).
	if u.burn_t > 0.0 and str(A.D["enemies"][u.kind].get("faction", "")) in A.D["foes"]["states"]["panic"]:
		u.state = "move"
		_step(u, u.pos - A.player.pos, dt, 1.3)
		return
	if u.flags.get("dummy", false):
		_step(u, A.player.pos - u.pos, dt, 0.3 if u.pos.distance_to(A.player.pos) > 30.0 else 0.0)
		return
	if brig.mind(u, dt):
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
		"ember":
			_ember(u, dt)
		"warden":
			_warden(u, dt)


## The fight director (enemy spec §6.4; N-6.1): at most `melee` melee and `ranged` ranged enemies
## may be winding up an attack on you at once, and none further than `reach` from you (the
## off-screen rule). The rest keep moving until a turn comes free. Duellists and bosses aren't counted.
func may_attack(u: Unit) -> bool:
	var Dr: Dictionary = A.D["foes"]["director"]
	if u.pos.distance_to(A.player.pos) > float(Dr["reach"]):
		return false
	var kind: String = str(A.D["enemies"][u.kind].get("attack", "melee"))
	if not Dr.has(kind):
		return true
	var busy := 0
	for o in A.enemies():
		if o != u and o.state == "windup" and str(A.D["enemies"][o.kind].get("attack", "")) == kind:
			busy += 1
	return busy < int(Dr[kind])


## An enemy's Focus: Impact above it breaks a wind-up (spell and combat spec §9). Its "focus" in
## data/spells.json, else one above its Poise (a stagger or more, as before Focus existed).
func focus(u: Unit) -> int:
	return int(A.D["enemies"][u.kind].get("focus", u.poise + 1))


## A hit above its Focus breaks a wind-up: the telegraph goes away, a cracked sigil puffs over it,
## and the attack comes back at half its cooldown.
func interrupt(u: Unit) -> void:
	if u.state in ["windup", "spark", "lance"]:
		A.cancel_zones(u.id)
		u.state = "move"
		u.state_t = 0.4
		var cd := float(A.D["enemies"][u.kind].get("cooldown", 0.0)) * 0.5
		u.cd["attack"] = maxf(u.cooldown("attack"), cd)
		A.fx("clink", u.pos + Vector2(0, -12), {"life": 0.35})
		A.stats["interrupts"] = int(A.stats.get("interrupts", 0)) + 1


func _step(u: Unit, dir: Vector2, dt: float, mult := 1.0) -> void:
	if dir.length() < 0.01:
		return
	u.pos = A.clamp_in(u.pos + dir.normalized() * A.move_speed(u) * mult * dt, u.radius)
	u.moving = true
	if absf(dir.x) > 0.1:
		u.facing = signf(dir.x)


## Which way to walk to reach `to` (a point): straight at it, or in the ruins, where a wall or the
## refectory's long tables are in the way, along the map's path round them (re-planned twice a second).
func _toward(u: Unit, to: Vector2, dt: float) -> Vector2:
	if A.world == null or A.world.clear_line(u.pos, to, u.radius):
		u.flags.erase("route")
		return to - u.pos
	u.flags["route_t"] = float(u.flags.get("route_t", 0.0)) - dt
	if not u.flags.has("route") or u.flags["route_t"] <= 0.0:
		u.flags["route"] = Array(A.world.path(u.pos, to, u.radius))
		u.flags["route_t"] = 0.5
	var route: Array = u.flags["route"]
	while route.size() > 1 and u.pos.distance_to(route[0]) < 8.0:
		route.pop_front()
	return (route[0] - u.pos) if not route.is_empty() else to - u.pos


func _hollow(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["hollow"]
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 3.0 and u.cooldown("attack") <= 0.0 and may_attack(u):
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
				A.add_zone({"kind": "slash", "owner": u.id, "pos": u.pos, "dir": to.normalized(),
					"reach": float(e["reach"]) + 2.0, "arc": 1.9, "delay": float(e["windup"]), "dmg": float(e["damage"])})
			else:
				_step(u, _toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"])


## An ember: a Hollow's rush, faster, and its swing ends in a short lunge.
func _ember(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["ember"]
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			if to.length() < float(e["reach"]) + 6.0 and u.cooldown("attack") <= 0.0 and may_attack(u):
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.aim = to.normalized()
				u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
				A.add_zone({"kind": "slash", "owner": u.id, "pos": u.pos, "dir": u.aim,
					"reach": float(e["reach"]) + 4.0, "arc": 1.6, "delay": float(e["windup"]), "dmg": float(e["damage"])})
			else:
				_step(u, _toward(u, A.player.pos, dt), dt)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.vel = u.aim * float(e["lunge"])
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.85, 1.15)


## The Kiln Warden (design/ruins/content.md §4). Phase 1: fire rings out from the grate, each
## with a gap to step through, and embers from the two side cracks; a cracked pipe drips on the
## grate and it flinches (the tell). Flooded (the sluice was turned): no rings in phase 1 and
## double damage for a while. Phase 2 (below 60%): vents breathe fire cones in turn, clockwise.
func _warden(u: Unit, dt: float) -> void:
	var e: Dictionary = A.D["enemies"]["warden"]
	if not u.flags.has("ring_t"):
		u.flags["ring_t"] = 1.2
		u.flags["ember_t"] = 2.5
		u.flags["drip_t"] = float(e["phase1"]["drip_every"]) * 0.5
		u.flags["vent_t"] = 1.0
		u.flags["vent_i"] = 0
		if not u.flags.has("phase"):
			u.flags["phase"] = 1
		if u.flags.get("flooded", false):
			u.flags["vuln_t"] = float(e["flooded"]["vuln_s"])
			u.flags["vuln_mult"] = float(e["flooded"]["vuln_mult"])
			A.fx("dust", u.pos, {"r": 26.0, "life": 1.2})
	if float(u.flags.get("vuln_t", 0.0)) > 0.0:
		u.flags["vuln_t"] -= dt
	if int(u.flags["phase"]) == 1 and u.hp < u.max_hp * float(e["phase2_at"]):
		u.flags["phase"] = 2
		u.flags["vent_t"] = 1.2
		A.fx("ring", u.pos, {"color": PixelArt.FIRE, "r": 40.0, "life": 0.6})
	var two: bool = int(u.flags["phase"]) == 2
	var p: Dictionary = e["phase2"] if two else e["phase1"]
	var p1: Dictionary = e["phase1"]
	if float(u.flags.get("flinch_t", 0.0)) > 0.0:
		u.flags["flinch_t"] -= dt
		return
	# The tell: in phase 1 a cracked pipe drips onto the grate and it flinches.
	if not two:
		u.flags["drip_t"] -= dt
		if u.flags["drip_t"] <= 0.0:
			u.flags["drip_t"] = float(p1["drip_every"])
			u.flags["flinch_t"] = float(p1["drip_flinch"])
			u.flash = 0.12
			A.fx("dust", u.pos + Vector2(0, -4), {"r": 10.0, "life": 0.6})
			A.stats["warden_flinch"] = int(A.stats.get("warden_flinch", 0)) + 1
	# Rings: not while the grate is quenched in phase 1; slower ones in phase 2.
	u.flags["ring_t"] -= dt
	if u.flags["ring_t"] <= 0.0:
		u.flags["ring_t"] = float(p.get("ring_every", p1["ring_every"]))
		if two or not u.flags.get("flooded", false):
			A.add_zone({"kind": "ring", "owner": u.id, "pos": u.pos, "wait": float(p1["ring_windup"]), "r0": u.radius,
				"r": u.radius, "speed": float(p1["ring_speed"]), "w": float(p1["ring_width"]), "max": float(p1["ring_max"]),
				"gap_a": A.rng.randf() * TAU, "gap": float(p1["ring_gap"]), "dmg": float(p1["ring_damage"])})
	# Embers out of the side cracks, a few at a time.
	u.flags["ember_t"] -= dt
	if u.flags["ember_t"] <= 0.0:
		u.flags["ember_t"] = float(p.get("ember_every", p1["ember_every"]))
		var alive := 0
		for o in A.enemies():
			if o.kind == "ember":
				alive += 1
		if alive < 5:
			var cracks: Array = p1["cracks"]
			var k := int(u.flags.get("crack_i", 0))
			u.flags["crack_i"] = k + 1
			A.crack_spawn(str(cracks[k % cracks.size()]), int(p1["ember_n"]))
	# Vents, clockwise, the one about to fire glowing first (its telegraph).
	if two:
		u.flags["vent_t"] -= dt
		if u.flags["vent_t"] <= 0.0:
			u.flags["vent_t"] = float(p["vent_every"])
			var vents: Array = p["vents"]
			var i := int(u.flags["vent_i"])
			u.flags["vent_i"] = i + 1
			var dir := Vector2.from_angle(deg_to_rad(float(vents[i % vents.size()])))
			A.add_zone({"kind": "cone", "owner": u.id, "pos": u.pos + dir * u.radius, "dir": dir,
				"reach": float(p["vent_reach"]), "arc": float(p["vent_arc"]), "delay": float(p["vent_windup"]),
				"dmg": float(p["vent_damage"])})


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
			if d < float(e["range"]) and u.cooldown("attack") <= 0.0 and may_attack(u):
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


## The Backward Slinger: faces you, but walks and throws backwards, and its stones fly the wrong way. The telegraph
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
			u.facing = signf(to.x) if absf(to.x) > 0.1 else u.facing
			if d < float(e["range"]) and u.cooldown("attack") <= 0.0 and may_attack(u):
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
				# In a duel he stands admiring his lance for a moment: the opening to punish.
				_rival_recover(u, float(A.encounter.get("lance_recover", 0.5)))


func _rival_choose(u: Unit, to: Vector2) -> void:
	var e: Dictionary = A.D["enemies"]["rival"]
	var d = to.length()
	var roll = A.rng.randf()
	if u.cooldown("storm") <= 0.0 and roll < 0.3 and not (A.encounter.get("tell", false) and not u.flags.has("opened")):
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
	# His tell: in a duel he always opens with Arc Lance from across the yard.
	var opening: bool = A.encounter.get("tell", false) and not u.flags.has("opened")
	u.flags["opened"] = true
	if opening or (d < 165.0 and roll < 0.6 and u.cooldown("lance") <= 0.0):
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
