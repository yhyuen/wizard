extends Node3D
## One figure on the field: a low-poly model, shaded soft or faceted (`facet`), posed from the
## shared animation library each frame. Wizards wear Magicka-style deep hoods with glowing eyes
## and carry a staff with a glowing gem. Purely visual: the sim's Unit stays the truth
## and this never changes it.

const DIR := "res://assets/models/figures/"
const SHADER := preload("res://scripts/view/lowpoly.gdshader")  # figures: can fade, two-sided
const SOLID := preload("res://scripts/view/lowpoly_solid.gdshader")  # everything else
const CUT := preload("res://scripts/view/lowpoly_cut.gdshader")  # town chunks on the line of sight
const BLEND := 0.08

static var _lib: AnimationLibrary
## Surface finishes by name ("figure", "prop", "stone", "metal", "ground"): bump, bump_scale,
## mottle, spec, gloss, wrap, rim. The view fills this from data/visual.json "surfaces".
static var SURFACES := {}
static var _bump_tex: NoiseTexture2D
static var _mottle_tex: NoiseTexture2D

var model: Node3D
var skel: Skeleton3D
var mats: Array[ShaderMaterial] = []
var _tree: AnimationTree
var _slot := 0
var _clip := ["", ""]
var _time := [0.0, 0.0]
var _blend := 1.0
var _base_scale := 1.0


## A flat-shaded material for meshes made in code (rocks, the shrine, spell shapes, the town).
## `glow` > 0 makes it emit its own colour. It can't fade; a figure's own parts use fade_mat.
static func mat(col: Color, glow := 0.0, shader: Shader = SOLID) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("albedo", col)
	sm.set_shader_parameter("glow", glow)
	return sm


## A figure's material: two-sided, and it can fade out (dithered).
static func fade_mat(col: Color, glow := 0.0) -> ShaderMaterial:
	return mat(col, glow, SHADER)


## Give a material one of the named finishes (see SURFACES). Glowing shapes keep theirs.
static func finish(sm: ShaderMaterial, surf: String) -> ShaderMaterial:
	if surf == "" or not SURFACES.has(surf):
		return sm
	if _bump_tex == null:
		_bump_tex = _noise_tex(true)
		_mottle_tex = _noise_tex(false)
	sm.set_shader_parameter("bump_tex", _bump_tex)
	sm.set_shader_parameter("mottle_tex", _mottle_tex)
	var f: Dictionary = SURFACES[surf]
	for k in f:
		if not str(k).begins_with("_"):
			sm.set_shader_parameter(k, float(f[k]))
	return sm


## A seamless noise shared by every finish: as a normal map (the bump) or plain (the mottle).
static func _noise_tex(normal: bool) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.generate_mipmaps = true
	t.as_normal_map = normal
	t.bump_strength = 4.0
	var n := FastNoiseLite.new()
	n.seed = 11 if normal else 5
	n.frequency = 0.02
	n.fractal_octaves = 4
	t.noise = n
	return t


## Shading on every surface under `n`, with the `surf` finish. `remap` swaps a recipe colour (hex,
## no #) for another; `tint` (alpha = amount) pulls every other colour toward one tone.
static func style(n: Node, darken: float, remap := {}, tint := Color(0, 0, 0, 0), out: Array = [], facet := 1.0, surf := "") -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var col: Color = src.albedo_color if src != null else Color.GRAY
			var hx := col.to_html(false)
			if remap.has(hx):
				col = Color(str(remap[hx]))
			elif tint.a > 0.0:
				col = col.lerp(Color(tint, 1.0), tint.a)
			var sm := fade_mat(col.darkened(darken))
			sm.set_shader_parameter("facet", facet)
			finish(sm, surf)
			mi.set_surface_override_material(s, sm)
			out.append(sm)
	for c in n.get_children():
		style(c, darken, remap, tint, out, facet, surf)


