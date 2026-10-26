extends SceneTree
## The first morning's drill (N-8.4): from the targets' scene, a bot presses the keys a player
## would (staff, both slots, both cantrips, the Ward, Blink, then knocking the straw men down),
## and the drill must end won with every step ticked, set `drill_done`, and move the main line on.
##
##   godot --headless --fixed-fps 60 --script res://tools/tests/drill.gd

var main
var slice
var run
var frames := 0
var bt := 0
var fails: Array = []


func _initialize() -> void:
	run = root.get_node("Run")
	run.save_enabled = false
	root.get_node("Progression").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)


func _close() -> void:
	for i in 40:
		if slice.cur.is_empty():
			break
		if slice.pending.is_empty():
			slice.choose(0)
		else:
			slice.advance()


## One frame of the player's keys: the drill's steps in order, then spells and staff until done.
func _intent(A) -> Dictionary:
	bt += 1
	var en: Array = A.enemies()
	var aim: Vector2 = A.player.pos + Vector2(0, -60)
	if not en.is_empty():
		aim = en[bt / 90 % en.size()].pos
	var seq := [["staff", 0, 2], ["slot1", 20, 70], ["slot2", 90, 140], ["cant1", 160, 162], ["cant2", 180, 182],
		["ward", 200, 260], ["blink", 280, 282]]
	var c := bt
	if bt >= 300:
		c = 300 + (bt - 300) % 120
		seq = [["slot1", 300, 350], ["staff", 360, 362], ["cant1", 370, 372], ["staff", 380, 382], ["slot2", 390, 410]]
	var held := {}
	var pressed := {}
	var released := {}
	for q in seq:
		if c == q[1]:
			pressed[q[0]] = true
		if c >= q[1] and c < q[2]:
			held[q[0]] = true
		if c == q[2]:
			released[q[0]] = true
	var mv := Vector2.ZERO
	if bt >= 300 and not en.is_empty() and A.player.pos.distance_to(aim) > 30.0:
		mv = (aim - A.player.pos).normalized()
	return {"move": mv, "aim": aim, "held": held, "pressed": pressed, "released": released}


func _check(ok: bool, what: String) -> void:
	print("[drill] %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		fails.append(what)


func _process(_dt: float) -> bool:
	if main == null or main.slice == null:
		return false
	slice = main.slice
	frames += 1
	if frames == 5:
		slice.new_month()
	elif frames == 10:
		_close()
		_check(slice.main_line().contains("drill"), "the first step names the drill")
		main.place_player(Vector2(1745, 1080))
		slice.use("targets")
		_check(slice.cur.get("id", "") == "drill", "the targets offer the drill in life 1")
		slice.choose(0)
		_close()
		_check(main.mode == "fight" and slice.drill != null, "the drill starts a fight with its steps")
		main.bot = _intent
	elif frames > 10 and main.mode != "fight" or frames == 2400:
		main.bot = Callable()
		_close()
		_check(main.mode == "world", "the drill ends")
		_check(run.flag("drill_done"), "drill_done is set")
		_check(not slice.main_line().contains("drill"), "the main line moves on")
		_check(int(main.arena.stats.get("damage_taken", 0.0)) == 0, "the straw men never hurt you")
		_check(not run.soul.get("guide", {}).has("straw_man"), "the Field Guide leaves the straw men out")
		print("[drill] %d failed" % fails.size())
		quit(1 if not fails.is_empty() else 0)
	return false
