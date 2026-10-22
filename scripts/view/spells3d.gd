extends RefCounted
## The spells as low-poly shapes: every shot, stone, burst and lingering field object is a few
## flat-shaded facets in its element's colour. Bursts and rings shrink away instead of fading, so
## the shapes stay solid; round the hot ones a soft halo glows into the bloom (Magicka's look). The
## telegraphs that are hitboxes (rings, cones, lines on the ground) stay the arena's own marks,
## laid on the ground by the view. Reads the sim each frame and never changes it.

const Figure := preload("res://scripts/view/figure.gd")
const HALO_SHADER := preload("res://scripts/view/halo.gdshader")

var view
var arena
var _pools := {}  # kind -> Array of nodes
var _used := {}
## The ground's fires (one per burning cell, often dozens) as two batches, flames and their
## glow, so a grass fire costs two draw calls instead of four per cell.
var _cell_fires: Array = []  # this frame's burning-cell zones
var _fire_mm: MultiMeshInstance3D
var _fire_halo_mm: MultiMeshInstance3D
const CELL_HALOS := 40  # the nearest this many cell fires glow; the rest are flames only
const CELL_LIGHTS := 2  # and the nearest this many ask for a light


func _init(the_view) -> void:
	view = the_view
	arena = the_view.arena


# --- shapes ---------------------------------------------------------------------------

## An octahedron stretched `len` along -Z (pointing where it flies).
static func octa(r: float, len := 1.0) -> ArrayMesh:
	var p := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, -r * len), Vector3(0, 0, r * len * 0.6)]
	var f := [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	return _tris(p, f)


static func tetra(r: float) -> ArrayMesh:
	var p := [Vector3(0, r, 0), Vector3(r * 0.94, -r * 0.33, 0), Vector3(-r * 0.47, -r * 0.33, r * 0.82), Vector3(-r * 0.47, -r * 0.33, -r * 0.82)]
	return _tris(p, [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]])


