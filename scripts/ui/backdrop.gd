extends RefCounted
## Painted backdrops for the slice's places, in the Moody night style (GDD 06.3): a dark sky for
## the time of day, the moon at today's phase, black silhouettes, lamps and spells as the only
## warm light, and slow mist. Drawn with plain polygons each frame onto the slice's Control, so
## there are no image files. design/slice/systems.md §6.

const INK := Color(0.012, 0.018, 0.04)
const INK2 := Color(0.03, 0.045, 0.085)
const LAMP := Color("ffb347")
const MOON := Color("dfe4f2")
const SHARD := Color("ffcf6a")

## Sky colours, top and horizon, for Morning, Noon, Afternoon, Dusk and Night. The College sits
## under a month-long overcast, so even noon is dim.
const SKY := [
	[Color(0.05, 0.08, 0.16), Color(0.24, 0.22, 0.3)],
	[Color(0.09, 0.12, 0.19), Color(0.25, 0.27, 0.32)],
	[Color(0.07, 0.09, 0.17), Color(0.28, 0.22, 0.26)],
	[Color(0.05, 0.05, 0.13), Color(0.4, 0.2, 0.18)],
	[Color(0.015, 0.02, 0.06), Color(0.06, 0.08, 0.15)],
]

var c: CanvasItem


## Paints place `id` (a key of data/slice/places.json, or "" for open sky) at time of day `ti`
## on `day`, `t` seconds into the scene.
func paint(canvas: CanvasItem, id: String, ti: int, day: int, t: float) -> void:
	c = canvas
	var indoor := id in ["room", "archive"]
	if indoor:
		_interior(id, ti, day, t)
	else:
		_sky(ti)
		_stars(ti, t)
		_moon(Vector2(800, 110), day, ti)
		match id:
			"yard":
				_yard(t)
			"observatory":
				_observatory(t)
			"north_door":
				_north_door(ti, t)
			"gate":
				_gate(t)
			"market":
				_market(t)
			"square":
				_square(t)
			"lane":
				_lane(t)
			"mill":
				_mill(t)
			"road":
				_road(t)
			_:
				_city_line(430.0, 0)
		_mist(ti, t)
	# Darken the edges so the panels on top read.
	for i in 6:
		c.draw_rect(Rect2(0, 540 - i * 14, 960, 14), Color(0, 0, 0, 0.05 * (6 - i)))


# --- pieces -------------------------------------------------------------------------

func _sky(ti: int) -> void:
	var top: Color = SKY[ti][0]
	var bot: Color = SKY[ti][1]
	var n := 18
	for i in n:
		var k := float(i) / (n - 1)
		c.draw_rect(Rect2(0, i * 30, 960, 31), top.lerp(bot, k * k))


func _stars(ti: int, t: float) -> void:
	if ti < 3:
		return
	var a := 0.35 if ti == 3 else 0.8
	for i in 70:
		var x := fmod(i * 137.508 * 3.1, 960.0)
		var y := fmod(i * 71.3 * 1.7, 300.0)
		var tw := 0.6 + 0.4 * sin(t * 1.3 + i)
		c.draw_circle(Vector2(x, y), 0.8 + fmod(i * 0.37, 1.0), Color(MOON, a * tw * (1.0 - y / 340.0)))


## The moon at day `day`'s phase, with a soft halo; hidden behind the overcast at noon.
func _moon(at: Vector2, day: int, ti: int) -> void:
	if ti == 1:
		return
	var a := 0.45 if ti < 3 else 1.0
	glow(at, 70.0, Color(MOON, 0.08 * a))
	c.draw_circle(at, 22.0, Color(MOON, 0.9 * a))
	var i := (day - 1) % 28
	var dx := -44.0 * i / 14.0 if i <= 14 else 44.0 * (28 - i) / 14.0
	if absf(dx) < 44.0:
		c.draw_circle(at + Vector2(dx, 0), 22.5, SKY[ti][0].lerp(SKY[ti][1], 0.15))


