extends Control
## Interface at 960×540 in the Star Atlas style (GDD 6.6): navy glass panels with gold hairlines,
## Cormorant small caps, planetary glyphs. The spellbook is a constellation of four star rings,
## then the two cantrips and the Ward's diamond (the stand-in bar of the UI spec §10); Vitality
## and Aether are fine lines, with Strain as a red end on Aether, and your Focus beside them;
## Cadence is four stars at the reticle and a wind-up fills a ring round it; the calendar row
## shows the 13 moons and this moon's days, ending in the Eclipse, with a dial for the time of day. Also the level-up toasts and the
## milestone picker. The game's own screens are scripts/game/slice.gd.

const Tris := preload("res://scripts/ui/tris.gd")
const SLOTS := ["slot1", "slot2", "slot3", "slot4"]
const CANTRIPS := ["cant1", "cant2"]
const AETHER := Color("b48cff")
const BG := Color(0.035, 0.055, 0.125, 0.8)  # navy glass
const HAIR := Color("d8c27a")  # gold hairline
const VITAL := Color("e8e4d8")
const SILVER := Color("c9d3e6")  # appointments on the calendar (UI spec §3.2)
const RING_R := 22.0
## The four stars of the spellbook, the two cantrips, then the Ward's diamond (HUD coordinates).
const STARS := [Vector2(300, 476), Vector2(383, 458), Vector2(466, 476), Vector2(549, 458)]
const CANT_AT := [Vector2(636, 478), Vector2(690, 478)]
const CANT_R := 14.0
const WARD_AT := Vector2(790, 470)

var main
var arena
var font: Font  # Cormorant Garamond, with the glyphs and the default font behind it
var font_sc: Font  # Cormorant small caps, for titles
## In the town and in fights all text goes into this one child canvas item, above the panels, so
## the browser draws it in a few batches instead of switching between shapes and glyphs each line.
var _text_ci: RID
var _batch := false
var _g := Tris.new()  # every shape, drawn as one command at the end of _draw (scripts/ui/tris.gd)
var toasts: Array = []  # {"text", "sub", "color", "t", "big"}
var banner := ""
var banner_t := 0.0
var glow := {}  # spell id -> seconds left on the level-up glow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_text_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_text_ci, get_canvas_item())
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var glyphs: FontFile = load("res://assets/fonts/NotoSansSymbols-Planets.ttf")
	font = _font("res://assets/fonts/CormorantGaramond-SemiBold.ttf", glyphs)
	font_sc = _font("res://assets/fonts/CormorantSC-SemiBold.ttf", glyphs)


func _font(path: String, glyphs: Font) -> Font:
	var f := load(path) as FontFile
	if f == null:
		return ThemeDB.fallback_font
	f.fallbacks = [glyphs, ThemeDB.fallback_font]
	return f


func reset() -> void:
	toasts.clear()
	glow.clear()


func push_toast(text: String, color: Color) -> void:
	toasts.append({"text": text, "sub": "", "color": color, "t": 0.0, "big": false})
	if toasts.size() > 5:
		toasts.pop_front()


func push_level(id: String, text: String, sub: String) -> void:
	toasts.append({"text": text, "sub": sub, "color": PixelArt.GOLD, "t": 0.0, "big": true})
	if toasts.size() > 5:
		toasts.pop_front()
	glow[id] = 1.6


func set_banner(text: String) -> void:
	banner = text
	banner_t = 0.0


static func fmt(def: Dictionary, v: float) -> String:
	var f: String = def.get("fmt", "%.0f")
	return f % v


func _process(dt: float) -> void:
	banner_t += dt
	for t in toasts.duplicate():
		t["t"] += dt
		if t["t"] > (4.0 if t["big"] else 3.0):
			toasts.erase(t)
	for k in glow.keys():
		glow[k] -= dt
		if glow[k] <= 0.0:
			glow.erase(k)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if main.mode in ["world", "fight"] and not Progression.pending.is_empty():
			for i in 2:
				if _pick_rect(i).has_point(ev.position):
					Progression.pick(i)
					accept_event()


# --- drawing ----------------------------------------------------------------

