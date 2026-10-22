extends RefCounted
## A simple bot at the wizard's controls, for the fight test and tuning. It aims at the nearest
## enemy and steps out of telegraphs (blinking when one is about to land, which also cancels a
## wind-up), raises the Ward against shots, and strikes with the staff when something is close.
## It casts one spell at a time, committed like smart cast, and waits for Aether rather than
## Overdraw. With Fire + Earth it keeps lodestones topped up with Pebble and uses Pillar, Fling and
## the signature; with Storm + Water it soaks enemies with Splash and Undertow, then lights them up
## with Spark, Arc Lance, Storm Call and Maelstrom. With Rewind in the book it forms the shard
## behind its target so the shard flies home through it.

var release: Array = []  # slots pressed last frame, released this frame
var holds := {}  # slot -> frames left to keep it held (Arc Lance charges while held)
var t := 0.0
var kit  # the wizard's kit, so presses can wait for Aether instead of Overdrawing


var home := Vector2.INF  # in the open world, where the fight started: the bot stays near it


## The point the bot drifts back to between dodges: the old arena's middle, or where it stood when
## the fight in the town began.
func _home(A) -> Vector2:
	if A.world == null:
		return Vector2(240, 140)
	if home == Vector2.INF:
		home = A.player.pos
	return home


func intent(A) -> Dictionary:
	t += 1.0 / 60.0
	var P: Unit = A.player
	kit = A.kit
	var out := {"move": Vector2.ZERO, "aim": P.pos + Vector2(40, 0), "held": {}, "pressed": {}, "released": {}, "smart": true}
	for s in release:
		out["released"][s] = true
	release.clear()
	for s in holds.keys():
		holds[s] -= 1
		if holds[s] <= 0:
			holds.erase(s)
			out["released"][s] = true
		else:
			out["held"][s] = true
	var foes: Array = A.enemies()
	if foes.is_empty():
		if A.world == null:
			out["move"] = (Vector2(240, 142) - P.pos) * 0.05  # the old arena's middle
		return out
	foes.sort_custom(func(a, b): return a.pos.distance_to(P.pos) < b.pos.distance_to(P.pos))
	var near: Unit = foes[0]
	# The Ward: raise it toward a shot about to land, if nothing is being wound up.
	if kit.wind.is_empty() and kit.aether > 20.0:
		for p in A.projs:
			if p["team"] == 1 and p["pos"].distance_to(P.pos) < 34.0 and (P.pos - p["pos"]).dot(p["vel"]) > 0.0:
				holds["ward"] = 12
				out["held"]["ward"] = true
				out["aim"] = p["pos"]
				return out
		# ...and toward a fire ring about to cross us outside its gap.
		for z in A.zones:
			if z["kind"] == "ring" and z["t"] >= float(z["wait"]):
				var to_r: Vector2 = P.pos - z["pos"]
				var gap_off := absf(angle_difference(to_r.angle(), float(z["gap_a"]))) > float(z["gap"]) * 0.5
				if gap_off and to_r.length() - float(z.get("r", z["r0"])) < 16.0 and to_r.length() > float(z.get("r", z["r0"])):
					holds["ward"] = 10
					out["held"]["ward"] = true
					out["aim"] = z["pos"]
					return out
	var r: Unit = A.rival()
	# A guardian (the Kiln Warden) is the focus unless something is in our face.
	var boss: Unit = null
	for u in foes:
		if u.flags.get("guardian", false) or A.D["enemies"][u.kind].get("guardian", false):
			boss = u
	if boss and r == null:
		r = boss
	var focus: Unit = r if r and near.pos.distance_to(P.pos) > 30.0 else near
	out["aim"] = focus.pos + Vector2(0, -4)
	# Movement: keep some distance, then step out of any telegraph that covers us.
	var to: Vector2 = focus.pos - P.pos
	var mv := Vector2.ZERO
	# Spark and Splash are short, so the Storm + Water bot fights closer.
	var short := Progression.loadout().has("storm")
	if to.length() < (35.0 if short else 60.0):
		mv -= to.normalized()
	elif to.length() > (65.0 if short else 120.0):
		mv += to.normalized() * 0.6
	mv += to.orthogonal().normalized() * 0.5 * (1.0 if int(t / 3.0) % 2 == 0 else -1.0)
	mv += (_home(A) - P.pos) * 0.004
	var danger := false
	for z in A.zones:
		var c := Vector2.ZERO
		var hit := false
		match z["kind"]:
			"slash":
				c = z["pos"]
				hit = P.pos.distance_to(c) < z["reach"] + 8.0
			"storm":
				c = z["pos"]
				hit = P.pos.distance_to(c) < z["r"] + 6.0
			"lance":
				c = Geometry2D.get_closest_point_to_segment(P.pos, z["a"], z["b"])
				hit = P.pos.distance_to(c) < z["w"] + 6.0
			"line", "rline":
				if not z.get("visual", false):
					c = Geometry2D.get_closest_point_to_segment(P.pos, z["a"], z["b"])
					hit = P.pos.distance_to(c) < 8.0
		if hit:
			var away: Vector2 = P.pos - c
			mv = away.normalized() * 2.0 if away.length() > 0.5 else Vector2.UP * 2.0
			if z.has("delay") and z["delay"] - z["t"] < 0.18:
				danger = true
	out["move"] = mv
	if danger:
		out["pressed"]["blink"] = true
	if not holds.is_empty() or not kit.wind.is_empty() or kit.recover_t > 0.0:
		return out
	# Casting. Rewind (Hours) forms behind the target, so it flies home through it.
	var rw: String = kit.slot_of("rewind")
	if _ready(rw) and to.length() < 110.0:
		out["aim"] = focus.pos + to.normalized() * 30.0
		_press(out, rw)
		return out
	if Progression.loadout().has("storm"):
		_storm_water(A, out, foes, near, focus, r)
	else:
		_fire_earth(A, out, foes, near, focus, r)
	# Nothing to cast: the staff, if something is close enough.
	if out["pressed"].is_empty() and near.pos.distance_to(P.pos) < float(A.D["staff"]["reach"]) + near.radius:
		out["aim"] = near.pos
		out["pressed"]["staff"] = true
	return out


