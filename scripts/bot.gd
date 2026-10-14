extends RefCounted
## A simple bot at the wizard's controls, for the fight test and tuning. It aims at the nearest
## enemy and steps out of telegraphs (blinking when one is about to land). With Fire + Earth it
## keeps lodestones topped up with Pebble and uses Pillar, Fling, the signature and Meteor; with
## Storm + Water it soaks enemies with Splash and Undertow, then lights them up with Spark, Arc
## Lance, Storm Call, Maelstrom and Conductor.

var release: Array = []  # slots pressed last frame, released this frame
var holds := {}  # slot -> frames left to keep it held (Arc Lance charges while held)
var t := 0.0
var pebble_t := 0.0
var last_pebbles := 0


func intent(A) -> Dictionary:
	t += 1.0 / 60.0
	pebble_t -= 1.0 / 60.0
	var P: Unit = A.player
	var out := {"move": Vector2.ZERO, "aim": P.pos + Vector2(40, 0), "held": {}, "pressed": {}, "released": {}}
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
		out["move"] = (Vector2(240, 142) - P.pos) * 0.05
		return out
	foes.sort_custom(func(a, b): return a.pos.distance_to(P.pos) < b.pos.distance_to(P.pos))
	var near: Unit = foes[0]
	var r: Unit = A.rival()
	var focus: Unit = r if r and near.pos.distance_to(P.pos) > 50.0 else near
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
	mv += (Vector2(240, 140) - P.pos) * 0.004
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
			"line":
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
	if not holds.is_empty():
		return out
	# Casting.
	if Progression.loadout().has("storm"):
		_storm_water(A, out, foes, near, focus, r)
		return out
	var stones: int = A.stone_count()
	var pebbles: int = A.stats["by_spell"].get("pebble", 0)
	if pebbles > last_pebbles:
		last_pebbles = pebbles
		pebble_t = 0.8
	if stones < Progression.stone_cap() and pebble_t <= 0.0:
		out["held"]["bolt2"] = true
	else:
		out["held"]["bolt1"] = true
	var kit = A.kit
	var marked := foes.filter(func(u): return u.pips > 0).size()
	var clustered := foes.filter(func(u): return u.pos.distance_to(focus.pos) < 25.0).size()
	var want := "avalanche" if r and stones >= 3 else "pyroclasm"
	if P.cooldown("pillar") <= 0.0 and not Progression.knows("meteor") and A.orbit_stones().size() > 0 and near.pos.distance_to(P.pos) < 45.0:
		out["aim"] = P.pos
		_press(out, "control1")
	elif P.cooldown("pillar") <= 0.0 and (clustered >= 2 or focus == r):
		_press(out, "control1")
	elif P.cooldown("fling") <= 0.0 and A.orbit_stones().size() >= 2 and near.pos.distance_to(P.pos) < 80.0:
		out["aim"] = near.pos
		_press(out, "control2")
	elif Progression.knows("meteor") and P.cooldown("meteor") <= 0.0 and stones >= 2 and (clustered >= 2 or focus == r):
		_press(out, "magick")
	elif kit.signature != want:
		out["pressed"]["swap_signature"] = true
	elif P.cooldown(want) <= 0.0 and (want == "avalanche" or marked >= 2):
		_press(out, "signature")
	return out


func _storm_water(A, out: Dictionary, foes: Array, near: Unit, focus: Unit, r: Unit) -> void:
	var P: Unit = A.player
	var kit = A.kit
	var storm := 0 if kit.slot_spell("bolt1") == "spark" else 1
	var water := 1 - storm
	var dry_near := near.wet_t <= 0.0 and near.pos.distance_to(P.pos) < 50.0
	out["held"]["bolt%d" % (water + 1 if dry_near else storm + 1)] = true
	var wet := foes.filter(func(u): return u.wet_t > 0.0).size()
	var clustered := foes.filter(func(u): return u.pos.distance_to(focus.pos) < 30.0).size()
	var want := "storm_call" if r and focus == r else "maelstrom"
	if P.cooldown("undertow") <= 0.0 and near.pos.distance_to(P.pos) < 70.0:
		out["aim"] = near.pos
		_press(out, "control%d" % (water + 1))
	elif P.cooldown("arc_lance") <= 0.0 and focus.pos.distance_to(P.pos) < Progression.stat("arc_lance", "range"):
		_hold(out, "control%d" % (storm + 1), int(Progression.stat("arc_lance", "charge") * 60.0) + 2)
	elif Progression.knows("conductor") and P.cooldown("conductor") <= 0.0 and (wet >= 2 or (r and r.wet_t > 0.0)):
		_press(out, "magick")
	elif P.cooldown(want) <= 0.0 and (want == "storm_call" or clustered >= 2):
		if kit.signature != want:
			out["pressed"]["swap_signature"] = true
		else:
			_press(out, "signature")


func _hold(out: Dictionary, slot: String, frames: int) -> void:
	out["pressed"][slot] = true
	out["held"][slot] = true
	holds[slot] = frames


func _press(out: Dictionary, slot: String) -> void:
	out["pressed"][slot] = true
	out["held"][slot] = true
	release.append(slot)
