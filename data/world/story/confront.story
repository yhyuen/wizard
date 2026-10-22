# SPOILER: sealed Ring 1 story (people spec §11, §21.3; build item N-7.6.7). Ring 1's two
# confrontations: a hard one after Lantern Night and a soft one before Seedmoon 20. The scenes'
# statements and breaks are data/world/confront/*.json; the rules are scripts/game/confront.gd.

=== pell_confront_ask
talk: pell
priority: 6
repeat: true
when: calamity_in("lantern_night") < 0 and k("pell_lips") and confronted("pell_lamps") == ""
Pell is counting flasks that he has already counted. He doesn't look up.
Pell: Oil? Rope? I've got rope.
* Ask him about the lamps -> pell_confront
* A game of Sparks [game_open("pell")] -> sparks_pell
* Leave

=== pell_confront
You set your hand on the flasks so he has to stop counting.
+ confront pell_lamps
? expose -> pell_expose
? bargain -> pell_bargain
? let_go -> pell_let_go
? lost -> pell_closed

=== pell_expose
You walk him to the gate. He doesn't run. The watch takes him without a word, as if they had been expecting someone.
Captain: We'll hold him. What happens after isn't up to me.
+ set pell_exposed
* Leave

=== pell_bargain
You tell him the watch need never hear it. One thing, and you'll keep quiet.
Pell: (very low) I never saw her face. A veil, and a voice like somebody reading aloud.
Pell: She said they'd all have it back. All of it. Every one of them.
Pell: That's all. That's all I have. Keep your word.
+ set pell_bargain
* Leave

=== pell_let_go
You step back from the crate. He stares at you as though you had struck him.
Pell: Why? (He doesn't wait for an answer.) I owe you, then. I don't know what that's worth. Something.
+ set pell_owes
* Leave

=== pell_closed
Pell: I've told you. I was at my stall. (He turns his back and goes on counting.) We're done.
* Leave

=== cass_talk
talk: cass
priority: 9
repeat: true
when: f("cass_asked") and day < 76 and confronted("cass_drawings") == ""
Cass has three drawings of the same tent spread out on her knees. None of them quite agree.
* Ask about her drawings -> cass_confront
* Leave

=== cass_confront
+ confront cass_drawings
? sit -> cass_sit

=== cass_sit
You tell her you'll sit for her, in Seedmoon, as long as she likes.
Cass: Promise? (She doesn't wait for it.) Good. Then that's one thing that stays put.
+ set cass_talked
* Leave
