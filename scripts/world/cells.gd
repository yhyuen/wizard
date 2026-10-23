extends RefCounted
## The ground's cell grid (design/world/spells-and-environment-spec.md §5, data/world/ground.json):
## every cell of a map has a material, and fire, water, charge, smoke and steam live on the cells.
## Fire spreads to neighbours with fuel (wind, weather, cloth and oil, a cap on burning cells) and
## leaves ash that can't burn again this life; water wets and puts out; lightning fills a connected
## wet or metal network as far as its grade reaches. Only cells with a timer tick (the active set).
## The world (world.gd) turns what happens here into flames, shocks and burning props.

var size := 24.0
var w := 0
var h := 0
var origin := Vector2.ZERO
var indoors := false
var mats: Array = []  # material ids, by index
var mdef: Array = []  # their data/materials.json entries
var sp: Dictionary  # ground.json "spread"
var mat := PackedByteArray()
var fuel := PackedFloat32Array()  # seconds of burning left in the cell; -1 burnt out (ash)
var burn := PackedFloat32Array()  # > 0 while burning
var wet := PackedFloat32Array()
var charge := PackedFloat32Array()
var smoke := PackedFloat32Array()
var steam := PackedFloat32Array()
var active := {}  # cell index -> true while any timer runs
var ash := {}  # burnt-out cells, for the scar on the ground
var rubble := {}  # cells under a fallen structure (slow to cross; Impact II clears them)
var burning := {}  # cell index -> the order it caught (oldest first burns faster when capped)
var _order := 0
var rng := RandomNumberGenerator.new()
var _gale_t := 0.0

## Weather on the cells (seasons spec §4; set by the world from the day's weather): wind 0-3 and
## the way it blows toward, fire spread ×, and rain (every outdoor cell counts as wet).
var wind := 0
var downwind := Vector2.ZERO
var fire_k := 1.0
var raining := false
var dry_k := 1.0  # Heat: wet dries this many times faster (N-4.5.2)
var freezing := false  # Frost (night to noon) and Snow: standing water and wet ground are ice
var snow := false  # Snow cover outdoors: walking is slower
var melt := {}  # cell index -> seconds a fire's thaw lasts on ice


func _init(map, def: Dictionary, spread: Dictionary, materials: Dictionary) -> void:
	sp = spread
	size = float(def.get("cell", 24.0))
	indoors = bool(def.get("indoors", false))
	for id in materials:
		mats.append(id)
		mdef.append(materials[id])
	origin = map.bounds.position
	w = int(ceil(map.bounds.size.x / size))
	h = int(ceil(map.bounds.size.y / size))
	var n := w * h
	mat.resize(n)
	for arr in [fuel, burn, wet, charge, smoke, steam]:
		arr.resize(n)
		arr.fill(0.0)
	var areas: Array = []  # [Rect2 or [centre, r], material]
	for pr in def.get("places", []):
		var pl: Dictionary = map.places.get(pr[0], {})
		if pl.has("rect"):
			var r: Array = pl["rect"]
			areas.append([Rect2(r[0], r[1], r[2], r[3]), pr[1]])
		elif pl.has("circle"):
			var c: Array = pl["circle"]
			areas.append([[Vector2(c[0], c[1]), float(c[2])], pr[1]])
	for r in def.get("paint", []):
		areas.append([Rect2(r[0], r[1], r[2], r[3]), r[4]])
	var rails: Array = []
	for r in def.get("rails", []):
		# an iron rail a cell wide, from one cell centre to another (the camp's lamp circuits);
		# it stays iron even where it runs under a wall or a shut door (the city's winch)
		rails.append(Rect2(Vector2(r[1], r[2]), Vector2.ZERO).expand(Vector2(r[3], r[4])).grow(size * 0.5 - 1.0))
	var iron := mats.find("iron")
	var dflt := mats.find(str(def.get("default", "earth")))
	var water := mats.find("water")
	var brick := mats.find("brick")
	for i in n:
		var c := centre(i)
		var m := dflt
		for a in areas:
			var shape = a[0]
			var inside: bool = shape.has_point(c) if shape is Rect2 else c.distance_to(shape[0]) <= float(shape[1])
			if inside:
				m = mats.find(str(a[1]))
		if map.in_water(c):
			m = water
		elif map.solid_at(c):
			m = brick
		for rr in rails:
			if rr.has_point(c):
				m = iron
		mat[i] = m
		fuel[i] = float(mdef[m].get("fuel_s", 0.0)) if int(mdef[m].get("fire", 0)) > 0 else 0.0


