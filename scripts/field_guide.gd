extends RefCounted
## The Field Guide (enemy spec §12.1; build item N-6.5): what you know about each kind of foe. It is
## knowledge, so it lives in the soul and survives every life (Run.soul "guide": kind ->
## {seen, beaten, found}). A kind is Seen when it comes into a fight, Beaten when killed or it yields,
## its weakness Found when you do one of its answers to it (data/enemies.json `answers`), and
## Mastered once beaten `guide.master_n` times with its weakness found. The Ledger's Guide tab
## shows it; achievements count it.

const KINDS := "res://data/enemies.json"

static var _data := {}

var A  # the arena


func _init(arena) -> void:
	A = arena


## The enemy records (kinds and the guide's rules), read once. Static, so the story's conditions
## can count the Guide without the autoloads.
static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(KINDS))
	return _data


static func book(soul: Dictionary) -> Dictionary:
	if not soul.has("guide"):
		soul["guide"] = {}
	return soul["guide"]


## Mastered: beaten often enough, with its weakness found (if it has one).
static func mastered(soul: Dictionary, kind: String) -> bool:
	var g := book(soul)
	if not g.has(kind):
		return false
	var e: Dictionary = g[kind]
	var has_answers: bool = not (data()["kinds"].get(kind, {}).get("answers", []) as Array).is_empty()
	return int(e["beaten"]) >= int(data()["guide"]["master_n"]) and (not has_answers or not (e["found"] as Array).is_empty())


## How many kinds have their weakness found, and how many are mastered (for achievements).
static func found_count(soul: Dictionary) -> int:
	var n := 0
	for k in book(soul):
		if not (book(soul)[k]["found"] as Array).is_empty():
			n += 1
	return n


static func mastered_count(soul: Dictionary) -> int:
	var n := 0
	for k in book(soul):
		if mastered(soul, k):
			n += 1
	return n


func _soul() -> Dictionary:
	return A.get_node("/root/Run").soul


## Whether the Guide lists this kind (the drill's straw men, `guide: false`, aren't foes).
static func listed(kind: String) -> bool:
	return bool(data()["kinds"].get(kind, {}).get("guide", true))


func entry(kind: String) -> Dictionary:
	var g := book(_soul())
	if not g.has(kind):
		g[kind] = {"seen": 0, "beaten": 0, "found": []}
	return g[kind]


func seen(u: Unit) -> void:
	if not listed(u.kind):
		return
	var e := entry(u.kind)
	if int(e["seen"]) == 0:
		e["seen"] = A.get_node("/root/Run").loop()


func beaten(u: Unit) -> void:
	if not listed(u.kind):
		return
	var e := entry(u.kind)
	e["beaten"] = int(e["beaten"]) + 1
	if u.flags.get("flooded", false):
		found(u, "flooded")


## You did one of its answers to it: the first time, the Guide notes the weakness and says so.
func found(u: Unit, answer: String) -> void:
	var k: Dictionary = A.D["enemies"][u.kind]
	if not answer in k.get("answers", []):
		return
	var e := entry(u.kind)
	if answer in e["found"]:
		return
	e["found"].append(answer)
	A.stats["guide_found"] = int(A.stats.get("guide_found", 0)) + 1
	A.toast.emit("Field Guide · %s: %s" % [str(k["name"]), str(k.get("lesson", ""))], PixelArt.GOLD)
