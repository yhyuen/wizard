extends "res://scripts/view/view3d.gd"
## Vellmar in 3D (design/open-world/tech-plan.md §1, §5; design/ruins/tech-plan.md §1–2): the map
## you stand on under a close, steep camera that follows the wizard, Diablo-style. The static
## map is merged per chunk (town_mesh.gd and its ruin kit, ruin_mesh.gd); this adds the ground,
## the people walking their day, the props spells push and burn, lamps and braziers lit or out,
## scorches on walls, the mill wheel, doors, roofs that lift while you're inside, and a mood: one
## for each time of day that blends into the next in the camp, a fixed one in the ruin. Going to
## another map frees all of that and builds the new one (rebuild). Spells and fighters still
## come from the arena through view3d.gd.
##
## The arena's flat marks (telegraphs, the reticle) are drawn into a window of the town that
## follows the wizard (`marks` in data/visual.json "world"), laid on the ground there, so they
## stay exactly their hitboxes without a texture the size of the town.

const TownMesh := preload("res://scripts/world/ruin_mesh.gd")
const TIMES := ["morning", "noon", "afternoon", "dusk", "night"]

var W  # scripts/world/world.gd
var wc: Dictionary  # data/visual.json "world"
var town  # ruin_mesh.gd (the town kit and the ruin kit)
var built_for := ""  # the map id the 3D was built from
var _map_root: Node3D  # everything that belongs to the map, freed on rebuild
var holder: Node2D  # the arena's parent in the marks viewport, moved so the window follows
var mark_origin := Vector2.ZERO
var mark_size := Vector2(720, 440)
var mark_scale := 2.0
var talk_to := ""  # who the wizard is talking to: the camera eases in on the two of them
var _overlay_mi: MeshInstance3D
var _moods := {}  # time of day -> parsed mood
var _mood := {}  # the mood now
var _fight_k := 0.0  # 0 exploring .. 1 in a fight: the night deepens a little
var _people := {}  # person id -> {"node", "rot", "t"}
var _marker: MeshInstance3D  # the gold mark over whoever you're talking to
var _prop_nodes: Array = []  # one per world prop
var _prop_mats := {}
var _scorch_root: Node3D
var _scorch_key := ""
var _lamp_key := "-"
var _cam_at := Vector3.ZERO
var _cam_ready := false
var _cliffs: Array = []  # Rect2
var _inside := ""
var warm := 0  # frames left of the shader warm-up behind the title (prewarm)


func setup_world(the_arena, vp: SubViewport, world, the_holder: Node2D) -> void:
	setup(the_arena, vp)
	W = world
	holder = the_holder
	wc = cfg["world"]
	var m: Dictionary = wc["marks"]
	mark_size = Vector2(m["size"][0], m["size"][1])
	mark_scale = float(m["scale"])
	overlay.size = Vector2i(mark_size * mark_scale)
	holder.scale = Vector2.ONE * mark_scale
	for k in wc["moods"]:
		_moods[k] = _parse_mood(wc["moods"][k])
	_mood = _moods["morning"]


func _ready() -> void:
	_build_env()
	_sun.directional_shadow_max_distance = 22.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # one shadow pass, not four
	_build_marks_window()
	_build_map()
	_marker = MeshInstance3D.new()
	_marker.mesh = Spells3D.octa(0.09, 1.6)
	_marker.material_override = Figure.mat(PixelArt.GOLD, 1.6)
	_marker.rotation_degrees.x = 90.0
	_marker.visible = false
	add_child(_marker)
	_build_vignette()
	spells = Spells3D.new(self)
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
	camera = Camera3D.new()
	camera.fov = float(wc["camera"]["fov"])
	camera.far = 80.0
	add_child(camera)
	camera.current = true
	_apply_world_mood()


