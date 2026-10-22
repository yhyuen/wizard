class_name Unit
extends RefCounted
## Anything with HP on the field: the wizard, Hollows, Slingers and the rival.

var id := 0
var kind := ""
var team := 1  # 0 = the player, 1 = enemies
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO  # pos at the start of this physics step, for drawing between steps
var vel := Vector2.ZERO  # knockback, decays
var radius := 5.0
var hp := 1.0
var max_hp := 1.0
var hp_lag := 1.0  # the chunk bar drains toward hp
var poise := 0
var speed := 30.0
var facing := 1.0
var dead := false
var death_t := 0.0

var pips := 0
var pip_timer := 0.0
var reaction := ""
var reaction_t := 0.0
var reaction_len := 0.0
var stun := 0.0  # hard lock that is not a reaction (wall stun)
var flash := 0.0
var iframes := 0.0
var slow_t := 0.0
var wet_t := 0.0  # Wet (Water): lightning chains further and discovers Conductor
var wall_check := 0.0  # Pin: a stone hit recently, so a wall hit stuns
var brk := 0.0  # the Break meter (enemy spec §4): full, it is Broken
var brk_t := 0.0  # seconds since the last hit filled it (it drains after a while)
var broken_t := 0.0  # Broken: can't act, takes more damage
var burn_t := 0.0  # burning (enemy spec §5): fire on a body that catches
var burn_tick := 0.0
var oil_t := 0.0  # oiled by tar: flesh catches, and anything burns harder

var anim := 0.0
var moving := false
var state := "idle"
var state_t := 0.0
var aim := Vector2.ZERO
var cd := {}
var cd_total := {}  # spell id -> the full lock last set (longer than the cooldown after an Overdraw)
var flags := {}


## Where to draw this unit this frame: between the last two physics steps, so movement stays
## smooth when the screen refreshes faster than 60 Hz or a frame runs late. A jump (a blink, a
## new map) is drawn where it lands.
func shown_pos() -> Vector2:
	return smooth(prev_pos, pos)


static func smooth(a: Vector2, b: Vector2) -> Vector2:
	if a.distance_squared_to(b) > 400.0:
		return b
	return a.lerp(b, Engine.get_physics_interpolation_fraction())


func alive() -> bool:
	return not dead


func locked() -> bool:
	return reaction_t > 0.0 or stun > 0.0


func cooldown(key: String) -> float:
	return float(cd.get(key, 0.0))


func tick_cooldowns(dt: float) -> void:
	for k in cd:
		cd[k] = maxf(0.0, float(cd[k]) - dt)


## Height for a launch: an arc over the reaction time.
func lift() -> float:
	if reaction != "launch" or reaction_len <= 0.0:
		return 0.0
	var t := 1.0 - reaction_t / reaction_len
	return sin(clampf(t * 1.25, 0.0, 1.0) * PI) * 10.0
