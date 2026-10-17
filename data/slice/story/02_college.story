# The College of Hours: your room, the archive, the yard, the Observatory, the north door and
# the gate. Traces R0, R4, R5, R7, R9, R10 (design/slice/content.md).

# --- your room ---------------------------------------------------------------

=== room_first
place: room
days: 1-28
times: any
priority: 5
Your room in the College: a narrow bed, a cold grate, a window over the roofs.
On the desk sits your brass star, the one you've had since you were small. One point is nicked.
[k("walker_star")] It is the same kind of star the veiled figure wore. Exactly the same kind.
Under the pillow there's a folded note. It is written in the College's old star cipher.
[not k("cipher")] You can't read it.
[k("cipher")] You can read it now: "Don't say how it ends."
+ learn own_star
+ learn pillow_note
[k("cipher")] + learn pillow_note_read
* Meditate for a while [not done("meditate")] -> meditate_room
* Leave

=== room_note_read
place: room
days: 1-22
times: any
priority: 6
when: k("cipher") and k("pillow_note") and not k("pillow_note_read")
You take the note from under the pillow and read it, slowly, symbol by symbol.
"Don't say how it ends."
+ learn pillow_note_read
* Meditate for a while [not done("meditate")] -> meditate_room
* Leave

=== room_idle
place: room
days: 1-28
times: any
repeat: true
priority: -10
Your room. The brass star on the desk, the note under the pillow.
* Meditate for a while [not done("meditate")] -> meditate_room
* Leave

=== meditate_room
You sit cross-legged on the cold floor and draw the night in, slow and even.
+ meditate 5

# --- the archive -------------------------------------------------------------

=== archive_meet
place: archive
days: 1-7
times: morning, noon, afternoon
priority: 10
when: not f("met_wren")
The archive smells of dust and lamp oil. The shelves climb up into the dark.
[loop == 1] Wren: You're the apprentice from the stairs. Everyone's talking about it. Are you hurt?
[loop > 1] Wren: Oh. You're the one from the stairs. Are you all right? You look like you've seen a ghost.
Wren: I'm Wren. I keep the archive. Mostly I keep it from falling down.
[not seen("sit_with_wren")] Between two ledgers on the desk lies a note in the star cipher.
+ set met_wren
+ learn wren
* Tell Wren about the sea [k("wren_sea") and not f("wren_friend")] -> wren_sea_tell
* Ask Wren to read the note on the desk [not k("noon_note") and day <= 4] -> noon_note
* Ask about the light hanging in the air [not seen("shard_look")] -> shard_look
* Leave

=== noon_note
Wren turns the note to the lamp.
Wren: "Day four. Noon. Sit with them." Odd. It isn't addressed to anyone.
Wren: It's the old star cipher. Hardly anyone uses it now. Me, the Provost, and whoever wrote this.
+ learn noon_note
* Ask about the light hanging in the air [not seen("shard_look")] -> shard_look
* Leave

=== shard_look
In the middle of the reading room, a sliver of amber light hangs in the air, turning slowly.
Wren: It's been there since the night of the light. Nobody can move it. I've been told not to touch it.
+ learn shard
[k("loop_known") and not k("model_rewind")] It pulls at the part of you that remembers dying. You could study it.
* Study the shard [k("loop_known") and not k("model_rewind")] -> shard_study
* Leave

=== shard_study
You stand under the shard until your eyes water and the light starts to make sense.
It is the shape of a moment folding back on itself. You feel your hand learn it.
+ model rewind
Rewind: step back to where you stood a moment ago. It will come back with you, every loop.

=== wren_sea_tell
You tell Wren the thing Wren told you at noon on day four: after the Eclipse, the sea.
Wren goes very still.
Wren: Nobody knows that. I've never said it out loud. Not once.
Wren: How many times have we met?
* "More than once." -> wren_trust

=== wren_trust
Wren: And I liked you, every time?
Wren laughs, shakily, and pulls out a chair for you.
+ set wren_friend
[not k("cipher")] Wren: Then you'd better learn the star cipher. Notes seem to follow you around.
[not k("cipher")] + learn cipher
* Ask about the Orrery [not k("orrery_wrong")] -> wren_orrery
* Leave

