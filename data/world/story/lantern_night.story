# Calamity 1, Lantern Night (N-7.5; seasons spec §8). Its frame is data/world/calamities.json and
# scripts/game/calamity.gd: at Night on Seedmoon 28, if you're in the camp, the onset scene plays
# and the Peak is fought where you stand; losing it ends the life. Elsewhere, it passes without you.
# The story layer (signs, preparations, the sealed scenes) is N-7.5.2. The format is in
# scripts/game/story.gd.

=== lantern_night_onset
The lamps go out.
Not all at once. One, at the end of the Gate row, then the next, then the next, a darkness running down the iron rail faster than a man can walk. Then the Market ring. Then the Square run. Then Mira's lane.
The mist comes up out of the city with nothing to stop it, and in the mist, on the north stair, something is climbing.
+ calamity_onset lantern_night
+ learn lantern_night
+ fight c1_peak
? won -> lantern_night_dawn

=== lantern_night_dawn
The mist thins. The east goes grey, then white, and the things on the stair go back down into the city as if they had somewhere to be.
+ calamity_dawn lantern_night
* Look at the Market
