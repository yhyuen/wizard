extends RefCounted
## Grade gates and the city's other ways through (Ring 1 places spec §8, §9; build item N-7.1.2).
## A door in a map's data can be a gate:
##   `gate`: a prop's tag (its 5th field in the map's props). The door stands open while that prop
##     is broken or burned to ash: Bell Street's barricade (wood: Fire II or Impact II), the lamp
##     depot's shutter (iron: Impact II bends it), the bakery's heap over the cellar hatch. If the
##     owner puts the prop back (owners mend at dawn), the door shuts again.
##   `winch` [x, y] and `grade`: lightning at that grade or more charging the rail cell there runs
##     the winch, and the door opens for the life (the depot shutter's other way).
##   `lens`: the glassworks' great lens. Turn its three mirrors (any Impact turns one a quarter)
##     until each faces the way the map's `lens` names, by day, and the sun through the lens burns
##     the fuse: the glassblower's loft opens for the life. Once you know the fuse is there (a
##     soul memory, `lens.know`), fire on it opens the door at once, in any later life.
## Doors these open stay open for the life; a new life shuts them.
## A map's `shortcuts` (N-7.1.3) open for good instead: the undercroft's drain grate opens when its
## `weight` prop (the counterweight crate) is shoved into the weight's rect, or lightning at `grade`
## charges the chain's rail cell at `winch`. Opening one teaches its soul memory `know`, and the
## exit that names it in `opened_by` works from then on, in this life and every later one.

var W  # scripts/world/world.gd


func _init(world) -> void:
	W = world


func _prop(tag: String) -> Dictionary:
	for p in W.props:
		if str(p.get("tag", "")) == tag:
			return p
	return {}


func _open(did: String, why: String) -> void:
	var dr: Dictionary = W.map.doors[did]
	if dr["open"]:
		return
	dr["open"] = true
	W.events_log.append(["gate", did, why])
	W.arena.fx("dust", (dr["rect"] as Rect2).get_center(), {"r": 24.0, "life": 0.7})


## Every frame: a gate's prop broken or burned opens it; put back, it shuts.
func update() -> void:
	for did in W.map.doors:
		var dr: Dictionary = W.map.doors[did]
		if dr.has("gate"):
			var p := _prop(str(dr["gate"]))
			if p.is_empty():
				continue
			var gone: bool = p["integrity"] == "broken" or p["state"] == "ash"
			if gone and not dr["open"]:
				_open(did, "broke" if p["integrity"] == "broken" else "burned")
			elif not gone and dr["open"] and not dr.get("opened", false):
				dr["open"] = false  # mended by its owner: shut again
	_lens()
	for sid in W.map.d.get("shortcuts", {}):
		var sc: Dictionary = W.map.d["shortcuts"][sid]
		if sc.has("weight") and not W.run.knows(str(sc["know"])):
			var wt: Dictionary = sc["weight"]
			var p := _prop(str(wt["prop"]))
			var r: Array = wt["rect"]
			if not p.is_empty() and Rect2(r[0], r[1], r[2], r[3]).has_point(p["pos"]):
				_shortcut(sc, "weight")


## Lightning filled these cells at `grade`: a gate's winch on one of them runs.
func struck(hit: Dictionary, grade: int) -> void:
	for did in W.map.doors:
		var dr: Dictionary = W.map.doors[did]
		if dr.has("winch") and not dr["open"] and grade >= int(dr.get("grade", 1)):
			var w: Array = dr["winch"]
			if hit.has(W.cells.index(Vector2(w[0], w[1]))):
				dr["opened"] = true
				_open(did, "winch")
				W.arena.fx("zap", Vector2(w[0], w[1]), {"to": (dr["rect"] as Rect2).get_center(), "color": PixelArt.STORM, "life": 0.3, "_w": true})
				W.arena.toast.emit("The winch catches the charge and drags the shutter up.", PixelArt.STORM)
	for sid in W.map.d.get("shortcuts", {}):
		var sc: Dictionary = W.map.d["shortcuts"][sid]
		if sc.has("winch") and grade >= int(sc.get("grade", 1)) and not W.run.knows(str(sc["know"])):
			var w: Array = sc["winch"]
			if hit.has(W.cells.index(Vector2(w[0], w[1]))):
				_shortcut(sc, "winch")


## A shortcut opens for good: you learn it, and its exit works from now on.
func _shortcut(sc: Dictionary, why: String) -> void:
	if not W.run.learn(str(sc["know"])):
		return
	W.events_log.append(["shortcut", str(sc["exit"]), why])
	var at: Rect2 = W.map.exits[str(sc["exit"])]["rect"]
	W.arena.fx("dust", at.get_center(), {"r": 30.0, "life": 0.9})
	W.arena.toast.emit("The chain runs, and with a shriek of rust the grate swings up. The way to the camp is open.", PixelArt.GOLD)


## An Impact on a mirror turns it a quarter round instead of shoving it.
func turn(p: Dictionary) -> String:
	p["turn"] = (int(p.get("turn", 0)) + 1) % 4
	p["rot"] = float(p.get("rot0", p["rot"])) + 90.0 * p["turn"]
	W.events_log.append(["turned", p.get("tag", p["kind"])])
	return "turned"


func _lens() -> void:
	var L: Dictionary = W.map.d.get("lens", {})
	if L.is_empty() or W.map.doors[str(L["door"])]["open"]:
		return
	if W.run.time_id() in ["dusk", "night"]:
		return  # no sun to gather
	for tag in L["mirrors"]:
		if int(_prop(str(tag)).get("turn", -1)) != int(L["mirrors"][tag]):
			return
	_fuse_burns(L, "lens")


func _fuse_burns(L: Dictionary, why: String) -> void:
	var did := str(L["door"])
	W.map.doors[did]["opened"] = true
	_open(did, why)
	var f: Array = L["fuse"]
	W.arena.fx("burst", Vector2(f[0], f[1]), {"color": PixelArt.FIRE, "r": 10.0, "life": 0.4})
	if W.run.learn(str(L["know"])):
		W.arena.toast.emit("The light through the lens finds a fuse in the wall. A hidden door swings open.", PixelArt.GOLD)


## Fire within `r` of `at`: once you know where the fuse is, fire on it opens the loft.
func fire_at(at: Vector2, r: float) -> void:
	var L: Dictionary = W.map.d.get("lens", {})
	if L.is_empty() or W.map.doors[str(L["door"])]["open"] or not W.run.knows(str(L["know"])):
		return
	var f: Array = L["fuse"]
	if at.distance_to(Vector2(f[0], f[1])) <= r + 12.0:
		_fuse_burns(L, "fuse")
