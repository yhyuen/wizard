# Growth: wells, Rings, Practice, the Echo (as built)

*Detail: [design/slice/systems.md](/mnt/project-files/design/slice/systems.md) §2 (the rules
these numbers came from). Design: GDD 04 (progression and the loop). Tracker: S-1 (slice M3),
C-1 (spell levels and milestones), N-3 (mastery).*

*Target for the long-loop direction: what carries between lives (spells known, best levels and
the Echo, remembered trials, Sphere Comprehension, school rank, insight) is the carry table in the
[lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) §4 (tracker M0-10); spell growth itself is the
[spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md) §6. Gear (slots, tiers, traits and their caps) is the
[economy spec](/mnt/project-files/design/economy/economy-and-repair-spec.md) §4 (tracker M0-15).
Not built yet.*

There are two layers, and the ruins game uses the first on top of the second.

## The loop's growth (`scripts/game/growth.gd`, `data/slice/progression.json`)

- **Reset on waking:** wells, the Ring, each Model's (spell's) Practice, the spellbook.
- **Kept across loops:** the Models you know, the best Practice each reached, the most wells you
  held (the **Echo**), each spell's mutation picks (`soul.revisions`), and insight. The Turning
  writes them with `scripts/game/lives.gd` `carry` ([loop.md](loop.md)).
- **Wells** come from kills (`wells.kill` 1), patrols and meditating, capped at `well_cap` 80.
  Below the most you held in an earlier loop they grow `echo_mult` ×3 faster.
- **Rings:** Apprentice, 1st (the yard trial sets the flag `ring1`), 2nd, 3rd, 4th at
  `ring_wells` 0/0/20/40/70. Open slots of the four-spell book by Ring `slots` 2/3/3/4/4 (spell and
  combat spec §5.1; six slots before the combat weight pass, N-2.3); a spell's tier needs a Ring
  (`tier_ring`: bolt 0, control 1, signature 4). HP 100 + 2 per well, Aether 100 + 1 per well;
  blink charges at Rings `blink_ring` 2 and 4.
- **Practice** (spell XP): grows ×3 below the best that Model reached before, plus **insight**
  (lives spec §4.3): +1 at each Turning, up to +3, each point +10%, and each Omen taken this life adds 5% of that (`lives.json` `insight`,
  `omen_insight`; it
  replaced Fluency, which counted loops that reached day 7). Meditating and training at the watch's
  targets work once a day each (`once_a_day`); training gives `train_share` 0.4 of a level.
- **Start:** `start_models` Ember Bolt, Pebble, Pillar, Fling.
- **Fights borrow it:** `begin_fight()` lends this loop's Practice and spellbook to the
  Progression autoload with the rules dictionary (`Progression.rules`: hp, aether, blinks, open
  slots, echo, `fluency` (the insight bonus), no Magicks); `end_fight()` takes them back. A book saved with six slots
  keeps its first four.

## Spell levels and mastery (`scripts/autoload/progression.gd`, `data/spells.json` `progression`)

- A spell levels from its own hits: XP needed `xp_base` 8 + `xp_step` 4 per level, max 20.
- **Stages** (spell spec §6, N-3): Novice 1–5, Adept 6–10, Master 11–15, Perfected 16–20
  (`stages`, `stage_top`). Under the slice's rules (`rules.walls`) a spell stops at the top of its
  stage (the **wall**); XP keeps filling up to one level's worth (`xp_bank` 1.0) and is spent the
  moment it breaks through.
- **Breakthrough trials** (`breakthrough_trials` 1/2/3 of them for Adept/Master/Perfected), from:
  a **feat** (land it on a foe 15/45/100 times this life, `feats`; training doesn't count), an
  **insight** (any Ledger entry naming the spell in `insight`, none written yet) and a
  **meditation** (meditate on the day of the spell's Sphere: each element has a `sphere`, the
  weekday's Sphere comes from the calendar; `growth.meditate_trials()`). Perfected also needs a
  best-ever level of 11+ (the Echo). A stage reached in an earlier life (`soul.broken`, written by
  `lives.gd` `carry`) counts as remembered: you still climb, but the trial is waived.
- A breakthrough emits `breakthrough(id, stage)`, toasts "Breakthrough: …", and offers the stage's
  Revision pick (the old milestone picks at 5, 10, 15 now come at each breakthrough).
- **What a stage changes:** the Force grade (`grade_by_stage` I–IV, capped by Ring `grade_cap`
  1/2/2/3/3), and each spell's `minor` axis grows ×1.2 per stage (`minor_step`). A stat is still
  `base + per × (level − 1)` (`floor`, `min`, `max`) on its main axis.
- **Prerequisites** (`needs`, spell spec §6.5): Pyroclasm needs Ember Bolt and Pillar at Adept,
  Storm Call Spark and Arc Lance at Adept, Maelstrom Undertow at Master, Avalanche Pebble and Fling
  at Adept, this life. Until then the book lists it "(not yet)" and it can't be slotted.
- **Rings need stages too** (`ring_stages`): the 2nd Ring four spells at Adept, the 3rd one at
  Master, the 4th two at Master, on top of the wells.
- The book shows each slot's stage and grade, and the selected slot's next trials with ticks.
- **Wizard level** and the halving rule (`loop_wizard_level_keep` 0.5), mastery and tome hints
  belong to the old Mill fight; the ruins game's loop doesn't use them (see [drift.md](drift.md)).
  Without `rules.walls` (the old Mill fight) spells level straight to 20 as before.
- Saves to `user://progress.json`, apart from the run ([loop.md](loop.md)).

## Tests

`tools/tests/relearn.gd` (loop 3 is back to loop 1's wells and Practice by day 3),
`tools/tests/unit.gd` (walls, trials, banking, remembered stages, prerequisites, Ring stages).
