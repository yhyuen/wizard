extends RefCounted
## Morale (enemy spec §6.5; build item N-6.4): people give up, Hollows and constructs never do.
## A unit of a faction that yields (data/enemies.json "morale") gives up at `yield_at` of its HP
## once its leader is down or `half_out` of its side is out of the fight. Minions run off the field;
## the rest kneel, out of the fight: spells pass them by and the fight can be won around them. Win,
## and the ones who knelt are spared, counted for the life by faction (Run.life "spared") for the
## reputation to read (powers spec; not built yet).

var A  # the arena
var seen := {}  # faction -> how many of its people came into this fight
var out := {}  # faction -> how many are dead, kneeling or fled
var leader_down := {}  # faction -> true once its leader is dead or kneels


func _init(arena) -> void:
	A = arena


func reset() -> void:
	seen = {}
	out = {}
	leader_down = {}


func _M() -> Dictionary:
	return A.D["foes"]["morale"]


func _faction(u: Unit) -> String:
	return str(A.D["enemies"][u.kind].get("faction", ""))


func yields(u: Unit) -> bool:
	return _faction(u) in _M()["factions"]


func on_spawn(u: Unit) -> void:
	var f := _faction(u)
	seen[f] = int(seen.get(f, 0)) + 1


## A unit left the fight (killed, knelt or fled).
func on_out(u: Unit) -> void:
	if u.flags.get("out", false):
		return
	u.flags["out"] = true
	var f := _faction(u)
	out[f] = int(out.get(f, 0)) + 1
	if A.D["enemies"][u.kind].get("leader", false) and not leader_down.get(f, false):
		leader_down[f] = true
		if yields(u) and A.phase == "enc":
			A.toast.emit("%s is down. The rest lose heart." % A.D["enemies"][u.kind]["name"], PixelArt.GOLD)


## Checked every step for a unit still fighting: true if it gave up this step.
func check(u: Unit) -> bool:
	if not yields(u) or u.flags.has("yielded") or u.flags.has("fleeing"):
		return false
	var f := _faction(u)
	var M := _M()
	var shaken: bool = leader_down.get(f, false) or int(out.get(f, 0)) >= ceili(int(seen.get(f, 1)) * float(M["half_out"]))
	if not shaken or u.hp > u.max_hp * float(M["yield_at"]):
		return false
	A.cancel_zones(u.id)
	u.state = "move"
	if str(A.D["enemies"][u.kind].get("tier", "")) == "minion":
		u.flags["fleeing"] = float(M["flee_s"])
		A.stats["fled"] = int(A.stats.get("fled", 0)) + 1
	else:
		u.flags["yielded"] = true
		u.team = 2  # out of the fight: not an enemy any more, not yet a friend
		A.fx("ring", u.pos, {"color": PixelArt.PAPER, "r": u.radius + 8.0, "life": 0.5})
		A.stats["yielded"] = int(A.stats.get("yielded", 0)) + 1
		Progression.add_wizard_xp(float(A.D["enemies"][u.kind]["xp"]))
		if not A.stats.has("yield_seen"):
			A.stats["yield_seen"] = true
			A.toast.emit("The %s yields: weapon down, on one knee." % A.D["enemies"][u.kind]["name"], PixelArt.PAPER)
	on_out(u)
	return true


## A fleeing unit runs from you, and is gone when its time is up.
func flee(u: Unit, dt: float) -> void:
	u.flags["fleeing"] = float(u.flags["fleeing"]) - dt
	A.ai._step(u, u.pos - A.player.pos, dt, 1.2)
	if u.flags["fleeing"] <= 0.0:
		u.team = 2
		u.dead = true
		u.death_t = 0.0  # gone from the field, not killed
		A.fx("dust", u.pos, {"r": 8.0, "life": 0.4})


## The fight is over: a win spares everyone who knelt.
func settle(won: bool) -> void:
	if not won:
		return
	var spared: Dictionary = Run.life.get("spared", {})
	for u in A.units:
		if u.flags.has("yielded") and not u.dead:
			var f := _faction(u)
			spared[f] = int(spared.get(f, 0)) + 1
	Run.life["spared"] = spared
