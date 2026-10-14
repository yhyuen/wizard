extends RefCounted
## The wizard's loadout: two equipped elements (design doc §1), changed only at an Orrery shrine.
## LMB / RMB are the Bolts of element 1 / 2, Q / E their Control spells, R the Signature (Tab swaps
## between the two elements' signatures), F the Magick for the pair, Space blink. Q, E, R and F
## show their telegraph while held and cast on release. The spells live in scripts/spells/.

const HOLD := ["control1", "control2", "signature", "magick"]
const GHOST_CASTS := 5
const FireEarth := preload("res://scripts/spells/fire_earth.gd")
const StormWater := preload("res://scripts/spells/storm_water.gd")

var A  # the arena
var fe  # Fire and Earth spells, and Meteor
var sw  # Storm and Water spells, and Conductor
var modules: Array = []
var cast_t = 0.0
var sig_index = 0
var signature: String:
	get:
		return Progression.spell_for(Progression.loadout()[sig_index], "signature")
var blink_charges = 1
var blink_t = 0.0
var last_element = "fire"
var holding = ""
var hold_t = 0.0  # seconds the current Q/E/R/F has been held (Arc Lance charges with it)
var ghosts = {}  # spell id -> {"old": level before the level-up, "casts": casts left to show it}
var denied = {}  # slot -> seconds left on the "not ready" flash
var aim = Vector2.ZERO
var move = Vector2.ZERO


func _init(arena) -> void:
	A = arena
	fe = FireEarth.new(arena, self)
	sw = StormWater.new(arena, self)
	modules = [fe, sw]
	Progression.spell_leveled.connect(_on_leveled)


func reset() -> void:
	cast_t = 0.0
	blink_charges = Progression.blink_charges()
	blink_t = 0.0
	holding = ""
	hold_t = 0.0
	sig_index = 0
	denied.clear()
	last_element = Progression.loadout()[0]
	for m in modules:
		m.reset()


## After the loadout changes at the shrine: the signature goes back to element 1's.
func reset_slots() -> void:
	sig_index = 0
	holding = ""


func _on_leveled(id: String, old: int, _new: int) -> void:
	ghosts[id] = {"old": old, "casts": GHOST_CASTS}
	if A.player and not A.player.dead:
		A.fx("levelup", A.player.pos, {"life": 0.9})


func slot_spell(slot: String) -> String:
	var lo: Array = Progression.loadout()
	match slot:
		"bolt1":
			return Progression.spell_for(lo[0], "bolt")
		"bolt2":
			return Progression.spell_for(lo[1], "bolt")
		"control1":
			return Progression.spell_for(lo[0], "control")
		"control2":
			return Progression.spell_for(lo[1], "control")
		"signature":
			return signature
		"magick":
			return Progression.magick_for(lo)
	return ""


func equipped(element: String) -> bool:
	return Progression.loadout().has(element)


func cooldown_total(id: String) -> float:
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
	if pressed.get("swap_signature", false):
		sig_index = 1 - sig_index
		var s: Dictionary = Progression.spell(signature)
		A.toast.emit("Signature: " + s["name"], element_color(s["element"]))
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
	if held.get("bolt1", false) and cast_t <= 0.0:
		bolt(slot_spell("bolt1"))
	elif held.get("bolt2", false) and cast_t <= 0.0:
		bolt(slot_spell("bolt2"))
	if holding != "":
		hold_t += dt
	for s in HOLD:
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


func bolt(id: String) -> void:
	var m = _module_for(id)
	if m == null:
		return
	m.call(id)
	cast_t = float(Progression.spell(id)["cast_time"])
	last_element = Progression.spell(id)["element"]
	count(id)


func cast(slot: String) -> void:
	var id = slot_spell(slot)
	var P: Unit = A.player
	if id == "":
		A.toast.emit("This pair has no Magick in the prototype yet.", PixelArt.PAPER)
		denied[slot] = 0.4
		return
	if P.cooldown(id) > 0.0:
		denied[slot] = 0.4
		return
	var m = _module_for(id)
	var ok = m != null and m.call(id)
	if not ok:
		denied[slot] = 0.4
		return
	P.cd[id] = cooldown_total(id)
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

## While Q/E/R/F is held, its telegraph shows exactly what will be hit. After a level-up, a
## dashed ghost shows the old size for a few casts (design doc §3).
func draw(c: CanvasItem) -> void:
	var P: Unit = A.player
	if P.dead or holding == "":
		return
	var id = slot_spell(holding)
	if id == "":
		return
	var ghost_old: int = ghosts[id]["old"] if ghosts.has(id) else 0
	for m in modules:
		if m.draw_preview(c, id, ghost_old):
			return


func draw_cone(c: CanvasItem, dir: Vector2, cone: float, reach_len: float, col: Color) -> void:
	var o: Vector2 = A.player.pos + Vector2(0, -4)
	var a = dir.angle()
	c.draw_line(o, o + Vector2.from_angle(a - cone * 0.5) * reach_len, col, 1.0)
	c.draw_line(o, o + Vector2.from_angle(a + cone * 0.5) * reach_len, col, 1.0)
	c.draw_arc(o, reach_len, a - cone * 0.5, a + cone * 0.5, 16, col, 1.0, false)
