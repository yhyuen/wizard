extends "res://scripts/world/town_mesh.gd"
## The ruin kit (design/ruins/tech-plan.md §2): what the Orrery's blast left, built from a map's
## data into the same chunks, materials and palette as the town (town_mesh.gd), so a new layer
## adds no new shaders. A layer's own colours come in through the palette (data/world/maps.json).
##
## | Data key | Builds |
## | walls (ruin kit), ruin_walls (any kit) | broken walls: jagged tops, fallen blocks at the foot |
## | rubble [x, y, w, h, height] | solid heaps of faceted stone |
## | circles of kind pillar, pillar_broken | standing and broken columns |
## | circles of kind observatory_ruin | the Observatory's broken stump |
## | pits [x, y, w, h] | collapsed floor: a hole in the ground, dark below |
## | stairwells [x, y, w, h] | stairs going down into the dark (the way into the ruin) |
## | cracks [x, y, w, h, sphere] | thin glowing seams; each its own mesh, so R2 can light one before a burst |
## | doors {id: {rect, state}} | sealed, shut or burnt doors; open ones are hidden |
## | tents [x, y, rotation, cloth, open] | the camp's tents and open shelters |
## | dressing [kind, x, y, rotation] | cot, tool_crate, barrier, targets, fissure, scorch, shrine, stair_up, clock, bones |
##
## No ceilings: the steep close camera and the line-of-sight cutaway read as indoors.

const SPHERE_COLS := {"mars": "ember", "luna": "window", "mercury": "brass", "jupiter": "brass", "saturn": "paper"}

var crack_mis: Array = []  # MeshInstance3D per map crack, in map order
var crack_mat: ShaderMaterial  # a crack at rest: a dim seam of its Sphere's colour
var crack_hot: ShaderMaterial  # a crack about to burst (arena.crack_glow)
var door_nodes := {}  # door id -> Node3D, hidden while the door is open


func _kit_ruin() -> void:
	crack_mat = glow_far.duplicate()
	crack_mat.set_shader_parameter("glow", 0.7)
	crack_hot = glow_far.duplicate()
	crack_hot.set_shader_parameter("glow", 3.2)
	if map.kit == "ruin":
		for w in map.d.get("walls", []):
			_broken_wall(Rect2(w[0], w[1], w[2], w[3]), float(w[4]))
	for w in map.d.get("ruin_walls", []):
		_broken_wall(Rect2(w[0], w[1], w[2], w[3]), float(w[4]))
	for r in map.d.get("rubble", []):
		_rubble(Rect2(r[0], r[1], r[2], r[3]), float(r[4]))
	for cr in map.d.get("circles", []):
		var at := Vector2(cr[0], cr[1])
		match str(cr[4]):
			"pillar":
				_pillar(at, float(cr[2]), float(cr[3]), false)
			"pillar_broken":
				_pillar(at, float(cr[2]), float(cr[3]), true)
			"observatory_ruin":
				_observatory_ruin(at, float(cr[2]), float(cr[3]))
			"bell":
				_bell(at, float(cr[2]), float(cr[3]))
	for pit: Rect2 in map.pits:
		_pit(pit)
	for st in map.d.get("stairwells", []):
		_stairwell(Rect2(st[0], st[1], st[2], st[3]))
	for i in map.cracks.size():
		_crack(map.cracks[i])
	for did in map.doors:
		_ruin_door(did, map.doors[did])
	for t in map.d.get("tents", []):
		_tent(t)
	for dr in map.d.get("dressing", []):
		_dressing(str(dr[0]), Vector2(dr[1], dr[2]), float(dr[3]) if dr.size() > 3 else 0.0)


# --- walls, rubble, columns -------------------------------------------------------

