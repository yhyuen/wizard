extends Node3D
## The fight seen as Wuxia sees its fights: ink figures, an ink-wash yard and props under a
## tilted camera, over the same 2D sim. The arena still simulates everything and still draws
## the flat marks (telegraphs, previews, zones, effects, the reticle) into an offscreen
## viewport, which lies on the ground here as a decal; this node adds what stands up off the
## ground: figures, lodestones, projectiles, flames, the Orrery, lightning. It reads the sim
## each frame and never changes it.

const Figure := preload("res://scripts/view/figure.gd")
const GROUND_SHADER := preload("res://scripts/view/ground.gdshader")
const OVERLAY_SHADER := preload("res://scripts/view/overlay.gdshader")
const CFG_PATH := "res://data/visual.json"
const SIM_CENTRE := Vector2(240, 135)
const SIM_SIZE := Vector2(480, 270)
const MAX_LIGHTS := 8

var arena
var cfg: Dictionary
var S := 0.0556  # metres per sim pixel
var camera: Camera3D
var overlay: SubViewport
var marks: Control  # pips and HP chunks over heads, in screen space

var _env: Environment
var _sun: DirectionalLight3D
var _ground: ShaderMaterial
var _overlay_mat: ShaderMaterial
var _mood := "day"
var _mood_k := 0.0  # 0 day .. 1 dusk, eased toward the target
var _mood_override := ""
var _figs := {}  # unit id -> {"node", "unit", "cast_t", "casts"}
var _pools := {}  # kind -> Array of nodes
var _used := {}  # kind -> how many used this frame
var _lights: Array[OmniLight3D] = []
var _light_wants: Array = []
var _shrine: Node3D
var _shrine_rings: Array = []
var _last_casts := 0
var _cast_t := 99.0
var _cam_base := Vector3.ZERO


func setup(the_arena, vp: SubViewport) -> void:
	arena = the_arena
	overlay = vp
	cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
	S = float(cfg["metres_per_px"])
	Figure.outline(Color(str(cfg["moods"]["day"]["outline"])), float(cfg["outline_px"]))


func _ready() -> void:
	_build_env()
	_build_ground()
	_build_overlay()
	_build_props()
	_build_shrine()
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
	camera = Camera3D.new()
	camera.fov = float(cfg["camera"]["fov"])
	add_child(camera)
	var o: Array = cfg["camera"]["offset"]
	var at: Array = cfg["camera"]["look_at"]
	var target := Vector3(at[0], at[1], at[2])
	_cam_base = target + Vector3(o[0], o[1], o[2])
	camera.position = _cam_base
	camera.look_at(target)
	camera.current = true
	_apply_mood(0.0)


# --- coordinates ----------------------------------------------------------------

func to_world(p: Vector2, h := 0.0) -> Vector3:
	return Vector3((p.x - SIM_CENTRE.x) * S, h, (p.y - SIM_CENTRE.y) * S)


## A sim point (and a height in metres) on screen, in the HUD's 960×540 coordinates.
func to_screen(p: Vector2, h := 0.0) -> Vector2:
	return camera.unproject_position(to_world(p, h))


## Where a screen point (HUD coordinates) meets the ground, in sim pixels.
func to_sim(screen: Vector2) -> Vector2:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return arena.mouse
	var hit := from + dir * (-from.y / dir.y)
	return Vector2(hit.x / S, hit.z / S) + SIM_CENTRE


static func face_rot(d: Vector2) -> float:
	return -atan2(d.y, d.x) + PI / 2.0


# --- building ---------------------------------------------------------------------

func _build_env() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_strength = 1.1
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.9
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)


