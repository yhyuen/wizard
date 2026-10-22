# The undercroft (design/places/ring1-places-and-fights-spec.md §4.3; build item N-7.1.3): the
# cistern-drain under the Sunken Square. The drain stair, the long channel, the sluice wheel that
# drains or floods it, and the grate up to the camp's market cellar (the drain shortcut). The
# channel's fight is N-7.1.6's. The format is in scripts/game/story.gd.

=== undercroft_stair
arrive: drain_stair
priority: 10
The stair ends in the dark under the square. Water drips somewhere ahead, and the air smells of rust and old rain.
A channel runs east from here, wide and black, toward the camp.
* Go on

=== sluice_room
arrive: sluice_room
priority: 10
An iron wheel as tall as a man stands in the wall, its spokes furred with rust. Chains run from it into the channel.
* Go on

=== sluice_wheel
use: sluice_wheel
repeat: true
The sluice wheel. Turned one way it opens the gates at the channel's end; the other way, it shuts them.
[f("channel_dry")] The channel below is drained to wet stone.
[not f("channel_dry")] The channel below runs knee-deep and black.
* Open the gates and drain the channel [not f("channel_dry")] -> sluice_drain
* Shut the gates and let it fill [f("channel_dry")] -> sluice_fill
* Leave

=== sluice_drain
You throw your weight on the spokes. Somewhere below, gates grind open, and the channel's water roars away into the dark.
+ set channel_dry

=== sluice_fill
You turn the wheel back. The gates groan shut, and the channel fills again, slow and black.
+ clear channel_dry

=== drain_grate
use: drain_grate
repeat: true
An iron grate in the vault overhead, rusted into its frame. Lamplight shows through it: the camp's market, right above you.
[not k("drain_open")] Its chain runs down to a post and a crate hung as a counterweight. A hard enough shove on the crate, or a strong charge down the chain, might drag the grate up.
[k("drain_open")] The grate stands open on its chain. The way to the camp is right there.
* Leave

# --- the undercroft's fight (N-7.1.6; places spec F9) ------------------------------------------

=== channel_here
arrive: channel
repeat: true
priority: 5
when: not done("channel") and since("channel_won") >= 3
+ today channel
Something stirs in the long channel: Hollows wading out of the dark, and behind them a few that walk the wrong way round, heels first.
* Fight them -> channel_go
* Back away

=== channel_go
+ fight channel
? won -> channel_won

=== channel_won
The channel goes still. Burn the backward ones, or they'll stand up again.
+ today channel_won

