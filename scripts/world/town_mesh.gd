extends Node3D
## Vellmar's buildings and street furniture, built once from data/world/map.json (design/
## open-world/tech-plan.md §5): houses with lit windows, the College walls and gate, the archive
## and your dormitory (whose roofs and front walls lift while you're inside), the Observatory
## with its burnt door, market stalls, the well and statue, the Mill and its wheel, the millrace
## and footbridge, the College stairs, the cliffs the College stands on, trees and rocks.
##
## Everything that stands still is merged into one solid and one glowing mesh per 12 m chunk,
## with the colour in the vertices, so the browser draws a handful of meshes near the camera
## and culls the rest. Lamps, the north door, the wheel, roofs you can lift and props that move
## are their own nodes; the world view (world_view.gd) drives them.

const Figure := preload("res://scripts/view/figure.gd")
const POOL_SHADER := preload("res://scripts/view/pool.gdshader")
const CHUNK_PX := 216.0

var view  # world_view.gd: to_world() and S
var map  # scripts/world/map.gd
var cfg: Dictionary  # data/visual.json "world" "town"
var pal: Dictionary
var rng := RandomNumberGenerator.new()
var _chunks := {}  # Vector2i -> {"solid": SurfaceTool, "glow": SurfaceTool, "n": int}
var solid_mat: ShaderMaterial
var glow_mat: ShaderMaterial  # every lit window: its glow follows the time of day
var lit_mat: ShaderMaterial  # a lit lantern
var dark_mat: ShaderMaterial  # an unlit lantern
var pool_mat: ShaderMaterial
var water_mat: ShaderMaterial
## Built for the view to drive: {id: Node3D}
var roofs := {}  # building id -> [MeshInstance3D] hidden while you're inside
var lanterns: Array = []  # one per map lamp: {"glass": MeshInstance3D, "pool": MeshInstance3D}
var brazier_fires: Array = []  # MeshInstance3D per brazier
var north_door: Node3D
var wheel: Node3D


func build(the_view, the_map, config: Dictionary) -> void:
	view = the_view
	map = the_map
	cfg = config
	pal = cfg["palette"]
	rng.seed = 21
	_materials()
	_cliffs()
	_hill()
	for w in map.d["walls"]:
		_wall(Rect2(w[0], w[1], w[2], w[3]), float(w[4]))
	_gate()
	var i := 0
	for b in map.d["blocks"]:
		_block(Rect2(b[0], b[1], b[2], b[3]), float(b[4]), i)
		i += 1
	for id in map.buildings:
		_building(id, map.buildings[id])
	_observatory()
	_stairs()
	for s in map.d.get("stalls", []):
		_stall(view.to_world(Vector2(s[0], s[1])), float(s[2]), c(str(s[3])))
	_square()
	_mill()
	_water()
	_north_door()
	for l in map.d["lamps"]:
		_lamp(Vector2(l[0], l[1]))
	for b in map.d.get("braziers", []):
		_brazier(Vector2(b[0], b[1]))
	_trees()
	_interiors()
	_commit()


func c(k: String) -> Color:
	return Color(str(pal[k]))


func _materials() -> void:
	solid_mat = Figure.mat(Color.WHITE)
	solid_mat.set_shader_parameter("vcol_albedo", true)
	solid_mat.set_shader_parameter("facet", 1.0)
	Figure.finish(solid_mat, "stone")
	glow_mat = Figure.mat(Color.WHITE, float(cfg.get("window_glow", 1.4)))
	glow_mat.set_shader_parameter("vcol_albedo", true)
	lit_mat = Figure.mat(c("window"), 2.2)
	dark_mat = Figure.mat(Color("2a2a30"))
	pool_mat = ShaderMaterial.new()
	pool_mat.shader = POOL_SHADER
	pool_mat.set_shader_parameter("strength", float(cfg.get("pool_strength", 0.5)))
	water_mat = Figure.mat(c("water"), 0.25)
	Figure.finish(water_mat, "metal")