=== sit_with_wren
place: archive
days: 4
times: noon
priority: 20
when: not f("wren_friend")
[k("noon_note")] Noon on day four. You came, as the note said.
Wren: You came back. I didn't think anyone ever came back to the archive on purpose.
The afternoon goes by. Wren talks about the shelves, the Provost nobody has seen in weeks, and the Orrery humming wrong since the night of the light.
Wren: Can I tell you something stupid? After the Eclipse I'm going to see the sea. I've never seen it. I've never told anyone.
+ learn wren_sea
+ set wren_friend
+ set noon_kept
[not k("cipher")] Wren: And you ought to learn the star cipher, since notes keep turning up for you. Here.
[not k("cipher")] + learn cipher
[k("cipher")] Wren: You can read the old cipher? Who on earth taught you that?
* Ask about the Orrery [not k("orrery_wrong")] -> wren_orrery
* Leave

=== sit_again
place: archive
days: 4
times: noon
priority: 19
when: f("wren_friend")
Noon on day four. Wren already has two cups of tea poured.
Wren: I had a feeling you'd come at noon. I don't know why.
+ set noon_kept
The afternoon goes by the way it always does, and you let it.
* Leave

=== wren_orrery
Wren: The night of the light, the Provost was inside the Orrery. Nobody's seen him since.
Wren: And the Orrery's been running slow. A hair every hour, as if it were winding back.
Wren: If anything in this city could break time, it would be that.
+ learn orrery_wrong
* Leave

=== archive_idle
place: archive
days: 1-28
times: morning, noon, afternoon
repeat: true
priority: -10
Wren is up a ladder, reshelving.
* Study with Wren -> archive_study
* Tell Wren about the sea [k("wren_sea") and not f("wren_friend")] -> wren_sea_tell
* Study the shard [k("loop_known") and not k("model_rewind")] -> shard_study
* Ask about the Orrery [f("wren_friend") and not k("orrery_wrong")] -> wren_orrery
* Leave

=== archive_closed
place: archive
days: 1-28
times: dusk, night
repeat: true
priority: -10
The archive is dark. Only the shard of light turns in the middle of the room.
* Study the shard [k("loop_known") and not k("model_rewind")] -> shard_study
* Leave

=== archive_study
Wren pulls down a book of College Models.
* Luna: Splash [not k("model_splash")] -> study_splash
* Mercury: Spark [not k("model_spark")] -> study_spark
* Luna: Undertow [not k("model_undertow")] -> study_undertow
* Mercury: Arc Lance [not k("model_arc_lance")] -> study_arc_lance
* Just read

=== study_splash
You work through the diagrams until the water in the cup answers you.
+ model splash

=== study_spark
Your fingertips crackle. Wren moves the inkwell out of reach.
+ model spark

=== study_undertow
The book shows a wave that carries, not a wave that breaks.
+ model undertow

=== study_arc_lance
A line of light from one hand to the far wall. Wren jumps.
+ model arc_lance

# --- the yard ----------------------------------------------------------------

=== silas_meet
place: yard
days: 2-7
times: morning
priority: 10
when: not k("silas")
A tall student is throwing sparks at a straw target and hitting it every time.
Silas: The one from the stairs. Silas Vane. You'll hear about me.
Silas: The yard trial's open, if you want to embarrass yourself. Practice duels are on day six.
+ learn silas
* Leave

=== silas_again
place: yard
days: 2-7
times: morning
priority: 10
when: k("silas") and loop > 1 and not k("silas_again")
Silas looks up from his target. For a moment his face does something strange.
Silas: Again? ... I mean, again someone from the stairs. Silas Vane. Day six. Don't be late.
+ learn silas_again
* Leave

=== silas_duel
place: yard
days: 6
times: morning
priority: 20
title: Practice duel
known: k("silas")
The yard is ringed with students. Silas waits in the chalk circle.
Silas: College rules. First to three hits. Try not to cry.
+ fight silas_duel
? won -> duel_won
? lost -> duel_lost

=== duel_won
Silas picks himself up and brushes the chalk off.
[loop > 1] Silas: You've got better since last time. ... Since last week.
[loop > 1] + learn silas_remembers
[loop == 1] Silas: Lucky. Next time, I won't be kind.
+ learn silas_tell

