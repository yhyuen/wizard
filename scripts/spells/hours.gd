extends RefCounted
## Hours, Saturn's inner ray: time run backwards (design/story/storyline-options.md, option A).
## Rewind forms where you aim, hangs for a moment, then flies back into your hand through
## everything between, dragging what it hits toward you. Its telegraph is the line it will fly,
## with chevrons pointing home. It comes back with you from loop 2.

var A  # the arena
var K  # the kit


func _init(arena, kit) -> void:
	A = arena
	K = kit


func reset() -> void:
	pass


func handles_proj(kind: String) -> bool:
	return kind == "rewind"


func detonate(z: Dictionary) -> bool:
	if z["kind"] != "rewind_form":
		return false
	_fly_home(z)
	return true


## A shard that reaches your hand is caught.
func update(_dt: float) -> void:
	if A.player == null or A.player.dead:
		return
	for p in A.projs.duplicate():
		if p["kind"] == "rewind" and p["pos"].distance_to(K.origin()) < 6.0:
			A.projs.erase(p)
			A.fx("ring", A.player.pos, {"color": PixelArt.HOURS, "r": 10.0, "life": 0.25})


## Where the shard forms: the aim point, but never so close that the flight home is nothing.
func form_point() -> Vector2:
	var s: Dictionary = Progression.spell("rewind")
	var P: Unit = A.player
	var d: Vector2 = K.aim - P.pos
	var reach_len := clampf(d.length(), float(s["min_range"]), Progression.reach("rewind"))
	return A.clamp_in(P.pos + K.aim_dir() * reach_len)


func rewind() -> bool:
	var s: Dictionary = Progression.spell("rewind")
	A.add_zone({"kind": "rewind_form", "pos": form_point(), "r": Progression.stat("rewind", "radius"),
		"delay": float(s["form"]), "dmg": Progression.stat("rewind", "damage")})
	return true


func _fly_home(z: Dictionary) -> void:
	var s: Dictionary = Progression.spell("rewind")
	var to: Vector2 = K.origin() - z["pos"]
	A.spawn_proj({"kind": "rewind", "team": 0, "pos": z["pos"], "vel": to.normalized() * float(s["speed"]),
		"r": z["r"], "life": 2.0, "dmg": z["dmg"], "color": PixelArt.HOURS, "home": A.player.id})
	A.fx("burst", z["pos"], {"color": PixelArt.HOURS, "r": 6.0, "life": 0.25})


## Pierces everything on the way home; each enemy is hit once and pulled toward you.
func on_proj_hit(p: Dictionary, u: Unit) -> bool:
	var s: Dictionary = Progression.spell("rewind")
	A.hit(u, p["dmg"], int(s["impact"]), p["vel"].normalized(), float(s["pull"]))
	A.fx("burst", p["pos"], {"color": PixelArt.HOURS, "r": 4.0, "life": 0.2})
	Progression.add_xp("rewind", float(s["xp_hit"]))
	return true


## A forming shard: its line home follows you, so the telegraph is always the real path.
func draw_field(c) -> void:
	for z in A.zones:
		if z["kind"] != "rewind_form":
			continue
		var k := clampf(z["t"] / z["delay"], 0.0, 1.0)
		_draw_path(c, z["pos"], K.origin(), z["r"], 0.5 + 0.4 * k)
		c.mark_circle(z["pos"], z["r"] * (0.4 + 0.6 * k), Color(PixelArt.HOURS, 0.5), true, -1.0, true)


func draw_preview(c, id: String, _ghost_old: int) -> bool:
	if id != "rewind":
		return false
	var at := form_point()
	var r := Progression.stat("rewind", "radius")
	_draw_path(c, at, K.origin(), r, 0.8)
	c.mark_arc(at, r, 0, TAU, 16, PixelArt.HOURS, 1.0, true)
	return true


## The flight home as a band its exact width, with chevrons pointing back at you.
func _draw_path(c, from: Vector2, to: Vector2, r: float, alpha: float) -> void:
	var d := to - from
	if d.length() < 1.0:
		return
	var dir := d.normalized()
	var n := dir.orthogonal() * r
	var col := Color(PixelArt.HOURS, alpha)
	c.mark_line(from + n, to + n, col, 1.0, true)
	c.mark_line(from - n, to - n, col, 1.0, true)
	c.mark_polygon(PackedVector2Array([from + n, to + n, to - n, from - n]), Color(PixelArt.HOURS, 0.1 * alpha))
	var steps := int(d.length() / 14.0)
	var phase := fmod(Time.get_ticks_msec() / 400.0, 1.0)
	for i in steps:
		var p := from + dir * (14.0 * (i + phase))
		c.mark_line(p - dir * 3.0 + n * 0.7, p, col, 1.0, true)
		c.mark_line(p - dir * 3.0 - n * 0.7, p, col, 1.0, true)
