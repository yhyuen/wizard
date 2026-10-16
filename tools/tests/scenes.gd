extends SceneTree
## Opens the test scene menu and plays every scene for a few seconds with the bot, headless:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/scenes.gd
##
## Each scene must start in the right phase and get enemies on the field (the Orrery scene must
## open the shrine instead), and leaving the menu must put the progress back as it was.

const SECONDS := 6

var main
var bot
var Progression
var i := -1
var frames := 0
var fails: Array = []
var before := {}
var seen := {}


func _initialize() -> void:
	Progression = root.get_node("Progression")
	Progression.save_enabled = false
	Progression.reset_all()
	before = Progression.p.duplicate(true)
	bot = load("res://scripts/bot.gd").new()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null or main.hud == null:
		return false
	if i < 0:
		main.open_tests()
		_next()
		return false
	frames += 1
	var a = main.arena
	if main.mode == "fight" and not main.shrine_open:
		a.intent = bot.intent(a)
		a.mouse = a.intent.get("aim", a.mouse)
	if not a.enemies().is_empty():
		seen["foes"] = true
	if a.rival() != null:
		seen["rival"] = true
	if a.zones.any(func(z): return z["kind"] == "rline"):
		seen["rline"] = true
	if not a.echo.is_empty() and a.echo.get("on", false):
		seen["echo"] = true
	if frames >= SECONDS * 60:
		_check()
		if i + 1 >= main.TEST_SCENES.size():
			main.close_tests()
			if JSON.stringify(Progression.p) != JSON.stringify(before):
				fails.append("leaving the test menu did not put the progress back")
			for f in fails:
				print("[scenes] FAIL: " + f)
			print("[scenes] %d scene(s), %d failure(s)" % [main.TEST_SCENES.size(), fails.size()])
			quit(1 if not fails.is_empty() else 0)
			return true
		main.open_tests()
		_next()
	return false


func _next() -> void:
	i += 1
	frames = 0
	seen = {}
	bot = load("res://scripts/bot.gd").new()
	main.run_test(i)


func _check() -> void:
	var t: Dictionary = main.TEST_SCENES[i]
	var a = main.arena
	var id: String = t["id"]
	print("[scenes] %s: phase %s, %s" % [t["name"], a.phase, seen.keys()])
	match id:
		"shrine":
			if not main.shrine_open:
				fails.append("the Orrery scene did not open the shrine")
			if not Progression.unlocked("rewind"):
				fails.append("the Orrery scene did not unlock every spell")
		"duel":
			if not seen.has("rival"):
				fails.append("the duel scene never brought Silas")
		"backward":
			if not seen.has("rline"):
				fails.append("no Backward Slinger threw a stone home")
		"inversion":
			if not seen.has("echo") or not Progression.spellbook().has("rewind"):
				fails.append("the inversion scene needs the echo and Rewind in the book")
		_:
			if not seen.has("foes"):
				fails.append("%s never put an enemy on the field" % t["name"])
