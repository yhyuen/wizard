extends RefCounted
## Short 3D scenes in the fight view where time runs the wrong way (design/slice/content.md, R1
## and R2; tech-plan M4): the Fire on the College stairs, where a veiled figure rises from the
## flames, lifts you out and walks backwards into them; and the Mourner in Lantern Market, who
## weeps at you and backs away through a crowd that walks forwards. The arena plays one instead
## of a fight (arena.start("cutscene:fire")); nothing here touches the rules.
##
## A unit's pose is set through its flags: "pose" = [clip, time] and "face" = a direction, which
## the 3D view (scripts/view/view3d.gd) shows instead of what the sim would pick.

const Figure := preload("res://scripts/view/figure.gd")
const LENGTH := {"fire": 12.5, "mourner": 9.0}
const CAPTIONS := {
	"fire": [[0.0, "The College stairs are burning."], [1.6, "Something in the flames is rising."],
		[4.0, "A spell you don't know lifts you out."], [6.2, "A brass star turns at its wrist."],
		[7.4, "Then it walks backwards into the fire, and lies down."]],
	"mourner": [[0.0, "Lantern Market, noon."], [1.5, "Someone in a grey veil has stopped dead, looking at you."],
		[4.2, "They are weeping."], [5.6, "They back away, still facing you, never turning round."]],
}

var A  # the arena
var id := ""
var t := 0.0
var you: Unit
var walker: Unit
var crowd: Array = []
var embers: Array = []
var done := false
var O := Vector2.ZERO  # where the stage is: the scenes were laid out round (240, 150)


## `at` is where you lie when the scene starts (in the town, the College stairs).
func _init(arena, which: String, at := Vector2(240, 150)) -> void:
	A = arena
	id = which
	O = at - Vector2(240, 150)
	you = A.player
	walker = _figure("walker", O + Vector2(240, 100))
	if id == "fire":
		you.pos = O + Vector2(240, 150)
		for i in 15:
			var p := O + Vector2(150 + i * 13.0, 96 + sin(i * 1.7) * 9.0)
			embers.append(A.add_zone({"kind": "ember", "pos": p, "life": 1.0e9}))
		for i in 6:
			embers.append(A.add_zone({"kind": "ember", "pos": you.pos + Vector2(-26 + i * 10.0, 6 + (i % 2) * 5), "life": 1.0e9}))
	else:
		you.pos = O + Vector2(240, 200)
		walker.pos = O + Vector2(250, 120)
		for i in 9:
			var u := _figure("townsfolk" if i % 2 == 0 else "townsfolk2", O + Vector2(60 + fmod(i * 97.0, 360.0), 70 + fmod(i * 61.0, 150.0)))
			u.flags["goal"] = _wander_goal(i)
			crowd.append(u)


func _figure(kind: String, at: Vector2) -> Unit:
	var u := Unit.new()
	u.kind = kind
	u.team = 2  # not a fighter: the rules ignore it
	u.pos = at
	u.radius = 5.0
	u.max_hp = 1.0
	u.hp = 1.0
	u.hp_lag = 1.0
	u.speed = 22.0
	u.state = "move"
	return A._add(u)


func caption() -> String:
	var out := ""
	for c in CAPTIONS.get(id, []):
		if t >= float(c[0]):
			out = c[1]
	return out


## Advances the scene by `dt`. Returns false once it is over.
func update(dt: float) -> bool:
	t += dt
	if id == "fire":
		_fire()
	else:
		_mourner(dt)
	A.mouse = walker.pos
	for u in A.units:
		u.anim += dt
	if t >= LENGTH[id]:
		done = true
	return not done


func _down(k: float) -> Array:
	return ["down", clampf(k, 0.0, 1.0) * Figure.clip_len("down")]


