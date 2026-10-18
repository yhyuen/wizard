# The city: Lantern Market, the square, Lamplighter's Lane, the Mill and the plateau road, plus
# night patrols. Traces R2, R3, R6, O1, O2, O5 (design/slice/content.md), now in the streets.

# --- Lantern Market ------------------------------------------------------------

=== mourner
arrive: market
days: 3
times: noon
priority: 20
Lantern Market at noon: fish and brass, and steam rising from the pie stalls.
Across the crowd, someone in a grey veil has stopped dead and is looking straight at you.
They are weeping. Not loudly. The way people weep at a graveside.
+ learn mourner
(Go after them, or let them go.)

=== mourner_chase
You push through the crowd. They back away, still facing you, never turning round.
However fast you go, they go faster, walking backwards, until the crowd closes over them.
An old woman at a stall spits to one side.
Woman: Never greet your own shadow. My gran used to say that.
+ learn saying_shadow

=== mourner_go
You stay where you are. The veiled figure lifts one hand, not quite a wave, and backs away into the crowd.
For a moment the noise of the market seems very far away.
+ set mourner_let_go

=== aldous_ask
talk: aldous
days: 4
times: morning
priority: 20
A big man in a flour-white coat catches at your sleeve.
Aldous: You're College? Please. I'm foreman at the Mill. The dead we burned last week won't stay down.
Aldous: Tomorrow afternoon, it'll be. It's always the afternoon. Will you come?
+ learn aldous
+ learn mill_day5
+ set aldous_asked
* Ask what he's seen -> aldous_tip
* Promise to come

=== aldous_tip
Aldous: They walk wrong. Backwards, like a cart rolling uphill.
Aldous: And they won't cross the millrace. I've watched them stop dead at the water.
+ learn millrace

=== aldous
talk: aldous
repeat: true
priority: -10
[day >= 6 and f("aldous_saved")] Aldous: Drinks are on me, College. Anything you like.
[day >= 6 and seen("mill_risen") and not f("aldous_saved")] He is standing in the Mill yard, looking at nothing. He doesn't answer to his name any more.
[not seen("mill_risen")] Aldous: Flour in everything. Even the bread.
[seen("aldous_ask") and not seen("mill_risen")] Aldous: Day five. The afternoon. You'll come?
* Ask what he's seen [seen("aldous_ask") and not k("millrace") and not seen("mill_risen")] -> aldous_tip
* Leave

=== old_woman
talk: old_woman
repeat: true
The old woman at the stall leans in to tell you what everyone is saying.
[day <= 2] Woman: All about the fire on the College stairs. And the Hollows seen beyond the walls at night.
[day == 3] Woman: The pie-seller swears the dog in the square has gone mad.
[day == 4] Woman: The Mill foreman's been begging for help all morning. Big man. Flour on him.
[day == 5] Woman: Trouble at the Mill this afternoon, they say. Nobody's going near it.
[day == 6 and f("aldous_saved")] Woman: The Mill foreman's buying drinks for anyone in a College robe.
[day == 6 and not f("aldous_saved")] Woman: They found the Mill foreman this morning, walking the yard. He doesn't answer to his name.
[day == 7] Woman: A novice up at the College hears voices at the north door. Tell him to stop listening.
[day > 7] Woman: Quieter every day. Folk are leaving.
[seen("mourner_chase")] Woman: And you. Never greet your own shadow.
* Leave

=== pie_seller
talk: pie_seller
repeat: true
The pie-seller wipes her hands on her apron.
"Pie? No? That dog in the square won't go near the well corner. Nor will I, now."
* Leave

# --- the square ----------------------------------------------------------------

=== dog_corner
use: dog_corner
days: 2-3
times: morning, noon
priority: 10
The stray dog goes everywhere in the square except this corner by the well, where it stops, whines and backs away.
There's nothing in the corner. You look twice.
+ learn dog_corner
* Leave