## A warm light: concentric circles fading out.
func glow(at: Vector2, r: float, col: Color) -> void:
	for i in 8:
		var k := 1.0 - i / 8.0
		c.draw_circle(at, r * k, Color(col, col.a * 0.35))


func lamp(at: Vector2, t: float, r := 46.0) -> void:
	var fl := 0.85 + 0.15 * sin(t * 7.0 + at.x) * sin(t * 3.1 + at.y)
	glow(at, r * fl, Color(LAMP, 0.25))
	c.draw_circle(at, 3.0, Color(LAMP, 0.95))


func poly(pts: Array, col := INK) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)


## Slow bands of mist across the ground; thicker at dusk and night.
func _mist(ti: int, t: float) -> void:
	var a := 0.05 if ti < 3 else 0.09
	for i in 5:
		var y := 400.0 + i * 26.0
		var x := fmod(t * (6.0 + i * 2.0) + i * 190.0, 1300.0) - 300.0
		for k in 4:
			c.draw_rect(Rect2(x - k * 60.0, y - k * 3.0, 520 + k * 120.0, 10 + k * 6.0), Color(0.75, 0.8, 0.9, a / (k + 1)))


## Rooftops along the horizon at height `y`, seeded by `seed`.
func _city_line(y: float, seed: int, col := INK2) -> void:
	var pts: Array = [Vector2(0, 540), Vector2(0, y)]
	var x := 0.0
	var i := seed
	while x < 960.0:
		var w := 40.0 + fmod(i * 37.0, 50.0)
		var h := 20.0 + fmod(i * 53.0, 60.0)
		pts.append(Vector2(x, y - h))
		if i % 3 == 0:
			pts.append(Vector2(x + w * 0.5, y - h - 26.0))  # a gable
		pts.append(Vector2(x + w, y - h))
		x += w
		i += 1
	pts.append(Vector2(960, y))
	pts.append(Vector2(960, 540))
	poly(pts, col)


func _ground(y: float, col := INK) -> void:
	c.draw_rect(Rect2(0, y, 960, 540 - y), col)


# --- the College ---------------------------------------------------------------------

func _college_skyline() -> void:
	# Spires, the long hall and the Observatory dome on the hill.
	poly([Vector2(0, 540), Vector2(0, 330), Vector2(120, 330), Vector2(120, 260), Vector2(140, 200), Vector2(160, 260),
		Vector2(160, 320), Vector2(380, 320), Vector2(380, 280), Vector2(420, 240), Vector2(460, 280), Vector2(460, 320),
		Vector2(620, 320), Vector2(620, 230), Vector2(640, 170), Vector2(660, 230), Vector2(660, 330), Vector2(960, 330),
		Vector2(960, 540)], INK2)
	c.draw_circle(Vector2(420, 250), 26.0, INK2)


func _yard(t: float) -> void:
	_college_skyline()
	_ground(380.0)
	# The cracked practice wall and straw targets.
	c.draw_rect(Rect2(0, 330, 960, 50), Color(0.04, 0.05, 0.09))
	for x in [210.0, 520.0, 760.0]:
		c.draw_line(Vector2(x, 420), Vector2(x, 360), Color(0.1, 0.09, 0.08), 3.0)
		c.draw_circle(Vector2(x, 352), 16.0, Color(0.12, 0.1, 0.07))
		c.draw_arc(Vector2(x, 352), 9.0, 0, TAU, 16, Color(0.2, 0.17, 0.1), 1.0)
	# Chalk circles on the flagstones.
	for k in 3:
		_ellipse(Vector2(380 + k * 140, 470), 52.0, 12.0, Color(0.85, 0.85, 0.8, 0.12))
	lamp(Vector2(90, 300), t)
	lamp(Vector2(880, 300), t)


