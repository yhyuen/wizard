extends Node3D
## The fight in low poly at night (GDD 6.3, "moody night"): faceted low-poly shapes with matte,
## bumpy materials, moonlight, low mist, a cobbled plaza at the edge of Vellmar with lit windows
## and lamp posts round it (town.gd), and spells as the main light, under a tilted camera that follows the player
## a little, over the same 2D sim. The arena still simulates everything and still draws
## the flat telegraphs (rings, cones, lines, hold-to-aim previews, the reticle) into an
## offscreen viewport, which lies on the ground here as a decal, so a telegraph stays exactly
## its hitbox. Spells and everything else that stands up are solid low-poly shapes
## (spells3d.gd). It reads the sim each frame and never changes it.

const Figure := preload("res://scripts/view/figure.gd")
const ShapeFigure := preload("res://scripts/view/shape_figure.gd")
const Spells3D := preload("res://scripts/view/spells3d.gd")
const Town := preload("res://scripts/view/town.gd")
const OVERLAY_SHADER := preload("res://scripts/view/overlay.gdshader")
const CFG_PATH := "res://data/visual.json"
const SIM_CENTRE := Vector2(240, 135)
const SIM_SIZE := Vector2(480, 270)
const MAX_LIGHTS := 4  # spell lights; each re-draws the meshes it touches in the browser renderer

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
var _mood_k := 0.0  # 0 night (the waves) .. 1 the duel's deeper night, eased toward the target
var _mood_override := ""
var _figs := {}  # unit id -> {"node", "unit", "cast_t", "casts"}
var spells  # Spells3D
var _lights: Array[OmniLight3D] = []
var low := false  # low graphics: no glow, no sun shadow, fewer spell lights (set_low)
var _light_wants: Array = []
var _shrine: Node3D
var _shrine_rings: Array = []
var _last_casts := 0
var _cast_t := 99.0
var _cam_base := Vector3.ZERO
var _cam_pan := Vector3.ZERO  # how far the camera has followed the player off the centre


func setup(the_arena, vp: SubViewport) -> void:
	arena = the_arena
	overlay = vp
	cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
	S = float(cfg["metres_per_px"])
	Figure.SURFACES = cfg.get("surfaces", {})


func _ready() -> void:
	_build_env()
	_build_ground()
	_build_overlay()
	_build_props()
	_build_shrine()
	if cfg.has("town"):
		var town := Town.new()
		add_child(town)
		town.build(self, cfg["town"])
	_build_vignette()
	spells = Spells3D.new(self)
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
	var adj: Dictionary = cfg.get("adjust", {})
	if not adj.is_empty():
		_env.adjustment_enabled = true
		_env.adjustment_saturation = float(adj.get("saturation", 1.0))
		_env.adjustment_contrast = float(adj.get("contrast", 1.0))
		_env.adjustment_brightness = float(adj.get("brightness", 1.0))
	var fog: Dictionary = cfg.get("fog", {})
	if not fog.is_empty():
		# low mist: thin overall, thicker near the ground
		_env.fog_enabled = true
		_env.fog_light_color = Color(str(fog["color"]))
		_env.fog_density = float(fog["density"])
		_env.fog_height = float(fog["height"])
		_env.fog_height_density = float(fog["height_density"])
		_env.fog_sky_affect = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 45.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # one shadow pass, not four
	add_child(_sun)


