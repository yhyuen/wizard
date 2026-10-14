extends Node3D
## One figure on the field: a low-poly model drawn flat-shaded (every face its own tone), posed
## from the shared animation library each frame. Purely visual: the sim's Unit stays the truth
## and this never changes it.

const DIR := "res://assets/models/figures/"
const SHADER := preload("res://scripts/view/lowpoly.gdshader")
const BLEND := 0.08

static var _lib: AnimationLibrary

var model: Node3D
var skel: Skeleton3D
var mats: Array[ShaderMaterial] = []
var _tree: AnimationTree
var _slot := 0
var _clip := ["", ""]
var _time := [0.0, 0.0]
var _blend := 1.0
var _base_scale := 1.0


## A flat-shaded material for meshes made in code (hats, rocks, the shrine, spell shapes).
## `glow` > 0 makes it emit its own colour.
static func mat(col: Color, glow := 0.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.set_shader_parameter("albedo", col)
	sm.set_shader_parameter("glow", glow)
	return sm


## Flat shading on every surface under `n`. `remap` swaps a recipe colour (hex,
## no #) for another; `tint` (alpha = amount) pulls every other colour toward one tone.
static func style(n: Node, darken: float, remap := {}, tint := Color(0, 0, 0, 0), out: Array = []) -> void:
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
			var sm := mat(col.darkened(darken))
			mi.set_surface_override_material(s, sm)
			out.append(sm)
	for c in n.get_children():
		style(c, darken, remap, tint, out)


## `def` comes from data/visual.json "figures": model, scale, colors, tint, hat, eyes, weapon.
func build(def: Dictionary, darken: float) -> void:
	model = (load(DIR + str(def["model"]) + ".glb") as PackedScene).instantiate()
	add_child(model)
	_base_scale = float(def.get("scale", 1.0))
	scale = Vector3.ONE * _base_scale
	var tint := Color(0, 0, 0, 0)
	if def.has("tint"):
		tint = Color(str(def["tint"][0]), float(def["tint"][1]))
	var out: Array = []
	style(model, darken, def.get("colors", {}), tint, out)
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
	if def.has("eyes"):
		_eyes(Color(str(def["eyes"])))

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
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := mat(col)
	mats.append(m)
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	at.add_child(mi)


static func _cyl(top: float, bottom: float, h: float, segs := 7) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return cm


## Hats are parts on the head bone, so they ride every clip: "wizard" (a wide brim and a tall
## crooked cone with a band) or "frontier" (a flat brim and a low crown).
func _hat(h: Dictionary) -> void:
	if skel == null:
		return
	var at := _bone_node("head")
	var col := Color(str(h["color"]))
	var band := Color(str(h.get("band", h["color"])))
	var y := 0.25
	match str(h["kind"]):
		"wizard":
			_part(at, _cyl(0.3, 0.33, 0.03, 8), col, Vector3(0, y - 0.02, 0))
			_part(at, _cyl(0.135, 0.15, 0.06), band, Vector3(0, y + 0.02, 0))
			_part(at, _cyl(0.0, 0.15, 0.5, 6), col, Vector3(0, y + 0.23, -0.03), Vector3(-14, 0, 0))
		_:
			_part(at, _cyl(0.26, 0.28, 0.03, 8), col, Vector3(0, y - 0.03, 0))
			_part(at, _cyl(0.12, 0.14, 0.14), col, Vector3(0, y + 0.05, 0))
			_part(at, _cyl(0.142, 0.142, 0.03), band, Vector3(0, y + 0.0, 0))


## Two glowing points on the face (the Hollows' ember eyes).
func _eyes(col: Color) -> void:
	if skel == null:
		return
	var at := _bone_node("head")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	for sx in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.024
		sm.height = 0.048
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = m
		mi.position = Vector3(0.035 * sx, 0.08, 0.1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