# --- merging into chunks -------------------------------------------------------------

func _chunk(at: Vector3) -> Dictionary:
	var k := Vector2i(int(floor(at.x / view.S / CHUNK_PX)), int(floor(at.z / view.S / CHUNK_PX)))
	if not _chunks.has(k):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var g := SurfaceTool.new()
		g.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[k] = {"solid": s, "glow": g, "ns": 0, "ng": 0}
	return _chunks[k]


## Appends a mesh's triangles at `xf` in one colour (sRGB, stored linear for the shader), into the
## chunk round the mesh's origin, or into `st` when one is given.
func _add(mesh: Mesh, xf: Transform3D, col: Color, glow := false, st: SurfaceTool = null) -> void:
	var lin := col.srgb_to_linear()
	var ch := {}
	if st == null:
		ch = _chunk(xf.origin)
		st = ch["glow"] if glow else ch["solid"]
		ch["ng" if glow else "ns"] += 1
	var nb := xf.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := idx.size() if idx.size() > 0 else verts.size()
		for k in n:
			var v := idx[k] if idx.size() > 0 else k
			st.set_color(lin)
			if norms.size() > v:
				st.set_normal((nb * norms[v]).normalized())
			st.add_vertex(xf * verts[v])


func _box(size: Vector3, pos: Vector3, col: Color, rot := 0.0, glow := false, st: SurfaceTool = null) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_add(bm, Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), pos), col, glow, st)


static func _cyl(top: float, bot: float, h: float, segs := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


## A box from a sim rect, `h` metres tall, standing on the ground (or from `y0`).
func _rect_box(r: Rect2, h: float, col: Color, y0 := 0.0, st: SurfaceTool = null) -> void:
	var a: Vector3 = view.to_world(r.position)
	var b: Vector3 = view.to_world(r.end)
	_box(Vector3(b.x - a.x, h, b.z - a.z), Vector3((a.x + b.x) * 0.5, y0 + h * 0.5, (a.z + b.z) * 0.5), col, 0.0, false, st)


func _commit() -> void:
	for k in _chunks:
		var ch: Dictionary = _chunks[k]
		if ch["ns"] > 0:
			_mesh(ch["solid"].commit(), solid_mat, true)
		if ch["ng"] > 0:
			_mesh(ch["glow"].commit(), glow_mat, false)


func _mesh(m: Mesh, mat: Material, shadows: bool, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


## A separate mesh (not chunked) from shapes added through `fill`: func(st: SurfaceTool).
func _own(fill: Callable, mat: Material, parent: Node = null, shadows := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	fill.call(st)
	return _mesh(st.commit(), mat, shadows, parent)


# --- the hill, the walls and the houses ---------------------------------------------------

## The hill the College stands on: a grassy shoulder with a rocky edge along the city side.
func _cliffs() -> void:
	for r in map.d.get("cliffs", []):
		var rect := Rect2(r[0], r[1], r[2], r[3])
		# Rocks along the edge facing the city (the camera looks north).
		var x := rect.position.x + 10.0
		while x < rect.end.x - 10.0:
			var s := rng.randf_range(0.8, 1.6)
			var p: Vector3 = view.to_world(Vector2(x, rect.end.y - 8.0 - rng.randf_range(0, 18)))
			_add(_rock_mesh(s), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, s * 0.3, 0)), c("rock").lerp(c("rock2"), rng.randf()))
			x += rng.randf_range(26, 46)


func _rock_mesh(s: float) -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = s
	sm.height = s * 1.3
	sm.radial_segments = 5
	sm.rings = 3
	return sm


## The north hill outside the north door: stones and a few dead trees in the dark.
func _hill() -> void:
	for i in 26:
		var p := Vector2(rng.randf_range(540, 1460), rng.randf_range(20, 180))
		if absf(p.x - 1100.0) < 50.0:
			continue
		_add(_rock_mesh(rng.randf_range(0.4, 1.1)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), view.to_world(p, 0.1)), c("rock2"))


