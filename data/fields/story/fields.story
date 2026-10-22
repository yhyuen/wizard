# The Mill fields (design/places/ring1-places-and-fights-spec.md §6; build item N-7.1.4): the
# Mill bridge you arrive at, the pond's sluice and the islet stone, the mill cellar's cold crack,
# the wayside shrine and the east fence. The fields' fights are N-7.1.6's. The format is in
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

# --- the fields' fights (N-7.1.6; places spec F10, F11, F17) --------------------------------

=== granary_raid_here
arrive: granary
times: night
repeat: true
priority: 5
when: day == 66 and not done("granary_raid")
+ today granary_raid
Lanterns at the granary, and men with sacks on the ladder. They want Aldous's grain, and they want it quiet.
"Walk on, wizard. This isn't your bread."
* Stop them -> granary_raid_go
* Back away

=== granary_raid_go
+ fight granary_raid
? won -> granary_raid_won
? lost -> granary_raid_lost

=== granary_raid_won
They drop the sacks and run for the road. Aldous will find his grain where it should be in the morning, and never know why.
+ today granary_raid_won

=== granary_raid_lost
You wake in the wheat at dawn. The granary door hangs open and half the sacks are gone.


=== fence_here
arrive: east_fence
times: dusk, night
repeat: true
priority: 5
when: not done("fence") and since("fence_won") >= 3
+ today fence
Out on the moor, shapes are coming down to the fence. Not wolves. They walk like people who've forgotten how.
* Hold the fence -> fence_go
* Back away

=== fence_go
+ fight fence
? won -> fence_won

=== fence_won
The last of them falls against the posts. The moor is empty again, as far as you can see, which isn't far.
+ today fence_won


=== mill_cellar_here
arrive: mill_cellar
times: night
repeat: true
priority: 5
when: not done("mill_cellar") and since("mill_cellar_won") >= 3 and day > 28
+ today mill_cellar
Down in the sack aisles something is tearing at the grain. Hollows, drawn by it the way moths are drawn to a lamp, and the air is thick with flour.
Fire would be a very bad idea in here.
* Fight them -> mill_cellar_go
* Back away

=== mill_cellar_go
+ fight mill_cellar
? won -> mill_cellar_won

=== mill_cellar_won
The aisles go still. Flour settles on everything, on you too, like snow.
+ today mill_cellar_won

