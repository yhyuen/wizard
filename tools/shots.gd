extends SceneTree
## Screenshots of the fight for review (needs a display, not --headless):
##
##   xvfb-run -a -s "-screen 0 1440x810x24" godot --rendering-driver opengl3 --resolution 1440x810 \
##       --fixed-fps 60 --script res://tools/shots.gd -- --out DIR [--at 4,14,30] [--seed 3]
##
## The bot plays loop 1 at practice levels; a shot is saved at each second in --at (shot_<s>.png),
## and one when Silas arrives (shot_duel.png) and a few seconds into the duel (shot_dusk.png).

var main
var bot
var frames := 0
var out := "user://shots"
var at: Array = [4, 12, 24]
var Progression
var _duel_f := -1
var _jump := false  # --duel: skip the waves and go straight to Silas


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
		elif args[i] == "--duel":
			_jump = true
		elif args[i] == "--at":
			at = Array(args[i + 1].split(",")).map(func(s): return int(s))
	DirAccess.make_dir_recursive_absolute(out)
	Progression = root.get_node("Progression")
	Progression.save_enabled = false
	Progression.reset_all()
	bot = load("res://scripts/bot.gd").new()
	main = load("res://scenes/main.tscn").instantiate()
	main.bot = func(a): return bot.intent(a)
	root.add_child.call_deferred(main)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("[shots] ", name)


func _process(_dt: float) -> bool:
	if main == null or main.arena == null:
		return false
	frames += 1
	if frames == 1:
		for id in Progression.data["spells"]:
			Progression.set_level(id, 5)
	var s := frames / 60.0
	if _jump and frames == 90:
		for u in main.arena.enemies():
			main.arena.kill(u)
		main.arena.spawn_queue.clear()
		main.arena.set_phase("duel")
	for t in at:
		if frames == int(t) * 60:
			_shot("shot_%d" % t)
	if main.arena.phase == "duel" and _duel_f < 0:
		_duel_f = frames
	if _duel_f > 0 and frames == _duel_f + 150:
		_shot("shot_duel")
	if _duel_f > 0 and frames == _duel_f + 480:
		_shot("shot_dusk")
		return true
	return s > 240.0
