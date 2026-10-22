# Minigames in the camp (N-7.6.5; people spec §9): Star-charts (a riddle race on the night sky,
# with Wren, Brogan and Lector Marrow, at Dusk and Night) and Sparks (the Lamplighters' dice, with
# Mira, Pell and Kestrel; Kestrel's market table is work). Each opponent's talk scene offers the
# game. Texture, not story. The format is in scripts/game/story.gd; the games are
# data/world/minigames/*.json and scripts/game/minigames/.

=== charts_wren
Wren: (already unrolling a chart across her knees) Three riddles. You first. No, me first. No. You.
+ game wren free
? won -> charts_won
? lost -> charts_lost

=== charts_wren_coin
Wren: You again? You always know them. I don't know how. (She pays before you've sat down.)
+ game wren coin

=== charts_brogan
Brogan: Dwarves read stone, not sky. But a debt's a debt, and I've been studying. Go on, then.
+ game brogan free
? won -> charts_won
? lost -> charts_lost

=== charts_brogan_coin
Brogan: No. Not again. (He counts the coins into your hand himself.) Take it, before I change my mind.
+ game brogan coin

=== charts_marrow
Marrow: A sky riddle, Observer? Very well. Mind you, I set these for third-years.
+ game marrow free
? won -> charts_won
? lost -> charts_lost

=== charts_marrow_coin
Marrow: I have seen you do this before, somehow. I would rather not lose to you twice tonight. (She pays.)
+ game marrow coin

=== charts_won
You roll the chart up and hand it back. Up there, the stars go on not caring who won.

=== charts_lost
The sky was the same sky. You just read it slower.

=== sparks_mira
Mira: (shaking the brass cup) Four dice each. Lamps count as anything. Don't call dark unless you mean it.
+ game mira free
? won -> sparks_won
? lost -> sparks_lost

=== sparks_pell
Pell: Oh, I'm terrible at this. Really. (He is not terrible at this.)
+ game pell free
? won -> sparks_won
? lost -> sparks_lost

=== sparks_kestrel
Kestrel: One game. Then you buy me something hot.
+ game kestrel free
? won -> sparks_won
? lost -> sparks_lost

=== sparks_kestrel_work
Kestrel: Table's yours till the lamps burn down. You take a wage, the house takes its cut, and you keep your ears open. People talk over dice.
+ game kestrel work
? won -> sparks_work_done
? lost -> sparks_work_done

=== sparks_won
The brass dice go back in their bag, still warm.

=== sparks_lost
You hand over the stake. The brass dice don't look sorry.

=== sparks_work_done
Kestrel: (counting the house's cut) Not bad. Same again, some other night.