## Everything that belongs to the map the world is on: the ground, the chunks, the props, the
## scorches and the people's figures.
func _build_map() -> void:
	built_for = W.map_id
	_map_root = Node3D.new()
	_map_root.name = "map_" + W.map_id
	add_child(_map_root)
	_cliffs = []
	for c in W.map.d.get("cliffs", []):
		_cliffs.append(Rect2(c[0], c[1], c[2], c[3]))
	_build_town_ground()
	var tc: Dictionary = wc["town"].duplicate(true)
	tc["palette"].merge(W.map_def().get("palette", {}), true)
	town = TownMesh.new()
	_map_root.add_child(town)
	town.build(self, W.map, tc)
	_prop_nodes = []
	_build_props()
	_scorch_root = Node3D.new()
	_map_root.add_child(_scorch_root)
	_people = {}
	_lamp_key = "-"
	_scorch_key = ""
	_inside = ""
	_cam_ready = false


## The world went to another map: frees this one's 3D and builds the new one's. The game shows
## its loading card and prewarms behind it (slice.gd go_map).
func rebuild() -> void:
	if built_for == W.map_id:
		return
	remove_child(_map_root)
	_map_root.queue_free()
	_build_map()
	_apply_world_mood()
	if low:
		set_low(true)


# --- coordinates ----------------------------------------------------------------------

func to_world(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x * S, h + ground_at(p), p.y * S)


func to_sim(screen: Vector2) -> Vector2:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return arena.mouse
	var hit := from + dir * (-from.y / dir.y)
	return Vector2(hit.x / S, hit.z / S)


## The ground's height (metres) under a sim point: flat streets and yards, the hill rising
## either side of the College, the bed of the millrace below the water.
func ground_at(p: Vector2) -> float:
	for r: Rect2 in _cliffs:
		if r.has_point(p):
			var b: Rect2 = W.map.bounds
			var d := INF
			if r.position.x > b.position.x:
				d = minf(d, p.x - r.position.x)
			if r.end.x < b.end.x:
				d = minf(d, r.end.x - p.x)
			if r.position.y > b.position.y:
				d = minf(d, p.y - r.position.y)
			if r.end.y < b.end.y:
				d = minf(d, r.end.y - p.y)
			return float(wc["cliff_m"]) * smoothstep(0.0, 80.0, d) * (0.85 + 0.15 * sin(p.x * 0.02) * sin(p.y * 0.017))
	for w: Rect2 in W.map.water:
		if w.grow(-2.0).has_point(p):
			return -0.45
	return 0.0


func height(x: float, z: float) -> float:
	return ground_at(Vector2(x / S, z / S))


# --- building ---------------------------------------------------------------------------

## The ground under the whole town: cobbles in the streets and the College, dirt at the Mill,
## on the road and the hill, grass on the slopes; chunked like the town.
func _build_town_ground() -> void:
	_ground = ShaderMaterial.new()
	_ground.shader = Figure.SOLID
	_ground.set_shader_parameter("use_vcol", true)
	_ground.set_shader_parameter("rim", 0.0)
	_ground.set_shader_parameter("facet", 0.0)
	Figure.finish(_ground, "ground")
	var b: Rect2 = W.map.bounds.grow(240.0)
	var cell := float(wc["ground_cell_m"]) / S
	var nx := int(ceil(b.size.x / cell))
	var nz := int(ceil(b.size.y / cell))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var grid := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var p := b.position + Vector2(ix, iz) * cell
			if ix > 0 and ix < nx and iz > 0 and iz < nz and ground_at(p) != 0.0:
				p += Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * cell
			row.append(Vector3(p.x * S, ground_at(p), p.y * S))
		grid.append(row)
	var chunk := int(round(TownMesh.CHUNK_PX / cell))
	var tools := {}
	for iz in nz:
		for ix in nx:
			var key := Vector2i(ix / chunk, iz / chunk)
			if not tools.has(key):
				tools[key] = SurfaceTool.new()
				tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			var st: SurfaceTool = tools[key]
			var a: Vector3 = grid[iz][ix]
			var bb: Vector3 = grid[iz][ix + 1]
			var c: Vector3 = grid[iz + 1][ix]
			var d: Vector3 = grid[iz + 1][ix + 1]
			for t in [[a, bb, d], [a, d, c]]:
				var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				if _in_hole(Vector2(mid.x / S, mid.z / S)):
					continue  # a pit or a stairwell: the ruin kit builds what's below
				var kind := _kind_at(Vector2(mid.x / S, mid.z / S), mid.y)
				var shade := rng.randf_range(0.94, 1.06)
				for v in t:  # clockwise from above, so the ground survives back-face culling
					st.set_color(Color(shade, shade, shade))
					st.set_uv(Vector2(kind, 0))
					st.set_normal(_ground_normal(v.x, v.z))
					st.add_vertex(v)
	for key in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = tools[key].commit()
		mi.material_override = _ground
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_map_root.add_child(mi)


