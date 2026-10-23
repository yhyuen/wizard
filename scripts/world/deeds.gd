extends RefCounted
## Owners and witnesses (spells-and-environment spec §7.3, §9; build item N-4.4): what you break
## belongs to someone, and someone may be watching. Every prop has an owner (data/world/owners.json,
## by map and place) and a value in crowns. When you break it or set it burning, anyone who can see
## it reacts by its value: a grumble, a demand to pay, or a call for the watch, each costing
## standing with the owner. Nobody saw? The next person to pass finds it, and you're the only
## caster in the camp. Putting out an owned fire, or mending a thing with Time, earns standing and
## fame. Owners put their things back a few dawns later; nobody mends what nobody owns.
##
## What it keeps is the life's: Run.life "standing" (owner -> points), "owed" (owner -> crowns),
## "fame", "infamy", "suspicion" and "unseen" (damage nobody has found yet), for the reputation
## and the economy to read when they're built.

const OWNERS := "res://data/world/owners.json"

const Seasons := preload("res://scripts/world/seasons.gd")

var W  # scripts/world/world.gd
var d: Dictionary
var _find_t := 0.0


func _init(world) -> void:
	W = world
	d = JSON.parse_string(FileAccess.get_file_as_string(OWNERS))


func owner_of(p: Dictionary) -> String:
	return _owner_on(W.map_id, p)


func owner_name(owner: String) -> String:
	return str(d["owners"].get(owner, {}).get("name", owner))


func value_of(p: Dictionary) -> int:
	return int(d["values"].get(p["kind"], 0))


func _life() -> Dictionary:
	return W.run.life


func _bump(key: String, owner: String, n: int) -> void:
	var t: Dictionary = _life().get(key, {})
	t[owner] = int(t.get(owner, 0)) + n
	_life()[key] = t


func _count(key: String, n := 1) -> void:
	_life()[key] = int(_life().get(key, 0)) + n


func standing(owner: String) -> int:
	return int(_life().get("standing", {}).get(owner, 0))


## How far someone sees a change now: less in the dark (the season's dark times, N-4.5.3), and
## less in mist, rain or snow (the lower of the two; the day's sight is 12 m, weather's `sight_m`;
## N-4.5.2).
func sight() -> float:
	var r := float(d["sight"]["night" if W.dark() else "day"])
	var m := float(W.sky_kind().get("sight_m", 12.0))
	return minf(r, float(d["sight"]["day"]) * m / 12.0)


## The people who can see `at`: in town, close enough, nothing solid between.
func witnesses(at: Vector2) -> Array:
	var r := sight()
	var out: Array = []
	for p in W.people.list:
		if p.on and p.fade < 0.5 and p.pos.distance_to(at) <= r and W.map.clear_line(p.pos, at, 2.0):
			out.append(p)
	out.sort_custom(func(a, b): return a.pos.distance_to(at) < b.pos.distance_to(at))
	return out


func _line(kind: String) -> String:
	var lines: Array = d["lines"][kind]
	return str(lines[W.people.rng.randi() % lines.size()])


## You broke it or set it burning (`how`: "broke", "burned"). Counted once until it's put back.
func damaged(p: Dictionary, how: String) -> void:
	if not p.has("broke_day"):
		p["broke_day"] = W.run.day()  # nature mends the wild too, so even nobody's things are dated
	var owner := owner_of(p)
	if owner == "" or p.get("damaged", false):
		return
	p["damaged"] = true
	var seen := witnesses(p["pos"])
	if seen.is_empty():
		var unseen: Array = _life().get("unseen", [])
		unseen.append({"map": W.map_id, "pos": p["pos"], "owner": owner, "kind": p["kind"]})
		_life()["unseen"] = unseen
		return
	_react(seen[0], owner, value_of(p), how == "burned")


