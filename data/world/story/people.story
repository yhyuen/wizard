# The Ring 1 roster's talks (N-7.2.2; people spec §21.1, the Ring 1 story's cast §3): a first
# talk that puts each person in the Ledger, and what they say after. "Notices" lines (life 2+,
# people spec §5) play once a life, the first time you talk; each names only what the soul knows.
# The main line's own scenes with these people come with their steps. The format is in
# scripts/game/story.gd.

# --- notices (life 2+) ------------------------------------------------------------------------

=== mira_notices
talk: mira
priority: 9
when: loop > 1
Mira: Have we... no. Sorry.
Mira: You've got a lamplighter's hands. It's the way you hold the taper.
* Leave

# --- the Guild ------------------------------------------------------------------------------

=== fennick_first
talk: fennick
priority: 10
when: not k("fennick")
Fennick: A College robe with the College still in it. Rare as hen's teeth this spring.
Fennick: Fennick Brass, Guild of Lamps, up from Lantern Quay. I run this market, such as it is.
Fennick: Forty pockets, and something useful in most of them. Come and see me at the bench.
+ learn fennick
* Leave

=== fennick
talk: fennick
repeat: true
priority: -10
[time == "dusk"] Fennick: Not now. The great lamp's a jealous creature at this hour.
[time != "dusk"] Fennick: Buying, selling or just admiring? All three are welcome. Two are profitable.
* Leave

# --- the kitchen and the Mill ---------------------------------------------------------------

=== bett_first
talk: bett
priority: 10
when: not k("bett")
Bett: You'll be hungry. Everyone's hungry. Sit there.
Bett: I'm Bett. Aldous is mine, and Tam, and the kitchen, for my sins.
Bett: There's soup at noon. It's mostly water, but it's hot water.
+ learn bett
* Leave

=== bett
talk: bett
repeat: true
priority: -10
Bett: Bowl's there. Mind, it's hot.
* Leave

=== tam_first
talk: tam
priority: 10
when: not k("tam")
Tam: Are you a real wizard? From the College? Do you want some water?
Tam: I'm Tam. I carry the water. I'm learning the Kindle too, only it won't light.
Tam: Dad says it will when it's ready. Dad says that about bread as well.
+ learn tam
* Leave

=== tam
talk: tam
repeat: true
priority: -10
[time == "dusk"] Tam: I have to go in before the lamps. Mum counts.
[time != "dusk"] Tam: Watch. No, watch properly. ...It nearly went that time.
* Leave

# --- the grief circle -------------------------------------------------------------------------

# Q-S3 (the Ring 1 story §5): sit at the fire. Pell says his children's names the first time;
# after three nights she asks you to whisper a name that isn't yours.
=== nobody_first
talk: nobody
priority: 10
when: not seen("nobody_first")
A fire at the camp's edge, small and well built, and around it a dozen people who aren't talking.
The woman tending it looks up. Afterwards you'll try to remember her face and find you can't.
Sister Nobody: Sit. You don't have to say anything. Most nights nobody does.
Sister Nobody: You can say a name here. No one here will tell you to move on.
+ learn nobody
* Sit a while [not done("circle")] -> circle_sit
* Leave

=== nobody
talk: nobody
repeat: true
priority: -10
Sister Nobody: The fire's warm. The night's long.
* Sit a while [not done("circle")] -> circle_sit
* Leave

=== circle_sit
You sit. Nobody asks you anything. The fire talks for all of you.
[f("circle_2")] + set circle_3
[f("circle_1")] + set circle_2
+ set circle_1
+ today circle
* Listen [not seen("circle_pell")] -> circle_pell
* Stay till it burns low [f("circle_3") and not f("circle_whisper") and not seen("circle_whisper")] -> circle_whisper
* Leave

=== circle_pell
Pell: (turning his forearm to the fire so the names show) Marta. Hob. Little Dain. The lake came up in the night, twelve years ago. I was at the market with the cart.
Pell: I sold the oil. I came home. There wasn't a home.
Sister Nobody: (gently) And?
Pell: And I'll have them back. All of it. She says.
+ learn pell_children
* Leave

=== circle_whisper
Sister Nobody: Whisper it. A name. Not yours. Not his. Its.
* Whisper -> circle_whisper_yes
* "No." -> circle_whisper_no

=== circle_whisper_yes
You don't know the name. Your mouth does. The air goes thin, your shadow lifts off the ground for a moment, and the torch nearest you burns backward into a new candle.
Sister Nobody: That's the Morning. It costs a little of you. Everything that matters does.
+ set circle_whisper
+ learn umbral_taste
* Leave

=== circle_whisper_no
Sister Nobody: (not offended at all) No. Of course. Come and sit anyway.
* Leave

# --- the Vanes -------------------------------------------------------------------------------

=== silas_first
talk: silas
priority: 10
when: not k("silas")
Silas: Oh. You lived. Wonderful.
Silas: Silas Vane. Storm, second year. You'll remember me from every exam you came second in.
Silas: If you're looking for my sister, don't.
+ learn silas
* Leave

=== silas
talk: silas
repeat: true
priority: -10
[time == "morning" or time == "noon"] Silas: I'm drilling. Go and drill somewhere else.
[time != "morning" and time != "noon"] Silas: She's fine. She's just drawing. Leave her be.
* Leave

# Q-S2 (the Ring 1 story §5): from Ashmoon 20 Cass asks you to sit for her; sit in Seedmoon, and
# from Seedmoon 26 she can't place you.
=== cass_fade
talk: cass
priority: 12
when: day >= 82 and not seen("cass_fade")
Cass: (friendly, blank) Do I know you?
[f("cass_portrait")] You show her the portrait. She looks at it for a long time.
[f("cass_portrait")] Cass: Someone's very good. I can't draw at all.
[not f("cass_portrait")] Cass: Sorry. I'm terrible with faces lately. Silas says I always was.
+ learn cass_fades
* Leave

