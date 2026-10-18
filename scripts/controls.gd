extends RefCounted
## Turns the keyboard and mouse into the fight's intent dictionary, in one of three schemes,
## switched with Tab on the title card and kept in user://settings.cfg:
##
##   classic       WASD moves, the mouse aims, LMB RMB Q E R F are the six spellbook slots.
##   league        League of Legends style: right-click the ground to walk there (hold it to
##                 keep walking toward the cursor), right-click an enemy to attack it with your
##                 Bolt, S stops, Q W E R D F are the six slots and cast at the cursor. Spells
##                 show their telegraph while held and cast on release (quick cast with indicator).
##   league_smart  The same, but spells cast the moment their key goes down (smart cast).
##
## The arena and the kit only ever see the intent, so the bot and the tests are unaffected.

const SCHEMES := ["classic", "league", "league_smart"]
const NAMES := {"classic": "Classic (WASD)", "league": "League (right-click to move)", "league_smart": "League, smart cast"}
const SETTINGS_PATH := "user://settings.cfg"
const SLOTS := ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "magick"]
const CLASSIC_KEYS := {"slot1": "LMB", "slot2": "RMB", "slot3": "Q", "slot4": "E", "slot5": "R", "slot6": "F", "magick": "C"}
const LEAGUE_KEYS := {"slot1": "Q", "slot2": "W", "slot3": "E", "slot4": "R", "slot5": "D", "slot6": "F", "magick": "C"}
const ARRIVE := 1.5  # sim px: a move order is done this close to its point
const ORDER_LIFE := 0.45  # seconds the click marker shows

var scheme := "classic"
var save_enabled := true
var dest = null  # Vector2 the wizard is walking to, or null
var target: Unit = null  # the enemy being attacked, or null
var order := {}  # the last right-click, for the ground marker: {"at", "t", "attack"}
## In the open world a walk follows the streets: the points still to reach (scripts/world/map.gd
## path). The map's click-to-walk and walking up to a person use it in either scheme.
var route := PackedVector2Array()


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var s: String = cfg.get_value("controls", "scheme", "classic")
		if s in SCHEMES:
			scheme = s


func league() -> bool:
	return scheme != "classic"


func smart() -> bool:
	return scheme == "league_smart"


## Tab on the title card: classic, League, League with smart cast, then back.
func cycle() -> void:
	set_scheme(SCHEMES[(SCHEMES.find(scheme) + 1) % SCHEMES.size()])


func set_scheme(s: String) -> void:
	scheme = s
	reset()
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("controls", "scheme", scheme)
	cfg.save(SETTINGS_PATH)


func key(slot: String) -> String:
	return (LEAGUE_KEYS if league() else CLASSIC_KEYS)[slot]


func reset() -> void:
	dest = null
	target = null
	order = {}
	route = PackedVector2Array()


## Walks to `to`: along the streets in the open world, straight across the yard otherwise.
func walk(A, to: Vector2) -> void:
	target = null
	dest = to
	if A.world != null and not A.world.clear_line(A.player.pos, to, A.player.radius):
		route = A.world.path(A.player.pos, to, A.player.radius)
	else:
		route = PackedVector2Array([to])


## The step toward the next point of the route, or zero when it is done.
func _follow(A) -> Vector2:
	var P: Unit = A.player
	while not route.is_empty() and P.pos.distance_to(route[0]) <= (ARRIVE if route.size() == 1 else 6.0):
		route.remove_at(0)
	if route.is_empty():
		dest = null
		return Vector2.ZERO
	return (route[0] - P.pos).normalized()


