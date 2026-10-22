# Calamity 1, Lantern Night (N-7.5; seasons spec §8). Its frame is data/world/calamities.json and
# scripts/game/calamity.gd: at Night on Seedmoon 28, if you're in the camp, the onset scene plays
# and the Peak is fought where you stand; losing it ends the life. Elsewhere, it passes without you.
# SEALED for builders (design/story/ring1/ring1-scenes.md S9, S12, S24): signs, preparations, the
# lighting at Dusk (a fixed event, calendar.json), the Onset, and Dawn. The format is in
# scripts/game/story.gd.

# --- Signs (Seedmoon 21-27): two pin a "?" on the 28th ----------------------------------------

=== sign_flicker
place: market
days: 77-83
times: dusk
slot: free
The lamps on the Gate circuit gutter as they come on, all six together, as if something had drawn a breath along the rail. Then they steady.
Nobody else seems to notice. A child points, and is hushed.
+ sign lantern_night flicker
* Leave

=== mira_oil
talk: mira
priority: 9
when: day >= 79 and day < 84
Mira: Smell that. (She holds a wick under your nose.) No. Properly.
Mira: Like a snuffed candle. Good oil smells of nothing. That's how you know it's good.
Mira: It's not the Guild's barrels. I checked the Guild's barrels. It's coming from somewhere else and getting into the lamps.
+ sign lantern_night mira_oil
* "Whose oil is it?" [not f("oil_grey")] -> mira_oil_whose
* "Pell's oil has a grey bloom in it." [f("oil_grey")] -> mira_oil_grey
* "I'll keep an eye on it." -> mira_oil_end

=== mira_oil_whose
Mira: Everyone's. Nobody's. Half the camp buys from Pell's stall because he's cheap and he's kind. (A pause.) He's very cheap.
* Leave

