extends RefCounted
## The camp's people (data/world/people.json; design/ruins/content.md §1): who stands where at
## each time of day, walking the street graph between their spots, barking a line now and then,
## and turning to face you when you come close. Mira walks the lane at dusk lighting its lamps;
## anyone can be given a `seek` override to come up to you and start talking. Nobody follows you
## down into the ruin: off the camp map everyone is away.
##
## Purely the camp's state: the world view draws it, the game starts the conversations.

const Story := preload("res://scripts/game/story.gd")

class Person:
	var id := ""
	var def: Dictionary
	var figure := ""
	var name := ""
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO  # as Unit.prev_pos
	var path := PackedVector2Array()
	var spot := "-"  # the spot being walked to; "" when off the map
	var on := false  # in town now
	var fade := 1.0  # 0 seen .. 1 gone (the view fades figures in and out)
	var face := Vector2.DOWN
	var moving := false
	var talking := false
	var bark := ""
	var bark_t := 0.0  # seconds the bark has been up
	var bark_cool := 0.0
	var flinch_t := 0.0  # seconds before this person flinches from a spell again
	var mode := ""  # "", "seek", "lamps", "wander"
	var seek_scene := ""
	var state := ""  # the mode's own step
	var state_t := 0.0
	var crowd := false
	var home := Vector2.ZERO  # where a wanderer wanders round
	var area := Rect2()

	func shown_pos() -> Vector2:
		return Unit.smooth(prev_pos, pos)

var W  # scripts/world/world.gd
var d: Dictionary
var list: Array = []  # Person
var by_id := {}
var rng := RandomNumberGenerator.new()
var _think := 0.0  # seconds to the next schedule check
var _scold_t := 0.0  # seconds before the captain scolds fire again


func _init(world) -> void:
	W = world
	d = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/people.json"))
	rng.seed = 11
	for id in d["people"]:
		var p := Person.new()
		p.id = id
		p.def = d["people"][id]
		p.figure = str(p.def["figure"])
		p.name = str(p.def["name"])
		list.append(p)
		by_id[id] = p
	var c: Dictionary = d["crowd"]
	var most := 0
	for t in c["count"]:
		most = maxi(most, int(c["count"][t]))
	for i in most:
		var p := Person.new()
		p.id = "crowd%d" % i
		p.figure = str(c["figures"][i % c["figures"].size()])
		p.name = "A passer-by"
		p.crowd = true
		var a: Array = c["areas"][i % c["areas"].size()]
		p.area = Rect2(a[0], a[1], a[2], a[3])
		list.append(p)


func get_person(id: String) -> Person:
	return by_id.get(id)


## A new day: everyone starts at the spot for this time of day.
func reset_day() -> void:
	for p in list:
		p.spot = "-"
		p.on = false
		p.fade = 1.0
		p.path = PackedVector2Array()
		p.mode = ""
		p.state = ""
		p.bark = ""
		p.talking = false
	_think = 0.0
	think(true)


# --- schedules --------------------------------------------------------------------

func _holds(rule: Dictionary) -> bool:
	if rule.has("days") and not W.run.day() in Story.parse_days(str(rule["days"])):
		return false
	if rule.has("times") and not W.run.time_id() in Story.parse_times(str(rule["times"])):
		return false
	return W.story.test(str(rule.get("when", "")))


## Where `p` should be now: {"spot", "seek"}.
func want(p: Person) -> Dictionary:
	if not W.in_camp() or p.def.has("from_day") and W.run.day() < int(p.def["from_day"]):
		return {"spot": ""}
	for o in p.def.get("overrides", []):
		if _holds(o):
			return {"spot": str(o["spot"]), "seek": str(o.get("seek", ""))}
	return {"spot": str(p.def["schedule"].get(W.run.time_id(), ""))}


