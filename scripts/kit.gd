extends RefCounted
## The wizard's kit (spell and combat spec §3–5): four spellbook slots (Q, E, R, F) holding any four
## known spells, two cantrips (1, 2), and always the staff strike (LMB), the Ward (hold RMB) and
## Blink (Space). Every spell has a wind-up, a release and a recovery: hold its key to wind up (the
## telegraph shows what will be hit), release to cast. Aether is scarce and slow to come back in a
## fight; short of it, a spell still casts by Overdraw, paid in HP and Strain until you rest. A hit
## above your Focus breaks a wind-up. Cadence: weaving different spells refunds a little Aether and
## builds notes toward a Resonant cast. The spells live in scripts/spells/.

const SLOTS := ["slot1", "slot2", "slot3", "slot4"]
const CANTRIPS := ["cant1", "cant2"]
const GHOST_CASTS := 5
const FireEarth := preload("res://scripts/spells/fire_earth.gd")
const StormWater := preload("res://scripts/spells/storm_water.gd")
const HoursKit := preload("res://scripts/spells/hours.gd")

var A  # the arena
var fe  # Fire and Earth spells
var sw  # Storm and Water spells
var hr  # Hours: Rewind, from loop 2
var modules: Array = []
var aether = 100.0
var strain = 0.0  # from Overdraw: lowers max Aether one for one until you rest
var last_cast = ""  # the spell cast last, for Cadence
var notes = 0  # Cadence notes; a full set makes the next spell Resonant
var note_t = 0.0  # seconds since the last cast; notes fade after "note_life"
var blink_charges = 1
var blink_t = 0.0
var last_element = "fire"
## The spell being wound up: {"slot", "id", "t", "need", "band", "commit"}; empty when there is none.
var wind := {}
var recover_t := 0.0  # after a release: no new spell until it runs out
var holding = ""  # the slot being wound up (its telegraph shows), or ""
var hold_t = 0.0  # seconds the current spell has been held (Arc Lance charges with it)
var staff_t := 0.0  # until the next staff strike
var warding := false  # the Ward is up
var ward_cool := 0.0  # after the Ward breaks or drops: until it can be raised again
var cant_charges := {}  # cantrip id -> charges
var cant_t := {}  # cantrip id -> seconds toward the next charge
var ghosts = {}  # spell id -> {"old": level before the level-up, "casts": casts left to show it}
var denied = {}  # slot -> seconds left on the "not ready" flash
var aim = Vector2.ZERO
var move = Vector2.ZERO


func _init(arena) -> void:
	A = arena
	fe = FireEarth.new(arena, self)
	sw = StormWater.new(arena, self)
	hr = HoursKit.new(arena, self)
	modules = [fe, sw, hr]
	Progression.spell_leveled.connect(_on_leveled)


## A new map or fight: everything but Aether and Strain, which only rest restores.
func reset() -> void:
	last_cast = ""
	notes = 0
	note_t = 0.0
	blink_charges = Progression.blink_charges()
	blink_t = 0.0
	wind = {}
	recover_t = 0.0
	holding = ""
	hold_t = 0.0
	staff_t = 0.0
	warding = false
	ward_cool = 0.0
	denied.clear()
	for id in cantrips():
		cant_charges[id] = int(cantrip(id)["charges"])
		cant_t[id] = 0.0
	aether = minf(aether, max_aether())
	last_element = Progression.loadout()[0]
	for m in modules:
		m.reset()


## Rest (waking at dawn, meditating, the start of a test fight): Strain clears, Aether is full.
func rest() -> void:
	strain = 0.0
	aether = max_aether()


## After the spellbook changes at your desk.
func reset_slots() -> void:
	_cancel()


func _on_leveled(id: String, old: int, _new: int) -> void:
	ghosts[id] = {"old": old, "casts": GHOST_CASTS}
	if A.player and not A.player.dead:
		A.fx("levelup", A.player.pos, {"life": 0.9})


