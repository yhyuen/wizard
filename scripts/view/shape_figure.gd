extends Node3D
## Sphere-born figures made of shapes, not skinned models (GDD v2: unskinned shapes are the cheap
## road for things born of the Spheres). It answers the view the way Figure does (build, pose,
## set_look) and uses the figures' own material, so nothing new compiles. data/visual.json
## figures with a "shape" use it:
##   ember: a flame core in a cage of dark faceted shards that bob and tilt.
##   kiln: the Kiln Warden, a squat furnace with a glowing grate at the front and three vents.
##   beast: a low four-legged body (N-7.6.3): a dog, a rat, a crawler of thorn ("spikes"); its legs
##   trot while it moves and it crouches into a wind-up. "body" is its colour, "eyes" its glint,
##   "long" stretches the body.

const Figure := preload("res://scripts/view/figure.gd")

var mats: Array[ShaderMaterial] = []
var _shape := ""
var _t := 0.0
var _base_scale := 1.0
var _cage: MeshInstance3D
var _core: MeshInstance3D
var _core_mat: ShaderMaterial
var _vent_mat: ShaderMaterial
var _glow := 2.0
var _legs: Array[MeshInstance3D] = []
var _torso: Node3D


func build(def: Dictionary, _darken: float) -> void:
	_shape = str(def["shape"])
	_base_scale = float(def.get("scale", 1.0))
	scale = Vector3.ONE * _base_scale
	_t = randf() * 3.0
	var body := Color(str(def.get("body", "2a2420")))
	var hot := Color(str(def.get("glow", "ff7a2a")))
	_glow = float(def.get("glow_k", 2.0))
	match _shape:
		"ember":
			_core_mat = _add_mat(hot, _glow)
			var sm := SphereMesh.new()
			sm.radius = 0.17
			sm.height = 0.34
			sm.radial_segments = 6
			sm.rings = 3
			_core = _mesh(sm, _core_mat, Vector3(0, 0.7, 0))
			# five shards round the core, merged so the cage is one draw
			var pm := PrismMesh.new()
			pm.size = Vector3(0.14, 0.38, 0.1)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 5:
				var a := i * TAU / 5.0
				var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5 + 0.25 * (i % 2))
				st.append_from(pm, 0, Transform3D(b, Vector3(cos(a) * 0.3, 0.1 * (i % 3) - 0.05, sin(a) * 0.3)))
			st.generate_normals()
			_cage = _mesh(st.commit(), _add_mat(body, 0.0), Vector3(0, 0.7, 0))
		"kiln":
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var drum := CylinderMesh.new()
			drum.top_radius = 1.0
			drum.bottom_radius = 1.25
			drum.height = 1.6
			drum.radial_segments = 8
			drum.rings = 1
			st.append_from(drum, 0, Transform3D(Basis(), Vector3(0, 0.8, 0)))
			var dome := CylinderMesh.new()
			dome.top_radius = 0.45
			dome.bottom_radius = 1.0
			dome.height = 0.6
			dome.radial_segments = 8
			dome.rings = 1
			st.append_from(dome, 0, Transform3D(Basis(), Vector3(0, 1.9, 0)))
			var flue := CylinderMesh.new()
			flue.top_radius = 0.3
			flue.bottom_radius = 0.35
			flue.height = 1.2
			flue.radial_segments = 6
			flue.rings = 1
			st.append_from(flue, 0, Transform3D(Basis(), Vector3(0, 2.7, 0)))
			st.generate_normals()
			_mesh(st.commit(), _add_mat(body, 0.0), Vector3.ZERO)
			# the grate at the front (+z faces the wizard): glowing bars
			_core_mat = _add_mat(hot, _glow)
			var gs := SurfaceTool.new()
			gs.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 5:
				var bar := BoxMesh.new()
				bar.size = Vector3(0.09, 0.8, 0.12)
				gs.append_from(bar, 0, Transform3D(Basis(), Vector3(-0.36 + i * 0.18, 0.75, 1.17)))
			gs.generate_normals()
			_core = _mesh(gs.commit(), _core_mat, Vector3.ZERO)
			# three vents: left, right and back; dark until the second phase
			_vent_mat = _add_mat(hot, 0.0)
			var vs := SurfaceTool.new()
			vs.begin(Mesh.PRIMITIVE_TRIANGLES)
			for a in [PI / 2.0, -PI / 2.0, PI]:
				var v := BoxMesh.new()
				v.size = Vector3(0.5, 0.3, 0.12)
				var b := Basis(Vector3.UP, a)
				vs.append_from(v, 0, Transform3D(b, b * Vector3(0, 1.1, 1.12)))
			vs.generate_normals()
			_mesh(vs.commit(), _vent_mat, Vector3.ZERO)
		"beast":
			_beast(def, body)


