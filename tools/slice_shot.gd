extends SceneTree
## Screenshots of the slice's screens for review (needs a display, not --headless): the title,
## a dawn, the day board, a scene, the Ledger, a death, the Long Night and the end card.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/slice_shot.gd -- --out DIR

var main
var slice
var run
var frames := 0
var out := "user://shots"
var plan: Array = []  # [frame, callable]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("[slice-shot] ", name)


func _process(_dt: float) -> bool:
	if main == null or main.slice == null:
		return false
	slice = main.slice
	slice.fight_resolver = func(id): return id != "tide"
	frames += 1
	match frames:
		20:
			_shot("01_title")
			slice.new_month()
		30:
			_shot("02_fire")
			slice.choose(0)
		40:
			_shot("03_dawn")
			slice.start_day()
		45:
			slice.choose(0)
		50:
			_shot("04_board")
			slice.pick_place("archive")
		60:
			_shot("05_archive")
			slice.choose(1)
		70:
			_shot("06_noon_note")
			slice.choose(slice.opts.size() - 1)
			run.learn("burnt_door")
			run.learn("scorch_match")
			slice.ledger_q = "q_door"
			slice.ledger_open = true
		80:
			_shot("07_ledger")
			slice.ledger_tab = 1
		90:
			_shot("08_ledger_clues")
			slice.ledger_open = false
			# Jump to day 7 dusk to see the tide and the death screen.
			run.skip_to(7, 3)
			slice.next_slot()
		100:
			_shot("09_tide")
			slice.advance()
		110:
			slice.advance()
		120:
			_shot("10_death")
			slice.wake()
			run.learn("noon_note")
			run.learn("own_star")
			run.skip_to(27, 4)
			slice.next_slot()
		130:
			slice.advance()
		135:
			slice.choose(0)
		140:
			slice.advance()
		145:
			_shot("11_long_night")
		150:
			run.learn("long_night")
			slice.begin_day()
		160:
			_shot("12_end")
			quit(0)
	return false