func centre(i: int) -> Vector2:
	return origin + Vector2((i % w) + 0.5, (i / w) + 0.5) * size


func index(p: Vector2) -> int:
	var x := int(floor((p.x - origin.x) / size))
	var y := int(floor((p.y - origin.y) / size))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


func material_at(p: Vector2) -> String:
	var i := index(p)
	return mats[mat[i]] if i >= 0 else ""


## The cells within `r` of `p` (always the one under `p`).
func within(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c := index(p)
	if c < 0:
		return out
	var k := int(ceil(r / size))
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var x := (c % w) + dx
			var y := (c / w) + dy
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var i := y * w + x
			if i == c or centre(i).distance_to(p) <= r + size * 0.5:
				out.append(i)
	return out


## A structure fell here: the cell is rubble, and whatever was burning on it is smothered.
func make_rubble(i: int) -> void:
	if i < 0 or mats[mat[i]] == "water":
		return
	rubble[i] = true
	if burn[i] > 0.0:
		burn[i] = 0.0
		burning.erase(i)


## Tar thrown on cell `i` (the Tar Pot): it is oil now, catches at Fire I and burns long.
func tar(i: int) -> bool:
	if i < 0 or burn[i] > 0.0 or mats[mat[i]] == "water":
		return false
	var o := mats.find("oil")
	mat[i] = o
	fuel[i] = float(mdef[o].get("fuel_s", 0.0))
	wet[i] = 0.0
	return true


func is_wet(i: int) -> bool:
	return wet[i] > 0.0 or (raining and not indoors) or mats[mat[i]] == "water"


func conducts(i: int) -> bool:
	return (is_wet(i) and not is_ice(i)) or int(mdef[mat[i]].get("conducts", 0)) > 0


## Frozen (N-4.5.2): on a freezing day outdoors, standing water and wet ground are ice. Ice doesn't
## conduct or burn; fire on it thaws it to water for `melt_s`.
func is_ice(i: int) -> bool:
	return freezing and not indoors and not melt.has(i) and (wet[i] > 0.0 or mats[mat[i]] == "water")


# --- forces on cells -----------------------------------------------------------------

## Fire at `grade` on cell `i`: it catches if it has fuel and the grade, isn't wet and the map
## isn't at its cap; on a wet cell the water steams off. Returns "burn", "steam" or "none".
func fire(i: int, grade: int) -> String:
	if i >= 0 and is_ice(i):
		melt[i] = float(sp.get("melt_s", 20.0))  # it thaws: water now, for a while
		steam[i] = float(sp["steam_s"])
		active[i] = true
		return "thaw"
	if i < 0 or burn[i] > 0.0 or fuel[i] <= 0.0:
		return "none"
	if is_wet(i):
		if wet[i] > 0.0:
			wet[i] = 0.0
			steam[i] = float(sp["steam_s"])
			active[i] = true
			return "steam"
		return "none"
	if grade < int(mdef[mat[i]].get("fire", 0)) or burning.size() >= int(sp["max_burning"]):
		return "none"
	burn[i] = fuel[i]
	_order += 1
	burning[i] = _order
	active[i] = true
	return "burn"


## Water on cell `i`: puts out a fire (it steams) and wets the cell.
func douse(i: int) -> bool:
	if i < 0:
		return false
	var was := burn[i] > 0.0
	if was:
		fuel[i] = burn[i]  # what hadn't burnt yet can burn again once it dries
		burn[i] = 0.0
		burning.erase(i)
		steam[i] = float(sp["steam_s"])
	wet[i] = float(sp["wet_s"])
	active[i] = true
	return was


## Cell `i` as the map made it: no fire, water, charge or ash, its fuel whole (a trial room put
## back, N-7.6.8).
func renew(i: int) -> void:
	if i < 0:
		return
	burn[i] = 0.0
	burning.erase(i)
	ash.erase(i)
	wet[i] = 0.0
	charge[i] = 0.0
	fuel[i] = float(mdef[mat[i]].get("fuel_s", 0.0)) if int(mdef[mat[i]].get("fire", 0)) > 0 else 0.0


## A held fire on cell `i` (Cinder Lattice, N-7.6.8): what can burn there burns out at once, with no
## spreading, and a fire already there is spent. Returns true if anything burned.
func burn_out(i: int) -> bool:
	if i < 0 or (fuel[i] <= 0.0 and burn[i] <= 0.0):
		return false
	burn[i] = 0.0
	burning.erase(i)
	fuel[i] = -1.0
	ash[i] = true
	wet[i] = 0.0
	smoke[i] = float(sp["smoke_s"])
	active[i] = true
	return true


## A lightning strike on cell `i` at `grade` (spec §5.3): a conductor fills its connected
## network breadth-first as far as the grade reaches (capped); cloth and grass catch fire at
## their lightning grade. Returns the charged cells.
func strike(i: int, grade: int) -> Array:
	if i < 0:
		return []
	if not conducts(i):
		var lf := int(mdef[mat[i]].get("lightning_fire", 0))
		if lf > 0 and grade >= lf:
			fire(i, 99)
		return []
	var reach: float = float(sp["reach"][clampi(grade, 1, sp["reach"].size()) - 1])
	var start := centre(i)
	var seen := {i: true}
	var queue: Array = [i]
	var out: Array = []
	while not queue.is_empty() and out.size() < int(sp["network_cap"]):
		var c: int = queue.pop_front()
		out.append(c)
		charge[c] = float(sp["charge_s"])
		active[c] = true
		for nb in _neighbours4(c):
			if not seen.has(nb) and conducts(nb) and centre(nb).distance_to(start) <= reach:
				seen[nb] = true
				queue.append(nb)
	return out


func _neighbours4(i: int) -> Array:
	var x := i % w
	var y := i / w
	var out: Array = []
	if x > 0: out.append(i - 1)
	if x < w - 1: out.append(i + 1)
	if y > 0: out.append(i - w)
	if y < h - 1: out.append(i + w)
	return out


# --- time ---------------------------------------------------------------------------

## Runs the active cells for `dt` (call at about 4 Hz). Returns what changed for the world:
## {"lit": [cells that caught], "out": [cells whose fire ended], "ash": [burnt out]}.
func tick(dt: float) -> Dictionary:
	var lit: Array = []
	var out: Array = []
	var burnt: Array = []
	var over: bool = burning.size() >= int(sp["max_burning"])
	for i in active.keys():
		if burn[i] > 0.0:
			if raining and not indoors:
				douse(i)  # rain puts a fire out
				out.append(i)
				continue
			burn[i] -= dt * (2.0 if over else 1.0)
			_spread(i, dt, lit)
			if burn[i] <= 0.0:
				burn[i] = 0.0
				fuel[i] = -1.0
				burning.erase(i)
				ash[i] = true
				smoke[i] = float(sp["smoke_s"])
				out.append(i)
				burnt.append(i)
		for arr in [charge, smoke, steam]:
			if arr[i] > 0.0:
				arr[i] = maxf(0.0, arr[i] - dt)
		if wet[i] > 0.0:
			wet[i] = maxf(0.0, wet[i] - dt * dry_k)  # Heat dries it faster
		if melt.has(i):
			melt[i] -= dt
			if melt[i] <= 0.0:
				melt.erase(i)
		if burn[i] <= 0.0 and wet[i] <= 0.0 and charge[i] <= 0.0 and smoke[i] <= 0.0 and steam[i] <= 0.0 and not melt.has(i):
			active.erase(i)
	# A gale throws an ember from a fire downwind now and then (spec §5.1).
	if wind >= 3 and not burning.is_empty():
		_gale_t += dt
		if _gale_t >= float(sp["gale_every"]):
			_gale_t = 0.0
			var from: int = burning.keys()[rng.randi() % burning.size()]
			var to := index(centre(from) + downwind * size * float(sp["gale_cells"]))
			if fire(to, 1) == "burn":
				lit.append(to)
	return {"lit": lit, "out": out, "ash": burnt}


func _spread(i: int, dt: float, lit: Array) -> void:
	var x := i % w
	var y := i / w
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j: int = ny * w + nx
			if fuel[j] <= 0.0 or burn[j] > 0.0 or is_wet(j):
				continue
			var p: float = float(sp["base"]) * fire_k * (0.7 if dx != 0 and dy != 0 else 1.0)
			if wind > 0:
				var d := Vector2(dx, dy).normalized().dot(downwind)
				p *= pow(float(sp["downwind"]), d) if d >= 0.0 else pow(float(sp["upwind"]), -d)
			if mats[mat[j]] in sp["fast"]:
				p *= float(sp["into_fast"])
			if rng.randf() < p * dt and fire(j, 1) == "burn":  # a spreading fire is grade I
				lit.append(j)
