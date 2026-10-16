extends Node3D
## The Mill yard as a cobbled plaza at the edge of Vellmar at night (GDD 6.3, after the "Moody
## night" mockup): cobbles inside a stone kerb, two-storey houses with lit windows round three
## sides, market stalls, trees and clutter in the streets, and lamp posts whose light pools on
## the ground. Built once from data/visual.json "town"; purely set dressing, nothing here
## touches the sim.
##
## Everything here stands still, so it is merged into three meshes (solid, glowing, lamp pools)
## with the colour in the vertices: a few draw calls in the browser instead of hundreds. The
## lamps are not real lights; their pools are additive glows on the ground.

const Figure := preload("res://scripts/view/figure.gd")
const POOL_SHADER := preload("res://scripts/view/pool.gdshader")

var view  # view3d.gd, for to_world() and the arena's bounds
var cfg: Dictionary
var pal: Dictionary
var rng := RandomNumberGenerator.new()
var _solid := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _pools := SurfaceTool.new()
var _lamps: Array = []  # lantern positions, for the light baked into the vertex colours
var _lamp_col := Color.WHITE


func build(the_view, config: Dictionary) -> void:
	view = the_view
	cfg = config
	pal = cfg["palette"]
	rng.seed = 7
	for st in [_solid, _glow, _pools]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lamp_col = Color(str(cfg.get("lamp_color", "ffb060"))).srgb_to_linear()
	for l in cfg["lamps"]:
		_lamps.append(Vector3(l[0], 2.7, l[1]))
	_cobbles()
	_kerb()
	var walls := ["wall", "wall2", "wall3"]
	var roofs := ["roof", "roof2", "roof3"]
	var i := 0
	for h in cfg["houses"]:
		# [x m, z m, width m, depth m, height m, facing degrees]: the front with the windows faces +z
		_house(Vector3(h[0], 0, h[1]), float(h[2]), float(h[3]), float(h[4]), float(h[5]), c(walls[i % 3]), c(roofs[(i + 1) % 3]))
		i += 1
	for s in cfg.get("stalls", []):
		_stall(Vector3(s[0], 0, s[1]), float(s[2]), c(str(s[3])))
	for t in cfg.get("trees", []):
		_tree(Vector3(t[0], 0, t[1]), float(t[2]))
	for p in cfg.get("props", []):
		_prop(str(p[0]), Vector3(p[1], 0, p[2]), float(p[3]), float(p[4]))
	for l in cfg["lamps"]:
		_lamp(Vector3(l[0], 0, l[1]))
	_commit()


func c(k: String) -> Color:
	return Color(str(pal[k]))


# --- merging ----------------------------------------------------------------------

## Appends a mesh's triangles at `xf` in one colour (sRGB, stored linear for the shader). Solid
## surfaces also get the lamps' warm light baked into their vertices, so walls and cobbles near
## a lantern glow without a real light.
func _add(st: SurfaceTool, mesh: Mesh, xf: Transform3D, col: Color) -> void:
	var lin := col.srgb_to_linear()
	var nb := xf.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := idx.size() if idx.size() > 0 else verts.size()
		for k in n:
			var v := idx[k] if idx.size() > 0 else k
			var at := xf * verts[v]
			st.set_color(_lit(lin, at) if st == _solid else lin)
			if norms.size() > v:
				st.set_normal((nb * norms[v]).normalized())
			st.add_vertex(at)


func _lit(lin: Color, at: Vector3) -> Color:
	var r := float(cfg.get("lamp_reach_m", 5.0))
	var k := 0.0
	for l: Vector3 in _lamps:
		k += pow(maxf(0.0, 1.0 - at.distance_to(l) / r), 2.0)
	var e := float(cfg.get("lamp_bake", 2.5)) * k
	return Color(lin.r * (1.0 + _lamp_col.r * e), lin.g * (1.0 + _lamp_col.g * e), lin.b * (1.0 + _lamp_col.b * e))


func _box(size: Vector3, pos: Vector3, col: Color, rot := 0.0, glow := false) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_add(_glow if glow else _solid, bm, Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), pos), col)


func _shape(m: Mesh, xf: Transform3D, col: Color, glow := false) -> void:
	_add(_glow if glow else _solid, m, xf, col)


