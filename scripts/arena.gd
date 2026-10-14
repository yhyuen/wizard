extends Node2D
## The Mill yard: the prototype's one fight. Two waves of Hollows, then a duel with Silas Vane,
## who calls more Hollows at half HP. An Orrery shrine stands in the yard (change elements and
## re-pick mutations while it is quiet), and a tome may lie by the fence. This node simulates and
## draws every unit, projectile, telegraph, field object and effect; the wizard's spells live in
## kit.gd and scripts/spells/, enemy minds in ai.gd.

signal fight_over(won: bool)
signal toast(text: String, color: Color)
signal banner(text: String)

const W := 480
const H := 270
const BOUNDS := Rect2(16, 30, 448, 222)
const GATES := [Vector2(20, 140), Vector2(460, 140), Vector2(240, 34), Vector2(240, 248)]
const REACTIONS := ["none", "flinch", "stagger", "knockdown", "launch"]
const Kit := preload("res://scripts/kit.gd")
const Ai := preload("res://scripts/ai.gd")

var D: Dictionary  # data/spells.json
var kit
var ai
var rng := RandomNumberGenerator.new()

var player: Unit
var units: Array = []
var projs: Array = []
var zones: Array = []
var stones: Array = []
var fxs: Array = []
var ignite_queue: Array = []
var next_id := 1

var intent := {}
var mouse := Vector2(W / 2.0, H / 2.0)
var hover: Unit = null
var paused := false
var hitstop := 0.0
var shake := 0.0
var orbit_ang := 0.0

var phase := "intro"
var phase_t := 0.0
var spawn_queue: Array = []
var summoned := false
var over_t := -1.0
var clear_t := 0.0  # seconds the yard has been quiet between waves
var fight_time := 0.0
var stats := {"casts": 0, "damage_taken": 0.0, "kills": 0, "by_spell": {}}

var _tex := {}


func _ready() -> void:
	D = Progression.data
	rng.seed = 7
	_tex["ground"] = PixelArt.ground(W, H, BOUNDS)
	_tex["wizard"] = PixelArt.frames("wizard", PixelArt.WIZARD, PixelArt.WIZARD_STEP)
	_tex["hollow"] = PixelArt.frames("hollow", PixelArt.HOLLOW, PixelArt.HOLLOW_STEP)
	_tex["slinger"] = PixelArt.frames("slinger", PixelArt.HOLLOW, PixelArt.HOLLOW_STEP, {"h": "G", "H": "v", "r": "y"})
	_tex["rival"] = PixelArt.frames("rival", PixelArt.RIVAL, PixelArt.RIVAL_STEP)
	_tex["wizard_flash"] = PixelArt.flash("wizard", PixelArt.WIZARD)
	_tex["hollow_flash"] = PixelArt.flash("hollow", PixelArt.HOLLOW)
	_tex["slinger_flash"] = _tex["hollow_flash"]
	_tex["rival_flash"] = PixelArt.flash("rival", PixelArt.RIVAL)
	_tex["stone"] = PixelArt.tex("stone", PixelArt.LODESTONE)
	_tex["ember"] = [PixelArt.tex("ember", PixelArt.EMBER), PixelArt.tex("ember_b", PixelArt.EMBER_B)]
	kit = Kit.new(self)
	ai = Ai.new(self)
	start()


func start() -> void:
	units.clear()
	projs.clear()
	zones.clear()
	stones.clear()
	fxs.clear()
	ignite_queue.clear()
	spawn_queue.clear()
	summoned = false
	over_t = -1.0
	clear_t = 0.0
	fight_time = 0.0
	stats = {"casts": 0, "damage_taken": 0.0, "kills": 0, "by_spell": {}}
	player = Unit.new()
	player.kind = "wizard"
	player.team = 0
	player.pos = Vector2(240, 142)
	player.radius = float(D["wizard"]["radius"])
	player.speed = float(D["wizard"]["speed"])
	player.max_hp = Progression.max_hp()
	player.hp = player.max_hp
	player.hp_lag = player.hp
	_add(player)
	kit.reset()
	_place_tome()
	set_phase("intro")


func _add(u: Unit) -> Unit:
	u.id = next_id
	next_id += 1
	units.append(u)
	return u


func spawn(kind: String, at: Vector2) -> Unit:
	var e: Dictionary = D["enemies"][kind]
	var u := Unit.new()
	u.kind = kind
	u.team = 1
	u.pos = at
	u.radius = float(e["radius"])
	u.max_hp = float(e["hp"])
	u.hp = u.max_hp
	u.hp_lag = u.hp
	u.poise = int(e["poise"])
	u.speed = float(e["speed"]) * rng.randf_range(0.9, 1.1)
	u.state = "enter"
	u.state_t = 0.5
	_add(u)
	fx("dust", at, {"r": 8.0, "life": 0.5})
	return u


func enemies() -> Array:
	return units.filter(func(u): return u.team == 1 and not u.dead)


func rival() -> Unit:
	for u in units:
		if u.kind == "rival" and not u.dead:
			return u
	return null


func unit_by_id(uid: int) -> Unit:
	for u in units:
		if u.id == uid:
			return u
	return null


# --- fight flow -------------------------------------------------------------

