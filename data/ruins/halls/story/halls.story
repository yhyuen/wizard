# The College halls (design/ruins/content.md §2-6): the landing and its shrine, the entrance hall,
# the long way (refectory, lecture gallery) and the short way (the rune door, the bell passage) to
# the Kiln antechamber, the cistern and its sluice, and the Kiln Warden. Each room's fight comes
# once a descent (a descent is a day: climbing out ends it).
# The format is in scripts/game/story.gd.

=== landing
arrive: landing
priority: 10
The stair ends on a landing. The College halls go on in the dark beyond it, deeper than you remembered.
[not k("the_halls")] The blast went down as well as up.
+ learn the_halls
A small Orrery shrine stands by the wall, its rings still turning, as if nothing had happened.
The stair you came down is at your back, if you want the daylight.
* Go on

=== sighting
arrive: entrance_hall
priority: 30
You come up into the entrance hall, and stop.
+ play_path sighting
+ learn figure_ahead
+ goto entrance_hall

=== entrance_hall
arrive: entrance_hall
repeat: true
priority: 20
when: not done("hall_fight")
+ today hall_fight
The entrance hall. Half its columns still stand. Somewhere far off, something ticks, slow and heavy.
A seam in the west wall begins to glow, orange as a forge, and things stir between the columns.
+ fight hall_fight
? lost -> hall_death
The last ember gutters out on the flagstones. The west seam was first to glow; the east one followed.
+ learn crack_order

=== shrine
use: shrine
repeat: true
A small Orrery shrine. Its brass rings turn round a gold core, slow and patient.
[not can_turn()] You lay a hand on the rings. They won't stop for you, not yet. Not until the year has struck once.
* Change the spellbook -> shrine_book
* Turn back the Hours [can_turn()] -> shrine_release
* Leave

=== shrine_book
+ book

=== shrine_release
You lay your hand on the rings and stop them. The year will begin again; everything you hold stays here.
You let it slip out of you like a held breath.
+ learn shrine_release
+ end_loop turned

=== rune_door
use: rune_door
repeat: true
A door of dressed stone, sealed with a dwarf rune: three strokes like a cairn, lit from within.
[not k("rune_ashlar")] You fix its shape in your memory.
[k("rune_ashlar")] Ashlar, the rune from the dwarves' crate. You trace its three strokes, they flare, and the door grinds aside.
+ learn rune_shape
[k("rune_ashlar")] + open rune_door
[k("rune_ashlar")] + learn rune_opened
* Leave

=== stair_back
use: stair_back
repeat: true
The stair goes up to the camp. A descent takes the day: once you climb out, you sleep.
* Climb out -> stair_climb
* Stay down here

=== stair_climb
You climb toward the grey light, and by the time you reach the camp the day is gone.
+ sleep

=== collapsed_stair
use: collapsed_stair
repeat: true
[not f("stair_mended")] The stair north is choked with fallen stone, from floor to vault.
[not f("stair_mended")] Fresh chalk on the rubble: a circle cut through by a line. Somebody marked this fall. The stair was brought down on purpose.
[not f("stair_mended")] + learn stair_cult
[not f("stair_mended") and k("hours_stirs")] The stones still remember where they stood. A Rewind might put them back.
[f("stair_mended")] The stair north stands whole again, the chalk circle with it, as if it had never fallen.
* Leave

=== stair_mend
use: collapsed_stair
cast: hours
repeat: true
when: not f("stair_mended")
The Rewind takes hold of the fall. Stone by stone the stair climbs back into its place, until the way north to the cistern stands open.
+ open collapsed_stair
+ set stair_mended
+ learn stair_mend

=== great_clock
use: great_clock
repeat: true
The College's great clock, fallen from its tower into the hall. Its hands stopped at the hour of the Eclipse.
[k("hours_stirs") and not k("provost_crossed")] The Hours tick under your ribs as you look at it. A Rewind would turn its hands back.
* Leave

=== clock_replay
use: great_clock
cast: hours
repeat: true
+ play_path provost_eclipse
+ learn provost_crossed

# --- the long way ----------------------------------------------------------------------------

=== hall_death
The embers close in. The last thing you see is the west seam kindling again, first, as it did before.
+ learn crack_order
+ end_loop fight:hall_fight

=== refectory
arrive: refectory
repeat: true
priority: 20
when: not done("refectory_fight")
+ today refectory_fight
The refectory. The long tables are still laid, under a skin of ash.
Along the walls four seams kindle one after another, always in the same order.
+ fight refectory_fight
? lost -> refectory_death
The seams go dark in the order they lit.

=== refectory_death
You go down among the tables. Each ember that dies bursts into a puddle of fire, and you were standing in too many of them.
+ learn ember_burst
+ end_loop fight:refectory_fight

=== gallery
arrive: gallery
repeat: true
priority: 20
when: not done("gallery_fight")
+ today gallery_fight
The lecture gallery. Its lamps hang dead along both walls, and in the dark between them the cracks begin to glow.
Embers keep out of lamplight, like the Hollows do. Fire would light those lamps.
+ fight gallery_fight
? lost -> gallery_death