## The reaction ladder (spec §9.3), by what it was worth.
func _react(who, owner: String, value: int, fire: bool) -> void:
	var L: Dictionary = d["ladder"]
	var step := "complain"
	if value > int(L["guards_over"]):
		step = "guards"
	elif value >= int(L["complain_under"]):
		step = "demand"
	var cost := int(L["standing"][step])
	if fire and step != "guards":
		cost = mini(cost, int(L["fire"]))  # fire is worse than a broken crate
	_bump("standing", owner, cost)
	W.events_log.append(["witnessed", owner])
	match step:
		"complain":
			W.people.say(who, _line("complain"))
		"demand":
			_bump("owed", owner, value)
			W.people.say(who, _line("demand") % [value, owner_name(owner)])
		"guards":
			_count("infamy")
			W.people.say(who, _line("guards"))
			W.arena.toast.emit("The watch is called. %s won't forget this." % owner_name(owner).capitalize(), PixelArt.DANGER)


## A good deed (`how`: "doused", "mended") on something someone owns.
func good(p: Dictionary, how: String) -> void:
	var owner := owner_of(p)
	if owner == "":
		return
	if how == "mended":
		var was: bool = p.get("damaged", false)
		p.erase("damaged")
		p.erase("broke_day")
		if not was:
			return
	_bump("standing", owner, int(d["ladder"]["good"]))
	_count("fame")
	W.events_log.append(["good", owner])
	var seen := witnesses(p["pos"])
	if not seen.is_empty():
		W.people.say(seen[0], _line("thanks"))


## Damage nobody saw is found by the next person who sees where it was.
func update(dt: float) -> void:
	_find_t -= dt
	if _find_t > 0.0:
		return
	_find_t = 1.0
	var unseen: Array = _life().get("unseen", [])
	for u in unseen.duplicate():
		if u["map"] != W.map_id:
			continue
		var seen := witnesses(u["pos"])
		if seen.is_empty():
			continue
		unseen.erase(u)
		_bump("standing", str(u["owner"]), int(d["ladder"]["found"]))
		_bump("suspicion", str(u["owner"]), 1)
		W.people.say(seen[0], _line("found"))
		W.events_log.append(["found", u["owner"]])


## Dawn: owners put back what was broken or burned long enough ago, on every map this life;
## nature grows back its plants (seasons.json `regrow` props, by the season; N-4.5.3).
func new_day() -> void:
	var day: int = W.run.day()
	var lists: Array = [[W.map_id, W.props]]
	for id in W._saved:
		lists.append([id, W._saved[id]["props"]])
	var plants: Dictionary = Seasons.data()["regrow"]["props"]
	for pair in lists:
		for p in pair[1]:
			if not p.has("broke_day"):
				continue
			if plants.has(p["kind"]):
				var need: int = Seasons.regrow_days(W.run, int(plants[p["kind"]]))
				if Seasons.regrows_on(pair[0]) and need >= 0 and day - int(p["broke_day"]) >= need:
					W.restore(p)
					p.erase("damaged")
					p.erase("broke_day")
					W.events_log.append(["regrew", p["kind"]])
				continue
			var owner := _owner_on(pair[0], p)
			if owner == "" or not d["owners"].get(owner, {}).get("repairs", false):
				continue
			if day - int(p["broke_day"]) >= int(d["repair_days"].get(p["kind"], 1)):
				W.restore(p)
				p.erase("damaged")
				p.erase("broke_day")
				W.events_log.append(["repaired", p["kind"]])
	# what was never found is forgotten once it's mended
	_life()["unseen"] = (_life().get("unseen", []) as Array).filter(func(u): return W.map_id != u["map"] or not _mended_at(u))


## Who owns a prop on a map: its own `owner`, else its place's, else the map's default.
func _owner_on(map_id: String, p: Dictionary) -> String:
	if p.has("owner"):
		return str(p["owner"])
	var m: Dictionary = d["maps"].get(map_id, {})
	var place: String = W.get_map(map_id).place_at(p["home"])
	if m.get("places", {}).has(place):
		return str(m["places"][place])
	return str(m.get("default", ""))


func _mended_at(u: Dictionary) -> bool:
	for p in W.props:
		if p["pos"].distance_to(u["pos"]) < 2.0 and not p.has("broke_day"):
			return true
	return false