=== duel_lost
Silas: Three. Go and lie down.
He always opened the same way: a long lance of lightning from across the yard.
+ learn silas_tell

=== yard_idle
place: yard
days: 1-28
times: any
repeat: true
priority: -10
The yard: chalk circles, straw targets, a cracked practice wall.
* Take the yard trial [not f("ring1")] -> yard_trial
* Train [not done("train")] -> yard_train
* Leave

=== yard_trial
[not k("trial_yard")] The examiner wakes a line of training constructs. They hit back, but softly.
[k("trial_yard")] The examiner squints at you. "Didn't you do this already?" Only one wave, then.
+ fight yard_trial
? won -> trial_won
? lost -> trial_lost

=== trial_won
The examiner chalks a single circle on your sleeve. The 1st Ring.
+ trial yard
+ set ring1

=== trial_lost
The examiner helps you up. "Again tomorrow, maybe."

=== yard_train
You drill until your hands ache and the target is more hole than straw.
+ train

# --- the Observatory ------------------------------------------------------------

=== burnt_door
place: observatory
days: 1-9
times: any
priority: 5
The Observatory door is burnt through. The scorch spreads outward from the inside, as if something burned its way out.
Nobody has been in since the night of the light. The bolt is still drawn on this side.
+ learn burnt_door
* Cast an Ember Bolt at the wall beside it [not k("scorch_match")] -> scorch_test
* Meditate under the dome [not done("meditate")] -> meditate_obs
* Leave

=== scorch_test
Your bolt leaves a black star on the stone: five points, flaring out.
You look from it to the door. The same five points. The same flare.
+ learn scorch_match
* Leave

=== observatory_idle
place: observatory
days: 1-28
times: any
repeat: true
priority: -10
The Observatory's burnt door. Above it, the dome is open to the sky.
* Meditate under the dome [not done("meditate")] -> meditate_obs
* Leave

=== meditate_obs
You sit beneath the open dome and breathe with the stars.
[time == "night"] + meditate 8
[time != "night"] + meditate 5

# --- the north door ------------------------------------------------------------

=== north_door_look
place: north_door
days: 1-7
times: morning, noon, afternoon
priority: 5
The north door of the College: iron-bound oak, older than the walls around it. It opens onto the dark side of the hill.
Chalked across it at head height, in a neat hand: the star cipher.
[k("cipher")] You read it: "Not before the bell."
+ learn warning_chalk
[k("cipher")] + learn warning_read
* Leave

=== north_door_read
place: north_door
days: 1-7
times: any
priority: 6
when: k("cipher") and k("warning_chalk") and not k("warning_read")
You read the chalk on the north door: "Not before the bell."
+ learn warning_read
* Leave

=== bar_door
place: north_door
days: 7
times: morning, noon, afternoon
priority: 20
title: Bar the door
known: died("north_door")
when: died("north_door") and not f("door_barred")
You remember the dark pouring through this door.
You drop the bar into its brackets and wedge it with a bench. It won't open from either side now.
+ set door_barred
* Leave

=== north_door_idle
place: north_door
days: 1-28
times: any
repeat: true
priority: -10
The north door. The wind whistles under it.
* Leave

# --- the College gate ------------------------------------------------------------

=== gate_letter
place: gate
days: 1-25
times: any
priority: 5
A folded letter is wedged in the College gate, jammed in so tight the porter hasn't noticed it.
It's written in the star cipher.
[k("cipher")] You read it: seven numbers, and a line beneath them. "For the Gate, when it turns." You have never heard of a gate that turns.
+ learn gate_letter
[k("cipher")] + learn combination
* Leave

=== gate_letter_read
place: gate
days: 1-25
times: any
priority: 6
when: k("cipher") and k("gate_letter") and not k("combination")
You work the letter out of the gate and read it: seven numbers, and a line beneath them.
"For the Gate, when it turns." You have never heard of a gate that turns.
+ learn combination
* Leave

=== gate_idle
place: gate
days: 1-28
times: any
repeat: true
priority: -10
The College gate. The porter nods at you and goes back to sleep.
* Leave