func set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	match p:
		"intro":
			banner.emit("Loop %d  ·  Day 3  ·  Ambush at the Mill" % Progression.loop())
			toast.emit("G at the Orrery: change elements or re-pick mutations", PixelArt.GOLD)
		"wave1":
			banner.emit("Dust Hollows climb the fence")
			for i in 6:
				spawn_queue.append({"t": 0.4 + i * 0.5, "kind": "hollow", "gate": i % 4})
		"wave2":
			banner.emit("More of them, and Slingers")
			for i in 8:
				spawn_queue.append({"t": 0.3 + i * 0.35, "kind": "hollow", "gate": (i + 1) % 4})
			spawn_queue.append({"t": 1.5, "kind": "slinger", "gate": 2})
			spawn_queue.append({"t": 2.2, "kind": "slinger", "gate": 3})
		"duel":
			banner.emit("Silas Vane, the Storm Rider, steps through the gate")
			spawn_queue.append({"t": 0.8, "kind": "rival", "gate": 1})


func _flow(dt: float) -> void:
	phase_t += dt
	if phase in ["wave1", "wave2", "duel"]:
		fight_time += dt
	for s in spawn_queue.duplicate():
		s["t"] -= dt
		if s["t"] <= 0.0:
			spawn_queue.erase(s)
			var g: Vector2 = GATES[int(s["gate"]) % GATES.size()]
			spawn(s["kind"], g + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
	var cleared := spawn_queue.is_empty() and enemies().is_empty()
	if cleared and phase in ["wave1", "wave2"] and phase_t > 1.0:
		if clear_t == 0.0:
			toast.emit("The yard is quiet. The Orrery hums (G).", PixelArt.GOLD)
		clear_t += dt
	else:
		clear_t = 0.0
	match phase:
		"intro":
			if phase_t > 3.0:
				set_phase("wave1")
		"wave1":
			if clear_t > 2.5:
				set_phase("wave2")
		"wave2":
			if clear_t > 2.5:
				set_phase("duel")
		"duel":
			var r := rival()
			if r and not summoned and r.hp <= r.max_hp * float(D["enemies"]["rival"]["summon_at"]):
				summoned = true
				banner.emit("Silas calls the Hollows!")
				for i in int(D["enemies"]["rival"]["summon_count"]):
					spawn_queue.append({"t": 0.2 + i * 0.3, "kind": "hollow", "gate": i})
	if over_t >= 0.0:
		over_t -= dt
		if over_t < 0.0:
			fight_over.emit(phase == "won")
			over_t = -2.0  # emitted


func _end(won: bool) -> void:
	if phase in ["won", "lost"]:
		return
	phase = "won" if won else "lost"
	over_t = 1.6
	if won:
		banner.emit("The Hollows crumble with their master")
		for u in enemies():
			kill(u)
	else:
		banner.emit("You fall in the dust of the Mill")


# --- the main loop ----------------------------------------------------------

func _physics_process(dt: float) -> void:
	if paused:
		return
	_update_fx(dt)
	shake = maxf(0.0, shake - dt * 18.0)
	position = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake if shake > 0.3 else Vector2.ZERO
	if hitstop > 0.0:
		hitstop -= dt
		return
	_flow(dt)
	orbit_ang += dt * 3.0
	if not player.dead:
		kit.update(dt, intent)
	for u in units:
		_update_unit(u, dt)
		if u.team == 1 and not u.dead:
			ai.update(u, dt)
	_separate()
	_update_projs(dt)
	_update_zones(dt)
	_update_stones(dt)
	var guard := 0
	while not ignite_queue.is_empty() and guard < 32:
		ignite(ignite_queue.pop_front())
		guard += 1
	units = units.filter(func(u): return not (u.dead and u.death_t <= 0.0 and u != player))
	hover = null
	var best := 14.0
	for u in enemies():
		var d: float = u.pos.distance_to(mouse)
		if d < best:
			best = d
			hover = u


func _process(_dt: float) -> void:
	queue_redraw()


func _update_unit(u: Unit, dt: float) -> void:
	u.anim += dt
	u.flash = maxf(0.0, u.flash - dt)
	u.iframes = maxf(0.0, u.iframes - dt)
	u.wall_check = maxf(0.0, u.wall_check - dt)
	u.hp_lag = move_toward(u.hp_lag, u.hp, dt * u.max_hp * 0.8)
	u.tick_cooldowns(dt)
	if u.dead:
		u.death_t -= dt
		return
	if u.reaction_t > 0.0:
		u.reaction_t -= dt
		if u.reaction_t <= 0.0:
			u.reaction = ""
	u.stun = maxf(0.0, u.stun - dt)
	u.slow_t = maxf(0.0, u.slow_t - dt)
	u.wet_t = maxf(0.0, u.wet_t - dt)
	if u.pips > 0:
		u.pip_timer -= dt
		if u.pip_timer <= 0.0:
			u.pips = 0
	u.pos += u.vel * dt
	u.vel = u.vel.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * dt))
	var before := u.pos
	u.pos = clamp_in(u.pos, u.radius)
	if before != u.pos:
		if u.wall_check > 0.0 and u.vel.length() > 25.0:
			u.stun = 1.0
			u.wall_check = 0.0
			fx("ring", u.pos, {"color": PixelArt.EARTH, "r": 10.0, "life": 0.3})
			toast.emit("Pinned!", PixelArt.EARTH)
		u.vel = Vector2.ZERO
	# Field objects under the unit.
	for z in zones:
		if z["kind"] == "ember" and u.team == 1 and u.pos.distance_to(z["pos"]) < 5.0 + u.radius:
			z["tick"] = float(z.get("tick", 0.0))
			if u.cooldown("ember_tick") <= 0.0:
				u.cd["ember_tick"] = 0.5
				hit(u, float(D["field"]["ember_dps"]) * 0.5, -1, Vector2.ZERO, 0.0, true)
		elif z["kind"] == "gravel" and u.team == 1 and u.pos.distance_to(z["pos"]) < float(z["r"]):
			u.slow_t = 0.2
		elif z["kind"] == "tome" and u == player and u.pos.distance_to(z["pos"]) < 9.0:
			_read_tome(z)


