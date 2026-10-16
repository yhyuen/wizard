extends SceneTree
## Screenshots of the menus for review (needs a display, not --headless): the title card, the
## Orrery shrine, the milestone picker and the Loop Ledger.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/menus_shot.gd -- --out DIR

var main
var frames := 0
var out := "user://shots"
var Progression


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	Progression = root.get_node("Progression")
	Progression.save_enabled = false
	Progression.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("[menus] ", name)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	frames += 1
	match frames:
		30:
			_shot("title")
			main.start_fight()
		60:
			for u in main.arena.enemies():
				main.arena.kill(u)
			main.arena.spawn_queue.clear()
		120:
			for id in Progression.data["spells"]:
				Progression.set_level(id, 5)
			main.open_shrine()  # levelling to 5 also queues the milestone picks shown next
		150:
			_shot("shrine")
			main.close_shrine()
		240:
			_shot("picker")
		260:
			main._on_fight_over(true)
		300:
			_shot("ledger")
			return true
	return false
