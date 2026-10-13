extends Control
## Interface at 960×540: spell cards with stat tracks, HP and field-object caps, the duel bar,
## level-up toasts, the milestone picker, the title card and the Loop Ledger.

const CARD := Vector2(150, 78)
const SLOTS := ["bolt1", "bolt2", "control1", "control2", "signature", "magick"]
const KEYS := {"bolt1": "LMB", "bolt2": "RMB", "control1": "Q", "control2": "E", "signature": "R", "magick": "F"}
const BG := Color(0.07, 0.055, 0.08, 0.86)

var main
var arena
var font: Font
var toasts: Array = []  # {"text", "sub", "color", "t", "big"}
var banner := ""
var banner_t := 0.0
var glow := {}  # spell id -> seconds left on the level-up glow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = ThemeDB.fallback_font


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
		if main.mode == "fight" and not Progression.pending.is_empty():
			for i in 2:
				if _pick_rect(i).has_point(ev.position):
					Progression.pick(i)
					if Progression.pending.is_empty():
						arena.paused = false
					accept_event()


# --- drawing ----------------------------------------------------------------

func _text(pos: Vector2, s: String, sz := 14, col := PixelArt.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos + Vector2(1, 1), s, align, width, sz, Color(0, 0, 0, 0.7 * col.a))
	draw_string(font, pos, s, align, width, sz, col)


func _panel(r: Rect2, border := Color(1, 1, 1, 0.12)) -> void:
	draw_rect(r, BG)
	draw_rect(r, border, false, 2.0)


## The mutation mark: a small four-point star (the default font has no ✦).
func star(c: Vector2, r: float, col := PixelArt.GOLD) -> void:
	var q := r * 0.3
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(q, -q), c + Vector2(r, 0), c + Vector2(q, q),
		c + Vector2(0, r), c + Vector2(-q, q), c + Vector2(-r, 0), c + Vector2(-q, -q)]), col)


func _draw() -> void:
	match main.mode:
		"title":
			_draw_title()
			return
		"fight", "ledger":
			_draw_fight()
	if main.mode == "fight" and not Progression.pending.is_empty():
		_draw_picker()
		return
	if main.mode == "ledger":
		_draw_ledger()
	_draw_toasts()


