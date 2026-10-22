extends RefCounted
## Armour layers (enemy spec §5.3; build item N-6.6): leather, mail and plate over a flesh body.
## A hit at or above the layer's grade in Impact goes fully through; a lighter one is mostly
## stopped. Every hit wears the layer down (more while the wearer is Broken), and when it's gone the
## armour is sundered: it falls away, and the wearer is plain flesh with a fuller Break meter.
## Metal lets lightning straight through and fire heats it, burning the wearer inside.

var A  # the arena


func _init(arena) -> void:
	A = arena


## Its armour layer's record, or {} once sundered (or if it wears none).
func layer(u: Unit) -> Dictionary:
	var kind := str(A.D["enemies"][u.kind].get("armour", ""))
	if kind == "" or u.flags.get("sundered", false):
		return {}
	return A.D["foes"]["armour"][kind]


func metal(u: Unit) -> bool:
	return layer(u).get("metal", false)


## A hit on it: how much of `dmg` reaches the body. Wears the layer, sunders it at 0.
func soak(u: Unit, dmg: float, impact: int, fire: bool, storm: bool) -> float:
	var a := layer(u)
	if a.is_empty():
		return dmg
	var R: Dictionary = A.D["foes"]["armour"]
	if not u.flags.has("arm_hp"):
		u.flags["arm_hp"] = float(a["hp"])
	var through := 1.0 if impact >= int(a["grade"]) else float(a["through"])
	if a.get("metal", false):
		if storm:
			through = 1.0  # lightning runs through the metal to the man inside
			A.guide.found(u, "conducted")
		if fire:
			u.flags["heat_t"] = float(R["heat_s"])
			A.guide.found(u, "heated")
	if through < 1.0 and not A.stats.has("armour_seen"):
		A.stats["armour_seen"] = true
		A.toast.emit("The %s turns light spells. Hit harder, or strip it." % str(a["name"]).to_lower(), PixelArt.PAPER)
	u.flags["arm_hp"] = float(u.flags["arm_hp"]) - dmg * (float(R["broken_k"]) if u.broken_t > 0.0 else 1.0)
	if u.flags["arm_hp"] <= 0.0:
		sunder(u)
	return dmg * through


## The armour falls away: plates on the ground, a Break bonus, and a body any spell can hurt.
func sunder(u: Unit) -> void:
	u.flags["sundered"] = true
	u.flags.erase("heat_t")
	A.fx("burst", u.pos + Vector2(0, -6), {"color": PixelArt.PAPER, "r": u.radius + 8.0, "life": 0.4})
	A.fx("clink", u.pos + Vector2(0, -10), {"life": 0.45})
	A.fx("dust", u.pos, {"r": 10.0, "life": 0.5})
	A.shake = maxf(A.shake, 2.0)
	A.stats["sundered"] = int(A.stats.get("sundered", 0)) + 1
	A.guide.found(u, "sundered")
	var top: float = A.break_max(u)
	if u.broken_t <= 0.0 and top > 0.0:
		u.brk = minf(top - 0.01, u.brk + top * float(A.D["foes"]["armour"]["sunder_break"]))
	if not A.stats.has("sunder_seen"):
		A.stats["sunder_seen"] = true
		A.toast.emit("The %s's armour falls away." % A.D["enemies"][u.kind]["name"], PixelArt.GOLD)


## Hot metal burns the wearer each tick, through the armour.
func tick(u: Unit, dt: float) -> void:
	if not u.flags.has("heat_t") or u.dead:
		return
	u.flags["heat_t"] = float(u.flags["heat_t"]) - dt
	if u.wet_t > 0.0:
		u.flags["heat_t"] = 0.0  # quenched
	if u.flags["heat_t"] <= 0.0:
		u.flags.erase("heat_t")
		return
	if u.cooldown("heat_tick") <= 0.0:
		u.cd["heat_tick"] = 0.5
		u.hp -= float(A.D["foes"]["armour"]["heat_dps"]) * 0.5
		u.flash = 0.05
		if u.hp <= 0.0:
			A.kill(u)


## Hot plate: the wearer can't stand as firm.
func poise_down(u: Unit) -> int:
	return 1 if u.flags.has("heat_t") and int(layer(u).get("grade", 0)) >= 3 else 0