## Every surface of a model's mesh merged into one, coloured per vertex (the same colours
## style() gives each surface): a figure then costs one draw, and one shadow draw, instead of one
## per colour, which is most of what a crowd costs in the browser renderer. A mesh that can't be
## merged (mixed formats) is styled surface by surface.
static func merge_style(n: Node, darken: float, remap: Dictionary, tint: Color, out: Array, facet: float) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var src: Mesh = mi.mesh
		var fmt0: int = src.surface_get_format(0) if src.get_surface_count() > 0 else 0
		var ok := src.get_surface_count() > 1
		for sf in src.get_surface_count():
			var f: int = src.surface_get_format(sf)
			if (f & Mesh.ARRAY_FORMAT_BONES) != (fmt0 & Mesh.ARRAY_FORMAT_BONES) or (f & Mesh.ARRAY_FORMAT_INDEX) == 0 \
					or src.surface_get_primitive_type(sf) != Mesh.PRIMITIVE_TRIANGLES:
				ok = false
		if not ok:
			style(n, darken, remap, tint, out, facet, "figure")
			return
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		var bones = null
		var weights := PackedFloat32Array()
		for sf in src.get_surface_count():
			var a := src.surface_get_arrays(sf)
			var srcm := src.surface_get_material(sf) as BaseMaterial3D
			var col: Color = srcm.albedo_color if srcm != null else Color.GRAY
			var hx := col.to_html(false)
			if remap.has(hx):
				col = Color(str(remap[hx]))
			elif tint.a > 0.0:
				col = col.lerp(Color(tint, 1.0), tint.a)
			col = col.darkened(darken).srgb_to_linear()
			var base := verts.size()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			verts.append_array(v)
			norms.append_array(a[Mesh.ARRAY_NORMAL])
			for i in v.size():
				cols.append(col)
			for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
				idx.append(i + base)
			if a[Mesh.ARRAY_BONES] != null:
				if bones == null:
					bones = a[Mesh.ARRAY_BONES].duplicate()
				else:
					bones.append_array(a[Mesh.ARRAY_BONES])
				weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		if bones != null:
			arr[Mesh.ARRAY_BONES] = bones
			arr[Mesh.ARRAY_WEIGHTS] = weights
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt0 & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		mi.mesh = am
		var sm := fade_mat(Color.WHITE)
		sm.set_shader_parameter("vcol_albedo", true)
		sm.set_shader_parameter("facet", facet)
		finish(sm, "figure")
		mi.material_override = sm
		out.append(sm)
	for c in n.get_children():
		merge_style(c, darken, remap, tint, out, facet)


var _facet := 1.0
var gem: MeshInstance3D  # the staff's gem, lit by the view in the caster's element colour
var _parts := {}  # bone attachment -> SurfaceTool: hats and mantles, merged per bone


