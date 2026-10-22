# Overheard talk in the camp (N-7.6.2; people spec §10): two people talking at a place in a window
# of days and times. Walk in and listen; what you hear is a rumour (data/world/rumours.json), kept
# for every life, and a date rumour pins its event on the calendar. A rumour heard in any life
# isn't overheard again. The format is in scripts/game/story.gd.

=== overhear_knights
place: watch_post, gate
days: 1-2
times: morning, noon, afternoon
slot: free
when: not rumour_heard("r_knights")
Two of the watch at the post, squinting east.
Watchman: Riders on the plateau road. A lot of them. Banner like an iron ring.
Watchwoman: Knights, then. By the second evening, at that pace. Wonderful. More mouths.
+ rumour r_knights
* Leave

=== overhear_iron_gate
place: inn
days: 20-29
times: dusk, night
slot: free
when: not rumour_heard("r_iron_gate")
At the next table in the Crooked Wick, a squire in mail is three cups past careful.
Squire: Dunmore's shutting the Iron Gate. First light, second of Thaw. Anyone out past it can stay out past it.
Camper: And the folk on the far farms?
Squire: (into his cup) Can stay out past it.
+ rumour r_iron_gate
* Leave

=== overhear_cinder_row
place: market
days: 28-37
times: morning, noon
slot: free
when: not rumour_heard("r_cinder_row")
Two salvagers argue over a bent spoon at the Market's edge.
Salvager: That dwarf went down Cinder Row for ring-metal. Never came up.
Salvager: Near the old bakery. My cousin swears he heard tapping down there of a night. Round the tenth, he says. Tin tables, it sounded like.
+ rumour r_cinder_row
* Leave

=== overhear_east_fence
place: watch_post
days: 56-67
times: noon, afternoon, dusk
slot: free
when: not rumour_heard("r_east_fence")
Halloway is going down a list with a stub of pencil, and not liking it.
Captain: Twelfth of Seedmoon, night. East fence at the Mill. That's two. Two, on a fence that wants six.
Watchman: There's the boy, Tam. He'd stand it.
Captain: He's a boy.
+ rumour r_east_fence
* Leave

=== overhear_lighting
place: market, great_lamp
days: 70-83
times: noon, afternoon, dusk
slot: free
when: not rumour_heard("r_lighting")
Mira, on a ladder, talking down to Bett, who is holding the ladder and not happy about it.
Mira: Every lamp in the Market, all at once, off the great lamp. Dusk, last night of Seedmoon. A proper lighting.
Bett: And who's paying for the oil?
Mira: The Guild. Fennick doesn't know yet.
+ rumour r_lighting
* Leave

=== overhear_pell
place: market
days: 8-60
times: noon, afternoon
slot: free
when: not rumour_heard("r_pell_cheap") and k("pell")
Two campers walk away from Pell's stall with a flask each.
Camper: Cheapest in the camp. I don't ask.
+ rumour r_pell_cheap
* Leave

=== overhear_bett
place: market
days: 15-80
times: morning
slot: free
when: not rumour_heard("r_bett_flowers") and k("bett")
A girl hands Bett a fistful of wildflowers. Bett puts them in a jar on the stall as if they were the day's takings.
+ rumour r_bett_flowers
* Leave
