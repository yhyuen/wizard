extends RefCounted
## The wizard's spellbook: six slots (LMB, RMB, Q, E, R, F) holding any six known spells, from any
## sphere, changed only at an Orrery shrine. C is the Magick, Space blink. A Bolt fires while its
## slot is held; every other spell shows its telegraph while held and casts on release.
## Spells cost Aether (the mana) and follow Cadence: the same spell cast again in a row is dulled,
## while weaving different spells refunds Aether and builds notes toward a Resonant cast
## (design/magic-world-revisit.md §4.2 and §8). The spells live in scripts/spells/.

const SLOTS := ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6"]
const ALL_SLOTS := ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "magick"]
const GHOST_CASTS := 5
const FireEarth := preload("res://scripts/spells/fire_earth.gd")
const StormWater := preload("res://scripts/spells/storm_water.gd")
const HoursKit := preload("res://scripts/spells/hours.gd")

var A  # the arena
var fe  # Fire and Earth spells, and Meteor
var sw  # Storm and Water spells, and Conductor
var hr  # Hours: Rewind, from loop 2
var modules: Array = []
var cast_t = 0.0
var aether = 100.0
var last_cast = ""  # the spell cast last, for Cadence
var repeats = 0  # how many times in a row `last_cast` has been cast again
var notes = 0  # Cadence notes; a full set makes the next non-Bolt spell Resonant
var note_t = 0.0  # seconds since the last cast; notes fade after "note_life"
var blink_charges = 1
var blink_t = 0.0
var last_element = "fire"
var holding = ""
var hold_t = 0.0  # seconds the current Q/E/R/F has been held (Arc Lance charges with it)
var ghosts = {}  # spell id -> {"old": level before the level-up, "casts": casts left to show it}
var denied = {}  # slot -> seconds left on the "not ready" flash
var aim = Vector2.ZERO
var ward_charges = 0  # the slice's cantrip on C: blocks the next projectile while it is up
var ward_t = 0.0
var move = Vector2.ZERO


func _init(arena) -> void:
	A = arena
	fe = FireEarth.new(arena, self)
	sw = StormWater.new(arena, self)
	hr = HoursKit.new(arena, self)
	modules = [fe, sw, hr]
	Progression.spell_leveled.connect(_on_leveled)


func reset() -> void:
	cast_t = 0.0
	aether = max_aether()
	last_cast = ""
	repeats = 0
	notes = 0
	note_t = 0.0
	blink_charges = Progression.blink_charges()
	blink_t = 0.0
	ward_charges = int(Progression.rules.get("ward", {}).get("charges", 0))
	ward_t = 0.0
	holding = ""
	hold_t = 0.0
	denied.clear()
	last_element = Progression.loadout()[0]
	for m in modules:
		m.reset()


## After the spellbook changes at the shrine.
func reset_slots() -> void:
	holding = ""


func _on_leveled(id: String, old: int, _new: int) -> void:
	ghosts[id] = {"old": old, "casts": GHOST_CASTS}
	if A.player and not A.player.dead:
		A.fx("levelup", A.player.pos, {"life": 0.9})


func slot_spell(slot: String) -> String:
	if slot == "magick":
		return Progression.magick_for(Progression.loadout())
	var i := SLOTS.find(slot)
	if i < 0 or not Progression.slot_open(i):
		return ""
	return Progression.spellbook()[i]


## The slot holding spell `id`, or "".
func slot_of(id: String) -> String:
	for s in ALL_SLOTS:
		if slot_spell(s) == id:
			return s
	return ""


func is_bolt(id: String) -> bool:
	return Progression.data["spells"].has(id) and Progression.spell(id)["slot"] == "bolt"


# --- Aether and Cadence -------------------------------------------------------

func max_aether() -> float:
	return Progression.max_aether()


func aether_cost(id: String) -> float:
	if A.D["magicks"].has(id):
		return float(A.D["magicks"][id].get("aether", A.D["aether"]["costs"]["magick"]))
	var s: Dictionary = Progression.spell(id)
	return float(s.get("aether", A.D["aether"]["costs"][s["slot"]]))