## A stone wall with a coping and merlons along its top.
func _wall(r: Rect2, h_px: float) -> void:
	var h := h_px * view.S
	_rect_box(r, h, c("wall_stone"))
	_rect_box(r.grow(2.0), 0.18, c("stone"), h)
	var horiz := r.size.x > r.size.y
	var len := r.size.x if horiz else r.size.y
	var n := int(len / 26.0)
	for k in n:
		var t := (k + 0.5) / n
		var p := r.position + (Vector2(r.size.x * t, r.size.y * 0.5) if horiz else Vector2(r.size.x * 0.5, r.size.y * t))
		if k % 2 == 0:
			_box(Vector3(0.6, 0.45, 0.6), view.to_world(p, h + 0.4), c("wall_stone"))


## The College gate: two towers either side of the gap, an arch over it; the east gate's posts.
func _gate() -> void:
	for x in [944.0, 1056.0]:
		_rect_box(Rect2(x - 18, 792, 36, 40), 6.6, c("wall_stone"))
		_box(Vector3(2.4, 0.5, 2.4), view.to_world(Vector2(x, 812), 6.85), c("roof"))
	_box(Vector3(80.0 * view.S, 0.9, 1.4), view.to_world(Vector2(1000, 812), 5.2), c("wall_stone"))
	_box(Vector3(80.0 * view.S, 0.2, 1.6), view.to_world(Vector2(1000, 812), 5.75), c("stone"))
	for y in [972.0, 1088.0]:
		_rect_box(Rect2(2092, y - 10, 32, 20), 5.2, c("wall_stone"))


## A row of houses filling a block: two-storey timber-framed fronts toward the camera, lit
## windows, pitched roofs and chimneys.
func _block(r: Rect2, h_px: float, seed_i: int) -> void:
	rng.seed = 100 + seed_i
	var rows := 2 if r.size.y > 150.0 else 1
	var walls := ["wall", "wall2", "wall3"]
	var roofs_k := ["roof", "roof2", "roof3"]
	for row in rows:
		var ry := r.position.y + r.size.y * row / rows
		var rh := r.size.y / rows
		var x := r.position.x
		while x < r.end.x - 1.0:
			var w := minf(rng.randf_range(58, 96), r.end.x - x)
			if r.end.x - (x + w) < 40.0:
				w = r.end.x - x
			var hh := (h_px + rng.randf_range(-14, 18)) * view.S
			_house(Rect2(x, ry, w, rh), hh, c(walls[rng.randi() % 3]), c(roofs_k[rng.randi() % 3]))
			x += w