func _build_ground() -> void:
	_ground = ShaderMaterial.new()
	_ground.shader = GROUND_SHADER
	var b: Rect2 = arena.BOUNDS
	_ground.set_shader_parameter("half_size", b.size * S * 0.5 + Vector2(1.5, 1.5))
	var g: Dictionary = cfg["ground"]
	var kinds := {"dirt": 0, "grass": 1, "wet": 2}
	var pats: Array = []
	for q in g["patches"]:
		var w := to_world(Vector2(q[0], q[1]))
		pats.append(Vector4(w.x, w.z, float(q[2]) * S, kinds[q[3]]))
	var segs: Array = []
	var infos: Array = []
	for pth in g["paths"]:
		var a := to_world(Vector2(pth[0][0], pth[0][1]))
		var c := to_world(Vector2(pth[1][0], pth[1][1]))
		segs.append(Vector4(a.x, a.z, c.x, c.z))
		infos.append(Vector4(float(g["path_width_px"]) * S, 0, 0, 0))
	_ground.set_shader_parameter("patch_n", pats.size())
	_ground.set_shader_parameter("patches", _pad(pats, 16))
	_ground.set_shader_parameter("seg_n", segs.size())
	_ground.set_shader_parameter("segs", _pad(segs, 16))
	_ground.set_shader_parameter("seg_info", _pad(infos, 16))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	mi.mesh = pm
	mi.material_override = _ground
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _pad(a: Array, n: int) -> PackedVector4Array:
	var out := PackedVector4Array()
	for v in a:
		out.append(v)
	while out.size() < n:
		out.append(Vector4.ZERO)
	return out


func _build_overlay() -> void:
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.set_shader_parameter("marks", overlay.get_texture())
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = SIM_SIZE * S
	mi.mesh = pm
	mi.material_override = _overlay_mat
	mi.position = to_world(SIM_SIZE * 0.5, 0.03)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _prop(id: String, at: Vector3, rot: float, s: float) -> void:
	var n: Node3D = (load("res://assets/models/props/%s.glb" % id) as PackedScene).instantiate()
	n.position = at
	n.rotation_degrees.y = rot
	n.scale = Vector3.ONE * s
	add_child(n)
	Figure.style(n, float(cfg["darken"]))


func _build_props() -> void:
	# The yard's fence along the sim's bounds, open at the four gates.
	var b: Rect2 = arena.BOUNDS
	var gap := float(cfg["fence_gap_px"])
	var step := 2.6 / S
	var sides := [
		[b.position, Vector2(b.end.x, b.position.y), 0.0],
		[Vector2(b.position.x, b.end.y), b.end, 0.0],
		[b.position, Vector2(b.position.x, b.end.y), 90.0],
		[Vector2(b.end.x, b.position.y), b.end, 90.0],
	]
	for sd in sides:
		var a: Vector2 = sd[0]
		var c: Vector2 = sd[1]
		var n := int(ceil(a.distance_to(c) / step))
		for i in n:
			var p := a.lerp(c, (i + 0.5) / n)
			var near_gate := false
			for g in arena.GATES:
				if p.distance_to(g) < gap:
					near_gate = true
			if not near_gate:
				_prop("fence", to_world(p), sd[2], 1.0)
	for pr in cfg["props"]:
		_prop(pr[0], to_world(Vector2(pr[1], pr[2])), float(pr[3]), float(pr[4]))


## The Orrery: a stone plinth, a brass post and two rings that turn; it glows while usable.
func _build_shrine() -> void:
	_shrine = Node3D.new()
	_shrine.position = to_world(arena.shrine_pos())
	add_child(_shrine)
	var plinth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.35, 0.6)
	plinth.mesh = bm
	plinth.position.y = 0.175
	plinth.material_override = Figure.ink(Color("4a4652"))
	_shrine.add_child(plinth)
	var post := MeshInstance3D.new()
	post.mesh = Figure._cyl(0.04, 0.05, 0.6)
	post.position.y = 0.65
	post.material_override = Figure.ink(Color("b08a3a"))
	_shrine.add_child(post)
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.3 - 0.07 * i
		tm.outer_radius = 0.34 - 0.07 * i
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		ring.position.y = 1.15
		ring.material_override = Figure.ink(Color("c9a45a"))
		_shrine.add_child(ring)
		_shrine_rings.append(ring)
	var core := _glow_node(0.07, Color("ffd36b"))
	core.position.y = 1.15
	_shrine.add_child(core)
	_shrine_rings.append(core)


# --- materials and pools --------------------------------------------------------------