func slot_spell(slot: String) -> String:
	if slot in CANTRIPS:
		var cs := cantrips()
		var ci := CANTRIPS.find(slot)
		return cs[ci] if ci < cs.size() else ""
	var i := SLOTS.find(slot)
	if i < 0 or not Progression.slot_open(i) or i >= Progression.spellbook().size():
		return ""
	return Progression.spellbook()[i]


## The slot holding spell `id`, or "".
func slot_of(id: String) -> String:
	for s in SLOTS:
		if slot_spell(s) == id:
			return s
	return ""


func cantrips() -> Array:
	return A.D.get("start_cantrips", [])


func cantrip(id: String) -> Dictionary:
	return A.D["cantrips"][id]


func is_cantrip(id: String) -> bool:
	return A.D.get("cantrips", {}).has(id)


## The spell's cast speed band: swift, weave or incant.
func band(id: String) -> String:
	return str(Progression.spell(id).get("cast", "swift"))


func windup(id: String) -> float:
	return float(Progression.spell(id).get("windup", 0.4))


# --- Aether and Cadence -------------------------------------------------------

func max_aether() -> float:
	return maxf(0.0, Progression.max_aether() - strain)


func aether_cost(id: String) -> float:
	if is_cantrip(id):
		return float(cantrip(id)["aether"])
	var s: Dictionary = Progression.spell(id)
	return float(s.get("aether", A.D["aether"]["costs"].get(band(id), 20)))


## Casting the same spell again no longer dulls it (cooldowns stop repeats): always 1.
func dull(_id: String) -> float:
	return 1.0


## A full set of notes makes the next spell Resonant.
func resonant_for(id: String) -> bool:
	return notes >= int(A.D["cadence"]["notes"]) and not is_cantrip(id)


## The Cadence scaling for casting (or previewing) spell `id` now.
func boost_for(id: String) -> Dictionary:
	var C: Dictionary = A.D["cadence"]
	var res := resonant_for(id)
	return {"id": id, "damage": 1.0, "size": float(C["resonant_size"]) if res else 1.0, "count": int(C["resonant_count"]) if res else 0}


## Called after a cast lands: a different spell from the last adds a note and refunds a little Aether.
func _cadence(id: String) -> void:
	var C: Dictionary = A.D["cadence"]
	if resonant_for(id):
		notes = 0
		A.stats["resonant"] = int(A.stats.get("resonant", 0)) + 1
		A.fx("ring", A.player.pos, {"color": PixelArt.PAPER, "r": 18.0, "life": 0.4})
	elif last_cast != "" and id != last_cast:
		notes = mini(notes + 1, int(C["notes"]))
		aether = minf(max_aether(), aether + float(C["refund"]))
	last_cast = id
	note_t = 0.0


## Runs one cast of `id` with Cadence applied; false if the spell refused (no target, no stones).
func _run(m, id: String) -> bool:
	Progression.boost = boost_for(id)
	var ok = m.call(id)
	Progression.boost = {}
	return not (ok is bool and ok == false)


func equipped(element: String) -> bool:
	return Progression.loadout().has(element)


func cooldown_total(id: String) -> float:
	if A.player and A.player.cd_total.has(id):
		return float(A.player.cd_total[id])
	return base_cooldown(id)


func base_cooldown(id: String) -> float:
	return float(Progression.spell(id).get("cooldown", 0.0))


func element_color(e: String) -> Color:
	match e:
		"fire":
			return PixelArt.FIRE
		"earth":
			return PixelArt.EARTH
		"storm":
			return PixelArt.STORM
		"water":
			return PixelArt.WATER
		"hours":
			return PixelArt.HOURS
	return PixelArt.PAPER


func _module_for(method: String):
	for m in modules:
		if m.has_method(method):
			return m
	return null


# --- input ------------------------------------------------------------------

