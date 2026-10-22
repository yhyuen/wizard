# The Apprentice road's main line in Ring 1 (N-7.3; the Ring 1 story §4, scenes S1-S3). SEALED
# story content: builders only. The first morning (life 1, and every life after), the glass note
# at the crater's edge, and the two first lessons. The format is in scripts/game/story.gd.

# --- S1. The first morning, life 1 ------------------------------------------------------------

=== wake_first
arrive: tent
when: loop == 1
priority: 20
You wake because the light is wrong.
It comes through the canvas the colour of weak tea, and it moves: a slow sweep, left to right, then gone, then back.
It's a lamp being carried past outside. There should be no lamps. It's morning.
And there should be a ceiling. Stone, with the brass rings turning above it in the dark.
You went to sleep in the lowest gallery of the Orrery with a polishing cloth in your hand.
Under your fingernails, packed into the quick, is a fine grey grit that glitters when you turn your hand.
You know, without knowing how you know, that it is glass from the eighth lens.
+ learn orrery_light
* Sit up slowly -> wake_wren
* Sit up fast -> wake_faint

=== wake_faint
The tent tilts. The canvas goes grey at the edges, then all of it.
Wren: Five.
Wren: I said don't. I've started counting.
+ set fainted_first
* Sit up slowly, this time -> wake_wren

=== wake_wren
Wren: Don't sit up fast. Three people have fainted this morning from sitting up fast. I've started counting.
Wren is grey with ash to the elbows, a pencil behind each ear, writing names in two columns: one long, one short. The short one has a line ruled under it like a grave.
+ learn wren
* "What happened to the Orrery?" -> wake_q_orrery
* "Which column am I in?" -> wake_q_column
* "Wren. Your hands are shaking." -> wake_q_hands

=== wake_q_orrery
Wren: It broke. That's the whole of what anyone knows. It broke and the city fell in around it.
Wren: Crane says not to speculate in front of the apprentices. Crane is speculating in her tent with the door tied shut.
* Reach for your things -> wake_ledger

=== wake_q_column
Wren: The long one. The long one is "found".
Wren: Don't make me ask how you were found, because nobody knows, and I'm tired of writing "nobody knows" in the margin.
* Reach for your things -> wake_ledger

=== wake_q_hands
Wren: They're cold. It's a cold morning.
Wren puts the pencil down, picks it up again, and writes a name very carefully.
Wren: Two hundred and six found. Ninety-one not. I keep counting in case it changes.
+ set wren_counts
* Reach for your things -> wake_ledger

=== wake_ledger
Your spellbook lies beside the cot, its pages scorched at the edges. Under your pillow is a book you don't own.
Black boards, no title. The College's seven rings are stamped on the spine, and an eighth ring beside them, empty.
The first eleven pages are full: small, careful writing in no alphabet you were taught.
The twelfth page is blank except for one line in your own hand, which you did not write.
"Don't trust the morning."
+ learn ledger_found
Wren: Crane wants every apprentice on the practice ground on the third. She said "every". She looked at me when she said it, so I think she meant you.
* Get up

# --- S1b. The glass note ------------------------------------------------------------------------

=== glass_note
arrive: hill
when: not f("glass_note")
Below the camp, a mile off and a mile down, is Vellmar. Roofs, spires, the long grey stair of the Archive.
The centre of it is gone. Where the Orrery stood there's a bowl of black glass.
Smoke rises from the fallen streets around it and, at the crater's edge, turns, and sinks back down. Slowly. Like something remembering where it came from.
There's a sound in your chest you've never heard before. A faint, dry note, like a fingernail drawn round the rim of a glass.
You've always heard the Spheres as almost nothing. This morning you hear one thing, very clearly, and it's coming from the crater.
+ set glass_note
+ learn glass_note
* Leave

# --- S1-again. The first morning, every life after ------------------------------------------------