func _observatory(t: float) -> void:
	_ground(400.0)
	# The hill and the dome, slit open to the sky, the burnt door below.
	poly([Vector2(0, 420), Vector2(240, 360), Vector2(720, 360), Vector2(960, 420), Vector2(960, 540), Vector2(0, 540)], INK2)
	c.draw_rect(Rect2(360, 250, 240, 120), INK)
	c.draw_circle(Vector2(480, 250), 120.0, INK)
	c.draw_rect(Rect2(250, 250, 460, 4), Color(0.08, 0.09, 0.14))
	poly([Vector2(466, 130), Vector2(494, 130), Vector2(500, 250), Vector2(460, 250)], Color(0.07, 0.09, 0.18))
	c.draw_line(Vector2(480, 200), Vector2(560, 120), Color(0.1, 0.1, 0.13), 6.0)  # the telescope
	c.draw_rect(Rect2(456, 320, 48, 50), Color(0.02, 0.02, 0.03))
	glow(Vector2(480, 345), 30.0, Color("ff7a3a", 0.08))  # the scorch still warm
	lamp(Vector2(330, 330), t, 36.0)


func _north_door(ti: int, t: float) -> void:
	_ground(420.0)
	c.draw_rect(Rect2(0, 120, 960, 300), Color(0.03, 0.04, 0.075))  # the wall fills the view
	for row in 10:
		var y := 130.0 + row * 29.0
		c.draw_line(Vector2(0, y), Vector2(960, y), Color(0, 0, 0, 0.35), 1.0)
	# The arched north door, iron-banded, with its bar and the chalk at head height.
	poly([Vector2(390, 420), Vector2(390, 230), Vector2(420, 190), Vector2(480, 170), Vector2(540, 190), Vector2(570, 230), Vector2(570, 420)], Color(0.06, 0.045, 0.035))
	for y in [260.0, 330.0, 390.0]:
		c.draw_rect(Rect2(390, y, 180, 6), Color(0.12, 0.12, 0.13))
	c.draw_rect(Rect2(360, 300, 240, 12), Color(0.16, 0.12, 0.08))
	for i in 5:
		c.draw_line(Vector2(440 + i * 16, 250 + (i % 2) * 4), Vector2(452 + i * 16, 244 + (i % 2) * 6), Color(0.9, 0.9, 0.85, 0.35), 1.5)
	lamp(Vector2(330, 250), t, 40.0)
	if ti >= 3:
		glow(Vector2(480, 420), 90.0, Color(0, 0, 0, 0.2))  # something waits beyond


func _gate(t: float) -> void:
	_city_line(400.0, 3)
	_ground(440.0)
	# Two towers and the arch, the letter-slot gate between.
	c.draw_rect(Rect2(250, 180, 110, 260), INK)
	c.draw_rect(Rect2(600, 180, 110, 260), INK)
	poly([Vector2(240, 180), Vector2(305, 120), Vector2(370, 180)], INK)
	poly([Vector2(590, 180), Vector2(655, 120), Vector2(720, 180)], INK)
	poly([Vector2(360, 440), Vector2(360, 260), Vector2(480, 210), Vector2(600, 260), Vector2(600, 440)], INK)
	poly([Vector2(390, 440), Vector2(390, 290), Vector2(480, 250), Vector2(570, 290), Vector2(570, 440)], Color(0.05, 0.06, 0.1))
	for i in 9:
		c.draw_line(Vector2(400 + i * 20, 300), Vector2(400 + i * 20, 440), INK, 3.0)
	lamp(Vector2(305, 230), t)
	lamp(Vector2(655, 230), t)


# --- the city -------------------------------------------------------------------------

func _market(t: float) -> void:
	_city_line(360.0, 7)
	_ground(430.0)
	# Stalls with awnings, each with a lantern.
	for i in 4:
		var x := 60.0 + i * 230.0
		c.draw_rect(Rect2(x, 360, 170, 70), INK)
		poly([Vector2(x - 12, 362), Vector2(x + 85, 330), Vector2(x + 182, 362)], Color(0.09, 0.04, 0.05) if i % 2 == 0 else Color(0.07, 0.06, 0.03))
		lamp(Vector2(x + 20 + (i % 2) * 130, 372), t, 52.0)
	# Strings of small lanterns across the street.
	for k in 14:
		var x := 40.0 + k * 66.0
		var y := 250.0 + sin(k * 0.45) * 18.0
		lamp(Vector2(x, y), t, 22.0)