func update(dt: float, intent: Dictionary) -> void:
	var P: Unit = A.player
	var held: Dictionary = intent.get("held", {})
	var pressed: Dictionary = intent.get("pressed", {})
	var released: Dictionary = intent.get("released", {})
	aim = intent.get("aim", A.mouse)
	move = intent.get("move", Vector2.ZERO)
	_regen(dt)
	note_t += dt
	if note_t > float(A.D["cadence"]["note_life"]):
		notes = 0
	for k in denied.keys():
		denied[k] -= dt
		if denied[k] <= 0.0:
			denied.erase(k)
	if blink_charges < Progression.blink_charges():
		blink_t += dt
		if blink_t >= float(A.D["wizard"]["blink_recharge"]):
			blink_t = 0.0
			blink_charges += 1
	for id in cant_charges:
		if cant_charges[id] < int(cantrip(id)["charges"]):
			cant_t[id] += dt
			if cant_t[id] >= float(cantrip(id)["recharge"]):
				cant_t[id] = 0.0
				cant_charges[id] += 1
	staff_t = maxf(0.0, staff_t - dt)
	recover_t = maxf(0.0, recover_t - dt)
	ward_cool = maxf(0.0, ward_cool - dt)
	for m in modules:
		m.update(dt)
	P.moving = false
	P.flags["move"] = Vector2.ZERO
	if absf(aim.x - P.pos.x) > 1.0:
		P.facing = signf(aim.x - P.pos.x)
	if P.locked():
		_cancel()
		warding = false
		return
	if move.length() > 0.01:
		var v = move.normalized() * A.move_speed(P) * move_mult()
		if v.length() > 0.01:
			P.pos = A.clamp_in(P.pos + v * dt, P.radius)
			P.moving = true
			P.flags["move"] = v
	if pressed.get("blink", false):
		_cancel()
		recover_t = 0.0
		blink()
	# The Ward: up while held, if there's Aether for it and nothing is being wound up.
	var want_ward: bool = held.get("ward", false) and wind.is_empty() and ward_cool <= 0.0
	if want_ward and not warding and aether > 1.0:
		warding = true
		Sfx.play("ward")
	elif not want_ward:
		warding = false
	if (pressed.get("staff", false) or held.get("staff", false)) and staff_t <= 0.0 and wind.is_empty() and not warding:
		staff_strike()
	for c in CANTRIPS:
		if pressed.get(c, false):
			cast_cantrip(c)
	for s in SLOTS:
		if pressed.get(s, false):
			begin(s)
		if released.get(s, false) and wind.get("slot", "") == s:
			release(intent.get("smart", false))
	# A key-up lost in a frozen frame (hit-stop) still counts: the key is no longer held.
	if not wind.is_empty() and not wind["commit"] and not held.get(wind["slot"], false):
		release(intent.get("smart", false))
	if not wind.is_empty():
		wind["t"] += dt
		hold_t += dt
		if wind["commit"] and wind["t"] >= wind["need"]:
			_fire()


func _regen(dt: float) -> void:
	var M: Dictionary = A.D["aether"]
	var top := max_aether()
	if warding:
		aether = maxf(0.0, aether - float(A.D["ward"]["drain"]) * dt)
		if aether <= 0.0:
			_drop_ward()
		return
	if A.fighting():
		aether = minf(top, aether + float(M["regen_fight"]) * dt)
	else:
		var cap: float = top * float(M["out_cap"])
		if aether < cap:
			aether = minf(cap, aether + float(M["regen_out"]) * dt)


## How fast the wizard walks now: slowed while winding up (rooted for an Incant), in recovery and
## behind the Ward.
func move_mult() -> float:
	var C: Dictionary = A.D["casting"]
	var m := 1.0
	if not wind.is_empty():
		m = float(C[wind["band"]]["move"])
	elif recover_t > 0.0:
		m = float(C["recovery_move"])
	if warding:
		m *= float(A.D["ward"]["move"])
	return m