## A broken wall: segments of uneven height, a tilted block left on some, and fallen stones at
## its foot.
func _broken_wall(r: Rect2, h_px: float) -> void:
	var h: float = h_px * view.S
	var horiz := r.size.x >= r.size.y
	var length := r.size.x if horiz else r.size.y
	var n := maxi(1, int(length / 22.0))
	var seg := length / n
	for k in n:
		var hh := h * (rng.randf_range(0.6, 1.0) if rng.randf() < 0.75 else rng.randf_range(0.25, 0.5))
		var sr := Rect2(r.position + Vector2(seg * k, 0), Vector2(seg + 0.5, r.size.y)) if horiz \
			else Rect2(r.position + Vector2(0, seg * k), Vector2(r.size.x, seg + 0.5))
		_rect_box(sr, hh, c("wall_stone").lerp(c("stone"), rng.randf() * 0.25))
		if rng.randf() < 0.45:
			var cap := Vector3(seg * view.S * 0.7, 0.35, r.size.y * view.S * 0.9) if horiz else Vector3(r.size.x * view.S * 0.9, 0.35, seg * view.S * 0.7)
			_box(cap, view.to_world(sr.get_center(), hh + 0.1), c("wall_stone"), rng.randf_range(-18, 18))
	for k in int(length / 50.0):
		var t := rng.randf()
		var side := 1.0 if rng.randf() < 0.6 else -1.0
		var p := Vector2(r.position.x + length * t, (r.end.y + 6.0) if side > 0 else (r.position.y - 6.0)) if horiz \
			else Vector2((r.end.x + 6.0) if side > 0 else (r.position.x - 6.0), r.position.y + length * t)
		var s := rng.randf_range(0.25, 0.5)
		_add(_rock_mesh(s), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), view.to_world(p, s * 0.2)), c("rock").lerp(c("wall_stone"), rng.randf()))


## A heap of fallen stone: a dark base, faceted stones piled higher toward its middle, and some
## squared blocks of masonry.
func _rubble(r: Rect2, h_px: float) -> void:
	var h: float = h_px * view.S
	_rect_box(r.grow(-2.0), h * 0.35, c("rock2"))
	var n := clampi(int(r.get_area() / 420.0), 4, 48)
	var big := clampf(minf(r.size.x, r.size.y) * view.S * 0.35, 0.4, 1.5)
	for i in n:
		var p := Vector2(rng.randf_range(r.position.x + 3, r.end.x - 3), rng.randf_range(r.position.y + 3, r.end.y - 3))
		var mid := 1.0 - maxf(absf(p.x - r.get_center().x) / (r.size.x * 0.5), absf(p.y - r.get_center().y) / (r.size.y * 0.5))
		var s := rng.randf_range(0.5, 1.0) * big
		var axis := Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized()
		_add(_rock_mesh(s), Transform3D(Basis(axis, rng.randf() * TAU), view.to_world(p, h * (0.3 + 0.6 * mid) - s * 0.2)),
			c("rock").lerp(c("rock2"), rng.randf()))
	for i in maxi(1, n / 5):
		var p := Vector2(rng.randf_range(r.position.x + 6, r.end.x - 6), rng.randf_range(r.position.y + 6, r.end.y - 6))
		_box(Vector3(rng.randf_range(0.6, 1.2), 0.45, rng.randf_range(0.4, 0.7)), view.to_world(p, h * rng.randf_range(0.3, 0.8)),
			c("wall_stone"), rng.randf() * 180.0)


## A column: base, shaft and capital; a broken one ends in a jagged stump, its drums on the floor.
func _pillar(at: Vector2, r_px: float, h_px: float, broken: bool) -> void:
	var p: Vector3 = view.to_world(at)
	var r: float = r_px * view.S
	var h: float = h_px * view.S
	_box(Vector3(r * 2.6, 0.3, r * 2.6), p + Vector3(0, 0.15, 0), c("stone"))
	_add(_cyl(r * 0.85, r, h, 8), Transform3D(Basis(), p + Vector3(0, 0.3 + h * 0.5, 0)), c("wall_stone"))
	if not broken:
		_box(Vector3(r * 2.4, 0.35, r * 2.4), p + Vector3(0, 0.3 + h + 0.17, 0), c("stone"))
		return
	for k in 2:
		_box(Vector3(r * 1.1, 0.4, r * 0.9), p + Vector3((k - 0.5) * r * 0.8, 0.3 + h + 0.1 + k * 0.12, 0), c("wall_stone"), rng.randf_range(-25, 25))
	for k in 2:
		var a := rng.randf() * TAU
		var q := p + Vector3(cos(a), 0, sin(a)) * (r * 2.5 + k * r * 2.2) + Vector3(0, r * 0.85, 0)
		_add(_cyl(r * 0.85, r * 0.85, r * 2.2, 8), Transform3D(Basis(Vector3.UP, a).rotated(Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)), PI / 2.0), q), c("wall_stone"))


