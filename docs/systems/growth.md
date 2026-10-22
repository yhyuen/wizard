# Growth: wells, Rings, Practice, the Echo (as built)

*Detail: [design/slice/systems.md](/mnt/project-files/design/slice/systems.md) §2 (the rules
these numbers came from). Design: GDD 04 (progression and the loop). Tracker: S-1 (slice M3),
C-1 (spell levels and milestones).*

*Target for the long-loop direction: what carries between lives (spells known, best levels and
the Echo, remembered trials, Sphere Comprehension, school rank, insight) is the carry table in the
[lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) §4 (tracker M0-10); spell growth itself is the
[spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md) §6. Not built yet.*

There are two layers, and the ruins game uses the first on top of the second.

## The loop's growth (`scripts/game/growth.gd`, `data/slice/progression.json`)

- **Reset on waking:** wells, the Ring, each Model's (spell's) Practice, the spellbook.
- **Kept across loops:** the Models you know, the best Practice each reached, the most wells you
  held (the **Echo**), each spell's mutation picks (`mem.revisions`), and Fluency.
- **Wells** come from kills (`wells.kill` 1), patrols and meditating, capped at `well_cap` 80.
  Below the most you held in an earlier loop they grow `echo_mult` ×3 faster.
- **Rings:** Apprentice, 1st (the yard trial sets the flag `ring1`), 2nd, 3rd, 4th at
  `ring_wells` 0/0/20/40/70. Open slots of the four-spell book by Ring `slots` 2/3/3/4/4 (spell and
  combat spec §5.1; six slots before the combat weight pass, N-2.3); a spell's tier needs a Ring
  (`tier_ring`: bolt 0, control 1, signature 4). HP 100 + 2 per well, Aether 100 + 1 per well;
  blink charges at Rings `blink_ring` 2 and 4.
- **Practice** (spell XP): grows ×3 below the best that Model reached before, plus Fluency
  +10% for each loop that reached day 7, capped at +50%. Meditating and training at the watch's
  targets work once a day each (`once_a_day`); training gives `train_share` 0.4 of a level.
- **Start:** `start_models` Ember Bolt, Pebble, Pillar, Fling.
- **Fights borrow it:** `begin_fight()` lends this loop's Practice and spellbook to the
  Progression autoload with the rules dictionary (`Progression.rules`: hp, aether, blinks, open
  slots, echo, fluency, no Magicks); `end_fight()` takes them back. A book saved with six slots
  keeps its first four.

## Spell levels (`scripts/autoload/progression.gd`, `data/spells.json` `progression`)

- A spell levels from its own hits: XP needed `xp_base` 8 + `xp_step` 4 per level, max 15.
- **Milestones** at 5, 10 and 15 pause the fight for a pick between two mutations; re-picks only
  at the Orrery shrine. A stat is `base + per × (level − 1)` (`floor`, `min`, `max`).
- **Wizard level** and the halving rule (`loop_wizard_level_keep` 0.5), mastery and tome hints
  belong to the old Mill fight; the ruins game's loop doesn't use them (see [drift.md](drift.md)).
- Saves to `user://progress.json`, apart from the run ([loop.md](loop.md)).

## Tests

`tools/tests/relearn.gd` (loop 3 is back to loop 1's wells and Practice by day 3),
`tools/tests/unit.gd`.
