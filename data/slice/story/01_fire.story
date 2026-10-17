# Day 1, dawn: the Fire (trace R1). Every loop opens here. See design/slice/content.md.

=== fire
backdrop: gate
place: anywhere
days: 1
times: morning
force: true
slot: free
priority: 100
when: loop == 1
+ cutscene fire
Smoke. Heat on your face. You are lying on the College stairs, and the stairs are burning.
You can't remember climbing them. You can't remember anything after the Orrery's light.
Something in the flames moves: a body, veiled, lying in the fire as if it had always been there.
It stirs. It rises. It never once looks at you.
A spell you don't know lifts you out of the fire and sets you down on the cold steps below.
At its wrist a small brass star turns in the heat.
Then it walks backwards, step by careful step, into the flames, and lies down.
+ learn veiled_figure
+ learn walker_star
When the fire burns out, there is no one on the stairs.
* Get up

=== fire_again
backdrop: gate
place: anywhere
days: 1
times: morning
force: true
slot: free
priority: 100
when: loop > 1
Smoke. Heat. The stairs, burning.
You know this. You were dead. You remember dying.
+ learn loop_known
The veiled body in the flames stirs and rises, exactly as before.
* Watch the figure closely [not k("star_nick")] -> fire_watch
* Look away until it's over

=== fire_watch
You make yourself look, though the heat makes your eyes stream.
The brass star at its wrist has a nick on one point, a little bite out of the brass.
[k("own_star")] Your star has that nick. You've had it since you were small.
+ learn star_nick
The spell lifts you clear. The figure walks backwards into the fire and lies down.
* Get up
