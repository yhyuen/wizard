# The east road (design/places/ring1-places-and-fights-spec.md §7; build item N-7.1.5): the road's
# end at the farm track, the toll bridge, the waystation's hearth and its cellar's vent, the
# quarry's claim stone and the Holds gate; and its fights (N-7.1.6): the Knights' picket, the
# toll, the smugglers' cellar and the ledge camp. The format is in scripts/game/story.gd.

=== road_end
arrive: road_end
priority: 10
The farm track drops off the plateau and becomes a proper road, wide enough for two carts, rutted deep by a hundred years of them.
East, it runs toward the rim and the mountains past it. Nobody has driven a cart down it since the Orrery fell.
* Go on

=== toll_sign
use: toll_sign
repeat: true
A board nailed to the toll hut, the paint fresher than the wood.
BRIDGE TOLL. FIVE CROWNS A HEAD. NO EXCEPTIONS, NO CREDIT, NO CASTING.
[day < 8] The hut is empty. Whoever wrote the board hasn't come back to collect yet.
* Leave

=== waystation_hearth
use: waystation_hearth
repeat: true
The coaching inn's great hearth, black with old smoke. Someone has kept it fed: there's dry wood stacked by the grate and the coals are still warm.
* Rest by the fire -> waystation_rest
* Leave

=== waystation_rest
You bank the fire, put your back to the warm stone and sleep with one eye on the door.
+ sleep

=== cellar_vent
use: cellar_vent
repeat: true
A grating low in the cellar's back wall, breathing out a smell of damp and pipe smoke. Somebody is down there.
Hay has been heaped against it, as if to hide it.
[k("smoke_vent")] The hay would burn. The smoke would have only one way to go.
* Leave

=== cellar_smoked
use: cellar_vent
cast: fire
The hay goes up with a roar and the smoke pours down through the grating. Below, someone starts to cough, then someone else, then all of them at once.
A bar scrapes. The cellar door bangs open.
+ learn smoke_vent
+ open cellar_door
* Meet them at the door [not done("cellar") and since("cellar_won") >= 28] -> cellar_go
* Let them go

=== quarry_claim
use: quarry_claim
repeat: true
A squared stone at the quarry's lip, cut with dwarf runes and, under them, plain letters for everyone else.
THIS STONE IS CLAIMED BY THE HOLDS. TAKE WHAT YOU NEED AND SAY WHO YOU ARE.
Nobody has said who they are for some time. The scaffolds are rotten and the ledges have new tenants.
* Leave

=== holds_gate
use: holds_gate
repeat: true
[day <= 28] A gate of black iron across the cutting, stood open and pinned back against the rock. Past it the road goes down into the mountain.
[day > 28] A gate of black iron across the cutting, shut and barred from the far side. Dwarf runes are chalked on it, fresh.
[day > 28] + learn holds_shut
* Leave

=== holds_road
use: holds_road
repeat: true
The road winds down into the mountain toward the Deep Holds. The dwarves let travellers in through Ashmoon. After that, they shut the gate.
+ learn holds_shut
The Holds are a road for another day.
* Turn back

# --- the road's fights (N-7.1.6; places spec F3, F13, F14, F15) -----------------------------

=== picket_here
arrive: knights_picket
times: morning, noon, afternoon
repeat: true
priority: 5
when: day >= 2 and not done("picket") and since("picket_won") >= 28
+ today picket
A picket of the Knights of the Iron Oath holds the road: a chain across it, a watch fire, a bell on a post, men in grey plate.
"Hands where we can see them, caster. No spells this side of the chain."
* Challenge them -> picket_go
* Back away

=== picket_go
+ fight picket
? won -> picket_won
? lost -> picket_lost

=== picket_won
The Knights fall back behind their chain and let you pass. They'll remember your face.
+ today picket_won

=== picket_lost
You wake on the road outside the chain with your hands bound and a headache. Someone cut the rope before they left.


=== toll_here
arrive: toll_bridge
times: morning, noon, afternoon
repeat: true
priority: 5
when: day >= 8 and not done("toll") and since("toll_won") >= 28
+ today toll
Brigands sit on the toll bridge with their boots on the rail. Their captain stands to meet you.
"Five crowns a head. You read the board."
* Refuse to pay -> toll_go
* Back away

=== toll_go
+ fight toll
? won -> toll_won
? lost -> toll_lost

=== toll_won
The captain calls it, and they go over the side of the bridge into the stream. The road east is open, for now.
+ today toll_won

=== toll_lost
You wake on the near bank with an empty purse. The captain has left you a crown for the ferryman, which is a joke, since there isn't one.