## A glowing sphere: emissive, so it blooms at dusk.
func _glow_node(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Additive and unshaded: light that has no body (a fire column, a lightning stroke).
static func _add_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color.BLACK
	return m


static func _set_glow(mi: MeshInstance3D, col: Color, energy: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	m.emission = col
	m.emission_energy_multiplier = energy


func _take(kind: String) -> Node3D:
	if not _pools.has(kind):
		_pools[kind] = []
	var pool: Array = _pools[kind]
	var i: int = _used.get(kind, 0)
	_used[kind] = i + 1
	if i < pool.size():
		pool[i].visible = true
		return pool[i]
	var n := _make(kind)
	add_child(n)
	pool.append(n)
	return n


func _make(kind: String) -> Node3D:
	match kind:
		"orb":
			return _glow_node(0.15, Color.WHITE)
		"rock":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.15
			sm.height = 0.24
			sm.radial_segments = 6
			sm.rings = 3
			mi.mesh = sm
			mi.material_override = Figure.ink(PixelArt.EARTH.darkened(0.15))
			return mi
		"flame":
			var n := Node3D.new()
			for k in 2:
				var mi := MeshInstance3D.new()
				var pm := PrismMesh.new()
				var h := 0.5 - 0.18 * k
				pm.size = Vector3(0.22 - 0.08 * k, h, 0.05)
				mi.mesh = pm
				var m := StandardMaterial3D.new()
				m.albedo_color = Color.BLACK
				m.emission_enabled = true
				m.emission = PixelArt.FIRE if k == 0 else PixelArt.FIRE_HOT
				m.emission_energy_multiplier = 2.0
				mi.material_override = m
				mi.position = Vector3(0, h * 0.5, 0.01 * k)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(mi)
			return n
		"column":
			var mi := MeshInstance3D.new()
			mi.mesh = Figure._cyl(1.0, 1.0, 1.0, 12)
			mi.material_override = _add_mat()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return mi
		"rod":
			var n := Node3D.new()
			var pole := MeshInstance3D.new()
			pole.mesh = Figure._cyl(0.03, 0.04, 0.9, 6)
			pole.position.y = 0.45
			pole.material_override = Figure.ink(PixelArt.STEEL)
			n.add_child(pole)
			var tip := _glow_node(0.07, PixelArt.STORM)
			tip.position.y = 0.95
			tip.name = "Tip"
			n.add_child(tip)
			return n
		"tome":
			var n := Node3D.new()
			for sx in [-1.0, 1.0]:
				var page := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.22, 0.03, 0.3)
				page.mesh = bm
				page.position = Vector3(0.11 * sx, 0, 0)
				page.rotation_degrees.z = -12.0 * sx
				page.material_override = Figure.ink(PixelArt.PAPER)
				n.add_child(page)
			var spine := _glow_node(0.03, PixelArt.GOLD)
			n.add_child(spine)
			return n
		"bolt":
			var n := Node3D.new()
			for i in 5:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.06, 0.06, 1.0)
				mi.mesh = bm
				mi.material_override = _add_mat()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(mi)
			return n
	return Node3D.new()


func _begin_pools() -> void:
	_used.clear()
	_light_wants.clear()


func _end_pools() -> void:
	for kind in _pools:
		var pool: Array = _pools[kind]
		for i in range(_used.get(kind, 0), pool.size()):
			pool[i].visible = false


func _want_light(at: Vector3, col: Color, energy: float, rng: float) -> void:
	_light_wants.append([at, col, energy, rng])


# --- every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	if arena == null or arena.player == null:
		return
	if Input.is_action_just_pressed("mood"):
		_mood_override = ("dusk" if _mood_k < 0.5 else "day")
	var want: String = _mood_override if _mood_override != "" else str(cfg["phase_moods"].get(arena.phase, "day"))
	_mood_k = move_toward(_mood_k, 1.0 if want == "dusk" else 0.0, delta / 2.5)
	_apply_mood(_mood_k)

	_begin_pools()
	_sync_figures(delta)
	_sync_stones()
	_sync_projs()
	_sync_zones()
	_sync_fx()
	_sync_shrine()
	_end_pools()
	_place_lights()

	var sh: float = arena.shake
	camera.position = _cam_base + (Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * sh * 0.03 if sh > 0.3 else Vector3.ZERO)
	if marks != null:
		marks.queue_redraw()


