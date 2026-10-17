extends Node
## Root: the arena seen through the 3D ink view (scripts/view/), the HUD on top at 960×540, the
## vertical slice's game flow on top of that (scripts/game/slice.gd: title, board, scenes, Ledger),
## and the fights, the Orrery shrine menu and the old Mill fight's Loop Ledger. Input becomes an intent
## dictionary each physics frame, so tests can drive the same code with a bot. With "enabled":
## false in data/visual.json the old pixel-art arena (480×270 scaled up ×2) comes back.

const Arena := preload("res://scripts/arena.gd")
const Hud := preload("res://scripts/hud.gd")
const View3D := preload("res://scripts/view/view3d.gd")
const Marks := preload("res://scripts/view/marks.gd")
const Controls := preload("res://scripts/controls.gd")
const Slice := preload("res://scripts/game/slice.gd")

var arena
var hud
var view  # the 3D view, or null for the flat pixel arena
var container: SubViewportContainer
var mode := "title"  # title, slice, tests, fight, ledger
var slice  # scripts/game/slice.gd: the slice's title card, day board, scenes and Ledger
var slice_fight := false  # the fight running was started from the slice
## Test scenes (T on the title card): jump straight into one part of the game. A test never
## touches the save: the progress is put back as it was when you leave the menu.
const TEST_SCENES := [
	{"id": "", "name": "Full fight", "text": "The normal run: both waves, then Silas"},
	{"id": "wave1", "name": "Wave 1: Dust Hollows", "text": "Melee Hollows, straight away"},
	{"id": "wave2", "name": "Wave 2: Slingers", "text": "Slingers and a Backward Slinger"},
	{"id": "duel", "name": "Duel: Silas Vane", "text": "Straight to the Storm Rider"},
	{"id": "backward", "name": "Backward Slingers", "text": "Stones that fly home, on repeat"},
	{"id": "inversion", "name": "Loop 2: Rewind and the echo", "text": "Rewind on F and your backwards echo"},
	{"id": "shrine", "name": "The Orrery", "text": "Shrine open, every spell unlocked"},
	{"id": "dummies", "name": "Practice yard", "text": "Hollows that never strike back"},
]
var testing := false  # in a test scene, or its menu
var _saved_p := {}  # the progress to put back after testing
var bot: Callable  # tests and the F2 autoplay set this: func(arena) -> intent
var autoplay
var wipe_armed := 0.0
var shrine_open := false
var controls  # scripts/controls.gd: classic or League-style; Tab switches, any time
var told_controls := false  # the first fight names the scheme once


func _ready() -> void:
	controls = Controls.new()
	var vis = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual.json"))
	if vis is Dictionary and vis.get("enabled", true):
		_build_3d(int(vis.get("overlay_scale", 3)))
	else:
		_build_flat()
	hud = Hud.new()
	hud.main = self
	hud.arena = arena
	arena.controls = controls
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
	slice = Slice.new()
	slice.main = self
	add_child(slice)
	slice.screen_changed.connect(_on_slice_screen)


func _on_slice_screen(s: String) -> void:
	if s != "fight" and mode in ["title", "slice"]:
		mode = "title" if s == "title" else "slice"


## The arena draws its flat marks into an offscreen viewport (scaled up so lines stay fine),
## which the 3D view lays on the ground under the figures.
func _build_3d(over: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480 * over, 270 * over)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	add_child(vp)
	var holder := Node2D.new()
	holder.scale = Vector2(over, over)
	vp.add_child(holder)
	arena = Arena.new()
	view = View3D.new()
	view.setup(arena, vp)
	arena.view = view
	holder.add_child(arena)
	add_child(view)
	var marks := Marks.new()
	marks.view = view
	marks.arena = arena
	view.marks = marks
	add_child(marks)


func _build_flat() -> void:
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


func start_fight(scene := "", enc := {}) -> void:
	mode = "fight"
	shrine_open = false
	slice.visible = false
	arena.start(scene, enc)
	arena.paused = false
	controls.reset()
	hud.reset()
	if not told_controls and not bot.is_valid():
		told_controls = true
		_toast_controls()
	if not bot.is_valid():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## A fight from the slice's story: `enc` is its entry in data/slice/encounters.json.
## The slice lends the fight its Practice, spellbook and rules (scripts/game/growth.gd).
func start_slice_fight(enc: Dictionary) -> void:
	slice_fight = true
	slice.growth.begin_fight()
	start_fight("", enc)


## Names the control scheme in a toast, replacing the last one so Tab presses do not stack.
func _toast_controls() -> void:
	hud.toasts = hud.toasts.filter(func(t): return not t["text"].begins_with("Controls: "))
	hud.push_toast("Controls: %s  ·  Tab to switch" % controls.NAMES[controls.scheme], PixelArt.GOLD)