func move_speed(u: Unit) -> float:
	var s := u.speed
	if u.slow_t > 0.0:
		s *= 1.0 - float(D["field"]["gravel_slow"])
	return s


func clamp_in(p: Vector2, r := 0.0) -> Vector2:
	return Vector2(clampf(p.x, BOUNDS.position.x + r, BOUNDS.end.x - r), clampf(p.y, BOUNDS.position.y + r, BOUNDS.end.y - r))


func _separate() -> void:
	var live := units.filter(func(u): return not u.dead)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: Unit = live[i]
			var b: Unit = live[j]
			var d := b.pos - a.pos
			var min_d := a.radius + b.radius
			var l := d.length()
			if l < min_d and l > 0.01:
				var push := d / l * (min_d - l) * 0.5
				if a != player:
					a.pos -= push
				if b != player:
					b.pos += push


# --- hits, pips and reactions -----------------------------------------------

## Deals damage. Impact against Poise picks the reaction (design doc §4.5); impact −1 is a quiet
## tick (embers). Hit-stop and shake follow the share of the target's HP removed (§4.7).
func hit(u: Unit, dmg: float, impact: int, dir: Vector2, knock := 0.0, quiet := false) -> bool:
	if u.dead or u.iframes > 0.0:
		return false
	u.hp -= dmg
	u.flash = 0.08
	if u == player:
		stats["damage_taken"] += dmg
		u.iframes = float(D["wizard"]["iframes"])
	if not quiet:
		var pct := dmg / u.max_hp
		hitstop = maxf(hitstop, clampf(pct * 0.35, 0.0, 0.08))
		shake = maxf(shake, clampf(pct * 16.0, 0.0, 4.0))
		var tier := clampi(impact - u.poise, 0, 4)
		if tier >= 1:
			var name: String = REACTIONS[tier]
			var length := float(D["reaction_time"][name])
			if u == player:
				length = minf(length, 0.4)
			if length >= u.reaction_t:
				u.reaction = name
				u.reaction_t = length
				u.reaction_len = length
			if tier >= 2 and u.team == 1:
				ai.interrupt(u)
			u.vel += dir * knock
		else:
			fx("clink", u.pos + Vector2(0, -8), {"life": 0.25})
			u.vel += dir * knock * 0.3
	if u.hp <= 0.0:
		kill(u)
	return true


func kill(u: Unit) -> void:
	if u.dead:
		return
	u.dead = true
	u.hp = 0.0
	u.death_t = 0.6
	u.pips = 0
	cancel_zones(u.id)
	if u == player:
		_end(false)
		return
	stats["kills"] += 1
	fx("burst", u.pos, {"color": PixelArt.PAPER, "r": 9.0, "life": 0.35})
	Progression.add_wizard_xp(float(D["enemies"][u.kind]["xp"]))
	if u.kind == "rival":
		_end(true)


func add_pips(u: Unit, n: int) -> void:
	if u.dead or u.team != 1:
		return
	u.pips += n
	var life := float(D["field"]["pip_life"])
	if Progression.has_mut("ember_bolt", "long_pips"):
		life *= 2.0
	u.pip_timer = life
	if u.pips >= ignite_threshold() and not ignite_queue.has(u):
		ignite_queue.append(u)


func ignite_threshold() -> int:
	return 4 if Progression.has_mut("ember_bolt", "double_ignite") else 3


## Ignite: a burst of fire damage that clears the pips. Its count is the horde-mastery signal.
func ignite(u: Unit) -> void:
	if u.dead:
		return
	var mult := 2.0 if Progression.has_mut("ember_bolt", "double_ignite") else 1.0
	u.pips = 0
	var dmg := Progression.stat("ember_bolt", "damage") * float(D["field"]["ignite_mult"]) * mult
	fx("burst", u.pos + Vector2(0, -4), {"color": PixelArt.FIRE, "r": float(D["field"]["ignite_radius"]), "life": 0.35})
	fx("burst", u.pos + Vector2(0, -4), {"color": PixelArt.FIRE_HOT, "r": 6.0, "life": 0.2})
	hit(u, dmg, 2, Vector2.UP, 0.0)
	Progression.add_xp("ember_bolt", float(Progression.spell("ember_bolt")["xp_ignite"]))
	if Progression.has_mut("ember_bolt", "ember_ignite"):
		add_ember(u.pos)
	if Progression.has_mut("ember_bolt", "ignite_heal") and not player.dead:
		player.hp = minf(player.max_hp, player.hp + 3.0)
	if Progression.has_mut("ember_bolt", "spread_ignite"):
		for e in enemies():
			if e != u and e.pos.distance_to(u.pos) < 40.0:
				fx("spark_line", u.pos, {"to": e.pos, "color": PixelArt.FIRE, "life": 0.2})
				add_pips(e, 1)


func add_ember(at: Vector2) -> void:
	var embers := zones.filter(func(z): return z["kind"] == "ember")
	if embers.size() >= int(D["field"]["ember_cap"]):
		zones.erase(embers[0])
	zones.append({"kind": "ember", "pos": at, "t": 0.0, "life": float(D["field"]["ember_life"]), "owner": 0})
	for s in stones:
		if s["pos"].distance_to(at) < 8.0:
			discover("meteor")


## Magicks are discovered by making their two elements meet in a fight (design doc §5).
func discover(magick: String) -> void:
	if Progression.knows(magick):
		return
	Progression.learn(magick)
	fx("ring", player.pos, {"color": PixelArt.GOLD, "r": 30.0, "life": 0.8})