func _apply_mood(k: float) -> void:
	var a: Dictionary = cfg["moods"]["day"]
	var b: Dictionary = cfg["moods"]["dusk"]
	var col := func(key: String) -> Color: return Color(str(a[key])).lerp(Color(str(b[key])), k)
	var num := func(key: String) -> float: return lerpf(float(a[key]), float(b[key]), k)
	_env.background_color = col.call("bg")
	_env.ambient_light_color = col.call("ambient")
	_env.ambient_light_energy = num.call("ambient_energy")
	_env.glow_intensity = num.call("glow")
	_sun.light_color = col.call("sun")
	_sun.light_energy = num.call("sun_energy")
	var ra: Array = a["sun_rot"]
	var rb: Array = b["sun_rot"]
	_sun.rotation_degrees = Vector3(lerpf(ra[0], rb[0], k), lerpf(ra[1], rb[1], k), 0)
	for key in ["base", "wash", "dirt", "grass", "wet", "ink"]:
		_ground.set_shader_parameter(key + "_col", Color(str(a["ground"][key])).lerp(Color(str(b["ground"][key])), k))
	_overlay_mat.set_shader_parameter("boost", num.call("overlay"))
	Figure.outline(col.call("outline"), float(cfg["outline_px"]))


func _fig_for(u: Unit) -> Dictionary:
	if _figs.has(u.id):
		return _figs[u.id]
	var f := Figure.new()
	f.build(cfg["figures"][u.kind], float(cfg["darken"]))
	add_child(f)
	var rec := {"node": f, "unit": u, "rot": 0.0, "seen": true, "run_t": randf() * 2.0}
	if u.team == 1:
		rec["rot"] = face_rot(arena.player.pos - u.pos)
	_figs[u.id] = rec
	return rec


func _sync_figures(delta: float) -> void:
	for id in _figs:
		_figs[id]["seen"] = false
	var P: Unit = arena.player
	var casts: int = int(arena.stats["casts"])
	if casts > _last_casts:
		_cast_t = 0.0
	_last_casts = casts
	_cast_t += delta
	for u in arena.units:
		var rec := _fig_for(u)
		rec["seen"] = true
		var f = rec["node"]
		f.position = to_world(u.pos, u.lift() * S)
		# Facing: the wizard faces the aim; enemies face the wizard, or where they walk.
		var d: Vector2 = (arena.mouse - u.pos) if u == P else (P.pos - u.pos)
		if d.length() > 0.5 and not u.dead:
			rec["rot"] = lerp_angle(rec["rot"], face_rot(d), clampf(delta * 14.0, 0.0, 1.0))
		f.rotation.y = rec["rot"]
		var pose := _pose(u, rec, delta)
		f.pose(pose[0], pose[1], delta)
		var fade := 0.0
		var dark := 0.0
		if u.dead:
			var k := 1.0 - clampf(u.death_t / 0.6, 0.0, 1.0)
			fade = smoothstep(0.4, 1.0, k)
			dark = 0.35 * k
		elif u == P and u.iframes > 0.0:
			fade = 0.45
		f.set_look(clampf(u.flash * 6.0, 0.0, 1.0), Color("fff0d8"), fade, dark)
		if u.kind == "rival" and not u.dead:
			_want_light(to_world(u.pos, 1.6), PixelArt.STORM, 0.6, 3.0)
	for id in _figs.keys():
		if not _figs[id]["seen"]:
			_figs[id]["node"].queue_free()
			_figs.erase(id)