func _physics_process(_dt: float) -> void:
	wipe_armed = maxf(0.0, wipe_armed - _dt)
	# Tab switches the control scheme anywhere: the title card, mid-fight or the Ledger.
	if Input.is_action_just_pressed("controls") and not bot.is_valid():
		controls.cycle()
		if mode != "title":
			_toast_controls()
	match mode:
		"title":
			if Input.is_action_just_pressed("tests") and not bot.is_valid():
				open_tests()
			elif bot.is_valid():
				start_fight()  # the fight bot (tools/tests/fight.gd) plays the old Mill fight
		"tests":
			if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("tests"):
				close_tests()
			for i in TEST_SCENES.size():
				if Input.is_action_just_pressed("pick%d" % (i + 1)):
					run_test(i)
					break
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
	if testing and not shrine_open and Input.is_action_just_pressed("cancel"):
		open_tests()
		return
	if shrine_open:
		if Input.is_action_just_pressed("shrine") or Input.is_action_just_pressed("cancel") or not arena.shrine_ready():
			close_shrine()
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
	var mouse: Vector2 = view.to_sim(hud.get_local_mouse_position()) if view else hud.get_local_mouse_position() / 2.0
	if bot.is_valid():
		arena.intent = bot.call(arena)
		arena.mouse = arena.intent.get("aim", arena.mouse)
		return
	arena.mouse = mouse
	arena.intent = controls.intent(arena, mouse, get_physics_process_delta_time())


# --- test scenes ------------------------------------------------------------------

func open_tests() -> void:
	if not testing:
		testing = true
		_saved_p = Progression.p.duplicate(true)
		Progression.save_enabled = false
	mode = "tests"
	slice.visible = false
	shrine_open = false
	arena.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Back to the title card, with the progress exactly as it was before testing.
func close_tests() -> void:
	if testing:
		testing = false
		Progression.p = _saved_p
		Progression.pending.clear()
		Progression.save_enabled = not "--script" in OS.get_cmdline_args()
	mode = "title"
	arena.paused = true
	slice.set_screen("title")


## Sets up what scene `i` needs (later loops, Rewind, an echo), then starts it.
func run_test(i: int) -> void:
	var t: Dictionary = TEST_SCENES[i]
	Progression.p = _saved_p.duplicate(true)
	Progression.pending.clear()
	if t["id"] in ["inversion", "shrine"]:
		if Progression.loop() < 2:
			Progression.next_loop()  # Rewind comes back with you, into slot 6
		if t["id"] == "inversion":
			if not Progression.spellbook().has("rewind"):
				Progression.set_spell(5, "rewind")
			if Progression.echo_track().is_empty():
				Progression.p["echo"] = {"loop": Progression.loop() - 1, "won": false, "track": _made_up_echo()}
	start_fight(t["id"])
	if t["id"] == "shrine":
		open_shrine()


## A last fight to replay when there is none yet: a slow loop round the yard, casting now and then.
func _made_up_echo() -> Array:
	var track: Array = []
	for i in 600:
		var a := i * 0.012
		track.append_array([240.0 + cos(a) * 70.0, 142.0 + sin(a) * 45.0, cos(a + 1.5), sin(a + 1.5), 1 if i % 9 == 0 else 0])
	return track


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


## Puts spell `id` in spellbook slot `index` (0-5). A spell already in another slot swaps with it.
func shrine_spell(index: int, id: String) -> void:
	if Progression.spellbook()[index] == id:
		return
	Progression.set_spell(index, id)
	hud.push_toast("%s: %s" % [controls.key(Hud.SLOTS[index]), Progression.spell(id)["name"]], PixelArt.GOLD)


func shrine_repick(id: String, lv: int, index: int) -> void:
	Progression.repick(id, lv, index)


func _on_fight_over(won: bool) -> void:
	if slice_fight:
		slice_fight = false
		mode = "slice"
		shrine_open = false
		arena.paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		slice.growth.end_fight()
		slice.fight_done(won, int(arena.stats["kills"]))
		return
	if testing:
		hud.push_toast("Test over: %s" % ("won" if won else "fell"), PixelArt.GOLD)
		open_tests()
		return
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
		"spellbook": Progression.spellbook().duplicate(),
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
	hud.push_level(id, "Magick discovered: %s (C)" % Progression.data["magicks"][id]["name"], Progression.data["magicks"][id]["blurb"])


func _on_hint(id: String) -> void:
	var m: Dictionary = Progression.data["magicks"][id]
	hud.push_level(id, "A tome on %s" % m["name"], m["hint"])
