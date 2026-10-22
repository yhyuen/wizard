# The Lamplighter road in Ring 1 (N-7.4; the Ring 1 story §9, scenes S20-S23). Life 2 and on, once
# the road is open (lives.json roads.lamplighter.opens_by). Master: Fennick Brass; friend: Mira.
# Fennick's offer hangs off the first morning (apprentice.story wake_again_ask); rule one and the
# late answer to his offer are choices on the Guild bench (camp.story). The coupling (S24) and the
# wrong oil are in lantern_night.story (N-7.5.2). The format is in scripts/game/story.gd.

# --- S20. Fennick at the tent flap --------------------------------------------------------------

=== fennick_flap
There's a second shape in the tent flap, behind Wren. A man in a coat with far too many pockets, holding a lamp he has clearly just mended.
Fennick: Morning. Fennick Brass. Guild. You don't know me.
Fennick: Odd thing. Mira says she dreamt of you last night. Lighting every lamp in the market by hand, one at a time, in the dark.
Fennick: She's not a dreamer, Mira. So.
Fennick: The Guild's short a pair of hands. Take the road of the Lamplighters? You'll train with us this year.
+ learn fennick
* "Yes." -> fennick_road_yes
* "Let me think about it." -> fennick_road_later

=== fennick_road_yes
Fennick: Good. Bench is at the back of the market. Bring nothing; I'll sell you everything.
+ road lamplighter
* Leave

=== fennick_road_later
Fennick: Think fast. Offers like this go off like milk. You'll find me at the bench until the College's intake.
+ set fennick_later
* Leave

# --- S21. Rule one (the Guild bench) --------------------------------------------------------------

=== rule_one
Fennick: Rule one of Spark Artifice, apprentice: the spell's not in your head. It's on the bench.
He taps a glass flask with lightning trapped in it like a moth.
Fennick: That's a spell. Three charges. No wind-up, no Aether, no chanting like a College kid with a cold.
* "And when I run out?" -> rule_one_two

=== rule_one_two
Fennick: Then you've learned rule two. Count your stock before the fight, not during.
You pack your own: oil, a spark in the stopper, wire, and keep it away from your face.
+ bench
You go to pocket the flask. He catches your hand.
Fennick: That one's live. You drop it in your coat, you're a lamp. Respect the glass.
+ set rule_one
+ merit 5
+ standing guild 2
* Leave

# --- L2. The round (Ashmoon 4 on, Dusk) ---------------------------------------------------------

# Mira gives you the round: the market's 24 lamps on four circuits, lit by hand. While you walk it
# the town leaves them to you (world.gd); light all 24 the same dusk and the round is done.
=== round_ask
place: market
days: 4-28
times: dusk
when: on_road("lamplighter") and not f("round_given")
known: true
title: Mira's round
Mira: You're the new hands? Good. Take a taper. Twenty-four lamps, four circuits, and the rails between them.
Mira: Fennick will tell you the rails are clever. They are. But you learn a market by walking it, lamp by lamp.
Mira: Go on. I'll watch you do the first one and then I'll pretend I'm not watching.
+ set round_given
+ today round
* Take the taper

=== round_again
place: market
days: 5-84
times: dusk
repeat: true
priority: -5
when: on_road("lamplighter") and f("round_given") and not f("round_done") and not done("round")
Mira holds out the taper without a word.
* Walk the round tonight -> round_walk
* Not tonight

=== round_walk
+ today round
* Take the taper

# The world sets round_done when the 24th lamp is lit by your hand the same dusk.
=== round_done
talk: mira
priority: 12
when: f("round_done") and not seen("round_done")
Mira: All twenty-four. One at a time. (She looks at you oddly.) That's how I dreamt it, you know.
+ merit 10
+ standing guild 3
* Leave

# --- S22. The rails (Thaw) --------------------------------------------------------------------------

=== rails
place: market
days: 29-56
times: morning, noon, afternoon
when: on_road("lamplighter") and not seen("rails")
known: true
title: Fennick and the rails
Fennick: Iron rail between every post. Know why?
Fennick: Not for the oil. For this.
He touches an Arc Rod to the rail at the end of the circuit. Six lamps flare at once, white, and settle.
Fennick: Lightning runs iron. Wet iron, further. Two circuits joined, it runs both. Remember that the night you need it.
+ model arc_rod
+ learn rails_flare
+ merit 5
* Leave

# --- S23. The Market reckoning (Seedmoon 14, Morning) ---------------------------------------------

# The exam (powers spec §4.5): build a device, sell it in the market, be in the black by nightfall.
# Crowns aren't built, so the day is choices: undercut Kestrel, or keep one back for Pell at Noon.
=== reckoning
place: market
days: 70
times: morning
when: on_road("lamplighter") and not seen("reckoning")
known: true
title: The Market reckoning
Fennick: Exam's simple. Build a thing. Sell it here. Be in the black by nightfall.
Fennick: Kestrel's selling the same thing, cheaper, from a crate. Kestrel always is.
You build six flasks at the bench before the market opens, and set them out on a cloth.
* Price them a copper under Kestrel's -> reckoning_under
* Price them the same as Kestrel's -> reckoning_same
* Price them high: yours are better -> reckoning_same

=== reckoning_under
By Noon you've sold four. Kestrel glares at you over the crate and drops their price again.
* Drop yours to match [not k("pell_children")] -> reckoning_close
* Keep the last one back for Pell [k("pell_children")] -> reckoning_pell

=== reckoning_pell
At Noon, as he always does, Pell comes to the stall.
Pell: (counting out coins) For the children's lamp. I keep one lit. Silly.
He pays far too much. You let him.
+ set reckoning_rich
* Count the takings -> reckoning_pass

=== reckoning_close
You sell the last two at Dusk for less than the oil cost. It's close.
* Count the takings -> reckoning_pass

=== reckoning_same
Nobody pays your price for what Kestrel sells cheaper. By Dusk you've sold one flask, to a man who thought it was soup.
Fennick: (reading your takings) In the red. Hm. Come back in summer. Bring a sharper pencil.
* Leave

=== reckoning_pass
Fennick: (reading your takings) In the black. Hm. Mira, write it down before it goes to their head.
+ set reckoning_passed
+ deed exam_reckoning
+ exam guild
* Leave [rank("guild") < 1]
* Wait for Fennick [rank("guild") >= 1] -> reckoning_adept

=== reckoning_adept
Fennick: And the Guild says Adept. Don't let it go to your hands, either. Hands are what we pay for.
* Leave