## Which clip the unit shows, and at what time: reactions first, then attacks, then moving.
func _pose(u: Unit, rec: Dictionary, delta: float) -> Array:
	var P: Unit = arena.player
	var staff := u == P
	if u.dead:
		var k := 1.0 - clampf(u.death_t / 0.6, 0.0, 1.0)
		return ["down", k * Figure.clip_len("down")]
	if u.reaction != "" and u.reaction_t > 0.0:
		var k := 1.0 - u.reaction_t / maxf(0.01, u.reaction_len)
		match u.reaction:
			"knockdown":
				return ["down", minf(k * 1.6, 1.0) * Figure.clip_len("down")]
			"launch":
				return ["air", k * Figure.clip_len("air")]
			"stagger":
				return ["stagger", k * Figure.clip_len("stagger")]
			_:
				return ["hit", k * Figure.clip_len("hit")]
	if u.stun > 0.0:
		return ["stagger", fmod(u.anim, Figure.clip_len("stagger"))]
	if u == P:
		if arena.kit.holding != "":
			return ["channel", Figure.clip_len("channel") * 0.4]
		if _cast_t < 0.45:
			return ["staff_thrust", 0.12 + _cast_t * 1.2]
	elif u.state in ["windup", "lance", "spark", "storm"] and u.state_t > 0.0:
		var clip := "overhead" if u.kind == "hollow" else ("channel" if u.state == "storm" else "cast")
		var e: Dictionary = arena.D["enemies"][u.kind]
		var total := float(e.get("windup", 0.6))
		var k := 1.0 - clampf(u.state_t / maxf(0.05, total), 0.0, 1.0)
		var anim: Animation = Figure._lib.get_animation(clip)
		var impact := 0.3 if anim == null else anim.length * 0.42
		return [clip, k * impact]
	if u.moving:
		rec["run_t"] += delta * clampf(u.speed / 50.0, 0.7, 1.4)
		var run := "staff_run" if staff else "run"
		return [run, fmod(rec["run_t"], Figure.clip_len(run))]
	rec["run_t"] += delta
	var idle := "staff_idle" if staff else "stand"
	return [idle, fmod(rec["run_t"], Figure.clip_len(idle))]


func _sync_stones() -> void:
	for s in arena.stones:
		var r := _take("rock")
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
		r.position = to_world(p, h)
		r.rotation.y += 0.05


func _sync_projs() -> void:
	for p in arena.projs:
		if p.get("ghost", false):
			continue
		var at := to_world(p["pos"], 0.7)
		if p["kind"] == "pebble":
			var r := _take("rock")
			r.position = at
			continue
		var o := _take("orb") as MeshInstance3D
		var col: Color = p["color"]
		if p["kind"] in ["ember", "pyro"]:
			col = PixelArt.FIRE
		o.position = at
		o.scale = Vector3.ONE * clampf(float(p["r"]) / 2.5, 0.8, 2.2)
		_set_glow(o, col, lerpf(1.1, 1.8, _mood_k))
		if p["kind"] in ["ember", "pyro"]:
			_want_light(at, PixelArt.FIRE, 1.6, 3.5)
		elif p.get("team", 0) == 1 or col == PixelArt.DANGER:
			_want_light(at, col, 1.0, 2.5)


func _sync_zones() -> void:
	for z in arena.zones:
		var t: float = z["t"]
		match z["kind"]:
			"ember":
				var f := _take("flame")
				f.position = to_world(z["pos"])
				var fade := clampf((z["life"] - t) / 1.0, 0.3, 1.0)
				f.scale = Vector3(1.0, (0.8 + 0.25 * sin(t * 13.0 + z["pos"].x)) * fade, 1.0)
				f.rotation.y = camera.rotation.y
				_want_light(to_world(z["pos"], 0.5), PixelArt.FIRE, 1.4 * fade, 3.0)
			"tome":
				var b := _take("tome")
				b.position = to_world(z["pos"], 0.55 + 0.06 * sin(t * 3.0))
				b.rotation.y = t * 0.8
				_want_light(b.position, PixelArt.GOLD, 0.8, 2.0)
			"column":
				var c := _take("column") as MeshInstance3D
				var k: float = 1.0 - t / z["life"]
				var r: float = float(z["r"]) * S * 0.6
				c.scale = Vector3(r, 2.4, r)
				c.position = to_world(z["pos"], 1.2)
				(c.material_override as StandardMaterial3D).albedo_color = PixelArt.FIRE.lerp(PixelArt.FIRE_HOT, k) * (0.8 * k)
				_want_light(to_world(z["pos"], 1.0), PixelArt.FIRE, 3.0 * k, 5.0)
			"meteor":
				var k := clampf(t / z["delay"], 0.0, 1.0)
				var o := _take("orb") as MeshInstance3D
				o.position = to_world(z["pos"] + Vector2(-20, 0) * (1.0 - k), 0.3 + 6.0 * (1.0 - k))
				o.scale = Vector3.ONE * 2.2
				_set_glow(o, PixelArt.FIRE_HOT, 3.0)
				_want_light(o.position, PixelArt.FIRE, 2.0, 5.0)
			"rod":
				var r := _take("rod")
				r.position = to_world(z["pos"])
				var lit: bool = z.get("zap_t", 1.0) < 0.15 or int(t * 4.0) % 2 == 0
				_set_glow(r.get_node("Tip"), PixelArt.STORM, 3.0 if lit else 1.0)
				if lit:
					_want_light(to_world(z["pos"], 1.0), PixelArt.STORM, 0.8, 2.0)
			"storm", "strike":
				var k := clampf(t / maxf(0.01, float(z.get("delay", 1.0))), 0.0, 1.0)
				_want_light(to_world(z["pos"], 1.0), PixelArt.STORM, 0.6 * k, float(z["r"]) * S * 2.0)