func unknown_magick_toast(magick: String) -> void:
	var m: Dictionary = D["magicks"][magick]
	if Progression.has_hint(magick):
		toast.emit("%s is still unknown. The tome said: %s" % [m["name"], m["hint"]], PixelArt.GOLD)
	else:
		var pair: Array = m["pair"]
		toast.emit("Unknown Magick. Make %s and %s meet in a fight, or find a tome." % [D["elements"][pair[0]]["name"], D["elements"][pair[1]]["name"]], PixelArt.GOLD)


# --- the Orrery shrine and tomes --------------------------------------------

func shrine_pos() -> Vector2:
	var p: Array = D["shrine"]["pos"]
	return Vector2(p[0], p[1])


## The shrine works while the yard is quiet: before the first wave and between waves.
func shrine_ready() -> bool:
	return phase in ["intro", "wave1", "wave2"] and spawn_queue.is_empty() and enemies().is_empty() \
		and not player.dead and player.pos.distance_to(shrine_pos()) <= float(D["shrine"]["reach"])


func _place_tome() -> void:
	var subject := Progression.tome_subject()
	if subject == "":
		return
	var spots: Array = D["shrine"]["tome_spots"]
	var sp: Array = spots[(Progression.loop() - 1) % spots.size()]
	add_zone({"kind": "tome", "pos": Vector2(sp[0], sp[1]), "subject": subject})


func _read_tome(z: Dictionary) -> void:
	zones.erase(z)
	Progression.read_tome(z["subject"])
	fx("ring", z["pos"], {"color": PixelArt.GOLD, "r": 16.0, "life": 0.5})


# --- projectiles ------------------------------------------------------------

func spawn_proj(p: Dictionary) -> void:
	p["hit"] = []
	p["t"] = 0.0
	projs.append(p)


func _update_projs(dt: float) -> void:
	for p in projs.duplicate():
		p["t"] += dt
		p["pos"] += p["vel"] * dt
		p["life"] -= dt
		if p["life"] <= 0.0:
			projs.erase(p)
			continue
		if p.get("ghost", false):
			continue
		if p.has("home"):
			var t := unit_by_id(p["home"])
			if t and not t.dead:
				p["vel"] = (t.pos + Vector2(0, -4) - p["pos"]).normalized() * p["vel"].length()
		if not BOUNDS.grow(2).has_point(p["pos"]):
			if int(p.get("wall_bounces", 0)) > 0:
				p["wall_bounces"] -= 1
				if p["pos"].x < BOUNDS.position.x or p["pos"].x > BOUNDS.end.x:
					p["vel"].x *= -1.0
				else:
					p["vel"].y *= -1.0
				p["pos"] = clamp_in(p["pos"])
				fx("dust", p["pos"], {"r": 4.0, "life": 0.2})
			else:
				fx("dust", p["pos"], {"r": 3.0, "life": 0.2})
				projs.erase(p)
				continue
		if p["team"] == 1:
			_enemy_proj(p)
			continue
		for u in enemies():
			if u.id in p["hit"] or u.id == p.get("last", -1):
				continue
			if u.pos.distance_to(p["pos"]) < u.radius + float(p["r"]) and u.lift() < 6.0:
				p["hit"].append(u.id)
				if not kit.on_proj_hit(p, u):
					projs.erase(p)
				break


func _enemy_proj(p: Dictionary) -> void:
	for s in stones:
		if s["state"] == "orbit" and s["pos"].distance_to(p["pos"]) < 4.0 + float(p["r"]):
			stones.erase(s)
			projs.erase(p)
			fx("burst", s["pos"], {"color": PixelArt.EARTH, "r": 6.0, "life": 0.25})
			return
	if not player.dead and player.pos.distance_to(p["pos"]) < player.radius + float(p["r"]):
		if hit(player, float(p["dmg"]), int(p.get("impact", 1)), p["vel"].normalized(), 20.0):
			fx("burst", p["pos"], {"color": p["color"], "r": 5.0, "life": 0.2})
		projs.erase(p)


# --- telegraphs and field objects -------------------------------------------

func add_zone(z: Dictionary) -> Dictionary:
	z["t"] = 0.0
	if not z.has("owner"):
		z["owner"] = 0
	zones.append(z)
	return z


func cancel_zones(owner_id: int) -> void:
	zones = zones.filter(func(z): return z["owner"] != owner_id or z["kind"] in ["ember", "gravel"])


func _update_zones(dt: float) -> void:
	for z in zones.duplicate():
		z["t"] += dt
		match z["kind"]:
			"ember", "gravel", "column", "rod", "puddle":
				if z["t"] >= z["life"]:
					zones.erase(z)
			"slash":
				var o := unit_by_id(z["owner"])
				if o:
					z["pos"] = o.pos
			_:
				pass
		if z.has("delay") and z["t"] >= z["delay"] and not z.get("done", false):
			z["done"] = true
			zones.erase(z)
			_detonate(z)
		elif z.has("pull") and z["t"] < z["delay"]:
			for u in enemies():
				var d: Vector2 = z["pos"] - u.pos
				if d.length() < z["r"] * 1.8 and d.length() > 2.0:
					u.pos += d.normalized() * 50.0 * dt


