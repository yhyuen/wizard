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

=== nobody_first
talk: nobody
priority: 10
when: not k("nobody")
A woman in grey sits by the fire with her hands open on her knees. When you try to look at her face, your eyes slide off it to the flames.
Sister Nobody: Sit, if you like. We say the names here. That's all we do.
Sister Nobody: They call me Sister Nobody. It suits me better than the other one did.
+ learn nobody
* Leave

=== nobody
talk: nobody
repeat: true
priority: -10
Sister Nobody: The fire's warm. The night's long. Stay as long as you need.
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