func _beast(def: Dictionary, body: Color) -> void:
	var long := float(def.get("long", 1.0))
	_torso = Node3D.new()
	add_child(_torso)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := BoxMesh.new()
	trunk.size = Vector3(0.34, 0.3, 0.7 * long)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 0.42, 0)))
	var head := PrismMesh.new()
	head.size = Vector3(0.26, 0.26, 0.32)
	st.append_from(head, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.5, 0.42 * long + 0.1)))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.06, 0.06, 0.34)
	st.append_from(tail, 0, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.55, -0.4 * long - 0.12)))
	if def.get("spikes", false):
		var thorn := PrismMesh.new()
		thorn.size = Vector3(0.1, 0.24, 0.1)
		for i in 7:
			var a := i * 2.4
			st.append_from(thorn, 0, Transform3D(Basis(Vector3.FORWARD, 0.6 * sin(a)), Vector3(0.12 * sin(a), 0.66, -0.3 * long + i * 0.1 * long)))
	st.generate_normals()
	var bm := _add_mat(body, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_torso.add_child(mi)
	var em := SphereMesh.new()
	em.radius = 0.035
	em.height = 0.07
	em.radial_segments = 4
	em.rings = 2
	var eye_mat := _add_mat(Color(str(def.get("eyes", "ffd36b"))), 1.6)
	for sx in [-0.07, 0.07]:
		var e := MeshInstance3D.new()
		e.mesh = em
		e.material_override = eye_mat
		e.position = Vector3(sx, 0.56, 0.42 * long + 0.2)
		_torso.add_child(e)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.08, 0.3, 0.08)
	for at in [Vector3(-0.12, 0.15, 0.25 * long), Vector3(0.12, 0.15, 0.25 * long), Vector3(-0.12, 0.15, -0.25 * long), Vector3(0.12, 0.15, -0.25 * long)]:
		_legs.append(_mesh(leg, bm, at))


func _add_mat(col: Color, glow: float) -> ShaderMaterial:
	var m := Figure.fade_mat(col, glow)
	mats.append(m)
	return m


func _mesh(m: Mesh, mat: ShaderMaterial, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Shapes have no clips: an attack wind-up flares the core, a hit shakes it, moving tilts the cage.
func pose(clip: String, t: float, delta: float) -> void:
	_t += delta
	match _shape:
		"ember":
			var tense := clip in ["overhead", "cast", "channel"]
			_cage.rotation = Vector3(0.25 * sin(_t * 2.3), _t * (5.0 if tense else 1.6), 0.25 * cos(_t * 1.9))
			_cage.position.y = 0.7 + 0.06 * sin(_t * 4.0)
			_core.position.y = 0.7 + 0.04 * sin(_t * 6.0 + 1.0)
			var s := 1.0 + (0.35 * minf(t * 3.0, 1.0) if tense else 0.08 * sin(_t * 9.0))
			_core.scale = Vector3.ONE * s
			if clip in ["down"]:
				_cage.position.y = maxf(0.15, 0.7 - t * 1.2)
		"beast":
			var moving := clip.contains("run") or clip.contains("walk")
			var tense := clip in ["overhead", "cast", "channel", "slash", "thrust"]
			for i in _legs.size():
				var ph := _t * 14.0 + (PI if i % 3 == 0 else 0.0)
				_legs[i].rotation.x = 0.6 * sin(ph) if moving else 0.0
			_torso.position.y = (0.03 * absf(sin(_t * 14.0)) if moving else 0.0) - (0.1 if tense else 0.0)
			_torso.rotation.x = 0.25 if tense else 0.0
			if clip == "down":
				_torso.rotation.z = minf(t * 3.0, 1.4)


## The view's per-frame look of the unit behind it: the grate glows white before a ring, is dark
## and steaming when flooded, and the vents light up in the second phase.
func sync_unit(u) -> void:
	if _shape != "kiln" or u == null:
		return
	var ring_t := float(u.flags.get("ring_t", 9.0))
	var k := 1.0 - clampf(ring_t / 1.0, 0.0, 1.0)
	var flooded: bool = u.flags.get("flooded", false) and int(u.flags.get("phase", 1)) == 1
	_core_mat.set_shader_parameter("albedo", Color("ff7a2a").lerp(Color("fff4e0"), k * (0.0 if flooded else 1.0)))
	_core_mat.set_shader_parameter("glow", 0.4 if flooded else _glow * (1.0 + k) * (0.85 + 0.15 * sin(_t * 3.0)))
	_vent_mat.set_shader_parameter("glow", 2.2 if int(u.flags.get("phase", 1)) == 2 else 0.0)


func set_look(flash: float, flash_col: Color, fade: float, dark: float) -> void:
	for m in mats:
		m.set_shader_parameter("flash", 0.25 + 0.6 * flash if flash > 0.0 else 0.0)
		m.set_shader_parameter("flash_color", flash_col)
		m.set_shader_parameter("fade", fade)
		m.set_shader_parameter("darken", dark)
	var sq := 0.07 * flash
	scale = Vector3(1.0 + sq, 1.0 - sq * 0.7, 1.0 + sq) * _base_scale
