# The first morning's drill (N-8.4; design/onboarding/first-30-minutes.md, piece A): at the Watch's
# straw targets in the square, life 1 only, until it's run or skipped. The fight `drill` ticks off
# one step at a time (slice.gd) and ends when they're done. Not story content: no SEALED lines.
# The format is in scripts/game/story.gd.

=== drill
use: targets
when: loop == 1 and not f("drill_done")
priority: 5
The watch's straw targets, more hole than straw. Someone has chalked the morning drill on the post, the way the Watch warms up before a shift.
Three straw men stand in a row. They won't hit back.
* Run the drill -> drill_go
* "I know how." -> drill_skip

=== drill_go
+ fight drill
? won -> drill_done
? lost -> drill_done

=== drill_done
The straw men lean, knocked crooked. Your hands remember the shapes now.
+ set drill_done
* Leave

=== drill_skip
You nod at the chalk and leave the straw men standing.
+ set drill_done
* Leave