=== cellar_here
arrive: smugglers_cellar
repeat: true
priority: 5
when: not done("cellar") and since("cellar_won") >= 28
+ today cellar
The smugglers' cellar: low beams, stacked crates and a lamp swinging from a hook. Every face in it turns to the stair.
* Fight them -> cellar_go
* Back away

=== cellar_go
+ today cellar
+ fight cellar
? won -> cellar_won
? lost -> cellar_lost

=== cellar_won
The last of them goes down among the crates. Whatever they were moving, it's yours to find now.
+ today cellar_won

=== cellar_lost
You wake in the waystation yard. They've barred the cellar again, from the inside.


=== quarry_here
arrive: quarry
times: morning, noon, afternoon
repeat: true
priority: 5
when: not done("quarry") and since("quarry_won") >= 28
+ today quarry
A brigand camp has dug in on the quarry ledges under a rotten scaffold. Crossbows come up along the top ledge.
* Fight them -> quarry_go
* Back away

=== quarry_go
+ fight quarry
? won -> quarry_won
? lost -> quarry_lost

=== quarry_won
The ledge camp is empty. The scaffold creaks over the cold fires.
+ today quarry_won

=== quarry_lost
You wake at the foot of the scree, sore all over. They didn't bother to come down and finish it.



# --- commissions on the east road (N-7.6.3; people spec §6.3: C3, C6, C8) ---------------------

=== com_c3_here
arrive: waystation
times: dusk, night
repeat: true
priority: 6
when: commission_step("c3_round") == 0
The night round ends here, at the burned waystation. The lamps on the posts behind you are dark, and in the yard somebody laughs and then stops.
[commission_known("c3_round")] You know this: two of them in the yard and one with a crossbow up on the cart.
[commission_lost("c3_round")] The scouts are back in the yard, bolder than before.
* Light the post lamps on the way back first, then deal with them -> com_c3_lamps
* Deal with them -> com_c3_go
* Wait them out in the ditch till they move on [commission_lost("c3_round")] -> com_c3_slow
* Leave it for now

=== com_c3_lamps
One lamp after another, back up the road. Anyone watching from the waystation can see exactly where you are. That's rather the point.
+ commission c3_round clean
+ commission c3_round work
* Now the yard -> com_c3_go

=== com_c3_go
+ fight com_round
? won -> com_c3_won
? lost -> com_c3_lost

=== com_c3_won
The scouts are off down the road toward the toll bridge, and in no hurry to come back.
+ commission c3_round next

=== com_c3_lost
You wake by the waystation's hearth with your purse lighter and your pride lighter still.
+ commission c3_round lose
+ downed 1 commission

=== com_c3_slow
A cold night in a wet ditch. Near dawn the scouts get bored and go.
+ commission c3_round slow
+ commission c3_round next

=== com_c6_here
arrive: quarry
repeat: true
priority: 6
when: commission_step("c6_bully") == 0
A big man sits on a block of stone under the loose face of the quarry as if it were a throne. His two friends lean on their picks. The quarrymen keep their heads down.
Bully: You lost, wizard? This is my quarry. Rent's due.
[commission_known("c6_bully")] You know this: he goes down to his knees if you break his guard, and his friends go with him. The stores are stacked right behind him.
[commission_lost("c6_bully")] Bully: Back for more? Rent's gone up.
* Put him on his knees -> com_c6_go
* Talk the crew into standing up to him, the slow way [commission_lost("c6_bully")] -> com_c6_slow
* Leave it for now

=== com_c6_go
+ fight com_bully
? won -> com_c6_won
? lost -> com_c6_lost

=== com_c6_won
The bully kneels in the chips and grit with his hands up. His friends are already halfway to the road. The quarrymen watch him go in silence, and then somebody starts laughing.
+ commission c6_bully next
+ commission c6_bully work

=== com_c6_lost
You wake at the bottom of the quarry track with a headache shaped like a fist.
+ commission c6_bully lose
+ downed 1 commission

=== com_c6_slow
It takes all afternoon, and three speeches, and one quarrywoman who turns out to be very good with a shovel. The bully leaves without his rent.
+ commission c6_bully slow
+ commission c6_bully next

=== com_c8_picket
arrive: knights_picket
repeat: true
priority: 6
when: day >= 2 and commission_step("c8_letters") == 0
A squire at the picket takes the scribe's letter, reads the name on it, and goes red to the ears.
Squire: I'll see he gets it. (He won't say who "he" is.)
+ commission c8_letters next