func _in_hole(p: Vector2) -> bool:
	if W.map.in_pit(p):
		return true
	for st in W.map.d.get("stairwells", []):
		if Rect2(st[0], st[1], st[2], st[3]).has_point(p):
			return true
	return false


## 0 dirt, 1 grass, 2 rock, 3 cobbles (in the ruin: the halls' flagstones, rock outside them).
func _kind_at(p: Vector2, h: float) -> int:
	var place: String = W.map.place_at(p)
	if W.map.kit == "ruin":
		return 3 if place != "" else 2
	if place in ["mill", "road", "hill"]:
		return 0
	if h > 0.05:
		return 2 if h > float(wc["cliff_m"]) * 0.9 and int(p.x * 0.05 + p.y * 0.03) % 3 == 0 else 1
	if place != "" or W.map.in_water(p):
		return 3 if not W.map.in_water(p) else 0
	return 1


## The window the arena's marks are drawn into, on the ground round the wizard.
func _build_marks_window() -> void:
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.set_shader_parameter("marks", overlay.get_texture())
	_overlay_mi = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = mark_size * S
	_overlay_mi.mesh = pm
	_overlay_mi.material_override = _overlay_mat
	_overlay_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay_mi)


## Hay, crates, barrels and the cart: each its own small mesh, since spells move and burn them.
func _build_props() -> void:
	var pal: Dictionary = wc["town"]["palette"]
	var col := {"hay": Color("b8984a"), "crate": Color(str(pal["timber"])).lightened(0.25), "barrel": Color(str(pal["timber"])).lightened(0.1),
		"cart": Color(str(pal["timber"])).lightened(0.15)}
	for k in col:
		_prop_mats[k] = Figure.finish(Figure.mat(col[k]), "prop")
		_prop_mats[k + "_burning"] = Figure.finish(Figure.mat(col[k].darkened(0.55)), "prop")
	_prop_mats["ash"] = Figure.finish(Figure.mat(Color(str(pal["ash"]))), "stone")
	for p in W.props:
		var n := MeshInstance3D.new()
		n.mesh = _prop_mesh(p["kind"])
		n.material_override = _prop_mats.get(p["kind"], _prop_mats["crate"])
		_map_root.add_child(n)
		_prop_nodes.append(n)


