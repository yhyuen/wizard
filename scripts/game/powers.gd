extends RefCounted
## The powers (powers spec §3-4; build item N-7.3.3): standing with each, and rank and merit in your
## road's power. Data in data/world/powers.json. Everything here is the life's: standing bumps
## (Run.life "standing", shared with deeds.gd), "power_rank" and "merit" reset at the Turning.

const PATH := "res://data/world/powers.json"

var run
var growth
var d: Dictionary


func _init(run_node, growth_node) -> void:
	run = run_node
	growth = growth_node
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


## The power your road joins you to this life ("" before a road, or none for it).
func power() -> String:
	for id in d["powers"]:
		if str(d["powers"][id].get("road", "")) == run.road() and run.road() != "":
			return id
	return ""


func power_name(id: String) -> String:
	return str(d["powers"].get(id, {}).get("name", id))


## Standing with `id`: the first morning's politics (your road's power at road_start), then every
## bump this life, held to -100..100.
func standing(id: String) -> int:
	var start := int(d["powers"].get(id, {}).get("start", 0))
	if id == power():
		start = int(d["road_start"])
	return clampi(start + int(run.life.get("standing", {}).get(id, 0)), -100, 100)


func tier(id: String) -> String:
	var name := ""
	for t in d["tiers"]:
		if standing(id) >= int(t["from"]):
			name = str(t["name"])
	return name


func add_standing(id: String, n: int) -> void:
	var t: Dictionary = run.life.get("standing", {})
	t[id] = int(t.get(id, 0)) + n
	run.life["standing"] = t


## Your rank in power `id`: -1 if you aren't a member, 0 Initiate from taking its road.
func rank(id: String) -> int:
	if id == "" or id != power():
		return -1
	return int(run.life.get("power_rank", 0))


func rank_name(r: int) -> String:
	return str(d["ranks"][clampi(r, 0, d["ranks"].size() - 1)]["name"]) if r >= 0 else ""


func merit() -> int:
	return int(run.life.get("merit", 0))


## Merit is earned only as a member (§4.3).
func add_merit(n: int) -> void:
	if power() != "":
		run.life["merit"] = merit() + n


## What rank `r` in your power still needs, as short lines ("" for each row met). Empty: ready.
func missing(r: int) -> Array:
	var out: Array = []
	if r <= 0 or r >= d["ranks"].size() or power() == "":
		return ["no rank to take"] if r != 0 else []
	var row: Dictionary = d["ranks"][r]
	var id := power()
	if standing(id) < int(row["standing"]):
		out.append("standing %d with %s (now %d)" % [int(row["standing"]), power_name(id), standing(id)])
	if growth.ring() < int(row["ring"]):
		out.append("the %s" % growth.ring_name(int(row["ring"])))
	var school := str(d["powers"][id].get("school", ""))
	var known: Array = growth.known_models().filter(func(s): return str(growth.prog.spell(s).get("school", "")) == school)
	if known.size() < int(row["spells"]):
		out.append("%d spells of your school (you know %d)" % [int(row["spells"]), known.size()])
	var st: Array = row["staged"]
	var pr: Dictionary = growth.practice()
	var staged := known.filter(func(s): return int(pr.get(s, {}).get("stage", 0)) >= int(st[1])).size()
	if staged < int(st[0]):
		out.append("%d of them at %s" % [int(st[0]), growth.prog.stage_name(int(st[1]))])
	if merit() < int(row["merit"]):
		out.append("%d merit (you have %d)" % [int(row["merit"]), merit()])
	return out


## An examination in power `id` (§4.5): the next rank, if its rows are met. Returns true on a rank.
func examine(id: String) -> bool:
	var r := rank(id)
	if r < 0 or not missing(r + 1).is_empty():
		return false
	run.life["power_rank"] = r + 1
	return true
