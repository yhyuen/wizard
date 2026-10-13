extends RefCounted
## A simple bot at the wizard's controls, for the fight test and tuning. It aims at the nearest
## enemy, steps out of telegraphs (blinking when one is about to land), keeps lodestones topped
## up with Pebble, and uses Pillar, Fling, the signature and Meteor when they fit.

var release: Array = []  # slots pressed last frame, released this frame
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
	var foes: Array = A.enemies()
	if foes.is_empty():
		out["move"] = (Vector2(240, 150) - P.pos) * 0.05
		return out
	foes.sort_custom(func(a, b): return a.pos.distance_to(P.pos) < b.pos.distance_to(P.pos))
	var near: Unit = foes[0]
	var r: Unit = A.rival()
	var focus: Unit = r if r and near.pos.distance_to(P.pos) > 50.0 else near
	out["aim"] = focus.pos + Vector2(0, -4)
	# Movement: keep some distance, then step out of any telegraph that covers us.
	var to: Vector2 = focus.pos - P.pos
	var mv := Vector2.ZERO
	if to.length() < 60.0:
		mv -= to.normalized()
	elif to.length() > 120.0:
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
	# Casting.
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


func _press(out: Dictionary, slot: String) -> void:
	out["pressed"][slot] = true
	out["held"][slot] = true
	release.append(slot)
