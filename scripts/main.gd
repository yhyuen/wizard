extends Node
## Root: the pixel-art arena in a 480×270 SubViewport scaled up ×2, the HUD on top at 960×540,
## and the title, fight and Loop Ledger flow, plus the Orrery shrine menu. Input becomes an intent
## dictionary each physics frame, so tests can drive the same code with a bot.

const Arena := preload("res://scripts/arena.gd")
const Hud := preload("res://scripts/hud.gd")

var arena
var hud
var container: SubViewportContainer
var mode := "title"  # title, fight, ledger
var bot: Callable  # tests and the F2 autoplay set this: func(arena) -> intent
var autoplay
var wipe_armed := 0.0
var shrine_open := false


func _ready() -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 2
	container.size = Vector2(960, 540)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.snap_2d_transforms_to_pixel = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.handle_input_locally = false
	container.add_child(vp)
	arena = Arena.new()
	vp.add_child(arena)
	hud = Hud.new()
	hud.main = self
	hud.arena = arena
	add_child(hud)
	arena.paused = true
	arena.toast.connect(hud.push_toast)
	arena.banner.connect(hud.set_banner)
	arena.fight_over.connect(_on_fight_over)
	Progression.spell_leveled.connect(_on_spell_leveled)
	Progression.mutation_picked.connect(_on_mutation)
	Progression.wizard_leveled.connect(_on_wizard_leveled)
	Progression.magick_learned.connect(_on_magick)
	Progression.hint_learned.connect(_on_hint)


func start_fight() -> void:
	mode = "fight"
	shrine_open = false
	arena.start()
	arena.paused = false
	hud.reset()
	if not bot.is_valid():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _physics_process(_dt: float) -> void:
	wipe_armed = maxf(0.0, wipe_armed - _dt)
	match mode:
		"title":
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("bolt1") or bot.is_valid():
				start_fight()
		"fight":
			_fight_input()
		"ledger":
			if Input.is_action_just_pressed("confirm"):
				Progression.next_loop()
				start_fight()
			elif Input.is_action_just_pressed("wipe"):
				if wipe_armed > 0.0:
					Progression.reset_all()
					hud.push_toast("Save wiped. Loop 1 again.", PixelArt.DANGER)
					wipe_armed = 0.0
				else:
					wipe_armed = 2.0
					hud.push_toast("Press Delete again to wipe every loop and spell level.", PixelArt.DANGER)


func _fight_input() -> void:
	if shrine_open:
		if Input.is_action_just_pressed("shrine") or Input.is_action_just_pressed("cancel") or not arena.shrine_ready():
			close_shrine()
		else:
			for i in 4:
				if Input.is_action_just_pressed("pick%d" % (i + 1)):
					shrine_element(1 if Input.is_key_pressed(KEY_SHIFT) else 0, Progression.elements()[i])
		return
	if Input.is_action_just_pressed("shrine") and not bot.is_valid():
		if arena.shrine_ready():
			open_shrine()
		elif arena.phase in ["intro", "wave1", "wave2"]:
			hud.push_toast("The Orrery answers only while the yard is quiet, and only up close.", PixelArt.GOLD)
	if not Progression.pending.is_empty():
		arena.paused = true
		if Input.is_action_just_pressed("pick1"):
			Progression.pick(0)
		elif Input.is_action_just_pressed("pick2"):
			Progression.pick(1)
		elif bot.is_valid() and autoplay == null:
			Progression.pick(arena.rng.randi() % 2)  # the test bot picks at random
		if Progression.pending.is_empty():
			arena.paused = false
		return
	if Input.is_action_just_pressed("autoplay"):
		if autoplay == null:
			autoplay = load("res://scripts/bot.gd").new()
			bot = func(a): return autoplay.intent(a)
			hud.push_toast("Autoplay on (F2 to take over)", PixelArt.PAPER)
		else:
			autoplay = null
			bot = Callable()
			hud.push_toast("Autoplay off", PixelArt.PAPER)
	if Input.is_action_just_pressed("practice"):
		for id in Progression.data["spells"]:
			Progression.set_level(id, Progression.level(id) + 1)
		hud.push_toast("Practice: every spell +1 level", PixelArt.GOLD)
	var mouse: Vector2 = hud.get_local_mouse_position() / 2.0
	if bot.is_valid():
		arena.intent = bot.call(arena)
		arena.mouse = arena.intent.get("aim", arena.mouse)
		return
	arena.mouse = mouse
	var intent := {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"aim": mouse,
		"held": {}, "pressed": {}, "released": {},
	}
	for a in ["bolt1", "bolt2", "control1", "control2", "signature", "magick", "blink", "swap_signature"]:
		intent["held"][a] = Input.is_action_pressed(a)
		intent["pressed"][a] = Input.is_action_just_pressed(a)
		intent["released"][a] = Input.is_action_just_released(a)
	arena.intent = intent