## Re-reads every schedule (each second, and at once when the time of day changes). `snap`
## puts everyone straight at their spots, as at dawn.
func think(snap := false) -> void:
	var count := int(d["crowd"]["count"].get(W.run.time_id(), 0)) if W.in_camp() else 0
	var crowd_i := 0
	for p in list:
		if p.crowd:
			var on := crowd_i < count
			crowd_i += 1
			if on and not p.on:
				p.on = true
				p.mode = "wander"
				p.pos = _wander_point(p)
				p.path = PackedVector2Array()
				p.fade = 1.0 if not snap else 0.0
			elif not on and p.on:
				p.on = false
			continue
		var w := want(p)
		if p.talking:
			continue
		if w["spot"] == "lamp_round":
			if p.mode != "lamps":
				_go(p, "lamp_round", snap)
				p.mode = "lamps"
				p.state = "0"
			continue
		if w["spot"] != p.spot:
			_go(p, w["spot"], snap)
			p.mode = ""
			if w.get("seek", "") != "" and not W.run.seen(w["seek"]):
				p.mode = "seek"
				p.seek_scene = w["seek"]
		if p.id == "dog" and p.on and p.mode == "":
			p.mode = "wander"
			p.home = p.pos
			p.area = Rect2(p.home - Vector2(60, 50), Vector2(120, 100))


func _go(p: Person, spot: String, snap: bool) -> void:
	p.spot = spot
	if spot == "":
		p.on = false
		p.path = PackedVector2Array()
		return
	var at: Vector2 = _spot_pos(spot)
	var far: bool = not p.on or p.pos.distance_to(W.player_pos()) > 420.0
	if snap or far:
		# Nobody sees them walk: they are simply there.
		p.pos = at
		p.path = PackedVector2Array()
		if not p.on:
			p.fade = 1.0 if not snap else 0.0
		p.on = true
		return
	p.on = true
	p.path = W.map.path(p.pos, at, 4.0)


func _spot_pos(spot: String) -> Vector2:
	if spot == "lamp_round":
		var lane: Array = W.lamps.filter(func(l): return l["group"] == "lane")
		return lane[0]["pos"] + Vector2(10, 0) if not lane.is_empty() else W.map.spots["mira_door"]
	return W.map.spots.get(spot, W.map.bounds.get_center())


func _wander_point(p: Person) -> Vector2:
	for i in 8:
		var q := Vector2(rng.randf_range(p.area.position.x, p.area.end.x), rng.randf_range(p.area.position.y, p.area.end.y))
		if not W.map.solid_at(q, 8.0):
			return q
	return p.area.get_center()


# --- every tick -------------------------------------------------------------------

func update(dt: float) -> void:
	_think -= dt
	if _think <= 0.0:
		_think = 1.0
		think()
	var player: Vector2 = W.player_pos()
	var speed := float(W.cfg["walk_speed"])
	_scold_t = maxf(0.0, _scold_t - dt)
	for p in list:
		p.flinch_t = maxf(0.0, p.flinch_t - dt)
		p.fade = move_toward(p.fade, 0.0 if p.on else 1.0, dt * 1.5)
		p.moving = false
		if not p.on:
			continue
		if p.talking:
			p.face = player - p.pos
			continue
		match p.mode:
			"lamps":
				_lamps(p, dt, speed)
			"seek":
				_seek(p, dt, speed)
			"wander":
				if p.path.is_empty():
					p.state_t -= dt
					if p.state_t <= 0.0:
						p.path = PackedVector2Array([_wander_point(p)])
						p.state_t = rng.randf_range(1.5, 5.0)
		_walk(p, dt, speed * (0.7 if p.crowd else 1.0))
		if not p.moving and player.distance_to(p.pos) < 70.0:
			p.face = player - p.pos
		_barks(p, dt, player)


func _walk(p: Person, dt: float, speed: float) -> void:
	if p.path.is_empty():
		return
	var to: Vector2 = p.path[0] - p.pos
	var step := speed * dt
	if to.length() <= step:
		p.pos = p.path[0]
		p.path.remove_at(0)
	else:
		p.pos += to / to.length() * step
		p.face = to
	p.moving = true


