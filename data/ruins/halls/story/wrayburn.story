# SPOILER: sealed Ring 1 story. The Kiln-master's cell behind the Kiln, Ring 1's inheritance (the
# Ring 1 story's Q-S7; people spec §12; build item N-7.6.8). Its three trial rooms are the map's
# `trials` (data/ruins/halls/map.json) and run in scripts/world/trials.gd. The format is in
# scripts/game/story.gd.

=== cell_seal
use: cell_seal
repeat: true
A doorway in the Kiln hall's west wall, bricked up long ago and well. The mortar is older than any wing of the College you know.
Warm air breathes through one crack, steady as a sleeper.
* Leave

=== qs7_cell
arrive: wrayburn_cell
priority: 10
when: not k("wrayburn") and not f("wr_begun")
A small room sealed so well the ash never got in. A desk, a cot, a fire grate swept clean ninety years ago.
Above the grate a figure hangs in the air, turning slowly, red and gold: a Model with no wizard holding it.
Wrayburn: (a voice from the figure, dry and amused, recorded) If you're hearing this, I'm dead and you've broken my door. Fine. Both happen.
Wrayburn: Magister Edda Wrayburn. Fire. I spent my life learning that the most useful thing a fire can do is stop.
Wrayburn: Three rooms. Light the first without burning it. Keep a flame alive in the second. Put the third out with fire. Then I'll show you something the College never let me publish.
+ set wr_begun
+ inherit wrayburn

=== qs7_again
arrive: wrayburn_cell
priority: 10
when: k("wrayburn") and not f("wr_begun")
The figure over the grate turns to face you before you're through the door.
Wrayburn: You again. One room, then. Any of them. I haven't got all century.
+ set wr_begun
+ inherit wrayburn

=== qs7_reward
when: f("wrayburn_three_done")
Wrayburn: Ha. Somebody finally listened.
The figure unfolds into a lattice of small fires held in a net, and folds itself into your mind like a letter into an envelope.
[k("wrayburn")] It's already there. It only wanted reminding.
+ model cinder_lattice
+ learn wrayburn
* Leave
