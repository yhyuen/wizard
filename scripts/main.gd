extends Node
## Root of the ruins game (design/ruins/, on the open-world prototype): the arena runs the map
## you're on (the wizard, spells, fights in place) seen through the 3D view
## (scripts/world/world_view.gd), the HUD on top at 960×540, and the game flow on top of that
## (scripts/game/slice.gd: title, the dialogue panel, the map, the Ledger, the loading card,
## death). Input becomes an intent dictionary each physics frame, so tests can drive the same
## code with a bot.

const Arena := preload("res://scripts/arena.gd")
const Hud := preload("res://scripts/hud.gd")
const WorldView := preload("res://scripts/world/world_view.gd")
const Marks := preload("res://scripts/view/marks.gd")
const Controls := preload("res://scripts/controls.gd")
const Slice := preload("res://scripts/game/slice.gd")

var arena
var hud
var view  # the 3D town; null only when a test builds the game without one
var marks_vp: SubViewport  # the arena's flat marks round the wizard, drawn offscreen for the view
## The 3D view renders at most this many pixels across; a bigger window (or a high-DPI screen)
## gets the 3D scaled up instead of drawn at full size, while the 2D stays sharp.
const MAX_3D_WIDTH := 1280.0
## Below this many frames per second for SLOW_SECONDS, graphics drop to low on their own (F4
## switches back); low graphics also draw the 3D at 3/4 size.
const SLOW_FPS := 40
const SLOW_SECONDS := 4.0
const SETTINGS := "user://settings.json"
var gfx := "auto"  # "auto", "high" or "low", kept in SETTINGS
var _slow_t := 0.0
var mode := "title"  # title, world (walking a map), fight (a fight in place), cutscene, slice (loading, death)
var slice  # scripts/game/slice.gd
var world  # scripts/world/world.gd (the slice's)
var bot: Callable  # tests and the F2 autoplay set this: func(arena) -> intent
var autoplay
var controls  # scripts/controls.gd: classic or League-style; Tab switches, any time
var told_controls := false
var input_cool := 0.0  # seconds after a panel closes in which a click doesn't also cast
## Walking up to a person or thing to talk or use it once in reach (League right-click, or the
## map): {"type", "id", "pos"}.
var going_to := {}


func _ready() -> void:
	controls = Controls.new()
	slice = Slice.new()
	slice.setup(self)
	world = slice.world
	var vis = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual.json"))
	_build_3d(vis)
	_load_settings()
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
	Progression.breakthrough.connect(_on_breakthrough)
	slice.main = self
	add_child(slice)
	slice.screen_changed.connect(_on_slice_screen)
	arena.start_world(world.map, world, world.map.spots["cot"])
	arena.paused = true
	view.prewarm()


func _on_slice_screen(s: String) -> void:
	match s:
		"title":
			mode = "title"
		"world":
			if not mode in ["fight", "cutscene"]:
				mode = "world"
		_:
			mode = "slice"
	if mode != "world" and mode != "fight":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The arena draws its flat marks into an offscreen viewport, a window of the town round the
