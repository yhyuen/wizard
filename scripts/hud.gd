extends Control
## Interface at 960×540 in the Star Atlas style (GDD 6.6): navy glass panels with gold hairlines,
## Cormorant small caps, planetary glyphs. The spellbook is a constellation of six star rings
## with the Magick as a gold diamond; Vitality and Aether are fine lines; Cadence is four stars at
## the reticle; a row of 28 moon phases ends in the Eclipse. Also the level-up toasts, the
## milestone picker, the Orrery shrine, the title card and the Loop Ledger.

const SLOTS := ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "magick"]
const AETHER := Color("b48cff")
const BG := Color(0.035, 0.055, 0.125, 0.8)  # navy glass
const HAIR := Color("d8c27a")  # gold hairline
const VITAL := Color("e8e4d8")
const RING_R := 22.0
## The six stars of the spellbook, then the Magick's diamond (HUD coordinates).
const STARS := [Vector2(273, 476), Vector2(356, 458), Vector2(439, 476), Vector2(522, 458), Vector2(605, 476), Vector2(688, 458)]
const MAGICK_AT := Vector2(800, 470)
const LOOP_DAYS := 28

var main
var arena
var font: Font  # Cormorant Garamond, with the glyphs and the default font behind it
var font_sc: Font  # Cormorant small caps, for titles
var toasts: Array = []  # {"text", "sub", "color", "t", "big"}
var banner := ""
var banner_t := 0.0
var glow := {}  # spell id -> seconds left on the level-up glow
var shrine_slot := 0  # the spellbook slot the shrine is filling


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		if main.mode == "fight" and main.shrine_open:
			for b in _shrine_buttons():
				if b["r"].has_point(ev.position):
					match b["kind"]:
						"slot":
							shrine_slot = b["index"]
						"spell":
							main.shrine_spell(shrine_slot, b["id"])
						"mut":
							main.shrine_repick(b["id"], b["level"], b["index"])
						"done":
							main.close_shrine()
					accept_event()
					return
		if main.mode == "fight" and not Progression.pending.is_empty():
			for i in 2:
				if _pick_rect(i).has_point(ev.position):
					Progression.pick(i)
					if Progression.pending.is_empty():
						arena.paused = false
					accept_event()


# --- drawing ----------------------------------------------------------------

## Text in Cormorant (which runs small, so sizes are nudged up), with a soft shadow.
func _text(pos: Vector2, s: String, sz := 14, col := PixelArt.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null) -> void:
	var fo: Font = font if f == null else f
	var size_px := int(round(sz * 1.12))
	draw_string(fo, pos + Vector2(0, 1), s, align, width, size_px, Color(0, 0, 0, 0.75 * col.a))
	draw_string(fo, pos, s, align, width, size_px, col)


## A title in small caps.
func _title(pos: Vector2, s: String, sz := 14, col := HAIR, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_text(pos, s, sz, col, align, width, font_sc)


func _text_w(s: String, sz: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(sz * 1.12))).x


## Navy glass with a gold hairline and an inner hairline, like a plate in a star atlas.
func _panel(r: Rect2, border := Color(HAIR, 0.55)) -> void:
	draw_rect(r, BG)
	draw_rect(r, border, false, 1.0)
	draw_rect(r.grow(-3.0), Color(border, border.a * 0.35), false, 1.0)


## The mutation mark: a small four-point star.
func star(c: Vector2, r: float, col := PixelArt.GOLD) -> void:
	var q := r * 0.3
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(q, -q), c + Vector2(r, 0), c + Vector2(q, q),
		c + Vector2(0, r), c + Vector2(-q, q), c + Vector2(-r, 0), c + Vector2(-q, -q)]), col)


## A fine meter: a dim hairline with the filled part bright, and a short glow cap at its end.
func _meter(at: Vector2, w: float, k: float, col: Color, lag := -1.0) -> void:
	draw_line(at, at + Vector2(w, 0), Color(col, 0.18), 2.0)
	if lag > k:
		draw_line(at, at + Vector2(w * clampf(lag, 0, 1), 0), Color(1, 1, 1, 0.45), 2.0)
	var e := at + Vector2(w * clampf(k, 0, 1), 0)
	draw_line(at, e, col, 2.0)
	if k > 0.0:
		draw_circle(e, 2.0, col.lightened(0.3))