# --- the Orrery shrine ----------------------------------------------------------

## The only place to change elements or re-pick a milestone mutation (design doc §7).
func open_shrine() -> void:
	if not arena.shrine_ready():
		return
	shrine_open = true
	arena.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_shrine() -> void:
	shrine_open = false
	arena.paused = false
	arena.kit.reset_slots()
	if not bot.is_valid():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Puts `element` in slot 0 or 1. Choosing the element already in the other slot swaps them.
func shrine_element(slot: int, element: String) -> void:
	var lo: Array = Progression.loadout().duplicate()
	if lo[slot] == element:
		return
	if lo[1 - slot] == element:
		lo.reverse()
	else:
		lo[slot] = element
	Progression.set_loadout(lo[0], lo[1])
	hud.push_toast("Equipped: %s + %s" % [Progression.data["elements"][lo[0]]["name"], Progression.data["elements"][lo[1]]["name"]], PixelArt.GOLD)


func shrine_repick(id: String, lv: int, index: int) -> void:
	Progression.repick(id, lv, index)


func _on_fight_over(won: bool) -> void:
	var levels := {}
	for id in Progression.data["spells"]:
		levels[id] = Progression.level(id)
	Progression.record({
		"result": "won" if won else "fell",
		"time": snappedf(arena.fight_time, 0.1),
		"casts": int(arena.stats["casts"]),
		"damage_taken": roundf(arena.stats["damage_taken"]),
		"kills": int(arena.stats["kills"]),
		"wizard_level": Progression.wizard_level(),
		"spells": levels,
		"elements": Progression.loadout().duplicate(),
	})
	mode = "ledger"
	shrine_open = false
	arena.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_spell_leveled(id: String, old: int, new: int) -> void:
	var s: Dictionary = Progression.spell(id)
	var parts: Array = []
	for key in s["stats"]:
		var def: Dictionary = s["stats"][key]
		if def.get("hidden", false):
			continue
		var a := Progression.stat(id, key, old)
		var b := Progression.stat(id, key, new)
		if not is_equal_approx(a, b):
			parts.append("%s %s › %s" % [def["label"], Hud.fmt(def, a), Hud.fmt(def, b)])
	hud.push_level(id, "%s  Lv %d" % [s["name"], new], "   ".join(parts))


func _on_mutation(id: String, mut: Dictionary) -> void:
	hud.push_toast("%s mutates into %s: %s" % [Progression.spell(id)["name"], mut["name"], mut["text"]], PixelArt.GOLD)


func _on_wizard_leveled(old: int, new: int) -> void:
	var p: Unit = arena.player
	if p and not p.dead:
		var gain := Progression.max_hp(new) - Progression.max_hp(old)
		p.max_hp = Progression.max_hp(new)
		p.hp = minf(p.max_hp, p.hp + maxf(0.0, gain))
		arena.kit.blink_charges = mini(arena.kit.blink_charges + Progression.blink_charges(new) - Progression.blink_charges(old), Progression.blink_charges(new))
	var line := "Wizard level %d: max HP %d" % [new, Progression.max_hp(new)]
	if Progression.blink_charges(new) != Progression.blink_charges(old):
		line += ", blink charges %d" % Progression.blink_charges(new)
	hud.push_toast(line, PixelArt.PAPER)


func _on_magick(id: String) -> void:
	hud.push_level(id, "Magick discovered: %s (F)" % Progression.data["magicks"][id]["name"], Progression.data["magicks"][id]["blurb"])


func _on_hint(id: String) -> void:
	var m: Dictionary = Progression.data["magicks"][id]
	hud.push_level(id, "A tome on %s" % m["name"], m["hint"])