=== wake_again
arrive: tent
when: loop > 1
priority: 20
You wake because the light is wrong.
It comes through the canvas the colour of weak tea, and it moves: a slow sweep, left to right, then gone, then back.
You lie very still. There's grit under your fingernails, fine and grey, that glitters when you turn your hand.
You count the sweeps. Four. Five. You know that on the seventh a voice will come from the tent flap.
Seven.
Wren: Don't sit up fast. Three people have fainted this morning from sitting up fast. I've started counting.
[loop == 2] You don't sit up at all. You look at Wren, ash to the elbows, alive, cross, writing names in two columns, and you can't breathe properly.
[loop == 2] You don't know if this is the worst thing that has ever happened to you, or the best.
[loop > 2] You lie still and let them say it. It's easier, the more you hear it. That frightens you a little.
[not k("hours_stirs")] Something has come back with you that wasn't there the first time: a slow tick under your ribs, the College's own Sphere. The Hours.
[not k("hours_stirs")] + learn hours_stirs
[not k("model_rewind")] + model rewind
* Answer Wren -> wake_again_ask

=== wake_again_ask
* "There's a dwarf under the half-bakery." [k("brogan") and not seen("wake_a_brogan")] -> wake_a_brogan
* Read the year's omens [omens_offered()] -> omens
* Get up -> wake_again_ledger

=== wake_a_brogan
Wren: A dwarf. In Vellmar. Under a bakery.
Wren writes it down.
Wren: Of course there is.
* Say something else -> wake_again_ask

=== wake_again_ledger
Under your pillow, the black Ledger. The first eleven pages in the small careful hand. Page twelve: "Don't trust the morning."
After it, in your own hand, everything you lived last year, already written.
[loop == 2] At the bottom of the next blank page, in the small careful hand that isn't yours, one line. You're almost sure it was written while you watched.
[loop == 2] "Welcome back."
[loop == 3] On the next blank page, in the small careful hand: "You lit them one at a time. Why one at a time?"
[loop == 4] On the next blank page, in the small careful hand: "The dwarves are lying about the ledger. Not the way you think."
* Get up

# --- S2. Crane's first lesson (Ashmoon 3, Morning; Ashmoon 4 if you missed it) --------------------
# The Model study isn't a screen yet: each of the seven strokes is a choice, and the Kindle lights
# by how many you got right (count("door_")).

=== crane_lesson
place: college_tents
days: 3-4
times: morning
when: not seen("crane_lesson")
known: true
title: Crane's first lesson
There are nine Magisters left alive and two hundred apprentices, so the College does what it always said it never would. It teaches in a field.
Magister Ottilie Crane takes the first class herself. She's small, sixty, in a Magister's blue with the hem cut off where it burned. She doesn't say good morning.
Crane: Hands out. Palms up. Don't draw yet.
Crane: Three days ago the most powerful instrument ever made broke over our heads, and every one of you has spent those three days wondering whether it was your fault.
Crane: It was not. You are not that important. Put it down.
+ learn crane
[k("seven_doors")] She turns her palm over the dead brazier, and the Kindle's figure turns above it. You know every stroke before she draws it.
[k("seven_doors")] Crane: (frowning) You hold the figure like someone who's been corrected before.
* Draw the seven doors, the way you know them [k("seven_doors")] -> crane_good
* Watch her draw [not k("seven_doors")] -> crane_figure

=== crane_figure
She turns her left palm over the dead brazier. A hand's width above it a figure appears: three circles of faint red light, threaded with seven short strokes. The coals catch from the centre out.
Crane: That's the Kindle. Every lamplighter's child in the Reach can do it by twelve. Most of you did it wrong.
Crane: Seven strokes, because fire has to breathe. Each stroke is a door for air. Close one and the flame starves on that side and leans. Close all seven and you get a very hot little stone that will burn your hand off.
She holds up her left hand. The last two fingers are missing.
Crane: I was nineteen. I knew the figure. A Model is not a shape. It's an argument you make to the world, and the world is a pedant.
Crane: You. Draw. Seven doors, one at a time. Tell me what each one is for as you build it.
* Draw the first stroke -> door_1

=== door_1
The first stroke, at the top of the inner circle.
* "It lets the air in." -> door_1_right
* "It holds the heat." -> door_2
* "It points the flame." -> door_2

=== door_1_right
+ set door_1
* Draw the second stroke -> door_2

=== door_2
The second stroke, crossing the first ring low on the left.
* "It feeds the air down to the heart." -> door_2_right
* "It lets the smoke out." -> door_3
* "It keeps the shape." -> door_3

=== door_2_right
+ set door_2
* Draw the third stroke -> door_3

