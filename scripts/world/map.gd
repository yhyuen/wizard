extends RefCounted
## One walkable map: the camp (data/world/map.json; design/open-world/world.md) or a layer of the
## ruin (data/ruins/<layer>/map.json; design/ruins/tech-plan.md §1–2). Answers the questions the
## sim and the people ask about it: where a circle of radius r can stand (collide), whether a shot
## hits a wall (blocks_shot), where water is, which place a point is in, and how to walk from one
## point to another along the streets (path).
##
## Solids are axis-aligned rects (houses, walls, cliffs, stalls, tents, rubble, cracks, closed
## doors, the walls of the buildings you can enter) and circles (the well, pillars). They are
## sorted into a grid of CELL-pixel cells so each query only looks at what is near. Pits stop
## walkers but not shots. Props that move (crates and barrels) are not here: the world adds them
## through `movers`. `exits` are rects that take you to another map.

const PATH := "res://data/world/map.json"
const CELL := 96.0
const WALL := 10.0  # thickness of an enterable building's walls

var id := "camp"
var kit := "town"  # which builders draw it: "town" (the camp) or "ruin"
var d: Dictionary
var bounds := Rect2()
var rects: Array = []  # [Rect2, kind]
var circles: Array = []  # [Vector2, r, kind]
var water: Array = []  # Rect2
var water_all: Array = []  # [Rect2, flag, deep]: every water rect; while its flag is set it's drained (a sluice)
var deep: Array = []  # Rect2: water too deep to wade (the mill pond), a wall to walkers until drained
var river := ""  # the season's water (N-4.5.3): "high" (rivers too deep to wade but on bridges), "frozen" (no water is deep: ice)
var rivers: Array = []  # indices into water_all of this map's rivers (data/world/seasons.json)
var bridges: Array = []  # Rect2
var doors := {}  # id -> {"rect": Rect2, "open": bool, "state": String}
var pits: Array = []  # Rect2: collapsed floor, not walkable, open to shots
var pits_all: Array = []  # every pit as the map was drawn (a fallen structure can bridge one for the life)
var cracks: Array = []  # {"rect", "sphere", "id", "foot"}: glowing seams that embers burst from; foot is where they step out
var exits := {}  # id -> {"rect": Rect2, "to": map id, "at": spot id there}
var buildings := {}  # id -> {"rect", "door", "walls": [Rect2], "height", ...}
var places := {}  # id -> {"name", "district", "rect" or "circle"}
var spots := {}  # id -> Vector2
var items := {}  # id -> {"name", "at": Vector2, "verb", "reach"}
var nodes := {}  # nav node id -> Vector2
var adj := {}  # nav node id -> [ids]
var _grid := {}  # Vector2i -> {"r": [rect indices], "c": [circle indices]}
## Moving solids the world owns (crates, barrels): func() -> Array of [Vector2, r].
var movers: Callable