=== mira_oil_grey
Mira holds the two flasks up to the light, one in each hand. She's quiet for a long time.
Mira: That's not oil. That's... (She doesn't finish.) I've seen him at the great lamp after dark. Three nights. At the coupling. I told myself he was helping.
+ set mira_sign_seat
* Leave

=== mira_oil_end
Mira: Do. Somebody should.
* Leave

=== pell_oil
talk: pell
priority: 9
when: day >= 77 and day < 84 and k("pell")
Pell: Oil? I've oil. Cheapest in the camp, and it burns all night. Take a flask. No, take it. For the College.
* Hold the flask up to the light -> pell_oil_look
* Thank him

=== pell_oil_look
In the lamplight the oil is clear, and then it isn't: a grey bloom turns in it, slow, like smoke in a bottle that has no smoke in it.
Pell: (quickly) It settles. Give it a shake.
+ set oil_grey
* Leave

=== sign_stair
place: market, watch_post, streets
days: 81-83
times: night
Up from the city, on the north stair, a scrape of feet that don't lift. Four Hollows at the top step, testing it, the way a man tests ice.
They stop at the edge of the lamplight and look at the lamps. Then they come on anyway.
+ sign lantern_night stair_test
+ fight stair_test
? won -> sign_stair_after

=== sign_stair_after
The last of them goes back down the stair in pieces. The watch on the wall didn't see them come. They count the lamps twice, after.
* Leave

# --- Preparations (any, before Night on Seedmoon 28; each takes a time of day) ---------------

=== ready
talk: mira
priority: 8
when: day >= 77 and day < 84 and seen("mira_oil")
Mira: If something's coming for my lamps, I'd like it to find them ready. Got a pair of hands?
* Re-wick a circuit with her [count("rewick_") < 4] -> ready_rewick
* Clear the hay and awnings off the lamp posts [not f("hay_cleared")] -> ready_hay
* "Who'll help on the night?" [not f("helpers_asked")] -> ready_helpers
* Not now

=== ready_rewick
You work down a circuit with her, post to post: new wick, new glass, a dab of the Guild's good oil and none of anyone else's.
[not f("rewick_a")] + set rewick_a
[f("rewick_a") and not f("rewick_b")] + set rewick_b
[f("rewick_b") and not f("rewick_c")] + set rewick_c
[f("rewick_c") and not f("rewick_d")] + set rewick_d
+ prep lantern_night rewick
Mira: Those'll hold a while, whatever comes. Longer than the rest.
* Leave

=== ready_hay
Hay off the posts, awnings rolled, crates stacked away from the glass. Bett watches you move her stall a yard to the left and says nothing, very loudly.
+ set hay_cleared
+ prep lantern_night clear_hay
* Leave

=== ready_helpers
[standing("guild") >= 25 or standing("college") >= 25] Mira: You? People will come if you ask. Four, maybe. Tapers and buckets.
[standing("guild") < 25 and standing("college") < 25] Mira: Ask around. Nobody knows you well enough yet to stand in the dark for you.
+ set helpers_asked
[standing("guild") >= 25 or standing("college") >= 25] + set helpers_coming
[standing("guild") >= 25 or standing("college") >= 25] + prep lantern_night helpers
* Leave

=== ready_watch
talk: captain
priority: 8
when: day >= 77 and day < 84 and f("pinned_calamity_1")
Captain: You've a face on you like you know something. Out with it.
* "Warn the households near the Market. Have them sleep in the College tents on the 28th." [not f("sheltered")] -> ready_shelter
* "Put braziers at the stair and the broken wall." [not f("braziers_set")] -> ready_braziers
* Nothing

=== ready_shelter
Halloway looks at you a long while.
Captain: Can't make anyone. But I can knock on doors. (He does, and so do you, the rest of the afternoon.)
+ set sheltered
+ prep lantern_night shelter
* Leave

=== ready_braziers
You haul wood and oil to the approaches with two of the watch: the north stair, the broken wall, the Mill lane.
Captain: Fire they won't cross. I'll grant you that much about the College.
+ set braziers_set
+ prep lantern_night braziers
* Leave

=== ready_rails
use: bench
priority: 5
when: day >= 77 and day < 84 and (on_road("lamplighter") or mastered("spark_artifice")) and not f("rails_bridged")
A coil of copper on the bench, and an iron rail that ends a yard short of the next.
* Bridge two of the Market's circuits -> ready_rails_do
* Set flare charges at the posts [not f("flares_set")] -> ready_flares
* Leave

=== ready_rails_do
You run the coil from the Gate circuit's last post to the Square run's first, and bind it tight. Two circuits, one rail.
+ set rails_bridged
+ prep lantern_night bridge_rails
* Leave

=== ready_flares
Flask charges, wired at the foot of four posts: break one and it relights the lamp above it from across the street.
+ set flares_set
+ prep lantern_night flares
* Leave

=== brogan_rails
talk: brogan
priority: 8
when: day >= 77 and day < 84 and f("pinned_calamity_1") and not f("rails_bridged")
Brogan: Iron rails, between the lamps? Whoever laid them stopped a yard short on the north row. Sloppy. I could close it for you.
* "Do." -> brogan_rails_do
* "Not now."

=== brogan_rails_do
Brogan closes the gap with a length of ring-metal and a hammer, humming the tin tables.
+ set rails_bridged
+ prep lantern_night bridge_rails
* Leave

# --- The coupling on the Lamplighter road (S24) -----------------------------------------------

=== coupling_duty
talk: fennick
priority: 9
when: on_road("lamplighter") and day >= 77 and day < 84 and not seen("coupling_duty")
Fennick: You're on the great lamp for the lighting. Stand at the platform, keep the crowd off the glass.
* "Stand at the coupling yourself, at Dusk. Don't let anyone touch it." [k("pell_lips") or f("mira_sign_seat")] -> coupling_ask
* "The stone isn't from a scavenger." [standing("guild") >= 25] -> coupling_stone
* "I'll be there."

=== coupling_ask
Fennick looks at you for a long time, the salesman gone out of his face.
Fennick: All right. I'll eat my apple there.
+ set fennick_guards
* Leave

=== coupling_stone
Fennick: (quietly) No. I pulled it out of the conductor housing myself, the morning after. The Guild built those conductors, you know. Forty years ago. The whole ring of them.
Fennick: It was warm. It's still warm. I don't know what it is. I put it in the lamp because the lamp was the safest place I could think of.
Fennick: (He laughs, without much in it.) Stupid. Everybody looks at a lamp.
+ learn fennick_stone
* Leave

# --- The lighting (Seedmoon 28, Dusk; the fixed event lantern_lighting) ------------------------

=== lighting
The Lamplighters call it Lantern Night, though nobody did before this year. It was Mira's idea.
On the last night of the third moon every lamp in the Market will be lit at once from the Guild's great lamp: the one that burns blue-white and never needs oil. The one with the stone in it.
Inside the great lamp's glass, where a wick should be, sits a shard of something like quicksilver frozen mid-splash. Its light makes your teeth ache.
Old Jory's fiddle survived the Shattering. He knows four songs and plays them in turn.
[not f("mill_burned")] Bett sells thin stew and barley cakes from the Mill's own seed, and she doesn't charge Tam's friends.
[f("mill_burned")] Bett sells thin stew and barley cakes, and she doesn't charge Tam's friends.
Wren finds you in the crowd and puts a cake in your hand without a word. That's how you know you're forgiven.
+ learn lantern_cakes
* Find a place in the crowd [not f("fennick_guards")] -> lighting_lit
* Go to the platform, where Fennick is [f("fennick_guards")] -> lighting_invite

=== lighting_lit
Mira climbs the steps of the great lamp's platform and holds up a taper.
Mira: Three moons ago the sky fell in. We're still here.
A cheer, ragged, real.
Mira: So let's have some light.
She touches the taper to the great lamp's vent. Blue-white flame leaps down the Market's lines, lamp to lamp to lamp, until the whole camp is drawn in light on the dark plateau like a figure on a page.
Everyone looks up. You don't. You're looking at Pell.
* Look -> lighting_pell

=== lighting_pell
Pell, who runs the oil stall, who is kind, who has three children's names on his forearm.
He's standing at the foot of the platform with his hand on the brass coupling where the lamp lines meet. His lips are moving.
Not a song. Not a prayer. A name. You can't hear it. You can feel it.
+ sound cast_hours
The glass note in your chest is suddenly loud, a fingernail round the rim of the world.
+ learn pell_lips
* Push through the crowd and grab his hand [k("pell_lips") and (f("mira_sign_seat") or loop > 1)] -> lighting_hand
* Say his children's names [k("pell_children") and (f("mira_sign_seat") or loop > 1)] -> lighting_names
* Watch the lamps -> lighting_watch

=== lighting_hand
You're at the coupling before you've decided to be. You take his wrist. It's very thin under the sleeve.
Pell: (not looking at you) Please. Please, it's only a word.
He says it anyway, softer, into your shoulder. The lamps nearest the coupling dim, and hold.
+ set cut_delayed
* Leave

=== lighting_names
You say them. The three names on his arm, in order, the way he said them at the grief fire.
Pell's lips stop moving.
Pell: You were listening.
At the camp's edge, Sister Nobody's fire goes out. Nobody notices but you.
+ set cut_stopped
* Leave

=== lighting_watch
The lamps burn on, blue-white and steady, and the fiddle starts its second song. Whatever you felt, the night doesn't seem to have felt it.
* Leave

=== lighting_invite
Mira climbs the platform with her taper. Fennick is already at the coupling, leaning on it, eating an apple, as if he'd been there all evening.
At the oil stall Pell catches your sleeve.
Pell: (very quietly) Will you come and see? The names. On my arm. Just for a moment, while they light it.
* Go with him -> lighting_invite_go
* Stay at the platform -> lighting_invite_stay

=== lighting_invite_go
He shows you the three names by the light of the stall lamp. While you're looking, under your feet, from the cellar drain, the glass note.
+ learn pell_lips
+ set cut_drain
* Leave

=== lighting_invite_stay
Fennick: Evening, Pell. Lovely night for it.
Pell says the name from where he stands, at the stall, very quietly. Nothing happens. The coupling is under Fennick's hand.
He sits down on the ground, where he is, and puts his face in his hands.
+ learn pell_lips
+ set cut_stopped
* Leave

# --- The Onset and the Peak (Seedmoon 28, Night) ----------------------------------------------

=== lantern_night_onset
[not f("cut_stopped")] The lamps go out.
[not f("cut_stopped")] Not all at once. One, at the end of the Gate row, then the next, then the next, a darkness running down the iron rail faster than a man can walk. Then the Market ring. Then the Square run. Then Mira's lane.
[not f("cut_stopped") and count("rewick_") > 0] Only the lamps you re-wicked hold, small and stubborn, like coins in the dark.
[not f("cut_stopped")] At the great lamp, glass breaks. The blue-white light goes out of the Market. It doesn't come back.
[f("cut_stopped")] The lamps hold. Every one, blue-white down the rails, and the great lamp burning over it all.
[f("cut_stopped")] The mist comes anyway. Up out of the city, over the lip, into the Market's streets, and in the mist something is climbing.
[not f("cut_stopped")] The mist comes up out of the city with nothing to stop it, and in the mist, on the north stair, something is climbing.
Wren: Lamps! Light the lamps! Anyone with a Kindle!
Crane: Apprentices to the wagons! Fire ring! Now!
+ calamity_onset lantern_night
+ learn lantern_night
+ fight c1_peak
? won -> lantern_night_dawn

# --- Dawn (S9c) -----------------------------------------------------------------------------------

=== lantern_night_dawn
The mist thins. The east goes grey, then white, and the things on the stair go back down into the city as if they had somewhere to be.
[f("heart_kept")] Dawn at the great lamp. Fennick is wrapping the stone in a cloth with hands that won't stay steady. He keeps saying "warm" under his breath, like a man counting.
[f("heart_kept")] Mira sits on the platform steps with her boots in a puddle of oil and doesn't move them.
[f("heart_kept")] From the crater road, very far off, a woman's voice sings four notes. Then it stops, as if it had forgotten the rest.
[f("heart_kept")] + learn four_notes
[not f("heart_kept")] You follow the trail of broken lamps toward the crater road. You don't decide to. Your feet decide.
[not f("heart_kept")] At the top of the switchback the less has gathered into something like a shape. A pool of absence as wide as the road.
[not f("heart_kept")] In the middle of it a woman stands with a veil over her face and the quicksilver stone held loose in one hand like an apple.
[not f("heart_kept")] Veiled woman: (gently, to no one) All of it. Every one of them. They'll all have it back.
[not f("heart_kept")] Veiled woman: Oh. You. He chose you? Then you'll do this many times.
[not f("heart_kept")] Veiled woman: I'm sorry. It doesn't get easier. It gets familiar.
[not f("heart_kept")] + learn veiled_woman
[not f("heart_kept") and ring <= 1] She opens her hand toward you, and the less comes up the road like a tide.
[not f("heart_kept") and ring > 1] She closes her hand, and walks backward into the less, and the less goes with her.
+ calamity_dawn lantern_night
* Count the lamps