## Starts winding up the spell in `slot`.
func begin(slot: String) -> void:
	var id := slot_spell(slot)
	if id == "" or not wind.is_empty() or recover_t > 0.0 or A.player.cooldown(id) > 0.0:
		denied[slot] = 0.4
		return
	warding = false
	var b := band(id)
	wind = {"slot": slot, "id": id, "t": 0.0, "need": windup(id), "band": b, "commit": false}
	holding = slot
	hold_t = 0.0


## The key came up: cast if the wind-up is full; a Swift spell (or any spell under smart cast) is
## committed and fires when its wind-up ends; anything else is cancelled with nothing spent.
func release(smart := false) -> void:
	if wind.is_empty():
		return
	if wind["t"] >= wind["need"]:
		_fire()
	elif wind["band"] == "swift" or smart:
		wind["commit"] = true
	else:
		_cancel()


## Fraction of the current wind-up done, 0..1 (0 when nothing is being wound up).
func wind_k() -> float:
	if wind.is_empty():
		return 0.0
	return clampf(float(wind["t"]) / maxf(0.01, float(wind["need"])), 0.0, 1.0)


func _cancel() -> void:
	wind = {}
	holding = ""
	hold_t = 0.0


## A hit above your Focus broke the wind-up: half its Aether is lost.
func interrupt() -> void:
	if wind.is_empty():
		return
	var id: String = wind["id"]
	aether = maxf(0.0, aether - aether_cost(id) * float(A.D["casting"]["interrupt_cost"]))
	_cancel()
	A.stats["broken"] = int(A.stats.get("broken", 0)) + 1
	A.fx("clink", A.player.pos + Vector2(0, -12), {"life": 0.35})
	A.fx("burst", A.player.pos + Vector2(0, -10), {"color": PixelArt.DANGER, "r": 6.0, "life": 0.3})
	A.toast.emit("Cast broken", PixelArt.DANGER)


func focus() -> int:
	return int(A.D["casting"]["focus"])


func _fire() -> void:
	var slot: String = wind["slot"]
	var id: String = wind["id"]
	var b: String = wind["band"]
	cast(slot)
	_cancel()
	recover_t = float(A.D["casting"][b]["recovery"])


func cast(slot: String) -> void:
	var id = slot_spell(slot)
	var P: Unit = A.player
	if id == "" or P.cooldown(id) > 0.0:
		denied[slot] = 0.4
		return
	var m = _module_for(id)
	var ok = m != null and _run(m, id)
	if not ok:
		denied[slot] = 0.4
		return
	_pay(aether_cost(id))
	_cadence(id)
	var lock := base_cooldown(id)
	P.cd[id] = lock
	P.cd_total[id] = lock
	last_element = Progression.spell(id)["element"]
	Sfx.play("cast_" + last_element, 3.0)
	count(id)
	use_ghost(id)


## Spends `cost` Aether. Short of it, the missing part is Overdrawn: paid in HP and Strain, and at
## high Strain the backlash stuns you.
func _pay(cost: float) -> void:
	var P: Unit = A.player
	if aether < cost:
		var O: Dictionary = A.D["overdraw"]
		var missing: float = cost - aether
		P.hp = maxf(1.0, P.hp - missing * float(O["hp_per_aether"]))
		strain += missing * float(O["strain_per_aether"])
		A.fx("burst", P.pos + Vector2(0, -6), {"color": PixelArt.DANGER, "r": 8.0, "life": 0.3})
		A.stats["overdraws"] = int(A.stats.get("overdraws", 0)) + 1
		if strain >= float(O["backlash_at"]):
			P.stun = maxf(P.stun, float(O["backlash_stun"]))
			A.toast.emit("Backlash", PixelArt.DANGER)
	aether = maxf(0.0, aether - cost)
	A.stats["aether_spent"] = float(A.stats.get("aether_spent", 0.0)) + cost