func _init(path := PATH, map_id := "camp", map_kit := "town") -> void:
	id = map_id
	kit = map_kit
	d = JSON.parse_string(FileAccess.get_file_as_string(path))
	var b: Array = d["bounds"]
	bounds = Rect2(b[0], b[1], b[2], b[3])
	for r in d.get("cliffs", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "cliff")
	for r in d.get("walls", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "wall")
	for r in d.get("blocks", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "block")
	for r in d.get("ruin_walls", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "wall")
	for s in d.get("stalls", []):
		var horiz: bool = absf(fmod(float(s[2]), 180.0)) < 45.0
		var size := Vector2(40, 18) if horiz else Vector2(18, 40)
		_rect(Rect2(Vector2(s[0], s[1]) - size * 0.5, size), "stall")
	for t in d.get("tents", []):
		if not (t.size() > 4 and bool(t[4])):  # an open shelter: walk in under the canvas
			_rect(tent_rect(t), "tent")
	for r in d.get("rubble", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "rubble")
	for c in d.get("cracks", []):
		var cr := Rect2(c[0], c[1], c[2], c[3])
		cracks.append({"rect": cr, "sphere": str(c[4]) if c.size() > 4 else "mars", "id": str(c[5]) if c.size() > 5 else "crack_%d" % cracks.size()})
		_rect(cr, "crack")
	for r in d.get("pits", []):
		pits.append(Rect2(r[0], r[1], r[2], r[3]))
	pits_all = pits.duplicate()
	for bid in d.get("buildings", {}):
		var bd: Dictionary = d["buildings"][bid].duplicate(true)
		var rr: Array = bd["rect"]
		bd["rect"] = Rect2(rr[0], rr[1], rr[2], rr[3])
		bd["walls"] = _building_walls(bd["rect"], bd["door"])
		for w in bd["walls"]:
			_rect(w, "building")
		buildings[bid] = bd
	for c in d.get("circles", []):
		circles.append([Vector2(c[0], c[1]), float(c[2]), str(c[4])])
		_index_circle(circles.size() - 1)
	for w in d.get("water", []):
		water_all.append([Rect2(w[0], w[1], w[2], w[3]), str(w[4]) if w.size() > 4 else "", w.size() > 5 and str(w[5]) == "deep"])
	water = water_all.map(func(w): return w[0])
	deep = water_all.filter(func(w): return w[2]).map(func(w): return w[0])
	for w in d.get("bridges", []):
		bridges.append(Rect2(w[0], w[1], w[2], w[3]))
	for did in d.get("doors", {}):
		var dd = d["doors"][did]
		var r: Array = dd["rect"] if dd is Dictionary else dd
		var state: String = str(dd.get("state", "shut")) if dd is Dictionary else "shut"
		doors[did] = {"rect": Rect2(r[0], r[1], r[2], r[3]), "open": state == "open", "state": state,
			"open_days": dd.get("open_days", []) if dd is Dictionary else []}
		if dd is Dictionary:
			# a gate (N-7.1.2): its prop, its winch, or the glassworks' lens opens it
			for k in ["gate", "winch", "grade", "lens"]:
				if dd.has(k):
					doors[did][k] = dd[k]
	for e in d.get("exits", []):
		var r: Array = e["rect"]
		exits[str(e["id"])] = {"rect": Rect2(r[0], r[1], r[2], r[3]), "to": str(e["to"]), "at": str(e["at"]),
			"opened_by": str(e.get("opened_by", ""))}
	for pid in d.get("places", {}):
		places[pid] = d["places"][pid]
	for sid in d.get("spots", {}):
		var p: Array = d["spots"][sid]
		spots[sid] = Vector2(p[0], p[1])
	for iid in d.get("items", {}):
		var it: Dictionary = d["items"][iid].duplicate()
		it["at"] = Vector2(it["at"][0], it["at"][1])
		items[iid] = it
	# The street graph is optional: a small ruin room is crossed in straight lines.
	var nav: Dictionary = d.get("nav", {"nodes": {}, "edges": []})
	for nid in nav["nodes"]:
		var p: Array = nav["nodes"][nid]
		nodes[nid] = Vector2(p[0], p[1])
		adj[nid] = []
	for e in nav["edges"]:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	for cr in cracks:
		cr["foot"] = _foot(cr["rect"])


## Where something stepping out of a crack in a wall stands: in front of it, on the open side.
func _foot(r: Rect2) -> Vector2:
	var out := Vector2.ZERO
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var p: Vector2 = r.get_center() + dir * 18.0
		if not solid_at(p, 5.0):
			out = p
			break
	return out if out != Vector2.ZERO else r.get_center()


func crack(cid: String) -> Dictionary:
	for cr in cracks:
		if cr["id"] == cid:
			return cr
	return {}


## Doors that stand open on some days only (the burnt door, open days 1–9) for `day`; the rest
## as the loop began.
func set_day_doors(day: int) -> void:
	for did in doors:
		var od: Array = doors[did]["open_days"]
		if not od.is_empty():
			doors[did]["open"] = day >= int(od[0]) and day <= int(od[1])


## A tent's footprint [x, y, rotation, cloth]: 44 × 36 px, turned by its rotation.
static func tent_rect(t: Array) -> Rect2:
	var horiz: bool = absf(fmod(float(t[2]), 180.0)) < 45.0
	var size := Vector2(44, 36) if horiz else Vector2(36, 44)
	return Rect2(Vector2(t[0], t[1]) - size * 0.5, size)


## The four walls of an enterable building, with a gap for its door.
func _building_walls(r: Rect2, door: Dictionary) -> Array:
	var out: Array = []
	var sides := {
		"north": [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), true],
		"south": [Vector2(r.position.x, r.end.y - WALL), Vector2(r.end.x, r.end.y - WALL), true],
		"west": [Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), false],
		"east": [Vector2(r.end.x - WALL, r.position.y), Vector2(r.end.x - WALL, r.end.y), false],
	}
	for side in sides:
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var horiz: bool = sides[side][2]
		var spans: Array = [[a.x if horiz else a.y, b.x if horiz else b.y]]
		if side == door["side"]:
			spans = [[spans[0][0], float(door["from"])], [float(door["to"]), spans[0][1]]]
		for s in spans:
			if s[1] - s[0] < 1.0:
				continue
			if horiz:
				out.append(Rect2(s[0], a.y, s[1] - s[0], WALL))
			else:
				out.append(Rect2(a.x, s[0], WALL, s[1] - s[0]))
	return out