func _glyph(e: String) -> String:
	return str(arena.D["elements"].get(e, {}).get("glyph", "✦"))


func _draw() -> void:
	match main.mode:
		"title":
			_draw_title()
			return
		"fight", "ledger":
			_draw_fight()
	if main.mode == "fight" and main.shrine_open:
		_draw_shrine()
		_draw_toasts()
		return
	if main.mode == "fight" and not Progression.pending.is_empty():
		_draw_picker()
		return
	if main.mode == "ledger":
		_draw_ledger()
	_draw_toasts()


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
	_title(Vector2(20, 30), "The Wizard  ·  Lv %d" % Progression.wizard_level(), 13)
	var wx: float = Progression.p["wizard_xp"] / Progression.wizard_xp_needed(Progression.wizard_level())
	draw_line(Vector2(20, 36), Vector2(214, 36), Color(HAIR, 0.15), 1.0)
	draw_line(Vector2(20, 36), Vector2(20 + 194 * clampf(wx, 0, 1), 36), Color(HAIR, 0.6), 1.0)
	_text(Vector2(20, 53), "Vitality", 11, Color(VITAL, 0.8))
	_text(Vector2(20, 53), "%d / %d" % [ceili(maxf(P.hp, 0.0)), int(P.max_hp)], 11, Color(VITAL, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 194)
	_meter(Vector2(20, 59), 194, maxf(P.hp, 0.0) / P.max_hp, VITAL if P.hp > P.max_hp * 0.3 else PixelArt.DANGER, P.hp_lag / P.max_hp)
	_text(Vector2(20, 76), "Aether", 11, Color(AETHER, 0.9))
	_text(Vector2(20, 76), "%d / %d" % [int(kit.aether), int(kit.max_aether())], 11, Color(AETHER, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 194)
	_meter(Vector2(20, 82), 194, kit.aether / kit.max_aether(), AETHER)
	_text(Vector2(20, 100), "Blink", 11, Color(VITAL, 0.7))
	for i in Progression.blink_charges():
		star(Vector2(58 + i * 12, 96), 4.0, VITAL if i < kit.blink_charges else Color(VITAL, 0.18))
	# One row of field-object diamonds per sphere in the book that has one.
	for row in rows.size():
		var f: Dictionary = field_count(rows[row])
		var col: Color = kit.element_color(rows[row])
		var y := 114 + row * 15
		_text(Vector2(20, y), "%s %s" % [_glyph(rows[row]), f["name"]], 11, col)
		for i in int(f["cap"]):
			_diamond(Vector2(88 + i * 11, y - 4), 3.5, col if i < int(f["count"]) else Color(col, 0.22), i < int(f["count"]))
	var el: Dictionary = arena.D["elements"]
	var mast: Array = []
	for e in lo:
		mast.append("%s %d" % [_glyph(e), Progression.mastery(e)])
	_text(Vector2(118, 100), "Mastery  " + "  ".join(mast), 10, Color(HAIR, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 96)
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
	# Hover: hits to kill with your current Bolt (design doc §4.4) and Poise.
	var h: Unit = arena.hover
	if h and main.mode == "fight":
		var sp: Vector2 = arena.screen_pos(h.pos, 1.8 if arena.view else 15.0) + Vector2(14, 0)
		var bolt := ""
		for s in kit.SLOTS:
			if kit.is_bolt(kit.slot_spell(s)):
				bolt = kit.slot_spell(s)
				break
		if bolt != "":
			var hits := ceili(h.hp / (Progression.stat(bolt, "damage") * kit.dull(bolt)))
			_text(sp, "×%d" % hits, 13, kit.element_color(Progression.spell(bolt)["element"]))
		_text(sp + Vector2(0, 13), "Poise %d" % h.poise, 10, Color(1, 1, 1, 0.75))
	if main.mode == "fight" and arena.shrine_ready():
		_title(arena.screen_pos(arena.shrine_pos(), 1.6 if arena.view else 21.0) + Vector2(-60, -16), "G · the Orrery", 13, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 120)
	if main.mode == "fight":
		_draw_cadence_stars()
	_draw_book()


## Top centre: the loop's 28 days as moon phases, today ringed, ending in the Eclipse's black
## sun; this run's numbers under it. (The prototype's fight is always the loop's first day.)
func _draw_moons() -> void:
	var step := 12.5
	var x0 := 480.0 - (LOOP_DAYS + 1) * step / 2.0 + step / 2.0
	var strip := Rect2(x0 - 12, 10, (LOOP_DAYS + 1) * step + 12, 22)
	draw_rect(strip, Color(BG, 0.55))
	draw_line(strip.position + Vector2(0, strip.size.y), strip.end, Color(HAIR, 0.3), 1.0)
	var today := 0
	var r := 4.2
	for i in LOOP_DAYS:
		var c := Vector2(x0 + i * step, 21)
		var lit := Color("dfe4f2", 0.8 if i == today else 0.45)
		draw_circle(c, r, lit)
		# the shadow slides across: new moon on day 0, full on day 14
		var dx := -2.0 * r * i / 14.0 if i <= 14 else 2.0 * r * (LOOP_DAYS - i) / 14.0
		if absf(dx) < 2.0 * r:
			draw_circle(c + Vector2(dx, 0), r + 0.3, Color(0.05, 0.07, 0.14))
		draw_arc(c, r, 0, TAU, 16, Color(lit, 0.35), 1.0)
		if i == today:
			draw_arc(c, r + 3.0, 0, TAU, 20, HAIR, 1.0)
	var ec := Vector2(x0 + LOOP_DAYS * step + 2.0, 21)
	draw_arc(ec, 6.5, 0, TAU, 24, Color(PixelArt.GOLD, 0.8), 1.5)
	draw_circle(ec, 5.5, Color(0, 0, 0))
	var t: float = arena.fight_time
	_title(Vector2(0, 48), "Loop %d   ·   Day %d of %d   ·   %d:%02d   ·   %d casts   ·   %d taken   ·   %d down" % [
		Progression.loop(), today + 1, LOOP_DAYS, int(t) / 60, int(t) % 60, int(arena.stats["casts"]),
		int(arena.stats["damage_taken"]), int(arena.stats["kills"])], 11, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 960)


func _diamond(c: Vector2, r: float, col: Color, filled := true) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 1.0)


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
			draw_line(at + shape[(i - 1) % shape.size()], p, Color(col, 0.6), 1.0)
		star(p, 3.5 if on else 2.0, col if on else Color(col, 0.25))
	if resonant:
		_title(at + Vector2(0, 14), "Resonant", 10, PixelArt.GOLD)


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
	return arena.zones.filter(func(z): return z["kind"] == kind).size()


## The spellbook as a constellation: the six stars joined by fine gold lines over a long arc,
## each a ring in its sphere's colour with the planet's glyph; the Magick is the diamond.
func _draw_book() -> void:
	var kit = arena.kit
	var arc := PackedVector2Array()
	for i in 41:
		var x := lerpf(226.0, 736.0, i / 40.0)
		arc.append(Vector2(x, 530.0 - 26.0 * sin(PI * i / 40.0)))
	draw_polyline(arc, Color(HAIR, 0.25), 1.0, true)
	for i in STARS.size() - 1:
		draw_line(STARS[i], STARS[i + 1], Color(HAIR, 0.3), 1.0, true)
	var hover := ""
	var mouse := get_local_mouse_position()
	for i in 6:
		var slot: String = SLOTS[i]
		var id: String = kit.slot_spell(slot)
		_draw_star_slot(STARS[i], slot, id)
		if mouse.distance_to(STARS[i]) < RING_R + 4.0:
			hover = id
	_draw_magick(MAGICK_AT, "magick", kit.slot_spell("magick"))
	if hover != "" and main.mode == "fight":
		_draw_spell_tip(hover, mouse)


func _draw_star_slot(c: Vector2, slot: String, id: String) -> void:
	var kit = arena.kit
	var s: Dictionary = Progression.spell(id)
	var col: Color = kit.element_color(s["element"])
	var ring := col
	var width := 2.0
	if glow.has(id):
		ring = PixelArt.GOLD if int(glow[id] * 8.0) % 2 == 0 else col
	if kit.holding == slot:
		ring = PixelArt.PAPER
		width = 3.0
	if kit.denied.has(slot):
		ring = PixelArt.DANGER
	if kit.resonant_for(id):
		draw_arc(c, RING_R + 7.0, 0, TAU, 40, Color(PixelArt.GOLD, 0.5 + 0.3 * sin(Time.get_ticks_msec() / 160.0)), 1.5, true)
	draw_circle(c, RING_R + 1.0, Color(0.03, 0.045, 0.1, 0.9))
	draw_arc(c, RING_R, 0, TAU, 40, ring, width, true)
	# the level's progress as a gold arc just outside the ring
	var lv := Progression.level(id)
	var frac := 1.0 if lv >= Progression.max_level() else Progression.xp(id) / Progression.xp_needed(lv)
	draw_arc(c, RING_R + 3.5, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, Color(PixelArt.GOLD, 0.75), 1.0, true)
	var left: float = arena.player.cooldown(id)
	if left > 0.0:
		var k := clampf(left / maxf(kit.cooldown_total(id), 0.01), 0.0, 1.0)
		var pts := PackedVector2Array([c])
		for j in 25:
			pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * k * j / 24.0) * (RING_R - 1.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
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
	if cost > 0.0:
		_text(c + Vector2(-50, RING_R + 27), "%d aether" % int(cost), 9, AETHER if kit.aether >= cost else PixelArt.DANGER, HORIZONTAL_ALIGNMENT_CENTER, 100)
	var d: float = kit.dull(id)
	if d < 0.999:
		_text(c + Vector2(RING_R - 4, -RING_R + 4), "×%.2f" % d, 10, PixelArt.DANGER)


## The Magick: a gold diamond. Unknown Magicks show a tome's hint if one was read (design doc §5).
func _draw_magick(c: Vector2, slot: String, id: String) -> void:
	var kit = arena.kit
	var r := 20.0
	_title(c + Vector2(-50, -r - 8), "C  ·  Magick", 10, Color(HAIR, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 100)
	var border := Color(HAIR, 0.8)
	if id == "":
		_diamond(c, r, Color(HAIR, 0.25), false)
		_text(c + Vector2(-70, r + 15), "None for these spheres", 11, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 140)
		return
	var m: Dictionary = arena.D["magicks"][id]
	var known := Progression.knows(id)
	if glow.has(id):
		border = PixelArt.GOLD if int(glow[id] * 8.0) % 2 == 0 else PixelArt.PAPER
	if kit.denied.has(slot):
		border = PixelArt.DANGER
	_diamond(c, r + 1.0, Color(0.03, 0.045, 0.1, 0.9))
	_diamond(c, r, border if known else Color(border, 0.4), false)
	_diamond(c, r - 4.0, Color(border, 0.25 if known else 0.1), false)
	var el: Dictionary = arena.D["elements"]
	var g := "%s%s" % [_glyph(m["pair"][0]), _glyph(m["pair"][1])]
	var left: float = arena.player.cooldown(id)
	if left > 0.0:
		_text(c + Vector2(-30, 6), "%.1f" % left, 15, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 60)
	else:
		_text(c + Vector2(-30, 6), g, 15, PixelArt.GOLD if known else Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 60)
	if not known:
		_text(c + Vector2(-80, r + 15), "Unknown Magick", 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 160)
		var hint: String = " ".join(m["hint_card"]) if Progression.has_hint(id) else "Make %s and %s meet." % [el[m["pair"][0]]["name"], el[m["pair"][1]]["name"]]
		_text(c + Vector2(-80, r + 28), hint, 9, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 160)
		return
	_text(c + Vector2(-80, r + 15), "%s  ·  Lv %d" % [m["name"], Progression.magick_level(id)], 12, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 160)
	var cost: float = kit.aether_cost(id)
	if cost > 0.0:
		_text(c + Vector2(-80, r + 27), "%d aether" % int(cost), 9, AETHER if kit.aether >= cost else PixelArt.DANGER, HORIZONTAL_ALIGNMENT_CENTER, 160)
	if kit.resonant_for(id):
		_diamond(c, r + 6.0, Color(PixelArt.GOLD, 0.6), false)


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
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.55))
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
	_text(Vector2(0, 350), "Press 1 or 2, or click. You can re-pick later, but only at an Orrery shrine.", 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 960)


# --- the Orrery shrine ----------------------------------------------------------

const SHRINE := Rect2(110, 56, 740, 420)


## Every clickable part of the shrine menu; drawing and clicks share it.
func _shrine_buttons() -> Array:
	var out: Array = []
	# The six spellbook slots.
	for i in 6:
		out.append({"kind": "slot", "index": i, "r": Rect2(SHRINE.position + Vector2(24, 112 + i * 30), Vector2(150, 26))})
	# Every spell, one column per sphere, one row per kind.
	var els: Array = Progression.elements()
	var kinds := ["bolt", "control", "signature"]
	for c in els.size():
		for k in kinds.size():
			var id := Progression.spell_for(els[c], kinds[k])
			if id != "":
				out.append({"kind": "spell", "id": id, "r": Rect2(SHRINE.position + Vector2(190 + c * 68, 112 + k * 30), Vector2(64, 26))})
	# Mutations of the spells in the book, one row per milestone with a choice.
	var y := SHRINE.position.y + 104.0
	for id in Progression.spellbook():
		for entry in Progression.repickable(id):
			for i in entry["options"].size():
				out.append({"kind": "mut", "id": id, "level": entry["level"], "index": i, "chosen": i == entry["chosen"],
					"name": entry["options"][i]["name"], "text": entry["options"][i]["text"],
					"r": Rect2(Vector2(SHRINE.position.x + 562 + i * 82, y), Vector2(78, 22))})
			y += 27.0
	out.append({"kind": "done", "r": Rect2(Vector2(SHRINE.position.x + SHRINE.size.x / 2.0 - 70, SHRINE.end.y - 44), Vector2(140, 30))})
	return out


func _draw_shrine() -> void:
	var kit = arena.kit
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.6))
	_panel(SHRINE, Color(PixelArt.GOLD, 0.7))
	_title(SHRINE.position + Vector2(0, 34), "The Orrery", 26, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, SHRINE.size.x)
	_text(SHRINE.position + Vector2(0, 56), "Your spells remember every loop. Choose what to carry, and how it behaves.", 13, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, SHRINE.size.x)
	_title(SHRINE.position + Vector2(24, 88), "Spellbook", 16, PixelArt.PAPER)
	_text(SHRINE.position + Vector2(24, 104), "pick a slot, then a spell", 10, Color(1, 1, 1, 0.45))
	_title(SHRINE.position + Vector2(190, 88), "Spells", 16, PixelArt.PAPER)
	_text(SHRINE.position + Vector2(190, 104), "any sphere, any slot", 10, Color(1, 1, 1, 0.45))
	_title(SHRINE.position + Vector2(470, 88), "Mutations", 16, PixelArt.PAPER)
	_text(SHRINE.position + Vector2(560, 88), "of the spells in the book; hover for detail", 10, Color(1, 1, 1, 0.45))
	var hover := get_local_mouse_position()
	var book: Array = Progression.spellbook()
	var y_label := -1.0
	var any_mut := false
	var els: Array = Progression.elements()
	for c in els.size():
		_text(SHRINE.position + Vector2(190 + c * 68, 230), Progression.data["elements"][els[c]]["name"], 11, kit.element_color(els[c]), HORIZONTAL_ALIGNMENT_CENTER, 64)
	var hover_spell := ""
	for b in _shrine_buttons():
		var r: Rect2 = b["r"]
		var hot := r.has_point(hover)
		match b["kind"]:
			"slot":
				var id: String = book[b["index"]]
				var s: Dictionary = Progression.spell(id)
				var col: Color = kit.element_color(s["element"])
				var on: bool = b["index"] == shrine_slot
				draw_rect(r, Color(col, 0.3) if on else Color(0, 0, 0, 0.3))
				draw_rect(r, PixelArt.PAPER if on else (col if hot else Color(col, 0.4)), false, 2.0 if on else 1.0)
				_text(r.position + Vector2(4, 17), main.controls.key(SLOTS[b["index"]]), 11, col, HORIZONTAL_ALIGNMENT_CENTER, 30)
				_text(r.position + Vector2(38, 17), s["name"], 12, PixelArt.PAPER if on else Color(1, 1, 1, 0.75))
				if hot:
					hover_spell = id
			"spell":
				var s: Dictionary = Progression.spell(b["id"])
				var col: Color = kit.element_color(s["element"])
				var in_book: bool = book.has(b["id"])
				draw_rect(r, Color(col, 0.3) if in_book else Color(0, 0, 0, 0.3))
				draw_rect(r, col if in_book or hot else Color(col, 0.35), false, 1.0)
				_text(r.position + Vector2(0, 17), s["name"], 10, PixelArt.PAPER if in_book else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				if hot:
					hover_spell = b["id"]
			"mut":
				any_mut = true
				if r.position.y != y_label:
					y_label = r.position.y
					var s: Dictionary = Progression.spell(b["id"])
					_text(Vector2(SHRINE.position.x + 470, r.position.y + 15), "%s %d" % [s["name"], b["level"]], 12, kit.element_color(s["element"]))
				var on: bool = b["chosen"]
				draw_rect(r, Color(PixelArt.GOLD, 0.3) if on else Color(0, 0, 0, 0.3))
				draw_rect(r, PixelArt.GOLD if on or hot else Color(PixelArt.GOLD, 0.35), false, 1.0)
				_text(r.position + Vector2(0, 16), b["name"], 11, PixelArt.PAPER if on else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				if hot:
					_text(Vector2(SHRINE.position.x + 470, SHRINE.end.y - 62), b["text"], 12, PixelArt.GOLD)
			"done":
				_panel(r, PixelArt.GOLD if hot else Color(PixelArt.GOLD, 0.5))
				_text(r.position + Vector2(0, 21), "Done (G)", 15, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if not any_mut:
		_text(SHRINE.position + Vector2(470, 112), "No mutations on these spells yet.", 12, Color(1, 1, 1, 0.55))
		_text(SHRINE.position + Vector2(470, 128), "Spells mutate at Lv 5, 10 and 15.", 12, Color(1, 1, 1, 0.55))
	# The hovered spell, and the Magick the book carries.
	var y := SHRINE.position.y + 300.0
	if hover_spell != "":
		var s: Dictionary = Progression.spell(hover_spell)
		_text(Vector2(SHRINE.position.x + 190, y), "%s  Lv %d  ·  %s  ·  %d Aether" % [s["name"], Progression.level(hover_spell), s["slot"].capitalize(), int(kit.aether_cost(hover_spell))], 12, kit.element_color(s["element"]))
		_text(Vector2(SHRINE.position.x + 190, y + 16), s["blurb"], 11, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 270)
	var magick := Progression.magick_for(Progression.loadout())
	var mtext := "Magick (C):  none for these spheres in the prototype"
	if magick != "":
		var m: Dictionary = arena.D["magicks"][magick]
		mtext = "Magick (C):  %s" % (m["name"] if Progression.knows(magick) else "??? (not yet discovered)")
	_text(Vector2(SHRINE.position.x + 24, SHRINE.position.y + 310), mtext, 12, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 160)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.02, 0.03, 0.07, 0.8))
	_title(Vector2(0, 110), "Wizard", 54, HAIR, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var el: Dictionary = Progression.data["elements"]
	var names: Array = []
	for e in Progression.loadout():
		names.append(el[e]["name"])
	_text(Vector2(0, 140), "Spellbook prototype  ·  %s  ·  Ambush at the Mill" % " + ".join(names), 16, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var book: Array = Progression.spellbook()
	var ctl = main.controls
	var k := func(i: int) -> String: return ctl.key(SLOTS[i])
	var rows := [
		["WASD", "Move", "Mouse", "Aim"],
		[k.call(0), Progression.spell(book[0])["name"], k.call(1), Progression.spell(book[1])["name"]],
		[k.call(2), Progression.spell(book[2])["name"], k.call(3), Progression.spell(book[3])["name"]],
		[k.call(4), Progression.spell(book[4])["name"], k.call(5), Progression.spell(book[5])["name"]],
		["C", "Magick (discover it first)", "G", "Orrery shrine (when the yard is quiet)"],
		["Space", "Blink", "F2", "Autoplay"],
		["F1", "Practice: every spell +1 level", "", "Bolts fire while held; others aim, then cast on release"],
	]
	if ctl.league():
		rows[0] = ["RMB", "Move, or attack an enemy", "S", "Stop"]
		rows[5] = ["Space", "Blink toward the cursor", "F2", "Autoplay"]
		if ctl.smart():
			rows[6][3] = "Spells cast at the cursor the moment you press them"
	var y := 200.0
	for row in rows:
		_text(Vector2(170, y), row[0], 14, PixelArt.GOLD)
		_text(Vector2(230, y), row[1], 14, PixelArt.PAPER)
		_text(Vector2(500, y), row[2], 14, PixelArt.GOLD)
		_text(Vector2(560, y), row[3], 14, PixelArt.PAPER)
		y += 24.0
	var sub := "Loop %d  ·  Aether is your mana: weave different spells to earn it back" % Progression.loop()
	if Progression.p["ledger"].size() > 0:
		sub += "  ·  your spells remember the earlier loops"
	_text(Vector2(0, 372), "Tab  ·  Controls: %s" % ctl.NAMES[ctl.scheme], 15, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	_text(Vector2(0, 398), sub, 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 960)
	var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
	_text(Vector2(0, 436), "Click or press Enter to begin", 20, Color(PixelArt.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_ledger() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.6))
	var r := Rect2(170, 90, 620, 330)
	_panel(r, Color(PixelArt.GOLD, 0.6))
	_title(r.position + Vector2(0, 34), "Loop Ledger  ·  Ambush at the Mill", 22, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var entries: Array = Progression.p["ledger"]
	var shown := entries.slice(maxi(0, entries.size() - 8))
	var y := r.position.y + 70.0
	for e in shown:
		var res: String = "won in %d:%02d" % [int(e["time"]) / 60, int(e["time"]) % 60] if e["result"] == "won" else "fell at %d:%02d" % [int(e["time"]) / 60, int(e["time"]) % 60]
		var col: Color = PixelArt.PAPER if e["result"] == "won" else Color(PixelArt.DANGER, 0.9)
		_text(Vector2(r.position.x + 24, y), "Loop %d" % int(e["loop"]), 15, PixelArt.GOLD)
		var pair := ""
		if e.has("elements"):
			var ns: Array = []
			for x in e["elements"]:
				if Progression.data["elements"].has(x):
					ns.append(Progression.data["elements"][x]["name"])
			pair = "%s  ·  " % "+".join(ns)
		_text(Vector2(r.position.x + 100, y), "%s%s  ·  %d casts  ·  %d taken  ·  wizard Lv %d" % [pair, res, int(e["casts"]), int(e["damage_taken"]), int(e["wizard_level"])], 13, col)
		y += 22.0
	# Sparkline of winning times: lower is stronger.
	var wins := entries.filter(func(e): return e["result"] == "won")
	if wins.size() >= 2:
		var hi := 0.0
		for e in wins:
			hi = maxf(hi, float(e["time"]))
		var pts := PackedVector2Array()
		for i in wins.size():
			pts.append(Vector2(r.position.x + 440 + i * 150.0 / (wins.size() - 1), r.end.y - 70 - 40.0 * float(wins[i]["time"]) / hi))
		draw_polyline(pts, PixelArt.GOLD, 2.0)
		_text(Vector2(r.position.x + 440, r.end.y - 22), "time to win, by loop", 10, Color(1, 1, 1, 0.5))
	_text(Vector2(r.position.x + 24, r.end.y - 44), "Spells, mutations and Magicks carry over.", 12, Color(1, 1, 1, 0.75))
	_text(Vector2(r.position.x + 24, r.end.y - 26), "The wizard level drops to half.", 12, Color(1, 1, 1, 0.75))
	_text(Vector2(0, r.end.y + 40), "Enter: wake again in Loop %d      Tab: controls      Delete twice: wipe the save" % (Progression.loop() + 1), 16, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