func _detonate(z: Dictionary) -> void:
	if z["owner"] == 0 and kit.detonate(z):
		return
	match z["kind"]:
		"storm":
			fx("bolt", z["pos"], {"color": PixelArt.STORM, "life": 0.25})
			fx("burst", z["pos"], {"color": PixelArt.STORM, "r": z["r"], "life": 0.25})
			if player.pos.distance_to(z["pos"]) < z["r"] + player.radius:
				hit(player, z["dmg"], 1, (player.pos - z["pos"]).normalized(), 30.0)
		"lance":
			fx("beam", z["a"], {"to": z["b"], "color": PixelArt.STORM, "w": z["w"], "life": 0.25})
			var closest := Geometry2D.get_closest_point_to_segment(player.pos, z["a"], z["b"])
			if player.pos.distance_to(closest) < z["w"] * 0.5 + player.radius:
				hit(player, z["dmg"], int(z.get("impact", 2)), (z["b"] - z["a"]).normalized(), 40.0)
		"slash":
			var o := unit_by_id(z["owner"])
			if o == null or o.dead:
				return
			fx("swipe", o.pos, {"dir": z["dir"], "r": z["reach"], "life": 0.15})
			var to := player.pos - o.pos
			if to.length() < z["reach"] + player.radius and absf(to.angle_to(z["dir"])) < z["arc"] * 0.5:
				hit(player, z["dmg"], 1, to.normalized(), 40.0)
		"line":
			var o := unit_by_id(z["owner"])
			if z.get("visual", false) or o == null or o.dead:
				return
			var dir: Vector2 = (z["b"] - z["a"]).normalized()
			var e: Dictionary = D["enemies"]["slinger"]
			spawn_proj({"kind": "rock", "team": 1, "pos": z["a"], "vel": dir * float(e["shot_speed"]), "r": 2.0,
				"dmg": float(e["damage"]), "impact": 1, "life": 1.6, "color": PixelArt.DANGER})


# --- lodestones -------------------------------------------------------------

func stone_count() -> int:
	return stones.size()


func orbit_stones() -> Array:
	return stones.filter(func(s): return s["state"] == "orbit")


func add_stone(at: Vector2) -> bool:
	if stones.size() >= Progression.stone_cap():
		return false
	stones.append({"state": "return", "pos": at, "vel": Vector2.ZERO, "hit": [], "dist": 0.0})
	return true


func _orbit_slot(s: Dictionary) -> Vector2:
	var orb := orbit_stones()
	var n := maxi(1, orb.size())
	var i := maxi(0, orb.find(s))
	var a := orbit_ang + TAU * i / n
	return player.pos + Vector2(cos(a), sin(a) * 0.8) * 13.0 + Vector2(0, -4)


func _update_stones(dt: float) -> void:
	for s in stones.duplicate():
		match s["state"]:
			"orbit":
				s["pos"] = _orbit_slot(s)
			"return":
				var target := player.pos + Vector2(0, -4)
				s["pos"] = s["pos"].move_toward(target, 230.0 * dt)
				if s["pos"].distance_to(target) < 14.0:
					s["state"] = "orbit"
			"ground":
				if not player.dead and s["pos"].distance_to(player.pos) < 10.0:
					s["state"] = "return"
			"flung", "recall":
				var step: Vector2 = s["vel"] * dt
				if s["state"] == "recall":
					step = (player.pos - s["pos"]).normalized() * float(s["speed"]) * dt
				s["pos"] += step
				s["dist"] += step.length()
				kit.fe.stone_sweep(s)
				if s["state"] == "recall" and s["pos"].distance_to(player.pos) < 12.0:
					s["state"] = "orbit"
				elif s["state"] == "flung" and (s["dist"] >= s["range"] or not BOUNDS.has_point(s["pos"])):
					s["pos"] = clamp_in(s["pos"], 3.0)
					s["state"] = "return" if Progression.has_mut("fling", "return_orbit") else "ground"
					_ground_tip()
			"slam":
				s["delay"] -= dt
				if s["delay"] > 0.0:
					s["pos"] += Vector2(0, -20) * dt
					continue
				var t := unit_by_id(s["target"])
				if t == null or t.dead:
					s["state"] = "ground"
					s["pos"] = clamp_in(s["pos"], 3.0)
					_ground_tip()
					continue
				s["pos"] = s["pos"].move_toward(t.pos, 300.0 * dt)
				if s["pos"].distance_to(t.pos) < t.radius + 2.0:
					kit.fe.avalanche_hit(s, t)


static var _tipped := false


func _ground_tip() -> void:
	if not _tipped:
		_tipped = true
		toast.emit("Walk over a grounded lodestone to pull it back into orbit.", PixelArt.EARTH)


# --- effects ----------------------------------------------------------------

func fx(kind: String, at: Vector2, extra := {}) -> void:
	var f := {"kind": kind, "pos": at, "t": 0.0, "life": 0.3}
	f.merge(extra, true)
	fxs.append(f)


func _update_fx(dt: float) -> void:
	for f in fxs.duplicate():
		f["t"] += dt
		if f.has("vel"):
			f["pos"] += f["vel"] * dt
		if f["t"] >= f["life"]:
			fxs.erase(f)


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	draw_texture(_tex["ground"], Vector2.ZERO)
	_draw_shrine()
	for z in zones:
		_draw_zone(z)
	kit.draw_field(self)
	for s in stones:
		if s["state"] == "ground":
			_draw_stone(s)
	var live := units.duplicate()
	live.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for u in live:
		draw_ellipse_px(u.pos + Vector2(0, 1), u.radius + 1.0, 2.0, Color(0, 0, 0, 0.35))
	for u in live:
		_draw_unit(u)
	for s in stones:
		if s["state"] != "ground":
			_draw_stone(s)
	for p in projs:
		_draw_proj(p)
	for f in fxs:
		_draw_fx(f)
	kit.draw(self)
	_draw_reticle()