## The ground: a low-poly mesh with smooth normals taken from the height field, so it reads as
## soft wet earth under the shader's bump. The yard is flat (the telegraphs lie on it); outside
## the fence the land rises into low hills. It is cut into chunks so a lamp or a spell light
## only re-draws the ground near it.
func _build_ground() -> void:
	_ground = ShaderMaterial.new()
	_ground.shader = Figure.SOLID
	_ground.set_shader_parameter("use_vcol", true)
	_ground.set_shader_parameter("rim", 0.0)
	_ground.set_shader_parameter("facet", float(g_facet()))
	Figure.finish(_ground, "ground")
	var g: Dictionary = cfg["ground"]
	var shade_var := float(g.get("shade_var", 0.08))
	var cell := float(g["cell_m"])
	var ext: Array = g["extent_m"]
	var nx := int(ext[0] / cell)
	var nz := int(ext[1] / cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var grid := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var x := (ix - nx * 0.5) * cell
			var z := (iz - nz * 0.5) * cell
			if ix > 0 and ix < nx and iz > 0 and iz < nz:
				x += rng.randf_range(-0.35, 0.35) * cell
				z += rng.randf_range(-0.35, 0.35) * cell
			row.append(Vector3(x, height(x, z), z))
		grid.append(row)
	var chunk := int(g.get("chunk_cells", 12))
	var tools := {}
	for iz in nz:
		for ix in nx:
			var key := Vector2i(ix / chunk, iz / chunk)
			if not tools.has(key):
				tools[key] = SurfaceTool.new()
				tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			var st: SurfaceTool = tools[key]
			var a: Vector3 = grid[iz][ix]
			var b: Vector3 = grid[iz][ix + 1]
			var c: Vector3 = grid[iz + 1][ix]
			var d: Vector3 = grid[iz + 1][ix + 1]
			var tris := [[a, b, d], [a, d, c]] if (ix + iz) % 2 == 0 else [[a, b, c], [b, d, c]]
			for t in tris:
				var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				var kind := _ground_kind(mid)
				var shade := rng.randf_range(1.0 - shade_var, 1.0 + shade_var)
				for v in t:  # clockwise from above, so the ground survives back-face culling
					st.set_color(Color(shade, shade, shade))
					st.set_uv(Vector2(kind, 0))
					st.set_normal(_ground_normal(v.x, v.z))
					st.add_vertex(v)
	for key in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[key].commit()
		mi.material_override = _ground
		add_child(mi)


func g_facet() -> float:
	return float(cfg["ground"].get("facet", 0.0))


func _ground_normal(x: float, z: float) -> Vector3:
	var e := 0.3
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


## How far a point (metres) lies outside the yard's fence.
func _outside(x: float, z: float) -> float:
	var b: Rect2 = arena.BOUNDS
	var lo := to_world(b.position)
	var hi := to_world(b.end)
	var dx := maxf(lo.x - x, x - hi.x)
	var dz := maxf(lo.z - z, z - hi.z)
	return maxf(0.0, maxf(dx, dz))


## Ground height (metres): flat in the yard and just past the fence, hills further out.
func height(x: float, z: float) -> float:
	var out := _outside(x, z)
	if out <= 0.0 and cfg.has("town"):
		return -0.05  # the grout under the cobbles
	var hill := 0.5 + 0.5 * sin(x * 0.31 + 1.7) * sin(z * 0.37 + 0.4) + 0.3 * sin(x * 0.11 - z * 0.17)
	return smoothstep(1.5, 9.0, out) * maxf(0.0, hill) * float(cfg["ground"]["hill_m"])


## 0 dirt, 1 grass, 2 hill, 3 path: the yard is trodden dirt, paths lead out of the gates.
func _ground_kind(p: Vector3) -> int:
	var g: Dictionary = cfg["ground"]
	var sim := Vector2(p.x / S, p.z / S) + SIM_CENTRE
	for pth in g["paths"]:
		var a := Vector2(pth[0][0], pth[0][1])
		var c := Vector2(pth[1][0], pth[1][1])
		if Geometry2D.get_closest_point_to_segment(sim, a, c).distance_to(sim) < float(g["path_width_px"]) * 0.5:
			return 3
	var out := _outside(p.x, p.z)
	if out <= 0.2:
		return 0
	return 2 if p.y > 0.6 else 1


func _build_overlay() -> void:
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.set_shader_parameter("marks", overlay.get_texture())
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = SIM_SIZE * S
	mi.mesh = pm
	mi.material_override = _overlay_mat
	mi.position = to_world(SIM_SIZE * 0.5, 0.06)  # just over the cobbles
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _prop(id: String, at: Vector3, rot: float, s: float) -> void:
	var n: Node3D = (load("res://assets/models/props/%s.glb" % id) as PackedScene).instantiate()
	n.position = Vector3(at.x, height(at.x, at.z), at.z)
	n.rotation_degrees.y = rot
	n.scale = Vector3.ONE * s
	add_child(n)
	Figure.style(n, float(cfg["darken"]), {}, Color(0, 0, 0, 0), [], float(cfg.get("props_facet", 1.0)), "prop")


func _build_props() -> void:
	if cfg.has("town"):
		return  # the town builds the kerb and the clutter, merged
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
	for pr in cfg.get("props", []):
		_prop(pr[0], to_world(Vector2(pr[1], pr[2])), float(pr[3]), float(pr[4]))


## The Orrery: a stone plinth, a brass post and two rings that turn round a gem; it glows
## while usable.
func _build_shrine() -> void:
	_shrine = Node3D.new()
	_shrine.position = to_world(arena.shrine_pos())
	add_child(_shrine)
	_shrine.scale = Vector3.ONE * float(cfg.get("shrine_scale", 1.0))
	var plinth := MeshInstance3D.new()
	plinth.mesh = Figure._cyl(0.3, 0.38, 0.35, 6)
	plinth.position.y = 0.175
	plinth.material_override = Figure.finish(Figure.mat(Color("4a4652")), "stone")
	_shrine.add_child(plinth)
	var post := MeshInstance3D.new()
	post.mesh = Figure._cyl(0.04, 0.05, 0.6, 5)
	post.position.y = 0.65
	post.material_override = Figure.finish(Figure.mat(Color("b08a3a")), "metal")
	_shrine.add_child(post)
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.3 - 0.07 * i
		tm.outer_radius = 0.34 - 0.07 * i
		tm.rings = 10
		tm.ring_segments = 3
		ring.mesh = tm
		ring.position.y = 1.15
		ring.material_override = Figure.finish(Figure.mat(Color("c9a45a")), "metal")
		_shrine.add_child(ring)
		# a planet riding each ring, in a Sphere colour
		var planet := MeshInstance3D.new()
		planet.mesh = Spells3D.octa(0.045, 1.0)
		planet.material_override = Figure.mat(Color(["aab6ff", "f0773c"][i]), 1.2)
		planet.position = Vector3(0.32 - 0.07 * i, 0, 0)
		ring.add_child(planet)
		_shrine_rings.append(ring)
	var core := MeshInstance3D.new()
	core.mesh = Spells3D.octa(0.08, 1.0)
	core.material_override = Figure.mat(Color("ffd36b"), 1.5)
	core.position.y = 1.15
	_shrine.add_child(core)
	_shrine_rings.append(core)


## A dark edge round the screen, drawn over the 3D and under the HUD. A gradient, not a
## screen-reading shader, so it costs nothing in the browser.
func _build_vignette() -> void:
	var v: Dictionary = cfg.get("vignette", {})
	if v.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.5) + Vector2(0.5, 0.5) * float(v["radius"])
	gt.width = 256
	gt.height = 144
	var edge := Color(str(v["color"]))
	var gr := Gradient.new()
	gr.set_color(0, Color(edge, 0.0))
	gr.set_color(1, Color(edge, float(v["strength"])))
	gr.add_point(float(v["inner"]), Color(edge, 0.0))
	gt.gradient = gr
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)