=== door_3
The third, the mirror of the second on the right.
* "It's there for balance." -> door_4
* "It feeds the other side, so it doesn't lean." -> door_3_right
* "It makes it hotter." -> door_4

=== door_3_right
+ set door_3
* Draw the fourth stroke -> door_4

=== door_4
The fourth, a short stroke straight up from the heart.
* "It lets the smoke out." -> door_4_right
* "It draws the flame up." -> door_5
* "It's where the fire starts." -> door_5

=== door_4_right
+ set door_4
* Draw the fifth stroke -> door_5

=== door_5
The fifth and sixth, a pair low on the outer circle.
* "They hold the coal up off its own ash." -> door_5_right
* "They're decoration." -> door_6
* "They spread the fire wider." -> door_6

=== door_5_right
+ set door_5
* Draw the seventh stroke -> door_6

=== door_6
The seventh, a long faint stroke all the way round, joining the other six.
* "It holds them all open together." -> door_6_right
* "It shuts the fire in." -> door_7
* "It makes it look finished." -> door_7

=== door_6_right
+ set door_6
* Pour Mars into the figure -> door_7

=== door_7
Mars is a long way off for you. A fire seen across a valley. A thread of warmth comes.
Crane: Less than a spark. (Not unkindly.) Good. People who hear Mars loudly pour it in like a bucket and never learn what the strokes are for.
* See what lights [count("door_") >= 6] -> crane_good
* See what lights [count("door_") >= 1 and count("door_") < 6] -> crane_lean
* See what lights [count("door_") == 0] -> crane_burn

=== crane_good
The figure steadies, stroke by stroke, as if each one had been waiting to be told. The coal catches and stays caught.
Crane: (a long look) Hm. Again tomorrow. Don't get proud; it's a coal.
+ set doors_all
+ learn seven_doors
* Leave

=== crane_lean
The flame catches and leans away from the doors you got wrong, like a plant away from a cold window.
Crane: See where it leans? That's your mistake, drawn for you. Fix it before supper.
+ learn seven_doors
* Leave

=== crane_burn
The figure closes in on itself. The coal flares white and your palm stings.
Crane: There. Now you know something the primer couldn't tell you. Again.
+ learn seven_doors
* Leave

=== crane
talk: crane
repeat: true
priority: -10
Crane: Hands out of your sleeves, apprentice. A wizard who can't see their own hands can't see their figure.
* Leave

# --- S3. Marrow's first lesson: Alignment (Ashmoon 5, Morning; Sol's day after) --------------------

=== marrow_lesson
place: college_tents
days: 5-6
times: morning
when: not seen("marrow_lesson")
known: true
title: Marrow's first lesson
Lector Thessaly Marrow sits on an upturned crate with a board across her knees. The board is covered in vellum, and the vellum is covered in pinpricks.
The flash on the night took her eyes. She reads the sky now by the dots her students prick for her, and she is faster than she was sighted.
Marrow: You're the Provost's one. The quiet chart.
Marrow: Good. Quiet charts listen. Stand on the stone, Observer.
A flat star stone, chalked with a circle.
+ learn marrow
* Stand still -> marrow_still

=== marrow_still
Marrow: Stand still.
You: I am still.
Marrow: Your heart isn't. Your breath isn't. Your opinion of me certainly isn't.
Marrow: The sky does not answer people who are in a hurry, Observer. Again.
* Shift your weight, and wait -> marrow_moved
* Breathe out, and let the second come -> marrow_good

=== marrow_moved
Marrow: You moved. I heard your boot. Again.
* Stand still -> marrow_still

=== marrow_good
The chalk circle at your feet sharpens, as if someone had drawn it again with a finer hand. The bolt you send at the far post runs further and straighter than it has any right to.
Marrow: There. That's Alignment. One honest second. Most wizards die without managing one.
Marrow: I teach on the Sun's day. Come every week, or don't come.
+ learn alignment
* Leave

=== marrow
talk: marrow
repeat: true
priority: -10
[time == "night"] Marrow: Hush. Mars is up, and he's in a temper.
[time != "night"] Marrow: Observer. Stand still when you talk to me. There. Better.
* Leave

=== wren
talk: wren
repeat: true
priority: -10
Wren: (not looking up) Found, found, not found. Found. Sorry. What?
* Leave