func _draw_unit(u: Unit) -> void:
	var frames: Array = _tex[u.kind]
	var tex: Texture2D = frames[1] if u.moving and int(u.anim * 6.0) % 2 == 1 else frames[0]
	if u.flash > 0.0:
		tex = _tex[u.kind + "_flash"]
	var size := tex.get_size()
	var lift := u.lift()
	var top_left := (u.pos - Vector2(size.x / 2.0, size.y - 1.0 + lift)).round()
	var mod := Color.WHITE
	if u.dead:
		mod = Color(1, 1, 1, clampf(u.death_t / 0.6, 0.0, 1.0))
		top_left.y += (1.0 - u.death_t / 0.6) * 4.0
	elif u == player and u.iframes > 0.0 and int(u.iframes * 20.0) % 2 == 0:
		mod = Color(1, 1, 1, 0.5)
	if u.reaction == "knockdown":
		# Knocked down: drawn lying on its side.
		draw_set_transform(u.pos, -PI / 2.0 * u.facing, Vector2.ONE)
		draw_texture(tex, Vector2(-size.x / 2.0, -size.y + 2.0), mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var rect := Rect2(top_left, size)
		if u.facing < 0:
			rect = Rect2(top_left + Vector2(size.x, 0), Vector2(-size.x, size.y))
		draw_texture_rect(tex, rect, false, mod)
	if u.dead:
		return
	var head := u.pos + Vector2(0, -size.y - 3.0 - lift)
	if u.reaction in ["stagger", "launch"] or u.stun > 0.0:
		var a := u.anim * 8.0
		for i in 3:
			var o := Vector2(cos(a + i * TAU / 3.0) * 5.0, sin(a + i * TAU / 3.0) * 1.5)
			draw_rect(Rect2((head + o).round(), Vector2.ONE), PixelArt.GOLD)
	if u.wet_t > 0.0:
		# Wet: a drip under the feet and a droplet by the head.
		draw_rect(Rect2((u.pos + Vector2(-3, 0)).round(), Vector2(6, 1)), Color(PixelArt.WATER, 0.7))
		draw_rect(Rect2((head + Vector2(5, 2)).round(), Vector2(2, 3)), PixelArt.WATER)
	if u.team == 1:
		_draw_pips(u, head + Vector2(0, -1))
		if u.kind != "rival":
			_draw_chunks(u, head + Vector2(0, 3))


## Flame pips over the head: filled pips and the empty slots left before Ignite.
func _draw_pips(u: Unit, at: Vector2) -> void:
	if u.pips <= 0:
		return
	var n := ignite_threshold()
	var x0 := at.x - (n * 3 - 1) / 2.0
	for i in n:
		var r := Rect2(Vector2(x0 + i * 3, at.y - 4).round(), Vector2(2, 2))
		if i < u.pips:
			draw_rect(r, PixelArt.FIRE_HOT if u.pip_timer > 1.0 or int(u.anim * 10) % 2 == 0 else PixelArt.FIRE)
		else:
			draw_rect(r, Color(PixelArt.FIRE, 0.35), false, 1.0)


## Enemy HP in chunks of 10 (design doc §4.4).
func _draw_chunks(u: Unit, at: Vector2) -> void:
	var chunks := int(ceil(u.max_hp / 10.0))
	var w := chunks * 3 - 1
	var x0 := roundf(at.x - w / 2.0)
	for i in chunks:
		var lo := i * 10.0
		var col := Color(0.15, 0.1, 0.12, 0.8)
		if u.hp > lo:
			col = PixelArt.DANGER if u.hp >= lo + 10.0 or u.hp >= u.max_hp else Color(PixelArt.DANGER, 0.55)
		elif u.hp_lag > lo:
			col = PixelArt.PAPER
		draw_rect(Rect2(x0 + i * 3, roundf(at.y), 2, 1), col)


func _draw_stone(s: Dictionary) -> void:
	var tex: Texture2D = _tex["stone"]
	var p: Vector2 = (s["pos"] - Vector2(3, 3)).round()
	if s["state"] == "ground":
		draw_texture(tex, p, Color(0.85, 0.85, 0.85))
	else:
		draw_texture(tex, p)


func _draw_proj(p: Dictionary) -> void:
	var pos: Vector2 = p["pos"].round()
	var col: Color = p["color"]
	var r := float(p["r"])
	if p.get("ghost", false):
		draw_arc(pos, r + 1.0, 0, TAU, 10, Color(PixelArt.PAPER, 0.6 * (1.0 - p["t"] / 1.2)), 1.0, false)
		return
	var tail: Vector2 = p["vel"].normalized() * -(r + 3.0)
	match p["kind"]:
		"pebble":
			draw_circle(pos, r, PixelArt.EARTH_DARK, true, -1.0, false)
			draw_circle(pos + Vector2(-0.5, -0.5), maxf(1.0, r - 1.0), PixelArt.EARTH, true, -1.0, false)
		"pyro":
			draw_line(pos, pos + tail * 2.0, Color(PixelArt.FIRE, 0.6), 2.0)
			draw_circle(pos, r + 1.0, PixelArt.FIRE, true, -1.0, false)
			draw_circle(pos, r - 1.0, PixelArt.FIRE_HOT, true, -1.0, false)
		_:
			draw_line(pos, pos + tail, Color(col, 0.55), 1.0)
			draw_circle(pos, r, col, true, -1.0, false)
			if p["kind"] == "ember":
				draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2.ONE), PixelArt.FIRE_HOT)


