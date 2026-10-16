class_name PixelArt
extends RefCounted
## Hand-placed pixel sprites, written as character grids and baked into textures once.
## One colour per element (design doc §4.2): fire is orange, earth is ochre, the rival's storm is cyan.

const PAL := {
	"k": "1b1420", "n": "2a2230",
	"h": "5a3a28", "H": "7a5236",
	"s": "e0a882", "p": "ece4d4",
	"c": "3e4a7a", "C": "5a6aa8",
	"g": "f0c05a", "w": "8f6a40",
	"o": "f08a3c", "y": "ffd36b", "R": "c8402e",
	"e": "c8964e", "E": "7d5a2e",
	"b": "b89a64", "B": "8a7046",
	"r": "e04a3a",
	"t": "8fe8ff", "T": "3a8aa8",
	"d": "4a4652", "D": "6e6878",
	"G": "5c7a3a", "v": "a3c46a",
}

const FIRE := Color("f08a3c")
const FIRE_HOT := Color("ffd36b")
const EARTH := Color("c8964e")
const EARTH_DARK := Color("7d5a2e")
const STORM := Color("8fe8ff")
const WATER := Color("4f86e8")
const WATER_DEEP := Color("2a4fa8")
const STEEL := Color("9aa3b5")
const STONE := Color("6f6a78")
const DANGER := Color("e04a3a")
const HOURS := Color("ffb347")  # Saturn's inner ray: time, and anything inverted
const GOLD := Color("f0c05a")
const INK := Color("1b1420")
const PAPER := Color("ece4d4")

const WIZARD := [
	"....kkkk....",
	"...kHHHHk...",
	"...kHggHk...",
	".kkkkkkkkkk.",
	"kHHHHHHHHHHk",
	"..ksnssnsk..",
	"..kssssssk..",
	"..kkccccckw.",
	".kcCCggCCckw",
	".kcCCgCCCckw",
	".kscCgCCcskw",
	"..kcCgCCckkw",
	"..kccgcccck.",
	"..kccccccck.",
	"...knk.knk..",
	"...kkk.kkk..",
]
const WIZARD_STEP := [
	"..knk...knk.",
	"..kkk...kkk.",
]

const HOLLOW := [
	"....kkkk....",
	"...kbbbbk...",
	"..kbrbbrbk..",
	"..kbbBBbbk..",
	"..kbBkkBbk..",
	"...kbbbbk...",
	".kkkhhhhkkk.",
	"kBkhHhhHhkBk",
	"kbkhhHHhhkbk",
	"...khhhhk...",
	"...kHhhHk...",
	"...kk..kk...",
	"...kB..Bk...",
	"...kk..kk...",
]
const HOLLOW_STEP := [
	"..kB....Bk..",
	"..kk....kk..",
]

const RIVAL := [
	"....kkkk....",
	"....kddk....",
	"....kddk....",
	"...kkttkk...",
	".kkkkkkkkkk.",
	"kddddddddddk",
	".kkpppppkk..",
	"..kptpptpk..",
	"..kppnnppk..",
	".kkdddddkkT.",
	"kDdDttDdDkT.",
	"kDdDdtDdDkT.",
	"kpdDdtDdDpT.",
	".kdDdtDdDkT.",
	".kdDdddDDdk.",
	".kdddddddddk",
	"...knk.knk..",
	"...kkk.kkk..",
]
const RIVAL_STEP := [
	"..knk...knk.",
	"..kkk...kkk.",
]

const LODESTONE := [
	".kkkk.",
	"keeEek",
	"keEeek",
	"kEeeEk",
	"keeEEk",
	".kkkk.",
]

const EMBER := [
	"..o...",
	".oyo..",
	".oyoo.",
	"oyyyo.",
	"oyyyyo",
	".oooo.",
]
const EMBER_B := [
	"...o..",
	"..oyo.",
	".ooyo.",
	".oyyyo",
	"oyyyyo",
	".oooo.",
]

static var _cache := {}


static func tex(name: String, rows: Array, recolor := {}) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var w: int = rows[0].length()
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			ch = recolor.get(ch, ch)
			img.set_pixel(x, y, Color(PAL[ch]))
	var t := ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


