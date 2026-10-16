extends SceneTree
## Screenshots of the inversion test for review (needs a display, not --headless):
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/inversion_shot.gd -- --out DIR [--fast]
##
## The bot plays loop 1, then loop 2 with Rewind in the book and the echo of loop 1 walking
## backwards. Saves the Orrery with the Hours column (inv_shrine.png), a Backward Slinger's stone
## forming behind the wizard (inv_rline.png), a Rewind forming and flying home
## (inv_rewind_form.png, inv_rewind_fly.png) and the echo mid-fight (inv_echo.png). --fast skips
## loop 1 with a made-up echo, since rendering a whole fight under xvfb is slow.

var main
var bot
var out := "user://shots"
var Progression
var taken := {}
var shrine_f := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	Progression = root.get_node("Progression")
	Progression.save_enabled = false
	Progression.reset_all()
	if "--fast" in args:
		# Skip loop 1: a made-up last fight (a slow loop round the yard, casting now and then).
		var track: Array = []
		for i in 600:
			var ang := i * 0.012
			track.append_array([240.0 + cos(ang) * 70.0, 142.0 + sin(ang) * 45.0, cos(ang + 1.5), sin(ang + 1.5), 1 if i % 9 == 0 else 0])
		Progression.set_echo(track, false)
		Progression.next_loop()
		shrine_f = 0
	bot = load("res://scripts/bot.gd").new()
	main = load("res://scenes/main.tscn").instantiate()
	main.bot = func(a): return bot.intent(a)
	root.add_child.call_deferred(main)


func _shot(name: String) -> void:
	if taken.has(name):
		return
	taken[name] = true
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("[shots] ", name)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	var a = main.arena
	if main.mode == "ledger":
		if Progression.loop() >= 2:
			return true
		bot.last_pebbles = 0
		Progression.next_loop()
		main.start_fight()
		shrine_f = 0
		return false
	if Progression.loop() < 2:
		return false
	if shrine_f >= 0:
		shrine_f += 1
		if shrine_f == 20:
			main.open_shrine()
		elif shrine_f == 26:
			_shot("inv_shrine")
			main.close_shrine()
			shrine_f = -1
		return false
	for z in a.zones:
		if z["kind"] == "rline" and z["t"] > 0.5:
			_shot("inv_rline")
		if z["kind"] == "rewind_form" and z["t"] > 0.25:
			_shot("inv_rewind_form")
	for p in a.projs:
		if p["kind"] == "rewind" and p["t"] > 0.12:
			_shot("inv_rewind_fly")
	if a.fight_time > 6.0 and a.echo.get("on", false) and a.echo.get("moving", false):
		_shot("inv_echo")
	return taken.size() >= 5 or a.fight_time > 120.0