func _house(r: Rect2, h: float, wall: Color, roof: Color, st: SurfaceTool = null) -> void:
	var a: Vector3 = view.to_world(r.position)
	var b: Vector3 = view.to_world(r.end)
	var w := b.x - a.x
	var d := b.z - a.z
	var cx := (a.x + b.x) * 0.5
	var cz := (a.z + b.z) * 0.5
	_box(Vector3(w - 0.1, h, d - 0.1), Vector3(cx, h * 0.5, cz), wall, 0.0, false, st)
	_box(Vector3(w, 0.6, d), Vector3(cx, 0.3, cz), c("stone"), 0.0, false, st)
	# The front (south, toward the camera): timber posts and beams, windows, a door.
	var fz := b.z + 0.02
	var floors := maxi(1, int(h / 2.4))
	var posts := maxi(1, int(w / 1.5))
	for k in posts + 1:
		_box(Vector3(0.14, h - 0.6, 0.1), Vector3(a.x + 0.05 + k * (w - 0.1) / posts, h * 0.5 + 0.3, fz), c("timber"), 0.0, false, st)
	for f in floors + 1:
		_box(Vector3(w - 0.1, 0.14, 0.12), Vector3(cx, 0.6 + f * (h - 0.6) / floors, fz), c("timber"), 0.0, false, st)
	var cols := maxi(1, int(w / 1.6))
	var door_k := rng.randi() % cols
	for f in floors:
		var y := 0.6 + (f + 0.5) * (h - 0.6) / floors
		for k in cols:
			var wx := a.x + (k + 0.5) * w / cols
			if f == 0 and k == door_k:
				_box(Vector3(0.85, 1.6, 0.08), Vector3(wx, 1.4, fz + 0.03), c("timber").darkened(0.3), 0.0, false, st)
				continue
			var lit := rng.randf() < 0.7
			_box(Vector3(0.5, 0.7, 0.06), Vector3(wx, y, fz + 0.04), c("window") if lit else c("dark_window"), 0.0, lit and st == null, st)
	# Side windows on the ends, so a street seen at an angle isn't blind.
	for side in [-1.0, 1.0]:
		if rng.randf() < 0.6:
			var sx := (a.x if side < 0 else b.x) + side * 0.03
			var lit := rng.randf() < 0.6
			_box(Vector3(0.06, 0.7, 0.5), Vector3(sx, 0.6 + (h - 0.6) * 0.7, cz), c("window") if lit else c("dark_window"), 0.0, lit and st == null, st)
	# Roof: ridge along the longer side; a chimney.
	var pm := PrismMesh.new()
	var rh := minf(h * 0.45, 2.6)
	if w >= d:
		pm.size = Vector3(d + 0.5, rh, w + 0.3)
		_add(pm, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(cx, h + rh * 0.5, cz)), roof, false, st)
	else:
		pm.size = Vector3(w + 0.5, rh, d + 0.3)
		_add(pm, Transform3D(Basis(), Vector3(cx, h + rh * 0.5, cz)), roof, false, st)
	if rng.randf() < 0.7:
		_box(Vector3(0.45, 1.3, 0.45), Vector3(a.x + w * rng.randf_range(0.2, 0.8), h + rh * 0.6, cz - d * 0.15), c("stone"), 0.0, false, st)


# --- buildings you can enter ------------------------------------------------------------

## The archive and your dormitory: walls with a doorway; the roof and the front (south) walls
## are their own meshes, hidden while you're inside.
func _building(id: String, bd: Dictionary) -> void:
	var h := float(bd["height"]) * view.S
	var rect: Rect2 = bd["rect"]
	var wall := c(str(bd.get("wall", "wall")))
	var lift := Node3D.new()
	lift.name = "lift_" + id
	add_child(lift)
	var front: Array = []
	var back: Array = []
	for w: Rect2 in bd["walls"]:
		if w.position.y + w.size.y >= rect.end.y - 0.5 and w.size.x > w.size.y:
			front.append(w)
		elif w.size.y > w.size.x and w.position.y + w.size.y >= rect.end.y - 0.5:
			# side walls reach the front: split their last 40 px off with the front
			back.append(Rect2(w.position, Vector2(w.size.x, w.size.y - 40)))
			front.append(Rect2(w.position + Vector2(0, w.size.y - 40), Vector2(w.size.x, 40)))
		else:
			back.append(w)
	for w in back:
		_rect_box(w, h, wall)
		_rect_box(w.grow(1.0), 0.15, c("stone"), h)
	var front_mi := _own(func(st):
		for w in front:
			_rect_box(w, h, wall, 0.0, st)
			_rect_box(w.grow(1.0), 0.15, c("stone"), h, st)
		# windows on the front
		var fw: Vector3 = view.to_world(Vector2(rect.get_center().x, rect.end.y))
		for k in 3:
			var x: float = view.to_world(Vector2(rect.position.x + rect.size.x * (k + 0.5) / 3.0, 0)).x
			if absf(x - fw.x) < 0.1 and str(bd["door"]["side"]) == "south":
				continue
			_box(Vector3(0.6, 0.9, 0.08), Vector3(x, h * 0.6, fw.z + 0.05), c("window"), 0.0, false, st)
	, solid_mat, lift)
	var pm := PrismMesh.new()
	var a: Vector3 = view.to_world(rect.position)
	var b: Vector3 = view.to_world(rect.end)
	var rh := 2.4
	var roof_mi := _own(func(st):
		pm.size = Vector3(b.z - a.z + 0.6, rh, b.x - a.x + 0.4)
		_add(pm, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3((a.x + b.x) * 0.5, h + rh * 0.5, (a.z + b.z) * 0.5)), c(str(bd.get("roof", "roof"))), false, st)
		_box(Vector3(0.5, 1.4, 0.5), Vector3(a.x + (b.x - a.x) * 0.25, h + rh * 0.7, (a.z + b.z) * 0.5), c("stone"), 0.0, false, st)
	, solid_mat, lift)
	roofs[id] = [front_mi, roof_mi]
	# The floor inside: planks.
	_box(Vector3(b.x - a.x - 0.4, 0.06, b.z - a.z - 0.4), Vector3((a.x + b.x) * 0.5, 0.03, (a.z + b.z) * 0.5), c("planks"))