func _prop_mesh(kind: String) -> Mesh:
	var def: Dictionary = W.prop_def(kind)
	var r := float(def["r"]) * S
	var h := float(def["h"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var put := func(m: Mesh, xf: Transform3D) -> void:
		st.append_from(m, 0, xf)
	match kind:
		"hay":
			var bm := BoxMesh.new()
			bm.size = Vector3(r * 1.8, h, r * 1.3)
			put.call(bm, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
			var band := BoxMesh.new()
			band.size = Vector3(r * 1.84, h * 0.08, r * 1.34)
			for y in [0.3, 0.7]:
				put.call(band, Transform3D(Basis(), Vector3(0, h * y, 0)))
		"barrel":
			var cm := CylinderMesh.new()
			cm.top_radius = r * 0.85
			cm.bottom_radius = r * 0.85
			cm.height = h
			cm.radial_segments = 8
			cm.rings = 1
			put.call(cm, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
			var hoop := CylinderMesh.new()
			hoop.top_radius = r * 0.9
			hoop.bottom_radius = r * 0.9
			hoop.height = h * 0.07
			hoop.radial_segments = 8
			hoop.rings = 1
			for y in [0.2, 0.8]:
				put.call(hoop, Transform3D(Basis(), Vector3(0, h * y, 0)))
		"cart":
			var bed := BoxMesh.new()
			bed.size = Vector3(r * 1.9, h * 0.4, r * 1.1)
			put.call(bed, Transform3D(Basis(), Vector3(0, h * 0.6, 0)))
			var wheel := CylinderMesh.new()
			wheel.top_radius = h * 0.4
			wheel.bottom_radius = h * 0.4
			wheel.height = 0.12
			wheel.radial_segments = 8
			wheel.rings = 1
			for sz in [-1.0, 1.0]:
				put.call(wheel, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, h * 0.4, sz * r * 0.6)))
			var shaft := BoxMesh.new()
			shaft.size = Vector3(r * 1.4, 0.08, 0.08)
			for sz in [-0.3, 0.3]:
				put.call(shaft, Transform3D(Basis(), Vector3(r * 1.5, h * 0.45, sz * r)))
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(r * 1.5, h, r * 1.5)
			put.call(bm, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
			var slat := BoxMesh.new()
			slat.size = Vector3(r * 1.54, h * 0.1, r * 1.54)
			put.call(slat, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
	return st.commit()


# --- the time of day ------------------------------------------------------------------------

func _parse_mood(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m:
		var v = m[k]
		if v is String:
			out[k] = Color(v)
		elif v is Array:
			out[k] = Vector3(v[0], v[1], v[2])
		elif v is Dictionary:
			var g := {}
			for gk in v:
				g[gk] = Color(str(v[gk]))
			out[k] = g
		else:
			out[k] = float(v)
	return out


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var x = a[key]
		var y = b.get(key, x)
		if x is Dictionary:
			out[key] = _mix(x, y, k)
		elif x is float:
			out[key] = lerpf(x, y, k)
		else:
			out[key] = x.lerp(y, k)
	return out


## This time of day's mood, sliding into the next one over the last part of it (or the map's
## own mood, in the ruin), and a little deeper while a fight is on.
func _update_mood(delta: float) -> void:
	var fixed: String = str(W.map_def().get("mood", ""))
	var fighting: bool = not arena.phase in ["explore", "cutscene"]
	_fight_k = move_toward(_fight_k, 1.0 if fighting else 0.0, delta / 2.0)
	if _moods.has(fixed):
		_mood = _moods[fixed]
	else:
		var t: int = W.run.time()
		var now: Dictionary = _moods[TIMES[t]]
		var next: Dictionary = _moods[TIMES[mini(t + 1, TIMES.size() - 1)]]
		var blend := float(wc["blend"])
		var k := smoothstep(1.0 - blend, 1.0, 1.0 - W.period_left())
		_mood = _mix(now, next, k)
	if _fight_k > 0.0:
		_mood = _mix(_mood, _moods["night"], _fight_k * float(wc["fight_deepen"]))
	_apply_world_mood()


func _apply_world_mood() -> void:
	var m := _mood
	_env.background_color = m["bg"]
	_env.ambient_light_color = m["ambient"]
	_env.ambient_light_energy = m["ambient_energy"]
	_env.glow_intensity = m["glow"]
	_env.fog_light_color = m["fog"]
	_env.fog_density = m["fog_density"]
	_sun.light_color = m["sun"]
	_sun.light_energy = m["sun_energy"]
	_sun.rotation_degrees = m["sun_rot"]
	var cols := PackedVector3Array()
	for key in ["dirt", "grass", "hill", "path"]:
		var c: Color = m["ground"][key].srgb_to_linear()
		cols.append(Vector3(c.r, c.g, c.b))
	_ground.set_shader_parameter("kind_cols", cols)
	_overlay_mat.set_shader_parameter("boost", m["overlay"])
	for gm in [town.glow_mat, town.glow_far]:
		gm.set_shader_parameter("glow", float(wc["town"].get("window_glow", 1.4)) * m["window"])


func deep() -> float:
	return _fight_k


func spell_k() -> float:
	return lerpf(0.35, 1.0, float(_mood.get("spell", 1.0)))


## Puts the camera straight over the wizard (a new day, or the story moving you).
func snap() -> void:
	_cam_ready = false


# --- every frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if arena == null or arena.player == null or W == null:
		return
	_update_mood(delta)
	_light_wants.clear()
	_sync_figures(delta)
	_sync_people(delta)
	_sync_echo(delta)
	spells.sync(delta)
	if warm > 0:
		_warm_up()
	_sync_props()
	_sync_lamps()
	_sync_town(delta)
	_place_lights()
	_follow_close(delta)
	_place_marks()
	if marks != null:
		marks.queue_redraw()


## Draws the town for a few frames behind the opaque title, with every spell shape and all four
## spell lights round the wizard, so the browser compiles the shaders while nobody is watching.
## WebGL compiles each shader on its first draw, and the Fire would otherwise stall on dozens.
func prewarm(frames := 3) -> void:
	warm = frames


func _warm_up() -> void:
	warm -= 1
	var at := to_world(arena.player.pos, 1.0)
	spells.warm_up(at)
	for i in MAX_LIGHTS:
		var a := i * TAU / MAX_LIGHTS
		want_light(at + Vector3(cos(a), 0.5, sin(a)) * 2.0, PixelArt.FIRE, 1.5, 6.0)


## The camera: close and steep behind the wizard, following all the way; it eases in while
## you talk, framing you and whoever you're talking to.
func _follow_close(delta: float) -> void:
	var c: Dictionary = wc["camera"]
	var o: Array = c["offset"]
	var target := to_world(arena.player.pos)
	target.y = 0.0
	var off := Vector3(o[0], o[1], o[2])
	var who = W.people.get_person(talk_to) if talk_to != "" else null
	if who != null:
		target = target.lerp(Vector3(who.pos.x * S, 0, who.pos.y * S), 0.5)
		off *= float(c["talk_zoom"])
	elif arena.cutscene != null and arena.cutscene.look != Vector2.INF:
		target = to_world(arena.cutscene.look)  # a recorded path: frame you and the figure
	if not _cam_ready:
		_cam_at = target
		_cam_ready = true
	_cam_at = _cam_at.lerp(target, 1.0 - exp(-delta * float(c["follow_speed"])))
	var sh: float = arena.shake
	camera.position = _cam_at + off + (Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * sh * 0.03 if sh > 0.3 else Vector3.ZERO)
	camera.look_at(_cam_at + Vector3(0, float(c["look_up"]), 0))
	var chest := to_world(arena.player.pos, 1.0)
	for m in [town.solid_mat, town.glow_mat]:
		m.set_shader_parameter("cut", 1.0)
		m.set_shader_parameter("cut_cam", camera.position)
		m.set_shader_parameter("cut_at", chest)
	town.cut_chunks(camera.position, chest, 2.5)


## Low graphics also drops the town's bump and mottling (six texture reads a pixel).
func set_low(on: bool) -> void:
	super.set_low(on)
	if town == null:
		return
	for m in [town.solid_mat, town.solid_far]:
		if not m.has_meta("bump"):
			m.set_meta("bump", m.get_shader_parameter("bump"))
			m.set_meta("mottle", m.get_shader_parameter("mottle"))
		m.set_shader_parameter("bump", 0.0 if on else m.get_meta("bump"))
		m.set_shader_parameter("mottle", 0.0 if on else m.get_meta("mottle"))


## Moves the marks window to stay round the wizard, snapped so the marks don't shimmer.
func _place_marks() -> void:
	var o: Vector2 = (arena.player.pos - mark_size * 0.5).snapped(Vector2(8, 8))
	mark_origin = o
	holder.position = -o * mark_scale
	var c := o + mark_size * 0.5
	_overlay_mi.position = Vector3(c.x * S, 0.06, c.y * S)


## Who's out in the town: within draw distance of the wizard, walking, standing at their
## spot in their own idle, or (the Mourner) walking backwards away from you.
func _sync_people(delta: float) -> void:
	var at: Vector2 = arena.player.pos
	var far := float(wc["draw_m"]) / S
	var rival_out: bool = arena.units.any(func(u): return u.kind == "rival")
	_marker.visible = false
	for p in W.people.list:
		var show: bool = p.fade < 0.99 and p.pos.distance_to(at) < far and not (p.id == "silas" and rival_out)
		var rec: Dictionary = _people.get(p.id, {})
		if not show:
			if not rec.is_empty():
				rec["node"].visible = false
			continue
		if rec.is_empty():
			rec = {"node": _make_person(p), "rot": face_rot(p.face), "t": randf() * 2.0}
			_people[p.id] = rec
		var n: Node3D = rec["node"]
		n.visible = true
		n.position = to_world(p.pos)
		if p.face.length() > 0.1:
			rec["rot"] = lerp_angle(rec["rot"], face_rot(p.face), clampf(delta * 8.0, 0.0, 1.0))
		n.rotation.y = rec["rot"]
		if p.id == "dog":
			_pose_dog(n, p, rec, delta)
			continue
		var f: Figure = n
		var clip := "walk" if p.moving else str(wc["idle"].get(p.id, "idle" if p.crowd else "stand"))
		if p.talking:
			clip = "stand"
		var back: bool = p.mode == "mourner" and p.moving
		rec["t"] += delta * (-1.6 if back else 1.0)
		f.pose(clip, fposmod(rec["t"], Figure.clip_len(clip)), delta)
		f.set_look(0.0, Color.WHITE, p.fade, 0.0)
		if p.id == talk_to:
			_marker.visible = true
			_marker.position = n.position + Vector3(0, 2.5 + 0.06 * sin(Time.get_ticks_msec() / 250.0), 0)


func _make_person(p) -> Node3D:
	if p.id == "dog":
		return _make_dog()
	var f := Figure.new()
	f.build(cfg["figures"].get(p.figure, cfg["figures"]["townsfolk"]), float(cfg["darken"]))
	_map_root.add_child(f)
	if p.crowd:
		# passers-by cast no shadow: each would draw itself again into the shadow map
		for mi in f.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return f


## The stray dog: a few boxes on four legs.
func _make_dog() -> Node3D:
	var d: Dictionary = wc["dog"]
	var body := Figure.finish(Figure.mat(Color(str(d["body"]))), "figure")
	var dark := Figure.finish(Figure.mat(Color(str(d["dark"]))), "figure")
	var n := Node3D.new()
	var parts := [
		["body", Vector3(0.28, 0.26, 0.7), Vector3(0, 0.5, 0), body],
		["head", Vector3(0.24, 0.24, 0.28), Vector3(0, 0.72, 0.42), body],
		["snout", Vector3(0.13, 0.11, 0.16), Vector3(0, 0.66, 0.6), dark],
		["tail", Vector3(0.06, 0.06, 0.3), Vector3(0, 0.62, -0.46), dark],
	]
	for i in 4:
		parts.append(["leg%d" % i, Vector3(0.08, 0.38, 0.08), Vector3(0.1 if i % 2 == 0 else -0.1, 0.19, 0.24 if i < 2 else -0.24), dark])
	for pt in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pt[1]
		mi.mesh = bm
		mi.position = pt[2]
		mi.material_override = pt[3]
		mi.name = pt[0]
		n.add_child(mi)
	n.scale = Vector3.ONE * float(d["scale"])
	_map_root.add_child(n)
	return n


func _pose_dog(n: Node3D, p, rec: Dictionary, delta: float) -> void:
	rec["t"] += delta * (9.0 if p.moving else 1.5)
	var t: float = rec["t"]
	for i in 4:
		var leg: Node3D = n.get_node("leg%d" % i)
		leg.rotation.x = sin(t + (PI if i in [1, 2] else 0.0)) * (0.5 if p.moving else 0.0)
	n.get_node("tail").rotation.y = sin(t * (3.0 if not p.moving else 1.0)) * 0.6
	n.get_node("head").position.y = 0.72 + (0.0 if p.moving else 0.02 * sin(t))


func _sync_props() -> void:
	for i in W.props.size():
		var p: Dictionary = W.props[i]
		var n: MeshInstance3D = _prop_nodes[i]
		var near: bool = p["pos"].distance_to(arena.player.pos) < float(wc["draw_m"]) / S
		n.visible = near
		if not near:
			continue
		n.position = to_world(p["pos"])
		n.rotation = Vector3(0, deg_to_rad(p["rot"]), 0)
		match p["state"]:
			"ash":
				n.material_override = _prop_mats["ash"]
				n.scale = Vector3(1.1, 0.25, 1.1)
			"burning":
				n.material_override = _prop_mats.get(p["kind"] + "_burning", _prop_mats["ash"])
				n.scale = Vector3.ONE * (0.92 + 0.08 * float(p["burn_t"]) / maxf(1.0, float(W.prop_def(p["kind"])["burns"])))
				want_light(to_world(p["pos"], 1.2), PixelArt.FIRE, 0.9, 5.0)
			_:
				n.material_override = _prop_mats.get(p["kind"], _prop_mats["crate"])
				n.scale = Vector3.ONE
		if W.prop_def(p["kind"]).get("roll", false) and p["vel"].length() > 4.0:
			# a barrel rolls over on its side while it travels
			var v: Vector2 = p["vel"].normalized()
			n.rotation = Vector3(0, -atan2(v.y, v.x), 0)
			n.rotate_object_local(Vector3.FORWARD, PI / 2.0)
			n.rotate_object_local(Vector3.UP, float(p["spin"]) * 6.0)


## Lanterns and their pools as the town's lamps are lit or put out. Lamps give no real light
## (each one would re-draw everything it touches in the browser renderer); the pools fake it.
func _sync_lamps() -> void:
	var at: Vector2 = arena.player.pos
	var lit: Array = []
	for i in W.lamps.size():
		if W.lamp_on(W.lamps[i]):
			lit.append(i)
		if W.lamps[i]["flare_t"] > 0.0 and W.lamps[i]["pos"].distance_to(at) < 220.0:
			# lightning in the iron: a cold white flash that fades
			want_light(to_world(W.lamps[i]["pos"], 2.75), PixelArt.STORM, 1.6 * W.lamps[i]["flare_t"] / float(W.pd["flare_s"]), 7.0)
	var key := str(lit)
	if key != _lamp_key:
		_lamp_key = key
		town.set_lit(lit)
	var flick := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 90.0)
	for i in W.braziers.size():
		var fire: MeshInstance3D = town.brazier_fires[i]
		var on: bool = W.braziers[i]["lit"]
		fire.visible = on
		if on:
			fire.scale = Vector3(1.0, flick, 1.0)
			if W.braziers[i]["pos"].distance_to(at) < 220.0:
				want_light(to_world(W.braziers[i]["pos"], 1.6), PixelArt.FIRE, 0.5, 6.0)


## The mill wheel, the ruin's doors, the roof of the building you're in, and scorches on walls.
func _sync_town(delta: float) -> void:
	if town.wheel != null:
		town.wheel.rotation.x += delta * 0.7
	for did in town.door_nodes:
		town.door_nodes[did].visible = not W.map.doors[did]["open"]
	for i in town.crack_mis.size():
		var hot: bool = arena.crack_glow.has(str(W.map.cracks[i]["id"]))
		town.crack_mis[i].material_override = town.crack_hot if hot else town.crack_mat
		if hot:
			want_light(to_world(W.map.cracks[i]["rect"].get_center(), 1.2), PixelArt.FIRE, 1.2, 5.0)
	var inside: String = W.map.building_at(arena.player.pos)
	if inside != _inside:
		for id in town.roofs:
			for mi in town.roofs[id]:
				mi.visible = id != inside
		_inside = inside
	var key := "%d:%s" % [W.scorches.size(), str(W.scorches[-1]["pos"]) if not W.scorches.is_empty() else ""]
	if key != _scorch_key:
		_scorch_key = key
		for c in _scorch_root.get_children():
			c.queue_free()
		for s in W.scorches:
			_scorch_root.add_child(_scorch_mesh(s))


## A five-pointed black star burnt into a wall where a fire spell hit it.
func _scorch_mesh(s: Dictionary) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for k in 10:
		var a := k * TAU / 10.0 - PI / 2.0
		var r := 0.75 if k % 2 == 0 else 0.28
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for k in 10:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[k])
		st.add_vertex(pts[(k + 1) % 10])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.03, 0.025, 0.02, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: Vector2 = s["dir"]
	mi.position = to_world(s["pos"] - d * 1.5, 1.3)
	mi.rotation.y = -atan2(d.y, d.x) + PI / 2.0
	return mi


func _place_lights() -> void:
	var scale := 1.0 if warm > 0 else float(_mood.get("lights", 1.0))
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
