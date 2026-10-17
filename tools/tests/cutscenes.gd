extends SceneTree
## The story's reverse scenes (scripts/game/cutscene.gd), headless:
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/cutscenes.gd
##
## Each one is played through the story as in the game: it must switch to the fight view with
## the walker on the field, end on its own within its length, and hand back to the same story
## scene. The Mourner is then played again and skipped, which must also hand back.

const PLAN := [["fire", "fire", false], ["mourner", "mourner", false], ["mourner", "mourner", true]]

var main
var slice
var run
var i := -1
var frames := 0
var saw_cut := false
var saw_walker := false
var fails: Array = []


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _process(_dt: float) -> bool:
	if main == null or main.slice == null or main.arena == null:
		return false
	slice = main.slice
	if i < 0:
		slice.new_month()
		slice.fight_resolver = Callable()
		_next()
		return false
	frames += 1
	var cut: Array = PLAN[i]
	if main.mode == "cutscene":
		saw_cut = true
		if main.arena.units.any(func(u): return u.kind == "walker"):
			saw_walker = true
		if cut[2] and frames == 60:
			main.arena.cutscene.t = main.arena.cutscene.LENGTH[cut[1]]  # what Space does
	var limit := 90 if cut[2] else int(main.arena.Cutscene.LENGTH[cut[1]] * 60.0) + 120
	if main.mode == "slice" and saw_cut:
		print("[cutscenes] %s%s: back to the story after %.1f s, on screen %s" % [cut[1], " (skipped)" if cut[2] else "", frames / 60.0, slice.screen])
		if slice.screen != "scene":
			fails.append("%s did not hand back to the story scene" % cut[1])
		if not saw_walker:
			fails.append("%s never put the walker on the field" % cut[1])
		if i + 1 >= PLAN.size():
			return _done()
		_next()
	elif frames > limit:
		fails.append("%s did not end in time (mode %s)" % [cut[1], main.mode])
		return _done()
	return false


func _next() -> void:
	i += 1
	frames = 0
	saw_cut = false
	saw_walker = false
	slice.play(PLAN[i][0])
	if main.mode != "cutscene":
		fails.append("%s did not start its reverse scene" % PLAN[i][0])


func _done() -> bool:
	for f in fails:
		print("[cutscenes] FAIL: " + f)
	if fails.is_empty():
		print("[cutscenes] every reverse scene plays and hands back")
	quit(1 if not fails.is_empty() else 0)
	return true