## How much of its power spell `id` would keep if cast now (repeats in a row dull it).
func dull(id: String) -> float:
	var C: Dictionary = A.D["cadence"]
	var n: int = repeats + 1 if id == last_cast else 0
	return maxf(float(C["floor"]), 1.0 - float(C["repeat_loss"]) * n)


## A full set of notes makes the next non-Bolt spell Resonant.
func resonant_for(id: String) -> bool:
	return notes >= int(A.D["cadence"]["notes"]) and not is_bolt(id)


## The Cadence scaling for casting (or previewing) spell `id` now.
func boost_for(id: String, with_dull := true) -> Dictionary:
	var C: Dictionary = A.D["cadence"]
	var res := resonant_for(id)
	return {"id": id, "damage": dull(id) if with_dull else 1.0,
		"size": float(C["resonant_size"]) if res else 1.0, "count": int(C["resonant_count"]) if res else 0}


## Called after a cast lands: updates the repeat count and the notes, refunding Aether for variety.
func _cadence(id: String) -> void:
	var C: Dictionary = A.D["cadence"]
	if id == last_cast:
		A.stats["dulled"] = int(A.stats.get("dulled", 0)) + 1
	if resonant_for(id):
		notes = 0
		A.stats["resonant"] = int(A.stats.get("resonant", 0)) + 1
		A.fx("ring", A.player.pos, {"color": PixelArt.PAPER, "r": 18.0, "life": 0.4})
	elif last_cast != "" and id != last_cast and not (is_bolt(id) and is_bolt(last_cast)):
		notes = mini(notes + 1, int(C["notes"]))
		aether = minf(max_aether(), aether + float(C["refund"]))
	repeats = repeats + 1 if id == last_cast else 0
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


## How long spell `id` is locked: its cooldown, or longer after an Overdraw.
func cooldown_total(id: String) -> float:
	if A.player and A.player.cd_total.has(id):
		return float(A.player.cd_total[id])
	return base_cooldown(id)


func base_cooldown(id: String) -> float:
	if A.D["magicks"].has(id):
		return float(A.D["magicks"][id]["cooldown"])
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
	cast_t -= dt
	aether = minf(max_aether(), aether + float(A.D["aether"]["regen"]) * dt)
	ward_t = maxf(0.0, ward_t - dt)
	note_t += dt
	if note_t > float(A.D["cadence"]["note_life"]):
		notes = 0
	for k in denied.keys():
		denied[k] -= dt
		if denied[k] <= 0.0:
			denied.erase(k)
	var max_charges = Progression.blink_charges()
	if blink_charges < max_charges:
		blink_t += dt
		if blink_t >= float(A.D["wizard"]["blink_recharge"]):
			blink_t = 0.0
			blink_charges += 1
	for m in modules:
		m.update(dt)
	P.moving = false
	P.flags["move"] = Vector2.ZERO
	if absf(aim.x - P.pos.x) > 1.0:
		P.facing = signf(aim.x - P.pos.x)
	if P.locked():
		holding = ""
		return
	if move.length() > 0.01:
		var v = move.normalized() * A.move_speed(P)
		if holding != "" and slot_spell(holding) == "arc_lance":
			v *= float(Progression.spell("arc_lance")["hold_speed"])
		P.pos = A.clamp_in(P.pos + v * dt, P.radius)
		P.moving = true
		P.flags["move"] = v
	if pressed.get("blink", false):
		blink()
	if cast_t <= 0.0:
		for s in SLOTS:
			if held.get(s, false) and is_bolt(slot_spell(s)):
				bolt(slot_spell(s))
				break
	if holding != "":
		hold_t += dt
	for s in ALL_SLOTS:
		if is_bolt(slot_spell(s)):
			continue
		if pressed.get(s, false):
			holding = s
			hold_t = 0.0
		if released.get(s, false):
			if holding == s:
				cast(s)
			if holding == s:
				holding = ""
	if holding != "" and not held.get(holding, false):
		holding = ""


