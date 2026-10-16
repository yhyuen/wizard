extends Node3D
## The edge of Vellmar round the Mill yard at night: timber-framed houses with lit windows past the
## fence, and lamp posts whose lanterns are real lights. Built once from data/visual.json "town";
## purely set dressing, nothing here touches the sim.

const Figure := preload("res://scripts/view/figure.gd")

var view  # view3d.gd, for to_world() and height()
var pal: Dictionary
var _mats := {}


func build(the_view, cfg: Dictionary) -> void:
	view = the_view
	pal = cfg["palette"]
	var walls := ["wall", "wall2", "wall3"]
	var roofs := ["roof", "roof2", "roof3"]
	var i := 0
	for h in cfg["houses"]:
		# [sim x, sim y, width m, depth m, height m, facing degrees]
		var at: Vector3 = view.to_world(Vector2(h[0], h[1]))
		_house(at, float(h[2]), float(h[3]), float(h[4]), float(h[5]), c(walls[i % 3]), c(roofs[(i + 1) % 3]))
		i += 1
	for l in cfg["lamps"]:
		_lamp(view.to_world(Vector2(l[0], l[1])), cfg)


func c(k: String) -> Color:
	return Color(str(pal[k]))


## One material per colour, finish and glow, so the many boxes share them.
func _mat(col: Color, surf: String, glow := 0.0) -> ShaderMaterial:
	var key := "%s/%s/%s" % [col.to_html(false), surf, glow]
	if not _mats.has(key):
		var m := Figure.mat(col, glow)
		m.set_shader_parameter("facet", 0.0)
		if glow == 0.0:
			Figure.finish(m, surf)
		_mats[key] = m
	return _mats[key]


func _mesh(m: Mesh, pos: Vector3, col: Color, parent: Node3D, surf := "stone", glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(col, surf, glow)
	mi.position = pos
	if glow > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, col: Color, parent: Node3D, surf := "stone", glow := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, pos, col, parent, surf, glow)


func _house(at: Vector3, w: float, d: float, h: float, face: float, wall: Color, roof: Color) -> void:
	var n := Node3D.new()
	n.position = Vector3(at.x, view.height(at.x, at.z) - 0.1, at.z)
	n.rotation_degrees.y = face
	add_child(n)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall, n, "stone")
	_box(Vector3(w + 0.1, 0.7, d + 0.1), Vector3(0, 0.35, 0), c("stone"), n, "stone")
	# timber frame on the front face (+z)
	var posts := maxi(1, int(w / 1.2))
	for k in posts + 1:
		_box(Vector3(0.14, h - 0.7, 0.12), Vector3(-w * 0.5 + k * (w / posts), h * 0.5 + 0.35, d * 0.5 + 0.03), c("timber"), n, "prop")
	_box(Vector3(w, 0.16, 0.14), Vector3(0, h * 0.55, d * 0.5 + 0.04), c("timber"), n, "prop")
	_box(Vector3(w, 0.16, 0.14), Vector3(0, h - 0.05, d * 0.5 + 0.04), c("timber"), n, "prop")
	# windows: most lit, a few dark
	for k in int(w / 1.6):
		var wx := -w * 0.5 + 0.8 + k * 1.6
		var lit := (k + int(at.x * 3.0)) % 3 != 0
		_box(Vector3(0.5, 0.7, 0.06), Vector3(wx, h * 0.75, d * 0.5 + 0.06), c("window") if lit else c("timber"), n, "prop", 1.3 if lit else 0.0)
		_box(Vector3(0.5, 0.6, 0.06), Vector3(wx, h * 0.3 + 0.35, d * 0.5 + 0.06), c("window"), n, "prop", 1.0)
	_box(Vector3(0.8, 1.5, 0.08), Vector3(w * 0.25, 1.1, d * 0.5 + 0.06), c("timber"), n, "prop")
	# roof: a prism along the width, and a chimney
	var pm := PrismMesh.new()
	pm.size = Vector3(d + 0.6, h * 0.55, w + 0.4)
	var rf := _mesh(pm, Vector3(0, h + h * 0.275, 0), roof, n, "stone")
	rf.rotation_degrees.y = 90
	_box(Vector3(0.4, 1.2, 0.4), Vector3(-w * 0.3, h + h * 0.4, -d * 0.15), c("stone"), n, "stone")


## A lamp post with a glowing lantern and a real warm light.
func _lamp(at: Vector3, cfg: Dictionary) -> void:
	var n := Node3D.new()
	n.position = Vector3(at.x, view.height(at.x, at.z), at.z)
	add_child(n)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.08
	post.height = 2.6
	post.radial_segments = 6
	_mesh(post, Vector3(0, 1.3, 0), c("timber"), n, "metal")
	_box(Vector3(0.32, 0.38, 0.32), Vector3(0, 2.75, 0), c("window"), n, "prop", 2.2)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.28
	cap.height = 0.28
	cap.radial_segments = 4
	_mesh(cap, Vector3(0, 3.08, 0), c("timber"), n, "metal")
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.6, 0)
	l.light_color = Color(str(cfg["lamp_color"]))
	l.light_energy = float(cfg["lamp_energy"])
	l.omni_range = float(cfg["lamp_range"])
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	n.add_child(l)