func _cyl(top: float, bot: float, h: float, segs := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


func _commit() -> void:
	var solid := Figure.mat(Color.WHITE)
	solid.set_shader_parameter("vcol_albedo", true)
	solid.set_shader_parameter("facet", 1.0)
	Figure.finish(solid, "stone")
	_mesh(_solid, solid, true)
	var glow := Figure.mat(Color.WHITE, float(cfg.get("window_glow", 1.4)))
	glow.set_shader_parameter("vcol_albedo", true)
	_mesh(_glow, glow, false)
	var pools := ShaderMaterial.new()
	pools.shader = POOL_SHADER
	pools.set_shader_parameter("strength", float(cfg.get("pool_strength", 0.5)))
	_mesh(_pools, pools, false)


func _mesh(st: SurfaceTool, m: Material, shadows: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- the plaza ----------------------------------------------------------------------

## Cobbles over the whole yard: rows of setts, each a little higher or lower and a shade
## lighter or darker, over the dark grout of the ground. Their tops stay under the telegraph
## decal (view3d lays it at 6 cm).
func _cobbles() -> void:
	var b: Rect2 = view.arena.BOUNDS
	var lo: Vector3 = view.to_world(b.position)
	var hi: Vector3 = view.to_world(b.end)
	var tile := float(cfg.get("cobble_m", 0.7))
	var row := 0
	var z := lo.z + tile * 0.5
	while z < hi.z:
		var x := lo.x + tile * (0.5 if row % 2 == 0 else 0.0)
		while x < hi.x:
			var w := minf(tile, hi.x - x + tile * 0.5) - 0.08
			if w > 0.15:
				var top := rng.randf_range(0.0, 0.035)
				var col := c("cobble").lerp(c("cobble2"), rng.randf())
				_box(Vector3(w, 0.08 + top, tile - 0.08), Vector3(x, (top - 0.08) * 0.5, z), col)
			x += tile
		z += tile
		row += 1


## A stone kerb round the plaza, open at the four gates.
func _kerb() -> void:
	var b: Rect2 = view.arena.BOUNDS
	var lo: Vector3 = view.to_world(b.position)
	var hi: Vector3 = view.to_world(b.end)
	var gap := float(cfg.get("gate_gap_m", 2.6)) * 0.5
	var out := 0.25
	var gates: Array = []
	for g in view.arena.GATES:
		gates.append(view.to_world(g))
	var sides := [[Vector3(lo.x - out, 0, lo.z - out), Vector3(hi.x + out, 0, lo.z - out)],
		[Vector3(lo.x - out, 0, hi.z + out), Vector3(hi.x + out, 0, hi.z + out)],
		[Vector3(lo.x - out, 0, lo.z - out), Vector3(lo.x - out, 0, hi.z + out)],
		[Vector3(hi.x + out, 0, lo.z - out), Vector3(hi.x + out, 0, hi.z + out)]]
	for sd in sides:
		var a: Vector3 = sd[0]
		var e: Vector3 = sd[1]
		# split the side round any gate on it
		var cuts: Array = [0.0]
		var len := a.distance_to(e)
		var dir := (e - a) / len
		for g: Vector3 in gates:
			var t: float = (g - a).dot(dir)
			var off: float = ((g - a) - dir * t).length()
			if off < 1.0 and t > 0.0 and t < len:
				cuts.append(t - gap)
				cuts.append(t + gap)
		cuts.append(len)
		for k in range(0, cuts.size(), 2):
			var t0: float = cuts[k]
			var t1: float = cuts[k + 1]
			if t1 - t0 < 0.1:
				continue
			var mid := a + dir * (t0 + t1) * 0.5
			var size := Vector3(t1 - t0, 0.22, 0.45) if absf(dir.x) > 0.5 else Vector3(0.45, 0.22, t1 - t0)
			_box(size, mid + Vector3(0, 0.06, 0), c("kerb"))


func _house(at: Vector3, w: float, d: float, h: float, face: float, wall: Color, roof: Color) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(face))
	var p := func(local: Vector3) -> Vector3: return at + basis * local
	var box := func(size: Vector3, local: Vector3, col: Color, glow := false) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_add(_glow if glow else _solid, bm, Transform3D(basis, p.call(local)), col)
	box.call(Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	box.call(Vector3(w + 0.1, 0.7, d + 0.1), Vector3(0, 0.35, 0), c("stone"))
	# timber frame on the front: posts, a beam under each floor and one under the eaves
	var posts := maxi(1, int(w / 1.3))
	for k in posts + 1:
		box.call(Vector3(0.14, h - 0.7, 0.1), Vector3(-w * 0.5 + k * (w / posts), h * 0.5 + 0.35, d * 0.5 + 0.03), c("timber"))
	var floors := maxi(1, int(h / 2.3))
	for f in floors + 1:
		box.call(Vector3(w, 0.14, 0.12), Vector3(0, 0.7 + f * (h - 0.7) / floors, d * 0.5 + 0.04), c("timber"))
	# windows, most lit; a door on the ground floor
	var cols := maxi(1, int(w / 1.4))
	for f in floors:
		var y := 0.7 + (f + 0.5) * (h - 0.7) / floors
		for k in cols:
			var wx := -w * 0.5 + (k + 0.5) * w / cols
			if f == 0 and k == cols - 1:
				box.call(Vector3(0.8, 1.5, 0.08), Vector3(wx, 1.45, d * 0.5 + 0.06), c("timber"))
				continue
			var lit := rng.randf() < 0.75
			box.call(Vector3(0.5, 0.7, 0.06), Vector3(wx, y, d * 0.5 + 0.06), c("window") if lit else c("dark_window"), lit)
	# roof: a prism along the width, and a chimney
	var pm := PrismMesh.new()
	pm.size = Vector3(d + 0.6, h * 0.45, w + 0.4)
	_shape(pm, Transform3D(basis * Basis(Vector3.UP, PI / 2.0), p.call(Vector3(0, h + h * 0.225, 0))), roof)
	box.call(Vector3(0.4, 1.2, 0.4), Vector3(-w * 0.3, h + h * 0.35, -d * 0.15), c("stone"))


func _stall(at: Vector3, rot: float, cloth: Color) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot))
	var put := func(size: Vector3, local: Vector3, col: Color, glow := false) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_add(_glow if glow else _solid, bm, Transform3D(basis, at + basis * local), col)
	put.call(Vector3(2.2, 0.9, 1.0), Vector3(0, 0.45, 0), c("timber"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			put.call(Vector3(0.08, 2.1, 0.08), Vector3(sx * 1.05, 1.05, sz * 0.45), c("timber"))
	var pm := PrismMesh.new()
	pm.size = Vector3(2.6, 0.55, 1.4)
	_shape(pm, Transform3D(basis, at + basis * Vector3(0, 2.35, 0)), cloth)
	for i in 4:
		put.call(Vector3(0.28, 0.22, 0.28), Vector3(-0.75 + i * 0.5, 1.0, 0.1), [c("cloth2"), c("leaf"), c("cloth"), c("brass")][i])
	put.call(Vector3(0.22, 0.26, 0.22), Vector3(0.9, 1.05, -0.3), c("window"), true)


func _tree(at: Vector3, s: float) -> void:
	_shape(_cyl(0.12 * s, 0.18 * s, 1.6 * s, 5), Transform3D(Basis(), at + Vector3(0, 0.8 * s, 0)), c("timber"))
	for i in 3:
		var sm := SphereMesh.new()
		sm.radius = (0.9 - i * 0.2) * s
		sm.height = sm.radius * 1.7
		sm.radial_segments = 6
		sm.rings = 3
		var off := Vector3(rng.randf_range(-0.2, 0.2), (1.7 + i * 0.5) * s, rng.randf_range(-0.2, 0.2))
		_shape(sm, Transform3D(Basis(), at + off), c("leaf") if i % 2 == 0 else c("leaf2"))
	_box(Vector3(1.1 * s, 0.45, 1.1 * s), at + Vector3(0, 0.22, 0), c("stone"))


## A prop model (barrels, crates, a cart, a well), merged in its own recipe colours.
func _prop(id: String, at: Vector3, rot: float, s: float) -> void:
	var n: Node3D = (load("res://assets/models/props/%s.glb" % id) as PackedScene).instantiate()
	var root_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(rot)).scaled(Vector3.ONE * s), at)
	_prop_meshes(n, root_xf)
	n.free()


