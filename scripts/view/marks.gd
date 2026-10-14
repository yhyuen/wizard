extends Control
## What floats over a figure's head, in screen space so it stays crisp: flame pips toward
## Ignite, HP in chunks of 10 (design doc §4.4), stun stars and the Wet drop.

var view
var arena


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(960, 540)


func _draw() -> void:
	if arena == null or arena.player == null:
		return
	for u in arena.units:
		if u.dead:
			continue
		var head: Vector2 = view.to_screen(u.pos, 2.15 + u.lift() * view.S)
		if u.reaction in ["stagger", "launch"] or u.stun > 0.0:
			var a: float = u.anim * 8.0
			for i in 3:
				var o := Vector2(cos(a + i * TAU / 3.0) * 11.0, sin(a + i * TAU / 3.0) * 3.0)
				draw_rect(Rect2(head + o - Vector2(1.5, 1.5), Vector2(3, 3)), PixelArt.GOLD)
		if u.wet_t > 0.0:
			draw_rect(Rect2(head + Vector2(10, 4), Vector2(3, 5)), PixelArt.WATER)
		if u.team == 1:
			_pips(u, head + Vector2(0, -6))
			if u.kind != "rival":
				_chunks(u, head + Vector2(0, 2))


func _pips(u: Unit, at: Vector2) -> void:
	if u.pips <= 0:
		return
	var n: int = arena.ignite_threshold()
	var x0 := at.x - (n * 7 - 2) / 2.0
	for i in n:
		var r := Rect2(Vector2(x0 + i * 7, at.y - 5), Vector2(5, 5))
		if i < u.pips:
			draw_rect(r, PixelArt.FIRE_HOT if u.pip_timer > 1.0 or int(u.anim * 10) % 2 == 0 else PixelArt.FIRE)
		else:
			draw_rect(r, Color(PixelArt.FIRE, 0.45), false, 1.0)


func _chunks(u: Unit, at: Vector2) -> void:
	var chunks := int(ceil(u.max_hp / 10.0))
	var w := chunks * 6 - 1
	var x0 := roundf(at.x - w / 2.0)
	draw_rect(Rect2(x0 - 1, at.y - 1, w + 2, 5), Color(0.03, 0.03, 0.05, 0.6))
	for i in chunks:
		var lo := i * 10.0
		var col := Color(0.15, 0.1, 0.12, 0.8)
		if u.hp > lo:
			col = PixelArt.DANGER if u.hp >= lo + 10.0 or u.hp >= u.max_hp else Color(PixelArt.DANGER, 0.55)
		elif u.hp_lag > lo:
			col = PixelArt.PAPER
		draw_rect(Rect2(x0 + i * 6, at.y, 5, 3), col)
