# The east road (design/places/ring1-places-and-fights-spec.md §7; build item N-7.1.5): the road's
# end at the farm track, the toll bridge, the waystation's hearth and its cellar's vent, the
# quarry's claim stone and the Holds gate. The road's fights (the picket, the toll, the cellar,
# the ledge camp) come with N-7.1.6. The format is in scripts/game/story.gd.

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
