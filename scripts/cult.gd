extends RefCounted
## The cult's first cell (enemy spec §8.11; build item N-6.7): the Acolyte and the Saboteur. They
## turn the room against you. The first Acolyte in a fight runs to raise the alarm; catch it, or
## more come. The rest throw a quick shadow bolt. The Saboteur flings oil where you stand and lights
## it: the circle shows first, and water on it before the fuse burns down puts it out.

var A  # the arena
var AI  # scripts/ai.gd


func _init(arena, ai) -> void:
	A = arena
	AI = ai


func mind(u: Unit, dt: float) -> bool:
	match u.kind:
		"acolyte":
			_acolyte(u, dt)
		"saboteur":
			_saboteur(u, dt)
		_:
			return false
	return true


func _rec(u: Unit) -> Dictionary:
	return A.D["enemies"][u.kind]


func _acolyte(u: Unit, dt: float) -> void:
	var e := _rec(u)
	if not A.stats.has("runner_id") and not u.flags.has("caller"):
		A.stats["runner_id"] = u.id  # the first one runs for help
		u.flags["runner"] = float(e["alarm"]["run_s"])
	if u.flags.has("runner"):
		_run(u, dt)
		return
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			AI.brig._keep_off(u, to, dt, 0.3)
			if to.length() < float(e["range"]) and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				u.state = "windup"
				u.state_t = float(e["windup"])
				var start := u.pos + Vector2(0, -6)
				A.add_zone({"kind": "line", "owner": u.id, "a": start, "b": start + to.normalized() * float(e["range"]),
					"delay": float(e["windup"])})
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = float(e["cooldown"]) * A.rng.randf_range(0.85, 1.15)


## The runner heads away from you; if it's still on its feet when its time is up, it's out of
## sight and the alarm is raised.
func _run(u: Unit, dt: float) -> void:
	u.flags["runner"] = float(u.flags["runner"]) - dt
	AI._step(u, u.pos - A.player.pos, dt, 1.25)
	if not A.stats.has("runner_seen"):
		A.stats["runner_seen"] = true
		A.toast.emit("An Acolyte runs for help. Catch it!", PixelArt.DANGER)
	if u.flags["runner"] > 0.0:
		return
	u.flags.erase("runner")
	var alarm: Dictionary = _rec(u)["alarm"]
	A.fx("ring", u.pos, {"color": PixelArt.DANGER, "r": 24.0, "life": 0.6})
	A.stats["alarms"] = int(A.stats.get("alarms", 0)) + 1
	A.toast.emit("The alarm is raised. More are coming.", PixelArt.DANGER)
	for k in int(alarm["n"]):
		var o: Unit = A.spawn(str(alarm["kind"]), A.clamp_in(u.pos + Vector2.from_angle(k * 2.1) * 14.0, 6.0))
		o.flags["caller"] = true  # they came to the call: none of them runs again
	# the runner itself is gone from the field, not beaten
	A.morale.on_out(u)
	u.team = 2
	u.dead = true
	u.death_t = 0.0


## Killed while running: the alarm never went up.
func on_killed(u: Unit) -> void:
	if u.kind == "acolyte" and u.flags.has("runner") and A.phase != "won":
		A.guide.found(u, "caught_runner")
		A.stats["runners_caught"] = int(A.stats.get("runners_caught", 0)) + 1


func _saboteur(u: Unit, dt: float) -> void:
	var e := _rec(u)
	var to: Vector2 = A.player.pos - u.pos
	match u.state:
		"move":
			AI.brig._keep_off(u, to, dt, 0.35)
			var oil: Dictionary = e["oil"]
			if to.length() < float(oil["range"]) and u.cooldown("oil") <= 0.0 and AI.may_attack(u):
				u.state = "windup"
				u.state_t = float(e["windup"])
				u.cd["oil"] = float(oil["cooldown"])
				# oil splashed where you stand: the circle shows how long until it's lit
				A.add_zone({"kind": "fuse", "owner": -1, "by": u.id, "pos": A.clamp_in(A.player.pos, 2.0), "r": float(oil["r"]),
					"delay": float(oil["fuse_s"])})
			elif to.length() < float(e["reach"]) + 3.0 and u.cooldown("attack") <= 0.0 and AI.may_attack(u):
				AI.brig._swing(u, to)
		"windup":
			u.state_t -= dt
			if u.state_t <= 0.0:
				u.state = "move"
				u.cd["attack"] = maxf(u.cooldown("attack"), float(e["cooldown"]))


## The fuse burns down: the oil goes up, burning whoever stands in it and the ground under it.
func light(z: Dictionary) -> void:
	var oil: Dictionary = A.D["enemies"]["saboteur"]["oil"]
	A.fx("burst", z["pos"], {"color": PixelArt.FIRE, "r": float(z["r"]), "life": 0.4})
	Sfx.play("cast_fire", -4.0)
	A.stats["oil_lit"] = int(A.stats.get("oil_lit", 0)) + 1
	var to: Vector2 = A.player.pos - z["pos"]
	if to.length() < float(z["r"]) + A.player.radius:
		A.hit(A.player, float(oil["damage"]), 1, to.normalized(), 30.0)
	if A.town != null:
		A.town.burn_ground(z["pos"], float(z["r"]) * 0.6, 1)
	A.add_zone({"kind": "blaze", "pos": z["pos"], "r": float(z["r"]) * 0.7, "life": float(oil["burn_s"]), "dmg": float(oil["burn_dps"]) * 0.5})


## Water landed: any oil within reach of it is washed out before it's lit.
func wet(at: Vector2, r: float) -> void:
	for z in A.zones.duplicate():
		if z["kind"] == "fuse" and at.distance_to(z["pos"]) < r + float(z["r"]):
			A.zones.erase(z)
			A.fx("dust", z["pos"], {"color": PixelArt.WATER, "r": float(z["r"]), "life": 0.5})
			A.stats["defused"] = int(A.stats.get("defused", 0)) + 1
			var by: Unit = A.unit_by_id(int(z.get("by", -1)))
			if by != null:
				A.guide.found(by, "defused")
