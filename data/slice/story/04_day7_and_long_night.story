# Day 7 (trace R4: the north door and the bell), the weeks that pass in the slice only, and the
# Long Night on day 27 (design/slice/content.md §5).

# --- day 7 ---------------------------------------------------------------------

=== tide
backdrop: north_door
place: anywhere
days: 7
times: dusk
force: true
priority: 50
when: not f("door_barred")
Dusk. A scream from the north side of the College. You run.
Pell, a first-year, is at the north door with both hands on the bar.
Pell: It's Wren! Wren's outside, can't you hear?
And you can: Wren's voice calling your name through the oak. Then it isn't quite Wren's voice.
[k("warning_read")] Not before the bell. The chalk is already fading.
Pell lifts the bar. The door swings open on the dark, and the dark comes in.
+ learn tide
+ fight tide
? won -> tide_survived
? lost -> tide_death

=== tide_death
There are too many. There are always too many.
The last thing you see is the chalk on the door, fading.
+ learn died_north_door
+ end_loop north_door

=== tide_survived
Somehow you are still standing. The dark draws back from the doorway, waiting.
+ set held_the_tide

=== door_holds
backdrop: north_door
place: anywhere
days: 7
times: dusk
force: true
priority: 50
when: f("door_barred")
Dusk. Someone is hammering on the north door. Pell is there, dragging at your bench, crying.
Pell: It's Wren! Let them in!
Wren's voice calls your name through the oak, then laughs in a way Wren never laughs.
You hold Pell back. The hammering goes on, and on.
+ set holding_door

=== the_bell
place: anywhere
days: 7
times: night
force: true
priority: 50
+ sound bell
At the last hour of the seventh day, the College bell rings.
[f("holding_door")] The hammering stops. The voice stops. When at last you lift the bar there is only mist on the hill, and the chalk on the door is gone.
[f("held_the_tide")] The dark at the door goes out like a tide.
+ learn the_bell
+ set survived_day7
* Go on -> weeks_pass

=== weeks_pass
The weeks pass.
In the full game you live them, one moon phase at a time: Mira's door on day sixteen, the duel on the Orrery steps, the Provost's empty study. In this slice they go by in a breath.
[f("wren_friend")] Wren finds you most evenings. You don't talk about the notes. Not yet.
[f("wren_friend")] + skip_to 27 night
[not f("wren_friend")] + goto eclipse_alone

=== eclipse_alone
Day twenty-eight. The Eclipse.
The Moon eats the Sun, and up on the hill the Orrery screams.
You face it alone. Nobody in this city sat up with you on the last night.
In the full game this is a fight. In the slice, the month ends here.
+ end_loop eclipse_alone

# --- the Long Night ------------------------------------------------------------

=== long_night
place: anywhere
days: 27
times: night
force: true
priority: 50
Day twenty-seven, the night before the Eclipse.
Wren sits on the end of your bed with a lamp, a pen, and a stack of clean paper.
Wren: Tell me everything. Everything you've found. I'll write it down properly.
Beside the lamp stands a brass censer Wren brought from the archive. It hisses softly as it fills with smoke.
Wren: When that's full, we stop. College rule for night work. Three things, maybe. Choose well.
+ goto ln_menu

=== ln_menu
[count("topic_") >= 3] + goto ln_close
Wren dips the pen and waits.
* The north door [died("north_door") and not f("topic_door")] -> ln_door
* Day four, noon [k("noon_note") and not f("topic_noon")] -> ln_noon
* The letter in the gate [k("combination") and not f("topic_letter")] -> ln_letter
* Rewind [k("model_rewind") and not f("topic_rewind")] -> ln_rewind
* The brass star [k("own_star") and k("walker_star") and not f("topic_star")] -> ln_star
* Mira's lantern [k("mira") and k("second_lantern") and not f("topic_lantern")] -> ln_lantern
* The mourner in the market [k("mourner") and not f("topic_mourner")] -> ln_mourner
* Tell Wren how it ends -> ln_trap

=== ln_door
You tell Wren about the north door: the voice, the dark, the bell that came too late.
Wren writes it down in the star cipher, in a small, careful hand: "Not before the bell."
+ set topic_door
[k("warning_chalk") and not k("notes_are_ours")] + goto ln_realise
+ goto ln_menu

=== ln_noon
You tell Wren about noon on day four, and the afternoon your friendship started.
Wren smiles and writes: "Day four. Noon. Sit with them."
+ set topic_noon
[not k("notes_are_ours")] + goto ln_realise
+ goto ln_menu

=== ln_letter
You tell Wren the seven numbers, and what they're for.
Wren writes them out, folds the paper small, and writes on the outside: "For the Gate, when it turns."
+ set topic_letter
[not k("notes_are_ours")] + goto ln_realise
+ goto ln_menu

=== ln_rewind
You show Wren the shape of Rewind, the fold of light you learnt from the shard.
Wren copies the pattern into the margin, frowning. Wren: I've seen this before. Hanging in my archive.
+ set topic_rewind
+ goto ln_menu

=== ln_star
You take your brass star from the desk and put it in Wren's hand. You don't quite know why.
Wren turns it over and finds the nick on one point with a thumb.
+ set topic_star
+ goto ln_menu

=== ln_lantern
You tell Wren about Mira, and the second lantern with her mark on it.
Wren writes: "Ask Mira for her lantern."
+ set topic_lantern
+ goto ln_menu

=== ln_mourner
You tell Wren about the veiled stranger who wept in the market.
Wren is quiet for a while, then writes two words: "Let them go."
+ set topic_mourner
+ goto ln_menu

=== ln_realise
You stop talking. You know that hand. You know those exact shapes.
It's the note on the archive desk. It's the chalk on the north door. Word for word, stroke for stroke.
The notes were never from someone who knew the future. They're from tonight. They're what you are telling Wren.
+ learn notes_are_ours
Wren looks up. Wren: What is it? You've gone white.
+ goto ln_menu

=== ln_close
The censer is full. The hissing stops.
Wren folds the pages into a neat packet and ties it with archive tape.
Wren: One more thing. Do I come back?
* Tell Wren how it ends -> ln_trap
* Say nothing -> ln_silence

=== ln_trap
You tell Wren how the road ends: the College stairs, the fire, a veiled figure lying down in the flames with an empty censer.
Wren listens and doesn't write a word. When you've finished, Wren puts the pen down.
Wren: Then I won't go.
The censer gutters. The lamp flame leans inward, like the one at Mira's door, and the room comes apart like wet paper.
+ learn trap_told
+ learn long_night
+ end_loop long_night

=== ln_silence
You don't answer. Wren looks at you for a long time, then nods, as if you had.
Wren: All right. Then I won't ask again.
[k("pillow_note_read")] Don't say how it ends. You didn't.
+ learn kept_silence
+ learn long_night
The lamp burns down. Tomorrow is the Eclipse. In the slice, the month ends here.
+ end_loop eclipse_after_long_night