## Ward (the slice's cantrip): a ring of light that stops the next projectile, for a moment.
func ward() -> void:
	if ward_charges <= 0 or ward_t > 0.0:
		denied["magick"] = 0.4
		return
	ward_charges -= 1
	ward_t = float(Progression.rules["ward"]["time"])
	A.fx("ring", A.player.pos, {"color": PixelArt.GOLD, "r": 12.0, "life": 0.3})


## True if the Ward is up; it breaks on the projectile it stops.
func ward_blocks() -> bool:
	if ward_t <= 0.0:
		return false
	ward_t = 0.0
	A.fx("burst", A.player.pos + Vector2(0, -6), {"color": PixelArt.GOLD, "r": 10.0, "life": 0.3})
	return true


func bolt(id: String) -> void:
	var m = _module_for(id)
	if m == null:
		return
	_run(m, id)
	cast_t = float(Progression.spell(id)["cast_time"])
	last_element = Progression.spell(id)["element"]
	_cadence(id)
	count(id)


func cast(slot: String) -> void:
	if slot == "magick" and Progression.rules.has("ward"):
		ward()
		return
	var id = slot_spell(slot)
	var P: Unit = A.player
	if id == "":
		if slot == "magick":
			A.toast.emit("This pair has no Magick in the prototype yet.", PixelArt.PAPER)
		denied[slot] = 0.4
		return
	if P.cooldown(id) > 0.0:
		denied[slot] = 0.4
		return
	var m = _module_for(id)
	var ok = m != null and _run(m, id)
	if not ok:
		denied[slot] = 0.4
		return
	var cost := aether_cost(id)
	var lock := base_cooldown(id)
	if aether < cost:
		# Overdraw: the missing Aether is paid in HP, and the spell is locked for a while.
		var O: Dictionary = A.D["overdraw"]
		P.hp = maxf(1.0, P.hp - (cost - aether) * float(O["hp_per_aether"]))
		lock = maxf(lock, float(O["lock"]))
		A.fx("burst", P.pos + Vector2(0, -6), {"color": PixelArt.DANGER, "r": 8.0, "life": 0.3})
		A.stats["overdraws"] = int(A.stats.get("overdraws", 0)) + 1
	aether = maxf(0.0, aether - cost)
	A.stats["aether_spent"] = float(A.stats.get("aether_spent", 0.0)) + cost
	_cadence(id)
	P.cd[id] = lock
	P.cd_total[id] = lock
	if Progression.data["spells"].has(id):
		last_element = Progression.spell(id)["element"]
	count(id)
	use_ghost(id)


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
	var dest: Vector2 = A.clamp_in(P.pos + dir * float(A.D["wizard"]["blink_dist"]), P.radius)
	A.fx("trail", P.pos + Vector2(0, -6), {"to": dest + Vector2(0, -6), "color": element_color(last_element), "life": 0.3})
	A.fx("dust", P.pos, {"r": 6.0, "life": 0.3})
	P.pos = dest
	P.iframes = maxf(P.iframes, 0.18)
	blink_charges -= 1


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

## While a non-Bolt slot is held, its telegraph shows exactly what will be hit. After a level-up, a
## dashed ghost shows the old size for a few casts (design doc §3).
func draw(c: CanvasItem) -> void:
	var P: Unit = A.player
	if P.dead or holding == "":
		return
	var id = slot_spell(holding)
	if id == "":
		return
	var ghost_old: int = ghosts[id]["old"] if ghosts.has(id) else 0
	# A Resonant cast previews at its real, bigger size: the telegraph is the hitbox.
	Progression.boost = boost_for(id, false)
	for m in modules:
		if m.draw_preview(c, id, ghost_old):
			break
	Progression.boost = {}


func draw_cone(c: CanvasItem, dir: Vector2, cone: float, reach_len: float, col: Color) -> void:
	var o: Vector2 = A.player.pos + Vector2(0, -4)
	var a = dir.angle()
	c.draw_line(o, o + Vector2.from_angle(a - cone * 0.5) * reach_len, col, 1.0)
	c.draw_line(o, o + Vector2.from_angle(a + cone * 0.5) * reach_len, col, 1.0)
	c.draw_arc(o, reach_len, a - cone * 0.5, a + cone * 0.5, 16, col, 1.0, false)