func _prop_meshes(n: Node, parent: Transform3D) -> void:
	var xf := parent
	if n is Node3D:
		xf = parent * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			var col: Color = src.albedo_color if src != null else Color.GRAY
			var one := ArrayMesh.new()
			one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
			_add(_solid, one, xf, col.darkened(float(cfg.get("prop_darken", 0.1))))
	for ch in n.get_children():
		_prop_meshes(ch, xf)


## A lamp post with a glowing lantern and a warm pool of light on the ground under it.
func _lamp(at: Vector3) -> void:
	_shape(_cyl(0.06, 0.08, 2.6, 5), Transform3D(Basis(), at + Vector3(0, 1.3, 0)), c("iron"))
	_box(Vector3(0.32, 0.38, 0.32), at + Vector3(0, 2.75, 0), c("window"), 0.0, true)
	_shape(_cyl(0.0, 0.28, 0.28, 4), Transform3D(Basis(), at + Vector3(0, 3.08, 0)), c("iron"))
	var r := float(cfg.get("pool_m", 3.2))
	var col := Color(str(cfg.get("lamp_color", "ffb060")))
	var y := 0.07
	var q := [Vector3(-r, y, -r), Vector3(r, y, -r), Vector3(r, y, r), Vector3(-r, y, r)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		_pools.set_color(col)
		_pools.set_uv(uv[k])
		_pools.add_vertex(at + q[k])
