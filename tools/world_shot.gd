extends SceneTree
## Screenshots of the first playable for review, with draw calls and frame time at each (needs a
## display, not --headless): the title, waking in the camp, the yard and the captain's cordon,
## the market at noon, the lane at dusk, the camp at night, a patrol fight, a burning hay bale,
## a grass fire and a charged wet patch, the camp's map, the Reach and the calendar, and the
## spellbook; then the loading card, the halls' landing and shrine, the
## entrance hall, the rune door, the halls' map, a crack glowing and the embers out of it, the
## refectory, the dark gallery, the bell passage, the burnt door, the cistern's sluice, the Kiln
## Warden's rings and vents, and the end card.
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
	run.life["day"] = d
	run.life["time"] = t
	slice.world.clock = 2.0
	slice.world.reset_day()
	main.place_player(at)
	slice.world.requests.clear()
	slice.cur = {}


## Ends a fight in place without its story outcome: back to walking.
func _end_fight() -> void:
	main.arena.resume_explore()
	main.mode = "world"
	slice.cur = {}


## Plays out whatever scene is up, taking the first choice each time.
func _close() -> void:
	for i in 20:
		if slice.cur.is_empty():
			break
		if slice.pending.is_empty():
			slice.choose(0)
		else:
			slice.advance()


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
			_shot("02_wake_camp")
			_close()
			_go(sp["yard_c"], 1, 1)
		160:
			_shot("03_yard_noon")
			_go(sp["captain"] + Vector2(-50, 40), 1, 1)
		200:
			_shot("04_captain_cordon")
			_go(sp["market_c"], 2, 1)
		240:
			_shot("05_market_noon")
			_go(sp["mira_door"] + Vector2(-60, -120), 2, 3)
		280:
			W.clock = 30.0
		320:
			_shot("06_lane_dusk")
			_go(sp["square_c"], 2, 4)
		360:
			_shot("07_camp_night")
			_go(sp["yard_c"] + Vector2(0, 40), 2, 4)
			slice._start_fight("patrol")
		480:
			_shot("08_patrol_fight")
			main.arena.resume_explore()
			main.mode = "world"
			_go(sp["mill_east"] + Vector2(-60, 120), 2, 2)
			for p in W.props:
				if p["kind"] == "hay" and p["pos"].distance_to(main.arena.player.pos) < 260.0:
					W.ignite(p)
					break
		540:
			_shot("09_mill_fire")
			# The ground (N-4.2): a grass fire spreading, and a wet patch beside it taking a Spark.
			var c = W.cells
			for i in c.mat.size():
				var p: Vector2 = c.centre(i)
				if c.within(p, 60.0).all(func(j): return c.mats[c.mat[j]] == "grass") and not W.map.solid_at(p, 60.0):
					_go(p + Vector2(70, 60), 2, 1)
					W.set_sky({"kind": "clear", "wind": 2, "dir": "W"}, {})
					W.burn_ground(p, 40.0, 1)
					W.wet_ground(p + Vector2(110, 40), 40.0)
					W.strike_ground(p + Vector2(80, 40), p + Vector2(130, 40), 3)
					break
		552:
			_shot("09a_ground_fire")
			slice.overlay = "map"
		560:
			_shot("10_camp_map")
			slice.map_tab = 1
		563:
			_shot("10a_the_reach")
			slice.map_tab = 2
			slice.weather.forecast("camp")  # asked Aldous: tomorrow's glyph shows
			for d in range(3, 15):
				slice.weather.note("camp", d)  # days lived in an earlier life, in the Almanac
		566:
			_shot("10b_calendar")
			slice.map_tab = 0
			slice.overlay = "ledger"
			slice.ledger_tab = 6
			slice.deeds.earn("first_ring")
		568:
			_shot("10c_deeds")
			slice.ledger_tab = 4
			slice.run.settle_event(slice.run.fixed_events().filter(func(e): return e["id"] == "iron_gate_shuts")[0], "missed")
		569:
			_shot("10d_appointments")
			slice.ledger_tab = 0
			slice.growth.practice()["pebble"].merge({"level": 10, "stage": 1, "xp": 20.0, "hits": 30}, true)  # at the Master wall, one trial short
			slice.growth.practice()["ember_bolt"].merge({"level": 7, "stage": 1}, true)
			slice.book_slot = slice.growth.book().find("pebble")
			slice.overlay = "book"
		570:
			_shot("11_book")
			slice.overlay = ""
			_go(sp["north_in"], 2, 0)
		600:
			_shot("12_north_stair")
			slice.go_map("halls", "landing")
		606:
			_shot("13_loading")
		690:
			_close()
		700:
			_shot("14_halls_landing")
			main.place_player(W.map.spots["hall_c"] + Vector2(0, 120))
		740:
			_shot("15_entrance_hall")
			main.place_player(W.map.items["rune_door"]["at"] + Vector2(-60, 0))
		780:
			_shot("16_rune_door")
			slice.overlay = "map"
		800:
			_shot("17_halls_map")
			slice.overlay = ""
			main.place_player(W.map.spots["hall_s"] if W.map.spots.has("hall_s") else Vector2(1100, 1620))
			main.start_world_cutscene("path:sighting", main.arena.player.pos)
		900:
			_shot("17a_sighting_still")
		990:
			_shot("17b_sighting_backwards")
		1060:
			main.mode = "world"
			main.arena.cutscene = null
			main.arena.phase = "explore"
			main.arena.units = main.arena.units.filter(func(u): return u.team != 2)
			main.place_player(W.map.items["great_clock"]["at"] + Vector2(-40, 0))
			main.start_world_cutscene("path:provost_eclipse", main.arena.player.pos)
		1260:
			_shot("17c_provost_replay")
			main.mode = "world"
			main.arena.cutscene = null
			main.arena.phase = "explore"
			main.arena.units = main.arena.units.filter(func(u): return u.team != 2)
			main.place_player(W.map.spots["hall_c"] + Vector2(-260, -40))
			slice._start_fight("hall_fight")
		1400:
			_shot("18_crack_glow")
		1530:
			_shot("19_hall_embers")
			_end_fight()
			_go(W.map.spots["refectory_c"], 2, 0)
		1570:
			_shot("20_refectory")
			_go(W.map.spots["gallery_c"], 2, 0)
		1610:
			_shot("21_gallery_dark")
			_go(W.map.spots["passage_c"] + Vector2(0, 60), 2, 0)
		1650:
			_shot("22_bell_passage")
			_go(W.map.spots["ante_s"] + Vector2(0, -60), 2, 0)
		1690:
			_shot("23_burnt_door")
			_go(W.map.spots["cistern_c"] + Vector2(120, 40), 2, 0)
		1730:
			_shot("24_cistern_sluice")
			_go(W.map.spots["kiln_s"], 2, 0)
			slice._start_fight("warden")
		2040:
			main.arena.player.hp = main.arena.player.max_hp
			_shot("25_warden_rings")
			var w = main.arena.enemies().filter(func(u): return u.kind == "warden")
			if not w.is_empty():
				w[0].hp = w[0].max_hp * 0.5
		2240:
			main.arena.player.hp = main.arena.player.max_hp
			_shot("26_warden_vents")
			_end_fight()
			slice.end_loop("first_playable_end")
		2260:
			_shot("27_end_card")
			var f := FileAccess.open(out.path_join("stats.txt"), FileAccess.WRITE)
			f.store_string("\n".join(stats) + "\n")
			return true
	return false
