# The city: Lantern Market, the square, Lamplighter's Lane, the Mill and the plateau road, plus
# night patrols. Traces R2, R3, R6, O1, O2, O5 (design/slice/content.md).

# --- Lantern Market ------------------------------------------------------------

=== mourner
place: market
days: 3
times: noon
priority: 20
+ cutscene mourner
Lantern Market at noon: fish and brass, and steam rising from the pie stalls.
Across the crowd, someone in a grey veil has stopped dead and is looking straight at you.
They are weeping. Not loudly. The way people weep at a graveside.
+ learn mourner
* Go after them -> mourner_chase
* Let them go -> mourner_go

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
place: market
days: 4
times: morning
priority: 20
A big man in a flour-white coat is catching at every robe that passes.
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

=== market_idle
place: market
days: 1-28
times: morning, noon, afternoon, dusk
repeat: true
priority: -10
The market hums. You catch scraps of talk between the stalls.
[day <= 2] Talk is all about the fire on the College stairs, and the Hollows seen beyond the walls at night.
[day == 3] A pie-seller swears the dog in the square has gone mad.
[day == 4] People say the Mill foreman has been begging for help all morning.
[day == 5] They say there's trouble at the Mill this afternoon. Nobody is going near it.
[day == 6 and f("aldous_saved")] The foreman from the Mill is buying drinks for anyone in a College robe.
[day == 6 and not f("aldous_saved")] They found the Mill foreman this morning, walking the yard. He doesn't answer to his name any more.
[day == 7] A novice from the College is telling anyone who'll listen that he hears voices at the north door.
[day > 7] The market is quieter every day.
* Leave

# --- the square ----------------------------------------------------------------

=== dog_corner
place: square
days: 2-3
times: morning, noon
priority: 10
A stray dog is nosing round the square. It goes everywhere except one corner by the well, where it stops, whines and backs away.
There's nothing in the corner. You look twice.
+ learn dog_corner
* Leave

=== square_idle
place: square
days: 1-28
times: morning, noon, afternoon, dusk
repeat: true
priority: -10
The square: a dry well, a statue of some forgotten Provost, pigeons.
* Leave

# --- Lamplighter's Lane ---------------------------------------------------------

=== mira_meet
place: lane
days: 1-7
times: dusk
priority: 10
Lamplighter's Lane at dusk. A woman on a ladder is lighting the lamps one by one.
Mira: Evening, College. Mind the ladder.
Two lanterns hang at her door: hers, and another with the same mark scratched in the brass. The second one's flame leans inward, as if something were drawing it in.
Mira: That? It's been there since the morning after the light. Same mark as mine, but it isn't mine. It won't go out.
+ learn mira
+ learn second_lantern
* Leave

=== lane_idle
place: lane
days: 1-28
times: morning, noon, afternoon, dusk
repeat: true
priority: -10
Lamplighter's Lane. At one door hang two lanterns, and one of them burns inward, even by day.
+ learn second_lantern
* Leave

# --- the Mill ------------------------------------------------------------------

=== mill_risen
place: mill
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

=== mill_survived
The risen back away west, still facing you, and are gone over the wall.
One of them caught Aldous's arm on the way. The cut closed as the claw passed back through it. He stares at his arm.
+ learn closing_wound
+ set aldous_saved
+ wells 8

=== mill_idle
place: mill
days: 1-28
times: morning, noon, afternoon, dusk
repeat: true
priority: -10
The Mill wheel turns slowly in the millrace. The ash heap by the wall is very still.
* Leave

# --- the plateau road ---------------------------------------------------------------

=== footprints
place: road
days: 6
times: morning
priority: 10
Frost on the plateau road. The sun hasn't reached it yet.
Footprints are appearing in the frost, one after another, a few yards ahead of you. Nobody is making them.
They lead back toward the city.
+ learn footprints
* Leave

=== road_idle
place: road
days: 1-28
times: morning, noon, afternoon, dusk
repeat: true
priority: -10
The plateau road runs east under an enormous sky. Vellmar's towers stand at your back.
* Leave

# --- night patrols -----------------------------------------------------------------

=== patrol
place: market, square, lane, mill, road, gate
days: 1-28
times: night
repeat: true
priority: -5
The streets are empty after dark. Then they aren't.
Shapes in the mist, shuffling, wearing the clothes of people you might have known.
Hollows.
* Fight them -> patrol_fight
* Slip away home

=== patrol_fight
+ fight patrol
? won -> patrol_won

=== patrol_won
The Hollows fall still. Every one of them was someone, once.
+ wells 4