## What's inside: the archive's shelves, desk and ladder; your bed, desk and grate.
func _interiors() -> void:
	var W := func(x: float, y: float, h := 0.0) -> Vector3: return view.to_world(Vector2(x, y), h)
	# The archive: shelves along the north and west walls, Wren's desk, a ladder, reading tables.
	for i in 7:
		_box(Vector3(2.0, 3.6, 0.7), W.call(600 + i * 38.0, 250, 1.8), c("timber"))
		for k in 4:
			_box(Vector3(1.8, 0.35, 0.5), W.call(600 + i * 38.0, 252, 0.5 + k * 0.85), [c("cloth"), c("cloth2"), c("leaf"), c("brass")][(i + k) % 4])
	for i in 3:
		_box(Vector3(0.7, 3.4, 2.0), W.call(576, 300 + i * 34.0, 1.7), c("timber"))
	_box(Vector3(2.2, 0.9, 1.1), W.call(780, 288, 0.45), c("timber"))
	_box(Vector3(0.5, 0.06, 0.4), W.call(770, 284, 0.93), c("paper"))
	_box(Vector3(1.6, 0.8, 0.9), W.call(700, 360, 0.4), c("timber").darkened(0.2))
	_box(Vector3(0.12, 3.4, 0.12), W.call(604, 268, 1.7), c("timber"))
	_box(Vector3(0.12, 3.4, 0.12), W.call(620, 268, 1.7), c("timber"))
	# Your room: a narrow bed, a desk, a cold grate.
	_box(Vector3(1.0, 0.5, 2.1), W.call(1420, 560, 0.25), c("timber"))
	_box(Vector3(0.9, 0.18, 1.9), W.call(1420, 560, 0.58), c("cloth2").darkened(0.3))
	_box(Vector3(0.6, 0.15, 0.4), W.call(1420, 538, 0.72), c("paper"))
	_box(Vector3(1.3, 0.8, 0.7), W.call(1432, 655, 0.4), c("timber"))
	_box(Vector3(0.12, 0.12, 0.12), W.call(1424, 652, 0.86), c("brass"))
	_box(Vector3(1.2, 1.0, 0.4), W.call(1330, 540, 0.5), c("stone"))


