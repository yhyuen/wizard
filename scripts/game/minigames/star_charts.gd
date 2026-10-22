extends RefCounted
## Star-charts (people spec §9.2; build item N-7.6.5): a riddle race on the night sky, one match
## against one opponent. Pure and seeded, so tests play it alone. Data in
## data/world/minigames/star_charts.json; the frame (games.gd) starts it and keeps what carries.
##
## A riddle's clues come one at a time (stage 1..3). Answer now, or ask for the next clue: if you
## wait past the opponent's buzz, they answer first. A wrong answer gives the riddle away.

var d: Dictionary  # the game's data
var opp: Dictionary  # the opponent's record
var known: Dictionary  # riddle ids answered right in any life (Run.soul "charts")
var easy := false
var tell := false  # the opponent's tell is known (or easy mode)
var rng := RandomNumberGenerator.new()

var order: Array = []  # the match's riddle ids
var opts: Array = []  # each riddle's options, shuffled
var buzz: Array = []  # each riddle's buzz stage
var right: Array = []  # whether the opponent's answer will be right
var i := 0  # the riddle now
var stage := 1  # the clues shown
var you := 0
var them := 0
var struck := -1  # easy mode: the option struck out
var said := ""  # what just happened, for the panel
var solved: Array = []  # riddle ids you answered right in this match


func _init(data: Dictionary, opponent: Dictionary, seed_: int, known_: Dictionary, easy_ := false, tell_ := false) -> void:
	d = data
	opp = opponent
	known = known_
	easy = easy_
	tell = tell_ or easy_
	rng.seed = seed_
	var tiers: Array = opp["tier"].map(func(t): return int(t))
	var pool: Array = d["riddles"].keys().filter(func(id): return int(d["riddles"][id]["tier"]) in tiers)
	pool.sort()
	for n in int(d["rounds"]):
		var k := rng.randi_range(0, pool.size() - 1)
		order.append(pool[k])
		pool.remove_at(k)
		var o: Array = d["riddles"][order[-1]]["options"].duplicate()
		for a in range(o.size() - 1, 0, -1):  # a seeded shuffle
			var b := rng.randi_range(0, a)
			var t = o[a]
			o[a] = o[b]
			o[b] = t
		opts.append(o)
		buzz.append(rng.randi_range(int(opp["buzz"][0]), int(opp["buzz"][1])))
		right.append(rng.randf() < float(opp["sure"]))
	_strike()


func riddle() -> Dictionary:
	return d["riddles"][order[i]] if i < order.size() else {}


func options() -> Array:
	return opts[i] if i < order.size() else []


func clues() -> Array:
	return riddle()["clues"].slice(0, stage) if i < order.size() else []


func over() -> bool:
	return you >= int(d["to_win"]) or them >= int(d["to_win"]) or i >= order.size()


func won() -> bool:
	return you > them


## You've answered this riddle right before, in some life: its answer shows.
func remembered() -> bool:
	return i < order.size() and known.has(order[i])


## The tell: they'll answer if you wait for the next clue.
func sign() -> String:
	return str(opp["sign"]) if tell and not over() and stage >= buzz[i] else ""


func answer(k: int) -> void:
	if over() or k < 0 or k >= options().size() or k == struck:
		return
	var r := riddle()
	if str(options()[k]) == str(r["answer"]):
		you += 1
		solved.append(order[i])
		said = "%s. Yours." % r["answer"]
	else:
		them += 1
		said = "Wrong. %s takes it: %s." % [opp["name"], r["answer"]]
	_next()


## Waits for the next clue; past their buzz, they answer first.
func wait() -> void:
	if over():
		return
	var r := riddle()
	if stage >= buzz[i]:
		if right[i]:
			them += 1
			said = "%s answers first: %s." % [opp["name"], r["answer"]]
		else:
			you += 1
			said = "%s says the wrong thing. It's yours: %s." % [opp["name"], r["answer"]]
		_next()
		return
	stage += 1


func _next() -> void:
	i += 1
	stage = 1
	_strike()


func _strike() -> void:
	struck = -1
	if easy and i < order.size():
		for k in options().size():
			if str(options()[k]) != str(riddle()["answer"]):
				struck = k
				return


## A bot for tests: `skill` 1 answers at the first clue and knows every sky; 0 always waits.
func bot(skill: float) -> bool:
	var n := 0
	while not over() and n < 50:
		n += 1
		if skill >= 1.0 or remembered():
			answer(options().find(riddle()["answer"]))
		else:
			wait()
	return won()