=== cass_portrait
talk: cass
priority: 11
when: f("cass_asked") and day >= 57 and day < 82 and not f("cass_portrait")
You sit. She draws for an hour without speaking, and twice she stops and frowns at her own hand, as if it belonged to someone else.
Cass: There. Don't show Silas.
+ set cass_portrait
* Leave

=== cass_ask
talk: cass
priority: 11
when: day >= 20 and day < 57 and not f("cass_asked")
She's drawing on the back of a wagon board with a stick of charcoal. It's you. It's very good.
Cass: Silas says I'm not to talk to the Provost's lot. Silas says a lot of things.
Cass: Sit for me properly in Seedmoon. I'll do you in colour, if I can find colour.
+ set cass_asked
* Leave

=== cass_first
talk: cass
priority: 10
when: not k("cass")
Cass: Don't move! You've got a good face for it. Sad around the eyes. Everyone has, this spring.
Cass: I'm Cass. Silas's sister. He hates you, you know, so I've decided to like you.
+ learn cass
* Leave

=== cass
talk: cass
repeat: true
priority: -10
Cass: Hold still. There. That's you, more or less. Less, mostly.
* Leave

# --- the market's travellers -----------------------------------------------------------------

=== kestrel_first
talk: kestrel
priority: 10
when: not k("kestrel")
Kestrel: (around a mouthful of something) Mm. College. You look like you need a letter carried, or a dinner eaten.
Kestrel: Kestrel. Guild courier. I go where the roads still go, and a few places they don't.
+ learn kestrel
* Leave

=== kestrel
talk: kestrel
repeat: true
priority: -10
Kestrel: Nothing for you today. Ask me tomorrow. Ask me with food.
* Leave

=== jory_first
talk: jory
priority: 10
when: not k("jory")
An old man tunes a fiddle with a scorched neck, one ear down to the strings.
Jory: She came through it, the old girl. Didn't come through it with many songs, mind. Four.
Jory: You want a happy one, you'll have to wait for someone to write it.
+ learn jory
* Leave

=== jory
talk: jory
repeat: true
priority: -10
[time == "dusk"] Jory plays. Nobody in the market talks while he does.
[time != "dusk"] Jory: Come by at dusk. I play better with the lamps lit.
* Leave

# --- the infirmary -----------------------------------------------------------------------------

=== pike_first
talk: pike
priority: 10
when: not k("pike")
Pike: Standing on your own? Good. Bleeding anywhere? No? Better.
Pike: Ansel Pike. I run this tent. I was College once, before my second Ring threw me out.
Pike: If you break something, come here. Bones I can do.
+ learn pike
* Leave

=== pike
talk: pike
repeat: true
priority: -10
Pike: Still in one piece. Keep it that way.
* Leave

# --- the Knights' envoy (the east road) ---------------------------------------------------------

=== dunmore_first
talk: dunmore
priority: 10
when: not k("dunmore")
Dunmore: Good day. Knight-Captain Osric Dunmore, of the Iron Oath.
Dunmore: We keep this road for the moment, at the Commander's pleasure. You'll find us courteous.
Dunmore: You'll also find us watching. I'd rather say so plainly than have you discover it.
+ learn dunmore
* Leave

=== dunmore
talk: dunmore
repeat: true
priority: -10
Dunmore: Wizard. The road is quiet today. Let's keep it so.
* Leave

=== maud_first
talk: maud
priority: 10
when: not k("maud")
The knight in lead-sealed plate looks at you a long moment before she answers.
Maud: Dame Maud Ashby. That's all you need.
+ learn maud
* Leave

=== maud
talk: maud
repeat: true
priority: -10
Maud: Move along.
* Leave

# --- the dwarf under the bakery (Q-S6; the fixed event brogan_trapped, Thaw 10, Night) ------------

=== brogan_voice
From under Cinder Row, somewhere near the sliced bakery, a voice: steady, and very annoyed.
Brogan: If that's a Hollow, go away. If it's a person, there's a beam on my legs and I've been reciting the tin tables for two days to stay sane.
* Go to the voice -> brogan_beam
* Leave it -> brogan_left

=== brogan_beam
+ go city bakery
The bakery's cellar, half full of bread racks and fallen roof. A dwarf lies under a beam as thick as a man, ash in his beard.
Brogan: Brogan Tallowmere. Salvage. I came for the ring-metal. The ring-metal came for me.
* Lever the beam up with a broken rack -> brogan_free
* Brace it and dig him out, slowly -> brogan_dig

=== brogan_dig
You wedge the rack under the beam and scrape the rubble away from his legs, a handful at a time, while he recites the tin tables at you. It takes most of the night.
* Pull him free -> brogan_free

=== brogan_free
Brogan: (testing his legs, swearing in a language that sounds like gravel) Good. Good. One works.
Brogan: Get me to your camp. Then get me home. The Holds are west. The Holds are always west.
+ set brogan_freed
+ bond brogan kindness beam
+ learn brogan
* Leave

=== brogan_left
The voice keeps on with its tables for a while. Then it stops.
+ set brogan_lost
* Leave

=== brogan_home
arrive: market
when: f("brogan_freed") and not f("brogan_home")
Brogan: (sitting on a crate in the market, a cup in each hand) Your people are soft and your beer is a crime. I owe you a road.
Brogan: When the passes are open, there's a door in the west cliff. Knock twice, then once, then say my name like you mean it.
+ set brogan_home
+ deed carried_brogan
* Leave

=== brogan
talk: brogan
repeat: true
priority: -10
Brogan: Still owe you a road. Dwarves pay their debts. Slowly, but we pay them.
* Leave
