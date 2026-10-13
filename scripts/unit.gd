class_name Unit
extends RefCounted
## Anything with HP on the field: the wizard, Hollows, Slingers and the rival.

var id := 0
var kind := ""
var team := 1  # 0 = the player, 1 = enemies
var pos := Vector2.ZERO
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
var wall_check := 0.0  # Pin: a stone hit recently, so a wall hit stuns

var anim := 0.0
var moving := false
var state := "idle"
var state_t := 0.0
var aim := Vector2.ZERO
var cd := {}
var flags := {}


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
