# The fallen city of Vellmar (design/places/ring1-places-and-fights-spec.md §4.1; build item
# N-7.1.2): the wall gap you arrive at, the Sunken Square's shrine and fountain, the glassworks'
# lens and the loft behind it, Wick Lane's house, the Archive gate's plaque and the crater's lip.
# And the city's fights (N-7.1.6). The format is in scripts/game/story.gd.

=== wall_gap
arrive: wall_gap
priority: 10
The road ends at a breach in the city wall. Past it, Vellmar: black roofs, black chimneys, streets of ash.
Nobody has swept these streets since the night the sky broke.
A Watch lamp hangs from a pole in the gap. Someone still trims its wick.
* Go on

=== square
arrive: sunken_square
priority: 10
The whole square has dropped a yard into the earth, flagstones and all. Six lamps lean over it, every one of them dark.
On the east side the ground gave way altogether. An old watchtower leans over the gap.
* Go on

=== city_shrine
use: shrine
repeat: true
A small Orrery shrine, half-buried in the square's tilted flags. Its rings still turn.
* Change the spellbook -> city_shrine_book
* Leave

=== city_shrine_book
+ book

=== city_fountain
use: fountain
repeat: true
The fountain's basin is dry and cracked. Coins lie in the dust at the bottom, black with soot.
Nobody has taken them. Out here, that says more than any sign.
* Leave

=== glass_lens
use: lens
repeat: true
A great lens of green glass hangs in an iron cradle, aimed at nothing. Three tall mirrors stand around the yard on pivots, each facing a different way.
[not k("glass_fuse")] Light off the mirrors could be passed from one to the next, if they were turned right. A firm knock would turn one.
[k("glass_fuse")] You know where the light should land: a fuse, set in the wall by the loft stair.
* Leave

=== glass_loft
arrive: glass_loft
priority: 10
A glassblower's loft, hidden behind a false wall. Notes cover the bench, the walls, the underside of the shelves.
[not k("glass_notes")] Most of it is about light: how to fold it, how to keep it, how to send it back.
+ learn glass_notes
* Go on

=== wick_notice
use: wick_house
repeat: true
A narrow house on Wick Lane, its door whole and its shutters closed. A Watch notice is nailed beside the step: FOR SALE BY ORDER OF THE WATCH. APPLY AT THE CAMP.
* Leave

=== crater_view
use: crater
repeat: true
The street simply stops. Below, the crater falls away for a mile, its far side lost in haze.
[time == "night" or time == "dusk"] Something down there glows, faint and steady, like an ember under ash.
The old road down the crater wall is buried under a rockfall.
* Leave

=== archive_plaque
use: archive_plaque
repeat: true
A brass plaque beside the Archive gate.
[not f("plaque_clean")] Soot has caked it black. You can't read a word of it.
[f("plaque_clean")] THE ARCHIVE OF THE COLLEGE OF HOURS. ENTRY BY THE COLLEGE'S KEY ALONE.
[f("plaque_clean")] + learn archive_key
* Leave

=== plaque_washed
use: archive_plaque
cast: water
The water runs black down the brass, and letters come up through the soot.
+ set plaque_clean
+ learn archive_key
THE ARCHIVE OF THE COLLEGE OF HOURS. ENTRY BY THE COLLEGE'S KEY ALONE.

=== plaque_warmed
use: archive_plaque
cast: fire
The soot crackles and flakes away in the heat. Under it, the letters are cut deep.
+ set plaque_clean
+ learn archive_key
THE ARCHIVE OF THE COLLEGE OF HOURS. ENTRY BY THE COLLEGE'S KEY ALONE.

# --- the city's fights (N-7.1.6; places spec §10.2) -----------------------------------------

=== cinder_row_here
arrive: cinder_row
times: morning, noon, afternoon
repeat: true
priority: 5
when: not done("cinder_row") and since("cinder_row_won") >= 28
+ today cinder_row
Scavengers are stripping lead off the burned roofs of Cinder Row. A man with a crossbow on a roof sees you first.
"This street's spoken for, friend. Keep walking."
* Stand your ground -> cinder_row_go
* Back away

=== cinder_row_go
+ fight cinder_row
? won -> cinder_row_won
? lost -> cinder_row_lost

=== cinder_row_won
They break for the wall and leave their lead behind. Cinder Row is quiet until they work up the nerve to come back.
+ today cinder_row_won

=== cinder_row_lost
You come to in the ash with your pockets turned out. They didn't take your life. They didn't think it was worth much.


=== square_nest_here
arrive: sunken_square
times: night
repeat: true
priority: 5
when: not done("square_nest") and since("square_nest_won") >= 3 and day <= 28
+ today square_nest
Something moves among the leaning lamps. Then everything does: Hollows, climbing out of the square's broken edge, more of them than you can count at once.
* Fight them -> square_nest_go
* Back away