## The intent for this physics frame, read from the real keyboard and mouse.
func intent(A, mouse: Vector2, dt: float) -> Dictionary:
	var raw := {"held": {}, "pressed": {}, "released": {}}
	if league():
		raw["move_click"] = Input.is_action_just_pressed("lol_move")
		raw["move_held"] = Input.is_action_pressed("lol_move")
		raw["stop"] = Input.is_action_just_pressed("lol_stop")
		for s in SLOTS:
			var a: String = "lol_" + s
			raw["held"][s] = Input.is_action_pressed(a)
			raw["pressed"][s] = Input.is_action_just_pressed(a)
			raw["released"][s] = Input.is_action_just_released(a)
	else:
		raw["move"] = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		for s in SLOTS:
			raw["held"][s] = Input.is_action_pressed(s)
			raw["pressed"][s] = Input.is_action_just_pressed(s)
			raw["released"][s] = Input.is_action_just_released(s)
	raw["held"]["blink"] = Input.is_action_pressed("blink")
	raw["pressed"]["blink"] = Input.is_action_just_pressed("blink")
	raw["released"]["blink"] = Input.is_action_just_released("blink")
	return build(A, mouse, raw, dt)


## The intent from already-read input `raw` (the tests call this directly).
func build(A, mouse: Vector2, raw: Dictionary, dt := 0.0) -> Dictionary:
	if not league():
		var mv: Vector2 = raw.get("move", Vector2.ZERO)
		if mv.length() > 0.1:
			route = PackedVector2Array()  # the keys take over from a walk
		elif not route.is_empty():
			mv = _follow(A)
		return {"move": mv, "aim": mouse,
			"held": raw["held"], "pressed": raw["pressed"], "released": raw["released"]}
	var P: Unit = A.player
	var held: Dictionary = raw["held"].duplicate()
	var pressed: Dictionary = raw["pressed"].duplicate()
	var released: Dictionary = raw["released"].duplicate()
	if not order.is_empty():
		order["t"] += dt
		if order["t"] > ORDER_LIFE:
			order = {}
	# Orders: right-click an enemy to attack it, the ground to walk there; S stops.
	if raw.get("stop", false):
		dest = null
		target = null
		route = PackedVector2Array()
	if raw.get("move_click", false):
		var h: Unit = A.hover
		if h != null and not h.dead:
			target = h
			dest = null
			order = {"at": h.pos, "t": 0.0, "attack": true}
		else:
			walk(A, A.clamp_in(mouse, P.radius))
			order = {"at": dest, "t": 0.0, "attack": false}
	elif raw.get("move_held", false) and target == null:
		var to: Vector2 = A.clamp_in(mouse, P.radius)
		if A.world == null or A.world.clear_line(P.pos, to, P.radius):
			dest = to
			route = PackedVector2Array([to])
	if target != null and (target.dead or not A.units.has(target)):
		target = null
	# Smart cast: a non-Bolt spell casts the frame its key goes down, with no telegraph.
	if smart():
		for s in SLOTS:
			if pressed.get(s, false) and not A.kit.is_bolt(A.kit.slot_spell(s)):
				released[s] = true
				held[s] = false
	var casting := false
	for s in SLOTS:
		if held.get(s, false) or pressed.get(s, false) or released.get(s, false):
			casting = true
	var aim := mouse
	var move := Vector2.ZERO
	if target != null:
		var bolt := _bolt_slot(A)
		var to: Vector2 = target.pos - P.pos
		if bolt == "" or to.length() > attack_range(A.kit.slot_spell(bolt)):
			move = to.normalized()
		elif not casting:
			held[bolt] = true
			aim = target.pos
	elif not route.is_empty():
		move = _follow(A)
	elif dest != null:
		var to: Vector2 = dest - P.pos
		if to.length() <= ARRIVE:
			dest = null
		else:
			move = to.normalized()
	# Blink goes toward the cursor, like Flash, and ends the order.
	if pressed.get("blink", false):
		move = Vector2.ZERO
		dest = null
		target = null
		route = PackedVector2Array()
	return {"move": move, "aim": aim, "held": held, "pressed": pressed, "released": released}


## The first spellbook slot holding a Bolt: right-click attacks use it.
func _bolt_slot(A) -> String:
	for s in A.kit.SLOTS:
		if A.kit.is_bolt(A.kit.slot_spell(s)):
			return s
	return ""


## How close the wizard walks before an attack fires its Bolt (sim px).
func attack_range(id: String) -> float:
	var s: Dictionary = Progression.spell(id)
	var r := 120.0
	if s["stats"].has("range"):
		r = Progression.stat(id, "range")
	elif s.has("range"):
		r = float(s["range"])
	return r * 0.9