func count(id: String) -> void:
	A.stats["casts"] += 1
	A.stats["by_spell"][id] = int(A.stats["by_spell"].get(id, 0)) + 1


func use_ghost(id: String) -> void:
	if ghosts.has(id):
		ghosts[id]["casts"] -= 1
		if ghosts[id]["casts"] <= 0:
			ghosts.erase(id)


func aim_dir() -> Vector2:
	var d: Vector2 = aim - A.player.pos
	return d.normalized() if d.length() > 0.5 else Vector2(A.player.facing, 0)


func origin() -> Vector2:
	return A.player.pos + Vector2(0, -6)


## The aim point, no further than `reach_len` from the wizard and inside the yard.
func aim_point(reach_len: float) -> Vector2:
	return A.clamp_in(A.player.pos + (aim - A.player.pos).limit_length(reach_len))


func blink() -> void:
	var P: Unit = A.player
	if blink_charges <= 0:
		denied["blink"] = 0.4
		return
	var dir = move.normalized() if move.length() > 0.01 else aim_dir()
	var dist := float(A.D["wizard"]["blink_dist"])
	if A.world != null:
		# no blinking through a wall into the dark outside the ruin: stop where the wall is
		var go := 0.0
		while go + 4.0 <= dist and not A.world.solid_at(P.pos + dir * (go + 4.0), P.radius):
			go += 4.0
		dist = go
	var dest: Vector2 = A.clamp_in(P.pos + dir * dist, P.radius)
	A.fx("trail", P.pos + Vector2(0, -6), {"to": dest + Vector2(0, -6), "color": element_color(last_element), "life": 0.3})
	A.fx("dust", P.pos, {"r": 6.0, "life": 0.3})
	P.pos = dest
	P.iframes = maxf(P.iframes, 0.18)
	blink_charges -= 1


# --- staff, Ward and cantrips -------------------------------------------------

## The staff strike: a short knock in front of you that also shoves props. Free, never a way to win.
func staff_strike() -> void:
	var S: Dictionary = A.D["staff"]
	var P: Unit = A.player
	staff_t = float(S["every"])
	var dir := aim_dir()
	var reach := float(S["reach"])
	A.fx("swipe", P.pos, {"dir": dir, "r": reach * 0.8, "life": 0.15})
	for u in A.enemies():
		var to: Vector2 = u.pos - P.pos
		if to.length() < reach + u.radius and absf(dir.angle_to(to)) < float(S["arc"]) * 0.5:
			A.hit(u, float(S["damage"]), int(S["impact"]), dir, float(S["knock"]))
	if A.town != null:
		var pr: Dictionary = A.town.prop_at(P.pos + dir * reach * 0.6, reach * 0.5)
		if not pr.is_empty():
			A.town.shove(pr, dir, 0.4)
	A.stats["staff"] = int(A.stats.get("staff", 0)) + 1


## True if the Ward is up and facing a hit coming along `dir`: it stops the hit and costs Aether.
## Impact at `breaks_at` or more breaks it (the arena staggers you); so does running out of Aether.
func ward_stops(dir: Vector2, impact: int) -> bool:
	if not warding or dir.length() < 0.01:
		return false
	var W: Dictionary = A.D["ward"]
	if absf(aim_dir().angle_to(-dir)) > float(W["arc"]) * 0.5:
		return false
	aether = maxf(0.0, aether - float(W["per_hit"]))
	A.stats["warded"] = int(A.stats.get("warded", 0)) + 1
	var at: Vector2 = A.player.pos + aim_dir() * 6.0 + Vector2(0, -6)
	A.fx("burst", at, {"color": PixelArt.GOLD, "r": 8.0, "life": 0.25})
	Sfx.play("ward")
	if impact >= int(W["breaks_at"]) or aether <= 0.0:
		_drop_ward()
	return true


func ward_broken() -> bool:
	return ward_cool > 0.0 and not warding