func _fire_earth(A, out: Dictionary, foes: Array, near: Unit, focus: Unit, r: Unit) -> void:
	var P: Unit = A.player
	var stones: int = A.stone_count()
	var marked := foes.filter(func(u): return u.pips > 0).size()
	var clustered := foes.filter(func(u): return u.pos.distance_to(focus.pos) < 25.0).size()
	var want := "avalanche" if r and stones >= 3 else "pyroclasm"
	if _ready(kit.slot_of("pillar")) and A.orbit_stones().size() > 0 and near.pos.distance_to(P.pos) < 45.0:
		out["aim"] = P.pos
		_press(out, kit.slot_of("pillar"))
	elif _ready(kit.slot_of("pillar")) and (clustered >= 2 or focus == r):
		_press(out, kit.slot_of("pillar"))
	elif _ready(kit.slot_of("fling")) and A.orbit_stones().size() >= 2 and near.pos.distance_to(P.pos) < 80.0:
		out["aim"] = near.pos
		_press(out, kit.slot_of("fling"))
	elif _ready(kit.slot_of(want)) and (want == "avalanche" or marked >= 2 or focus == r):
		_press(out, kit.slot_of(want))
	elif _ready(kit.slot_of("pebble")):
		_press(out, kit.slot_of("pebble"))
	elif _ready(kit.slot_of("ember_bolt")):
		_press(out, kit.slot_of("ember_bolt"))


func _storm_water(A, out: Dictionary, foes: Array, near: Unit, focus: Unit, r: Unit) -> void:
	var P: Unit = A.player
	var dry_near := near.wet_t <= 0.0 and near.pos.distance_to(P.pos) < 50.0
	var clustered := foes.filter(func(u): return u.pos.distance_to(focus.pos) < 30.0).size()
	var want := "storm_call" if r and focus == r else "maelstrom"
	if _ready(kit.slot_of("undertow")) and near.pos.distance_to(P.pos) < 70.0:
		out["aim"] = near.pos
		_press(out, kit.slot_of("undertow"))
	elif _ready(kit.slot_of("arc_lance")) and focus.pos.distance_to(P.pos) < Progression.stat("arc_lance", "range"):
		_hold(out, kit.slot_of("arc_lance"), int(Progression.stat("arc_lance", "charge") * 60.0) + 2)
	elif _ready(kit.slot_of(want)) and (want == "storm_call" or clustered >= 2):
		_press(out, kit.slot_of(want))
	elif _ready(kit.slot_of("splash")) and dry_near:
		_press(out, kit.slot_of("splash"))
	elif _ready(kit.slot_of("spark")):
		_press(out, kit.slot_of("spark"))


## In the book and off cooldown. The bot picks the first spell that is ready and then waits for its
## Aether (_press) rather than spending it on whatever is cheapest, and never Overdraws.
func _ready(slot: String) -> bool:
	return slot != "" and kit.slot_spell(slot) != "" and kit.A.player.cooldown(kit.slot_spell(slot)) <= 0.0


func _affords(slot: String) -> bool:
	if slot == "":
		return false
	var id: String = kit.slot_spell(slot)
	return id != "" and kit.aether >= kit.aether_cost(id)


func _hold(out: Dictionary, slot: String, frames: int) -> void:
	if not _affords(slot):
		return
	out["pressed"][slot] = true
	out["held"][slot] = true
	holds[slot] = frames


func _press(out: Dictionary, slot: String) -> void:
	if not _affords(slot):
		return
	out["pressed"][slot] = true
	out["held"][slot] = true
	release.append(slot)