func _rect(r: Rect2, kind: String) -> void:
	rects.append([r, kind])
	var i := rects.size() - 1
	for cell in _cells(r):
		_cell(cell)["r"].append(i)


func _index_circle(i: int) -> void:
	var c: Vector2 = circles[i][0]
	var r: float = circles[i][1]
	for cell in _cells(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)):
		_cell(cell)["c"].append(i)


func _cells(r: Rect2) -> Array:
	var out: Array = []
	for x in range(int(floor(r.position.x / CELL)), int(floor(r.end.x / CELL)) + 1):
		for y in range(int(floor(r.position.y / CELL)), int(floor(r.end.y / CELL)) + 1):
			out.append(Vector2i(x, y))
	return out


func _cell(k: Vector2i) -> Dictionary:
	if not _grid.has(k):
		_grid[k] = {"r": [], "c": []}
	return _grid[k]


const _NONE := {"r": [], "c": []}


func _near(p: Vector2, r: float) -> Dictionary:
	# Most queries fall inside one cell: its own lists, without building new ones.
	var lo := Vector2i(floori((p.x - r) / CELL), floori((p.y - r) / CELL))
	if lo == Vector2i(floori((p.x + r) / CELL), floori((p.y + r) / CELL)):
		return _grid.get(lo, _NONE)
	var rs := {}
	var cs := {}
	for cell in _cells(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
		var g: Dictionary = _grid.get(cell, {})
		for i in g.get("r", []):
			rs[i] = true
		for i in g.get("c", []):
			cs[i] = true
	return {"r": rs.keys(), "c": cs.keys()}


# --- collision ----------------------------------------------------------------------

## Where a circle of radius `r` that wants to be at `p` ends up: inside the bounds and pushed
## out of every solid, so walking into a wall slides along it. `wet_solid` treats running water
## as solid too (for the things that walk out of the mist).
func collide(p: Vector2, r := 0.0, wet_solid := false) -> Vector2:
	p = Vector2(clampf(p.x, bounds.position.x + r, bounds.end.x - r), clampf(p.y, bounds.position.y + r, bounds.end.y - r))
	for pass_i in 2:
		var near := _near(p, r + 2.0)
		for i in near["r"]:
			p = _out_of_rect(p, r, rects[i][0])
		for i in near["c"]:
			p = _out_of_circle(p, r, circles[i][0], circles[i][1])
		for did in doors:
			if not doors[did]["open"]:
				p = _out_of_rect(p, r, doors[did]["rect"])
		for pit: Rect2 in pits:
			p = _out_of_rect(p, r, pit)
		for dw: Rect2 in deep:
			p = _out_of_rect(p, r, dw)
		if wet_solid:
			for w in water:
				p = _out_of_rect(p, r, w)
		if movers.is_valid():
			for m in movers.call():
				p = _out_of_circle(p, r, m[0], m[1])
	return p


static func _out_of_rect(p: Vector2, r: float, box: Rect2) -> Vector2:
	var q := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))
	var d := p - q
	var l := d.length()
	if l >= r:
		return p
	if l > 0.001:
		return q + d / l * r
	# The centre is inside: out by the shortest way.
	var outs := [p.x - box.position.x, box.end.x - p.x, p.y - box.position.y, box.end.y - p.y]
	var m: int = outs.find(outs.min())
	match m:
		0:
			return Vector2(box.position.x - r, p.y)
		1:
			return Vector2(box.end.x + r, p.y)
		2:
			return Vector2(p.x, box.position.y - r)
	return Vector2(p.x, box.end.y + r)


static func _out_of_circle(p: Vector2, r: float, c: Vector2, cr: float) -> Vector2:
	var d := p - c
	var l := d.length()
	if l >= r + cr:
		return p
	if l < 0.001:
		d = Vector2.DOWN
		l = 1.0
	return c + d / l * (r + cr)