func _fire() -> void:
	walker.flags["face"] = you.pos - walker.pos
	# You lie in the fire until the spell lifts you clear, then stand on the cold steps.
	if t < 4.0:
		you.flags["pose"] = _down(1.0)
	elif t < 5.2:
		var k := (t - 4.0) / 1.2
		you.pos = O + Vector2(240, lerpf(150, 196, smoothstep(0.0, 1.0, k)))
		you.flags["pose"] = ["air", k * Figure.clip_len("air")]
	else:
		you.flags["pose"] = ["staff_idle", fmod(t, Figure.clip_len("staff_idle"))]
	# It lies in the flames, rises (its fall, backwards), casts, then walks back in and lies down.
	if t < 1.6:
		walker.flags["pose"] = _down(1.0)
	elif t < 3.4:
		walker.flags["pose"] = _down(1.0 - (t - 1.6) / 1.8)
	elif t < 5.4:
		walker.pos = walker.pos.move_toward(O + Vector2(240, 118), 18.0 / 60.0)
		walker.flags["pose"] = ["cast", minf(1.0, (t - 3.4) / 1.4) * Figure.clip_len("cast") * 0.5]
		if t >= 4.0 and not walker.flags.has("lifted"):
			walker.flags["lifted"] = true
			A.fx("ring", you.pos, {"color": PixelArt.HOURS, "r": 18.0, "life": 1.0})
	elif t < 7.4:
		walker.flags["pose"] = ["stand", fmod(t, Figure.clip_len("stand"))]
		if t >= 6.2 and not walker.flags.has("glint"):
			walker.flags["glint"] = true
			A.fx("ring", walker.pos + Vector2(5, -6), {"color": PixelArt.GOLD, "r": 5.0, "life": 0.8})
	elif t < 9.6:
		# Backwards: facing you, its feet carry it away, the run played in reverse.
		walker.pos = walker.pos.move_toward(O + Vector2(240, 98), 10.0 / 60.0)
		walker.flags["pose"] = ["run", fposmod(-(t - 7.4) * 0.8, Figure.clip_len("run"))]
	else:
		walker.flags["pose"] = _down((t - 9.6) / 1.2)
	# The fire burns down at the end.
	if t > 10.8 and not embers.is_empty():
		var z: Dictionary = embers.pop_back()
		A.zones.erase(z)


func _mourner(dt: float) -> void:
	you.flags["pose"] = ["staff_idle", fmod(t, Figure.clip_len("staff_idle"))]
	walker.flags["face"] = you.pos - walker.pos
	if t < 1.5:
		walker.pos = walker.pos.move_toward(O + Vector2(240, 140), 20.0 * dt)
		walker.flags["pose"] = ["run", fmod(t * 0.6, Figure.clip_len("run"))]
	elif t < 5.6:
		# Stopped dead; the shoulders shake.
		var shake := 0.15 + 0.05 * sin(t * 9.0)
		walker.flags["pose"] = ["hit", shake * Figure.clip_len("hit")] if t > 4.2 else ["stand", fmod(t, Figure.clip_len("stand"))]
	else:
		# Backing away faster than anyone could walk backwards, the run played in reverse.
		walker.pos = walker.pos.move_toward(O + Vector2(250, 40), 34.0 * dt)
		walker.flags["pose"] = ["run", fposmod(-(t - 5.6) * 1.3, Figure.clip_len("run"))]
	# The crowd walks forwards, about its business, and never notices.
	for i in crowd.size():
		var u: Unit = crowd[i]
		var g: Vector2 = u.flags["goal"]
		if u.pos.distance_to(g) < 4.0:
			u.flags["goal"] = _wander_goal(i + int(t * 3.0))
			g = u.flags["goal"]
		u.pos = u.pos.move_toward(g, u.speed * dt)
		u.flags["face"] = g - u.pos
		u.flags["pose"] = ["run", fmod(t * 0.55 + i * 0.3, Figure.clip_len("run"))]


func _wander_goal(i: int) -> Vector2:
	return O + Vector2(40 + fmod(i * 131.0, 400.0), 60 + fmod(i * 73.0, 170.0))
