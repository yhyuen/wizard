extends SceneTree
## Top-down previews of every map in data/world/maps.json, for checking a layout without playing
## it (design/ruins/tech-plan.md §2):
##
##   godot --headless --script res://tools/map_preview.gd -- --out DIR
##
## Writes <map>.png (shapes only) and <map>.svg (the same, with every place, spot, item, exit and
## nav node named) for each map. Walls and blocks are grey, rubble brown, tents tan, pillars and
## other circles light grey, water blue, pits black, glowing cracks red, sealed doors purple and
## open ones green, exits yellow, the nav graph cyan, spots white, items gold, lamps orange and
## braziers red. The faint grid is every 10 m (180 px).

const Map := preload("res://scripts/world/map.gd")
const SCALE := 0.5  # image px per sim px
const GRID := 180.0  # 10 m
const COLORS := {
	"bg": "2a2a30", "grid": "34343c", "place": "4a4a58", "cliff": "4e4a44", "wall": "8a8690", "block": "6e6a74",
	"building": "8a8690", "stall": "7a6a50", "tent": "a89870", "rubble": "7a6450", "crack": "e04030",
	"circle": "a8a4ae", "water": "3a6a9a", "bridge": "8a7050", "pit": "08080a", "sealed": "9a5ad0",
	"open": "5ab070", "exit": "e8c840", "nav": "40a0b0", "spot": "f0f0f0", "item": "e0b040", "lamp": "f09040",
	"brazier": "e05030", "rail": "5a6a7a",
}

var out := "user://map_preview"
var img: Image
var svg: PackedStringArray
var origin := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/maps.json"))
	for mid in reg["maps"]:
		var def: Dictionary = reg["maps"][mid]
		var m = Map.new(str(def["path"]), mid, str(def.get("kit", "town")))
		_draw(m, str(def.get("name", mid)))
		print("[map-preview] %s: %s.png and %s.svg (%d x %d m)" % [def.get("name", mid), mid, mid,
			int(m.bounds.size.x / 18.0), int(m.bounds.size.y / 18.0)])
	quit()


func _draw(m, title: String) -> void:
	origin = m.bounds.position
	var size := Vector2i((m.bounds.size as Vector2 * SCALE).ceil())
	img = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	img.fill(_c("bg"))
	svg = PackedStringArray()
	svg.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="sans-serif" font-size="9">' % [size.x, size.y])
	svg.append('<rect width="100%%" height="100%%" fill="#%s"/>' % COLORS["bg"])
	var x: float = m.bounds.position.x
	while x <= m.bounds.end.x:
		_line(Vector2(x, m.bounds.position.y), Vector2(x, m.bounds.end.y), "grid")
		x += GRID
	var y: float = m.bounds.position.y
	while y <= m.bounds.end.y:
		_line(Vector2(m.bounds.position.x, y), Vector2(m.bounds.end.x, y), "grid")
		y += GRID
	for pid in m.places:
		var pl: Dictionary = m.places[pid]
		if pl.has("rect"):
			var r: Array = pl["rect"]
			_rect(Rect2(r[0], r[1], r[2], r[3]), "place", false)
			_label(Vector2(r[0] + 4, r[1] + 11), pl["name"], "place")
		elif pl.has("circle"):
			var c: Array = pl["circle"]
			_circle(Vector2(c[0], c[1]), c[2], "place", false)
			_label(Vector2(c[0], c[1]) + Vector2(-20, -float(c[2]) + 11), pl["name"], "place")
	for w in m.water:
		_rect(w, "water")
	for b in m.bridges:
		_rect(b, "bridge")
	for pit in m.pits:
		_rect(pit, "pit")
	for rk in m.rects:
		var kind: String = rk[1]
		_rect(rk[0], kind if COLORS.has(kind) else "wall")
	for c in m.circles:
		_circle(c[0], c[1], "circle")
	for did in m.doors:
		var dr: Dictionary = m.doors[did]
		_rect(dr["rect"], "open" if dr["open"] else "sealed")
		_label((dr["rect"] as Rect2).end + Vector2(2, 0), did, "open" if dr["open"] else "sealed")
	for eid in m.exits:
		var ex: Dictionary = m.exits[eid]
		_rect(ex["rect"], "exit", false)
		_label((ex["rect"] as Rect2).position + Vector2(0, -3), "%s → %s %s" % [eid, ex["to"], ex["at"]], "exit")
	for a in m.adj:
		for b in m.adj[a]:
			if str(a) < str(b):
				_line(m.nodes[a], m.nodes[b], "nav")
	for nid in m.nodes:
		_circle(m.nodes[nid], 4.0, "nav")
	for r in m.d.get("rails", []):
		_rect(Rect2(Vector2(r[1], r[2]), Vector2.ZERO).expand(Vector2(r[3], r[4])).grow(4.0), "rail")
	for l in m.d.get("lamps", []):
		_circle(Vector2(l[0], l[1]), 5.0, "lamp")
		if l.size() > 3:
			_label(Vector2(l[0], l[1]) + Vector2(5, -5), str(l[3]), "lamp")
	for b in m.d.get("braziers", []):
		_circle(Vector2(b[0], b[1]), 7.0, "brazier")
	for sid in m.spots:
		_circle(m.spots[sid], 4.0, "spot")
		_label(m.spots[sid] + Vector2(6, 3), sid, "spot")
	for iid in m.items:
		var at: Vector2 = m.items[iid]["at"]
		_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), "item")
		_label(at + Vector2(8, -6), iid, "item")
	_label(m.bounds.position + Vector2(8, 24), title, "spot", 16)
	svg.append("</svg>")
	img.save_png(out.path_join(m.id + ".png"))
	var f := FileAccess.open(out.path_join(m.id + ".svg"), FileAccess.WRITE)
	f.store_string("\n".join(svg) + "\n")


