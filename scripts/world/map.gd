extends RefCounted
## Vellmar as one walkable map (data/world/map.json; design/open-world/world.md). Answers the
## questions the sim and the people ask about the town: where a circle of radius r can stand
## (collide), whether a shot hits a wall (blocks_shot), where running water is, which place a
## point is in, and how to walk from one point to another along the streets (path).
##
## Solids are axis-aligned rects (houses, walls, cliffs, stalls, closed doors, the walls of the
## buildings you can enter) and circles (the Observatory, the well). They are sorted into a grid
## of CELL-pixel cells so each query only looks at what is near. Props that move (crates and
## barrels) are not here: the world adds them through `movers`.

const PATH := "res://data/world/map.json"
const CELL := 96.0
const WALL := 10.0  # thickness of an enterable building's walls

var d: Dictionary
var bounds := Rect2()
var rects: Array = []  # [Rect2, kind]
var circles: Array = []  # [Vector2, r, kind]
var water: Array = []  # Rect2
var bridges: Array = []  # Rect2
var doors := {}  # id -> {"rect": Rect2, "open": bool}
var buildings := {}  # id -> {"rect", "door", "walls": [Rect2], "height", ...}
var places := {}  # id -> {"name", "district", "rect" or "circle"}
var spots := {}  # id -> Vector2
var items := {}  # id -> {"name", "at": Vector2, "verb", "reach"}
var nodes := {}  # nav node id -> Vector2
var adj := {}  # nav node id -> [ids]
var _grid := {}  # Vector2i -> {"r": [rect indices], "c": [circle indices]}
## Moving solids the world owns (crates, barrels): func() -> Array of [Vector2, r].
var movers: Callable


func _init(path := PATH) -> void:
	d = JSON.parse_string(FileAccess.get_file_as_string(path))
	var b: Array = d["bounds"]
	bounds = Rect2(b[0], b[1], b[2], b[3])
	for r in d.get("cliffs", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "cliff")
	for r in d.get("walls", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "wall")
	for r in d.get("blocks", []):
		_rect(Rect2(r[0], r[1], r[2], r[3]), "block")
	for s in d.get("stalls", []):
		var horiz: bool = absf(fmod(float(s[2]), 180.0)) < 45.0
		var size := Vector2(40, 18) if horiz else Vector2(18, 40)
		_rect(Rect2(Vector2(s[0], s[1]) - size * 0.5, size), "stall")
	for id in d.get("buildings", {}):
		var bd: Dictionary = d["buildings"][id].duplicate(true)
		var rr: Array = bd["rect"]
		bd["rect"] = Rect2(rr[0], rr[1], rr[2], rr[3])
		bd["walls"] = _building_walls(bd["rect"], bd["door"])
		for w in bd["walls"]:
			_rect(w, "building")
		buildings[id] = bd
	for c in d.get("circles", []):
		circles.append([Vector2(c[0], c[1]), float(c[2]), str(c[4])])
		_index_circle(circles.size() - 1)
	for w in d.get("water", []):
		water.append(Rect2(w[0], w[1], w[2], w[3]))
	for w in d.get("bridges", []):
		bridges.append(Rect2(w[0], w[1], w[2], w[3]))
	for id in d.get("doors", {}):
		var r: Array = d["doors"][id]
		doors[id] = {"rect": Rect2(r[0], r[1], r[2], r[3]), "open": false}
	for id in d.get("places", {}):
		places[id] = d["places"][id]
	for id in d.get("spots", {}):
		var p: Array = d["spots"][id]
		spots[id] = Vector2(p[0], p[1])
	for id in d.get("items", {}):
		var it: Dictionary = d["items"][id].duplicate()
		it["at"] = Vector2(it["at"][0], it["at"][1])
		items[id] = it
	for id in d["nav"]["nodes"]:
		var p: Array = d["nav"]["nodes"][id]
		nodes[id] = Vector2(p[0], p[1])
		adj[id] = []
	for e in d["nav"]["edges"]:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])


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
		for id in doors:
			if not doors[id]["open"]:
				p = _out_of_rect(p, r, doors[id]["rect"])
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
	for id in doors:
		if not doors[id]["open"] and (doors[id]["rect"] as Rect2).grow(grow).has_point(p):
			return true
	return false


func blocks_shot(p: Vector2) -> bool:
	return solid_at(p)


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
		if solid_at(a.lerp(b, float(i) / n), r):
			return false
	return true


# --- places --------------------------------------------------------------------------

## The place a point is in ("" outside them all). The first match in the data wins, so small
## places come before the larger ones round them.
func place_at(p: Vector2) -> String:
	for id in places:
		if in_place(id, p):
			return id
	return ""


func in_place(id: String, p: Vector2) -> bool:
	var pl: Dictionary = places.get(id, {})
	if pl.has("rect"):
		var r: Array = pl["rect"]
		return Rect2(r[0], r[1], r[2], r[3]).has_point(p)
	if pl.has("circle"):
		var c: Array = pl["circle"]
		return p.distance_to(Vector2(c[0], c[1])) < float(c[2])
	return false


func place_name(id: String) -> String:
	return str(places.get(id, {}).get("name", ""))


func place_centre(id: String) -> Vector2:
	var pl: Dictionary = places.get(id, {})
	if pl.has("rect"):
		var r: Array = pl["rect"]
		return Rect2(r[0], r[1], r[2], r[3]).get_center()
	if pl.has("circle"):
		return Vector2(pl["circle"][0], pl["circle"][1])
	return bounds.get_center()


## The enterable building a point is inside, or "".
func building_at(p: Vector2) -> String:
	for id in buildings:
		if (buildings[id]["rect"] as Rect2).has_point(p):
			return id
	return ""


# --- the street graph ----------------------------------------------------------------

## The nav node nearest `p` that can be walked to in a straight line (or simply the nearest).
func nearest_node(p: Vector2, r := 4.0) -> String:
	var ids: Array = nodes.keys()
	ids.sort_custom(func(a, b): return p.distance_squared_to(nodes[a]) < p.distance_squared_to(nodes[b]))
	for id in ids.slice(0, 6):
		if clear_line(p, nodes[id], r):
			return id
	return ids[0]


## A walk from `a` to `b` along the streets: a list of points ending at `b`. Straight there when
## nothing is in the way.
func path(a: Vector2, b: Vector2, r := 4.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if clear_line(a, b, r):
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
	for id in chain:
		out.append(nodes[id])
	out.append(b)
	return out


## Length of a path from `a` (for the route bot's clock).
static func path_length(a: Vector2, pts: PackedVector2Array) -> float:
	var l := 0.0
	var at := a
	for p in pts:
		l += at.distance_to(p)
		at = p
	return l