## wizard, which the view lays on the ground under the figures.
func _build_3d(_vis: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	add_child(vp)
	marks_vp = vp
	var holder := Node2D.new()
	vp.add_child(holder)
	arena = Arena.new()
	world.arena = arena
	view = WorldView.new()
	view.setup_world(arena, vp, world, holder)
	arena.view = view
	holder.add_child(arena)
	add_child(view)
	var marks := Marks.new()
	marks.view = view
	marks.arena = arena
	view.marks = marks
	add_child(marks)


# --- the town -----------------------------------------------------------------------------

## A new day, or a new loop: the wizard stands at `at` with nothing attacking. Waking after a
## death in the ruin rebuilds the camp's 3D first.
func enter_world(at: Vector2) -> void:
	if view != null and view.built_for != world.map_id:
		view.rebuild()
		view.prewarm()
	arena.start_world(world.map, world, at)
	arena.paused = false
	mode = "world"
	controls.reset()
	going_to = {}
	hud.reset()
	if view != null:
		view.snap()
	if not told_controls and not bot.is_valid():
		told_controls = true
		_toast_controls()


## Onto the map the world just went to, behind the loading card (slice.gd go_map): the arena
## takes the new map, the view builds it and warms its shaders, and the wizard stands at `at`.
func change_map(at: Vector2) -> void:
	arena.start_world(world.map, world, at)
	arena.paused = true
	controls.reset()
	going_to = {}
	if view != null:
		view.rebuild()
		view.snap()
		view.prewarm()


## The loading card is gone: walking again.
func resume_world() -> void:
	mode = "world"
	controls.reset()
	hud.reset()
	if view != null:
		view.snap()


## Puts the wizard at `at` (a story's `+ move`, or a fight that pulls you somewhere).
func place_player(at: Vector2) -> void:
	arena.player.pos = at
	controls.reset()
	going_to = {}
	if view != null:
		view.snap()


## After wells or a Ring change: Vitality and Aether follow the lent rules.
func refresh_player() -> void:
	var P: Unit = arena.player
	if P == null:
		return
	var old := P.max_hp
	P.max_hp = Progression.max_hp()
	P.hp = minf(P.max_hp, P.hp + maxf(0.0, P.max_hp - old))


## After the spellbook changes at your desk.
func refresh_book() -> void:
	arena.kit.reset_slots()


## A fight from the story, where you stand (data/slice/encounters.json), its enemies from `spawns`.
func start_world_fight(enc: Dictionary, spawns: Array) -> void:
	mode = "fight"
	controls.reset()
	going_to = {}
	arena.begin_encounter(enc, spawns)
	arena.paused = false


## A short scene in the town (the Fire on the College stairs, staged at `at`).
func start_world_cutscene(id: String, at: Vector2) -> void:
	mode = "cutscene"
	controls.reset()
	arena.play_cutscene(id, at)
	arena.paused = false


## Walks to `at` along the streets (the map), in either scheme.
func walk_to(at: Vector2) -> void:
	going_to = {}
	controls.walk(arena, at)


## Walks up to a person or thing, then talks or uses it.
func go_to(target: Dictionary) -> void:
	controls.walk(arena, target["pos"])
	going_to = target


## Names the control scheme in a toast, replacing the last one so Tab presses do not stack.
func _toast_controls() -> void:
	hud.toasts = hud.toasts.filter(func(t): return not t["text"].begins_with("Controls: "))
	hud.push_toast("Controls: %s  ·  Tab to switch" % controls.NAMES[controls.scheme], PixelArt.GOLD)


func _process(dt: float) -> void:
	_show_3d(mode in ["world", "fight", "cutscene"] or (view != null and view.warm > 0))
	if view == null or bot.is_valid():
		return
	if Input.is_action_just_pressed("graphics"):
		set_gfx("low" if not view.low else "high")
		hud.push_toast("Graphics: %s  ·  F4 to switch" % ("low" if view.low else "high"), PixelArt.GOLD)
	# Auto: a town that keeps running slow switches to low graphics, once.
	if gfx == "auto" and mode in ["world", "fight"] and not view.low and not arena.paused:
		_slow_t = _slow_t + dt if Engine.get_frames_per_second() < SLOW_FPS else 0.0
		if _slow_t > SLOW_SECONDS:
			view.set_low(true)
			hud.push_toast("Running slowly, so graphics are now low  ·  F4 for high", PixelArt.GOLD)


func set_gfx(g: String) -> void:
	gfx = g
	if view != null:
		view.set_low(g == "low")
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"gfx": gfx}))


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if d is Dictionary and str(d.get("gfx", "")) in ["auto", "high", "low"]:
			gfx = d["gfx"]
	if view != null and gfx == "low":
		view.set_low(true)


