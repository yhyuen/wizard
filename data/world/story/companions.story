# Companions in Ring 1 (N-7.6.6; people spec §4.4): Wren (a Guide), Mira (a Cutter) and Brogan (a
# Guard) walk with you once you're Close (Brogan once he's home). One at a time. Their night talks
# play as you wake, one a night. Texture, not story: no clue, key, spell or road. The format is in
# scripts/game/story.gd; the rules are data/world/companions.json.

=== walk_wren
Wren: Walk with you? Out there? (She is already rolling up a chart.) I'll need the blue one. And the other blue one.
Wren: I won't fight. I'm no good at it. But I'll know where we are, and I hear things.
+ companion wren join

=== part_wren
Wren: Home, then. Tents. Charts. Tea that's gone cold. (She waves without looking back.)
+ companion wren part

=== walk_mira
Mira: Someone has to keep the lamps lit round you. (She shoulders her hook-pole.) I'll watch your back. You watch the dark.
+ companion mira join

=== part_mira
Mira: The lane won't light itself. Shout if you need me.
+ companion mira part

=== walk_brogan
Brogan: I said I owed you a road. A dwarf walks it with you, then. (He picks up a hammer that could fell a door.)
Brogan: Stand behind me when it goes badly. That's the whole plan.
+ companion brogan join

=== part_brogan
Brogan: Back to the forge. You know where I'll be. Loudly.
+ companion brogan part

=== night_wren_1
The fire's down to coals. Wren is lying on her back, naming stars under her breath, wrong as often as right.
Wren: Did you know the Ferryman used to have a coin in his hand? Two hundred years ago. Then someone recharted it and the coin went.
Wren: I keep thinking somebody lost something, the day that coin went. Silly. Go back to sleep.

=== night_wren_2
Wren is awake before you, writing in a book so small she has to hold it to her nose.
Wren: I write down everyone I meet. Just their names, and one thing. (She shows you a page. There are a lot of crossings-out.)
Wren: You're in here somewhere. I think. Don't look. It's not finished.

=== night_mira_1
Mira trims the wick of your lantern without asking, the way other people straighten collars.
Mira: My father lit the lane before me. He used to say the dark doesn't hate you. It just doesn't know you're there.
Mira: So you make sure it does. That's all a lamp is. Saying you're here.

=== night_mira_2
Mira: Can I tell you something? (She doesn't wait.) I counted. Since the fall, I've lit every lamp on the lane every night but four.
Mira: The four I missed, I remember better than all the rest put together.

=== night_brogan_1
Brogan sharpens nothing in particular, slowly, for the sound of it.
Brogan: Down in the Holds we sing to the stone before we cut it. So it knows it's being asked.
Brogan: Up here nobody asks anything. They just take. (He tests the edge on his thumbnail.) Doesn't mean you have to.
