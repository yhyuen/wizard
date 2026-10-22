extends RefCounted
## Inheritances' trial rooms (people spec §12; build item N-7.6.8). A map's `trials` names each
## inheritance's rooms, in order; `start(id)` (the story's `inherit <id>`) opens the way into the
## first. Each room tests one idea and runs only while you stand in it; pass it and the way into
## the next opens. Pass them all and the story's reward scene plays. Once you know the inheritance
## (its `know`, a soul memory), a later life opens every room at once and needs only `later` of
## them. A failed room is put back as it was and you try again.
##   `lamps`: light every lamp of the room's group without any of the room's floor burning.
##   `keep`: keep the room's brazier alight `hold_s` seconds; while any of its draught-doors (props
##     tagged `vents`) stands open, a lit fire lasts `gust_s`. Any Impact or a staff strike slams a
##     door shut for `shut_s`.
##   `choke`: a pyre (the room's brazier) throws embers a cell further along the line to the shelf
##     every `every` s, from `first` cells out. An ember landing on a cell with nothing left to burn
##     chokes the pyre; one that reaches the shelf burns it. Water anywhere in the room fails it.
## A life's progress is Run.life.trials {id: [rooms passed]}.

var W  # scripts/world/world.gd
var live := {}  # room id -> what runs in it now: {"gust", "hold", "k", "t", "wait"}


func _init(world) -> void:
	W = world


func _defs() -> Dictionary:
	return W.map.d.get("trials", {})


func passed(id: String) -> Array:
	if not W.run.life.has("trials"):
		W.run.life["trials"] = {}
	if not W.run.life["trials"].has(id):
		W.run.life["trials"][id] = []
	return W.run.life["trials"][id]


func begun(id: String) -> bool:
	return W.run.life.get("trials", {}).has(id)


## How many rooms this life needs: all of them, or `later` once you know the inheritance.
func need(id: String) -> int:
	var T: Dictionary = _defs()[id]
	return int(T.get("later", 1)) if W.run.knows(str(T["know"])) else T["rooms"].size()


## The story's `inherit <id>`: the trials begin, and the way into the first room opens (every room,
## once you know it).
func start(id: String) -> void:
	var T: Dictionary = _defs().get(id, {})
	if T.is_empty() or begun(id):
		return
	passed(id)
	var rooms: Array = T["rooms"]
	for i in rooms.size():
		if i == 0 or W.run.knows(str(T["know"])):
			_open(str(rooms[i]["door"]))
		if rooms[i].has("vents"):
			_vents(rooms[i])


func reset() -> void:
	live.clear()


func _open(did: String) -> void:
	var dr: Dictionary = W.map.doors[did]
	dr["open"] = true
	dr["opened"] = true
	W.arena.fx("dust", (dr["rect"] as Rect2).get_center(), {"r": 18.0, "life": 0.6})


func _rect(room: Dictionary) -> Rect2:
	var r = W.map.places[str(room["place"])]["rect"]
	return r if r is Rect2 else Rect2(r[0], r[1], r[2], r[3])


## Every frame on this map: the room you stand in runs.
func update(dt: float) -> void:
	var defs := _defs()
	for id in defs:
		if not begun(id) or W.run.flag(str(defs[id]["done"])):
			continue
		for room in defs[id]["rooms"]:
			if str(room["id"]) in passed(id):
				continue
			if _rect(room).has_point(W.player_pos()):
				_run(id, room, dt)
	for p in W.props:
		if p.has("shut_t") and p["shut_t"] > 0.0:
			p["shut_t"] = maxf(0.0, p["shut_t"] - dt)
			if p["shut_t"] <= 0.0:
				p["rot"] = float(p["rot0"]) + 70.0  # it bangs open again


func _run(id: String, room: Dictionary, dt: float) -> void:
	var rid := str(room["id"])
	if not live.has(rid):
		live[rid] = {"gust": 0.0, "hold": 0.0, "k": int(room.get("first", 2)), "t": 0.0, "wait": 0.0}
	var L: Dictionary = live[rid]
	if L["wait"] > 0.0:
		L["wait"] -= dt
		return
	match str(room["kind"]):
		"lamps":
			var r := _rect(room)
			if _burnt(r):
				_fail(id, room, "burnt")
				return
			var mine: Array = W.lamps.filter(func(l): return str(l["group"]) == str(room["lamps"]) and r.has_point(l["pos"]))
			if not mine.is_empty() and mine.all(func(l): return l["lit"]):
				_pass(id, room)
		"keep":
			var b: Dictionary = W.braziers[int(room["brazier"])]
			var open := _vents(room).any(func(p): return float(p.get("shut_t", 0.0)) <= 0.0)
			if not b["lit"]:
				L["hold"] = 0.0
				L["gust"] = 0.0
				return
			if open:
				L["gust"] += dt
				if L["gust"] >= float(room["gust_s"]):
					b["lit"] = false
					L["gust"] = 0.0
					L["hold"] = 0.0
					W.events_log.append(["gust", rid])
					W.arena.fx("dust", b["pos"], {"r": 14.0, "life": 0.6})
					W.arena.toast.emit(_line(id, "gust"), PixelArt.DANGER)
				return
			L["gust"] = 0.0
			L["hold"] += dt
			if L["hold"] >= float(room["hold_s"]):
				_pass(id, room)
		"choke":
			_choke(id, room, L, dt)


