extends RefCounted
## Minigames' shared rules (people spec §9.1; build item N-7.6.5): who plays what, free play once
## per opponent a week, work, the first win's rumour pick, tells and answers that carry, playing for
## coin once beaten in a past life (never at dice), easy mode, the bond, and no games in a
## calamity's week. The games themselves are star_charts.gd and sparks.gd; the panel is the slice's.
## What it keeps is the life's (Run.life "games" {who: {week, work}}, "game_firsts" {key: true},
## "crowns") and the soul's (Run.soul "games_beaten" {who: life first beaten}, "tells" {who: life},
## "charts" {riddle: life}).

const StarCharts := preload("res://scripts/game/minigames/star_charts.gd")
const Sparks := preload("res://scripts/game/minigames/sparks.gd")
const GAMES := {"star_charts": "res://data/world/minigames/star_charts.json", "sparks": "res://data/world/minigames/sparks.json"}
const NAMES := {"star_charts": "Star-charts", "sparks": "Sparks"}
const KINDS := [["date", "When"], ["person", "Who"], ["lead", "Where"]]

var run
var bonds
var rumours
var commissions  # for the calamity week (commissions.gd calamity_week)
var d := {}  # game id -> its data


func _init(run_node, bonds_, rumours_, commissions_) -> void:
	run = run_node
	bonds = bonds_
	rumours = rumours_
	commissions = commissions_
	for g in GAMES:
		d[g] = JSON.parse_string(FileAccess.get_file_as_string(GAMES[g]))


## The game `who` plays ("" if none).
func game_of(who: String) -> String:
	for g in d:
		if d[g]["opponents"].has(who):
			return g
	return ""


func opp(who: String) -> Dictionary:
	var g := game_of(who)
	return d[g]["opponents"][who] if g != "" else {}


func _week() -> int:
	return (run.day() - 1) / 7


func _state(who: String) -> Dictionary:
	if not run.life.has("games"):
		run.life["games"] = {}
	if not run.life["games"].has(who):
		run.life["games"][who] = {}
	return run.life["games"][who]


func _calm() -> bool:
	return commissions == null or not commissions.calamity_week()


## Free play: once a week per opponent, not in a calamity's week.
func open(who: String) -> bool:
	return game_of(who) != "" and _calm() and int(_state(who).get("week", -1)) != _week()


## Work: an opponent with a job for you, once a day.
func work_open(who: String) -> bool:
	return opp(who).has("work") and _calm() and int(_state(who).get("work", -1)) != run.day()


## Beaten in an earlier life.
func beaten_before(who: String) -> bool:
	var b: Dictionary = run.soul.get("games_beaten", {})
	return b.has(who) and int(b[who]) < run.loop()


## Playing for coin without playing: beaten in a past life, free play open, and never at dice.
func coin_open(who: String) -> bool:
	return beaten_before(who) and game_of(who) != "sparks" and open(who)


func tell_known(who: String) -> bool:
	return run.soul.get("tells", {}).has(who)


## Starts a match (`mode` free or work): its core, seeded by the life, the day and who.
func start(who: String, mode: String, easy := false) -> RefCounted:
	var g := game_of(who)
	_state(who)["work" if mode == "work" else "week"] = run.day() if mode == "work" else _week()
	var seed_ := hash("%s:%d:%d:%s" % [who, run.loop(), run.day(), mode])
	if g == "star_charts":
		return StarCharts.new(d[g], opp(who), seed_, run.soul.get("charts", {}), easy, tell_known(who))
	return Sparks.new(d[g], opp(who), seed_, easy, tell_known(who))


## A match is over: crowns, the bond, what carries, and for work its wage and a rumour. Returns
## {won, crowns, tell (learned now), heard [rumour ids], pick [kinds a first win may pick from]}.
func finish(who: String, mode: String, won: bool, core = null, region := "camp") -> Dictionary:
	var o := opp(who)
	var out := {"won": won, "crowns": 0, "tell": "", "heard": [], "pick": []}
	var crowns := int(run.life.get("crowns", 0))
	if mode == "work":
		out["crowns"] = int(o["work"]["wage"])
	elif won:
		out["crowns"] = int(o["stake"])
	else:
		out["crowns"] = -mini(int(o["stake"]), crowns)
	run.life["crowns"] = crowns + int(out["crowns"])
	if mode == "coin":
		_state(who)["week"] = _week()  # it takes the week's free play
		return out  # no rumour, no bond
	bonds.gain(who, "minigame_win" if won else "minigame_loss")
	if mode == "work":
		var r: String = rumours.draw(rumours.pool_now(region))
		if r != "" and rumours.hear(r):
			out["heard"].append(r)
	if core != null and game_of(who) == "star_charts":
		if not run.soul.has("charts"):
			run.soul["charts"] = {}
		for id in core.solved:
			if not run.soul["charts"].has(id):
				run.soul["charts"][id] = run.loop()
			var rr := str(d["star_charts"]["riddles"][id].get("rumour", ""))
			if rr != "" and rumours.hear(rr):
				out["heard"].append(rr)
	if won:
		for k in ["games_beaten", "tells"]:
			if not run.soul.has(k):
				run.soul[k] = {}
		if not run.soul["games_beaten"].has(who):
			run.soul["games_beaten"][who] = run.loop()
		if not run.soul["tells"].has(who):
			run.soul["tells"][who] = run.loop()
			out["tell"] = str(o["tell"])
		var key := "%s:%s:%s" % [who, region, run.cal["moons"][run.moon() - 1]["season"]]
		if not run.life.get("game_firsts", {}).has(key):
			if not run.life.has("game_firsts"):
				run.life["game_firsts"] = {}
			run.life["game_firsts"][key] = true
			var pool: String = rumours.pool_now(region)
			for kd in KINDS:
				if rumours.draw(pool, kd[0]) != "":
					out["pick"].append(kd)
	return out


## The first win's pick: hears the most useful unheard rumour of `kind`. Returns its id.
func pick(kind: String, region := "camp") -> String:
	var r: String = rumours.draw(rumours.pool_now(region), kind)
	if r != "":
		rumours.hear(r)
	return r


## Everyone you've beaten, in any life, as [who].
func beaten() -> Array:
	return run.soul.get("games_beaten", {}).keys()


## Every opponent, [who].
func opponents() -> Array:
	var out: Array = []
	for g in d:
		out.append_array(d[g]["opponents"].keys())
	return out