## The Observatory: a round stone tower with a dark dome, its door burnt through from inside.
func _observatory() -> void:
	for cr in map.circles:
		if cr[2] != "observatory":
			continue
		var p: Vector3 = view.to_world(cr[0])
		var r: float = float(cr[1]) * view.S
		var h := 8.6
		_add(_cyl(r, r * 1.04, h, 14), Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), c("wall_stone"))
		_add(_cyl(r * 1.08, r * 1.08, 0.3, 14), Transform3D(Basis(), p + Vector3(0, h, 0)), c("stone"))
		var dome := SphereMesh.new()
		dome.radius = r * 0.92
		dome.height = r * 1.84
		dome.radial_segments = 12
		dome.rings = 5
		dome.is_hemisphere = true
		_add(dome, Transform3D(Basis(), p + Vector3(0, h, 0)), c("dome"))
		# the slit in the dome
		_box(Vector3(0.7, r * 0.9, r * 1.9), p + Vector3(0, h + r * 0.45, 0), c("dark_window"))
		# the burnt door, and the scorch spreading out round it
		var dz: float = p.z + r * 0.98
		_box(Vector3(1.5, 2.4, 0.3), Vector3(p.x, 1.2, dz), c("char"))
		for k in 7:
			var a := -PI / 2.0 + (k - 3) * 0.32
			_box(Vector3(0.18, 0.06, 0.9 + (k % 2) * 0.5), Vector3(p.x + cos(a) * 0.1, 1.3 + sin(a) * 0.1, dz + 0.17), c("ember"), rad_to_deg(a), true)
		for k in 5:
			var a := k * TAU / 5.0 - PI / 2.0
			_box(Vector3(0.35, 1.3, 0.06), Vector3(p.x + cos(a) * 1.0, 1.4 + sin(a) * 1.0, dz + 0.12), c("char"), 0.0)


func _stairs() -> void:
	var s: Array = map.d["stairs"]
	var r := Rect2(s[0], s[1], s[2], s[3])
	var n := 5
	for k in n:
		var top := r.position.y + r.size.y * k / n
		_rect_box(Rect2(r.position.x, top, r.size.x, r.size.y - r.size.y * k / n), 0.05 + 0.05 * k, c("stone").lerp(c("wall_stone"), 0.3))


