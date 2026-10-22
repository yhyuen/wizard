extends SceneTree
## Screenshots of the first playable for review, with draw calls and frame time at each (needs a
## display, not --headless): the title, waking in the camp, the yard and the captain's cordon,
## the market at noon, the lane at dusk, the great lamp and its circuits at night, the camp at night, a patrol fight, the brigands' toll fight, a burning hay bale,
## a grass fire and a charged wet patch, the leaning gallery coming down, the camp's map, the Reach and the calendar, the Deeds and the Field Guide, and the
## spellbook; then the loading card, the halls' landing and shrine, the
## entrance hall, the rune door, the halls' map, a crack glowing and the embers out of it, the
## refectory, the dark gallery, the bell passage, the burnt door, the cistern's sluice, the Kiln
## Warden's rings and vents, the end card, and the fallen city: the wall gap, the Sunken Square,
## the glassworks, Bell Street's barricade and the Old Watch at dusk; the undercroft's stair,
## channel and grate hall; the Mill fields' bridge, pond, orchard and east fence at dusk.
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/world_shot.gd -- --out DIR

const FieldGuide := preload("res://scripts/field_guide.gd")

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
			_go(sp["great_lamp"] + Vector2(0, 40), 2, 4)
		340:
			_shot("07a_great_lamp")
			_go(sp["square_c"], 2, 4)
		360:
			_shot("07_camp_night")
			_go(sp["yard_c"] + Vector2(0, 40), 2, 4)
			slice._start_fight("patrol")
		480:
			_shot("08_patrol_fight")
			main.arena.resume_explore()
			main.mode = "world"
			# Brigands (N-6.3): the bridge toll, fought in the yard until the east road is built.
			_go(sp["yard_c"] + Vector2(0, 40), 2, 2)
			slice._start_fight("toll")
		590:
			# bring them in round you, so the frame shows the shield, the keg and the Captain
			var P: Vector2 = main.arena.player.pos
			var kinds := ["cutthroat", "shieldman", "brigand_captain", "powder_monkey", "crossbowman", "cutthroat"]
			for k in kinds.size():
				var u = main.arena.spawn(kinds[k], P + Vector2.from_angle(-PI * 0.95 + k * PI * 0.38) * 70.0)
				u.state = "move"
		606:
			_shot("08a_brigands")
			main.arena.resume_explore()
			main.mode = "world"
			# The Knights' picket (N-6.6): two Shieldknights side by side, a Squire and the Silencer.
			_go(sp["yard_c"] + Vector2(0, 40), 2, 2)
			slice._start_fight("picket")
		610:
			var P: Vector2 = main.arena.player.pos
			var kinds := ["shieldknight", "shieldknight", "oath_squire", "silencer"]
			for k in kinds.size():
				var u = main.arena.spawn(kinds[k], P + Vector2.from_angle(-PI * 0.8 + k * PI * 0.32) * (60.0 if k < 3 else 90.0))
				u.state = "move"
		618:
			var sil = main.arena.enemies().filter(func(u): return u.kind == "silencer")
			if not sil.is_empty():
				main.arena.add_zone({"kind": "bell", "owner": sil[0].id, "pos": main.arena.player.pos + Vector2(10, 0), "r": 35.0, "delay": 0.8})
		626:
			_shot("08b_knights")
			main.arena.resume_explore()
			main.mode = "world"
			_go(sp["mill_east"] + Vector2(-60, 120), 2, 2)
			for p in W.props:
				if p["kind"] == "hay" and p["pos"].distance_to(main.arena.player.pos) < 260.0:
					W.ignite(p)
					break
		660:
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
		672:
			_shot("09a_ground_fire")
			# The leaning gallery (N-4.3): a post breaks, and it shakes before it comes down.
			var st: Dictionary = W.structures[0]
			_go(st["rect"].get_center() + Vector2(-40, 110), 2, 1)
			W._break(st["supports"][0])
		677:
			_shot("09b_gallery_falls")
			# Spark Artifice (N-5.2): a tar pool going up under a flask, an arc rod and a smoke cloud.
			_go(sp["market_c"] + Vector2(0, -20), 2, 4)
			var K = main.arena.kit
			var at: Vector2 = main.arena.player.pos + Vector2(70, -10)
			K.ar.detonate({"kind": "throw", "device": "tar_pot", "pos": at, "r": 26.0})
			K.ar.detonate({"kind": "throw", "device": "spark_flask", "pos": at + Vector2(10, 0), "r": 16.0})
			K.ar.detonate({"kind": "throw", "device": "arc_rod", "pos": main.arena.player.pos + Vector2(-60, -30), "r": 50.0})
			K.ar.detonate({"kind": "throw", "device": "smoke_jar", "pos": main.arena.player.pos + Vector2(-20, 60), "r": 28.0})
			K.ar.detonate({"kind": "throw", "device": "star_lantern", "pos": main.arena.player.pos + Vector2(-90, 40), "r": 40.0})
		679:
			_shot("09c_devices")
			slice.overlay = "map"
		680:
			_shot("10_camp_map")
			slice.map_tab = 1
		683:
			_shot("10a_the_reach")
			slice.map_tab = 2
			slice.weather.forecast("camp")  # asked Aldous: tomorrow's glyph shows
			for d in range(3, 15):
				slice.weather.note("camp", d)  # days lived in an earlier life, in the Almanac
		686:
			_shot("10b_calendar")
			slice.map_tab = 0
			slice.overlay = "ledger"
			slice.ledger_tab = 6
			slice.deeds.earn("first_ring")
		688:
			_shot("10c_deeds")
			# the Field Guide (N-6.5): the fights so far, a weakness found and one kind mastered
			slice.ledger_tab = 7
			var G: Dictionary = FieldGuide.book(run.soul)
			G["hollow"] = {"seen": 1, "beaten": 12, "found": ["burned"]}
			G["shieldman"] = {"seen": 1, "beaten": 2, "found": ["shield_burned"]}
			G["choir"] = {"seen": 1, "beaten": 0, "found": []}
		689:
			_shot("10c1_field_guide")
			slice.ledger_tab = 4
			slice.run.settle_event(slice.run.fixed_events().filter(func(e): return e["id"] == "iron_gate_shuts")[0], "missed")
		691:
			_shot("10d_appointments")
			slice.ledger_tab = 0
			slice.growth.practice()["pebble"].merge({"level": 10, "stage": 1, "xp": 20.0, "hits": 30}, true)  # at the Master wall, one trial short
			slice.growth.practice()["ember_bolt"].merge({"level": 7, "stage": 1}, true)
			slice.book_slot = slice.growth.book().find("pebble")
			slice.overlay = "book"
		692:
			_shot("11_book")
			slice.overlay = ""
			_go(sp["north_in"], 2, 0)
		722:
			_shot("12_north_stair")
			slice.go_map("halls", "landing")
		728:
			_shot("13_loading")
		812:
			_close()
		822:
			_shot("14_halls_landing")
			main.place_player(W.map.spots["hall_c"] + Vector2(0, 120))
		862:
			_shot("15_entrance_hall")
			main.place_player(W.map.items["rune_door"]["at"] + Vector2(-60, 0))
		902:
			_shot("16_rune_door")
			slice.overlay = "map"
		922:
			_shot("17_halls_map")
			slice.overlay = ""
			main.place_player(W.map.spots["hall_s"] if W.map.spots.has("hall_s") else Vector2(1100, 1620))
			main.start_world_cutscene("path:sighting", main.arena.player.pos)
		1002:
			_shot("17a_sighting_still")
		1092:
			_shot("17b_sighting_backwards")
		1162:
			main.mode = "world"
			main.arena.cutscene = null
			main.arena.phase = "explore"
			main.arena.units = main.arena.units.filter(func(u): return u.team != 2)
			main.place_player(W.map.items["great_clock"]["at"] + Vector2(-40, 0))
			main.start_world_cutscene("path:provost_eclipse", main.arena.player.pos)
		1362:
			_shot("17c_provost_replay")
			main.mode = "world"
			main.arena.cutscene = null
			main.arena.phase = "explore"
			main.arena.units = main.arena.units.filter(func(u): return u.team != 2)
			main.place_player(W.map.spots["hall_c"] + Vector2(-260, -40))
			slice._start_fight("hall_fight")
		1502:
			_shot("18_crack_glow")
		1632:
			_shot("19_hall_embers")
			_end_fight()
			_go(W.map.spots["refectory_c"], 2, 0)
		1672:
			_shot("20_refectory")
			_go(W.map.spots["gallery_c"], 2, 0)
		1712:
			_shot("21_gallery_dark")
			_go(W.map.spots["passage_c"] + Vector2(0, 60), 2, 0)
		1752:
			_shot("22_bell_passage")
			_go(W.map.spots["ante_s"] + Vector2(0, -60), 2, 0)
		1792:
			_shot("23_burnt_door")
			_go(W.map.spots["cistern_c"] + Vector2(120, 40), 2, 0)
		1832:
			_shot("24_cistern_sluice")
			_go(W.map.spots["kiln_s"], 2, 0)
			slice._start_fight("warden")
		2142:
			main.arena.player.hp = main.arena.player.max_hp
			_shot("25_warden_rings")
			var w = main.arena.enemies().filter(func(u): return u.kind == "warden")
			if not w.is_empty():
				w[0].hp = w[0].max_hp * 0.5
		2342:
			main.arena.player.hp = main.arena.player.max_hp
			_shot("26_warden_vents")
			_end_fight()
			slice.end_loop("first_playable_end")
		2362:
			_shot("27_end_card")
			run.life["day"] = 2
			slice.set_screen("world")
			slice.go_map("city", "wall_gap")
		2450:
			_close()
		2460:
			_shot("28_city_wall_gap")
			_go(W.map.spots["sunken_square"] + Vector2(-120, 60), 2, 1)
		2500:
			_shot("29_sunken_square")
			_go(W.map.items["lens"]["at"] + Vector2(60, 90), 2, 1)
		2540:
			_shot("30_glassworks")
			_go(W.map.spots["barricade_w"], 2, 2)
		2580:
			_shot("31_bell_street")
			_go(W.map.spots["old_watch"] + Vector2(-80, 20), 2, 3)
		2620:
			_shot("32_old_watch_dusk")
			main.place_player(W.map.spots["drain_top"])
			slice.go_map("undercroft", "drain_stair")
		2710:
			_close()
		2720:
			_shot("33_undercroft_stair")
			_go(W.map.spots["channel"] + Vector2(-120, -140), 2, 1)
		2760:
			_shot("34_undercroft_channel")
			_go(W.map.spots["grate_hall"] + Vector2(40, 40), 2, 1)
		2800:
			_shot("35_grate_hall")
			slice.go_map("fields", "mill_bridge")
		2890:
			_close()
		2900:
			_shot("36_mill_bridge")
			_go(W.map.spots["mill_pond"] + Vector2(-60, 60), 2, 1)
		2940:
			_shot("37_mill_pond")
			_go(W.map.spots["orchard"] + Vector2(0, 80), 2, 2)
		2980:
			_shot("38_orchard")
			_go(W.map.spots["east_fence"], 2, 3)
		3020:
			_shot("39_east_fence_dusk")
			var f := FileAccess.open(out.path_join("stats.txt"), FileAccess.WRITE)
			f.store_string("\n".join(stats) + "\n")
			return true
	return false
