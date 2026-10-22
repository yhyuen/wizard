# The fallen city of Vellmar (design/places/ring1-places-and-fights-spec.md §4.1; build item
# N-7.1.2): the wall gap you arrive at, the Sunken Square's shrine and fountain, the glassworks'
# lens and the loft behind it, Wick Lane's house, the Archive gate's plaque and the crater's lip.
# The city's fights come with N-7.1.6. The format is in scripts/game/story.gd.

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
