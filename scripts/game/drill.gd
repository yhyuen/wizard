extends RefCounted
## The first morning's drill (N-8.4, encounter `drill`, data/world/story/tutorial.story): a list of
## steps ticked off from the fight's own counts (arena.stats, the kit), shown beside the fight by
## slice.gd. When every step is done the fight ends won.

const Tips := preload("res://scripts/game/tips.gd")
const WARD_S := 0.6  # seconds the Ward must be held
const DOWNS := 3  # straw men knocked down

var ward_t := 0.0
var done := {}  # step id -> true


## [id, text with {keys} and {name}, the slot it uses ("" for none)]
const STEPS := [
	["staff", "{staff}: swing your staff", ""],
	["slot1", "Hold {slot1}, aim, let go: {name}", "slot1"],
	["slot2", "Hold {slot2}, aim, let go: {name}", "slot2"],
	["cant1", "{cant1}: {name}, a quick cantrip", "cant1"],
	["cant2", "{cant2}: {name}", "cant2"],
	["ward", "{ward} for a moment: your Ward", ""],
	["blink", "{blink}: Blink", ""],
	["spar", "Knock the straw men down (3)", ""],
]


## Updates the steps from the fight; true once all are done.
func update(dt: float, arena) -> bool:
	var st: Dictionary = arena.stats
	var kit = arena.kit
	if kit.warding:
		ward_t += dt
	for s in STEPS:
		var id: String = s[0]
		if done.has(id):
			continue
		var spell: String = kit.slot_spell(s[2]) if s[2] != "" else ""
		var ok := false
		match id:
			"staff":
				ok = int(st.get("staff", 0)) > 0
			"slot1", "slot2":
				ok = spell == "" or int(st["by_spell"].get(spell, 0)) > 0
			"cant1", "cant2":
				ok = spell == "" or int(st.get("by_cantrip", {}).get(spell, 0)) > 0
			"ward":
				ok = ward_t >= WARD_S
			"blink":
				ok = int(st.get("blinks", 0)) > 0
			"spar":
				ok = int(st.get("downs", 0)) >= DOWNS
		if ok:
			done[id] = true
	return done.size() == STEPS.size()


## The steps to draw: [text, done].
func lines(arena, controls) -> Array:
	var out: Array = []
	for s in STEPS:
		var t: String = s[1]
		if s[2] != "":
			var spell: String = arena.kit.slot_spell(s[2])
			var nm := ""
			if spell != "":
				nm = str(arena.kit.cantrip(spell)["name"]) if arena.kit.is_cantrip(spell) else str(Progression.spell(spell)["name"])
			t = t.replace("{name}", nm if nm != "" else "(empty slot)")
		out.append([Tips.keyed(t, controls), done.has(s[0])])
	return out