func _draw_zone(z: Dictionary) -> void:
	var t: float = z["t"]
	match z["kind"]:
		"ember":
			var frames: Array = _tex["ember"]
			var fade := clampf((z["life"] - t) / 1.0, 0.3, 1.0)
			draw_texture(frames[int(t * 6.0) % 2], (z["pos"] - Vector2(3, 5)).round(), Color(1, 1, 1, fade))
		"gravel":
			for i in 10:
				var a := i * 2.4
				var o := Vector2(cos(a), sin(a)) * fmod(i * 3.7, z["r"])
				draw_rect(Rect2((z["pos"] + o).round(), Vector2.ONE), PixelArt.EARTH_DARK)
		"pillar", "meteor":
			var col := PixelArt.FIRE
			var k := clampf(t / z["delay"], 0.0, 1.0)
			# The telegraph is the hitbox: the outer ring is the exact radius, the inner disc fills
			# toward it as the delay runs out. Hero effect: only the latest signature stays bright.
			var bright: bool = z.get("hero", false) or t < 0.3
			draw_arc(z["pos"], z["r"], 0, TAU, 32, col, 1.0, false)
			if z.has("ghost_r"):
				draw_dashed_circle(z["pos"], z["ghost_r"], Color(PixelArt.PAPER, 0.7))
			draw_circle(z["pos"], z["r"] * k, Color(col, 0.35 if bright else 0.12), true, -1.0, false)
			if z["kind"] == "meteor":
				var fall: Vector2 = z["pos"] + Vector2(-20, -60) * (1.0 - k)
				draw_circle(fall, 3.0, PixelArt.FIRE_HOT, true, -1.0, false)
				draw_texture(_tex["stone"], (fall - Vector2(3, 3)).round(), Color(1, 0.7, 0.4))
		"storm":
			var k := clampf(t / z["delay"], 0.0, 1.0)
			draw_arc(z["pos"], z["r"], 0, TAU, 32, PixelArt.STORM, 1.0, false)
			draw_circle(z["pos"], z["r"] * k, Color(PixelArt.STORM, 0.25), true, -1.0, false)
		"lance":
			var k := clampf(t / z["delay"], 0.0, 1.0)
			var dir: Vector2 = (z["b"] - z["a"]).normalized()
			var n: Vector2 = dir.orthogonal() * z["w"] * 0.5
			var pts := PackedVector2Array([z["a"] + n, z["b"] + n, z["b"] - n, z["a"] - n, z["a"] + n])
			draw_polyline(pts, PixelArt.STORM, 1.0)
			var mid: Vector2 = z["a"].lerp(z["b"], k)
			draw_colored_polygon(PackedVector2Array([z["a"] + n, mid + n, mid - n, z["a"] - n]), Color(PixelArt.STORM, 0.25))
		"slash":
			var dir: Vector2 = z["dir"]
			var k := clampf(t / z["delay"], 0.0, 1.0)
			var a0: float = dir.angle() - z["arc"] * 0.5
			var pts := PackedVector2Array([z["pos"]])
			for i in 9:
				var a: float = a0 + z["arc"] * i / 8.0
				pts.append(z["pos"] + Vector2(cos(a), sin(a)) * z["reach"])
			draw_colored_polygon(pts, Color(PixelArt.DANGER, 0.12 + 0.25 * k))
			pts.append(z["pos"])
			draw_polyline(pts, Color(PixelArt.DANGER, 0.8), 1.0)
		"line":
			var k := clampf(t / z["delay"], 0.0, 1.0)
			draw_line(z["a"], z["b"], Color(PixelArt.DANGER, 0.3 + 0.5 * k), 1.0)
		"tome":
			var p: Vector2 = z["pos"].round() + Vector2(0, -2 + roundf(sin(t * 3.0)))
			draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 6)), PixelArt.INK)
			draw_rect(Rect2(p + Vector2(-3, -2), Vector2(3, 4)), PixelArt.PAPER)
			draw_rect(Rect2(p + Vector2(0, -2), Vector2(3, 4)), PixelArt.PAPER)
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(1, 6)), PixelArt.GOLD)
			if int(t * 2.0) % 2 == 0:
				draw_rect(Rect2(p + Vector2(4, -6), Vector2(1, 1)), PixelArt.GOLD)
		"column":
			var k: float = 1.0 - t / z["life"]
			draw_rect(Rect2(z["pos"] + Vector2(-z["r"] * 0.6, -40), Vector2(z["r"] * 1.2, 40)), Color(PixelArt.FIRE, 0.5 * k))
			draw_rect(Rect2(z["pos"] + Vector2(-z["r"] * 0.3, -40), Vector2(z["r"] * 0.6, 40)), Color(PixelArt.FIRE_HOT, 0.7 * k))


