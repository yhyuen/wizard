# The Mill fields (design/places/ring1-places-and-fights-spec.md §6; build item N-7.1.4): the
# Mill bridge you arrive at, the pond's sluice and the islet stone, the mill cellar's cold crack,
# the wayside shrine and the east fence. The fields' fights come with N-7.1.6. The format is in
# scripts/game/story.gd.

=== mill_bridge
arrive: mill_bridge
priority: 10
The lane from the camp crosses the millrace on a timber footbridge. Beyond it the Mill fields run east to the moor, wheat gone to seed and nobody to cut it.
Somewhere ahead a mill wheel thumps round and round, the steadiest sound on the plateau.
* Go on

=== pond_sluice
use: sluice
repeat: true
A sluice gate at the pond's outflow, worked by a crank. Aldous keeps it shut to run the mill.
[f("pond_dry")] The pond is drained to mud and reeds. The wheel stands still.
[not f("pond_dry")] Out in the middle of the pond, a stone stands on an islet nobody can reach.
* Open the sluice and drain the pond [not f("pond_dry")] -> pond_drain
* Shut the sluice and let it fill [f("pond_dry")] -> pond_fill
* Leave

=== pond_drain
You wind the crank until the gate lifts. The pond pours out through the race, and the mill wheel slows, and stops.
Mud and reeds come up out of the water, and a dry path to the islet with them.
+ set pond_dry

=== pond_fill
You drop the gate. The water backs up, slow and brown, and after a while the wheel starts turning again.
+ clear pond_dry

=== islet_stone
use: islet_stone
repeat: true
A standing stone on the islet, older than the mill and older than the College. A blue light sleeps in a notch at its top.
[not k("islet_stone")] When you lay a hand on it, the stone hums, like a struck glass.
+ learn islet_stone
* Leave

=== wayside_shrine
use: wayside_shrine
repeat: true
A small Orrery shrine at the crossroads, under a dome no bigger than an umbrella. Someone has left a sheaf of wheat at its foot.
* Change the spellbook -> wayside_book
* Leave

=== wayside_book
+ book

=== cold_crack
use: cold_crack
repeat: true
At the end of the last aisle the cellar wall is split by a crack, and the crack is cold. Frost furs its edges in the middle of the day.
Whatever is behind it, it isn't letting you through. Not yet.
* Leave

=== scarecrow
use: scarecrow
repeat: true
A scarecrow on the fence line with an iron basket for a heart. Aldous lights it at dusk, to keep the things on the moor guessing.
* Leave