func _sync_fx() -> void:
	for f in arena.fxs:
		var k: float = f["t"] / f["life"]
		match f["kind"]:
			"bolt":
				var n := _take("bolt")
				var base := to_world(f["pos"])
				var pts := [Vector3(0.2, 4.4, -0.3), Vector3(-0.15, 3.3, 0.1), Vector3(0.2, 2.4, -0.1), Vector3(-0.15, 1.5, 0.15), Vector3(0.1, 0.6, 0.0), Vector3.ZERO]
				var i := 0
				for seg in n.get_children():
					var a: Vector3 = base + pts[i]
					var b: Vector3 = base + pts[i + 1]
					var mi := seg as MeshInstance3D
					mi.look_at_from_position((a + b) * 0.5, b, Vector3.RIGHT)
					mi.scale = Vector3(1, 1, a.distance_to(b))
					(mi.material_override as StandardMaterial3D).albedo_color = Color(f.get("color", PixelArt.STORM)) * (1.0 - k)
					i += 1
				_want_light(base + Vector3(0, 1.5, 0), PixelArt.STORM, 3.0 * (1.0 - k), 5.0)
			"rise":
				var r := _take("rock")
				r.position = to_world(f["pos"], 0.2 + 2.0 * k)
			"burst":
				var col: Color = f.get("color", PixelArt.PAPER)
				if col == PixelArt.FIRE or col == PixelArt.FIRE_HOT:
					_want_light(to_world(f["pos"], 0.6), PixelArt.FIRE, 1.5 * (1.0 - k), 3.0)
				elif col == PixelArt.STORM:
					_want_light(to_world(f["pos"], 0.6), PixelArt.STORM, 1.5 * (1.0 - k), 3.0)
			"zap", "beam":
				var a := to_world(f["pos"], 0.8)
				_want_light(a, f.get("color", PixelArt.STORM), 1.5 * (1.0 - k), 3.0)


func _sync_shrine() -> void:
	var ready: bool = arena.shrine_ready()
	var spin := Time.get_ticks_msec() / 900.0
	_shrine_rings[0].rotation = Vector3(spin, 0, 0.4)
	_shrine_rings[1].rotation = Vector3(0.5, 0, spin * 1.3)
	_set_glow(_shrine_rings[2], PixelArt.FIRE_HOT if ready else PixelArt.PAPER, 3.0 if ready else 0.6)
	if ready:
		_want_light(_shrine.position + Vector3(0, 1.2, 0), PixelArt.GOLD, 1.2, 3.0)


## Spells light the scene at dusk: the brightest few wants get a real light.
func _place_lights() -> void:
	var scale := lerpf(float(cfg["moods"]["day"]["lights"]), float(cfg["moods"]["dusk"]["lights"]), _mood_k)
	_light_wants.sort_custom(func(a, b): return a[2] > b[2])
	for i in MAX_LIGHTS:
		var l := _lights[i]
		if i < _light_wants.size() and scale > 0.01:
			var w: Array = _light_wants[i]
			l.visible = true
			l.position = w[0]
			l.light_color = w[1]
			l.light_energy = float(w[2]) * scale
			l.omni_range = float(w[3])
		else:
			l.visible = false
