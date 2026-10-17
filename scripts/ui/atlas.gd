extends Control
## Drawing helpers for the Star Atlas UI (GDD 6.6): navy glass panels with gold hairlines,
## Cormorant serif and small caps, and buttons that are rebuilt each frame while drawing, so a
## click or a number key always matches what is on screen.

const BG := Color(0.035, 0.055, 0.125, 0.86)  # navy glass
const HAIR := Color("d8c27a")  # gold hairline
const GOLD := Color("f0c05a")
const PAPER := Color("ece4d4")
const DIM := Color(1, 1, 1, 0.6)
const HOURS := Color("ffb347")
const DANGER := Color("e04a3a")
const NIGHT := Color(0.02, 0.03, 0.07)

var font: Font
var font_sc: Font
var buttons: Array = []  # {"r": Rect2, "act": Callable, "key": int} rebuilt every draw
var _drawn_buttons: Array = []


func _ready() -> void:
	size = Vector2(960, 540)
	var glyphs: FontFile = load("res://assets/fonts/NotoSansSymbols-Planets.ttf")
	font = _font("res://assets/fonts/CormorantGaramond-SemiBold.ttf", glyphs)
	font_sc = _font("res://assets/fonts/CormorantSC-SemiBold.ttf", glyphs)


func _font(path: String, glyphs: Font) -> Font:
	var f := load(path) as FontFile
	if f == null:
		return ThemeDB.fallback_font
	f.fallbacks = [glyphs, ThemeDB.fallback_font]
	return f


func px(sz: int) -> int:
	return int(round(sz * 1.12))  # Cormorant runs small


func text(pos: Vector2, s: String, sz := 14, col := PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null) -> void:
	var fo: Font = font if f == null else f
	draw_string(fo, pos + Vector2(0, 1), s, align, width, px(sz), Color(0, 0, 0, 0.75 * col.a))
	draw_string(fo, pos, s, align, width, px(sz), col)


func title(pos: Vector2, s: String, sz := 14, col := HAIR, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	text(pos, s, sz, col, align, width, font_sc)


func text_w(s: String, sz: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px(sz)).x


## Wraps `s` to `width` and draws it from `pos` down. Returns the y below the last line.
func para(pos: Vector2, s: String, width: float, sz := 15, col := PAPER, gap := 1.32) -> float:
	var y := pos.y
	for line in wrap_text(s, width, sz):
		text(Vector2(pos.x, y), line, sz, col)
		y += px(sz) * gap
	return y


func wrap_text(s: String, width: float, sz: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" ", false):
		var t := word if cur.is_empty() else cur + " " + word
		if text_w(t, sz) > width and not cur.is_empty():
			out.append(cur)
			cur = word
		else:
			cur = t
	if not cur.is_empty():
		out.append(cur)
	return out


func panel(r: Rect2, border := Color(HAIR, 0.55)) -> void:
	draw_rect(r, BG)
	draw_rect(r, border, false, 1.0)
	draw_rect(r.grow(-3.0), Color(border, border.a * 0.35), false, 1.0)


func star(c: Vector2, r: float, col := GOLD) -> void:
	var q := r * 0.3
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(q, -q), c + Vector2(r, 0), c + Vector2(q, q),
		c + Vector2(0, r), c + Vector2(-q, q), c + Vector2(-r, 0), c + Vector2(-q, -q)]), col)


## A text button. `key` is the number key (1–9) that also presses it, or 0 for none.
func button(r: Rect2, label: String, act: Callable, key := 0, sz := 15, enabled := true) -> void:
	var hot := enabled and r.has_point(get_local_mouse_position())
	draw_rect(r, Color(GOLD, 0.2) if hot else Color(0, 0, 0, 0.35))
	draw_rect(r, (GOLD if hot else Color(GOLD, 0.4)) if enabled else Color(1, 1, 1, 0.15), false, 1.0)
	var x := r.position.x + 10.0
	if key > 0:
		text(Vector2(x, r.position.y + r.size.y * 0.5 + px(sz) * 0.33), str(key), sz, GOLD)
		x += 22.0
	text(Vector2(x, r.position.y + r.size.y * 0.5 + px(sz) * 0.33), label, sz, PAPER if enabled else DIM, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 6.0)
	if enabled:
		buttons.append({"r": r, "act": act, "key": key})


func begin_buttons() -> void:
	buttons = []


func end_buttons() -> void:
	_drawn_buttons = buttons


func click(at: Vector2) -> bool:
	for b in _drawn_buttons:
		if b["r"].has_point(at):
			b["act"].call()
			return true
	return false


func press_key(n: int) -> bool:
	for b in _drawn_buttons:
		if int(b["key"]) == n:
			b["act"].call()
			return true
	return false


## The 28 days as moon phases, today ringed, the Eclipse a black sun at the end.
func moons(centre: Vector2, day: int, last := 28) -> void:
	var step := 19.0
	var x0 := centre.x - step * (last - 1) * 0.5
	for i in last:
		var c := Vector2(x0 + i * step, centre.y)
		var d := i + 1
		var past := d < day
		var col := Color(PAPER, 0.25 if past else 0.75)
		if d == last:
			draw_circle(c, 6.0, Color(0, 0, 0))
			draw_arc(c, 7.5, 0, TAU, 20, HOURS, 1.2)
		else:
			# Phase: new at day 1, full around day 14.
			var k := sin(PI * float(i) / float(last - 1))
			draw_arc(c, 5.0, 0, TAU, 16, Color(col, col.a * 0.6), 1.0)
			if k > 0.06:
				draw_circle(c, 5.0 * k, col)
		if d == day:
			draw_arc(c, 8.5, 0, TAU, 20, GOLD, 1.5)