func _drop_ward() -> void:
	warding = false
	ward_cool = float(A.D["ward"]["cool"])
	A.fx("ring", A.player.pos, {"color": PixelArt.DANGER, "r": 12.0, "life": 0.3})


func cast_cantrip(slot: String) -> void:
	var id := slot_spell(slot)
	if id == "" or int(cant_charges.get(id, 0)) <= 0 or not wind.is_empty():
		denied[slot] = 0.4
		return
	var c: Dictionary = cantrip(id)
	var at: Vector2 = aim_point(float(c["range"]))
	var r := float(c["r"])
	match id:
		"kindle":
			A.fx("burst", at, {"color": PixelArt.FIRE, "r": r, "life": 0.3})
			for u in A.enemies():
				if u.pos.distance_to(at) < r + u.radius:
					A._src_kind = "fire"
					A.hit(u, float(c["damage"]), int(c["impact"]), (u.pos - A.player.pos).normalized(), 10.0)
					A._src_kind = ""
					A.add_pips(u, int(c["pips"]))
		"douse":
			A.fx("burst", at, {"color": PixelArt.WATER, "r": r, "life": 0.3})
			A.fx("dust", at, {"color": PixelArt.WATER, "r": r, "life": 0.4})
			for u in A.enemies():
				if u.pos.distance_to(at) < r + u.radius:
					u.wet_t = maxf(u.wet_t, float(c["wet"]))
	# The world reads this mark (scripts/world/world.gd): Kindle lights and burns, Douse puts out.
	A.add_zone({"kind": id, "pos": at, "r": r, "life": 0.2})
	cant_charges[id] -= 1
	_pay(aether_cost(id))
	last_element = c["element"]
	Sfx.play("cast_" + last_element, 3.0)
	A.stats["cantrips"] = int(A.stats.get("cantrips", 0)) + 1


# --- hooks from the arena -----------------------------------------------------

## Returns true to keep the projectile flying (pierce, bounce).
func on_proj_hit(p: Dictionary, u: Unit) -> bool:
	for m in modules:
		if m.handles_proj(p["kind"]):
			return m.on_proj_hit(p, u)
	return false


## A delayed telegraph the wizard placed has landed.
func detonate(z: Dictionary) -> bool:
	for m in modules:
		if m.detonate(z):
			return true
	return false


func draw_field(c: CanvasItem) -> void:
	for m in modules:
		m.draw_field(c)


# --- previews -----------------------------------------------------------------

## While a spell winds up, its telegraph shows exactly what will be hit (a Swift bolt shows its
## line). After a level-up, a dashed ghost shows the old size for a few casts.
func draw(c: CanvasItem) -> void:
	var P: Unit = A.player
	if P.dead or holding == "":
		return
	var id = slot_spell(holding)
	if id == "":
		return
	var ghost_old: int = ghosts[id]["old"] if ghosts.has(id) else 0
	# A Resonant cast previews at its real, bigger size: the telegraph is the hitbox.
	Progression.boost = boost_for(id)
	var drawn := false
	for m in modules:
		if m.draw_preview(c, id, ghost_old):
			drawn = true
			break
	Progression.boost = {}
	if not drawn:
		var o: Vector2 = P.pos + Vector2(0, -4)
		c.draw_line(o, o + aim_dir() * (16.0 + 44.0 * wind_k()), Color(element_color(Progression.spell(id)["element"]), 0.9), 1.0)


func draw_cone(c: CanvasItem, dir: Vector2, cone: float, reach_len: float, col: Color) -> void:
	var o: Vector2 = A.player.pos + Vector2(0, -4)
	var a = dir.angle()
	c.draw_line(o, o + Vector2.from_angle(a - cone * 0.5) * reach_len, col, 1.0)
	c.draw_line(o, o + Vector2.from_angle(a + cone * 0.5) * reach_len, col, 1.0)
	c.draw_arc(o, reach_len, a - cone * 0.5, a + cone * 0.5, 16, col, 1.0, false)
