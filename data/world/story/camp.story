# The survivors' camp (design/ruins/content.md §1, §6): waking on the cot, the camp's people,
# the dwarves' crate, the east gate, the watch's targets, the way down, and the Hollows that walk
# the College ruins at night. Beats C1 (Mira) and H4 (the crate). The format is in
# scripts/game/story.gd.

# --- waking ------------------------------------------------------------------------

# Omens (lives spec §6.4): curses taken for the whole life, read before you rise on the first
# morning of life 2 onwards. Their numbers are in data/world/lives.json "omens".
=== omens
The candle by the cot gutters, and the smoke lies in shapes over the canvas. You've learnt to read them. Each is a hard year you can choose, and a harder year teaches more.
Take as many as you dare. Once taken, an omen holds until the year is done.
* The Hard Sky: every foe stands up longer [not omen("hard_foes")] -> omen_hard_foes
* The Thin Well: your Aether returns at half the pace [not omen("thin_aether")] -> omen_thin_aether
* The Early Bell: the first calamity comes a moon sooner [not omen("early_calamity")] -> omen_early_calamity
* Get up

=== omen_hard_foes
+ omen hard_foes
The smoke settles over the shape of a raised fist. So be it.
* Read on -> omens
* Get up

=== omen_thin_aether
+ omen thin_aether
The smoke thins to a thread and nearly goes out. So be it.
* Read on -> omens
* Get up

=== omen_early_calamity
+ omen early_calamity
Somewhere a bell rings once, though no one is near it. So be it.
* Read on -> omens
* Get up

=== cot
use: cot
repeat: true
Your cot under the canvas, and your spellbook.
* Change the spellbook -> cot_book
* Meditate for a while [not done("meditate")] -> cot_meditate
* Sleep until dawn -> cot_sleep
* Leave

=== cot_book
+ book

=== cot_meditate
You sit cross-legged on the cot and draw the cold in, slow and even, until the shaking stops.
+ meditate 5

=== cot_sleep
You lie down and let the day go.
+ sleep

# --- the market --------------------------------------------------------------------

=== mira_c1
talk: mira
priority: 10
when: not k("carried_out")
Mira: You're up. Good. I wasn't sure you would be.
Mira: You know who brought you in? Neither do I.
Mira: A veiled figure left you at the east gate before dawn. Carried you, like you weighed nothing.
Mira: Then it went back the way it came. I've never seen anyone walk like that. I didn't like it.
+ learn mira
+ learn carried_out
* "Which way did it go?" -> mira_which
* Leave

=== mira_which
Mira: North. Back toward the College, and what's left of it.
* Leave

=== mira_thanks
talk: mira
priority: 8
when: f("lit_lane") and not f("mira_thanked")
Mira: Somebody lit my lane before I got round to it. That was you, wasn't it, College?
Mira: Saved me the oil and the ladder. Thank you.
+ set mira_thanked
* Leave

=== mira
talk: mira
repeat: true
priority: -10
[time == "dusk"] Mira: Can't stop. Lamps don't light themselves.
[time != "dusk"] Mira: Stay where the lamps are, after dark. Whatever came up out of the College doesn't like the light.
* Leave

=== pell_first
talk: pell
priority: 10
when: not k("wren_cipher")
Pell: You're from the College! You're alive! Anything you need, I'll find it. Rope, chalk, lamp oil. Anything.
Pell: You know Wren, don't you? Everyone knows Wren. Always scribbling in that star cipher of the College's. A hobby, Wren says.
Pell: Notes to people, in stars. I never could read them.
+ learn pell
+ learn wren_cipher
* Leave

=== pell
talk: pell
repeat: true
priority: -10
[time == "morning" or time == "noon"] Pell: Still here if you need anything. Anything at all.
[time != "morning" and time != "noon"] Pell: Someone should go down there. Someone who knows the College. Someone like you.
* Leave

=== captain_first
talk: captain
priority: 10
when: not k("captain")
Captain: Stop there. Nobody goes past the gate. Nobody goes down.
Captain: Halloway. Captain of the watch, what's left of it. Eleven of us.
Captain: We lost six last night to the things that walk up out of the College after dark.
Captain: ...You're one of theirs, aren't you. A College robe. Fine. I didn't see you. Be back before the lamps.
+ learn captain
* Leave

=== captain
talk: captain
repeat: true
priority: -10
Captain: I didn't see you. Lamps before dark, College.
* Leave

=== pie_seller
talk: pie_seller
repeat: true
The pie-seller hands you one pie, hot, and doesn't say what's in it.
* Leave

=== dog
talk: dog
repeat: true
The dog sniffs your hand, then your boots, then decides you're all right.
* Leave

=== dwarf_crate
use: dwarf_crate
priority: 5
when: not k("rune_ashlar")
A salvage crate of dwarf tools: crowbars, wedges, a lamp with a cracked glass.
Every handle is stamped with the same rune, three strokes like a cairn.
One of the dwarves, packing it, sees you looking. "Ashlar. The stone that holds. Our doors answer to it, if you ask them right."
+ learn rune_ashlar
* Leave

=== dwarf_crate_again
use: dwarf_crate
repeat: true
priority: -10
The dwarves' crate. Ashlar on every handle.
* Leave