## The College bell where it fell: a bronze bell on its side, its crown cracked, the clapper out.
func _bell(at: Vector2, r_px: float, h_px: float) -> void:
	var p: Vector3 = view.to_world(at)
	var r: float = r_px * view.S
	var lay := Basis(Vector3.FORWARD, PI / 2.0 + 0.12)
	_add(_cyl(r * 0.55, r * 1.05, r * 1.8, 10), Transform3D(lay, p + Vector3(0, r * 0.95, 0)), c("brass").darkened(0.35))
	_add(_cyl(r * 1.1, r * 1.1, r * 0.18, 10), Transform3D(lay, p + Vector3(-r * 0.9, r * 1.0, 0)), c("brass").darkened(0.2))
	_box(Vector3(r * 0.5, r * 0.4, r * 0.5), p + Vector3(r * 1.05, r * 0.95, 0), c("iron"))
	_box(Vector3(r * 0.25, r * 0.25, r * 1.6), p + Vector3(-r * 1.6, r * 0.12, r * 0.4), c("iron"), 30.0)


## The Observatory after the blast: a ring of broken wall round a heap of its own dome.
func _observatory_ruin(at: Vector2, r_px: float, h_px: float) -> void:
	var p: Vector3 = view.to_world(at)
	var r: float = r_px * view.S
	var h: float = h_px * view.S
	var n := 16
	for k in n:
		if k in [3, 4, 11]:
			continue  # gaps blown through it
		var a := k * TAU / n
		var hh := h * rng.randf_range(0.35, 1.0)
		var q := p + Vector3(cos(a), 0, sin(a)) * r * 0.95
		_box(Vector3(r * TAU / n * 1.05, hh, 0.9), q + Vector3(0, hh * 0.5, 0), c("wall_stone").lerp(c("char"), rng.randf() * 0.4), -rad_to_deg(a) + 90.0)
	for i in 14:
		var a := rng.randf() * TAU
		var q := p + Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.0, 0.8)
		var s := rng.randf_range(0.6, 1.4)
		_add(_rock_mesh(s), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q + Vector3(0, s * 0.4, 0)), c("dome").lerp(c("rock2"), rng.randf()))


# --- holes in the floor ---------------------------------------------------------------

## The sides and bottom of a hole cut in the ground (the view leaves the ground out there).
func _hole(r: Rect2, depth: float, col: Color) -> void:
	var a: Vector3 = view.to_world(r.position)
	var b: Vector3 = view.to_world(r.end)
	var w := b.x - a.x
	var d := b.z - a.z
	var cx := (a.x + b.x) * 0.5
	var cz := (a.z + b.z) * 0.5
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(w, d)
	_add(floor_m, Transform3D(Basis(), Vector3(cx, -depth, cz)), col.darkened(0.5))
	var ns := PlaneMesh.new()
	ns.size = Vector2(w, depth)
	_add(ns, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(cx, -depth * 0.5, a.z)), col)
	_add(ns, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(cx, -depth * 0.5, b.z)), col.darkened(0.3))
	var ew := PlaneMesh.new()
	ew.size = Vector2(depth, d)
	_add(ew, Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3(a.x, -depth * 0.5, cz)), col.darkened(0.15))
	_add(ew, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(b.x, -depth * 0.5, cz)), col.darkened(0.15))


## Collapsed floor: a dark drop with broken edges.
func _pit(r: Rect2) -> void:
	_hole(r, 3.2, c("rock2").darkened(0.55))
	var edge := r.grow(4.0)
	for i in int((r.size.x + r.size.y) / 14.0):
		var t := rng.randf()
		var p: Vector2
		match rng.randi() % 4:
			0:
				p = Vector2(edge.position.x + edge.size.x * t, edge.position.y)
			1:
				p = Vector2(edge.position.x + edge.size.x * t, edge.end.y)
			2:
				p = Vector2(edge.position.x, edge.position.y + edge.size.y * t)
			_:
				p = Vector2(edge.end.x, edge.position.y + edge.size.y * t)
		var s := rng.randf_range(0.2, 0.45)
		_add(_rock_mesh(s), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), view.to_world(p, 0.0)), c("rock").lerp(c("rock2"), rng.randf()))


