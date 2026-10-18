# Day 1, dawn: the Fire on the College stairs (trace R1), and your room. Every loop opens on
# the stairs. Where each slice scene now happens: design/open-world/world.md §5.

=== fire
days: 1
times: morning
force: true
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
+ move stairs
When the fire burns out, there is no one on the stairs.
* Get up

=== fire_again
days: 1
times: morning
force: true
priority: 100
when: loop > 1
+ cutscene fire
Smoke. Heat. The stairs, burning.
You know this. You were dead. You remember dying.
+ learn loop_known
+ move stairs
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

# --- your room ------------------------------------------------------------------

=== room_first
arrive: room
priority: 5
Your room in the College: a narrow bed, a cold grate, a window over the roofs.
On the desk sits your brass star, the one you've had since you were small. One point is nicked.
[k("walker_star")] It is the same kind of star the veiled figure wore. Exactly the same kind.
+ learn own_star
* Leave

=== desk
use: desk
repeat: true
Your desk. The brass star, a stub of candle, and your spellbook lying open.
[k("walker_star")] The star's nicked point catches the light, the same as the one in the fire.
+ learn own_star
Each Ring you reach opens another page of it.
* Change the spellbook -> desk_book
* Leave

=== desk_book
+ book

=== bed_first
use: bed
priority: 5
when: not k("pillow_note")
Under the pillow there's a folded note. It is written in the College's old star cipher.
[not k("cipher")] You can't read it.
[k("cipher")] You can read it: "Don't say how it ends."
+ learn pillow_note
[k("cipher")] + learn pillow_note_read
* Meditate for a while [not done("meditate")] -> meditate_room
* Sleep until dawn -> sleep_now
* Leave

=== room_note_read
use: bed
priority: 6
when: k("cipher") and k("pillow_note") and not k("pillow_note_read")
You take the note from under the pillow and read it, slowly, symbol by symbol.
"Don't say how it ends."
+ learn pillow_note_read
* Meditate for a while [not done("meditate")] -> meditate_room
* Sleep until dawn -> sleep_now
* Leave

=== bed
use: bed
repeat: true
priority: -10
Your bed, and the note under the pillow.
* Meditate for a while [not done("meditate")] -> meditate_room
* Sleep until dawn -> sleep_now
* Leave

=== meditate_room
You sit cross-legged on the cold floor and draw the night in, slow and even.
+ meditate 5

=== sleep_now
You lie down and let the day go.
+ sleep