=== gallery_death
They catch you in the dark between the dead lamps. Not one of them came near the lamp you fell against.
+ learn ember_light
+ end_loop fight:gallery_fight

=== wren_chalk
use: wren_chalk
repeat: true
A mark in chalk on the gallery wall, small and neat: a row of star signs and an arrow.
[k("wren_cipher")] The College's old star cipher, Wren's hobby. It reads: the sealed door. The arrow points east, back toward the entrance hall.
[not k("wren_cipher")] A cipher of some kind. Someone in the camp might know it.
+ learn wren_chalk
* Leave

# --- the short way ---------------------------------------------------------------------------

=== bell_passage
arrive: bell_passage
priority: 10
A narrow passage, half filled by the College bell. It fell from its tower and came to rest here on its side, its crown split.
Nothing moves. The passage runs on north, toward the heat.
+ learn short_route

# --- the Kiln --------------------------------------------------------------------------------

=== antechamber
arrive: antechamber
repeat: true
priority: 20
when: not done("ante_fight")
+ today ante_fight
The Kiln antechamber. Heat breathes out of the north arch.
Three figures get up off the floor the way dead men don't: backwards, as if their fall were being undone.
+ fight ante_fight
? lost -> ante_death

=== ante_death
A stone takes you from behind, from nowhere. Then you see it: their stones appear behind you and fly home to the hand.
+ learn backward_stones
+ end_loop fight:ante_fight

=== burnt_door
use: burnt_door
repeat: true
[day <= 9] The door to the cistern hangs in charred pieces. It was burnt open from the far side: the scorch fans out toward you.
[day <= 9] + learn burnt_far_side
[day >= 10] The door to the cistern is whole: new oak, cool to the touch, without a mark on it.
[day >= 10 and k("burnt_far_side")] You saw it burnt to its hinges. A door doesn't heal.
[day >= 10 and k("burnt_far_side")] + learn door_healed
[day >= 10 and k("burnt_far_side")] + learn doors_heal
[day >= 10] It won't open.
* Leave

=== sluice
use: sluice
repeat: true
[not done("sluice")] A great iron wheel on a stone stem, with sluice gates under it. A channel runs from them down toward the Kiln.
[done("sluice")] The sluice stands open. Water runs down the channel toward the Kiln.
* Turn the wheel [not done("sluice")] -> sluice_turn
* Leave

=== sluice_turn
You put your back into it. The wheel grinds a quarter turn, then another, and the cistern roars away down the channel.
+ today sluice
+ learn sluice_flood

=== kiln_hall
arrive: kiln_hall
repeat: true
priority: 20
when: not f("warden_down")
The Kiln hall. At its far end the College's great furnace squats on its plinth, and it is awake: its grate glows, and it turns to face you.
[done("sluice")] Water runs down the wall from the channel and steams across its grate.
[k("trial_warden")] It knows you. It doesn't bother with the rings: its vents open at once.
* Face it -> warden_fight
* Back away -> warden_back

=== warden_back
You back out under the arch. The heat follows you a little way, then lets you go.
+ move ante_c

=== warden_fight
+ fight warden
? won -> warden_won
? lost -> warden_death

=== warden_death
The fire closes over you.
Before it does, you see it again: each time the cracked pipe drips onto the grate, the Kiln Warden flinches.
+ learn warden_water
+ end_loop fight:warden

=== warden_won
The grate gutters and goes dark. The Kiln Warden settles on its plinth like a banked fire, and is still.
Something settles in you as well: a Ring closes round your power.
+ set ring1
+ set warden_down
+ trial warden
Beyond it, the Archive stair goes up into the dark.

=== archive_stair
use: archive_stair
repeat: true
The Archive stair climbs past the Kiln into the dark, choked with fallen stone a few steps up.
A draught comes down through the gaps, smelling of old paper.
* Climb to the Provost's study with Wren [f("warden_down") and f("daybook_yes") and day == 67 and not f("daybook")] -> daybook_study
* Sit on the bottom step and rest (the end of the first playable) [f("warden_down")] -> end_card
* Leave

=== end_card
+ end_loop first_playable_end

# --- S7, Wren's book (SEALED story content; the life 1 main line, N-7.3.2) ----------------------

# Wren meets you here on Seedmoon 11 if you said you'd come (apprentice.story). The study is a
# scene at the top of the stair for now, not a room.
=== daybook_study
Wren is sitting on the bottom step with a lantern between their boots. They don't say anything; they just get up and climb, and you climb after them, over the fallen stone, into the dark.
The Provost's study is the only room in the halls that still looks like a room. The ash has settled on it like a dust sheet.
The daybook is on the reading stand, open, as Wren said. His handwriting runs right to the edge of the page.
Wren reads the last page by your Kindle-light. Their face does something you don't have a word for.
Wren: Later.
They close the book. The word means "never ask me".
+ set daybook
+ learn daybook_hand
+ learn lens_schedule
+ learn polish_margin
* Go back down the stair -> daybook_stair

=== daybook_stair
The stair under you ages.
There's no other word. The oak treads grey, split, sag and powder in the time it takes to look down. A hundred years in a heartbeat.
You fall one storey into the room below. Wren, a step above you, doesn't.
+ downed 3 fall
* Let go