## Mira's round at dusk: to each lamp on the lane in turn; it comes on as she reaches it.
func _lamps(p: Person, dt: float, speed: float) -> void:
	var lane: Array = W.lamps.filter(func(l): return l["group"] == "lane")
	var i := int(p.state)
	if i >= lane.size():
		if p.spot != "mira_door":
			_go(p, "mira_door", false)
		return
	var stand: Vector2 = lane[i]["pos"] + Vector2(12, 4)
	if p.path.is_empty() and p.pos.distance_to(stand) > 3.0:
		p.path = W.map.path(p.pos, stand, 4.0)
	if p.pos.distance_to(stand) <= 3.0:
		p.face = lane[i]["pos"] - p.pos
		p.state_t += dt
		if p.state_t > 1.4:
			W.light_lamp(lane[i], "mira")
			p.state = str(i + 1)
			p.state_t = 0.0


## Someone with a `seek` override: comes up to the wizard and starts talking.
func _seek(p: Person, _dt: float, _speed: float) -> void:
	var player: Vector2 = W.player_pos()
	if W.run.seen(p.seek_scene):
		p.mode = ""
		return
	var d := p.pos.distance_to(player)
	if d < float(W.cfg["seek_range"]) and W.map.clear_line(p.pos, player, 4.0):
		p.path = PackedVector2Array([player])
		if d < 26.0 and W.can_start():
			p.path = PackedVector2Array()
			W.request({"t": "talk", "id": p.id, "scene": p.seek_scene})


func _barks(p: Person, dt: float, player: Vector2) -> void:
	if p.bark != "":
		p.bark_t += dt
		if p.bark_t > float(W.cfg["bark_life"]):
			p.bark = ""
	p.bark_cool -= dt
	if p.bark_cool > 0.0 or p.pos.distance_to(player) > float(W.cfg["bark_range"]):
		return
	var ev: Array = W.cfg["bark_every"]
	p.bark_cool = rng.randf_range(ev[0], ev[1])
	var lines: Array = []
	if p.crowd:
		lines = d["crowd"]["barks"]
	else:
		for b in p.def.get("barks", []):
			if _holds(b):
				lines.append(b["text"])
	if not lines.is_empty():
		p.bark = str(lines[rng.randi() % lines.size()])
		p.bark_t = 0.0


# --- reacting to magic (OW2) --------------------------------------------------------

## A line over someone's head now, ahead of their usual barks.
func say(p: Person, text: String) -> void:
	p.bark = text
	p.bark_t = 0.0
	p.bark_cool = maxf(p.bark_cool, float(W.cfg["bark_life"]) + 1.0)


## A spell went off at `at`: anyone close flinches back a step and complains.
func flinch(at: Vector2) -> void:
	var R: Dictionary = d["reactions"]
	var r := float(R["flinch_r"])
	for p in list:
		if not p.on or p.talking or p.flinch_t > 0.0 or p.pos.distance_to(at) > r:
			continue
		p.flinch_t = float(R["flinch_cool"])
		var away: Vector2 = (p.pos - at).normalized() if p.pos.distance_to(at) > 0.1 else Vector2.DOWN
		p.pos = W.map.collide(p.pos + away * float(R["flinch_step"]), 4.0)
		p.face = -away
		var lines: Array = R["flinch"] if p.crowd else p.def.get("flinch", R["flinch"])
		say(p, str(lines[rng.randi() % lines.size()]))
		W.events_log.append(["flinch", p.id])


## Fire flying in the College ruins at `at`: the watch captain, if near enough to see it, has words.
func scold_fire(at: Vector2) -> void:
	var p: Person = by_id.get("captain")
	if p == null or not p.on or _scold_t > 0.0 or p.pos.distance_to(at) > float(W.cfg["bark_range"]):
		return
	_scold_t = float(d["reactions"]["scold_cool"])
	p.face = W.player_pos() - p.pos
	say(p, str(d["reactions"]["captain_fire"]))
	W.events_log.append(["scold", "captain"])


## Everyone you could talk to: in town, not the crowd's nameless passers-by.
func talkable() -> Array:
	return list.filter(func(p): return p.on and p.fade < 0.5 and not p.crowd and not p.def.get("talk_none", false))
