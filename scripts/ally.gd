extends RefCounted
## A companion fighting beside you (people spec §4.4; build item N-7.6.6). Not a unit: nothing
## targets them yet, and their figure is their person's (scripts/world/people.gd draws them where
## this puts them). Each step they keep near you, strike the nearest enemy close to you, and do
## their role: a Guard shoves the nearest enemy off you when you're Staggered or low, a Cutter cuts
## short one wind-up aimed near you. What they finish trains nothing of yours. Data in
## data/world/companions.json.

const CUT_STATES := ["windup", "spark", "lance", "smother", "ring_windup", "vent_windup"]

var A  # scripts/arena.gd
var who := ""
var rec: Dictionary
var pos := Vector2.ZERO
var face := Vector2.DOWN
var moving := false
var speed := 72.0
var strike_t := 0.5
var role_t := 0.0
var helps := 0  # roles done this fight (for the tests)


func _init(arena, id: String, r: Dictionary, at: Vector2, spd: float) -> void:
	A = arena
	who = id
	rec = r
	pos = at
	speed = spd


func tick(dt: float) -> void:
	var p = A.player
	moving = false
	if p == null or p.dead:
		return
	var es: Array = A.enemies()
	var tgt = null
	var best := 110.0
	for e in es:
		var dd: float = e.pos.distance_to(p.pos)
		if dd < best:
			best = dd
			tgt = e
	var st: Dictionary = rec.get("strike", {})
	var reach := float(st.get("reach", 18.0))
	var goal: Vector2 = p.pos + Vector2(-20, 12)
	if tgt != null:
		goal = tgt.pos + (pos - tgt.pos).normalized() * (reach * 0.8 + tgt.radius)
	var to := goal - pos
	if to.length() > 3.0:
		pos += to.normalized() * minf(to.length(), speed * dt)
		pos = A.clamp_in(pos, 5.0)
		face = to
		moving = true
	elif tgt != null:
		face = tgt.pos - pos
	strike_t -= dt
	if tgt != null and not st.is_empty() and strike_t <= 0.0 and pos.distance_to(tgt.pos) <= reach + tgt.radius + 2.0:
		strike_t = float(st["every"])
		_hit(tgt, float(st["dmg"]), int(st["impact"]), 30.0)
	role_t -= dt
	if role_t > 0.0:
		return
	match str(rec["role"]):
		"cutter":
			for e in es:
				if e.state in CUT_STATES and e.pos.distance_to(p.pos) < 140.0:
					A.ai.interrupt(e)
					_hit(e, 2.0, 3, 20.0)
					role_t = float(rec["cut_every"])
					helps += 1
					A.toast.emit("%s cuts in." % _name(), PixelArt.GOLD)
					break
		"guard":
			if p.hp < float(rec["guard_hp"]) * p.max_hp or p.reaction != "":
				var near = null
				var nd := 90.0
				for e in es:
					if e.pos.distance_to(p.pos) < nd:
						nd = e.pos.distance_to(p.pos)
						near = e
				if near != null:
					pos = p.pos.lerp(near.pos, 0.5)
					_hit(near, 3.0, 3, 160.0, (near.pos - p.pos).normalized())
					role_t = float(rec["guard_every"])
					helps += 1
					A.toast.emit("%s steps in." % _name(), PixelArt.GOLD)


## A blow of theirs: it counts as theirs, so a kill trains nothing of yours.
func _hit(e, dmg: float, impact: int, knock: float, dir := Vector2.ZERO) -> void:
	var kills: int = A.stats["kills"]
	A.hit(e, dmg, impact, dir if dir != Vector2.ZERO else (e.pos - pos).normalized(), knock)
	A.stats["kills"] = kills


func _name() -> String:
	return str(A.town.people.get_person(who).name) if A.town != null and A.town.people.get_person(who) != null else who.capitalize()
