extends RefCounted
## The camp's dueling ladder (people spec §7.1; build item N-7.6.4): six rungs, one duelist each,
## each showing a school's style. Challenge the rung above yours at Dusk, once a week; win and you
## hold it and take its purse, lose and you're bruised (no days lost). What it keeps is the life's
## (Run.life "rung", "ladder_day", "crowns") and the soul's (Run.soul "ladder_books" {rung: life
## first beaten}: the duelist's book). Data in data/world/ladders/camp.json.

const PATH := "res://data/world/ladders/camp.json"

var run
var d: Dictionary


func _init(run_node) -> void:
	run = run_node
	d = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func size() -> int:
	return d["rungs"].size()


## The rung you hold this life (0 none, 6 champion).
func rung() -> int:
	return int(run.life.get("rung", 0))


## Rung `n` (1 = the bottom).
func rec(n: int) -> Dictionary:
	return d["rungs"][n - 1] if n >= 1 and n <= size() else {}


## You may challenge the rung above: one isn't the top, and a week has passed since the last bout.
func open() -> bool:
	return rung() < size() and (not run.life.has("ladder_day") or run.day() - int(run.life["ladder_day"]) >= int(d["every"]))


## A bout begins: the week starts again.
func bout() -> void:
	run.life["ladder_day"] = run.day()


## Won the bout for the rung above: hold it, take its purse, and learn its book for every life.
## Returns the purse.
func win() -> int:
	var n := rung() + 1
	if n > size():
		return 0
	run.life["rung"] = n
	var purse := int(rec(n)["purse"])
	run.life["crowns"] = int(run.life.get("crowns", 0)) + purse
	if not run.soul.has("ladder_books"):
		run.soul["ladder_books"] = {}
	if not run.soul["ladder_books"].has(str(n)):
		run.soul["ladder_books"][str(n)] = run.loop()
	return purse


## Rung `n`'s duelist was beaten in an earlier life: you know their book.
func book_known(n: int) -> bool:
	var b: Dictionary = run.soul.get("ladder_books", {})
	return b.has(str(n)) and int(b[str(n)]) < run.loop()


## Every book you hold (beaten in any life), [{n, name, book}].
func books() -> Array:
	var out: Array = []
	var b: Dictionary = run.soul.get("ladder_books", {})
	for n in range(1, size() + 1):
		if b.has(str(n)):
			out.append({"n": n, "name": rec(n)["name"], "book": rec(n)["book"]})
	return out