static func _tris(p: Array, faces: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		for i in f:
			st.add_vertex(p[i])
	st.generate_normals()
	return st.commit()


## A rough rock: a coarse sphere with its rings pulled about.
static func rock(r: float, seed_v: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.6
	sm.radial_segments = 6
	sm.rings = 3
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var moved := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = verts[i] * rng.randf_range(0.8, 1.15)
		verts[i] = moved[key]
	arr[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _mi(mesh: Mesh, col: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Figure.fade_mat(col, glow)  # two-sided: octa and tetra are wound by hand
	if glow > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func paint(n: Node, col: Color, glow: float) -> void:
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("albedo", col)
		m.set_shader_parameter("glow", glow)
	for c in n.get_children():
		paint(c, col, glow)


# --- pools --------------------------------------------------------------------------------

func take(kind: String) -> Node3D:
	if not _pools.has(kind):
		_pools[kind] = []
	var pool: Array = _pools[kind]
	var i: int = _used.get(kind, 0)
	_used[kind] = i + 1
	if i < pool.size():
		pool[i].visible = true
		pool[i].scale = Vector3.ONE
		pool[i].rotation = Vector3.ZERO
		return pool[i]
	var n := _make(kind, pool.size())
	view.add_child(n)
	pool.append(n)
	return n


## Every shape _make builds, for warm_up.
const KINDS := ["halo", "gem", "orb", "fireball", "rock", "boulder", "shard", "cube", "stick", "ring", "flame",
	"spikes", "rod", "tome", "whirl"]


## Shows one of every shape round `at` this frame, so the browser compiles their shaders now
## (behind the title) instead of in the middle of the first scene that casts them.
func warm_up(at: Vector3) -> void:
	for i in KINDS.size():
		var a := i * TAU / KINDS.size()
		take(KINDS[i]).position = at + Vector3(cos(a), 0.2 * (i % 3), sin(a)) * 1.5
	_cell_fires = [{"t": 0.0, "pos": arena.player.pos + Vector2(0, 30)}]  # and the ground's fires
	_ground_fires()


func _make(kind: String, i: int) -> Node3D:
	match kind:
		"halo":
			var mi := MeshInstance3D.new()
			mi.mesh = QuadMesh.new()
			var hm := ShaderMaterial.new()
			hm.shader = HALO_SHADER
			mi.material_override = hm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return mi
		"gem":
			return _mi(octa(0.12, 2.2), Color.WHITE, 1.5)
		"orb":
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			sm.radial_segments = 6
			sm.rings = 3
			return _mi(sm, Color.WHITE, 1.5)
		"fireball":
			# A comet (League of Legends' Brand Q as the reference): a round white-hot core in an
			# orange shell, and flame tongues streaming back from it, longer than the head.
			# Built along -Z, the way it flies.
			var n := Node3D.new()
			var core := SphereMesh.new()
			core.radius = 0.1
			core.height = 0.2
			core.radial_segments = 6
			core.rings = 3
			var cm := _mi(core, PixelArt.FIRE_HOT, 1.0)
			cm.name = "Core"
			cm.position.z = -0.1  # the white-hot nose pokes out the front of the shell
			n.add_child(cm)
			var shell := SphereMesh.new()
			shell.radius = 0.17
			shell.height = 0.3
			shell.radial_segments = 7
			shell.rings = 3
			var sm := _mi(shell, PixelArt.FIRE, 0.5)
			sm.name = "Shell"
			n.add_child(sm)
			var tail := Node3D.new()
			tail.name = "Tail"
			n.add_child(tail)
			var tongues := [[0.15, 0.75, Vector3(0, 0, 0)], [0.09, 0.55, Vector3(0.07, 0.05, 0)], [0.08, 0.5, Vector3(-0.06, -0.04, 0)], [0.06, 0.4, Vector3(0, 0.08, 0)]]
			for k in tongues.size():
				var t: Array = tongues[k]
				var tc := CylinderMesh.new()
				tc.top_radius = 0.0
				tc.bottom_radius = t[0]
				tc.height = t[1]
				tc.radial_segments = 5
				tc.rings = 1
				var tm := _mi(tc, PixelArt.FIRE if k == 0 else PixelArt.FIRE.lerp(PixelArt.DANGER, 0.5), 0.6)
				tm.rotation_degrees.x = 90.0  # the cone's tip points back (+Z), its wide base at the head
				tm.position = t[2] + Vector3(0, 0, t[1] * 0.5 + 0.02)
				tail.add_child(tm)
			return n
		"rock":
			return _mi(rock(0.17, 11 + i), PixelArt.EARTH.darkened(0.2))
		"boulder":
			return _mi(rock(0.45, 91 + i), PixelArt.EARTH.darkened(0.25), 0.0)
		"shard":
			return _mi(tetra(0.09), Color.WHITE, 1.5)
		"cube":
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * 0.12
			return _mi(bm, Color("a08a6a"))
		"stick":
			# a thin hexagonal rod one metre long along -Z, for streaks, beams and lightning
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.0
			cm.height = 1.0
			cm.radial_segments = 5
			cm.rings = 1
			var mi := _mi(cm, Color.WHITE, 2.0)
			mi.rotation_degrees.x = 90.0
			var n := Node3D.new()
			n.add_child(mi)
			return n
		"ring":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.85
			tm.outer_radius = 1.0
			tm.rings = 10
			tm.ring_segments = 3
			return _mi(tm, Color.WHITE, 1.5)
		"flame":
			var n := Node3D.new()
			for k in 3:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.13 - 0.03 * k
				cm.height = 0.5 - 0.12 * k
				cm.radial_segments = 4
				cm.rings = 1
				var mi := _mi(cm, PixelArt.FIRE if k < 2 else PixelArt.FIRE_HOT, 1.6)
				mi.position = Vector3((k - 1) * 0.08, cm.height * 0.5, (k % 2) * 0.05)
				n.add_child(mi)
			return n
		"spikes":
			# Pillar: a ring of stone spikes round a fire core
			var n := Node3D.new()
			for k in 6:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.22
				cm.height = 1.2 + 0.3 * (k % 2)
				cm.radial_segments = 5
				cm.rings = 1
				var mi := _mi(cm, PixelArt.EARTH.darkened(0.2))
				var a := TAU * k / 6.0
				mi.position = Vector3(cos(a) * 0.55, cm.height * 0.35, sin(a) * 0.55)
				mi.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
				n.add_child(mi)
			var core := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.15
			cc.bottom_radius = 0.35
			cc.height = 1.8
			cc.radial_segments = 6
			cc.rings = 1
			core.mesh = cc
			core.material_override = Figure.mat(PixelArt.FIRE, 1.8)
			core.position.y = 0.9
			core.name = "Core"
			n.add_child(core)
			return n
		"rod":
			var n := Node3D.new()
			var pole := MeshInstance3D.new()
			pole.mesh = Figure._cyl(0.03, 0.04, 0.9, 5)
			pole.position.y = 0.45
			pole.material_override = Figure.mat(PixelArt.STEEL)
			n.add_child(pole)
			var tip := _mi(octa(0.08, 1.0), PixelArt.STORM, 1.5)
			tip.position.y = 0.98
			tip.rotation_degrees.x = 90.0
			tip.name = "Tip"
			n.add_child(tip)
			return n
		"tome":
			var n := Node3D.new()
			for sx in [-1.0, 1.0]:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.22, 0.03, 0.3)
				var page := _mi(bm, PixelArt.PAPER)
				page.position = Vector3(0.11 * sx, 0, 0)
				page.rotation_degrees.z = -12.0 * sx
				n.add_child(page)
			var gem := _mi(octa(0.05, 1.0), PixelArt.GOLD, 1.5)
			gem.position.y = 0.12
			n.add_child(gem)
			return n
		"whirl":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.7
			tm.outer_radius = 1.0
			tm.rings = 8
			tm.ring_segments = 3
			return _mi(tm, PixelArt.WATER, 0.6)
	return Node3D.new()


# --- every frame --------------------------------------------------------------------------

func sync(_delta: float) -> void:
	_used.clear()
	var glow_k: float = view.spell_k()
	_stones()
	_projs(glow_k)
	_cell_fires.clear()
	_zones(glow_k)
	_ground_fires()
	_fx(glow_k)
	for kind in _pools:
		var pool: Array = _pools[kind]
		for i in range(_used.get(kind, 0), pool.size()):
			pool[i].visible = false


## A glow `d` metres across round `at`. Fainter in the waves, brightest in the duel (view.spell_k()).
func halo(at: Vector3, col: Color, d: float, strength := 1.0) -> void:
	if d <= 0.01 or strength <= 0.01:
		return
	var h := take("halo") as MeshInstance3D
	h.position = at
	h.scale = Vector3.ONE * d
	var m := h.material_override as ShaderMaterial
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("strength", strength * lerpf(0.55, 1.0, view.spell_k()))


func _w(p: Vector2, h := 0.0) -> Vector3:
	return view.to_world(p, h)


func _glow(glow_k: float, dim := 0.9, full := 1.8) -> float:
	return lerpf(dim, full, glow_k)


func _stones() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s in arena.stones:
		var r := take("rock")
		var p: Vector2 = s["pos"]
		var h := 0.12
		match s["state"]:
			"orbit", "return", "recall":
				p += Vector2(0, 4)
				h = 1.1
			"flung":
				h = 0.6
			"slam":
				h = 1.0 + maxf(0.0, float(s.get("delay", 0.0))) * 3.0
		r.position = _w(p, h)
		r.rotation = Vector3(t * 1.3, t * 2.0 + p.x, 0)


## Shots fly low (knee to hip), pointing along their velocity: fire as a comet, storm as a
## glowing crystal with a spark or two behind, pebbles and thrown stones as rocks. The solid part
## of a shot is drawn the size of its hitbox (a touch over), and only halos and tails reach past
## it, tails always behind. Each shot also casts a ground shadow exactly its hitbox (arena.gd
## _draw_marks), so where it will hit reads off the ground (design/magic-world-revisit.md §2).
const SHOT_SCALE := 1.1
const SHOT_HEIGHT := 0.4
## The radius each shot mesh is built at, so it can be scaled to its hitbox.
const SHOT_BASE := {"rock": 0.17, "fireball": 0.17, "gem": 0.12}


func _projs(glow_k: float) -> void:
	for p in arena.projs:
		if p.get("ghost", false):
			continue
		var at := _w(p["pos"], SHOT_HEIGHT)
		var v: Vector2 = p["vel"]
		var dir := Vector3(v.x, 0, v.y).normalized() if v.length() > 0.1 else Vector3.FORWARD
		var col: Color = p["color"]
		var hit_m: float = float(p["r"]) * view.S  # the hitbox radius in metres
		match p["kind"]:
			"pebble", "rock":
				var size: float = hit_m / SHOT_BASE["rock"] * SHOT_SCALE
				var r := take("rock")
				r.position = at
				r.scale = Vector3.ONE * size
				r.rotation = Vector3(p["t"] * 9.0, p["t"] * 6.0, 0)
			"bolt":
				# a crossbow bolt: a dark shaft, no glow
				_stick(at - dir * 0.35, at + dir * 0.35, 0.035, Color("5a4630"), 0.0)
			"net":
				var n := take("ring")
				n.position = at
				n.rotation = Vector3(0, p["t"] * 6.0, 0)
				n.scale = Vector3.ONE * hit_m * 2.2
				paint(n, PixelArt.PAPER, 0.3)
			"ember", "pyro":
				var size: float = hit_m / SHOT_BASE["fireball"] * SHOT_SCALE
				var fb := take("fireball")
				fb.position = at
				fb.look_at(at + dir, Vector3.UP)
				fb.scale = Vector3.ONE * size
				var tail: Node3D = fb.get_node("Tail")
				tail.rotation.z = p["t"] * 9.0
				tail.scale = Vector3(1.0, 1.0, 1.1 + 0.3 * sin(p["t"] * 31.0))
				# kept low enough that the shell stays orange instead of blowing out to white
				var gl := _glow(glow_k, 0.45, 0.8)
				paint(fb.get_node("Core"), PixelArt.FIRE_HOT, gl * 2.0)
				paint(fb.get_node("Shell"), PixelArt.FIRE, gl)
				for k in tail.get_child_count():
					var tm: MeshInstance3D = tail.get_child(k)
					tm.material_override.set_shader_parameter("glow", gl * 0.9)
				# embers shed behind it
				for k in 2:
					var sh := take("shard")
					var back := fmod(p["t"] * 3.0 + k * 0.5, 1.0)
					sh.position = at - dir * (0.5 + 0.9 * back) * size + Vector3(_jit(k, 1) * 0.1, 0.1 * back, 0)
					sh.scale = Vector3.ONE * size * 0.6 * (1.0 - back)
					sh.rotation = Vector3(p["t"] * 11.0 + k, p["t"] * 7.0, 0)
					paint(sh, PixelArt.FIRE_HOT, gl * 1.5)
				halo(at, PixelArt.FIRE, 0.75 * size, 1.4)
				halo(at - dir * 0.3 * size, PixelArt.FIRE.lerp(PixelArt.DANGER, 0.3), 0.6 * size, 0.8)
				view.want_light(at, PixelArt.FIRE, 1.6, 3.5)
			_:
				var fire := false
				var size: float = hit_m / SHOT_BASE["gem"] * SHOT_SCALE
				var g := take("gem")
				g.position = at
				g.look_at(at + dir, Vector3.UP)
				g.rotate_object_local(Vector3.FORWARD, p["t"] * 14.0)
				g.scale = Vector3.ONE * size
				paint(g, col, _glow(glow_k, 1.0, 2.0))
				for k in 2:
					var sh := take("shard")
					sh.position = at - dir * (0.25 + 0.22 * k) * size + Vector3(0, 0.05 * sin(p["t"] * 20.0 + k), 0)
					sh.scale = Vector3.ONE * size * (0.8 - 0.25 * k)
					sh.rotation = Vector3(p["t"] * 11.0 + k, p["t"] * 7.0, 0)
					paint(sh, PixelArt.FIRE_HOT if fire else col.lightened(0.3), _glow(glow_k, 1.0, 2.0))
				halo(at, col, minf(0.55 * size, 1.3), 1.3)
				if fire:
					view.want_light(at, PixelArt.FIRE, 1.6, 3.5)
				else:
					view.want_light(at, col, 1.0, 2.5)


func _zones(glow_k: float) -> void:
	# a burning enemy (N-6.2): a flame on its back
	for u in arena.units:
		if u.burn_t > 0.0 and not u.dead:
			var f := take("flame")
			f.position = _w(u.shown_pos(), 0.5)
			f.scale = Vector3(0.6, 0.7 + 0.2 * sin(u.anim * 14.0), 0.6)
			halo(_w(u.shown_pos(), 0.8), PixelArt.FIRE, 1.0, 0.8)
		if u.dead:
			continue
		# brigands' gear (N-6.3): a Shieldman's wooden shield toward you, a Powder Monkey's keg on his back
		if u.kind == "shieldman" and not u.flags.get("shield_gone", false):
			var front: Vector2 = (arena.player.pos - u.pos).normalized()
			var sh := take("cube")
			sh.position = _w(u.shown_pos() + front * 5.0, 0.75)
			sh.look_at(_w(u.shown_pos() + front * 20.0, 0.75), Vector3.UP)
			sh.scale = Vector3(4.6, 6.0, 0.7)
			paint(sh, Color("6a4a2c"), 0.0)
		elif u.kind == "powder_monkey" and not u.flags.get("keg_gone", false):
			var back: Vector2 = (u.pos - arena.player.pos).normalized()
			var kg := take("cube")
			kg.position = _w(u.shown_pos() + back * 3.5, 0.85)
			kg.scale = Vector3(2.6, 3.2, 2.6)
			paint(kg, Color("4a3424"), 0.0)
	for z in arena.zones:
		var t: float = z["t"]
		match z["kind"]:
			"ember", "blaze":
				if z.has("cell"):
					_cell_fires.append(z)
					continue
				var f := take("flame")
				f.position = _w(z["pos"])
				var fade := clampf((z["life"] - t) / 1.0, 0.3, 1.0)
				f.scale = Vector3(1.0, (0.8 + 0.25 * sin(t * 13.0 + z["pos"].x)) * fade, 1.0)
				f.rotation.y = t * 0.7 + z["pos"].x
				halo(_w(z["pos"], 0.45), PixelArt.FIRE, 1.6 * fade, 0.9)
				view.want_light(_w(z["pos"], 0.5), PixelArt.FIRE, 1.4 * fade, 3.0)
			"column":
				# Pillar erupts: stone spikes punch up round a fire core, then sink
				var c := take("spikes")
				var k: float = clampf(t / z["life"], 0.0, 1.0)
				var up := minf(1.0, k * 5.0) * (1.0 - smoothstep(0.6, 1.0, k))
				var r: float = float(z["r"]) * view.S / 1.1
				c.position = _w(z["pos"], -1.0 + up)
				c.scale = Vector3(r, 1.0, r)
				paint(c.get_node("Core"), PixelArt.FIRE.lerp(PixelArt.FIRE_HOT, 1.0 - k), _glow(glow_k, 1.2, 2.4))
				halo(_w(z["pos"], 0.6), PixelArt.FIRE, r * 2.6 * up, 1.2 * (1.0 - k))
				view.want_light(_w(z["pos"], 1.0), PixelArt.FIRE, 3.0 * (1.0 - k), 5.0)
			"meteor":
				var k := clampf(t / z["delay"], 0.0, 1.0)
				var b := take("boulder")
				b.position = _w(z["pos"] + Vector2(-20, 0) * (1.0 - k), 0.3 + 7.0 * (1.0 - k))
				b.rotation = Vector3(t * 4.0, t * 3.0, 0)
				paint(b, PixelArt.EARTH.lerp(PixelArt.FIRE, 0.5), _glow(glow_k, 0.6, 1.2))
				var tail := take("shard")
				tail.position = b.position + Vector3(0.4, 0.8, 0)
				tail.scale = Vector3.ONE * 2.5
				paint(tail, PixelArt.FIRE_HOT, 2.0)
				halo(b.position, PixelArt.FIRE, 2.4, 1.3)
				view.want_light(b.position, PixelArt.FIRE, 2.0, 5.0)
			"ring":
				# The Warden's fire ring: low flames along the band, none in its gap
				if t < float(z["wait"]):
					continue
				var r: float = z.get("r", z["r0"])
				var half: float = z["gap"] * 0.5
				for i in 10:
					var a: float = float(z["gap_a"]) + half + (TAU - 2.0 * half) * (i + 0.5) / 10.0
					var f := take("flame")
					f.position = _w(z["pos"] + Vector2(cos(a), sin(a)) * r)
					f.scale = Vector3(0.8, 0.6 + 0.2 * sin(t * 11.0 + i), 0.8)
				view.want_light(_w(z["pos"], 1.0), PixelArt.FIRE, 1.6, 4.0)
			"gravel":
				for i in 6:
					var a := i * 2.4
					var o := Vector2(cos(a), sin(a)) * fmod(i * 3.7, z["r"])
					var r := take("rock")
					r.position = _w(z["pos"] + o, 0.05)
					r.scale = Vector3.ONE * 0.45
					r.rotation = Vector3(a, a * 2.0, 0)
			"pot":
				# a Powder Monkey's pot arcing to its circle, once he has thrown it
				if t >= float(z["fly_at"]):
					var k := clampf((t - float(z["fly_at"])) / maxf(0.01, float(z["delay"]) - float(z["fly_at"])), 0.0, 1.0)
					var o := take("orb")
					o.position = _w(z["from"].lerp(z["pos"], k), SHOT_HEIGHT + 1.6 * sin(PI * k))
					o.scale = Vector3.ONE * 0.5
					paint(o, Color("3a2a1e"), 0.0)
			"throw":
				# a Spark Artifice device in flight: a glass flask arcing to where it lands (N-5.2)
				var k := clampf(t / maxf(0.01, float(z["delay"])), 0.0, 1.0)
				var o := take("orb")
				o.position = _w(z["from"].lerp(z["pos"], k), SHOT_HEIGHT + 1.4 * sin(PI * k))
				o.scale = Vector3.ONE * 0.6
				var col: Color = PixelArt.STORM if z["device"] == "arc_rod" else (PixelArt.FIRE if z["device"] == "spark_flask" else PixelArt.PAPER)
				paint(o, col, _glow(glow_k, 0.8, 1.6))
			"lantern":
				# the Star Lantern hangs at head height, a gold light (N-5.3)
				var o := take("orb")
				o.position = _w(z["pos"], 1.5 + 0.08 * sin(t * 2.0))
				o.scale = Vector3.ONE * 0.9
				paint(o, PixelArt.GOLD, _glow(glow_k, 1.4, 2.4))
				halo(o.position, PixelArt.GOLD, 1.6, 1.0)
				view.want_light(o.position, PixelArt.GOLD, 1.6, 5.0)
			"arc_rod":
				var r := take("rod")
				r.position = _w(z["pos"])
				var lit: bool = z.get("zap_t", 1.0) > float(Progression.spell("arc_rod")["zap_every"]) - 0.15
				paint(r.get_node("Tip"), PixelArt.GOLD, 2.4 if lit else 0.8)
				r.get_node("Tip").rotation.y = t * 2.0
				if lit:
					halo(r.get_node("Tip").global_position, PixelArt.STORM, 0.7, 1.4)
					view.want_light(_w(z["pos"], 1.0), PixelArt.STORM, 0.8, 2.0)
			"rod":
				var r := take("rod")
				r.position = _w(z["pos"])
				var lit: bool = z.get("zap_t", 1.0) < 0.15 or int(t * 4.0) % 2 == 0
				paint(r.get_node("Tip"), PixelArt.STORM, 2.4 if lit else 0.6)
				r.get_node("Tip").rotation.y = t * 3.0
				if lit:
					halo(r.get_node("Tip").global_position, PixelArt.STORM, 0.7, 1.4)
					view.want_light(_w(z["pos"], 1.0), PixelArt.STORM, 0.8, 2.0)
			"whirl":
				for i in 2:
					var w := take("whirl")
					var r: float = float(z["r"]) * view.S * (0.55 + 0.4 * i)
					w.position = _w(z["pos"], 0.08 + 0.1 * i)
					w.scale = Vector3(r, 1.0, r)
					w.rotation.y = -t * (4.0 - i)
			"tome":
				var b := take("tome")
				b.position = _w(z["pos"], 0.55 + 0.06 * sin(t * 3.0))
				b.rotation.y = t * 0.8
				halo(b.position, PixelArt.GOLD, 0.8, 0.8)
				view.want_light(b.position, PixelArt.GOLD, 0.8, 2.0)
			"rewind_form", "rline":
				# Hours: a shard grows where a stone or a Rewind will appear, before it flies home
				var k := clampf(t / maxf(0.01, float(z.get("delay", 1.0))), 0.0, 1.0)
				var at2: Vector2 = z["pos"] if z["kind"] == "rewind_form" else z["a"]
				var g := take("gem")
				g.position = _w(at2, SHOT_HEIGHT + 0.2 * (1.0 - k))
				g.rotation = Vector3(0, t * 6.0, 0.4)
				g.scale = Vector3.ONE * (0.4 + 1.2 * k)
				paint(g, PixelArt.HOURS, _glow(glow_k, 1.0, 2.0))
				halo(g.position, PixelArt.HOURS, 0.6 + 0.6 * k, 1.2 * k)
				view.want_light(g.position, PixelArt.HOURS, 1.2 * k, 2.5)
			"storm", "strike":
				var k := clampf(t / maxf(0.01, float(z.get("delay", 1.0))), 0.0, 1.0)
				view.want_light(_w(z["pos"], 1.0), PixelArt.STORM, 0.6 * k, float(z["r"]) * view.S * 2.0)


## The burning cells: every flame in one batch, and a glow and a light for the nearest few.
func _ground_fires() -> void:
	var n := _cell_fires.size()
	if _fire_mm == null:
		if n == 0:
			return
		_fire_mm = _batch(flame_mesh(), Figure.fade_mat(Color.WHITE, 1.6))
		_fire_mm.material_override.set_shader_parameter("vcol_albedo", true)
		var hm := ShaderMaterial.new()
		hm.shader = HALO_SHADER
		hm.set_shader_parameter("color", PixelArt.FIRE)
		_fire_halo_mm = _batch(QuadMesh.new(), hm)
	_fire_mm.visible = n > 0
	_fire_halo_mm.visible = n > 0
	if n == 0:
		return
	var at: Vector2 = arena.player.pos
	_cell_fires.sort_custom(func(a, b): return a["pos"].distance_squared_to(at) < b["pos"].distance_squared_to(at))
	var mm := _fire_mm.multimesh
	if mm.instance_count < n:
		mm.instance_count = n + 32
	mm.visible_instance_count = n
	var halos := mini(n, CELL_HALOS)
	var hmm := _fire_halo_mm.multimesh
	if hmm.instance_count < halos:
		hmm.instance_count = CELL_HALOS
	hmm.visible_instance_count = halos
	_fire_halo_mm.material_override.set_shader_parameter("strength", 0.9 * lerpf(0.55, 1.0, view.spell_k()))
	for i in n:
		var z: Dictionary = _cell_fires[i]
		var t: float = z["t"]
		var x: float = z["pos"].x
		var b := Basis(Vector3.UP, t * 0.7 + x).scaled(Vector3(1.0, 0.8 + 0.25 * sin(t * 13.0 + x), 1.0))
		mm.set_instance_transform(i, Transform3D(b, _w(z["pos"])))
		if i < halos:
			hmm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 1.6), _w(z["pos"], 0.45)))
		if i < CELL_LIGHTS:
			view.want_light(_w(z["pos"], 0.5), PixelArt.FIRE, 1.4, 3.0)


