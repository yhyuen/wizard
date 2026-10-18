# The College of Hours: Wren and the archive, the yard, the Observatory, the north door and the
# gate. Traces R0, R4, R5, R7, R9, R10 (design/slice/content.md), now spoken in place.

# --- Wren --------------------------------------------------------------------

=== archive_meet
talk: wren
days: 1-7
times: morning, noon, afternoon, dusk
priority: 10
when: not f("met_wren")
[loop == 1] Wren: You're the apprentice from the stairs. Everyone's talking about it. Are you hurt?
[loop > 1] Wren: Oh. You're the one from the stairs. Are you all right? You look like you've seen a ghost.
Wren: I'm Wren. I keep the archive. Mostly I keep it from falling down.
+ set met_wren
+ learn wren
* Tell Wren about the sea [k("wren_sea") and not f("wren_friend")] -> wren_sea_tell
* Ask Wren to read the note on the desk [not k("noon_note") and day <= 4] -> noon_note
* Ask about the light hanging in the archive [not seen("shard_look")] -> shard_look
* Leave

=== noon_note
Wren turns the note to the lamp.
Wren: "Day four. Noon. Sit with them." Odd. It isn't addressed to anyone.
Wren: It's the old star cipher. Hardly anyone uses it now. Me, the Provost, and whoever wrote this.
+ learn noon_note
+ take noon_note
* Ask about the light hanging in the archive [not seen("shard_look")] -> shard_look
* Leave

=== sit_with_wren
talk: wren
days: 4
times: noon
priority: 20
when: not f("wren_friend")
[k("noon_note")] Noon on day four. You came, as the note said.
Wren: You came back. I didn't think anyone ever came back to the archive on purpose.
The afternoon goes by. Wren talks about the shelves, the Provost nobody has seen in weeks, and the Orrery humming wrong since the night of the light.
Wren: Can I tell you something stupid? After the Eclipse I'm going to see the sea. I've never seen it. I've never told anyone.
+ learn wren_sea
+ set met_wren
+ set wren_friend
+ set noon_kept
[not k("cipher")] Wren: And you ought to learn the star cipher, since notes keep turning up for you. Here.
[not k("cipher")] + learn cipher
[k("cipher")] Wren: You can read the old cipher? Who on earth taught you that?
* Ask about the Orrery [not k("orrery_wrong")] -> wren_orrery
* Leave

=== sit_again
talk: wren
days: 4
times: noon
priority: 19
when: f("wren_friend")
Noon on day four. Wren already has two cups of tea poured.
Wren: I had a feeling you'd come at noon. I don't know why.
+ set noon_kept
The afternoon goes by the way it always does, and you let it.
* Leave

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

=== wren_orrery
Wren: The night of the light, the Provost was inside the Orrery. Nobody's seen him since.
Wren: And the Orrery's been running slow. A hair every hour, as if it were winding back.
Wren: If anything in this city could break time, it would be that.
+ learn orrery_wrong
* Leave

=== wren_default
talk: wren
repeat: true
priority: -10
[time == "dusk"] Wren looks up from a book on the yard bench, where the lamps are coming on.
[time != "dusk"] Wren comes down the ladder with an armful of ledgers.
Wren: Need something?
* Study with Wren [time != "dusk"] -> archive_study
* Tell Wren about the sea [k("wren_sea") and not f("wren_friend")] -> wren_sea_tell
* Ask Wren to read the note on the desk [not k("noon_note") and day <= 4] -> noon_note
* Ask about the Orrery [f("wren_friend") and not k("orrery_wrong")] -> wren_orrery
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

# --- the archive's things -------------------------------------------------------

=== desk_note_read
use: noon_note
priority: 5
when: k("cipher")
Between two ledgers on Wren's desk lies a note in the star cipher. You read it.
"Day four. Noon. Sit with them." It isn't addressed to anyone.
+ learn noon_note
+ take noon_note

=== desk_note
use: noon_note
repeat: true
priority: -10
Between two ledgers on Wren's desk lies a note in the star cipher. You can't read it.
[f("met_wren")] Wren could.

=== shard_look
use: shard
priority: 5
In the middle of the reading room, a sliver of amber light hangs in the air, turning slowly.
It has hung there since the night of the light, they say. Nobody can move it.
+ learn shard
[k("loop_known") and not k("model_rewind")] It pulls at the part of you that remembers dying. You could study it.
* Study the shard [k("loop_known") and not k("model_rewind")] -> shard_study
* Leave

=== shard_idle
use: shard
repeat: true
priority: -10
The shard of light turns slowly in the air.
* Study the shard [k("loop_known") and not k("model_rewind")] -> shard_study
* Leave

=== shard_study
You stand under the shard until your eyes water and the light starts to make sense.
It is the shape of a moment folding back on itself. You feel your hand learn it.
+ model rewind
Rewind: step back to where you stood a moment ago. It will come back with you, every loop.

# --- the yard ----------------------------------------------------------------

=== silas_meet
talk: silas
days: 2-7
priority: 10
when: not k("silas")
A tall student in a storm-blue coat looks you up and down.
Silas: The one from the stairs. Silas Vane. You'll hear about me.
Silas: The yard trial's open, if you want to embarrass yourself. Practice duels are on day six, in the morning.
+ learn silas
* Leave