## 0 in the waves' night .. 1 in the duel's deeper night.
func deep() -> float:
	return _mood_k


## How strongly spells glow and light the ground (0 dim .. 1 full): already high in the waves,
## full in the duel.
func spell_k() -> float:
	return lerpf(float(cfg.get("spell_glow_floor", 0.0)), 1.0, _mood_k)


func want_light(at: Vector3, col: Color, energy: float, rng: float) -> void:
	_light_wants.append([at, col, energy, rng])


# --- every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	if arena == null or arena.player == null:
		return
	if Input.is_action_just_pressed("mood"):
		_mood_override = ("duel" if _mood_k < 0.5 else "night")
	var want: String = _mood_override if _mood_override != "" else str(cfg["phase_moods"].get(arena.phase, "night"))
	_mood_k = move_toward(_mood_k, 1.0 if want == "duel" else 0.0, delta / 2.5)
	_apply_mood(_mood_k)

	_light_wants.clear()
	_sync_figures(delta)
	_sync_echo(delta)
	spells.sync(delta)
	_sync_shrine()
	_place_lights()

	_follow(delta)
	var sh: float = arena.shake
	camera.position = _cam_base + _cam_pan + (Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * sh * 0.03 if sh > 0.3 else Vector3.ZERO)
	if marks != null:
		marks.queue_redraw()


## The camera sits closer than the whole yard and drifts after the player (Magicka keeps the
## wizards big on screen), but only part of the way and never past "follow_limit_m", so the
## fence and the gates stay in view.
func _follow(delta: float) -> void:
	var c: Dictionary = cfg["camera"]
	var k := float(c.get("follow", 0.0))
	if k <= 0.0:
		return
	var lim: Array = c.get("follow_limit_m", [0, 0])
	var p := to_world(arena.player.pos) * k
	var want := Vector3(clampf(p.x, -lim[0], lim[0]), 0.0, clampf(p.z, -lim[1], lim[1]))
	_cam_pan = _cam_pan.lerp(want, 1.0 - exp(-delta * 4.0))


