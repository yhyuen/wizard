# Commissions in the camp (N-7.6.3; people spec §6): the board in the square and the duty slate at
# the watch post, where jobs are taken and paid. The steps out in Ring 1 are in each map's story.
# Texture, not story: no clue, key, spell or road, no named fate. The format is in
# scripts/game/story.gd; the jobs are data/world/commissions.json.

=== board
use: board
repeat: true
slot: free
The commissions board: a door off its hinges, nailed to two posts. Notes pinned all over it, most of them weeks old.
[commission_board_empty()] Nothing new this week. Someone has chalked across the door: NOT NOW. LANTERN NIGHT.
* Take: The Lost Goat, 25 crowns [commission_posted("c1_goat")] -> c1_take
* Take: Bramble on the Mill Road, 30 crowns [commission_posted("c2_bramble")] -> c2_take
* Take: Salvage Rights, 35 crowns [commission_posted("c4_salvage")] -> c4_take
* Take: The Cellar Flood, 30 crowns [commission_posted("c5_flood")] -> c5_take
* Take: The Quarry Bully, 45 crowns [commission_posted("c6_bully")] -> c6_take
* Take: Rats in the Granary, 35 crowns [commission_posted("c7_rats")] -> c7_take
* Take: Letters Home, 20 crowns [commission_posted("c8_letters")] -> c8_take
* Hand over the goat [commission_step("c1_goat") == 1] -> c1_pay
* Tell the carter the road's clear [commission_step("c2_bramble") == 1] -> c2_pay
* Hand over the chest [commission_step("c4_salvage") == 1] -> c4_pay
* Tell the widow her cellar's dry [commission_step("c5_flood") == 1] -> c5_pay
* Tell the quarryman it's done [commission_step("c6_bully") == 1] -> c6_pay
* Tell the miller his loft's clear [commission_step("c7_rats") == 1] -> c7_pay
* Tell the scribe the letters are delivered [commission_step("c8_letters") == 2] -> c8_pay
* Leave

=== c1_take
A note in a careful hand, with a drawing of a goat that could be a dog. "LOST. Brown nanny, one horn, answers to Pepper. Last seen going out past the Mill. The herder at the board, mornings."
The herder is there, as it happens, and grips your hand in both of his.
Herder: She'll be in the old orchard, she always goes for the orchard. Only the dogs have got into it since the fall. Wild ones.
Herder: There's hay stacked in the ditch there. Don't you go burning it. Folk need that hay.
[commission_known("c1_goat")] You know where she'll be: the ditch between the second and third rows, under the hay.
+ commission c1_goat take

=== c1_pay
Pepper sees the herder and stops being difficult at once.
Herder: Look at her. Not a scratch. (He counts coins into your palm, and then one more.)
[commission_clean("c1_goat")] Herder: And the hay's all there, they tell me. I'm obliged.
+ commission c1_goat pay

=== c2_take
"BRAMBLE across the Mill road at the long field. Thorn as high as a cart and things nesting in it. CLEAR IT. Ask for the carter."
Carter: Burn it if you like, it's only bramble. But that's Aldous's fence along the east side, and he counts the posts.
+ commission c2_bramble take

=== c2_pay
Carter: Clear to the Mill? First time since winter. (He pays, and doesn't haggle.)
[commission_clean("c2_bramble")] Carter: And the fence still standing. Aldous'll be pleased, not that he'll say so.
+ commission c2_bramble pay

=== c4_take
"SALVAGE RIGHTS, Cinder Row, the house with the green door. Strongbox in the cellar. Mine by right. Others say different. 35 crowns to whoever brings it up."
Scavenger: (a small woman with a large crowbar) The beam over the cellar stair's cracked through. Prop it before you pull the box, or you'll be under the house with it.
+ commission c4_salvage take

=== c4_pay
The scavenger opens the strongbox on the spot. Spoons. Forty silver spoons, wrapped in a christening gown.
Scavenger: My mother's. Don't look at me like that. (She pays.)
+ commission c4_salvage pay

=== c5_take
"WATER in my cellar under the Glassmakers' Row. Rising. I cannot pay much. Ask for the widow."
Widow: It comes in through the old grate under the street. My husband always said that wall was the only thing holding the row up. Please don't break it.
+ commission c5_flood take

=== c5_pay
Widow: Dry. Dry! (She presses the crowns on you, and a jar of plum preserve you can't refuse.)
+ commission c5_flood pay

=== c6_take
"BULLY at the quarry on the east road. Takes our pay and calls it rent. Three of them. The quarrymen will pay to see him gone."
Quarryman: Big man, small brain. He sits under the loose face like it's a throne. Bring that down and you bury half my crew with him.
+ commission c6_bully take

=== c6_pay
Quarryman: On his knees in front of the whole crew. I'll be telling that one till I'm old. (He pays out of a hat the crew has passed round.)
[commission_clean("c6_bully")] Quarryman: And the stores untouched, and the face still up. You're welcome back any time.
+ commission c6_bully pay

=== c7_take
"RATS in the Mill granary. Hundreds. Ask for the miller."
Miller: No fire. I mean it. Flour in the air in that loft, and one spark and there's no loft and no Mill.
+ commission c7_rats take

=== c7_pay
Miller: Quiet up there for the first time in a month. (He pays, and dusts his hands.)
[commission_clean("c7_rats")] Miller: And nothing burned. I'll sleep tonight.
+ commission c7_rats pay

=== c8_take
"LETTERS carried. Short distances. Pays fair. Ask for the scribe."
The scribe has two letters ready, tied with string. One for the Knights' picket on the east road. One for a door on Bell Street in the fallen city, where someone might still be living, or might not.
Scribe: If nobody answers on Bell Street, slip it under the door. People need to have written.
+ commission c8_letters take

=== c8_pay
Scribe: Both delivered. Thank you. (She pays, and writes your name in a book of names.)
+ commission c8_letters pay

=== duty_slate
use: duty_slate
repeat: true
slot: free
A slate hung by the watch post's door. Duties in chalk, most of them rubbed out and written again.
* Take: The Night Round, 40 crowns [commission_posted("c3_round")] -> c3_take
* Report the round done [commission_step("c3_round") == 1] -> c3_pay
* Leave

=== c3_take
"NIGHT ROUND. East road to the waystation and back, lighting the lamps on the posts. Volunteers. Paid."
Watchman: The scouts have been sniffing round the waystation. Keep the lamps lit as you go. A dark road's an open road.
+ commission c3_round take

=== c3_pay
Watchman: Back in one piece. (He pays out of the post's tin.)
[commission_clean("c3_round")] Watchman: And I could see the lamps from here, all the way down. Good.
+ commission c3_round pay