func _draw_fight() -> void:
	var P: Unit = arena.player
	var kit = arena.kit
	# Top left: wizard level, HP in chunks of 10, blink charges, field-object caps (design doc §4.3).
	_panel(Rect2(8, 8, 236, 84))
	_text(Vector2(16, 26), "Wizard  Lv %d" % Progression.wizard_level(), 14)
	var wx: float = Progression.p["wizard_xp"] / Progression.wizard_xp_needed(Progression.wizard_level())
	draw_rect(Rect2(130, 18, 104, 4), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(130, 18, 104 * clampf(wx, 0, 1), 4), PixelArt.PAPER)
	var hp_r := Rect2(16, 34, 218, 12)
	draw_rect(hp_r, Color(0.2, 0.1, 0.12))
	draw_rect(Rect2(hp_r.position, Vector2(hp_r.size.x * P.hp_lag / P.max_hp, 12)), PixelArt.PAPER)
	draw_rect(Rect2(hp_r.position, Vector2(hp_r.size.x * maxf(P.hp, 0.0) / P.max_hp, 12)), Color("6cc46c"))
	var chunks := int(P.max_hp / 10.0)
	for i in range(1, chunks):
		var x := hp_r.position.x + hp_r.size.x * i * 10.0 / P.max_hp
		draw_line(Vector2(x, 34), Vector2(x, 46), Color(0, 0, 0, 0.5), 1.0)
	_text(Vector2(18, 45), "%d / %d" % [ceili(maxf(P.hp, 0.0)), int(P.max_hp)], 11)
	_text(Vector2(16, 64), "Blink", 12, PixelArt.PAPER)
	for i in Progression.blink_charges():
		var col: Color = PixelArt.PAPER if i < kit.blink_charges else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(56 + i * 12, 56, 8, 8), col)
	_text(Vector2(100, 64), "Stones", 12, PixelArt.EARTH)
	var cap := Progression.stone_cap()
	for i in cap:
		var filled: bool = i < arena.stone_count()
		draw_rect(Rect2(150 + i * 10, 56, 7, 7), PixelArt.EARTH if filled else Color(PixelArt.EARTH, 0.2), filled, -1.0 if filled else 1.0)
	_text(Vector2(100, 84), "Embers", 12, PixelArt.FIRE)
	var embers: int = arena.zones.filter(func(z): return z["kind"] == "ember").size()
	for i in int(arena.D["field"]["ember_cap"]):
		var filled := i < embers
		draw_rect(Rect2(150 + i * 10, 76, 7, 7), PixelArt.FIRE if filled else Color(PixelArt.FIRE, 0.2), filled, -1.0 if filled else 1.0)
	_text(Vector2(16, 84), "Fire %d · Earth %d" % [Progression.mastery("fire"), Progression.mastery("earth")], 10, Color(1, 1, 1, 0.6))
	# Top right: the loop and this run's numbers, which the Ledger keeps.
	_panel(Rect2(800, 8, 152, 62))
	_text(Vector2(810, 26), "Loop %d" % Progression.loop(), 14, PixelArt.GOLD)
	var t: float = arena.fight_time
	_text(Vector2(810, 44), "%d:%02d   %d casts" % [int(t) / 60, int(t) % 60, int(arena.stats["casts"])], 12)
	_text(Vector2(810, 61), "%d taken  ·  %d down" % [int(arena.stats["damage_taken"]), int(arena.stats["kills"])], 11, Color(1, 1, 1, 0.7))
	# Duel bar.
	var r: Unit = arena.rival()
	if r:
		var bar := Rect2(330, 24, 300, 10)
		_text(Vector2(330, 20), "Silas Vane, Storm Rider   Poise %d" % r.poise, 13, PixelArt.STORM)
		draw_rect(bar, Color(0.15, 0.1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * r.hp_lag / r.max_hp, 10)), PixelArt.PAPER)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * r.hp / r.max_hp, 10)), PixelArt.DANGER)
		for i in range(1, int(r.max_hp / 10.0)):
			var x := bar.position.x + bar.size.x * i * 10.0 / r.max_hp
			draw_line(Vector2(x, 24), Vector2(x, 34), Color(0, 0, 0, 0.45), 1.0)
		if r.pips > 0:
			for i in arena.ignite_threshold():
				draw_rect(Rect2(636 + i * 9, 25, 7, 7), PixelArt.FIRE_HOT if i < r.pips else Color(PixelArt.FIRE, 0.25))
	# Banner.
	if banner != "" and banner_t < 3.2:
		var a := clampf(3.2 - banner_t, 0.0, 1.0) * clampf(banner_t * 4.0, 0.0, 1.0)
		_text(Vector2(0, 66 if r else 40), banner, 20, Color(PixelArt.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)
	# Hover: hits to kill with your current Bolt (design doc §4.4) and Poise.
	var h: Unit = arena.hover
	if h and main.mode == "fight":
		var sp: Vector2 = h.pos * 2.0 + Vector2(14, -30)
		var hits := ceili(h.hp / Progression.stat("ember_bolt", "damage"))
		_text(sp, "×%d" % hits, 13, PixelArt.FIRE_HOT)
		_text(sp + Vector2(0, 13), "Poise %d" % h.poise, 10, Color(1, 1, 1, 0.75))
	_draw_cards()


func _draw_cards() -> void:
	var kit = arena.kit
	var x0 := (960.0 - SLOTS.size() * (CARD.x + 4.0) + 4.0) / 2.0
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var id: String = kit.slot_spell(slot)
		var r := Rect2(Vector2(x0 + i * (CARD.x + 4.0), 540 - CARD.y - 8), CARD)
		if id == "meteor":
			_draw_magick_card(r, slot)
		else:
			_draw_spell_card(r, slot, id)


func _draw_spell_card(r: Rect2, slot: String, id: String) -> void:
	var kit = arena.kit
	var s: Dictionary = Progression.spell(id)
	var col: Color = kit.element_color(s["element"])
	var border := Color(col, 0.6)
	if glow.has(id):
		border = PixelArt.GOLD if int(glow[id] * 8.0) % 2 == 0 else col
	if kit.denied.has(slot):
		border = PixelArt.DANGER
	if kit.holding == slot:
		border = PixelArt.PAPER
	_panel(r, border)
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(30, 15)), Color(col, 0.25))
	_text(r.position + Vector2(5, 16), KEYS[slot], 11, col, HORIZONTAL_ALIGNMENT_CENTER, 28)
	_text(r.position + Vector2(38, 17), s["name"], 13, PixelArt.PAPER)
	if Progression.mutated(id):
		var w := font.get_string_size(s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		star(r.position + Vector2(38 + w + 7, 12), 4.0)
	var lv := Progression.level(id)
	_text(r.position + Vector2(0, 17), "Lv %d" % lv, 12, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6)
	var frac := 1.0 if lv >= Progression.max_level() else Progression.xp(id) / Progression.xp_needed(lv)
	draw_rect(Rect2(r.position + Vector2(6, 23), Vector2(r.size.x - 12, 3)), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(r.position + Vector2(6, 23), Vector2((r.size.x - 12) * frac, 3)), PixelArt.GOLD)
	var y := 40.0
	for key in s["stats"]:
		var def: Dictionary = s["stats"][key]
		if def.get("hidden", false):
			continue
		_text(r.position + Vector2(8, y), def["label"], 11, Color(1, 1, 1, 0.65))
		_text(r.position + Vector2(0, y), fmt(def, Progression.stat(id, key)), 11, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
		y += 13.0
	var muts: Array = Progression.mut_names(id)
	if not muts.is_empty():
		star(r.position + Vector2(11, r.size.y - 10), 3.0)
		_text(r.position + Vector2(18, r.size.y - 6), ", ".join(muts), 10, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 22)
	elif slot == "signature":
		var other := "Avalanche" if id == "pyroclasm" else "Pyroclasm"
		_text(r.position + Vector2(8, r.size.y - 6), "Tab: " + other, 10, Color(1, 1, 1, 0.5))
	_draw_cooldown(r, id)


func _draw_magick_card(r: Rect2, slot: String) -> void:
	var kit = arena.kit
	var m: Dictionary = arena.D["magicks"]["meteor"]
	var known := Progression.knows("meteor")
	var border := Color(PixelArt.FIRE_HOT, 0.6) if known else Color(1, 1, 1, 0.15)
	if glow.has("meteor"):
		border = PixelArt.GOLD if int(glow["meteor"] * 8.0) % 2 == 0 else PixelArt.FIRE
	if kit.denied.has(slot):
		border = PixelArt.DANGER
	_panel(r, border)
	_text(r.position + Vector2(5, 16), "F", 11, PixelArt.FIRE_HOT, HORIZONTAL_ALIGNMENT_CENTER, 28)
	if not known:
		_text(r.position + Vector2(38, 17), "Magick: ???", 13, Color(1, 1, 1, 0.6))
		_text(r.position + Vector2(8, 40), "Mix fire and stone.", 11, Color(1, 1, 1, 0.6))
		_text(r.position + Vector2(8, 54), "Catch a lodestone", 11, Color(1, 1, 1, 0.45))
		_text(r.position + Vector2(8, 67), "in a Pillar.", 11, Color(1, 1, 1, 0.45))
		return
	_text(r.position + Vector2(38, 17), m["name"], 13, PixelArt.FIRE_HOT)
	_text(r.position + Vector2(0, 17), "Lv %d" % Progression.magick_level("meteor"), 12, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6)
	_text(r.position + Vector2(8, 32), "Fire + Earth Magick", 10, Color(1, 1, 1, 0.5))
	var y := 46.0
	for key in m["stats"]:
		var def: Dictionary = m["stats"][key]
		_text(r.position + Vector2(8, y), def["label"], 11, Color(1, 1, 1, 0.65))
		_text(r.position + Vector2(0, y), fmt(def, Progression.magick_stat("meteor", key)), 11, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
		y += 13.0
	_text(r.position + Vector2(8, r.size.y - 6), "1 meteor per lodestone", 10, Color(1, 1, 1, 0.5))
	_draw_cooldown(r, "meteor")


func _draw_cooldown(r: Rect2, id: String) -> void:
	var left: float = arena.player.cooldown(id)
	if left <= 0.0:
		return
	var total: float = arena.kit.cooldown_total(id)
	var k := clampf(left / maxf(total, 0.01), 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(2, 2 + (r.size.y - 4) * (1.0 - k)), Vector2(r.size.x - 4, (r.size.y - 4) * k)), Color(0, 0, 0, 0.55))
	_text(r.position + Vector2(0, r.size.y / 2.0 + 8), "%.1f" % left, 18, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


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
	_text(Vector2(0, 170), "%s reached Lv %d" % [s["name"], entry["level"]], 24, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	_text(Vector2(0, 194), "Choose a mutation. It changes how the spell behaves.", 14, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var opts := Progression.milestone_options(entry)
	for i in opts.size():
		var r := _pick_rect(i)
		var hot := r.has_point(get_local_mouse_position())
		_panel(r, PixelArt.GOLD if hot else Color(PixelArt.GOLD, 0.5))
		_text(r.position + Vector2(12, 26), "[%d]  %s" % [i + 1, opts[i]["name"]], 18, PixelArt.GOLD)
		_text(r.position + Vector2(12, 56), opts[i]["text"], 14, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
	_text(Vector2(0, 350), "Press 1 or 2, or click. Re-picking happens only at an Orrery shrine.", 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.05, 0.04, 0.06, 0.78))
	_text(Vector2(0, 110), "WIZARD", 48, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960)
	_text(Vector2(0, 140), "Readable Arsenal prototype  ·  Fire + Earth  ·  Ambush at the Mill", 16, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
	var rows := [
		["WASD", "Move", "Mouse", "Aim"],
		["LMB", "Ember Bolt (3 pips = Ignite)", "RMB", "Pebble (drops a lodestone)"],
		["Q", "Pillar (hold to aim)", "E", "Fling your lodestones"],
		["R", "Signature (Tab swaps)", "F", "Magick (discover it first)"],
		["Space", "Blink", "F1", "Practice: every spell +1 level"],
	]
	var y := 200.0
	for row in rows:
		_text(Vector2(170, y), row[0], 14, PixelArt.GOLD)
		_text(Vector2(230, y), row[1], 14, PixelArt.PAPER)
		_text(Vector2(500, y), row[2], 14, PixelArt.GOLD)
		_text(Vector2(560, y), row[3], 14, PixelArt.PAPER)
		y += 26.0
	var sub := "Loop %d" % Progression.loop()
	if Progression.p["ledger"].size() > 0:
		sub += "  ·  your spells remember the earlier loops"
	_text(Vector2(0, 360), sub, 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 960)
	var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
	_text(Vector2(0, 420), "Click or press Enter to begin", 20, Color(PixelArt.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, 960)


func _draw_ledger() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.6))
	var r := Rect2(170, 90, 620, 330)
	_panel(r, Color(PixelArt.GOLD, 0.6))
	_text(r.position + Vector2(0, 34), "LOOP LEDGER  ·  Ambush at the Mill", 22, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var entries: Array = Progression.p["ledger"]
	var shown := entries.slice(maxi(0, entries.size() - 8))
	var y := r.position.y + 70.0
	for e in shown:
		var res: String = "won in %d:%02d" % [int(e["time"]) / 60, int(e["time"]) % 60] if e["result"] == "won" else "fell at %d:%02d" % [int(e["time"]) / 60, int(e["time"]) % 60]
		var col: Color = PixelArt.PAPER if e["result"] == "won" else Color(PixelArt.DANGER, 0.9)
		_text(Vector2(r.position.x + 24, y), "Loop %d" % int(e["loop"]), 15, PixelArt.GOLD)
		_text(Vector2(r.position.x + 100, y), "%s  ·  %d casts  ·  %d damage taken  ·  wizard Lv %d" % [res, int(e["casts"]), int(e["damage_taken"]), int(e["wizard_level"])], 14, col)
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
	_text(Vector2(0, r.end.y + 40), "Enter: wake again in Loop %d      Delete twice: wipe the save" % (Progression.loop() + 1), 16, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 960)