## A stairwell: a hole with steps going down, away from the camera (north), into the dark.
func _stairwell(r: Rect2) -> void:
	var depth := 3.0
	_hole(r, depth, c("rock2").darkened(0.5))
	var a: Vector3 = view.to_world(r.position)
	var b: Vector3 = view.to_world(r.end)
	var steps := 7
	var sd := (b.z - a.z) / steps
	for k in steps:
		var top := -0.38 * (k + 1)
		var z := b.z - (k + 0.5) * sd
		_box(Vector3(b.x - a.x - 0.05, depth + top, sd), Vector3((a.x + b.x) * 0.5, -depth + (depth + top) * 0.5, z),
			c("stone").darkened(0.15 + 0.08 * k))
	# kerb stones round the top
	for x in [a.x - 0.2, b.x + 0.2]:
		_box(Vector3(0.4, 0.5, b.z - a.z + 0.4), Vector3(x, 0.25, (a.z + b.z) * 0.5), c("wall_stone"))


# --- cracks and doors -----------------------------------------------------------------

## A crack in a wall: a jagged seam of its Sphere's colour, dim until something comes through.
func _crack(cr: Dictionary) -> void:
	var r: Rect2 = cr["rect"]
	var col := c(SPHERE_COLS.get(str(cr["sphere"]), "ember"))
	var horiz := r.size.x >= r.size.y
	var mi := _own(func(st):
		var a: Vector3 = view.to_world(r.position)
		var b: Vector3 = view.to_world(r.end)
		var length := (b.x - a.x) if horiz else (b.z - a.z)
		for k in 4:
			var t := (k + 0.5) / 4.0
			var off := (0.08 if k % 2 == 0 else -0.08)
			var pos := Vector3(lerpf(a.x, b.x, t) if horiz else (a.x + b.x) * 0.5 + off, 0.4 + k * 0.45, lerpf(a.z, b.z, t) if not horiz else (a.z + b.z) * 0.5 + off)
			var bm := BoxMesh.new()
			bm.size = Vector3(length * 0.32, 0.5, 0.12) if horiz else Vector3(0.12, 0.5, length * 0.32)
			var normal := Vector3.BACK if horiz else Vector3.RIGHT
			_add(bm, Transform3D(Basis(normal, deg_to_rad(28.0 if k % 2 == 0 else -28.0)), pos), col, false, st)
	, crack_mat, null, false)
	crack_mis.append(mi)


