extends SceneTree
## Screenshots of the open world for review, with draw calls and frame time at each (needs a
## display, not --headless): the title, the Fire on the stairs, your room, Wren in the archive,
## the yard, the market at noon with the crowd, the lane at dusk, the town at night, a patrol
## fight, a burning hay bale, the map and the spellbook.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/world_shot.gd -- --out DIR

var main
var slice
var run
var frames := 0
var out := "user://shots"
var plan: Array = []  # [frame, callable]
var stats: Array = []


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
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var lights: int = main.view._lights.filter(func(l): return l.visible).size()
	var line := "%s: %d draw calls, %d objects, %dk primitives, %d lights, %.1f ms/frame" % [name, dc, objs, prims / 1000, lights,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	stats.append(line)
	print("[world-shot] ", line)


## Jumps to `place` (a spot or a place) at time `t` of day `d`.
func _go(at: Vector2, d: int, t: int) -> void:
	run.lp["day"] = d
	run.lp["time"] = t
	slice.world.clock = 2.0
	slice.world.reset_day()
	main.place_player(at)
	slice.world.requests.clear()
	slice.cur = {}


func _process(_dt: float) -> bool:
	if main == null or main.slice == null:
		return false
	slice = main.slice
	var W = slice.world
	var sp: Dictionary = W.map.spots
	frames += 1
	match frames:
		20:
			_shot("01_title")
			slice.new_month()
		120:
			_shot("02_fire")  # the cutscene on the stairs
			main.arena.cutscene.t = 9.0
		260:
			_shot("03_fire_after")
			for i in 20:
				if slice.cur.is_empty():
					break
				if slice.pending.is_empty():
					slice.choose(0)
				else:
					slice.advance()
		300:
			_shot("04_stairs_morning")
			_go(sp["room_in"], 1, 0)
		340:
			_shot("05_room")
			_go(sp["wren_desk"] + Vector2(0, 40), 2, 0)
		380:
			slice.talk("wren")
		400:
			_shot("06_wren_talk")
			slice.cur = {}
			slice._stop_talking()
			_go(sp["yard_c"], 2, 1)
		440:
			_shot("07_yard_noon")
			_go(sp["market_c"], 2, 1)
		500:
			_shot("08_market_noon")
			_go(sp["mira_door"] + Vector2(-60, -120), 2, 3)
		540:
			W.clock = 30.0
		580:
			_shot("09_lane_dusk")
			_go(sp["square_c"], 2, 4)
		620:
			_shot("10_square_night")
			_go(sp["market_c"] + Vector2(0, 40), 2, 4)
			slice._start_fight("patrol")
		740:
			_shot("11_patrol_fight")
			main.arena.resume_explore()
			main.mode = "world"
			_go(sp["mill_east"] + Vector2(-60, 120), 2, 2)
			for p in W.props:
				if p["kind"] == "hay" and p["pos"].distance_to(main.arena.player.pos) < 260.0:
					W.ignite(p)
					break
		800:
			_shot("12_mill_fire")
			slice.overlay = "map"
		820:
			_shot("13_map")
			slice.overlay = "book"
		830:
			_shot("14_book")
			slice.overlay = ""
			_go(Vector2(1300, 480), 2, 4)
		870:
			_shot("15_observatory_night")
			var f := FileAccess.open(out.path_join("stats.txt"), FileAccess.WRITE)
			f.store_string("\n".join(stats) + "\n")
			return true
	return false