## Whether a point is inside anything solid (a shot hitting a wall).
func solid_at(p: Vector2, grow := 0.0) -> bool:
	if not bounds.has_point(p):
		return true
	var near := _near(p, grow + 1.0)
	for i in near["r"]:
		if (rects[i][0] as Rect2).grow(grow).has_point(p):
			return true
	for i in near["c"]:
		if p.distance_to(circles[i][0]) < float(circles[i][1]) + grow:
			return true
	for did in doors:
		if not doors[did]["open"] and (doors[did]["rect"] as Rect2).grow(grow).has_point(p):
			return true
	return false


func blocks_shot(p: Vector2) -> bool:
	return solid_at(p)


## Whether a walker can't stand at `p`: anything solid, a pit, or deep water.
func blocked(p: Vector2, grow := 0.0) -> bool:
	if solid_at(p, grow):
		return true
	for pit: Rect2 in pits:
		if pit.grow(grow).has_point(p):
			return true
	for dw: Rect2 in deep:
		if dw.grow(grow).has_point(p):
			return true
	return false


func in_pit(p: Vector2, r := 0.0) -> bool:
	for pit: Rect2 in pits:
		if pit.grow(r).has_point(p):
			return true
	return false


## The exit a point stands in, or "".
func exit_at(p: Vector2) -> String:
	for eid in exits:
		if (exits[eid]["rect"] as Rect2).has_point(p):
			return eid
	return ""


## The circle a point is in (the Observatory for the scorch test), or "".
func circle_kind_at(p: Vector2, grow := 0.0) -> String:
	for c in circles:
		if p.distance_to(c[0]) < float(c[1]) + grow:
			return c[2]
	return ""


func in_water(p: Vector2, r := 0.0) -> bool:
	for w in water:
		if (w as Rect2).grow(r).has_point(p):
			return true
	return false


func on_bridge(p: Vector2) -> bool:
	for b in bridges:
		if (b as Rect2).has_point(p):
			return true
	return false


## Out of the water by the shortest way (Hollows never stand in running water).
func out_of_water(p: Vector2, r: float) -> Vector2:
	for w in water:
		p = _out_of_rect(p, r, w)
	return p


## Whether a circle of radius `r` can travel in a straight line from a to b.
func clear_line(a: Vector2, b: Vector2, r := 0.0) -> bool:
	var n := maxi(1, int(a.distance_to(b) / 8.0))
	for i in n + 1:
		if blocked(a.lerp(b, float(i) / n), r):
			return false
	return true


# --- places --------------------------------------------------------------------------

## The place a point is in ("" outside them all). The first match in the data wins, so small
## places come before the larger ones round them.
func place_at(p: Vector2) -> String:
	for pid in places:
		if in_place(pid, p):
			return pid
	return ""


func in_place(pid: String, p: Vector2) -> bool:
	var pl: Dictionary = places.get(pid, {})
	if pl.has("rect"):
		var r: Array = pl["rect"]
		return Rect2(r[0], r[1], r[2], r[3]).has_point(p)
	if pl.has("circle"):
		var c: Array = pl["circle"]
		return p.distance_to(Vector2(c[0], c[1])) < float(c[2])
	return false


func place_name(pid: String) -> String:
	return str(places.get(pid, {}).get("name", ""))


func place_centre(pid: String) -> Vector2:
	var pl: Dictionary = places.get(pid, {})
	if pl.has("rect"):
		var r: Array = pl["rect"]
		return Rect2(r[0], r[1], r[2], r[3]).get_center()
	if pl.has("circle"):
		return Vector2(pl["circle"][0], pl["circle"][1])
	return bounds.get_center()


## The enterable building a point is inside, or "".
func building_at(p: Vector2) -> String:
	for bid in buildings:
		if (buildings[bid]["rect"] as Rect2).has_point(p):
			return bid
	return ""


# --- the street graph ----------------------------------------------------------------

## The nav node nearest `p` that can be walked to in a straight line (or simply the nearest).
func nearest_node(p: Vector2, r := 4.0) -> String:
	var ids: Array = nodes.keys()
	if ids.is_empty():
		return ""
	ids.sort_custom(func(a, b): return p.distance_squared_to(nodes[a]) < p.distance_squared_to(nodes[b]))
	for nid in ids.slice(0, 6):
		if clear_line(p, nodes[nid], r):
			return nid
	return ids[0]