=== dog_corner_idle
use: dog_corner
repeat: true
priority: -10
An empty corner by the well. Nothing there.
* Leave

=== dog
talk: dog
repeat: true
The dog sniffs your hand, then your boots, then decides you're all right.
[day >= 2 and day <= 3] It keeps glancing at the corner by the well, and won't go near it.
* Leave

# --- Lamplighter's Lane ---------------------------------------------------------

=== mira_meet
talk: mira
days: 1-7
times: dusk
priority: 10
when: not k("mira")
Mira is working down Lamplighter's Lane with her pole, lighting the lamps one by one.
Mira: Evening, College. Mind the ladder.
Mira: Two lanterns at my door, if you're wondering. Mine, and one with the same mark scratched in the brass. Since the morning after the light. It isn't mine, and it won't go out.
+ learn mira
+ learn second_lantern
* Leave

=== mira
talk: mira
repeat: true
priority: -10
[time == "dusk"] Mira: Can't stop. Lamps don't light themselves.
[time != "dusk"] Mira: Oil's dear this month. Everything's dear this month.
[k("mira")] Mira: That second lantern's still burning, if you're wondering. Leaning in, like it's listening.
* Leave

=== second_lantern
use: second_lantern
priority: 5
Two lanterns hang at Mira's door: hers, and another with the same mark scratched in the brass.
The second one's flame leans inward, as if something were drawing it in.
+ learn second_lantern
* Leave

=== lantern_water
use: second_lantern
cast: water
priority: 5
The water hisses on the glass. The flame leans further in and burns on, as if the water had never been there.
+ learn second_lantern

=== lantern_idle
use: second_lantern
repeat: true
priority: -10
Mira's two lanterns. One burns inward, even by day.
* Leave

# --- the Mill ------------------------------------------------------------------

=== mill_risen
arrive: mill
days: 5
times: afternoon
priority: 20
title: The dead at the Mill
known: k("mill_day5")
The Mill yard. Flour lies on the cobbles like snow.
[f("aldous_asked")] Aldous waves you over from the mill-house door, white-faced.
In the ash heap by the wall, something moves. Then another. The dead are getting up, the way smoke goes back into a fire.
[k("millrace")] You remember what Aldous said: they won't cross the millrace.
+ learn risen
+ fight mill_risen
? won -> mill_survived
? lost -> mill_death

=== mill_death
You knock them down, and they get up. You knock them down again, and they get up, closer.
+ learn died_mill
+ end_loop mill

=== mill_survived
The risen back away west, still facing you, and are gone over the wall.
One of them caught Aldous's arm on the way. The cut closed as the claw passed back through it. He stares at his arm.
+ learn closing_wound
+ set aldous_saved
+ wells 8

=== ash_heap
use: ash_heap
repeat: true
The ash heap by the Mill wall: what's left of last week's dead. It is very still.
[k("risen")] You know now that it won't stay that way.
* Leave

# --- the plateau road ---------------------------------------------------------------

=== footprints
arrive: road
days: 6
times: morning
priority: 10
Frost on the plateau road. The sun hasn't reached it yet.
Footprints are appearing in the frost, one after another, a few yards ahead of you. Nobody is making them.
They lead back toward the city.
+ learn footprints
* Leave

# --- night patrols -----------------------------------------------------------------

=== patrol
arrive: market, square, lane, mill, road
times: night
repeat: true
priority: -5
when: not done("patrol")
+ today patrol
The streets are empty after dark. Then they aren't.
Shapes in the mist, shuffling, wearing the clothes of people you might have known.
Hollows.
* Fight them -> patrol_fight
* Slip away

=== patrol_fight
+ fight patrol
? won -> patrol_won
? lost -> patrol_death

=== patrol_death
They come out of the mist from every side at once, and keep coming.
+ learn died_patrol
+ end_loop patrol

=== patrol_won
The Hollows fall still. Every one of them was someone, once.
+ wells 4
