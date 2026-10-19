# The College halls, R1 (design/ruins/content.md §2): the landing, its shrine, and the entrance
# hall, with the ways on still blocked. R2 adds the rooms beyond, the traces and the Kiln Warden.
# The format is in scripts/game/story.gd.

=== landing
arrive: landing
priority: 10
The stair ends on a landing. The College halls go on in the dark beyond it, deeper than you remembered.
[not k("the_halls")] The blast went down as well as up.
+ learn the_halls
A small Orrery shrine stands by the wall, its rings still turning, as if nothing had happened.
* Go on

=== entrance_hall
arrive: entrance_hall
priority: 10
The entrance hall. Half its columns still stand. Somewhere far off, something ticks, slow and heavy.
* Go on

=== shrine
use: shrine
repeat: true
A small Orrery shrine. Its brass rings turn round a gold core, slow and patient.
* Change the spellbook -> shrine_book
* Let this loop go -> shrine_release
* Leave

=== shrine_book
+ book

=== shrine_release
You lay your hand on the rings and stop them, and let the loop slip out of you like a held breath.
+ learn shrine_release
+ end_loop shrine

=== rune_door
use: rune_door
repeat: true
A door of dressed stone, sealed with a dwarf rune: three strokes like a cairn, lit from within.
[not k("rune_ashlar")] You fix its shape in your memory.
[k("rune_ashlar")] Ashlar, the rune from the dwarves' crate. It warms under your hand, and something behind the door shifts, and holds.
+ learn rune_shape
* Leave

=== collapsed_stair
use: collapsed_stair
repeat: true
The stair north is choked with fallen stone, from floor to vault.
* Leave