## A walk from `a` to `b` along the streets: a list of points ending at `b`. Straight there when
## nothing is in the way.
func path(a: Vector2, b: Vector2, r := 4.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if clear_line(a, b, r) or nodes.is_empty():
		out.append(b)
		return out
	var s := nearest_node(a, r)
	var g := nearest_node(b, r)
	var prev := {s: ""}
	var dist := {s: 0.0}
	var open := [s]
	while not open.is_empty():
		open.sort_custom(func(x, y): return dist[x] + nodes[x].distance_to(nodes[g]) < dist[y] + nodes[y].distance_to(nodes[g]))
		var n: String = open.pop_front()
		if n == g:
			break
		for m in adj[n]:
			if _door_across(nodes[n], nodes[m]):
				continue  # a shut door cuts the graph (the rune door until you open it)
			var nd: float = dist[n] + nodes[n].distance_to(nodes[m])
			if not dist.has(m) or nd < dist[m]:
				dist[m] = nd
				prev[m] = n
				if not open.has(m):
					open.append(m)
	var chain: Array = []
	var cur := g
	while cur != "" and prev.has(cur):
		chain.push_front(cur)
		cur = prev[cur]
	# Cut the corners: no stepping back to a node behind you when the next one is in sight (a
	# walk that re-plans as it goes would otherwise turn round at every re-plan), and no last
	# detour once the end is in sight.
	while chain.size() >= 2 and clear_line(a, nodes[chain[1]], r):
		chain.pop_front()
	while chain.size() >= 2 and clear_line(nodes[chain[-2]], b, r):
		chain.pop_back()
	for nid in chain:
		out.append(nodes[nid])
	out.append(b)
	return out


## A shut door between two nav nodes.
func _door_across(a: Vector2, b: Vector2) -> bool:
	for did in doors:
		if doors[did]["open"]:
			continue
		var r: Rect2 = (doors[did]["rect"] as Rect2).grow(2.0)
		var steps := int(a.distance_to(b) / 6.0) + 1
		for i in steps + 1:
			if r.has_point(a.lerp(b, float(i) / steps)):
				return true
	return false


## Length of a path from `a` (for the route bot's clock).
static func path_length(a: Vector2, pts: PackedVector2Array) -> float:
	var l := 0.0
	var at := a
	for p in pts:
		l += at.distance_to(p)
		at = p
	return l


## A fallen structure lies across `r`: the pits under it can be walked over for the life.
func bridge_pits(r: Rect2) -> int:
	var n := pits.size()
	pits = pits.filter(func(p: Rect2): return not p.intersects(r))
	return n - pits.size()


## The water that stands now, given the life flags set (`flag(id) -> bool`): a rect whose drain
## flag is set is gone. Returns whether anything changed.
func set_drained(flag: Callable) -> bool:
	var now: Array = []
	for i in water_all.size():
		if water_all[i][1] == "" or not flag.call(water_all[i][1]):
			now.append(i)
	if now.size() == water.size():
		return false
	water = now.map(func(i): return water_all[i][0])
	_deep_of(now)
	return true


func _deep_of(now: Array) -> void:
	deep = []
	if river == "frozen":
		return
	for i in now:
		if water_all[i][2]:
			deep.append(water_all[i][0])
		elif river == "high" and i in rivers:
			deep.append_array(_minus_bridges(water_all[i][0]))


## The season's rivers (N-4.5.3): `state` is "high", "low", "frozen" or "", `ids` the rivers'
## water indices (data/world/seasons.json); the deep water follows.
func set_river(state: String, ids: Array) -> void:
	if state == river and ids == rivers:
		return
	river = state
	rivers = ids
	var now: Array = []
	for i in water_all.size():
		if water.has(water_all[i][0]):
			now.append(i)
	_deep_of(now)


## Rect `r` with this map's bridges cut out of it (high water is crossed on the bridges).
func _minus_bridges(r: Rect2) -> Array:
	var parts: Array = [r]
	for b: Rect2 in bridges:
		var next: Array = []
		for q: Rect2 in parts:
			if not q.intersects(b):
				next.append(q)
				continue
			var cut := q.intersection(b)
			if cut.position.y > q.position.y:
				next.append(Rect2(q.position, Vector2(q.size.x, cut.position.y - q.position.y)))
			if cut.end.y < q.end.y:
				next.append(Rect2(Vector2(q.position.x, cut.end.y), Vector2(q.size.x, q.end.y - cut.end.y)))
			if cut.position.x > q.position.x:
				next.append(Rect2(Vector2(q.position.x, cut.position.y), Vector2(cut.position.x - q.position.x, cut.size.y)))
			if cut.end.x < q.end.x:
				next.append(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(q.end.x - cut.end.x, cut.size.y)))
		parts = next
	return parts