## The death and end screens cover the whole window, so the town behind them is not drawn.
func _show_3d(on: bool) -> void:
	if view == null:
		return
	var vp := get_viewport()
	var scale := clampf(MAX_3D_WIDTH / maxf(1.0, DisplayServer.window_get_size().x), 0.5, 1.0)
	if view.low:
		scale *= 0.75
	if not is_equal_approx(vp.scaling_3d_scale, scale):
		vp.scaling_3d_scale = scale
	if vp.disable_3d == (not on):
		return
	vp.disable_3d = not on
	marks_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _physics_process(dt: float) -> void:
	input_cool = maxf(0.0, input_cool - dt)
	# Tab switches the control scheme anywhere.
	if Input.is_action_just_pressed("controls") and not bot.is_valid():
		controls.cycle()
		if mode != "title":
			_toast_controls()
	var frozen: bool = mode == "slice" or mode == "title" or (mode == "world" and slice.busy())
	if not Progression.pending.is_empty() and mode in ["world", "fight"]:
		frozen = true
		_pick_input()
	arena.paused = frozen
	if frozen:
		return
	match mode:
		"world", "fight":
			_town_input()
		"cutscene":
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("blink"):
				if arena.cutscene != null:
					arena.cutscene.t = maxf(arena.cutscene.t, arena.cutscene.length)


## A milestone pick (1 or 2) while the town waits.
func _pick_input() -> void:
	if Input.is_action_just_pressed("pick1"):
		Progression.pick(0)
	elif Input.is_action_just_pressed("pick2"):
		Progression.pick(1)
	elif bot.is_valid() and autoplay == null:
		Progression.pick(arena.rng.randi() % 2)  # the test bot picks at random


func _town_input() -> void:
	if Input.is_action_just_pressed("autoplay") and mode == "fight":
		if autoplay == null:
			autoplay = load("res://scripts/bot.gd").new()
			bot = func(a): return autoplay.intent(a)
			hud.push_toast("Autoplay on (F2 to take over)", PixelArt.PAPER)
		else:
			autoplay = null
			bot = Callable()
			hud.push_toast("Autoplay off", PixelArt.PAPER)
	if autoplay != null and mode == "world":
		autoplay = null  # autoplay only fights
		bot = Callable()
	if Input.is_action_just_pressed("practice"):
		for id in Progression.data["spells"]:
			Progression.set_level(id, Progression.level(id) + 1)
		hud.push_toast("Practice: every spell +1 level", PixelArt.GOLD)
	if bot.is_valid():
		arena.intent = bot.call(arena)
		arena.mouse = arena.intent.get("aim", arena.mouse)
		return
	var mouse: Vector2 = view.to_sim(hud.get_local_mouse_position())
	arena.mouse = mouse
	# League: right-click a person or a thing walks up to it, then talks or uses it.
	var clicked := {}
	if mode == "world" and controls.league() and Input.is_action_just_pressed("lol_move"):
		clicked = world.under(mouse)
	var intent: Dictionary = controls.intent(arena, mouse, get_physics_process_delta_time())
	if not clicked.is_empty():
		go_to(clicked)
		intent = controls.build(arena, mouse, {"held": {}, "pressed": {}, "released": {}})
	if input_cool > 0.0:
		for k in ["held", "pressed", "released"]:
			intent[k] = {}
	arena.intent = intent
	if not going_to.is_empty() and mode == "world":
		var reach := float(world.cfg["reach"])
		var at: Vector2 = going_to["pos"]
		if going_to["type"] == "person" and world.people.get_person(going_to["id"]) != null:
			at = world.people.get_person(going_to["id"]).pos
		if arena.player.pos.distance_to(at) < reach:
			world.interact(going_to)
			going_to = {}
			controls.reset()
		elif controls.route.is_empty() and controls.dest == null:
			going_to = {}


func _on_fight_over(won: bool) -> void:
	match mode:
		"cutscene":
			mode = "world"
			slice.cutscene_done()
		"fight":
			mode = "world"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			slice.fight_done(won, int(arena.stats["kills"]))


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
	if Progression.at_wall(id):
		hud.push_toast("%s has reached the top of %s. Its next breakthrough is in your spellbook." % [s["name"],
			Progression.stage_name(Progression.stage(id))], PixelArt.GOLD)


## A breakthrough (spell spec §6.4): a new stage, a bigger step, a higher Force grade.
func _on_breakthrough(id: String, stage: int) -> void:
	hud.push_toast("Breakthrough: %s is %s now (Force grade %d)." % [Progression.spell(id)["name"], Progression.stage_name(stage),
		Progression.grade(id)], PixelArt.GOLD)


func _on_mutation(id: String, mut: Dictionary) -> void:
	hud.push_toast("%s mutates into %s: %s" % [Progression.spell(id)["name"], mut["name"], mut["text"]], PixelArt.GOLD)