func _apply_mood(k: float) -> void:
	var a: Dictionary = cfg["moods"]["night"]
	var b: Dictionary = cfg["moods"]["duel"]
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
	var cols := PackedVector3Array()
	for key in ["dirt", "grass", "hill", "path"]:
		var c := Color(str(a["ground"][key])).lerp(Color(str(b["ground"][key])), k)
		if cfg["ground"].get("linear", false):
			c = c.srgb_to_linear()  # kind_cols is a plain vec3, so it takes linear colour
		cols.append(Vector3(c.r, c.g, c.b))
	_ground.set_shader_parameter("kind_cols", cols)
	_overlay_mat.set_shader_parameter("boost", num.call("overlay"))
	_env.fog_light_color = col.call("fog") if a.has("fog") else _env.fog_light_color


func _fig_for(u: Unit) -> Dictionary:
	if _figs.has(u.id):
		return _figs[u.id]
	var def: Dictionary = cfg["figures"][u.kind]
	var f = ShapeFigure.new() if def.has("shape") else Figure.new()
	f.build(def, float(cfg["darken"]))
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
		f.position = to_world(u.shown_pos(), u.lift() * S)
		# Facing: the wizard faces the aim; enemies face the wizard, or where they walk.
		var d: Vector2 = (arena.mouse - u.pos) if u == P else (P.pos - u.pos)
		if u.flags.has("face"):
			d = u.flags["face"]  # a cutscene says where it looks
		if d.length() > 0.5 and not u.dead:
			rec["rot"] = lerp_angle(rec["rot"], face_rot(d), clampf(delta * 14.0, 0.0, 1.0))
		f.rotation.y = rec["rot"]
		var pose := _pose(u, rec, delta)
		f.pose(pose[0], pose[1], delta)
		if f is ShapeFigure:
			f.sync_unit(u)
		var fade := 0.0
		var dark := 0.0
		if u.dead:
			var k := 1.0 - clampf(u.death_t / 0.6, 0.0, 1.0)
			fade = smoothstep(0.4, 1.0, k)
			dark = 0.35 * k
		elif u == P and u.iframes > 0.0:
			fade = 0.45
		if u.flags.has("ghost"):
			f.set_look(0.6, PixelArt.HOURS, 0.3, 0.0)  # an Hours replay: a figure out of the past
		else:
			f.set_look(clampf(u.flash * 6.0, 0.0, 1.0), Color("fff0d8"), fade, dark)
		if u.kind == "rival" and not u.dead:
			want_light(to_world(u.pos, 1.6), PixelArt.STORM, 0.6, 3.0)
		if u == P and not u.dead:
			# the wizard's staff gem: a small light of their own, so they never vanish in the dark
			var gl: Array = cfg.get("player_light", [])
			if not gl.is_empty():
				want_light(to_world(u.pos, 2.0), Color(str(gl[0])), float(gl[1]), float(gl[2]))
	for id in _figs.keys():
		if not _figs[id]["seen"]:
			_figs[id]["node"].queue_free()
			_figs.erase(id)


## Which clip the unit shows, and at what time: reactions first, then attacks, then moving.
func _pose(u: Unit, rec: Dictionary, delta: float) -> Array:
	var P: Unit = arena.player
	var staff := u == P
	if u.flags.has("pose"):
		return u.flags["pose"]  # a cutscene poses it (scripts/game/cutscene.gd)
	if u.dead:
		var k := 1.0 - clampf(u.death_t / 0.6, 0.0, 1.0)
		if u.kind == "inverted":
			# it came into the fight by rising from death, so it leaves standing, fading out of time
			return ["stand", 0.0]
		return ["down", k * Figure.clip_len("down")]
	if u.flags.has("yielded"):
		return ["down", 0.3 * Figure.clip_len("down")]  # kneeling, out of the fight (N-6.4)
	if u.state == "enter" and u.kind == "inverted":
		# the Backward Slinger's death played in reverse: it lies dead, then rises
		var rise := float(arena.D["enemies"]["inverted"]["rise"])
		var k := clampf(u.state_t / rise, 0.0, 1.0)
		return ["down", smoothstep(0.0, 1.0, k) * Figure.clip_len("down")]
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
	elif u.state in ["windup", "lance", "spark", "storm", "hum", "smother"] and u.state_t > 0.0:
		var clip := "overhead" if u.kind in ["hollow", "cutthroat", "shieldman", "brigand_captain", "oath_squire", "shieldknight"] else ("channel" if u.state in ["storm", "hum", "smother"] else "cast")
		var e: Dictionary = arena.D["enemies"][u.kind]
		var total := float(e.get("windup", 0.6))
		var k := 1.0 - clampf(u.state_t / maxf(0.05, total), 0.0, 1.0)
		if u.kind == "inverted":
			k = 1.0 - k  # the Backward Slinger's throw plays in reverse: it catches, not throws
		var anim: Animation = Figure._lib.get_animation(clip)
		var impact := 0.3 if anim == null else anim.length * 0.42
		return [clip, k * impact]
	if u.moving:
		# The Backward Slinger faces you but its legs run backwards.
		rec["run_t"] += delta * clampf(u.speed / 50.0, 0.7, 1.4) * (-1.0 if u.kind == "inverted" else 1.0)
		var run := "staff_run" if staff else "run"
		return [run, fposmod(rec["run_t"], Figure.clip_len(run))]
	rec["run_t"] += delta
	var idle := "staff_idle" if staff else "stand"
	return [idle, fposmod(rec["run_t"], Figure.clip_len(idle))]