func _batch(mesh: Mesh, m: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(mi)
	return mi


## The "flame" shape's three cones as one mesh, coloured by vertex (for the ground's fires).
static func flame_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.13 - 0.03 * k
		cm.height = 0.5 - 0.12 * k
		cm.radial_segments = 4
		cm.rings = 1
		var arr := cm.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var off := Vector3((k - 1) * 0.08, cm.height * 0.5, (k % 2) * 0.05)
		st.set_color((PixelArt.FIRE if k < 2 else PixelArt.FIRE_HOT).srgb_to_linear())
		for j in arr[Mesh.ARRAY_INDEX]:
			st.set_normal(norms[j])
			st.add_vertex(verts[j] + off)
	return st.commit()


## A stick from `a` to `b`, `w` thick.
func _stick(a: Vector3, b: Vector3, w: float, col: Color, glow: float) -> void:
	var n := take("stick")
	var d := b - a
	if d.length() < 0.01:
		n.visible = false
		return
	n.position = (a + b) * 0.5
	n.look_at(b, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	n.scale = Vector3(w, w, d.length())
	paint(n, col, glow)


static func _jit(seed_v: float, i: int) -> float:
	return fract(sin(seed_v * 12.9898 + i * 78.233) * 43758.5453) * 2.0 - 1.0


static func fract(x: float) -> float:
	return x - floorf(x)


func _fx(glow_k: float) -> void:
	var g := _glow(glow_k, 1.2, 2.4)
	for f in arena.fxs:
		var k: float = f["t"] / f["life"]
		var left := 1.0 - k
		var col: Color = f.get("color", PixelArt.PAPER)
		var at := _w(f["pos"], 0.6)
		var seed_v: float = f["pos"].x * 0.37 + f["pos"].y * 1.31
		match f["kind"]:
			"burst", "clink":
				# shards fly out from the hit and shrink away
				var n := 7 if f["kind"] == "burst" else 4
				var r: float = float(f.get("r", 6.0)) * view.S * (0.4 + 0.9 * k)
				for i in n:
					var a := TAU * i / n + _jit(seed_v, i) * 0.4
					var sh := take("shard")
					sh.position = at + Vector3(cos(a) * r, 0.25 * sin(k * PI) + _jit(seed_v, i + 9) * 0.15, sin(a) * r)
					sh.scale = Vector3.ONE * left * (1.3 if f["kind"] == "burst" else 0.8)
					sh.rotation = Vector3(k * 8.0 + i, a, 0)
					paint(sh, col, g)
				if f["kind"] == "burst":
					halo(at, col, float(f.get("r", 6.0)) * view.S * 3.0 * (0.6 + 0.6 * k), 1.6 * left)
				if col == PixelArt.FIRE or col == PixelArt.FIRE_HOT or col == PixelArt.STORM:
					view.want_light(at, col, 1.5 * left, 3.0)
			"ring", "levelup":
				var rg := take("ring")
				var rr: float = float(f.get("r", 20.0)) * view.S * k if f["kind"] == "ring" else (0.4 + 1.2 * k)
				rg.position = _w(f["pos"], 0.06)
				rg.scale = Vector3(maxf(0.05, rr), left * 1.5, maxf(0.05, rr))
				paint(rg, col if f["kind"] == "ring" else PixelArt.GOLD, g)
				if f["kind"] == "levelup":
					for i in 6:
						var a := TAU * i / 6.0 + k * 3.0
						var sh := take("shard")
						sh.position = _w(f["pos"], 0.3 + 1.8 * k) + Vector3(cos(a) * 0.5, 0, sin(a) * 0.5)
						sh.scale = Vector3.ONE * left
						paint(sh, PixelArt.GOLD, g)
			"dust":
				for i in 5:
					var a := TAU * i / 5.0 + seed_v
					var c := take("cube")
					var r: float = float(f.get("r", 8.0)) * view.S * k
					c.position = _w(f["pos"], 0.1 + 0.4 * k) + Vector3(cos(a) * r, 0, sin(a) * r)
					c.scale = Vector3.ONE * (1.0 + k) * left * 1.4
					c.rotation = Vector3(a, k * 3.0, 0)
			"spark_line", "trail":
				_stick(at, _w(f["to"], 0.6), 0.04 * left, col, g)
			"beam":
				_stick(_w(f["pos"], 0.7), _w(f["to"], 0.7), float(f.get("w", 6.0)) * view.S * 0.4 * left, col, g)
				halo(_w(f["to"], 0.7), col, 1.2, 1.4 * left)
				view.want_light(_w(f["pos"].lerp(f["to"], 0.5), 0.8), col, 2.0 * left, 4.0)
			"zap":
				var a3 := _w(f["pos"], 0.8)
				var b3 := _w(f["to"], 0.8)
				var steps := maxi(2, int(a3.distance_to(b3) / 0.5))
				var side := (b3 - a3).cross(Vector3.UP).normalized()
				var prev := a3
				for i in range(1, steps + 1):
					var nxt := a3.lerp(b3, float(i) / steps)
					if i < steps:
						nxt += side * _jit(seed_v + floorf(k * 6.0), i) * 0.18 + Vector3(0, _jit(seed_v, i + 3) * 0.12, 0)
					_stick(prev, nxt, 0.035 * float(f.get("w", 1.0)) * left, col, g)
					prev = nxt
				halo(b3, col, 0.9, 1.5 * left)
				view.want_light((a3 + b3) * 0.5, col, 1.5 * left, 3.0)
			"bolt":
				var base := _w(f["pos"])
				var prev := base + Vector3(0.25, 5.0, -0.4)
				for i in range(1, 7):
					var nxt := base + Vector3(_jit(seed_v, i) * 0.3 if i < 6 else 0.0, 5.0 - i * (5.0 / 6.0), _jit(seed_v, i + 5) * 0.2 if i < 6 else 0.0)
					_stick(prev, nxt, 0.07 * left, col, g * 1.4)
					prev = nxt
				halo(base + Vector3(0, 0.4, 0), PixelArt.STORM, 2.4, 2.0 * left)
				view.want_light(base + Vector3(0, 1.5, 0), PixelArt.STORM, 3.0 * left, 5.0)
			"swipe":
				var dir: Vector2 = f["dir"]
				for i in 5:
					var a: float = dir.angle() + lerpf(-0.9, 0.9, i / 4.0)
					var sh := take("shard")
					sh.position = _w(f["pos"] + Vector2.from_angle(a) * float(f["r"]), 0.8)
					sh.scale = Vector3.ONE * left
					paint(sh, PixelArt.PAPER, g * 0.5)
			"spray":
				var dir: Vector2 = f["dir"]
				for i in 7:
					var a: float = dir.angle() + lerpf(-f["cone"] * 0.5, f["cone"] * 0.5, i / 6.0)
					var sh := take("shard")
					var d: float = float(f["r"]) * (0.3 + 0.7 * k) * (0.8 + 0.2 * fmod(i * 1.7, 1.0))
					sh.position = _w(f["pos"] + Vector2.from_angle(a) * d, 0.5 + 0.2 * sin(k * PI))
					sh.scale = Vector3.ONE * left * 1.2
					paint(sh, PixelArt.WATER, g * 0.6)
			"rise":
				var r := take("rock")
				r.position = _w(f["pos"], 0.2 + 2.0 * k)
				r.scale = Vector3.ONE * left