func _draw_fx(f: Dictionary) -> void:
	var k: float = f["t"] / f["life"]
	var col: Color = f.get("color", PixelArt.PAPER)
	match f["kind"]:
		"burst":
			draw_arc(f["pos"], f["r"] * (0.4 + 0.6 * k), 0, TAU, 24, Color(col, 1.0 - k), 2.0, false)
		"ring":
			draw_arc(f["pos"], f["r"] * k, 0, TAU, 32, Color(col, 1.0 - k), 1.0, false)
		"dust":
			for i in 6:
				var a := i * TAU / 6.0
				draw_rect(Rect2((f["pos"] + Vector2(cos(a), sin(a) * 0.6) * f["r"] * k).round(), Vector2.ONE), Color("a08a6a", 1.0 - k))
		"clink":
			draw_line(f["pos"] + Vector2(-2, -2), f["pos"] + Vector2(2, 2), Color(PixelArt.PAPER, 1.0 - k), 1.0)
			draw_line(f["pos"] + Vector2(2, -2), f["pos"] + Vector2(-2, 2), Color(PixelArt.PAPER, 1.0 - k), 1.0)
		"spark_line":
			draw_line(f["pos"], f["to"], Color(col, 1.0 - k), 1.0)
		"beam":
			draw_line(f["pos"], f["to"], Color(PixelArt.PAPER, 1.0 - k), f["w"])
			draw_line(f["pos"], f["to"], Color(col, 1.0 - k), maxf(1.0, f["w"] - 4.0))
		"bolt":
			var p: Vector2 = f["pos"]
			var prev := p + Vector2(0, -80)
			for i in range(1, 6):
				var nxt := p + Vector2(rng.randf_range(-4, 4) if i < 5 else 0.0, -80 + i * 16)
				draw_line(prev, nxt, Color(col, 1.0 - k), 1.0)
				prev = nxt
		"swipe":
			var dir: Vector2 = f["dir"]
			draw_arc(f["pos"], f["r"], dir.angle() - 0.9, dir.angle() + 0.9, 10, Color(PixelArt.PAPER, 1.0 - k), 1.0, false)
		"trail":
			draw_line(f["pos"], f["to"], Color(col, 0.7 * (1.0 - k)), 3.0)
		"levelup":
			draw_arc(f["pos"], 6.0 + 18.0 * k, 0, TAU, 32, Color(PixelArt.GOLD, 1.0 - k), 1.0, false)
			for i in 8:
				var a := i * TAU / 8.0 + k
				var o := Vector2(cos(a) * 9.0, -20.0 * k + sin(a) * 3.0)
				draw_rect(Rect2((f["pos"] + o).round(), Vector2.ONE), Color(PixelArt.GOLD, 1.0 - k))
		"zap":
			var a: Vector2 = f["pos"]
			var b: Vector2 = f["to"]
			var n := (b - a).orthogonal().normalized()
			var prev := a
			var steps := maxi(2, int(a.distance_to(b) / 8.0))
			for i in range(1, steps + 1):
				var nxt := a.lerp(b, float(i) / steps) + (n * rng.randf_range(-3, 3) if i < steps else Vector2.ZERO)
				draw_line(prev, nxt, Color(col, 1.0 - k), f.get("w", 1.0))
				prev = nxt
		"spray":
			var dir: Vector2 = f["dir"]
			for i in 7:
				var a := dir.angle() + lerpf(-f["cone"] * 0.5, f["cone"] * 0.5, i / 6.0)
				var p: Vector2 = f["pos"] + Vector2.from_angle(a) * f["r"] * (0.3 + 0.7 * k) * (0.8 + 0.2 * fmod(i * 1.7, 1.0))
				draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(PixelArt.WATER, 1.0 - k))
		"cone":
			# A level-up ghost for a bolt cone: the old size, dashed.
			var dir: Vector2 = f["dir"]
			var gc := Color(PixelArt.PAPER, 0.7 * (1.0 - k))
			draw_dashed_line(f["pos"], f["pos"] + Vector2.from_angle(dir.angle() - f["cone"] * 0.5) * f["r"], gc)
			draw_dashed_line(f["pos"], f["pos"] + Vector2.from_angle(dir.angle() + f["cone"] * 0.5) * f["r"], gc)
			draw_arc(f["pos"], f["r"], dir.angle() - f["cone"] * 0.5, dir.angle() + f["cone"] * 0.5, 12, gc, 1.0, false)
		"rise":
			draw_texture(_tex["stone"], (f["pos"] - Vector2(3, 3 + 30.0 * k)).round(), Color(1, 0.6, 0.3, 1.0 - k))


func _draw_reticle() -> void:
	var m := mouse.round()
	var col := Color(PixelArt.PAPER, 0.85)
	draw_rect(Rect2(m + Vector2(-4, 0), Vector2(2, 1)), col)
	draw_rect(Rect2(m + Vector2(3, 0), Vector2(2, 1)), col)
	draw_rect(Rect2(m + Vector2(0, -4), Vector2(1, 2)), col)
	draw_rect(Rect2(m + Vector2(0, 3), Vector2(1, 2)), col)


func draw_ellipse_px(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## The Orrery: a brass armillary on a plinth. It glows while it can be used.
func _draw_shrine() -> void:
	var p := shrine_pos().round()
	var ready := shrine_ready()
	draw_ellipse_px(p + Vector2(0, 1), 9.0, 3.0, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(p + Vector2(-5, -5), Vector2(10, 5)), PixelArt.STONE)
	draw_rect(Rect2(p + Vector2(-1, -12), Vector2(2, 7)), PixelArt.GOLD)
	var spin := Time.get_ticks_msec() / 900.0
	draw_arc(p + Vector2(0, -17), 6.0, 0, TAU, 16, PixelArt.GOLD, 1.0, false)
	draw_arc(p + Vector2(0, -17), 6.0 * absf(cos(spin)), 0, TAU, 16, Color(PixelArt.GOLD, 0.8), 1.0, false)
	draw_rect(Rect2(p + Vector2(-1, -18), Vector2(2, 2)), PixelArt.FIRE_HOT if ready else PixelArt.PAPER)
	if ready:
		draw_arc(p + Vector2(0, -6), float(D["shrine"]["reach"]), 0, TAU, 32, Color(PixelArt.GOLD, 0.35), 1.0, false)


func draw_dashed_circle(c: Vector2, r: float, col: Color) -> void:
	var n := 16
	for i in n:
		if i % 2 == 0:
			draw_arc(c, r, i * TAU / n, (i + 1) * TAU / n, 4, col, 1.0, false)
