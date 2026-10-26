extends RefCounted
## First-time tips (N-8.4, data/world/tips.json): queued by what the player does, shown one at a
## time in the first life, each once per soul (`soul.hints`, shared with slice.gd's HINTS).

var d: Dictionary
var run  # the Run autoload
var on := true  # the 'tips' setting (main.gd)
var queue: Array = []
var cur := ""
var t := 0.0  # seconds the current tip has been on screen


func _init(r) -> void:
	run = r
	d = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/tips.json"))


func seen(id: String) -> bool:
	return run.loop() > 1 or run.soul.get("hints", {}).has(id)


## Asks for tip `id`; it waits in the queue until its place (world or fight) comes up.
func want(id: String) -> void:
	if not on or not d["tips"].has(id) or seen(id) or id == cur or id in queue:
		return
	queue.append(id)


## The tip for a place the wizard walked into, if any.
func want_place(place: String) -> void:
	if d["places"].has(place):
		want(str(d["places"][place]))


## Advances the shown tip by `dt` while `where` ("world", "fight" or "") is where the player is.
## Returns the tip to draw now, or "".
func tick(dt: float, where: String) -> String:
	if not on or where == "":
		return ""
	if cur != "" and d["tips"][cur]["where"] != where:
		cur = ""  # its moment passed (a fight ended): it shows again next time
	if cur == "":
		for id in queue:
			if d["tips"][id]["where"] == where:
				cur = id
				t = 0.0
				queue.erase(id)
				break
	if cur == "":
		return ""
	t += dt
	if t > float(d["tips"][cur]["s"]):
		if not run.soul.has("hints"):
			run.soul["hints"] = {}
		run.soul["hints"][cur] = true
		cur = ""
		return ""
	return cur


## Tip `id`'s text with the keys of the current control scheme.
func text(id: String, controls) -> String:
	return keyed(d["tips"][id]["text"], controls)


## `s` with {move} {staff} {slot1} {slot2} {cant1} {cant2} {ward} {blink} as the scheme's keys.
static func keyed(s: String, controls) -> String:
	var lol: bool = controls.league()
	var keys := {
		"move": "Right-click" if lol else "WASD",
		"staff": "A (or right-click a foe)" if lol else "LMB",
		"slot1": "Q", "slot2": "W" if lol else "E",
		"cant1": "D" if lol else "1", "cant2": "F" if lol else "2",
		"ward": "Hold C" if lol else "Hold RMB", "blink": "Space"}
	for k in keys:
		s = s.replace("{%s}" % k, keys[k])
	return s