## `def` comes from data/visual.json "figures": model, scale, colors, tint, hat, eyes, weapon,
## facet (1 faceted .. 0 smooth), staff_gem.
func build(def: Dictionary, darken: float) -> void:
	model = (load(DIR + str(def["model"]) + ".glb") as PackedScene).instantiate()
	add_child(model)
	_base_scale = float(def.get("scale", 1.0))
	scale = Vector3.ONE * _base_scale
	var tint := Color(0, 0, 0, 0)
	if def.has("tint"):
		tint = Color(str(def["tint"][0]), float(def["tint"][1]))
	_facet = float(def.get("facet", 1.0))
	var out: Array = []
	merge_style(model, darken, def.get("colors", {}), tint, out, _facet)
	for m in out:
		mats.append(m)
	for n in model.find_children("*", "Skeleton3D", true, false):
		skel = n
		break
	var weapon := str(def.get("weapon", "none"))
	for w in ["sword", "blade", "staff"]:
		var wn := model.find_child("weapon_" + w, true, false)
		if wn != null:
			wn.visible = w == weapon
	if def.has("hat"):
		_hat(def["hat"])
		_commit_parts()
	var hooded: bool = def.has("hat") and str(def["hat"]["kind"]) == "hood"
	if def.has("eyes"):
		_eyes(Color(str(def["eyes"])), 0.19 if hooded else 0.1, 0.06 if hooded else 0.08)
	if weapon == "staff" and def.has("staff_gem"):
		_staff_gem(Color(str(def["staff_gem"])))

	if _lib == null:
		var src: Node = (load(DIR + "anims.glb") as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		_lib = ap.get_animation_library("").duplicate(true)
		src.free()
	_tree = AnimationTree.new()
	_tree.add_animation_library("", _lib)
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(model)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bt := AnimationNodeBlendTree.new()
	for i in 2:
		var an := AnimationNodeAnimation.new()
		an.animation = &"stand"
		bt.add_node("a%d" % i, an)
		bt.add_node("s%d" % i, AnimationNodeTimeSeek.new())
		bt.connect_node("s%d" % i, 0, "a%d" % i)
	bt.add_node("mix", AnimationNodeBlend2.new())
	bt.connect_node("mix", 0, "s0")
	bt.connect_node("mix", 1, "s1")
	bt.connect_node("output", 0, "mix")
	_tree.tree_root = bt
	_tree.active = true


static func clip_len(clip: String) -> float:
	return _lib.get_animation(clip).length if _lib != null and _lib.has_animation(clip) else 1.0


## Shows `clip` at `t` seconds, crossfading from the last clip.
func pose(clip: String, t: float, delta: float) -> void:
	if not _lib.has_animation(clip):
		clip = "stand"
	if clip != _clip[_slot]:
		_slot = 1 - _slot
		_clip[_slot] = clip
		_blend = 0.0
		var an: AnimationNodeAnimation = (_tree.tree_root as AnimationNodeBlendTree).get_node("a%d" % _slot)
		an.animation = StringName(clip)
	_time[_slot] = t
	_blend = minf(1.0, _blend + delta / BLEND)
	_tree.set("parameters/mix/blend_amount", _blend if _slot == 1 else 1.0 - _blend)
	for i in 2:
		_tree.set("parameters/s%d/seek_request" % i, _time[i])
	_tree.advance(0.0)


## Hit flash (`k` 0 = off), the dithered fade (0 solid .. 1 gone) and the beaten darkening.
func set_look(flash: float, flash_col: Color, fade: float, dark: float) -> void:
	for m in mats:
		m.set_shader_parameter("flash", 0.25 + 0.6 * flash if flash > 0.0 else 0.0)
		m.set_shader_parameter("flash_color", flash_col)
		m.set_shader_parameter("fade", fade)
		m.set_shader_parameter("darken", dark)
	var sq := 0.07 * flash
	scale = Vector3(1.0 + sq, 1.0 - sq * 0.7, 1.0 + sq) * _base_scale


func _bone_node(bone: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba


func _part(at: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO) -> void:
	if not _parts.has(at):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[at] = st
	var st: SurfaceTool = _parts[at]
	var xf := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
	var nb := xf.basis.inverse().transposed()
	var lin := col.srgb_to_linear()
	var a := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx = a[Mesh.ARRAY_INDEX]
	var n: int = idx.size() if idx != null else verts.size()
	for k in n:
		var v: int = idx[k] if idx != null else k
		st.set_color(lin)
		st.set_normal((nb * norms[v]).normalized())
		st.add_vertex(xf * verts[v])


## Each bone's parts as one mesh.
func _commit_parts() -> void:
	for at in _parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _parts[at].commit()
		var m := fade_mat(Color.WHITE)
		m.set_shader_parameter("vcol_albedo", true)
		m.set_shader_parameter("facet", _facet)
		finish(m, "figure")
		mats.append(m)
		mi.material_override = m
		at.add_child(mi)
	_parts.clear()


static func _cyl(top: float, bottom: float, h: float, segs := 7) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return cm


## Hats are parts on the head bone, so they ride every clip: "hood" (Magicka's deep pointed cowl,
## the face lost in shadow, with a mantle and trim on the shoulders), "wizard" (a wide brim and a
## tall crooked cone with a band) or "frontier" (a flat brim and a low crown).
func _hat(h: Dictionary) -> void:
	if skel == null:
		return
	var at := _bone_node("head")
	var col := Color(str(h["color"]))
	var band := Color(str(h.get("band", h["color"])))
	var y := 0.25
	match str(h["kind"]):
		"hood":
			var cowl := SphereMesh.new()
			cowl.radius = 0.2
			cowl.height = 0.4
			cowl.radial_segments = 10
			cowl.rings = 5
			_part(at, cowl, col, Vector3(0, 0.09, -0.01))
			# the opening: a dark oval where the face should be
			_part(at, _cyl(0.115, 0.115, 0.02, 10), Color("120e16"), Vector3(0, 0.06, 0.175), Vector3(90, 0, 0))
			_part(at, _cyl(0.0, 0.16, 0.42, 8), col, Vector3(0, 0.33, -0.12), Vector3(-38, 0, 0))
			var ch := _bone_node("chest")
			_part(ch, _cyl(0.15, 0.31, 0.24, 10), col, Vector3(0, 0.15, 0))
			_part(ch, _cyl(0.315, 0.315, 0.035, 10), band, Vector3(0, 0.035, 0))
		"wizard":
			_part(at, _cyl(0.3, 0.33, 0.03, 8), col, Vector3(0, y - 0.02, 0))
			_part(at, _cyl(0.135, 0.15, 0.06), band, Vector3(0, y + 0.02, 0))
			_part(at, _cyl(0.0, 0.15, 0.5, 6), col, Vector3(0, y + 0.23, -0.03), Vector3(-14, 0, 0))
		_:
			_part(at, _cyl(0.26, 0.28, 0.03, 8), col, Vector3(0, y - 0.03, 0))
			_part(at, _cyl(0.12, 0.14, 0.14), col, Vector3(0, y + 0.05, 0))
			_part(at, _cyl(0.142, 0.142, 0.03), band, Vector3(0, y + 0.0, 0))


## Two glowing points on the face (the Hollows' ember eyes, the wizard's eyes under the hood).
## They glow past the bloom threshold, so they shine.
func _eyes(col: Color, z := 0.1, y := 0.08) -> void:
	if skel == null:
		return
	var at := _bone_node("head")
	var m := fade_mat(col, 2.5)
	mats.append(m)  # so they fade out with the body
	var sm := SphereMesh.new()
	sm.radius = 0.024
	sm.height = 0.048
	sm.radial_segments = 6
	sm.rings = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		st.append_from(sm, 0, Transform3D(Basis(), Vector3(0.04 * sx, y, z)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.add_child(mi)


## A faceted gem on the far end of the staff, riding the grip bone. The end is found from the
## staff mesh itself, so it follows whatever staff the model carries.
func _staff_gem(col: Color) -> void:
	var staff := model.find_child("weapon_staff", true, false) as MeshInstance3D
	if staff == null or skel == null:
		return
	var grip := skel.find_bone("grip_R")
	if grip < 0:
		return
	var box := staff.get_aabb()
	var rest := skel.get_bone_global_rest(grip)
	var axis := 1 if box.size.y >= box.size.x and box.size.y >= box.size.z else (0 if box.size.x >= box.size.z else 2)
	var lo := box.get_center()
	var hi := box.get_center()
	lo[axis] = box.position[axis]
	hi[axis] = box.end[axis]
	var tip := hi if hi.distance_to(rest.origin) > lo.distance_to(rest.origin) else lo
	var at := _bone_node("grip_R")
	gem = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.16
	sm.radial_segments = 5
	sm.rings = 2
	gem.mesh = sm
	var gm := fade_mat(col, 1.6)
	mats.append(gm)
	gem.material_override = gm
	gem.position = rest.affine_inverse() * tip
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.add_child(gem)