=== square_nest_go
+ fight square_nest
? won -> square_nest_won

=== square_nest_won
The square goes still. The shrine's rings tick round in the dark, and nothing else moves.
+ today square_nest_won


=== square_choir_here
arrive: sunken_square
times: night
repeat: true
priority: 5
when: not done("square_nest") and since("square_nest_won") >= 3 and day > 28
+ today square_nest
Something moves among the leaning lamps. Then everything does, and under the shuffling there's a sound like singing, if a crowd could sing with one throat.
* Fight them -> square_choir_go
* Back away

=== square_choir_go
+ fight square_choir
? won -> square_choir_won

=== square_choir_won
The square goes still, and the singing with it. The shrine's rings tick round in the dark.
+ today square_nest_won


=== glassworks_here
arrive: glassworks
repeat: true
priority: 5
when: not f("husk_down") and not done("glassworks")
+ today glassworks
The furnace mouths are cold, but the air in the glassworks hums. Something in the middle of the floor is leaking light, a man-shape gone thin as blown glass, with Hollows crouched round it like dogs round a fire.
* Fight it -> glassworks_go
* Back away

=== glassworks_go
+ fight glassworks
? won -> glassworks_won

=== glassworks_won
The thing in the middle of the floor comes apart like a dropped lamp. The hum stops. Nothing in here will leak again, not this life.
+ today glassworks_won
+ set husk_down


=== depot_here
arrive: lamp_depot
times: night
repeat: true
priority: 5
when: not done("depot") and since("depot_won") >= 3 and day > 28
+ today depot
Inside the depot the lamps on their racks are going out one by one, and not by any wind. Long shapes hang off them, drinking.
* Fight them -> depot_go
* Back away

=== depot_go
+ fight depot
? won -> depot_won

=== depot_won
The last of the lamp-drinkers falls off its rack. The depot is dark, but it's an ordinary dark.
+ today depot_won


=== watch_cell_here
arrive: old_watch
times: night
repeat: true
priority: 5
when: day >= 70 and day <= 83 and not done("watch_cell") and since("watch_cell_won") >= 3
+ today watch_cell
There's a light in the Old Watch, three floors up, where there shouldn't be anyone. Voices too, low and all together, like a lesson being learned by heart.
Someone at a window sees you. A shape breaks for the stairs.
* Go after them -> watch_cell_go
* Back away

=== watch_cell_go
+ fight watch_cell
? won -> watch_cell_won
? lost -> watch_cell_lost

=== watch_cell_won
The Old Watch goes quiet. Whoever they were, they won't meet here again soon.
+ today watch_cell_won

=== watch_cell_lost
You wake at the foot of the tower. Somebody dragged you out of the way before they left, which is more than you expected.



# --- commissions in the fallen city (N-7.6.3; people spec §6.3: C4, C8) -----------------------

=== com_c4_here
arrive: cinder_row
times: morning, noon, afternoon
repeat: true
priority: 6
when: commission_step("c4_salvage") == 0
The house with the green door is half a house now. The cellar stair goes down under a beam that's cracked right through. Three people are already picking over the rubble, and they've seen you.
Scavenger: Move along. This one's spoken for.
[commission_known("c4_salvage")] You know this: the box is under the stair, and the beam goes if you so much as breathe on it. Prop it first.
[commission_lost("c4_salvage")] Scavenger: You again. Didn't you learn?
* Prop the beam before anything else -> com_c4_shore
* Run them off -> com_c4_go
* Wait till they knock off for the day, then go in [commission_lost("c4_salvage")] -> com_c4_slow
* Leave it for now

=== com_c4_shore
You wedge a post under the cracked beam while they jeer at you. It holds. They stop jeering.
+ commission c4_salvage clean
+ commission c4_salvage work
* Now them -> com_c4_go

=== com_c4_go
+ fight com_salvage
? won -> com_c4_won
? lost -> com_c4_lost

=== com_c4_won
They decide it's somebody else's house after all. The strongbox is under the stair where the note said, heavier than it looks.
+ commission c4_salvage next

=== com_c4_lost
You wake on Cinder Row with a lump on your head and the rival crew long gone.
+ commission c4_salvage lose
+ downed 1 commission

=== com_c4_slow
They knock off at dusk. You go in after, by lamplight, very quietly, and come out with the box.
+ commission c4_salvage slow
+ commission c4_salvage next

=== com_c8_bell
arrive: bell_street
repeat: true
priority: 6
when: commission_step("c8_letters") == 1
The door on Bell Street is still on its hinges. Nobody answers. You slip the letter under it, and as you go you hear, or think you hear, someone pick it up.
+ commission c8_letters next