func _square(t: float) -> void:
	_city_line(380.0, 11)
	_ground(430.0)
	# The column at the centre and the empty corner the dog won't go near.
	c.draw_rect(Rect2(462, 240, 36, 190), INK)
	c.draw_rect(Rect2(440, 230, 80, 14), INK)
	c.draw_circle(Vector2(480, 222), 14.0, INK)
	_ellipse(Vector2(480, 440), 120.0, 18.0, Color(0, 0, 0, 0.35))
	glow(Vector2(820, 420), 70.0, Color(0.55, 0.6, 0.8, 0.05))  # a corner colder than the rest
	lamp(Vector2(160, 330), t)
	lamp(Vector2(330, 330), t)
	lamp(Vector2(650, 330), t)


func _lane(t: float) -> void:
	_ground(440.0)
	# Houses close on both sides, lamps receding along the curve.
	poly([Vector2(0, 540), Vector2(0, 120), Vector2(300, 260), Vector2(380, 300), Vector2(380, 440), Vector2(0, 540)], INK)
	poly([Vector2(960, 540), Vector2(960, 140), Vector2(640, 270), Vector2(570, 300), Vector2(570, 440), Vector2(960, 540)], INK)
	c.draw_rect(Rect2(380, 300, 190, 140), INK2)
	for i in 5:
		var k := i / 4.0
		lamp(Vector2(lerpf(220, 440, k), lerpf(250, 320, k)), t, lerpf(60, 18, k))
	# Mira's door, and the second lantern by it, burning inward.
	c.draw_rect(Rect2(120, 330, 60, 110), Color(0.06, 0.04, 0.03))
	lamp(Vector2(200, 340), t, 40.0)
	glow(Vector2(232, 340), 18.0, Color("8fb4ff", 0.25))
	c.draw_circle(Vector2(232, 340), 2.5, Color("cfe0ff"))


func _mill(t: float) -> void:
	_city_line(380.0, 5, Color(0.025, 0.035, 0.07))
	_ground(430.0)
	# The mill house, its wheel, and the millrace across the yard.
	c.draw_rect(Rect2(520, 240, 300, 190), INK)
	poly([Vector2(500, 240), Vector2(670, 160), Vector2(840, 240)], INK)
	var wc := Vector2(470, 350)
	c.draw_circle(wc, 80.0, INK)
	for k in 8:
		var a := k * TAU / 8.0 + t * 0.2
		c.draw_line(wc, wc + Vector2.from_angle(a) * 80.0, Color(0.05, 0.06, 0.1), 3.0)
	c.draw_rect(Rect2(0, 460, 960, 26), Color(0.06, 0.1, 0.16))
	for k in 12:
		var x := fmod(k * 90.0 + t * 30.0, 960.0)
		c.draw_line(Vector2(x, 470), Vector2(x + 30, 470), Color(MOON, 0.15), 1.0)
	lamp(Vector2(560, 300), t, 40.0)
	# The ash heap by the wall.
	poly([Vector2(80, 430), Vector2(150, 395), Vector2(240, 430)], Color(0.05, 0.05, 0.06))


func _road(t: float) -> void:
	# The plateau: low hills, the road running back toward the city, frost on the stones.
	poly([Vector2(0, 360), Vector2(200, 320), Vector2(420, 345), Vector2(640, 310), Vector2(960, 350), Vector2(960, 540), Vector2(0, 540)], INK2)
	poly([Vector2(0, 430), Vector2(300, 400), Vector2(700, 410), Vector2(960, 395), Vector2(960, 540), Vector2(0, 540)], INK)
	poly([Vector2(430, 540), Vector2(475, 360), Vector2(490, 360), Vector2(560, 540)], Color(0.07, 0.08, 0.11))
	for i in 9:
		var y := 520.0 - i * 18.0
		c.draw_circle(Vector2(480 + sin(i * 1.7) * 18.0 * (1.0 - i / 10.0), y), 2.0 * (1.0 - i / 12.0), Color(0.75, 0.82, 0.95, 0.25))
	glow(Vector2(80, 300), 40.0, Color(LAMP, 0.08))  # the city, far off


