extends RefCounted
## The matter core (design/world/spells-and-environment-spec.md §1-§4, data/materials.json): the
## one place that says what a force at a grade does to a material. It only answers; the world
## (scripts/world/world.gd `apply_force`) carries the answer out on the prop.

const DATA := "res://data/materials.json"

var d: Dictionary


func _init() -> void:
	d = JSON.parse_string(FileAccess.get_file_as_string(DATA))


func material(id: String) -> Dictionary:
	return d["materials"].get(id, {})


## The grade `force` needs to do its full work on `mat` (0: never; it only ever does the weak
## version). `over` is a prop kind's own `break` and `fire` grades.
func need(force: String, mat: String, over := {}) -> int:
	var m := material(mat)
	match force:
		"impact":
			return int(over.get("break", m.get("break", 0)))
		"fire":
			return int(over.get("fire", m.get("fire", 0)))
		"lightning":
			return 1 if int(m.get("conducts", 0)) > 0 else int(over.get("lightning_fire", m.get("lightning_fire", 0)))
	return 1


## What `force` at `grade` does to `mat`: an op from the results table (§4.1), or its weak version
## below the grade (§4.2: one grade short of breaking cracks, more only dents). "none" if nothing.
func result(force: String, grade: int, mat: String, over := {}) -> String:
	var row: Array = d["results"].get(mat, {}).get(force, [])
	if row.is_empty():
		return "none"
	var n := need(force, mat, over)
	if n > 0 and grade >= n:
		return str(row[0])
	var weak := str(row[1])
	if weak == "crack" and force == "impact" and n > 0 and grade < n - 1:
		return "dent"
	return weak


## What a spell's mark in the world (a projectile, zone or effect `kind`) carries: {force, spell,
## shove}, or {} if it carries nothing.
func carrier(kind: String) -> Dictionary:
	return d["carriers"].get(kind, {})


## The kinds that carry `force` (for the world's own checks: fire on a wall leaves a scorch).
func kinds_of(force: String) -> Array:
	return d["carriers"].keys().filter(func(k): return d["carriers"][k]["force"] == force)


func state_s(state: String) -> float:
	return float(d["states"].get(state, {}).get("s", 0.0))