## Text in Cormorant (which runs small, so sizes are nudged up), with a soft shadow.
func _text(pos: Vector2, s: String, sz := 14, col := PixelArt.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null) -> void:
	var fo: Font = font if f == null else f
	var size_px := int(round(sz * 1.12))
	var ci := _text_ci
	if not _batch:
		ci = get_canvas_item()
		_g.flush(ci)  # keep the order: the shapes so far, then this text
	fo.draw_string(ci, pos + Vector2(0, 1), s, align, width, size_px, Color(0, 0, 0, 0.75 * col.a))
	fo.draw_string(ci, pos, s, align, width, size_px, col)


## A title in small caps.
func _title(pos: Vector2, s: String, sz := 14, col := HAIR, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_text(pos, s, sz, col, align, width, font_sc)


func _text_w(s: String, sz: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(sz * 1.12))).x


## Navy glass with a gold hairline and an inner hairline, like a plate in a star atlas.
func _panel(r: Rect2, border := Color(HAIR, 0.55)) -> void:
	_g.rect(r, BG)
	_g.rect(r, border, false, 1.0)
	_g.rect(r.grow(-3.0), Color(border, border.a * 0.35), false, 1.0)


## The mutation mark: a small four-point star.
func star(c: Vector2, r: float, col := PixelArt.GOLD) -> void:
	var q := r * 0.3
	# A fan from the centre, since the star is not convex.
	_g.poly(PackedVector2Array([c, c + Vector2(0, -r), c + Vector2(q, -q), c + Vector2(r, 0), c + Vector2(q, q),
		c + Vector2(0, r), c + Vector2(-q, q), c + Vector2(-r, 0), c + Vector2(-q, -q), c + Vector2(0, -r)]), col)


## A fine meter: a dim hairline with the filled part bright, and a short glow cap at its end.
func _meter(at: Vector2, w: float, k: float, col: Color, lag := -1.0) -> void:
	_g.line(at, at + Vector2(w, 0), Color(col, 0.18), 2.0)
	if lag > k:
		_g.line(at, at + Vector2(w * clampf(lag, 0, 1), 0), Color(1, 1, 1, 0.45), 2.0)
	var e := at + Vector2(w * clampf(k, 0, 1), 0)
	_g.line(at, e, col, 2.0)
	if k > 0.0:
		_g.circle(e, 2.0, col.lightened(0.3))


