extends SceneTree
## A quick still of the yard for tuning the look (needs a display, not --headless): starts the
## fight, hides the HUD and saves one frame.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --script res://tools/look_shot.gd -- --out FILE.png [--duel]

var main
var frames := 0
var out := "user://look.png"
var duel := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
		elif args[i] == "--duel":
			duel = true
	var prog = root.get_node("Progression")
	prog.save_enabled = false
	prog.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	frames += 1
	if frames == 5:
		main.start_fight()
		main.hud.visible = false
		if duel:
			main.arena.set_phase("duel")
	if frames == 200:
		root.get_viewport().get_texture().get_image().save_png(out)
		return true
	return false