func _c(key: String) -> Color:
	return Color.html(COLORS[key])


func _p(v: Vector2) -> Vector2:
	return (v - origin) * SCALE


func _rect(r: Rect2, key: String, fill := true) -> void:
	var a := _p(r.position)
	var b := _p(r.end)
	var ir := Rect2i(Vector2i(a.floor()), Vector2i((b - a).ceil()).max(Vector2i.ONE))
	if fill:
		img.fill_rect(ir.intersection(Rect2i(Vector2i.ZERO, img.get_size())), _c(key))
		svg.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#%s"/>' % [a.x, a.y, b.x - a.x, b.y - a.y, COLORS[key]])
	else:
		for edge in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
			_px_line(edge[0], edge[1], _c(key))
		svg.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" stroke="#%s"/>' % [a.x, a.y, b.x - a.x, b.y - a.y, COLORS[key]])


func _circle(c: Vector2, r: float, key: String, fill := true) -> void:
	var p := _p(c)
	var pr := maxf(1.0, r * SCALE)
	if fill:
		for yy in range(int(p.y - pr), int(p.y + pr) + 1):
			for xx in range(int(p.x - pr), int(p.x + pr) + 1):
				if Vector2(xx, yy).distance_to(p) <= pr and xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
					img.set_pixel(xx, yy, _c(key))
		svg.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#%s"/>' % [p.x, p.y, pr, COLORS[key]])
	else:
		var n := maxi(12, int(pr))
		for i in n:
			_px_line(p + Vector2.from_angle(TAU * i / n) * pr, p + Vector2.from_angle(TAU * (i + 1) / n) * pr, _c(key))
		svg.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#%s"/>' % [p.x, p.y, pr, COLORS[key]])


func _line(a: Vector2, b: Vector2, key: String) -> void:
	_px_line(_p(a), _p(b), _c(key))
	svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#%s"/>' % [_p(a).x, _p(a).y, _p(b).x, _p(b).y, COLORS[key]])


func _px_line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, int(a.distance_to(b)))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixel(int(q.x), int(q.y), col)


func _label(at: Vector2, text: String, key: String, size := 9) -> void:
	var p := _p(at)
	svg.append('<text x="%.1f" y="%.1f" fill="#%s" font-size="%d">%s</text>' % [p.x, p.y, COLORS[key], size, text.xml_escape()])