=== silas_again
talk: silas
days: 2-7
priority: 10
when: k("silas") and loop > 1 and not k("silas_again")
Silas looks at you. For a moment his face does something strange.
Silas: Again? ... I mean, again someone from the stairs. Silas Vane. Day six. Don't be late.
+ learn silas_again
* Leave

=== silas_duel
arrive: yard
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

=== silas_duel_talk
talk: silas
days: 6
times: morning
priority: 20
when: not seen("silas_duel")
+ goto silas_duel

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

=== silas_default
talk: silas
repeat: true
priority: -10
[day < 6] Silas: Day six. The chalk circle. Unless you're scared.
[day >= 6 and seen("silas_duel")] Silas: Don't look so pleased with yourself.
[day >= 6 and not seen("silas_duel")] Silas: You missed the duels. Of course you did.
* Leave

=== examiner
talk: examiner
repeat: true
The examiner looks up from a slate of names.
[not f("ring1")] Examiner: The yard trial is open to any apprentice. The constructs hit back, but softly.
[f("ring1")] Examiner: First Ring. Don't let it go to your head.
* Take the yard trial [not f("ring1")] -> yard_trial
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

=== targets
use: targets
repeat: true
The straw targets, more hole than straw.
* Train [not done("train")] -> yard_train
* Leave

=== yard_train
You drill until your hands ache and the target is more hole than straw.
+ train

=== pell
talk: pell
repeat: true
[day < 7] Pell: You're the one from the stairs! Is it true you were on fire? Properly on fire?
[day == 7] Pell: I'm on the north door today. Someone has to be. The wind keeps calling my name. That's silly, isn't it?
* Leave

=== porter
talk: porter
repeat: true
The porter opens one eye.
[time == "dusk" or time == "night"] Porter: Lamps are lit. Mind the north side after dark.
[time != "dusk" and time != "night"] Porter: Gate's open. Gate's always open. Nobody ever asks me why.
* Leave

# --- the Observatory ------------------------------------------------------------

=== burnt_door
use: burnt_door
days: 1-9
priority: 5
The Observatory door is burnt through. The scorch spreads outward from the inside, as if something burned its way out.
Nobody has been in since the night of the light. The bolt is still drawn on this side.
+ learn burnt_door
[not k("scorch_match")] Five black points flare out round it. You could put an Ember Bolt into the wall beside it, and compare.
* Meditate under the dome [not done("meditate")] -> meditate_obs
* Leave

=== scorch_test
use: burnt_door
cast: fire
when: not k("scorch_match")
Your bolt leaves a black star on the stone: five points, flaring out.
You look from it to the door. The same five points. The same flare.
+ learn burnt_door
+ learn scorch_match

=== observatory_idle
use: burnt_door
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
use: chalk
priority: 5
The north door of the College: iron-bound oak, older than the walls around it. It opens onto the dark side of the hill.
Chalked across it at head height, in a neat hand: the star cipher.
[k("cipher")] You read it: "Not before the bell."
+ learn warning_chalk
[k("cipher")] + learn warning_read
* Leave

=== north_door_read
use: chalk
priority: 6
when: k("cipher") and k("warning_chalk") and not k("warning_read")
You read the chalk on the north door: "Not before the bell."
+ learn warning_read
* Leave

=== north_door_idle
use: chalk
repeat: true
priority: -10
The north door. The wind whistles under it.
[k("warning_read")] The chalk still says: "Not before the bell."
* Leave

=== bar_door
use: beam
days: 7
times: morning, noon, afternoon
priority: 20
title: Bar the door
known: died("north_door")
when: died("north_door") and not f("door_barred")
You remember the dark pouring through this door.
You drop the beam into its brackets and wedge it with a bench. It won't open from either side now.
+ set door_barred
* Leave

=== beam
use: beam
repeat: true
priority: -10
A heavy beam leans against the wall. It would fit the door's brackets.
[f("door_barred")] It's in the brackets now. Nothing is coming through.
[not f("door_barred")] You have no reason to bar the door. Not yet.
* Leave

# --- the College gate ------------------------------------------------------------

=== gate_letter
use: gate_letter
days: 1-25
priority: 5
A folded letter is wedged in the College gate, jammed in so tight the porter hasn't noticed it.
It's written in the star cipher.
[k("cipher")] You read it: seven numbers, and a line beneath them. "For the Gate, when it turns." You have never heard of a gate that turns.
+ learn gate_letter
[k("cipher")] + learn combination
[k("cipher")] + take gate_letter
* Leave

=== gate_letter_read
use: gate_letter
days: 1-25
priority: 6
when: k("cipher") and k("gate_letter") and not k("combination")
You work the letter out of the gate and read it: seven numbers, and a line beneath them.
"For the Gate, when it turns." You have never heard of a gate that turns.
+ learn combination
+ take gate_letter
* Leave

=== gate_letter_idle
use: gate_letter
repeat: true
priority: -10
The letter is still jammed in the gate, in a cipher you can't read.
* Leave