## A door in the ruin: sealed with a rune that glows, burnt, or just shut. Hidden while open.
func _ruin_door(did: String, door: Dictionary) -> void:
	var r: Rect2 = door["rect"]
	var node := Node3D.new()
	node.name = "door_" + did
	add_child(node)
	var a: Vector3 = view.to_world(r.position)
	var b: Vector3 = view.to_world(r.end)
	var centre := (a + b) * 0.5
	var horiz := r.size.x >= r.size.y
	var state: String = door["state"]
	# A burnt door is drawn whole (the slab, day 10 on) inside a charred frame that stays when it
	# stands burnt open (days 1-9).
	if state == "rubble":
		# a fall of stone that the Hours can lift back where it came from (the collapsed stair),
		# with the cult's chalk circle on its face
		_own(func(st):
			for i in 7:
				var p := Vector2(rng.randf_range(r.position.x + 6, r.end.x - 6), rng.randf_range(r.position.y + 4, r.end.y - 4))
				var sz := rng.randf_range(0.6, 1.1)
				var axis := Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized()
				_add(_rock_mesh(sz), Transform3D(Basis(axis, rng.randf() * TAU), view.to_world(p, 0.3 + 0.8 * (i % 3))), c("rock").lerp(c("rock2"), rng.randf()), false, st)
			_box(Vector3(b.x - a.x, 1.2, b.z - a.z), centre + Vector3(0, 0.6, 0), c("rock2"), 0.0, false, st)
		, solid_mat, node)
		_own(func(st):
			_add(_cyl(0.32, 0.32, 0.03, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), centre + Vector3(0, 1.3, (b.z - a.z) * 0.5 + 0.05)), c("paper"), true, st)
		, glow_far, node, false)
		door_nodes[did] = node
		return
	var slab := c("wall_stone").darkened(0.25)
	if state == "burnt":
		_own(func(st):
			for side in [-1.0, 1.0]:
				var off := Vector3((b.x - a.x) * 0.5 + 0.12, 0, 0) if horiz else Vector3(0, 0, (b.z - a.z) * 0.5 + 0.12)
				_box(Vector3(0.24 if horiz else b.x - a.x + 0.1, 3.4, b.z - a.z + 0.1 if horiz else 0.24), centre + off * side + Vector3(0, 1.7, 0), c("char"), 0.0, false, st)
			_box(Vector3(b.x - a.x + 0.4, 0.3, b.z - a.z + 0.4), centre + Vector3(0, 0.02, 0), c("char"), 0.0, false, st)
		, solid_mat, null)
	_own(func(st):
		_box(Vector3(b.x - a.x, 3.2, b.z - a.z), centre + Vector3(0, 1.6, 0), slab, 0.0, false, st)
		# a lintel over it
		_box(Vector3(b.x - a.x + (0.0 if horiz else 0.3), 0.4, b.z - a.z + (0.3 if horiz else 0.0)), centre + Vector3(0, 3.4, 0), c("stone"), 0.0, false, st)
	, solid_mat, node)
	if state == "sealed":
		# the dwarf rune: three strokes of brass light on the face toward the hall
		var face := Vector3(0, 0, 1) if horiz else Vector3(-1, 0, 0)
		var at := centre + face * ((b.z - a.z) * 0.5 + 0.03 if horiz else (b.x - a.x) * 0.5 + 0.03)
		_own(func(st):
			for k in 3:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.1, 1.1, 0.04) if horiz else Vector3(0.04, 1.1, 0.1)
				_add(bm, Transform3D(Basis(face, deg_to_rad([0.0, 35.0, -35.0][k])), at + Vector3(0, 1.7, 0)), c("brass"), true, st)
		, glow_far, node, false)
	door_nodes[did] = node


# --- the camp ---------------------------------------------------------------------------

## A tent: a ridge of canvas on the ground; an open shelter is a sloped sheet on four posts.
func _tent(t: Array) -> void:
	var at: Vector3 = view.to_world(Vector2(t[0], t[1]))
	var basis := Basis(Vector3.UP, deg_to_rad(float(t[2])))
	var cloth := c(str(t[3])) if pal.has(str(t[3])) else c("cloth2")
	var w: float = 44.0 * view.S
	var d: float = 36.0 * view.S
	if t.size() > 4 and bool(t[4]):
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var hh := 2.0 if sz < 0 else 1.4
				_box(Vector3(0.09, hh, 0.09), at + basis * Vector3(sx * w * 0.45, hh * 0.5, sz * d * 0.45), c("timber"))
		_box(Vector3(w, 0.05, d * 1.05), at + basis * Vector3(0, 1.75, 0), cloth, float(t[2]))
		_box(Vector3(w * 0.95, 1.8, 0.05), at + basis * Vector3(0, 0.95, -d * 0.47), cloth.darkened(0.2), float(t[2]))
		return
	var pm := PrismMesh.new()
	pm.size = Vector3(d, 1.8, w)
	_add(pm, Transform3D(basis * Basis(Vector3.UP, PI / 2.0), at + Vector3(0, 0.9, 0)), cloth)
	_box(Vector3(0.6, 1.1, 0.04), at + basis * Vector3(0, 0.55, d * 0.5 + 0.01), cloth.darkened(0.6), float(t[2]))