## A sprite with its walk frame: the step rows replace the last two rows.
static func frames(name: String, rows: Array, step: Array, recolor := {}) -> Array:
	var walk := rows.duplicate()
	walk[walk.size() - 2] = step[0]
	walk[walk.size() - 1] = step[1]
	return [tex(name, rows, recolor), tex(name + "_step", walk, recolor)]


## A white silhouette of a sprite, for the hit flash.
static func flash(name: String, rows: Array) -> ImageTexture:
	var key := name + "_flash"
	if _cache.has(key):
		return _cache[key]
	var white := {}
	for ch in PAL:
		white[ch] = "p"
	return tex(key, rows, white)


## The Mill yard: packed dirt, grass at the edges, a split-rail fence and the old mill.
static func ground(w: int, h: int, bounds: Rect2) -> ImageTexture:
	if _cache.has("ground"):
		return _cache["ground"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1873
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dirt := [Color("6b5a43"), Color("66553f"), Color("70604a"), Color("62513c")]
	var grass := [Color("4e6b34"), Color("56753a"), Color("4a6430"), Color("5c7a3a")]
	for y in h:
		for x in w:
			var inside := bounds.grow(-2).has_point(Vector2(x, y))
			var edge := minf(minf(x - bounds.position.x, bounds.end.x - x), minf(y - bounds.position.y, bounds.end.y - y))
			var c: Color
			if not inside or edge < rng.randf_range(2, 9):
				c = grass[rng.randi() % 4]
			else:
				c = dirt[rng.randi() % 4]
			img.set_pixel(x, y, c)
	# Pebbles and wheel ruts in the dirt.
	for i in 260:
		var px := rng.randi_range(int(bounds.position.x) + 8, int(bounds.end.x) - 8)
		var py := rng.randi_range(int(bounds.position.y) + 8, int(bounds.end.y) - 8)
		img.set_pixel(px, py, Color("8a7a60") if rng.randf() < 0.5 else Color("4f4232"))
	for x in range(int(bounds.position.x) + 20, int(bounds.end.x) - 20):
		for ry in [bounds.position.y + 150, bounds.position.y + 158]:
			if rng.randf() < 0.8:
				img.set_pixel(x, int(ry + sin(x * 0.03) * 3), Color("57483a"))
	# Grass tufts outside the fence.
	for i in 400:
		var gx := rng.randi_range(0, w - 1)
		var gy := rng.randi_range(0, h - 1)
		if not bounds.has_point(Vector2(gx, gy)):
			img.set_pixel(gx, gy, Color("7d9a4a"))
	# The fence: posts and two rails.
	var fence := Color("8f6a40")
	var fence_dark := Color("5a3a28")
	var r := bounds.grow(1)
	for x in range(int(r.position.x), int(r.end.x) + 1):
		for yy in [r.position.y - 3, r.position.y, r.end.y - 1, r.end.y + 2]:
			img.set_pixel(x, int(yy), fence if int(yy) % 2 == 0 else fence_dark)
	for y in range(int(r.position.y) - 3, int(r.end.y) + 3):
		for xx in [r.position.x - 1, r.position.x + 1, r.end.x - 1, r.end.x + 1]:
			img.set_pixel(int(xx), y, fence if y % 2 == 0 else fence_dark)
	for x in range(int(r.position.x), int(r.end.x) + 1, 24):
		for yy in [r.position.y, r.end.y]:
			for d in range(-5, 4):
				img.set_pixel(x, clampi(int(yy) + d, 0, h - 1), fence_dark)
	# The old mill, top left, outside the fence.
	var mill := Rect2i(2, 0, 40, 26)
	for y in range(mill.position.y, mill.end.y):
		for x in range(mill.position.x, mill.end.x):
			var plank := Color("6e4e34") if (x / 4) % 2 == 0 else Color("7a5a3c")
			if y < 8:
				plank = Color("4a3a40") if (x + y) % 3 else Color("3a2e34")
			img.set_pixel(x, y, plank)
	for y in range(14, 26):
		for x in range(18, 26):
			img.set_pixel(x, y, Color("2a2230"))
	var t := ImageTexture.create_from_image(img)
	_cache["ground"] = t
	return t