# --- the Mill ------------------------------------------------------------------------

=== aldous_first
talk: aldous
priority: 10
when: not k("mill_cellars")
Aldous: Bread? Take it. There's little enough, but it's bread.
Aldous: Don't go near my cellar door. Things came up out of it the night the Orrery fell. Up the steps, out into the yard.
Aldous: I've nailed it shut. I hear them, some nights.
+ learn aldous
+ learn mill_cellars
* Leave

=== aldous
talk: aldous
repeat: true
priority: -10
Aldous: Flour and ash. Flour and ash.
* What's the sky doing tomorrow? -> aldous_weather
* Leave

# The forecast (seasons spec §3.5): Aldous reads tomorrow's weather off the rim.
=== aldous_weather
Aldous squints at the rim, where the cloud comes up off the plain.
+ forecast aldous
* Leave

# --- the square, the east gate -------------------------------------------------------

=== bench
use: bench
repeat: true
The Lamplighters' bench: a vice, a spirit lamp, racks of empty flasks and coils of copper wire.
[not k("model_spark_flask")] A Lamplighter looks up from her soldering. "Want to see how a flask is packed? Oil, a spark in the stopper, and keep it away from your face."
[not k("model_spark_flask")] + model spark_flask
* Ask about the lantern with the star-chart shade [mastered("astral_rite") and mastered("spark_artifice") and not k("model_star_lantern")] -> bench_lantern
* "About that road, Fennick." [offered("lamplighter") and f("fennick_later") and day < 7] -> fennick_road_yes
* "Rule one?" [on_road("lamplighter") and not f("rule_one")] -> rule_one
* Fill your devices (it takes a while) -> bench_fill
* Ask for spare stock [not f("bench_stock")] -> bench_stock
* Leave

=== bench_fill
You pour, stopper, wind wire and wipe your hands.
+ bench

=== bench_lantern
The Lamplighter turns the lantern so its shade throws stars across the bench. "College work and ours, in one glass. Only someone who knows both trades can hang it right."
She shows you how the chart lines up with the wick.
+ model star_lantern

=== bench_stock
The Lamplighter pushes a crate of oil and empty vials across the bench. "Bring me back the glass."
+ set bench_stock
+ bench stock

=== targets
use: targets
repeat: true
The watch's straw targets, more hole than straw.
* Train [not done("train")] -> targets_train
* Leave

=== targets_train
You drill until your hands ache and the target is more hole than straw.
+ train

=== east_gate
use: east_gate
priority: 5
when: not k("backward_prints")
The east gate, where Mira found you. Ash has drifted against the posts.
There are prints in it, coming out of the gate toward the camp. The heels are where the toes should be.
+ learn backward_prints
* Leave

=== east_gate_again
use: east_gate
repeat: true
priority: -10
The east gate. The backward prints are still there in the ash, as if nobody dares walk over them.
* Leave

# --- the way down --------------------------------------------------------------------

=== north_stair
use: north_stair
repeat: true
The north door is gone, and the wall round it. Where it stood, a stair goes down under the College into the dark.
Cold air comes up it, and a smell like a forge gone out.
* Go down (a descent takes the day) -> descend
* Not yet

=== descend
+ go north_stair

# --- night in the ruins ----------------------------------------------------------------

=== patrol
arrive: college, yard, archive, observatory, stairs, north_door, duel_ring, broken_wall, college_tents
times: night
repeat: true
priority: -5
when: not done("patrol")
+ today patrol
The ruins are quiet after dark. Then they aren't.
Shapes in the mist among the fallen stone, shuffling, wearing the clothes of people you might have known.
Hollows.
* Fight them -> patrol_fight
* Slip away

=== patrol_fight
+ fight patrol
? won -> patrol_won
? lost -> patrol_death

=== patrol_death
They come out of the mist from every side at once, and keep coming.
+ learn died_patrol
+ end_loop patrol

=== patrol_won
The Hollows fall still. Every one of them was someone, once.
+ wells 4

# --- the Eclipse ---------------------------------------------------------------------

=== eclipse
The Eclipse comes. Under the ruin, the Orrery's heart wakes a second time.
The light has no colour, and this time it doesn't stop at the College.
+ learn second_blast
+ end_loop eclipse

# --- fixed events (lives spec §6.2; data/world/calendar.json) -------------------------------

=== knights_arrive
backdrop: east_gate
Six knights in lead-sealed plate ride up the east road at dusk and pitch grey tents a bowshot from the wagons.
Their captain walks the last stretch alone, helmet under his arm, and stops at the edge of the light.
Dunmore: Knight-Captain Osric Dunmore, of the Iron Oath, on the Commander's business. We'll keep to our side of the fence.
Dunmore: We'll need the names of every wizard in the camp who casts fire. For your safety. You understand.
Behind him, a knight with very tired eyes is looking at you, and at nobody else.
[loop > 1] Maud: (to Dunmore, not to you) That one.
[loop > 1] Dunmore: (mildly) That one what, Dame Maud?
[loop > 1] Maud: ...Nothing. I thought I knew the face.
+ learn knights_camp
+ learn dunmore
+ set knights_camped
* Watch them a while