func _choke(id: String, room: Dictionary, L: Dictionary, dt: float) -> void:
	var pyre: Dictionary = W.braziers[int(room["brazier"])]
	if not pyre["lit"]:
		pyre["lit"] = true
		L["t"] = 0.0
		W.arena.toast.emit(_line(id, "pyre"), PixelArt.FIRE)
	L["t"] += dt
	if L["t"] < float(room["every"]):
		return
	L["t"] = 0.0
	var shelf := _prop(str(room["shelf"]))
	var from: Vector2 = pyre["pos"]
	var to: Vector2 = shelf["pos"]
	var cs: float = W.cells.size
	var at: Vector2 = from + (to - from).normalized() * cs * L["k"]
	W.arena.fx("trail", from + Vector2(0, -6), {"to": at, "color": PixelArt.FIRE, "life": 0.4})
	if at.distance_to(from) >= from.distance_to(to) - cs * 0.5:
		W.ignite(shelf)
		_fail(id, room, "shelf")
		return
	var i: int = W.cells.index(at)
	if W.cells.wet[i] > 0.0:
		_fail(id, room, "water")
		return
	if W.cells.fuel[i] < 0.0:
		_pass(id, room)  # nothing left there to burn: the pyre starves
		pyre["lit"] = false
		W.arena.fx("dust", pyre["pos"], {"r": 14.0, "life": 0.8})
		return
	W.cells.fire(i, 1)
	W._sync_fire_zones()
	L["k"] += 1


## Water anywhere in a running choke room fails it.
func wet(at: Vector2, r: float) -> void:
	var defs := _defs()
	for id in defs:
		if not begun(id):
			continue
		for room in defs[id]["rooms"]:
			if str(room["kind"]) == "choke" and live.has(str(room["id"])) and not str(room["id"]) in passed(id) \
					and _rect(room).grow(r).has_point(at):
				_fail(id, room, "water")


## An Impact or a staff strike on a draught-door slams it shut for a while.
func slam(p: Dictionary) -> String:
	var shut := 45.0
	for id in _defs():
		for room in _defs()[id]["rooms"]:
			if room.has("shut_s") and _rect(room).grow(14.0).has_point(p["home"]):
				shut = float(room["shut_s"])
	p["shut_t"] = shut
	p["rot"] = float(p["rot0"])
	W.events_log.append(["slammed", p.get("tag", p["kind"])])
	W.arena.fx("dust", p["pos"], {"r": 8.0, "life": 0.3})
	return "slammed"


func _vents(room: Dictionary) -> Array:
	var r := _rect(room).grow(14.0)
	var out: Array = W.props.filter(func(p): return str(p.get("tag", "")) == str(room["vents"]) and r.has_point(p["pos"]))
	for p in out:
		if not p.has("shut_t"):
			p["shut_t"] = 0.0  # they start banging open
			p["rot"] = float(p["rot0"]) + 70.0
	return out


## What the room says (the map's `lines`, by what happened).
func _line(id: String, key: String) -> String:
	return str(_defs()[id].get("lines", {}).get(key, ""))


func _prop(tag: String) -> Dictionary:
	for p in W.props:
		if str(p.get("tag", "")) == tag:
			return p
	return {}


func _burnt(r: Rect2) -> bool:
	for i in W.cells.within(r.get_center(), maxf(r.size.x, r.size.y)):
		if r.has_point(W.cells.centre(i)) and (W.cells.burn[i] > 0.0 or W.cells.ash.has(i)):
			return true
	return false


func _pass(id: String, room: Dictionary) -> void:
	var T: Dictionary = _defs()[id]
	passed(id).append(str(room["id"]))
	live.erase(str(room["id"]))
	W.events_log.append(["trial", str(room["id"])])
	var rooms: Array = T["rooms"]
	var at := rooms.find(room)
	if at + 1 < rooms.size():
		_open(str(rooms[at + 1]["door"]))
	if passed(id).size() >= need(id):
		W.run.set_flag(str(T["done"]))
		W.request({"t": "scene", "id": str(T["scene"])})
	else:
		W.arena.toast.emit(_line(id, "next"), PixelArt.GOLD)


## The room goes back as it was: fires out and the floor whole, lamps dark, the shelf mended.
func _fail(id: String, room: Dictionary, why: String) -> void:
	var r := _rect(room)
	for i in W.cells.within(r.get_center(), maxf(r.size.x, r.size.y)):
		if r.has_point(W.cells.centre(i)):
			W.cells.renew(i)
	W._sync_fire_zones()
	for l in W.lamps:
		if r.has_point(l["pos"]):
			l["lit"] = false
			l["by"] = ""
	for b in W.braziers:
		if r.has_point(b["pos"]):
			b["lit"] = false
	for p in W.props:
		if r.grow(14.0).has_point(p["home"]) and not p.has("shut_t"):
			W.restore(p)
	live[str(room["id"])] = {"gust": 0.0, "hold": 0.0, "k": int(room.get("first", 2)), "t": 0.0, "wait": 3.0}
	W.events_log.append(["trial_failed", str(room["id"])])
	W.arena.toast.emit(_line(id, why), PixelArt.DANGER)
