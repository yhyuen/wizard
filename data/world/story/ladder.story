# The camp's dueling ladder (N-7.6.4; people spec §7.1): the slate by the chalk ring in the College
# yard. Six rungs, one duelist each; challenge the rung above yours at Dusk, once a week. A duel to
# three clean hits, a KO or a yield; a loss is a bruise, not an injury. The format is in
# scripts/game/story.gd; the rungs are data/world/ladders/camp.json.

=== ladder_post
use: ladder_post
repeat: true
slot: free
A slate nailed to a post by the chalk ring, six names on it in a column, bottom to top. Somebody keeps it carefully: the chalk is fresh.
[rung() == 0] Your name isn't on it.
[rung() > 0 and rung() < 6] Your name is chalked partway up, where somebody else's used to be.
[rung() == 6] Your name is at the top. Somebody has drawn a small crown next to it, not entirely kindly.
[not (time == "dusk")] Bouts are at Dusk, when the yard's done working.
[time == "dusk" and not ladder_open() and rung() < 6] You've had your bout this week.
* Challenge Garrow Pike for the first rung [time == "dusk" and ladder_open() and rung() == 0] -> ladder_1
* Challenge Mother Thistle for the second rung [time == "dusk" and ladder_open() and rung() == 1] -> ladder_2
* Challenge Dunstan Webb for the third rung [time == "dusk" and ladder_open() and rung() == 2] -> ladder_3
* Challenge Aldric Vey for the fourth rung [time == "dusk" and ladder_open() and rung() == 3] -> ladder_4
* Challenge Nerys Hale for the fifth rung [time == "dusk" and ladder_open() and rung() == 4] -> ladder_5
* Challenge Silas Vane for the top of the ladder [time == "dusk" and ladder_open() and rung() == 5] -> ladder_6
* Leave

=== ladder_1
Garrow Pike steps into the ring with a quarterstaff across his shoulders and no magic at all, and the yard cheers him like an old friend.
Garrow: Three clean hits, wizard. No tricks, no fire on the crowd. I'll go easy.
[ladder_book(1)] You know him: the rush, the lunge, and the step back after every swing. That's when to cast.
+ ladder bout
+ fight ladder_1
? won -> ladder_won
? lost -> ladder_lost

=== ladder_2
Mother Thistle walks in with a basket on her arm and a smell of lamp oil about her. She sets the basket down outside the chalk, very carefully.
Thistle: Mind your feet, dear. The ground's not always on your side.
[ladder_book(2)] You know her: the oil comes first, where you're standing. The circle shows before it lights.
+ ladder bout
+ fight ladder_2
? won -> ladder_won
? lost -> ladder_lost

=== ladder_3
Dunstan Webb wears the Guild's brass on his collar and a charged rod on his hip. He flicks the rod, and a spark jumps between his fingers.
Dunstan: Fennick says I'm wasting charge on this. Fennick says a lot of things.
[ladder_book(3)] You know him: one spark from across the ring, then he stands winding the charge again.
+ ladder bout
+ fight ladder_3
? won -> ladder_won
? lost -> ladder_lost

=== ladder_4
Aldric Vey ducks under the rope in his surcoat, shield on his arm, and salutes you with the flat of his blade.
Aldric: By the Oath, then. Yield when you've had enough. There's no shame in it.
[ladder_book(4)] You know him: shield up, walking you down. It only faces one way.
+ ladder bout
+ fight ladder_4
? won -> ladder_won
? lost -> ladder_lost

=== ladder_5
Nerys Hale is wet to the knees, as if she's walked up out of the river to get here. Her breath steams in the dusk.
Nerys: The Drowned don't usually bother with camp games. Consider yourself honoured.
[ladder_book(5)] You know her: frost from the far side of the ring, quick to wind up, and it breaks if you hit her first.
+ ladder bout
+ fight ladder_5
? won -> ladder_won
? lost -> ladder_lost

=== ladder_6
Silas Vane is already in the ring, leaning on his staff as if he's been waiting all week. He probably has.
Silas: Top of the slate. College rules: three clean hits, and nobody dies, however much one might like to.
[ladder_book(6)] You know him: the Arc Lance first, from across the ring, and then a moment of admiring it.
+ ladder bout
+ fight ladder_6
? won -> ladder_won
? lost -> ladder_lost

=== ladder_won
The yard roars. Someone wipes the slate and chalks your name a rung higher, and someone else puts a purse in your hand.
+ ladder win

=== ladder_lost
You pick yourself up out of the chalk, bruised and no worse. The yard is kind about it, mostly. Next week, then.
