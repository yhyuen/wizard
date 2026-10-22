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
when: not done("mill_cellar") and since("mill_cellar_won") >= 3 and day > 28 and not f("mill_burned")
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


# --- S4, the cellar thing (the life 1 main line; Aldous asks in data/world/story/apprentice.story) --

=== cellar_first
arrive: mill_cellar
priority: 8
when: f("cellar_asked") and not f("cellar_done") and not f("cellar_patient_1")
The cellar door is set into the hillside under the mill. Inside, the dark smells of dust and barley and something like a snuffed candle.
The sacks are stacked to the beams in long aisles. Your lantern makes one small room of light that moves when you move.
At the end of the first aisle, where the light stops, something is sitting in the dark.
You can't see it. You can see where it is, because there is a place the lantern-light doesn't go. Not a shadow. A shadow has edges. A patch of less.
When you step forward it doesn't move. When you step back, it's a step closer.
+ learn the_less
* Build the Kindle here and now -> cellar_fire
* Hang the lantern on the hook and back away slowly -> cellar_patient

=== cellar_fire
Seven doors. You name them as you lay them. North for draw. South for spread.
The Kindle doesn't light a lamp. It lights the air in front of you: a ball of honest flame the size of a fist.
For the first time you see the thing in the dark. A man, sitting on a seed sack with his hands on his knees. You can see the sacking through his chest. His face is a smooth place, like a page with the ink washed off.
The light touches him and he flinches. He turns his washed-out face aside, like someone in bed when the shutters are opened.
He doesn't strike. He tilts his head at you, the way a dog does at a sound it almost knows.
And the flame falls.
It drops from your figure because you let go of it in fright, and it lands on the barley.
Dry grain doesn't catch. It goes.
+ ignite mill_cellar
+ sound cast_fire
In the light, more light than this cellar has held in three hundred years, you see what was sitting in the dark. Not one faceless man. A dozen, along every aisle, all turning their blank faces away from the fire like sleepers.
Then the roof beam comes down.
* Run -> cellar_after

=== cellar_after
+ move mill_pond
You're on the hillside on your hands and knees. The mill above you is burning.
Aldous is standing in the field with a bucket in each hand and no water in either, watching the camp's bread go up into the evening.
He doesn't shout. That's the worst of it.
Aldous: (after a long time) Well. It's not waiting any more.
Aldous: There's seed in the east barn. Not enough. (He puts the buckets down very carefully, as if they might break.) Not nearly enough.
+ set cellar_done
+ set mill_burned
+ deed burned_mill
+ remember aldous mill_burned
+ merit 5
+ standing miller -10
+ learn page_why
* Leave

=== cellar_patient
You hang the lantern on the hook at the end of the aisle and step back, slowly. The less doesn't follow into the light.
It sits at the edge of it, exactly at the edge, the way a cat sits at the edge of a rug it's been told off for.
Through the dark you feel it tilt its head at you, the way a dog does at a sound it almost knows.
One lamp. One aisle. That's a start.
+ set cellar_patient_1
+ today cellar
+ learn page_why
* Leave

=== cellar_aisle2
arrive: mill_cellar
priority: 8
when: f("cellar_patient_1") and not f("cellar_patient_2") and not done("cellar")
Your first lamp is still burning on its hook. The less sits where the second aisle goes dark, patient as a heron.
You carry a second lamp down the aisle a step at a time and hang it. It gives ground. Not much. Enough.
+ set cellar_patient_2
+ today cellar
* Leave

=== cellar_aisle3
arrive: mill_cellar
priority: 8
when: f("cellar_patient_2") and not f("cellar_done") and not done("cellar")
The third lamp goes up on the last hook. The cellar is a long room of light, all three aisles, sack after sack of seed barley, and nothing sitting on any of them.
At the end of the third aisle, where the less was, there's a crack in the floor. Cold breathes out of it, very steadily, like something asleep.
+ set cellar_done
+ set seed_saved
+ learn mill_crack
* Carry the seed up to Aldous -> cellar_seed

=== cellar_seed
Aldous: (looking at the sacks, not at you) Three days. I'd have said one torch and done.
Aldous: (He picks up a handful of barley and lets it run through his fingers.) Bread for Highsun.
Aldous: Tam. Fetch the good lantern back up. Leave the others. (To you.) I'm leaving the others.
+ remember aldous seed_saved
+ merit 15
+ standing miller 10
* Leave


# --- S8, two on the watch (the fixed event tam_fence: Seedmoon 12, Night, the Mill fields) --------

=== tam_fence_here
Captain Halloway's watchman, Dob, is alone on the east fence with a lantern that won't stay lit.
Dob: Supposed to be two of us. The other one's a wizard and the wizards are all off in the city looking for books.
At the far end of the fence, a boy and a goat. Tam has the rope. The goat has opinions.
Between Tam and the gate there's a patch of field where the lantern light doesn't go.
* Kindle the lantern -> tam_fence_light
* Call Tam to you -> tam_fence_call

=== tam_fence_call
Tam: (cheerful) It won't come! It's being a goat!
He laughs, and walks towards you with the rope, straight into the patch of less.
* Kindle the lantern, now -> tam_fence_light

=== tam_fence_light
Seven doors. The lantern takes the Kindle and holds it, steady and yellow.
The patch of less stops at the edge of the light. It sits there, exactly at the edge.
Tam walks the goat home through the gate in the light, talking to it the whole way.
Tam: You're a bad goat. You're the worst goat.
Dob: (letting his breath out) Two on the watch. Like it should be.
+ set tam_safe
* Leave