func _stall(at: Vector3, rot: float, cloth: Color) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot))
	var put := func(size: Vector3, local: Vector3, col: Color, glow := false) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_add(bm, Transform3D(basis, at + basis * local), col, glow)
	put.call(Vector3(2.2, 0.9, 1.0), Vector3(0, 0.45, 0), c("timber"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			put.call(Vector3(0.08, 2.1, 0.08), Vector3(sx * 1.05, 1.05, sz * 0.45), c("timber"))
	var pm := PrismMesh.new()
	pm.size = Vector3(2.6, 0.55, 1.4)
	_add(pm, Transform3D(basis, at + basis * Vector3(0, 2.35, 0)), cloth)
	for i in 4:
		put.call(Vector3(0.28, 0.22, 0.28), Vector3(-0.75 + i * 0.5, 1.0, 0.1), [c("cloth2"), c("leaf"), c("cloth"), c("brass")][i])
	put.call(Vector3(0.22, 0.26, 0.22), Vector3(0.9, 1.05, -0.3), c("window"), true)


## The square's dry well and the forgotten Provost on his plinth; the Mill's ash heap.
func _square() -> void:
	for cr in map.circles:
		var p: Vector3 = view.to_world(cr[0])
		var r: float = float(cr[1]) * view.S
		match cr[2]:
			"well":
				_add(_cyl(r, r, 0.8, 8), Transform3D(Basis(), p + Vector3(0, 0.4, 0)), c("stone"))
				_add(_cyl(r * 0.7, r * 0.7, 0.05, 8), Transform3D(Basis(), p + Vector3(0, 0.81, 0)), c("dark_window"))
				for sx in [-1.0, 1.0]:
					_box(Vector3(0.12, 2.0, 0.12), p + Vector3(sx * r * 0.9, 1.4, 0), c("timber"))
				var pm := PrismMesh.new()
				pm.size = Vector3(r * 2.4, 0.5, r * 1.6)
				_add(pm, Transform3D(Basis(), p + Vector3(0, 2.6, 0)), c("roof"))
			"statue":
				_add(_cyl(r * 1.4, r * 1.6, 1.2, 6), Transform3D(Basis(), p + Vector3(0, 0.6, 0)), c("stone"))
				_add(_cyl(0.22, 0.4, 1.6, 6), Transform3D(Basis(), p + Vector3(0, 2.0, 0)), c("statue"))
				var head := SphereMesh.new()
				head.radius = 0.2
				head.height = 0.4
				head.radial_segments = 6
				head.rings = 3
				_add(head, Transform3D(Basis(), p + Vector3(0, 3.0, 0)), c("statue"))
			"ash":
				_add(_cyl(0.1, r * 1.1, 0.6, 7), Transform3D(Basis(), p + Vector3(0, 0.3, 0)), c("ash"))


## The Mill: its wheel turning in the millrace (the house itself is one of the blocks).
func _mill() -> void:
	wheel = Node3D.new()
	wheel.position = view.to_world(Vector2(420, 985), 1.4)
	add_child(wheel)
	_own(func(st):
		for k in 8:
			var a := k * TAU / 8.0
			_add(BoxMesh.new(), Transform3D(Basis(Vector3.RIGHT, a).scaled(Vector3(1.6, 0.12, 2.8)), Vector3.ZERO), c("timber"), false, st)
		var rim := TorusMesh.new()
		rim.inner_radius = 1.25
		rim.outer_radius = 1.45
		rim.rings = 12
		rim.ring_segments = 3
		_add(rim, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3.ZERO), c("timber").darkened(0.2), false, st)
	, solid_mat, wheel)


## The millrace: running water, stone banks, and the footbridge.
func _water() -> void:
	for w: Rect2 in map.water:
		var a: Vector3 = view.to_world(w.position)
		var b: Vector3 = view.to_world(w.end)
		var pm := PlaneMesh.new()
		pm.size = Vector2(b.x - a.x, b.z - a.z)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = water_mat
		mi.position = Vector3((a.x + b.x) * 0.5, -0.12, (a.z + b.z) * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		for x in [w.position.x - 3.0, w.end.x + 3.0]:
			var y := w.position.y
			while y < w.end.y:
				var on_bridge := false
				for br: Rect2 in map.bridges:
					if y + 40 > br.position.y and y < br.end.y:
						on_bridge = true
				if not on_bridge:
					_rect_box(Rect2(x - 3, y, 6, 40), 0.22, c("stone"))
				y += 40.0
	for br: Rect2 in map.bridges:
		_rect_box(br, 0.12, c("timber"), 0.05)
		_rect_box(Rect2(br.position.x, br.position.y, br.size.x, 3), 0.9, c("timber").darkened(0.3))
		_rect_box(Rect2(br.position.x, br.end.y - 3, br.size.x, 3), 0.9, c("timber").darkened(0.3))


## The north door: iron-bound oak in the College's north wall; it swings in on day 7.
func _north_door() -> void:
	var d: Array = map.d["doors"]["north_door"]
	var hinge := Vector2(d[0], d[1] + d[3] * 0.5)
	north_door = Node3D.new()
	north_door.position = view.to_world(hinge)
	add_child(north_door)
	var w: float = float(d[2]) * view.S
	_own(func(st):
		_box(Vector3(w, 3.2, 0.25), Vector3(w * 0.5, 1.6, 0), c("timber").darkened(0.25), 0.0, false, st)
		for y in [0.6, 1.6, 2.6]:
			_box(Vector3(w, 0.12, 0.3), Vector3(w * 0.5, y, 0), c("iron"), 0.0, false, st)
	, solid_mat, north_door)


## A lamp post: the post is merged; the lantern and its pool of light are separate, so each can
## be lit and put out.
func _lamp(at: Vector2) -> void:
	var p: Vector3 = view.to_world(at)
	_add(_cyl(0.06, 0.08, 2.6, 5), Transform3D(Basis(), p + Vector3(0, 1.3, 0)), c("iron"))
	_add(_cyl(0.0, 0.28, 0.28, 4), Transform3D(Basis(), p + Vector3(0, 3.08, 0)), c("iron"))
	var glass := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.38, 0.32)
	glass.mesh = bm
	glass.material_override = dark_mat
	glass.position = p + Vector3(0, 2.75, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var pool := _pool_quad(p, float(cfg.get("pool_m", 3.4)), Color(str(cfg.get("lamp_color", "ffb060"))))
	pool.visible = false
	lanterns.append({"glass": glass, "pool": pool})


func _pool_quad(p: Vector3, r: float, col: Color) -> MeshInstance3D:
	return _own(func(st):
		var y := 0.07
		var q := [Vector3(-r, y, -r), Vector3(r, y, -r), Vector3(r, y, r), Vector3(-r, y, r)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(uv[k])
			st.add_vertex(p + q[k])
	, pool_mat, null, false)


## A brazier in the yard: an iron bowl on legs, with a fire that shows when it's lit.
func _brazier(at: Vector2) -> void:
	var p: Vector3 = view.to_world(at)
	_add(_cyl(0.42, 0.22, 0.35, 7), Transform3D(Basis(), p + Vector3(0, 0.95, 0)), c("iron"))
	for k in 3:
		var a := k * TAU / 3.0
		_box(Vector3(0.07, 0.9, 0.07), p + Vector3(cos(a) * 0.25, 0.45, sin(a) * 0.25), c("iron"))
	var fire := MeshInstance3D.new()
	fire.mesh = _cyl(0.0, 0.3, 0.6, 5)
	fire.material_override = Figure.mat(Color("ff8a3a"), 2.4)
	fire.position = p + Vector3(0, 1.4, 0)
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.visible = false
	add_child(fire)
	brazier_fires.append(fire)


func _tree(at: Vector3, s: float, dead := false) -> void:
	_add(_cyl(0.12 * s, 0.18 * s, 1.8 * s, 5), Transform3D(Basis(), at + Vector3(0, 0.9 * s, 0)), c("timber"))
	if dead:
		for k in 3:
			var a := k * TAU / 3.0 + rng.randf()
			_add(_cyl(0.03 * s, 0.07 * s, 1.1 * s, 4), Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.7), at + Vector3(cos(a) * 0.3, 1.9 * s, sin(a) * 0.3) * Vector3(s, 1, s)), c("timber"))
		return
	for i in 3:
		var sm := SphereMesh.new()
		sm.radius = (0.9 - i * 0.2) * s
		sm.height = sm.radius * 1.7
		sm.radial_segments = 6
		sm.rings = 3
		var off := Vector3(rng.randf_range(-0.2, 0.2), (1.8 + i * 0.5) * s, rng.randf_range(-0.2, 0.2))
		_add(sm, Transform3D(Basis(), at + off), c("leaf") if i % 2 == 0 else c("leaf2"))


func _trees() -> void:
	# On the hill either side of the College, and along the road out east.
	for cl in map.d.get("cliffs", []):
		var r := Rect2(cl[0], cl[1], cl[2], cl[3])
		var n := int(r.get_area() / 26000.0)
		for i in n:
			var p := Vector2(rng.randf_range(r.position.x + 20, r.end.x - 20), rng.randf_range(r.position.y + 20, r.end.y - 30))
			_tree(view.to_world(p), rng.randf_range(0.9, 1.5), rng.randf() < 0.3)
	for i in 8:
		_tree(view.to_world(Vector2(rng.randf_range(560, 1440), rng.randf_range(30, 170))), rng.randf_range(0.8, 1.2), true)
	for p in [Vector2(2180, 880), Vector2(2300, 870), Vector2(2360, 1180), Vector2(2200, 1200), Vector2(2280, 1400), Vector2(2150, 1500),
			Vector2(1500, 1150), Vector2(1770, 905), Vector2(200, 1300)]:
		_tree(view.to_world(p), rng.randf_range(0.9, 1.3), p.x > 2100 and rng.randf() < 0.5)
