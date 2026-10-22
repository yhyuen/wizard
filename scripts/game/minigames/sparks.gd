extends RefCounted
## Sparks, the Lamplighters' dice (people spec §9.2; build item N-7.6.5): liar's dice, you against
## one player. Pure and seeded, so tests play it alone. Data in data/world/minigames/sparks.json;
## the frame (games.gd) starts it and keeps what carries.
##
## A bid is [count, face] across both cups; ones (lamps) count as any face but are bid as
## themselves. Raise (more dice, or as many on a higher face) or call dark: the cups open, and
## whoever was wrong loses a die. Out of dice, out of the game.

var d: Dictionary
var opp: Dictionary
var easy := false
var tell := false  # the opponent's tell is known (or easy mode)
var rng := RandomNumberGenerator.new()

var mine: Array = []  # your dice this round
var theirs: Array = []
var n_mine := 0  # dice left
var n_theirs := 0
var bid: Array = []  # [count, face], or [] at the round's start
var by_you := false  # whose bid it is
var phase := "you"  # you (your move), reveal (the cups are open), over
var bluffing := false  # their last bid is past what they hold
var said := ""
var you_lost := false  # who lost the last die: they bid first next round
var log_lines: Array = []


func _init(data: Dictionary, opponent: Dictionary, seed_: int, easy_ := false, tell_ := false) -> void:
	d = data
	opp = opponent
	easy = easy_
	tell = tell_ or easy_
	rng.seed = seed_
	n_mine = int(d["dice"])
	n_theirs = n_mine
	_roll()


func _roll() -> void:
	mine = []
	theirs = []
	for k in n_mine:
		mine.append(rng.randi_range(1, 6))
	for k in n_theirs:
		theirs.append(rng.randi_range(1, 6))
	mine.sort()
	bid = []
	bluffing = false


func over() -> bool:
	return n_mine == 0 or n_theirs == 0


func won() -> bool:
	return n_theirs == 0


## How many dice of `face` across `cup` (lamps count, unless the face is lamps).
static func count(cup: Array, face: int) -> int:
	return cup.filter(func(v): return v == face or (v == 1 and face != 1)).size()


func legal(n: int, f: int) -> bool:
	if n < 1 or f < 1 or f > 6 or n > n_mine + n_theirs:
		return false
	return bid.is_empty() or n > int(bid[0]) or (n == int(bid[0]) and f > int(bid[1]))


## The fewest dice you may bid on `face` now.
func min_on(f: int) -> int:
	if bid.is_empty():
		return 1
	return int(bid[0]) if f > int(bid[1]) else int(bid[0]) + 1


func sign() -> String:
	return str(opp["sign"]) if tell and bluffing and phase == "you" else ""


## Your bid; the opponent answers at once.
func raise_to(n: int, f: int) -> void:
	if phase != "you" or not legal(n, f):
		return
	bid = [n, f]
	by_you = true
	said = "You bid %s." % bid_name(n, f)
	_their_turn()


## You call dark on their bid.
func call_dark() -> void:
	if phase != "you" or bid.is_empty() or by_you:
		return
	_open(true)


## After the reveal: the next round (the loser of the last bids first; their bid is made at once).
func next_round() -> void:
	if phase != "reveal":
		return
	_roll()
	phase = "you"
	said = ""
	if not you_lost:
		_their_turn()


static func bid_name(n: int, f: int) -> String:
	var faces := ["", "lamps", "2s", "3s", "4s", "5s", "6s"]
	return "%d %s" % [n, faces[f]]


## What the opponent expects of `face` from their cup and your dice unseen.
func _expect(cup: Array, unseen: int, f: int) -> float:
	return count(cup, f) + unseen * (1.0 / 6.0 if f == 1 else 1.0 / 3.0)


func _their_turn() -> void:
	var nerve := float(opp["nerve"])
	if not bid.is_empty() and float(bid[0]) > _expect(theirs, n_mine, int(bid[1])) + nerve:
		_open(false)
		return
	# the best bid they can make: the face they hold most of, the fewest dice that raise
	var best_f := 6
	var best_v := -99.0
	for f in range(1, 7):
		var v := _expect(theirs, n_mine, f) - float(min_on(f))
		if v > best_v:
			best_v = v
			best_f = f
	var f := best_f
	if rng.randf() < float(opp["bluff"]):
		f = rng.randi_range(2, 6)  # a face they may not hold
	var n := min_on(f)
	if not legal(n, f):
		_open(false)
		return
	bid = [n, f]
	by_you = false
	bluffing = float(n) > count(theirs, f) + n_mine * (1.0 / 6.0 if f == 1 else 1.0 / 3.0) + 0.5
	said += ("  " if said != "" else "") + "%s bids %s." % [opp["name"], bid_name(n, f)]
	phase = "you"


## The cups open: `you_called` is whether you called dark.
func _open(you_called: bool) -> void:
	var have := count(mine, int(bid[1])) + count(theirs, int(bid[1]))
	var holds := have >= int(bid[0])
	# the caller loses when the bid holds; the bidder when it doesn't
	var you_lose := holds == you_called
	var who := "You call dark." if you_called else "%s calls dark." % opp["name"]
	you_lost = you_lose
	if you_lose:
		n_mine -= 1
	else:
		n_theirs -= 1
	said = "%s %d on the table. %s" % [who, have, "You lose a die." if you_lose else "%s loses a die." % opp["name"]]
	log_lines.append(said)
	phase = "over" if over() else "reveal"


## A bot for tests: plays the opponent's own rule with `nerve`.
func bot(nerve: float) -> bool:
	var n := 0
	while not over() and n < 200:
		n += 1
		if phase == "reveal":
			next_round()
			continue
		if not bid.is_empty() and not by_you and float(bid[0]) > _expect(mine, n_theirs, int(bid[1])) + nerve:
			call_dark()
			continue
		var best_f := 6
		var best_v := -99.0
		for f in range(1, 7):
			var v := _expect(mine, n_theirs, f) - float(min_on(f))
			if v > best_v:
				best_v = v
				best_f = f
		if legal(min_on(best_f), best_f):
			raise_to(min_on(best_f), best_f)
		elif not by_you and not bid.is_empty():
			call_dark()
		else:
			break
	return won()