# --- interiors ------------------------------------------------------------------------

func _interior(id: String, ti: int, day: int, t: float) -> void:
	c.draw_rect(Rect2(0, 0, 960, 540), Color(0.03, 0.035, 0.06))
	# A tall window onto the night, with the moon.
	var win := Rect2(770, 70, 150, 230)
	var sky: Color = SKY[ti][0]
	c.draw_rect(win, sky)
	if ti >= 3:
		for i in 16:
			c.draw_circle(win.position + Vector2(fmod(i * 47.0, 170.0), fmod(i * 83.0, 260.0)), 1.0, Color(MOON, 0.6))
	var m := win.position + Vector2(100, 64)
	if ti != 1:
		c.draw_circle(m, 16.0, Color(MOON, 0.85))
		var i := (day - 1) % 28
		var dx := -32.0 * i / 14.0 if i <= 14 else 32.0 * (28 - i) / 14.0
		if absf(dx) < 32.0:
			c.draw_circle(m + Vector2(dx, 0), 16.5, sky)
	c.draw_rect(Rect2(win.position.x + 72, win.position.y, 6, win.size.y), INK)
	c.draw_rect(Rect2(win.position.x, win.position.y + 110, win.size.x, 6), INK)
	c.draw_rect(win, INK, false, 8.0)
	glow(win.get_center() + Vector2(0, 180), 160.0, Color(MOON, 0.03))
	if id == "archive":
		# Shelves, ladders, and the hanging shard of amber light that won't move.
		# Tall stacks behind the page, and a low one under the window.
		for sh_r: Rect2 in [Rect2(20, 60, 180, 420), Rect2(220, 60, 180, 420), Rect2(420, 60, 180, 420), Rect2(700, 330, 250, 160)]:
			c.draw_rect(sh_r, INK)
			var rows := int(sh_r.size.y / 48.0)
			var books := int((sh_r.size.x - 16.0) / 18.0)
			for row in rows:
				var y := sh_r.position.y + 30.0 + row * 48.0
				c.draw_rect(Rect2(sh_r.position.x + 8, y, sh_r.size.x - 16, 3), Color(0.08, 0.06, 0.04))
				for b in books:
					var h := 30.0 - fmod(b * 7.0 + row, 8.0)
					c.draw_rect(Rect2(sh_r.position.x + 12 + b * 18, y - h, 12, h), Color(0.06 + fmod(b * 0.013, 0.04), 0.045, 0.04))
		var sh := Vector2(860, 250)
		glow(sh, 60.0, Color(SHARD, 0.12))
		poly([sh + Vector2(0, -16), sh + Vector2(6, 0), sh + Vector2(0, 16), sh + Vector2(-6, 0)], SHARD)
		lamp(Vector2(760, 470), t, 70.0)  # Wren's reading lamp
	else:
		# Your room: the bed, the desk with the brass star, a candle.
		c.draw_rect(Rect2(60, 360, 300, 120), INK)
		c.draw_rect(Rect2(60, 330, 80, 40), Color(0.05, 0.05, 0.07))
		c.draw_rect(Rect2(720, 400, 220, 18), INK)
		c.draw_rect(Rect2(730, 418, 12, 90), INK)
		c.draw_rect(Rect2(918, 418, 12, 90), INK)
		var star := Vector2(860, 392)
		glow(star, 20.0, Color("c8a050", 0.15))
		var pts: Array = []
		for k in 10:
			pts.append(star + Vector2.from_angle(-PI / 2 + k * PI / 5) * (7.0 if k % 2 == 0 else 3.0))
		poly(pts, Color("c8a050"))
		lamp(Vector2(760, 386), t, 60.0)


func _ellipse(at: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)
