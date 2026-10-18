extends RefCounted
## Collects flat-coloured shapes as triangles and draws them all as one command (flush), in the
## order they were added. The browser renderer otherwise spends a draw call on most circles, arcs
## and polygons, and the HUD has dozens of them (the 28 moons alone were about 80).

var pts := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var n := pts.size()
	pts.append_array([a, b, c])
	cols.append_array([col, col, col])
	idx.append_array([n, n + 1, n + 2])


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var n := pts.size()
	pts.append_array([a, b, c, d])
	cols.append_array([col, col, col, col])
	idx.append_array([n, n + 1, n + 2, n, n + 2, n + 3])


func rect(r: Rect2, col: Color, filled := true, w := 1.0) -> void:
	if filled:
		_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)
		return
	var h := w * 0.5
	line(r.position + Vector2(-h, 0), Vector2(r.end.x + h, r.position.y), col, w)
	line(Vector2(r.position.x - h, r.end.y), r.end + Vector2(h, 0), col, w)
	line(r.position + Vector2(0, h), Vector2(r.position.x, r.end.y - h), col, w)
	line(Vector2(r.end.x, r.position.y + h), r.end - Vector2(0, h), col, w)


func line(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var nrm := d.normalized().orthogonal() * maxf(w, 1.0) * 0.5
	_quad(a - nrm, b - nrm, b + nrm, a + nrm, col)


func polyline(p: PackedVector2Array, col: Color, w := 1.0) -> void:
	for i in p.size() - 1:
		line(p[i], p[i + 1], col, w)


## A convex polygon, as a fan from its first point.
func poly(p: PackedVector2Array, col: Color) -> void:
	for i in range(1, p.size() - 1):
		_tri(p[0], p[i], p[i + 1], col)


func circle(c: Vector2, r: float, col: Color, segs := 0) -> void:
	var n := segs if segs > 0 else clampi(int(r * 2.0) + 8, 10, 32)
	var prev := c + Vector2(r, 0)
	for i in range(1, n + 1):
		var p := c + Vector2.from_angle(TAU * i / n) * r
		_tri(c, prev, p, col)
		prev = p


func arc(c: Vector2, r: float, a0: float, a1: float, segs: int, col: Color, w := 1.0) -> void:
	var h := maxf(w, 1.0) * 0.5
	var prev := Vector2.from_angle(a0)
	for i in range(1, segs + 1):
		var d := Vector2.from_angle(lerpf(a0, a1, float(i) / segs))
		_quad(c + prev * (r - h), c + d * (r - h), c + d * (r + h), c + prev * (r + h), col)
		prev = d


## Shapes that rarely change: `build` adds them, and runs again only when `key` changes; in
## between, the triangles it made last time are drawn as they are (one command of their own, so
## whatever was collected before them is flushed first to keep the order).
var _cache := {}  # name -> {"key", "pts", "cols", "idx"}


func cached(ci: RID, name: String, key, build: Callable) -> void:
	flush(ci)
	var c: Dictionary = _cache.get(name, {})
	if c.is_empty() or c["key"] != key:
		build.call()
		c = {"key": key, "pts": pts, "cols": cols, "idx": idx}
		_cache[name] = c
		pts = PackedVector2Array()
		cols = PackedColorArray()
		idx = PackedInt32Array()
	if not c["idx"].is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, c["idx"], c["pts"], c["cols"])


## Draws everything collected onto canvas item `ci` and starts again.
func flush(ci: RID) -> void:
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)
	pts = PackedVector2Array()
	cols = PackedColorArray()
	idx = PackedInt32Array()
