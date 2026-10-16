extends SceneTree
## Rough frame cost of the fight (needs a display, not --headless): the bot plays, and every few
## seconds this prints draw calls, objects and primitives in the frame, and the frame rate.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --script res://tools/perf.gd -- [--seconds 30]
##
## Draw calls are the number to watch for the browser build: under xvfb the frame rate is
## software rendering and only good for comparing two builds on the same machine.

var main
var bot
var t := 0.0
var seconds := 30.0
var next := 3.0
var samples: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seconds":
			seconds = float(args[i + 1])
	var prog = root.get_node("Progression")
	prog.save_enabled = false
	prog.reset_all()
	bot = load("res://scripts/bot.gd").new()
	main = load("res://scenes/main.tscn").instantiate()
	main.bot = func(a): return bot.intent(a)
	root.add_child.call_deferred(main)


func _process(dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	t += dt
	if t >= next:
		next += 3.0
		var s := {
			"t": snappedf(t, 0.1),
			"phase": main.arena.phase,
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		}
		samples.append(s)
		print("[perf] ", s)
	if t >= seconds:
		var keys := ["fps", "draws", "objects", "prims"]
		var avg := {}
		for k in keys:
			var sum := 0.0
			for s in samples:
				sum += float(s[k])
			avg[k] = snappedf(sum / maxf(1.0, samples.size()), 0.1)
		print("[perf] average ", avg)
		return true
	return false