## Things to look at that don't block: the camp's and the ruin's small furniture.
func _dressing(kind: String, at2: Vector2, rot: float) -> void:
	var at: Vector3 = view.to_world(at2)
	var basis := Basis(Vector3.UP, deg_to_rad(rot))
	var put := func(size: Vector3, local: Vector3, col: Color, glow := false) -> void:
		_box(size, at + basis * local, col, rot, glow)
	match kind:
		"cot":
			put.call(Vector3(0.8, 0.3, 1.9), Vector3(0, 0.15, 0), c("timber"))
			put.call(Vector3(0.72, 0.12, 1.7), Vector3(0, 0.36, 0.05), c("cloth2").darkened(0.35))
			put.call(Vector3(0.5, 0.1, 0.3), Vector3(0, 0.44, -0.7), c("paper").darkened(0.2))
		"tool_crate":
			put.call(Vector3(1.0, 0.6, 0.7), Vector3(0, 0.3, 0), c("timber").lightened(0.15))
			for k in 2:
				put.call(Vector3(1.04, 0.07, 0.74), Vector3(0, 0.15 + k * 0.3, 0), c("iron"))
			for k in 3:
				put.call(Vector3(0.05, 0.7, 0.05), Vector3(-0.3 + k * 0.25, 0.75, 0.1 * (k - 1)), c("timber").darkened(0.2))
			put.call(Vector3(0.22, 0.22, 0.02), Vector3(0, 0.35, 0.36), c("brass"), true)  # the stamped rune
		"barrier":
			for sx in [-1.0, 1.0]:
				put.call(Vector3(0.1, 1.0, 0.5), Vector3(sx * 1.5, 0.5, 0), c("timber"))
			put.call(Vector3(3.4, 0.12, 0.12), Vector3(0, 0.95, 0), c("cloth"))
		"targets":
			for sx in [-1.0, 1.0]:
				put.call(Vector3(0.1, 1.6, 0.1), Vector3(sx * 0.8, 0.8, 0), c("timber"))
				put.call(Vector3(0.6, 0.8, 0.3), Vector3(sx * 0.8, 1.2, 0.05), Color("b8984a"))
		"fissure":
			put.call(Vector3(2.2, 0.05, 0.35), Vector3(0, 0.02, 0), c("char"))
			put.call(Vector3(1.8, 0.06, 0.07), Vector3(0, 0.04, 0), c("ember"), true)
		"scorch":
			_add(_cyl(1.3, 1.3, 0.03, 7), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, 0.015, 0)), c("char"))
		"shrine":
			_add(_cyl(0.3, 0.38, 0.35, 6), Transform3D(basis, at + Vector3(0, 0.175, 0)), Color("4a4652"))
			_add(_cyl(0.04, 0.05, 0.6, 5), Transform3D(basis, at + Vector3(0, 0.65, 0)), c("brass"))
			for k in 2:
				var tm := TorusMesh.new()
				tm.inner_radius = 0.3 - 0.07 * k
				tm.outer_radius = 0.34 - 0.07 * k
				tm.rings = 10
				tm.ring_segments = 3
				_add(tm, Transform3D(Basis(Vector3(1, 0, 0.4 * k).normalized(), 0.5 + k * 0.6), at + Vector3(0, 1.15, 0)), c("brass"))
			_box(Vector3(0.14, 0.14, 0.14), at + Vector3(0, 1.15, 0), Color("ffd36b"), 45.0, true)
		"stair_up":
			for k in 6:
				put.call(Vector3(3.2, 0.3 * (k + 1), 0.34), Vector3(0, 0.15 * (k + 1), -0.9 + k * 0.34), c("stone").darkened(0.05 * k))
		"clock":
			var face := _cyl(1.7, 1.7, 0.18, 12)
			_add(face, Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.35), at + Vector3(0, 1.4, 0)), c("paper").darkened(0.45))
			var rim := TorusMesh.new()
			rim.inner_radius = 1.6
			rim.outer_radius = 1.8
			rim.rings = 12
			rim.ring_segments = 3
			_add(rim, Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.35), at + Vector3(0, 1.4, 0)), c("brass").darkened(0.3))
			put.call(Vector3(0.08, 1.2, 0.05), Vector3(0.2, 1.7, 0.22), c("iron"))
		"bones":
			for k in 4:
				put.call(Vector3(0.35, 0.06, 0.06), Vector3(rng.randf_range(-0.4, 0.4), 0.03, rng.randf_range(-0.4, 0.4)), c("paper").darkened(0.3))