var _echo_fig: Figure = null
var _echo_rot := 0.0
var _echo_run := 0.0


## Your echo: last fight's you, walking it backwards. It faces where you aimed while its feet run
## the other way, the run clip played in reverse.
func _sync_echo(delta: float) -> void:
	var e: Dictionary = arena.echo
	if e.is_empty() or not e.get("on", false):
		if _echo_fig != null:
			_echo_fig.visible = false
		return
	if _echo_fig == null:
		_echo_fig = Figure.new()
		_echo_fig.build(cfg["figures"]["echo"], float(cfg["darken"]))
		add_child(_echo_fig)
	_echo_fig.visible = true
	_echo_fig.position = to_world(e["pos"])
	_echo_rot = lerp_angle(_echo_rot, face_rot(e["aim"]), clampf(delta * 10.0, 0.0, 1.0))
	_echo_fig.rotation.y = _echo_rot
	if e["moving"]:
		_echo_run -= delta
		_echo_fig.pose("staff_run", fposmod(_echo_run, Figure.clip_len("staff_run")), delta)
	else:
		_echo_run += delta
		_echo_fig.pose("staff_idle", fposmod(_echo_run, Figure.clip_len("staff_idle")), delta)
	_echo_fig.set_look(0.6, PixelArt.HOURS, float(e["fade"]), 0.0)
	want_light(to_world(e["pos"], 1.6), PixelArt.HOURS, 0.5 * (1.0 - float(e["fade"])), 2.5)


func _sync_shrine() -> void:
	# A reverse scene from the story is not at the Orrery.
	_shrine.visible = arena.cutscene == null
	var ready: bool = arena.shrine_ready()
	var spin := Time.get_ticks_msec() / 900.0
	_shrine_rings[0].rotation = Vector3(spin, 0, 0.4)
	_shrine_rings[1].rotation = Vector3(0.5, 0, spin * 1.3)
	_shrine_rings[2].rotation.y = spin * 2.0
	Spells3D.paint(_shrine_rings[2], PixelArt.FIRE_HOT if ready else PixelArt.PAPER, 2.0 if ready else 0.3)
	if ready:
		want_light(_shrine.position + Vector3(0, 1.2, 0), PixelArt.GOLD, 1.2, 3.0)


## Low graphics, for slow machines: drops the glow pass, the sun's shadow map and half the spell
## lights, which together are most of what the browser renderer spends beyond the meshes.
func set_low(on: bool) -> void:
	low = on
	_env.glow_enabled = not on
	_sun.shadow_enabled = not on


## Spells light the night: the brightest few wants get a real light.
func _place_lights() -> void:
	var scale := lerpf(float(cfg["moods"]["night"]["lights"]), float(cfg["moods"]["duel"]["lights"]), _mood_k)
	_light_wants.sort_custom(func(a, b): return a[2] > b[2])
	var n := 2 if low else MAX_LIGHTS
	for i in MAX_LIGHTS:
		var l := _lights[i]
		if i < mini(n, _light_wants.size()) and scale > 0.01:
			var w: Array = _light_wants[i]
			l.visible = true
			l.position = w[0]
			l.light_color = w[1]
			l.light_energy = float(w[2]) * scale
			l.omni_range = float(w[3])
		else:
			l.visible = false