func _glyph(e: String) -> String:
	return str(arena.D["elements"].get(e, {}).get("glyph", "✦"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _text_ci.is_valid():
		RenderingServer.free_rid(_text_ci)


func _draw() -> void:
	RenderingServer.canvas_item_clear(_text_ci)
	_batch = main.mode in ["world", "fight"] and Progression.pending.is_empty()
	_draw_all()
	_g.flush(get_canvas_item())


func _draw_all() -> void:
	match main.mode:
		"cutscene":
			_draw_cutscene()
			return
		"world", "fight":
			_draw_fight()
		_:
			return  # the game draws its own screens (scripts/game/slice.gd)
	if not Progression.pending.is_empty():
		_draw_picker()
		return
	_draw_toasts()


## A cutscene: letterbox bars, its caption, and how to skip.
func _draw_cutscene() -> void:
	var cs = arena.cutscene
	if cs == null:
		return
	var k := clampf(cs.t * 2.0, 0.0, 1.0)
	_g.rect(Rect2(0, 0, 960, 46 * k), Color(0, 0, 0, 0.92))
	_g.rect(Rect2(0, 540 - 70 * k, 960, 70 * k), Color(0, 0, 0, 0.92))
	var cap: String = cs.caption()
	if cap != "":
		_text(Vector2(0, 504), cap, 17, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	_text(Vector2(0, 530), "Space to skip", 10, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, 940)


func _draw_fight() -> void:
	var P: Unit = arena.player
	var kit = arena.kit
	# Top left: the wizard, Vitality and Aether as fine lines, Blink, field-object caps and
	# the masteries.
	var lo: Array = Progression.loadout()
	var rows: Array = []
	for e in lo:
		var f: Dictionary = field_count(e)
		if int(f["cap"]) > 0 and rows.size() < 3:
			rows.append(e)
	var pr := Rect2(10, 10, 214, 104 + rows.size() * 15)
	_panel(pr)
	var wx: float
	# Your Ring and wells, with the way to the next Ring as the hairline.
	var g = main.slice.growth
	_title(Vector2(20, 30), "%s  ·  %d wells" % [g.ring_name(), g.wells()], 13)
	var need: Array = g.d["ring_wells"]
	var ri: int = g.ring()
	wx = 1.0 if ri == 0 or ri + 1 >= need.size() else float(g.wells() - int(need[ri])) / float(int(need[ri + 1]) - int(need[ri]))
	_g.line(Vector2(20, 36), Vector2(214, 36), Color(HAIR, 0.15), 1.0)
	_g.line(Vector2(20, 36), Vector2(20 + 194 * clampf(wx, 0, 1), 36), Color(HAIR, 0.6), 1.0)
	_text(Vector2(20, 53), "Vitality" + ("  ·  Injured" if arena.hp_cap < 1.0 else ""), 11, Color(VITAL, 0.8) if arena.hp_cap >= 1.0 else PixelArt.DANGER)
	_text(Vector2(20, 53), "%d / %d" % [ceili(maxf(P.hp, 0.0)), int(P.max_hp)], 11, Color(VITAL, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 194)
	_meter(Vector2(20, 59), 194, maxf(P.hp, 0.0) / P.max_hp, VITAL if P.hp > P.max_hp * 0.3 else PixelArt.DANGER, P.hp_lag / P.max_hp)
	if arena.hp_cap < 1.0:  # Injured: the part of the line you can't fill until you sleep
		_g.line(Vector2(20 + 194 * arena.hp_cap, 59), Vector2(214, 59), Color(PixelArt.DANGER, 0.6), 2.0)
	# Aether: the pool, and Strain (from Overdraw) as a red end that rest clears.
	var pool: float = maxf(1.0, Progression.max_aether())
	_text(Vector2(20, 76), "Aether", 11, Color(AETHER, 0.9))
	var strain_s: String = "  ·  Strain %d" % int(kit.strain) if kit.strain >= 1.0 else ""
	_text(Vector2(20, 76), "%d / %d%s" % [int(kit.aether), int(kit.max_aether()), strain_s], 11, Color(AETHER, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 194)
	_meter(Vector2(20, 82), 194, kit.aether / pool, AETHER)
	if kit.strain > 0.0:
		var sx: float = 20.0 + 194.0 * clampf(kit.max_aether() / pool, 0.0, 1.0)
		_g.line(Vector2(sx, 82), Vector2(214, 82), PixelArt.DANGER, 2.0)
	_text(Vector2(20, 100), "Blink", 11, Color(VITAL, 0.7))
	for i in Progression.blink_charges():
		star(Vector2(58 + i * 12, 96), 4.0, VITAL if i < kit.blink_charges else Color(VITAL, 0.18))
	_text(Vector2(20, 100), "Focus %d" % kit.focus(), 11, Color(VITAL, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 194)
	# One row of field-object diamonds per sphere in the book that has one.
	for row in rows.size():
		var f: Dictionary = field_count(rows[row])
		var col: Color = kit.element_color(rows[row])
		var y := 114 + row * 15
		_text(Vector2(20, y), "%s %s" % [_glyph(rows[row]), f["name"]], 11, col)
		for i in int(f["cap"]):
			_diamond(Vector2(88 + i * 11, y - 4), 3.5, col if i < int(f["count"]) else Color(col, 0.22), i < int(f["count"]))
	# The main line's gold step under the vitals, outside fights (UI spec §3.4).
	if main.mode == "world" and main.slice.screen == "world":
		var step: String = main.slice.main_line()
		if step != "":
			star(Vector2(17, pr.end.y + 14), 3.5, PixelArt.GOLD)
			var rows_t: Array = main.slice.wrap_text(step, 200.0, 12)
			for i in rows_t.size():
				_text(Vector2(26, pr.end.y + 18 + i * 15), rows_t[i], 12, Color(PixelArt.GOLD, 0.9))
		# The jobs line: the commission you're on, in paper under the gold step (N-7.6.3).
		var job: String = main.slice.job_line()
		if job != "":
			var jy: float = pr.end.y + 18 + (main.slice.wrap_text(step, 200.0, 12).size() if step != "" else 0) * 15 + 6
			_diamond(Vector2(17, jy - 4), 3.0, PixelArt.PAPER, false)
			var rows_j: Array = main.slice.wrap_text(job, 200.0, 11)
			for i in rows_j.size():
				_text(Vector2(26, jy + i * 14), rows_j[i], 11, Color(PixelArt.PAPER, 0.8))
	var el: Dictionary = arena.D["elements"]
	_draw_moons()
	# Top right: the duelist.
	var r: Unit = arena.rival()
	if r:
		var br := Rect2(726, 10, 224, 70)
		_panel(br)
		_title(br.position + Vector2(12, 21), "Silas Vane", 15, PixelArt.STORM)
		_text(br.position + Vector2(12, 36), "Storm Rider  ·  %s %s" % [_glyph("storm"), el["storm"]["name"]], 10, Color(VITAL, 0.55))
		_meter(br.position + Vector2(12, 46), 200, r.hp / r.max_hp, PixelArt.STORM, r.hp_lag / r.max_hp)
		_text(br.position + Vector2(12, 63), "Poise", 10, Color(VITAL, 0.7))
		for i in maxi(r.poise, 0):
			star(br.position + Vector2(48 + i * 11, 59), 4.0, VITAL)
		if r.pips > 0:
			for i in arena.ignite_threshold():
				_diamond(br.position + Vector2(130 + i * 10, 59), 3.5, PixelArt.FIRE_HOT if i < r.pips else Color(PixelArt.FIRE, 0.25), i < r.pips)
		if r.wet_t > 0.0:
			_text(br.position + Vector2(0, 63), "Wet", 11, PixelArt.WATER, HORIZONTAL_ALIGNMENT_RIGHT, 212)
	# Banner, under the moon row.
	if banner != "" and banner_t < 3.2:
		var a := clampf(3.2 - banner_t, 0.0, 1.0) * clampf(banner_t * 4.0, 0.0, 1.0)
		_title(Vector2(0, 84), banner, 20, Color(PixelArt.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
	# Hover: the enemy's Poise and Focus (Impact above Focus breaks its wind-up).
	var h: Unit = arena.hover
	if h and main.mode in ["world", "fight"]:
		var sp: Vector2 = arena.screen_pos(h.pos, 1.8 if arena.view else 15.0) + Vector2(14, 0)
		_text(sp + Vector2(0, 13), "Poise %d  ·  Focus %d" % [h.poise, arena.ai.focus(h)], 10, Color(1, 1, 1, 0.75))
	if main.slice.in_dialogue():
		return  # the dialogue panel sits where the spellbook row is
	if main.mode in ["world", "fight"]:
		_draw_cadence_stars()
		_draw_windup()
	_draw_book()


## Top centre: the calendar row (UI spec §3.2): the year's 13 moons, then this moon's 28 days as
## four weeks of seven, each in its weekday Sphere's colour, today ringed, known calamities as dark
## discs, the Great Eclipse as a black sun at the end, and a dial for the time of day. In a fight
## it collapses to one line.
func _draw_moons() -> void:
	var run = main.slice.run
	var known := ""
	for e in main.slice.reach.events():
		known += ("2" if e["appointment"] else "1") if e["known"] else "0"
	var sl = main.slice
	var here: String = sl.region()
	known += "/%s/%s" % [sl.weather.kind(here), sl.weather.known(here, run.day() + 1)]
	var key := "%d/%d/%s" % [run.day(), run.time(), known]
	_g.cached(get_canvas_item(), "moons", key, _moon_shapes.bind(run.day(), run.time()))
	if main.mode == "fight":
		var t: float = arena.fight_time
		_title(Vector2(0, 48), "%s   ·   %s   ·   %d:%02d   ·   %d casts   ·   %d taken   ·   %d down" % [
			run.date_name(), run.time_name(), int(t) / 60, int(t) % 60, int(arena.stats["casts"]),
			int(arena.stats["damage_taken"]), int(arena.stats["kills"])], 11, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 960)
		return
	var w = main.world
	_title(Vector2(0, 48), "%s   ·   %s   ·   %s   ·   %s   ·   %s" % [run.moon_name(), run.date_name(), run.weekday()["name"],
		sl.weather.kind_name(sl.weather.kind(here)), w.map.place_name(w.here)],
		12, Color(HAIR, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 960)


const MOON_STEP := 10.0
const DAY_STEP := 7.0
const WEEK_GAP := 4.0


## The calendar row's shapes (cached: they change with the time of day and what you know).
func _moon_shapes(day: int, time: int) -> void:
	var run = main.slice.run
	var moon: int = run.moon()
	var width: float = run.MOONS * MOON_STEP + 10.0 + run.MOON_DAYS * DAY_STEP + 3 * WEEK_GAP + 20.0 + 26.0 + 36.0
	var x0 := 480.0 - width / 2.0
	var strip := Rect2(x0 - 8, 10, width + 16, 22)
	_g.rect(strip, Color(BG, 0.55))
	_g.line(strip.position + Vector2(0, strip.size.y), strip.end, Color(HAIR, 0.3), 1.0)
	var calamity := {}
	var pins := {}  # day -> silver (an appointment) or gold (a known fixed event), UI spec §3.2
	for e in main.slice.reach.events():
		if e["known"] and e["kind"] == "calamity":
			calamity[int(e["day"])] = true
		elif e["known"] or e["appointment"]:
			pins[int(e["day"])] = SILVER if e["appointment"] else PixelArt.GOLD
	# the 13 moons: past ones dim, this one bright and ringed
	for m in run.MOONS:
		var c := Vector2(x0 + m * MOON_STEP + 4.0, 21)
		var a := 0.85 if m + 1 == moon else (0.2 if m + 1 < moon else 0.45)
		_g.circle(c, 3.4, Color("dfe4f2", a))
		if m + 1 == moon:
			_g.arc(c, 5.6, 0, TAU, 16, HAIR, 1.0)
		for d in calamity:
			if (int(d) - 1) / run.MOON_DAYS == m:
				_g.circle(c + Vector2(2.5, 0), 3.0, Color(0, 0, 0))
		for d in pins:
			if (int(d) - 1) / run.MOON_DAYS == m:
				_g.circle(c + Vector2(0, -6), 1.3, pins[d])
	# this moon's 28 days in four weeks, each dot in its weekday Sphere's colour
	var dx0: float = x0 + run.MOONS * MOON_STEP + 10.0
	var first: int = run.day_of(moon, 1)
	for i in run.MOON_DAYS:
		var d: int = first + i
		var c := Vector2(dx0 + i * DAY_STEP + (i / 7) * WEEK_GAP, 21)
		var col := Color(run.weekday(d)["color"])
		if calamity.has(d):
			_g.circle(c, 3.0, Color(0, 0, 0))
			_g.arc(c, 3.2, 0, TAU, 12, Color(PixelArt.GOLD, 0.7), 1.0)
		else:
			_g.circle(c, 2.6 if d == day else 1.8, Color(col, 0.95 if d == day else (0.2 if d < day else 0.45)))
		if d == day:
			_g.arc(c, 4.6, 0, TAU, 16, HAIR, 1.0)
		if pins.has(d):
			_g.line(c + Vector2(0, -8), c + Vector2(0, -4), pins[d], 1.0)
			_g.circle(c + Vector2(0, -8.5), 1.6, pins[d])
	# the Great Eclipse: a black sun at the row's end
	var ec := Vector2(dx0 + run.MOON_DAYS * DAY_STEP + 3 * WEEK_GAP + 8.0, 21)
	_g.arc(ec, 6.5, 0, TAU, 24, Color(PixelArt.GOLD, 0.8), 1.5)
	_g.circle(ec, 5.5, Color(0, 0, 0))
	# the time of day: a small dial, Morning to Night left to right over the top
	var dc := Vector2(ec.x + 22.0, 25)
	_g.arc(dc, 7.0, PI, TAU, 12, Color(HAIR, 0.4), 1.0)
	var ang := PI + PI * float(time) / 4.0
	_g.line(dc, dc + Vector2.from_angle(ang) * 7.0, HAIR, 1.5)
	_g.circle(dc + Vector2.from_angle(ang) * 7.0, 1.8, Color(PixelArt.GOLD, 0.9))
	# the weather (seasons spec §3.5): today's glyph, and tomorrow's once Aldous has told you
	var wx = main.slice.weather
	var here: String = main.slice.region()
	var today: String = wx.kind(here)
	wx.glyph(_g, today, Vector2(dc.x + 20.0, 21), 5.5, wx.color(today))
	var tomorrow: String = wx.known(here, day + 1) if day < run.LAST_DAY else ""
	if tomorrow != "":
		wx.glyph(_g, tomorrow, Vector2(dc.x + 36.0, 22), 3.8, Color(wx.color(tomorrow), 0.55))


func _diamond(c: Vector2, r: float, col: Color, filled := true) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		_g.poly(pts, col)
	else:
		pts.append(pts[0])
		_g.polyline(pts, col, 1.0)


## Cadence: four stars by the reticle, joined as they light; Resonant when all four are lit.
func _draw_cadence_stars() -> void:
	var kit = arena.kit
	if kit.notes <= 0:
		return
	var at: Vector2 = arena.screen_pos(arena.mouse, 0.0) + Vector2(16, -14)
	var full: int = int(arena.D["cadence"]["notes"])
	var shape := [Vector2(0, 0), Vector2(9, -6), Vector2(18, -2), Vector2(25, -10)]
	var resonant: bool = kit.notes >= full
	var col: Color = PixelArt.GOLD if resonant else VITAL
	for i in full:
		var p: Vector2 = at + shape[i % shape.size()]
		var on: bool = i < kit.notes
		if on and i > 0:
			_g.line(at + shape[(i - 1) % shape.size()], p, Color(col, 0.6), 1.0)
		star(p, 3.5 if on else 2.0, col if on else Color(col, 0.25))
	if resonant:
		_title(at + Vector2(0, 14), "Resonant", 10, PixelArt.GOLD)


## A wind-up: a ring round the reticle fills until the spell can be released.
func _draw_windup() -> void:
	var kit = arena.kit
	if kit.wind.is_empty():
		return
	var at: Vector2 = arena.screen_pos(arena.mouse, 0.0)
	var k: float = kit.wind_k()
	var col: Color = PixelArt.PAPER if k >= 1.0 else kit.element_color(Progression.spell(kit.wind["id"])["element"])
	_g.arc(at, 13.0, 0, TAU, 32, Color(col, 0.2), 1.0)
	_g.arc(at, 13.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, col, 2.0)


## The field-object row for an element: its name, how many are out and the cap (design doc §4.3).
func field_count(element: String) -> Dictionary:
	var F: Dictionary = arena.D["field"]
	match element:
		"earth":
			return {"name": "Stones", "count": arena.stone_count(), "cap": Progression.stone_cap()}
		"fire":
			return {"name": "Embers", "count": _zones_of("ember"), "cap": F["ember_cap"]}
		"storm":
			return {"name": "Rods", "count": _zones_of("rod"), "cap": F["rod_cap"]}
		"water":
			return {"name": "Puddles", "count": _zones_of("puddle"), "cap": F["puddle_cap"]}
	return {"name": "", "count": 0, "cap": 0}


func _zones_of(kind: String) -> int:
	return arena.zones.filter(func(z): return z["kind"] == kind and not z.has("cell")).size()


## The spellbook as a constellation: the four stars joined by fine gold lines over a long arc,
## each a ring in its sphere's colour with the planet's glyph; then the cantrips and the Ward.
func _draw_book() -> void:
	var kit = arena.kit
	# The rings, the constellation and the level arcs change rarely: drawn from a cache.
	var key: Array = []
	for i in SLOTS.size():
		key.append(_ring_key(SLOTS[i], kit.slot_spell(SLOTS[i])))
	_g.cached(get_canvas_item(), "book", key, _book_shapes)
	var hover := ""
	var mouse := get_local_mouse_position()
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var id: String = kit.slot_spell(slot)
		_draw_star_slot(STARS[i], slot, id)
		if mouse.distance_to(STARS[i]) < RING_R + 4.0:
			hover = id
	for i in CANTRIPS.size():
		_draw_cantrip(CANT_AT[i], CANTRIPS[i], kit.slot_spell(CANTRIPS[i]))
	_draw_ward(WARD_AT, 20.0)
	if hover != "" and main.mode in ["world", "fight"]:
		_draw_spell_tip(hover, mouse)


## A cantrip: a small ring with its glyph, its charges as dots under it.
func _draw_cantrip(c: Vector2, slot: String, id: String) -> void:
	if id == "":
		return
	var kit = arena.kit
	var cd: Dictionary = kit.cantrip(id)
	var col: Color = kit.element_color(cd["element"])
	var n: int = int(kit.cant_charges.get(id, 0))
	_g.circle(c, CANT_R + 1.0, Color(0.03, 0.045, 0.1, 0.9))
	_g.arc(c, CANT_R, 0, TAU, 28, PixelArt.DANGER if kit.denied.has(slot) else (col if n > 0 else Color(col, 0.35)), 1.5)
	_text(c + Vector2(-20, 6), _glyph(cd["element"]), 15, col if n > 0 else Color(col, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 40)
	_title(c + Vector2(-30, -CANT_R - 6), main.controls.key(slot), 10, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 60)
	_text(c + Vector2(-40, CANT_R + 13), cd["name"], 11, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 80)
	for i in int(cd["charges"]):
		_g.circle(c + Vector2((i - (int(cd["charges"]) - 1) / 2.0) * 7.0, CANT_R + 20), 2.0, col if i < n else Color(col, 0.2))


## What a slot's ring looks like: its spell, colour, width and level arc.
func _ring_key(slot: String, id: String) -> Array:
	if id == "":
		return [""]
	var kit = arena.kit
	var s: Dictionary = Progression.spell(id)
	var ring: Color = kit.element_color(s["element"])
	var width := 2.0
	if glow.has(id):
		ring = PixelArt.GOLD if int(glow[id] * 8.0) % 2 == 0 else ring
	if kit.holding == slot:
		ring = PixelArt.PAPER
		width = 3.0
	if kit.denied.has(slot):
		ring = PixelArt.DANGER
	var lv := Progression.level(id)
	var frac := 1.0 if lv >= Progression.max_level() else Progression.xp(id) / Progression.xp_needed(lv)
	return [id, ring, width, snappedf(frac, 0.01)]


func _book_shapes() -> void:
	var arc := PackedVector2Array()
	for i in 41:
		var x := lerpf(226.0, 736.0, i / 40.0)
		arc.append(Vector2(x, 530.0 - 26.0 * sin(PI * i / 40.0)))
	_g.polyline(arc, Color(HAIR, 0.25), 1.0)
	for i in STARS.size() - 1:
		_g.line(STARS[i], STARS[i + 1], Color(HAIR, 0.3), 1.0)
	for i in SLOTS.size():
		var c: Vector2 = STARS[i]
		var k: Array = _ring_key(SLOTS[i], arena.kit.slot_spell(SLOTS[i]))
		if k[0] == "":
			_g.circle(c, RING_R + 1.0, Color(0.03, 0.045, 0.1, 0.6))
			_g.arc(c, RING_R, 0, TAU, 40, Color(HAIR, 0.2), 1.0)
			continue
		_g.circle(c, RING_R + 1.0, Color(0.03, 0.045, 0.1, 0.9))
		_g.arc(c, RING_R, 0, TAU, 40, k[1], k[2])
		_g.arc(c, RING_R + 3.5, -PI / 2.0, -PI / 2.0 + TAU * float(k[3]), 40, Color(PixelArt.GOLD, 0.75), 1.0)


func _draw_star_slot(c: Vector2, slot: String, id: String) -> void:
	var kit = arena.kit
	if id == "":
		# A slot your Ring hasn't opened yet (the slice); its ring is in _book_shapes.
		_title(c + Vector2(-40, -RING_R - 8), main.controls.key(slot), 10, Color(HAIR, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 80)
		_text(c + Vector2(-50, RING_R + 15), "sealed", 11, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 100)
		return
	var s: Dictionary = Progression.spell(id)
	var col: Color = kit.element_color(s["element"])
	# The ring and the level's gold arc are in _book_shapes (cached).
	if kit.resonant_for(id):
		_g.arc(c, RING_R + 7.0, 0, TAU, 40, Color(PixelArt.GOLD, 0.5 + 0.3 * sin(Time.get_ticks_msec() / 160.0)), 1.5)
	var lv := Progression.level(id)
	var left: float = arena.player.cooldown(id)
	if left > 0.0:
		var k := clampf(left / maxf(kit.cooldown_total(id), 0.01), 0.0, 1.0)
		var pts := PackedVector2Array([c])
		for j in 25:
			pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * k * j / 24.0) * (RING_R - 1.0))
		_g.poly(pts, Color(0, 0, 0, 0.6))
		_text(c + Vector2(-30, 6), "%.1f" % left, 15, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 60)
	else:
		_text(c + Vector2(-30, 9), _glyph(s["element"]), 22, col, HORIZONTAL_ALIGNMENT_CENTER, 60)
	# key and level above, name and cost below
	_title(c + Vector2(-40, -RING_R - 8), "%s  ·  %d" % [main.controls.key(slot), lv], 10, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var label: String = s["name"]
	_text(c + Vector2(-50, RING_R + 15), label, 12, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 100)
	if Progression.mutated(id):
		star(c + Vector2(_text_w(label, 12) / 2.0 + 6, RING_R + 10), 3.0)
	var cost: float = kit.aether_cost(id)
	var charges: int = Progression.charges(id) if Progression.is_device(id) else -1
	if charges >= 0:
		_text(c + Vector2(-50, RING_R + 27), "%d charge%s" % [charges, "" if charges == 1 else "s"], 9, AETHER if charges > 0 else PixelArt.DANGER, HORIZONTAL_ALIGNMENT_CENTER, 100)
	elif cost > 0.0:
		_text(c + Vector2(-50, RING_R + 27), "%d aether  ·  %s" % [int(cost), kit.band(id).capitalize()], 9, AETHER if kit.aether >= cost else PixelArt.DANGER, HORIZONTAL_ALIGNMENT_CENTER, 100)


## The Ward (always there): a diamond, lit while it is up, red while it is broken.
func _draw_ward(c: Vector2, r: float) -> void:
	var kit = arena.kit
	_title(c + Vector2(-50, -r - 8), "%s  ·  Ward" % main.controls.key("ward"), 10, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 100)
	var up: bool = kit.warding
	var border: Color = PixelArt.DANGER if kit.ward_broken() else (PixelArt.GOLD if up else Color(HAIR, 0.8))
	_diamond(c, r + 1.0, Color(0.03, 0.045, 0.1, 0.9))
	_diamond(c, r, border, false)
	if up:
		_diamond(c, r - 4.0, Color(PixelArt.GOLD, 0.35))
	_text(c + Vector2(-80, r + 15), "hold: %d aether/s" % int(arena.D["ward"]["drain"]), 11, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 160)


## Hovering a star shows the spell's numbers and mutations, as the old cards did.
func _draw_spell_tip(id: String, at: Vector2) -> void:
	var s: Dictionary = Progression.spell(id)
	var lines: Array = []
	for key in s["stats"]:
		var def: Dictionary = s["stats"][key]
		if not def.get("hidden", false):
			lines.append([def["label"], fmt(def, Progression.stat(id, key))])
	var muts: Array = Progression.mut_names(id)
	var h := 30.0 + lines.size() * 14.0 + (14.0 if not muts.is_empty() else 0.0)
	var r := Rect2(Vector2(clampf(at.x - 80, 8, 792), 430 - h), Vector2(160, h))
	_panel(r)
	_title(r.position + Vector2(10, 18), "%s  Lv %d" % [s["name"], Progression.level(id)], 12, arena.kit.element_color(s["element"]))
	var y := r.position.y + 34
	for l in lines:
		_text(Vector2(r.position.x + 10, y), l[0], 11, Color(1, 1, 1, 0.65))
		_text(Vector2(r.position.x, y), l[1], 11, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10)
		y += 14.0
	if not muts.is_empty():
		star(Vector2(r.position.x + 13, y - 4), 3.0)
		_text(Vector2(r.position.x + 20, y), ", ".join(muts), 10, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26)


func _draw_toasts() -> void:
	var y := 120.0
	for t in toasts:
		var life: float = 4.0 if t["big"] else 3.0
		var a := clampf((life - t["t"]) / 0.6, 0.0, 1.0)
		var col: Color = t["color"]
		if t["big"]:
			var pop := 1.0 + maxf(0.0, 0.25 - t["t"]) * 1.2
			_text(Vector2(0, y + 6), t["text"], int(22 * pop), Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
			y += 24.0
			if t["sub"] != "":
				_text(Vector2(0, y + 2), t["sub"], 14, Color(PixelArt.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
				y += 18.0
		else:
			_text(Vector2(0, y), t["text"], 14, Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
			y += 18.0
		y += 4.0


func _pick_rect(i: int) -> Rect2:
	return Rect2(Vector2(210 + i * 280, 210), Vector2(260, 110))


func _draw_picker() -> void:
	_g.rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.55))
	var entry: Dictionary = Progression.pending[0]
	var s: Dictionary = Progression.spell(entry["spell"])
	_title(Vector2(0, 170), "%s reached Lv %d" % [s["name"], entry["level"]], 24, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	_text(Vector2(0, 194), "Choose a mutation. It changes how the spell behaves.", 14, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var opts := Progression.milestone_options(entry)
	for i in opts.size():
		var r := _pick_rect(i)
		var hot := r.has_point(get_local_mouse_position())
		_panel(r, PixelArt.GOLD if hot else Color(PixelArt.GOLD, 0.5))
		_title(r.position + Vector2(12, 26), "%d  ·  %s" % [i + 1, opts[i]["name"]], 18, PixelArt.GOLD)
		_text(r.position + Vector2(12, 56), opts[i]["text"], 14, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
	_text(Vector2(0, 350), "Press 1 or 2, or click.", 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 960)
